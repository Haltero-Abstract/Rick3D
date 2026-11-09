;=====================================================================
; ECRAN.S - SCREENS : double buffer, erasing by rectangles, flip
;   (included by RICK3D.S ; the settings are in PARAMS.S)
;=====================================================================

;---------------------------------------------------------------------
; a6 = work screen, a4 = its dirty rectangle, a3 = its text state
back_ptrs:
                tst.w   cur_back
                bne.s   .b1
                move.l  scr0,a6
                lea     rlist0,a4
                lea     txts0,a3
                lea     huds0,a5
                rts
.b1:            move.l  scr1,a6
                lea     rlist1,a4
                lea     txts1,a3
                lea     huds1,a5
                rts

; flip : shows the screen just drawn.
;   The address is written DIRECTLY in the video registers (the VIDEL takes
;   it at the start of the next frame), then we wait for that VBL : after it,
;   the old screen is no longer shown and we can draw in it.
;   (Setscreen changes the address only at the next VBL : we then drew
;   one frame out of two in the screen being shown -> flicker.)
flip:
                bsr     back_ptrs
                move.l  a6,d0
                add.l   phys_off,d0
                move.w  sr,-(sp)
                move.w  #$2700,sr
                clr.l   $45e.w                  ; screenpt : the TOS VBL no longer touches it
                move.b  d0,$ffff820d.w          ; low address
                lsr.l   #8,d0
                move.b  d0,$ffff8203.w          ; middle
                lsr.l   #8,d0
                move.b  d0,$ffff8201.w          ; high
                move.w  (sp)+,sr
                move.l  $466.w,d0               ; _frclock : waits for the VBL
.w:             cmp.l   $466.w,d0
                beq.s   .w
                eor.w   #1,cur_back
                rts

; Erasing : each screen keeps the list of the rectangles drawn in
; the previous frame (one per object : Rick, platforms, shots...). The
; scenery (bgbuf) is copied back only into these rectangles.
                rsreset
L_CNT           rs.w    1
L_YMIN          rs.w    1               ; top / bottom of all the rectangles
L_YMAX          rs.w    1
L_FULL          rs.w    1               ; 1 : the whole screen (new scenery)
L_R             rs.w    4*MAXR          ; x0, y0, x1, y1
L_SIZE          rs.b    0

erase_full:
                lea     bgbuf,a0
                move.l  a6,a1
                move.w  #SCRSZ/16-1,d0
.full:          move.l  (a0)+,(a1)+
                move.l  (a0)+,(a1)+
                move.l  (a0)+,(a1)+
                move.l  (a0)+,(a1)+
                dbra    d0,.full
                rts

erase_list:
                movem.l a4-a5,-(sp)
                move.w  L_CNT(a4),d7
                lea     L_R(a4),a5
                bra.s   .n
.l:             movem.w (a5)+,d0-d3
                bsr.s   erase_one
.n:             dbra    d7,.l
                movem.l (sp)+,a4-a5
                rts

; erase_one : copies the scenery back into d0,d1 - d2,d3 (screen a6)
erase_one:
                lea     bgbuf,a0
                move.w  d1,d4
                mulu    #LINEB,d4
                move.w  d0,d5
                add.w   d5,d5
                ext.l   d5
                add.l   d5,d4
                lea     (a0,d4.l),a0
                lea     (a6,d4.l),a1
                sub.w   d0,d2
                sub.w   d1,d3
.ly:            move.l  a0,a2
                move.l  a1,a3
                move.w  d2,d6
.lx:            move.w  (a2)+,(a3)+
                dbra    d6,.lx
                lea     LINEB(a0),a0
                lea     LINEB(a1),a1
                dbra    d3,.ly
                rts

bb_reset:
                move.w  #32767,bb_x0
                move.w  #32767,bb_y0
                move.w  #-32768,bb_x1
                move.w  #-32768,bb_y1
                rts

; bb_push : adds the drawn rectangle (bb) to the list of the screen
bb_push:
                movem.l d0-d1/a0-a1,-(sp)
                move.w  bb_x0,d0
                cmp.w   bb_x1,d0
                bgt     .x                      ; nothing drawn
                move.l  cur_list,a0
                move.w  L_CNT(a0),d0
                cmp.w   #MAXR,d0
                blo.s   .add
                subq.w  #1,d0                   ; list full : merged with the last one
                lsl.w   #3,d0
                lea     L_R(a0,d0.w),a1
                move.w  bb_x0,d1
                cmp.w   (a1),d1
                bge.s   .u1
                move.w  d1,(a1)
.u1:            move.w  bb_y0,d1
                cmp.w   2(a1),d1
                bge.s   .u2
                move.w  d1,2(a1)
.u2:            move.w  bb_x1,d1
                cmp.w   4(a1),d1
                ble.s   .u3
                move.w  d1,4(a1)
.u3:            move.w  bb_y1,d1
                cmp.w   6(a1),d1
                ble.s   .ym
                move.w  d1,6(a1)
                bra.s   .ym
.add:           addq.w  #1,L_CNT(a0)
                lsl.w   #3,d0
                lea     L_R(a0,d0.w),a1
                move.w  bb_x0,(a1)+
                move.w  bb_y0,(a1)+
                move.w  bb_x1,(a1)+
                move.w  bb_y1,(a1)+
.ym:            move.w  bb_y0,d1
                cmp.w   L_YMIN(a0),d1
                bge.s   .y1
                move.w  d1,L_YMIN(a0)
.y1:            move.w  bb_y1,d1
                cmp.w   L_YMAX(a0),d1
                ble.s   .y2
                move.w  d1,L_YMAX(a0)
.y2:            bsr     bb_reset
.x:             movem.l (sp)+,d0-d1/a0-a1
                rts

;---------------------------------------------------------------------
; SCREEN SCROLLING (steps of SC_STEP tiles, see check_window)
; keep_old : copies the current scenery (bgbuf) into bgold
keep_old:       movem.l d0/a0-a1,-(sp)
                lea     bgbuf,a0
                lea     bgold,a1
                move.w  #SCRSZ/16-1,d0
.l:             move.l  (a0)+,(a1)+
                move.l  (a0)+,(a1)+
                move.l  (a0)+,(a1)+
                move.l  (a0)+,(a1)+
                dbra    d0,.l
                movem.l (sp)+,d0/a0-a1
                rts

; glide : SC_NFR-1 frames in between the old scenery (bgold)
;   and the new one (bgbuf), shifted like the front plane (TPX pixels per
;   tile), with Rick ; the game is stopped meanwhile
glide:          movem.l d0-d7/a0-a6,-(sp)
                move.w  win_ox,sc_ox            ; (new win_ox / win_oy)
                move.w  win_oy,sc_oy
                move.w  sc_glide,d0             ; d0 = step (tiles, +/-)
                bne.s   .h
                move.w  sc_vglide,d0
.h:             move.w  d0,sc_d
                move.w  #1,sc_k                 ; frame k
.fr:            move.w  sc_d,d0                 ; s = |P| * k / N (pixels)
                bpl.s   .p
                neg.w   d0
.p:             mulu    #TPX,d0
                move.w  d0,sc_p                 ; |P| : total shift
                mulu    sc_k,d0
                divu    #SC_NFR,d0
                move.w  d0,sc_s
                bsr     back_ptrs
                tst.w   sc_glide
                beq.s   .cv
                bsr     glide_comp
                bra.s   .rk
.cv:            bsr     glide_vcomp
.rk:            move.w  sc_d,d0                 ; Rick : scenery half-way
                lsl.w   #3,d0                   ;  (world units)
                muls    sc_k,d0
                divs    #SC_NFR,d0
                move.w  sc_d,d1
                lsl.w   #3,d1
                sub.w   d1,d0                   ; - whole step + part
                tst.w   sc_glide
                beq.s   .ry
                add.w   d0,win_ox
                bra.s   .rd
.ry:            add.w   d0,win_oy
.rd:            move.w  #HUD_H,clip_y0
                move.w  sc_y1,clip_y1
                bsr     draw_rick
                clr.w   clip_y0
                move.w  #SCR_H-1,clip_y1
                move.w  sc_ox,win_ox
                move.w  sc_oy,win_oy
                bsr     flip
                bsr     sfx_update
                addq.w  #1,sc_k
                cmp.w   #SC_NFR,sc_k
                blt     .fr
                movem.l (sp)+,d0-d7/a0-a6
                rts

; glide_vcomp : like glide_comp, vertically : above the seam
;   B one scenery, below it the other one (whole rows)
glide_vcomp:    movem.l d0-d7/a0-a5,-(sp)
                move.w  #SCR_H-1,d0
                tst.w   txt_hidden
                bne.s   .y
                move.w  txt_y,d0
                subq.w  #1,d0
.y:             move.w  d0,sc_y1
                move.w  sc_s,d4                 ; s
                move.w  sc_p,d5                 ; P
                tst.w   sc_vglide
                bmi.s   .neg
                ; downwards : B = 120 + P/2 - s
                ;   y < B <- old at y+s ; y >= B <- new at y+s-P
                move.w  d5,d3
                lsr.w   #1,d3
                add.w   #SCR_H/2,d3
                sub.w   d4,d3
                lea     bgold,a0
                move.w  d4,d0                   ; shift A (rows)
                lea     bgbuf,a1
                move.w  d4,d1
                sub.w   d5,d1                   ; shift B
                bra.s   .go
.neg:           ; upwards : B = 120 - P/2 + s
                ;   y < B <- new at y-s+P ; y >= B <- old at y-s
                move.w  #SCR_H/2,d3
                move.w  d5,d0
                lsr.w   #1,d0
                sub.w   d0,d3
                add.w   d4,d3
                lea     bgbuf,a0
                move.w  d5,d0
                sub.w   d4,d0
                lea     bgold,a1
                move.w  d4,d1
                neg.w   d1
.go:            move.w  #HUD_H,d7               ; d7 = row y
.row:           move.w  d7,d2
                cmp.w   d3,d2
                bge.s   .rb
                add.w   d0,d2                   ; source A
                move.l  a0,a3
                bra.s   .rc
.rb:            add.w   d1,d2                   ; source B
                move.l  a1,a3
.rc:            tst.w   d2                      ; (outside the scenery : nothing)
                bmi.s   .nx
                cmp.w   #SCR_H,d2
                bge.s   .nx
                mulu    #LINEB,d2
                adda.l  d2,a3
                move.w  d7,d2
                mulu    #LINEB,d2
                move.l  a6,a4
                adda.l  d2,a4
                move.w  #SCR_W/2-1,d6
.cp:            move.l  (a3)+,(a4)+
                dbra    d6,.cp
.nx:            addq.w  #1,d7
                cmp.w   sc_y1,d7
                ble.s   .row
                movem.l (sp)+,d0-d7/a0-a5
                rts

; glide_comp : builds the picture in a6 (rows from the HUD down to the text) :
;   left of the seam B one scenery, right of it the other one
glide_comp:     movem.l d0-d7/a0-a5,-(sp)
                move.w  #SCR_H-1,d0             ; last row
                tst.w   txt_hidden
                bne.s   .y
                move.w  txt_y,d0
                subq.w  #1,d0
.y:             move.w  d0,sc_y1
                move.w  sc_s,d4                 ; s
                move.w  sc_p,d5                 ; P
                tst.w   sc_glide
                bmi.s   .neg
                ; to the right : B = 160 + P/2 - s
                ;   [0,B) <- old at x+s ; [B,320) <- new at x+s-P
                move.w  d5,d3
                lsr.w   #1,d3
                add.w   #SCR_W/2,d3
                sub.w   d4,d3                   ; d3 = B
                lea     bgold,a0
                move.w  d4,d0                   ; shift of source A
                lea     bgbuf,a1
                move.w  d4,d1
                sub.w   d5,d1                   ; shift of source B (s - P)
                bra.s   .go
.neg:           ; to the left : B = 160 - P/2 + s
                ;   [0,B) <- new at x+P-s ; [B,320) <- old at x-s
                move.w  #SCR_W/2,d3
                move.w  d5,d0
                lsr.w   #1,d0
                sub.w   d0,d3
                add.w   d4,d3                   ; d3 = B
                lea     bgbuf,a0
                move.w  d5,d0
                sub.w   d4,d0                   ; shift of source A
                lea     bgold,a1
                move.w  d4,d1
                neg.w   d1                      ; shift of source B (-s)
.go:            add.w   d0,d0                   ; (bytes)
                adda.w  d0,a0
                add.w   d1,d1                   ; (for x = 0 : the loop
                adda.w  d1,a1                   ;  adds B)
                move.w  #HUD_H,d2               ; 1st row
                mulu    #LINEB,d2
                adda.l  d2,a0
                adda.l  d2,a1
                move.l  a6,a2
                adda.l  d2,a2
                move.w  d3,d6                   ; d6 = width A
                move.w  #SCR_W,d7
                sub.w   d3,d7                   ; d7 = width B
                move.w  sc_y1,d5
                sub.w   #HUD_H,d5               ; rows - 1
.row:           move.l  a0,a3
                move.l  a2,a4
                move.w  d6,d0
                subq.w  #1,d0
                bmi.s   .b
.ca:            move.w  (a3)+,(a4)+
                dbra    d0,.ca
.b:             move.l  a1,a3
                adda.w  d6,a3
                adda.w  d6,a3
                move.w  d7,d0
                subq.w  #1,d0
                bmi.s   .n
.cb:            move.w  (a3)+,(a4)+
                dbra    d0,.cb
.n:             lea     LINEB(a0),a0
                lea     LINEB(a1),a1
                lea     LINEB(a2),a2
                dbra    d5,.row
                movem.l (sp)+,d0-d7/a0-a5
                rts
