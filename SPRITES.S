;=====================================================================
; SPRITES.S - CACHED SPRITES OF THE CHARACTERS (Rick, enemies)
;   (included by RICK3D.S ; the settings are in PARAMS.S)
;
; A character (model + animation step + mirror) is drawn ONCE by the
; 3D renderer (draw_box) into an off-screen picture (spr_scr, filled
; with the colour key SPR_KEY), where it is first needed ; it is used
; again in the same "bucket" of 32 x 32 world units (SPR_BSH) of the screen (the
; perspective of the side faces depends on the position) and the same
; sub-pixel phase (SPR_SUBX / SPR_SUBY). Its opaque pixels are kept as runs per
; line (spans) in a pool (spc_pool) ; each frame, the sprite is only
; copied (move.l) at the exact projected position.
; Key : model address, walk step, ladder beat, mirror, bucket X / Y, phases.
; The pool is emptied when full and at each level (spr_flush).
; S key : cached sprites on / off (comparison with the 3D drawing).
;
; Sprite record :
;   key.l, next.l (hash chain), dx.w dy.w (top-left of the box - anchor ;
;   dx = $8000 : not cached, old drawing), w.w, h.w (0 = nothing drawn),
;   then h lines : size.w (bytes of the line, header included),
;   spans-1.w, spans : offset.w (bytes ; bit 0 = one colour), jump.w
;   (-2 x longs, bit 0 = odd pixel first), pixels (one colour : 1 word).
;=====================================================================

                rsreset
SP_KEY          rs.l    1
SP_NEXT         rs.l    1
SP_DX           rs.w    1
SP_DY           rs.w    1
SP_W            rs.w    1
SP_H            rs.w    1
SP_LINES        rs.b    0

;---------------------------------------------------------------------
; rick_spr / en_spr : Rick / the enemy (animation an_* / en_*), model a2,
;   origin d6/d7 -> Z set : drawn ; Z clear : draw it the old way
rick_spr:
                move.w  an_sl,sp_sl
                move.w  an_lf,sp_lf
                move.w  an_lb,sp_lb
                move.w  an_la,sp_la
                move.w  an_lb2,sp_lb2
                move.w  an_mir,sp_mir
                move.w  #RICK_W,sp_wid
                bra     spr_draw
en_spr:
                move.w  en_sl,sp_sl
                move.w  en_lf,sp_lf
                move.w  en_lb,sp_lb
                move.w  en_la,sp_la
                move.w  en_lb2,sp_lb2
                move.w  en_mir,sp_mir
                move.w  #EN_W,sp_wid
                bra     spr_draw

;---------------------------------------------------------------------
; plat_spr : moving platform (draw_plats : d0-d3 = world box, d7 = loop
;   counter) -> a model of 1 box (colour set 13 = col_mplat) per platform
;   in plat_mdl, drawn as a cached sprite ; Z set : drawn
plat_spr:
                movem.l d6-d7/a2,-(sp)
                move.w  nplats,d6
                sub.w   d7,d6
                mulu    #18,d6
                lea     plat_mdl,a2
                adda.l  d6,a2
                clr.l   (a2)                    ; x0, y0
                move.w  d2,d6
                sub.w   d0,d6
                move.w  d6,4(a2)                ; x1
                move.w  d3,d6
                sub.w   d1,d6
                move.w  d6,6(a2)                ; y1
                move.w  #PLAT_Z0-ZMID,8(a2)
                move.w  #PLAT_Z1-ZMID,10(a2)
                move.w  #13,12(a2)
                clr.w   14(a2)
                move.w  #-99,16(a2)
                clr.w   sp_sl                   ; (no animation)
                clr.w   sp_lf
                clr.w   sp_lb
                clr.w   sp_la
                clr.w   sp_lb2
                clr.w   sp_mir
                move.w  d0,d6
                move.w  d1,d7
                bsr     spr_draw
                movem.l (sp)+,d6-d7/a2          ; (flags kept)
                rts

;---------------------------------------------------------------------
; spr_draw : a2 = model, d6/d7 = world origin, animation in sp_*
;   -> d0 = 0 (Z set) : drawn in a6 (clip_y0/clip_y1, bb updated)
spr_draw:
                movem.l d1-d7/a0-a6,-(sp)
                tst.w   spr_on
                beq     .fail
                tst.w   view_back               ; back view : old drawing
                bne     .fail
                tst.w   spr_ready
                bne.s   .rd
                bsr     spr_flush
.rd:            move.w  d6,d1                   ; buckets of 2^SPR_BSH world units
                add.w   #160,d1
                bmi     .f2
                lsr.w   #SPR_BSH,d1
                cmp.w   #63,d1
                bhi     .f2
                move.w  d7,d2
                add.w   #128,d2
                bmi     .f2
                lsr.w   #SPR_BSH,d2
                cmp.w   #63,d2
                bhi     .f2
                move.w  d1,d3
                lsl.w   #6,d3
                or.w    d2,d3                   ; d3 = xb(6) yb(6)
                move.w  d6,d0                   ; anchor on the screen and
                bsr     spr_proj                ;  sub-pixel phases
                move.w  d0,spr_ax
                moveq   #3-SPR_SUBX,d0
                lsr.w   d0,d1
                move.w  d1,d5
                move.w  d7,d0
                bsr     spr_proj
                move.w  d0,spr_ay
                moveq   #3-SPR_SUBY,d0
                lsr.w   d0,d1
                lsl.w   #3,d1
                or.w    d1,d5
                ; --- key : model.w ^ phases | step(2) beat(1) mirror(1) xb(6) yb(6)
                ;     (the models are 256 bytes apart : low byte free)
                move.w  sp_sl,d0                ; walk step : 0, 2, -2
                asr.w   #1,d0
                and.w   #3,d0
                lsl.w   #1,d0
                move.w  sp_la,d4                ; ladder beat : 0 / 2
                lsr.w   #1,d4
                and.w   #1,d4
                or.w    d4,d0
                lsl.w   #1,d0
                move.w  sp_mir,d4
                and.w   #1,d4
                or.w    d4,d0
                lsl.w   #8,d0
                lsl.w   #4,d0
                or.w    d0,d3
                move.w  a2,d0
                eor.w   d5,d0
                swap    d3
                move.w  d0,d3
                swap    d3
                move.l  d3,d4                   ; hash
                swap    d4
                eor.w   d3,d4
                move.w  d4,d5
                lsr.w   #7,d5
                eor.w   d5,d4
                and.w   #SPR_HASH-1,d4
                lsl.w   #2,d4
                lea     spc_hash,a0
                move.l  (a0,d4.w),a1
.find:          move.l  a1,d0
                beq.s   .miss
                cmp.l   SP_KEY(a1),d3
                beq.s   .hit
                move.l  SP_NEXT(a1),a1
                bra.s   .find
.miss:          bsr     spr_make
.hit:           move.w  SP_DX(a1),d4
                cmp.w   #$8000,d4
                beq     .f4
                move.w  SP_H(a1),d5
                beq     .ok                     ; (nothing to draw)
                move.w  spr_ax,d0               ; --- position on the screen
                add.w   #CX,d0
                add.w   d4,d0
                move.w  d0,d4                   ; d4 = x0
                move.w  d0,d2
                add.w   SP_W(a1),d2
                subq.w  #1,d2                   ; d2 = x1
                move.w  d4,spr_sx               ; out at the sides : clipped
                clr.w   spr_xc                  ;  pixel by pixel (slow copy)
                tst.w   d4
                bpl.s   .xc0
                moveq   #0,d4
                move.w  #1,spr_xc
.xc0:           cmp.w   #SCR_W-1,d2
                ble.s   .xc1
                move.w  #SCR_W-1,d2
                move.w  #1,spr_xc
.xc1:           cmp.w   d2,d4
                bgt     .ok                     ; (completely out)
                move.w  spr_ay,d0
                add.w   #CY,d0
                add.w   SP_DY(a1),d0
                move.w  d0,d1                   ; d1 = first line
                move.w  d0,d3
                add.w   d5,d3
                subq.w  #1,d3                   ; d3 = last line
                move.w  d1,d0
                cmp.w   clip_y0,d0              ; clipping (HUD, bar, floors)
                bge.s   .c0
                move.w  clip_y0,d0
.c0:            cmp.w   clip_y1,d3
                ble.s   .c1
                move.w  clip_y1,d3
.c1:            cmp.w   d3,d0
                bgt     .ok
                lea     SP_LINES(a1),a0
                exg     d0,d1
                sub.w   d1,d0
                neg.w   d0                      ; lines skipped at the top
                bra.s   .sk1
.sk:            adda.w  (a0),a0
.sk1:           dbra    d0,.sk
                tst.w   spr_rec                 ; erasing : by its own spans
                beq.s   .bb
                tst.w   spr_xc                  ; (clipped at the sides : rectangle)
                bne.s   .bb
                move.l  cur_list,a4
                move.w  L_SN(a4),d0
                cmp.w   #MAXS,d0
                bhs.s   .bb                     ; (list full : rectangle)
                addq.w  #1,L_SN(a4)
                mulu    #SE_SZ,d0
                lea     L_S(a4),a5
                adda.w  d0,a5
                move.l  a0,SE_LP(a5)
                move.w  d1,d0
                mulu    #LINEB,d0
                moveq   #0,d5
                move.w  d4,d5
                add.l   d5,d5
                add.l   d5,d0
                move.l  d0,SE_OFF(a5)
                move.w  d3,d0
                sub.w   d1,d0
                move.w  d0,SE_NL(a5)
                move.w  spr_gen,SE_GEN(a5)
                move.w  d4,SE_X0(a5)
                move.w  d1,SE_X0+2(a5)
                move.w  d2,SE_X0+4(a5)
                move.w  d3,SE_X0+6(a5)
                cmp.w   L_YMIN(a4),d1           ; (bar / HUD to redraw ?)
                bge.s   .y1
                move.w  d1,L_YMIN(a4)
.y1:            cmp.w   L_YMAX(a4),d3
                ble.s   .b4
                move.w  d3,L_YMAX(a4)
                bra.s   .b4
.bb:            cmp.w   bb_x0,d4                ; erasing rectangle
                bge.s   .b1
                move.w  d4,bb_x0
.b1:            cmp.w   bb_y0,d1
                bge.s   .b2
                move.w  d1,bb_y0
.b2:            cmp.w   bb_x1,d2
                ble.s   .b3
                move.w  d2,bb_x1
.b3:            cmp.w   bb_y1,d3
                ble.s   .b4
                move.w  d3,bb_y1
.b4:            move.w  d3,d7
                sub.w   d1,d7                   ; lines - 1
                mulu    #LINEB,d1
                lea     (a6,d1.l),a3
                tst.w   spr_xc
                bne     .slow
                add.w   d4,d4
                adda.w  d4,a3
.ln:            move.w  (a0)+,d1                ; size of the line
                lea     -2(a0,d1.w),a4          ; -> next line
                move.w  (a0)+,d2                ; spans - 1
                bmi     .nl
.sp:            move.w  (a0)+,d1
                bclr    #0,d1                   ; (bit 0 : one colour)
                bne     .fl
                lea     (a3,d1.w),a2
                move.w  (a0)+,d3
                bclr    #0,d3                   ; odd pixel first
                beq.s   .ev
                move.w  (a0)+,(a2)+
.ev:            jmp     .te(pc,d3.w)
                rept    SPR_MAXL
                move.l  (a0)+,(a2)+
                endr
.te:            dbra    d2,.sp
.nl:            move.l  a4,a0
                lea     LINEB(a3),a3
                dbra    d7,.ln
.ok:            moveq   #0,d0
                bra     .x
.fl:            lea     (a3,d1.w),a2            ; span of one colour : filled
                move.w  (a0)+,d3                ;  (half the memory accesses)
                move.w  (a0)+,d4
                move.w  d4,d5
                swap    d5
                move.w  d4,d5
                bclr    #0,d3
                beq.s   .fe
                move.w  d4,(a2)+
.fe:            jmp     .tf(pc,d3.w)
                rept    SPR_MAXL
                move.l  d5,(a2)+
                endr
.tf:            dbra    d2,.sp
                bra     .nl
.slow:          move.w  spr_sx,d6               ; --- clipped at the sides
                move.w  d6,d4
                add.w   d4,d4
                adda.w  d4,a3                   ; (left of the box, may be < 0)
.sl:            move.w  (a0)+,d1
                lea     -2(a0,d1.w),a4
                move.w  (a0)+,d2
                bmi.s   .snl
.ss:            move.w  (a0)+,d1                ; offset (bytes)
                bclr    #0,d1
                sne     d0                      ; d0 : one colour
                move.w  (a0)+,d3
                moveq   #1,d5
                and.w   d3,d5                   ; odd pixel
                bclr    #0,d3
                sub.w   d3,d5                   ; d5 = pixels
                move.l  a0,a5                   ; a5 = pixels of the span
                tst.b   d0
                beq.s   .kl
                addq.l  #2,a0                   ; (one colour : 1 word)
                bra.s   .km
.kl:            adda.w  d5,a0
                adda.w  d5,a0                   ; a0 -> next span
.km:
                lea     (a3,d1.w),a2            ; a2 = screen
                asr.w   #1,d1
                add.w   d6,d1                   ; d1 = x of the 1st pixel
                move.w  d1,d4
                add.w   d5,d4                   ; d4 = x after the last one
                tst.w   d1                      ; span clipped at the left
                bpl.s   .k0
                tst.b   d0
                bne.s   .kc
                suba.w  d1,a5
                suba.w  d1,a5
.kc:            suba.w  d1,a2
                suba.w  d1,a2
                moveq   #0,d1
.k0:            cmp.w   #SCR_W,d4               ;  and at the right
                ble.s   .k1
                move.w  #SCR_W,d4
.k1:            sub.w   d1,d4
                ble.s   .kn
                subq.w  #1,d4
.kp:            move.w  (a5),(a2)+
                tst.b   d0
                bne.s   .kq
                addq.l  #2,a5
.kq:            dbra    d4,.kp
.kn:
                dbra    d2,.ss
.snl:           move.l  a4,a0
                lea     LINEB(a3),a3
                dbra    d7,.sl
                bra     .ok
.f2:            moveq   #2,d0                   ; out of the buckets
                bra.s   .fn
.f4:            moveq   #4,d0                   ; not cached (edges of the picture)
.fn:            or.w    d0,spr_fbm              ; (log : 3D drawings instead of
                addq.w  #1,spr_fb               ;  sprites, reasons, place)
                move.w  d6,spr_fbx              ; (+ 1000 : no sign in the log)
                add.w   #1000,spr_fbx
                move.w  d7,spr_fby
                add.w   #1000,spr_fby
.fail:          moveq   #1,d0
.x:             tst.w   d0
                movem.l (sp)+,d1-d7/a0-a6
                rts

; spr_proj : d0 = world coordinate -> d0 = pixels at ZREF (rounded down),
;   d1 = sub-pixel phase (0 .. 7)
spr_proj:
                muls    #FOC,d0
                add.l   #200*SPR_ZREF,d0
                divu    #SPR_ZREF,d0
                move.l  d0,d1
                clr.w   d1
                swap    d1                      ; remainder
                lsl.l   #3,d1
                divu    #SPR_ZREF,d1
                sub.w   #200,d0
                rts

;---------------------------------------------------------------------
; spr_make : new sprite, drawn at the place where it is first needed :
;   a2 = model, d6/d7 = origin, d3.l = key, d4.w = hash offset,
;   anchor spr_ax / spr_ay -> a1 = record
spr_make:
                addq.w  #1,spr_mk               ; (log : sprites made)
                movem.l d0-d7/a0/a2-a6,-(sp)
                move.l  d3,-(sp)
                move.w  d4,-(sp)
                move.w  clip_y0,-(sp)
                move.w  clip_y1,-(sp)
                move.l  bb_x0,-(sp)             ; (bb_x0 + bb_y0)
                move.l  bb_x1,-(sp)             ; (bb_x1 + bb_y1)
                clr.w   clip_y0                 ; whole picture
                move.w  #SCR_H-1,clip_y1
                lea     spr_scr,a6
                move.w  #4,spr_try
.try:           jsr     bb_reset
                bsr     spr_parts
                movem.w bb_x0,d0-d3             ; drawn box
                cmp.w   d2,d0
                bgt.s   .tok
                moveq   #0,d5                   ; touches an edge of the picture :
                tst.w   d0                      ;  drawn again 16 units closer to
                bgt.s   .t1                     ;  the centre (same bucket : the
                add.w   #16,d6                  ;  perspective is nearly the same)
                moveq   #1,d5
.t1:            cmp.w   #SCR_W-1,d2
                blt.s   .t2
                sub.w   #16,d6
                moveq   #1,d5
.t2:            tst.w   d1
                bgt.s   .t3
                add.w   #16,d7
                moveq   #1,d5
.t3:            cmp.w   #SCR_H-1,d3
                blt.s   .t4
                sub.w   #16,d7
                moveq   #1,d5
.t4:            tst.w   d5
                beq.s   .tok
                subq.w  #1,spr_try
                beq.s   .tok                    ; (gives up : not cached)
                bsr     spr_clean
                bra.s   .try
.tok:           movem.l d0-d1,-(sp)             ; anchor of the drawn place
                move.w  d6,d0
                bsr     spr_proj
                move.w  d0,spr_mx
                move.w  d7,d0
                bsr     spr_proj
                move.w  d0,spr_my
                movem.l (sp)+,d0-d1
                move.l  (sp)+,bb_x1
                move.l  (sp)+,bb_x0
                move.w  (sp)+,clip_y1
                move.w  (sp)+,clip_y0
                cmp.w   d2,d0
                bgt     .empty
                tst.w   d0                      ; touches an edge : clipped,
                ble     .fb                     ;  not cached (old drawing)
                cmp.w   #SCR_W-1,d2
                bge     .fb
                tst.w   d1
                ble     .fb
                cmp.w   #SCR_H-1,d3
                bge     .fb
                move.w  d2,d4
                sub.w   d0,d4
                addq.w  #1,d4                   ; d4 = width
                move.w  d3,d5
                sub.w   d1,d5
                addq.w  #1,d5                   ; d5 = height
                move.w  d4,d6                   ; size max : h x (8 + 6 w)
                mulu    #6,d6
                addq.l  #8,d6
                mulu    d5,d6
                add.l   #SP_LINES+16,d6
                cmp.l   #SPR_POOL/2,d6
                bhi     .fb
                move.l  spr_free,a1
                add.l   a1,d6
                cmp.l   #spc_pool+SPR_POOL,d6
                bls.s   .room
                bsr     spr_reset               ; pool full : emptied
                move.l  spr_free,a1
.room:          move.w  d0,d6
                sub.w   spr_mx,d6
                sub.w   #CX,d6
                move.w  d6,SP_DX(a1)
                move.w  d1,d6
                sub.w   spr_my,d6
                sub.w   #CY,d6
                move.w  d6,SP_DY(a1)
                move.w  d4,SP_W(a1)
                move.w  d5,SP_H(a1)
                lea     spr_scr,a3              ; --- spans
                mulu    #LINEB,d1
                adda.l  d1,a3
                add.w   d0,d0
                adda.w  d0,a3
                lea     SP_LINES(a1),a0
                move.w  d4,d6                   ; d6 = width
                move.w  d5,d7
                subq.w  #1,d7
.line:          move.l  a0,a4                   ; line header
                addq.l  #4,a0
                moveq   #-1,d5                  ; spans - 1
                moveq   #0,d0                   ; x
.skip:          cmp.w   d6,d0
                bge     .eol
                cmp.w   #SPR_KEY,(a3,d0.w*2)
                bne.s   .run
                addq.w  #1,d0
                bra.s   .skip
.run:           move.w  d0,d1                   ; start of the run
.r1:            addq.w  #1,d0
                cmp.w   d6,d0
                bge.s   .r2
                move.w  d0,d2
                sub.w   d1,d2
                cmp.w   #SPR_MAXL*2,d2          ; (max length of a span)
                bge.s   .r2
                cmp.w   #SPR_KEY,(a3,d0.w*2)
                bne.s   .r1
.r2:            addq.w  #1,d5
                move.w  d1,d2
                add.w   d2,d2
                move.w  d2,(a0)+                ; offset (bytes)
                move.w  d0,d2
                sub.w   d1,d2                   ; pixels
                move.w  d2,d3
                lsr.w   #1,d3
                add.w   d3,d3
                neg.w   d3                      ; -2 x longs
                btst    #0,d2
                beq.s   .r3
                bset    #0,d3
.r3:            move.w  d3,(a0)+
                lea     (a3,d1.w*2),a5
                cmp.w   #3,d2                   ; one colour (3 pixels or more) :
                blt.s   .lit                    ;  colour only, filled
                move.w  (a5),d3
                move.w  d2,d4
                subq.w  #2,d4
                lea     2(a5),a2
.u:             cmp.w   (a2)+,d3
                dbne    d4,.u
                bne.s   .lit
                or.w    #1,-4(a0)               ; (offset : bit 0)
                move.w  d3,(a0)+
                subq.w  #1,d2
.cl:            move.w  #SPR_KEY,(a5)+
                dbra    d2,.cl
                bra     .skip
.lit:           subq.w  #1,d2
.cp:            move.w  (a5),(a0)+
                move.w  #SPR_KEY,(a5)+          ; (picture cleaned)
                dbra    d2,.cp
                bra     .skip
.eol:           move.l  a0,d2
                sub.l   a4,d2
                move.w  d2,(a4)
                move.w  d5,2(a4)
                lea     LINEB(a3),a3
                dbra    d7,.line
                move.l  a0,spr_free
                bra.s   .link
.fb:            bsr     spr_clean
                move.w  #$8000,d6
                bra.s   .small
.empty:         moveq   #0,d6
.small:         move.l  spr_free,a1
                lea     SP_LINES(a1),a0
                cmp.l   #spc_pool+SPR_POOL,a0
                bls.s   .s1
                bsr     spr_reset
                move.l  spr_free,a1
                lea     SP_LINES(a1),a0
.s1:            move.w  d6,SP_DX(a1)
                clr.w   SP_DY(a1)
                clr.w   SP_W(a1)
                clr.w   SP_H(a1)
                move.l  a0,spr_free
.link:          move.w  (sp)+,d4
                move.l  (sp)+,d3
                move.l  d3,SP_KEY(a1)
                lea     spc_hash,a2
                move.l  (a2,d4.w),SP_NEXT(a1)
                move.l  a1,(a2,d4.w)
                movem.l (sp)+,d0-d7/a0/a2-a6
                rts

; spr_clean : rectangle d0,d1 - d2,d3 of spr_scr back to the key
spr_clean:
                movem.l d0-d3/a0-a1,-(sp)
                lea     spr_scr,a0
                mulu    #LINEB,d1
                adda.l  d1,a0
                sub.w   d0,d2                   ; width - 1
                add.w   d0,d0
                adda.w  d0,a0
                movem.l (sp),d0-d1              ; (y0 back)
                sub.w   d1,d3                   ; height - 1
.y:             move.l  a0,a1
                move.w  d2,d0
.x:             move.w  #SPR_KEY,(a1)+
                dbra    d0,.x
                lea     LINEB(a0),a0
                dbra    d3,.y
                movem.l (sp)+,d0-d3/a0-a1
                rts

; spr_parts : draws the model a2 at d6/d7 (animation sp_*), like
;   draw_rick0 / en_draw1 (side view)
spr_parts:
                movem.l d0-d7/a0-a2,-(sp)
.part:          move.w  (a2)+,d0
                cmp.w   #-99,d0
                beq     .end
                move.w  (a2)+,d1
                move.w  (a2)+,d2
                move.w  (a2)+,d3
                move.w  (a2)+,-(sp)             ; z0
                move.w  (a2)+,d5                ; z1
                move.w  (a2)+,d4                ; colour set
                lsl.w   #2,d4
                lea     setptr,a1
                move.l  (a1,d4.w),a1
                move.w  (a2)+,d4                ; animation (high byte)
                lsr.w   #8,d4
                btst    #0,d4                   ; front leg
                beq.s   .b0
                add.w   sp_sl,d0
                add.w   sp_sl,d2
                sub.w   sp_lf,d3
.b0:            btst    #1,d4                   ; back leg
                beq.s   .b1
                sub.w   sp_sl,d0
                sub.w   sp_sl,d2
                sub.w   sp_lb,d3
.b1:            btst    #2,d4                   ; front arm
                beq.s   .b2
                sub.w   sp_sl,d0
                sub.w   sp_sl,d2
.b2:            btst    #3,d4                   ; back arm
                beq.s   .b3
                add.w   sp_sl,d0
                add.w   sp_sl,d2
.b3:            btst    #4,d4                   ; ladder : limb A
                beq.s   .b4
                sub.w   sp_la,d3
                btst    #6,d4
                beq.s   .b4
                sub.w   sp_la,d1
.b4:            btst    #5,d4                   ; ladder : limb B
                beq.s   .b5
                sub.w   sp_lb2,d3
                btst    #6,d4
                beq.s   .b5
                sub.w   sp_lb2,d1
.b5:            tst.w   sp_mir                  ; mirror : x -> width - x
                beq.s   .b6
                exg     d0,d2
                neg.w   d0
                neg.w   d2
                add.w   sp_wid,d0
                add.w   sp_wid,d2
.b6:            move.w  (sp)+,d4                ; z0
                add.w   #ZMID,d4
                add.w   #ZMID,d5
                add.w   d6,d0
                add.w   d6,d2
                add.w   d7,d1
                add.w   d7,d3
                jsr     draw_box
                bra     .part
.end:           movem.l (sp)+,d0-d7/a0-a2
                rts

;---------------------------------------------------------------------
; spr_reset : empty pool ; spr_flush : + picture filled with the key
;   (new level : new models / colours)
spr_reset:
                movem.l d0/a0,-(sp)
                lea     spc_hash,a0
                move.w  #SPR_HASH-1,d0
.h:             clr.l   (a0)+
                dbra    d0,.h
                move.l  #spc_pool,spr_free
                addq.w  #1,spr_gen              ; (sprites noted : no longer valid)
                movem.l (sp)+,d0/a0
                rts
spr_flush:
                jsr     bg_reset                ; (new level : no screen built)
                bsr     spr_reset
                tst.w   spr_ready
                bne.s   .x
                movem.l d0-d1/a0,-(sp)
                lea     spr_scr,a0
                move.l  #(SPR_KEY<<16)|SPR_KEY,d1
                move.w  #SCR_W*SCR_H/2-1,d0
.f:             move.l  d1,(a0)+
                dbra    d0,.f
                move.w  #1,spr_ready
                movem.l (sp)+,d0-d1/a0
.x:             rts

; spr_erase : the cached sprites drawn in this screen (a4 = its list,
;   a6 = screen) : the scenery is copied back only under their spans
spr_erase:
                movem.l d0-d7/a0-a5,-(sp)
                move.w  L_SN(a4),d7
                beq     .x
                subq.w  #1,d7
                lea     L_S(a4),a5
                moveq   #0,d5                   ; (profiler : words)
.e:             move.l  a5,-(sp)
                move.w  SE_GEN(a5),d0
                cmp.w   spr_gen,d0
                beq.s   .sp
                movem.w SE_X0(a5),d0-d3         ; pool emptied : rectangle
                movem.l d5/d7,-(sp)
                jsr     erase_one
                movem.l (sp)+,d5/d7
                bra     .nx
.sp:            move.l  SE_LP(a5),a0
                move.l  SE_OFF(a5),d0
                lea     (a6,d0.l),a3
                lea     bgbuf,a2
                adda.l  d0,a2
                move.w  SE_NL(a5),d6
.ln:            move.w  (a0)+,d1                ; size of the line
                lea     -2(a0,d1.w),a1
                move.w  (a0)+,d2                ; spans - 1
                bmi     .nl
.s:             move.w  (a0)+,d1
                bclr    #0,d1
                sne     d0                      ; (one colour : 1 word)
                lea     (a3,d1.w),a4
                lea     (a2,d1.w),a5
                move.w  (a0)+,d3
                bclr    #0,d3
                beq.s   .ev
                move.w  (a5)+,(a4)+
                addq.w  #1,d5
                tst.b   d0
                bne.s   .ev
                addq.l  #2,a0
.ev:            sub.w   d3,d5
                tst.b   d0
                beq.s   .el
                addq.l  #2,a0
                bra.s   .eg
.el:            suba.w  d3,a0                   ; (pixels of the sprite skipped)
                suba.w  d3,a0
.eg:
                jmp     .te(pc,d3.w)
                rept    SPR_MAXL
                move.l  (a5)+,(a4)+
                endr
.te:            dbra    d2,.s
.nl:            move.l  a1,a0
                lea     LINEB(a3),a3
                lea     LINEB(a2),a2
                dbra    d6,.ln
.nx:            move.l  (sp)+,a5
                lea     SE_SZ(a5),a5
                dbra    d7,.e
                add.l   d5,pr_ew
.x:             movem.l (sp)+,d0-d7/a0-a5
                rts

; spr_toggle : S key : cached sprites on / off (message in the bar)
spr_toggle:
                eor.w   #1,spr_on
                lea     t_spron,a0
                tst.w   spr_on
                bne.s   .m
                lea     t_sproff,a0
.m:             move.l  a0,msg_ptr
                move.w  #MSG_DUR,msg_t
                rts
