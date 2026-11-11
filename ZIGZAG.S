;=====================================================================
; ZIGZAG.S - beams and waves (zigzag of PIEGES.S), side view : all the
;   segments projected by the table zp_ptab and filled here (before :
;   zap_rect + rect_bb for each segment of 4 units)
;   (included by RICK3D.S at the end of the code : branches in range)
;=====================================================================

; d0 = x start, d2 = x end, d1 = top of the band (centred world units)

zz_fast:
                movem.l d0-d7/a0-a5,-(sp)
                tst.w   zp_tok
                bne.s   .tk
                jsr     zp_mktab
.tk:            lea     zp_ptab+1024,a0
                lea     zz_y,a1                 ; the 3 heights 0 2 4 : lines y0, y1
                moveq   #0,d4
.yb:            move.w  d1,d5
                add.w   d4,d5
                move.w  d5,d6
                addq.w  #2,d6
                add.w   d5,d5
                move.w  (a0,d5.w),d5
                add.w   #CY,d5
                add.w   d6,d6
                move.w  (a0,d6.w),d6
                add.w   #CY-1,d6
                cmp.w   d5,d6
                bge.s   .y1
                move.w  d5,d6
.y1:            cmp.w   clip_y0,d5
                bge.s   .y2
                move.w  clip_y0,d5
.y2:            cmp.w   clip_y1,d6
                ble.s   .y3
                move.w  clip_y1,d6
.y3:            move.w  d5,(a1)+
                move.w  d6,(a1)+
                addq.w  #2,d4
                cmp.w   #4,d4
                ble.s   .yb
                lea     zz_y,a1
                move.w  d2,d7                   ; d7 = end
                moveq   #0,d3
                move.w  zp_ph,d3
                divu    #ZZ_SLOW,d3             ; d3 = slow phase
                moveq   #0,d5                   ; d5 = index
.l:             cmp.w   d7,d0
                bge     .done
                cmp.w   #-500,d0                ; (out of the table)
                blt     .nx
                cmp.w   #500,d0
                bgt     .nx
                move.w  d5,d4
                add.w   d3,d4
                and.w   #3,d4                   ; height 0 2 4 2 (triangle)
                cmp.w   #3,d4
                bne.s   .h
                moveq   #1,d4
.h:             lsl.w   #2,d4
                move.w  d0,d1
                add.w   d1,d1
                move.w  (a0,d1.w),d1
                add.w   #CX,d1                  ; x0
                move.w  d0,d2
                addq.w  #4,d2
                cmp.w   d7,d2
                ble.s   .c
                move.w  d7,d2
.c:             add.w   d2,d2
                move.w  (a0,d2.w),d2
                add.w   #CX-1,d2                ; x1
                cmp.w   d1,d2
                bge.s   .c1
                move.w  d1,d2
.c1:            tst.w   d1
                bpl.s   .c2
                moveq   #0,d1
.c2:            cmp.w   #SCR_W-1,d2
                ble.s   .c3
                move.w  #SCR_W-1,d2
.c3:            cmp.w   d1,d2
                blt.s   .nx
                move.w  (a1,d4.w),d6            ; y0
                move.w  2(a1,d4.w),d4           ; y1
                cmp.w   d6,d4
                blt.s   .nx
                cmp.w   bb_x0,d1                ; erasing rectangle
                bge.s   .b1
                move.w  d1,bb_x0
.b1:            cmp.w   bb_x1,d2
                ble.s   .b2
                move.w  d2,bb_x1
.b2:            cmp.w   bb_y0,d6
                bge.s   .b3
                move.w  d6,bb_y0
.b3:            cmp.w   bb_y1,d4
                ble.s   .b4
                move.w  d4,bb_y1
.b4:            sub.w   d6,d4                   ; lines - 1
                sub.w   d1,d2                   ; pixels - 1
                mulu    #LINEB,d6
                lea     (a6,d6.l),a3
                add.w   d1,d1
                adda.w  d1,a3
                move.w  col_zap,d1
.fy:            move.l  a3,a2
                move.w  d2,d6
.fx:            move.w  d1,(a2)+
                dbra    d6,.fx
                lea     LINEB(a3),a3
                dbra    d4,.fy
.nx:            addq.w  #4,d0
                addq.w  #1,d5
                bra     .l
.done:          movem.l (sp)+,d0-d7/a0-a5
                rts

;---------------------------------------------------------------------
; CANISTERS (PIEGES.S) : pickup without rebuilding the scenery
CAN_MRG         equ     8
; can_model : draw_model ; in draw_items, also records the drawn box
;   of the canister (can_cur), + CAN_MRG for its bar (ZP_BP = 2)
can_model:
                tst.w   can_rec
                beq     draw_model
                movem.l d0-d4/a1,-(sp)
                move.l  bb_x0,-(sp)
                move.l  bb_x1,-(sp)
                jsr     bb_reset
                bsr     draw_model
                movem.w bb_x0,d0-d3
                move.l  (sp)+,bb_x1
                move.l  (sp)+,bb_x0
                move.l  can_cur,a1
                moveq   #1,d4                   ; (1 : nothing drawn)
                cmp.w   d2,d0
                bgt.s   .st
                sub.w   #CAN_MRG,d0             ; (margin : the bar under it
                sub.w   #CAN_MRG,d1             ;  is drawn without bb)
                add.w   #CAN_MRG,d2
                add.w   #CAN_MRG,d3
                tst.w   d0
                bpl.s   .c0
                moveq   #0,d0
.c0:            tst.w   d1
                bpl.s   .c1
                moveq   #0,d1
.c1:            cmp.w   #SCR_W-1,d2
                ble.s   .c2
                move.w  #SCR_W-1,d2
.c2:            cmp.w   #SCR_H-1,d3
                ble.s   .c3
                move.w  #SCR_H-1,d3
.c3:            cmp.w   d2,d0
                bgt.s   .st
                cmp.w   d3,d1
                bgt.s   .st
                movem.w d0-d3,ZP_BX0(a1)
                moveq   #2,d4
.st:            move.l  d4,ZP_BP(a1)
                movem.l (sp)+,d0-d4/a1
                rts

; can_erase : canister a2 picked up -> its box gets back the scenery
;   without it (bg_noit) where nothing was drawn over it after (front
;   faces), and is erased on the 2 screens (no full rebuild)
can_erase:
                movem.l d0-d5/a0-a3,-(sp)
                move.l  ZP_BP(a2),d0
                bne.s   .bp
                move.w  #1,items_dirty          ; not recorded : rebuild
                bra     .x
.bp:            cmp.l   #2,d0                   ; (1 : nothing drawn)
                bls     .x
                move.l  d0,a3
                movem.w ZP_BX0(a2),d0-d3
                move.w  d1,d4
                mulu    #LINEB,d4
                move.w  d0,d5
                add.w   d5,d5
                ext.l   d5
                add.l   d5,d4
                lea     bgbuf,a0
                add.l   d4,a0
                move.l  bg_noitp,a1
                add.l   d4,a1
                move.w  d3,d5
                sub.w   d1,d5
.ly:            move.w  d2,d4
                sub.w   d0,d4
                movem.l a0-a1,-(sp)
.lx:            cmp.w   (a3)+,(a0)+             ; still the canister's pixel ?
                bne.s   .nx
                move.w  (a1),-2(a0)
.nx:            addq.l  #2,a1
                dbra    d4,.lx
                movem.l (sp)+,a0-a1
                lea     LINEB(a0),a0
                lea     LINEB(a1),a1
                dbra    d5,.ly
                move.l  cur_list,-(sp)          ; box erased on both screens
                move.l  bb_x0,-(sp)
                move.l  bb_x1,-(sp)
                movem.w d0-d3,bb_x0
                move.l  #rlist0,cur_list
                jsr     bb_push
                movem.w d0-d3,bb_x0
                move.l  #rlist1,cur_list
                jsr     bb_push
                move.l  (sp)+,bb_x1
                move.l  (sp)+,bb_x0
                move.l  (sp)+,cur_list
                move.l  #1,ZP_BP(a2)
.x:             movem.l (sp)+,d0-d5/a0-a3
                rts
;---------------------------------------------------------------------
; bld_begin / bld_end : around build_screen (0.2 - 0.5 s) : the 3D is done
;   by the 030 (BLD_DSP = 0 : no exchange with the DSP, so the interrupts
;   are never masked and the music replay has the DSP for itself), and
;   the YM sound effects go on : sfx_update is put in the TOS VBL queue
;   (one step per VBL, like the main loop) while building
bld_begin:
                move.w  d3don,bld_d3d
                ifeq    BLD_DSP
                clr.w   d3don
                endif
                movem.l d0/a0,-(sp)
                clr.l   bld_slot
                move.w  $454.w,d0               ; nvbls : a free place
                subq.w  #1,d0
                bmi.s   .x
                move.l  $456.w,a0               ; _vblqueue
.l:             tst.l   (a0)
                beq.s   .f
                addq.l  #4,a0
                dbra    d0,.l
                bra.s   .x                      ; (none : no sound effects)
.f:             move.l  a0,bld_slot
                move.l  #sfx_update,(a0)
.x:             movem.l (sp)+,d0/a0
                move.w  #1,bld_on
                rts
bld_end:
                clr.w   bld_on
                move.l  a0,-(sp)
                move.l  bld_slot,d0
                beq.s   .x
                move.l  d0,a0
                clr.l   (a0)
.x:             move.l  (sp)+,a0
                move.w  bld_d3d,d3don
                rts
