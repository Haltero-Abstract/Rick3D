;=====================================================================
; RENDU3D.S - 3D RENDERING : boxes, projection, filled quads
;   (included by RICK3D.S ; the settings are in PARAMS.S)
;=====================================================================

;---------------------------------------------------------------------
; 3D box : d0=X0 d1=Y0 d2=X1 d3=Y1 (centred world coordinates)
;            d4=Z0 d5=Z1, a1 -> colours (face, side, top, bottom)
; Only the faces turned towards the camera are drawn, and only
; those allowed by box_mask (1 left 2 right 4 top 8 bottom).
draw_box:
                BGCHK                           ; (background build : pause ?)
                movem.l d0-d7/a0-a1,-(sp)
                tst.w   view_back               ; back view : axes swapped
                beq.s   .std
                tst.w   bv_rec                  ; (moving objects : noted)
                bne     .rec
                tst.w   bv_bill                 ; flat object : turned to face
                beq.s   .nbb                    ;  the camera
                bsr     bv_billb
.nbb:           bsr     bv_xform
                beq     .skip
.std:           tst.w   d3don                   ; maths by the DSP (R3D)
                beq.s   .c030                   ;  only if there is a side face
                btst    #0,box_mask+1           ;  to draw (otherwise the
                beq.s   .q1                     ;  030 is faster)
                tst.w   d0
                bgt.s   .dsp
.q1:            btst    #1,box_mask+1
                beq.s   .q2
                tst.w   d2
                blt.s   .dsp
.q2:            btst    #2,box_mask+1
                beq.s   .q3
                tst.w   d1
                bgt.s   .dsp
.q3:            btst    #3,box_mask+1
                beq.s   .c030
                tst.w   d3
                bge.s   .c030
.dsp:           jsr     d3dbox
                tst.l   d7
                bmi.s   .c030                   ; (it no longer answers)
                beq     .skip
                bra     .front                  ; front face : d0-d3 projected
.c030:
                btst    #0,box_mask+1           ; (faces hidden by a neighbour)
                beq.s   .nol
                tst.w   d0
                ble.s   .nol
                lea     q3d,a0                  ; left face
                PT      d0,d1,d4
                PT      d0,d1,d5
                PT      d0,d3,d5
                PT      d0,d3,d4
                lea     q3d,a0
                move.w  2(a1),d7
                bsr     draw_quad3d
.nol:           btst    #1,box_mask+1
                beq.s   .nor
                tst.w   d2
                bge.s   .nor
                lea     q3d,a0                  ; right face
                PT      d2,d1,d4
                PT      d2,d1,d5
                PT      d2,d3,d5
                PT      d2,d3,d4
                lea     q3d,a0
                move.w  2(a1),d7
                bsr     draw_quad3d
.nor:           btst    #2,box_mask+1
                beq.s   .not
                tst.w   d1
                ble.s   .not
                lea     q3d,a0                  ; top
                PT      d0,d1,d4
                PT      d2,d1,d4
                PT      d2,d1,d5
                PT      d0,d1,d5
                lea     q3d,a0
                move.w  4(a1),d7
                bsr     draw_quad3d
.not:           btst    #3,box_mask+1
                beq.s   .nob
                tst.w   d3
                bge     .nob
                lea     q3d,a0                  ; bottom
                PT      d0,d3,d4
                PT      d2,d3,d4
                PT      d2,d3,d5
                PT      d0,d3,d5
                lea     q3d,a0
                move.w  6(a1),d7
                bsr     draw_quad3d
.nob:           tst.w   view_back               ; (back view : hidden face)
                beq.s   .nb2
                tst.w   bv_nofront
                bne     .skip
                tst.w   bv_nf2
                bne     .skip
.nb2:
                move.w  (a1),d7                 ; front face : a rectangle
                muls    #FOC,d0                 ; (direct projection)
                divs    d4,d0
                add.w   #CX,d0
                muls    #FOC,d2
                divs    d4,d2
                add.w   #CX,d2
                muls    #FOC,d1
                divs    d4,d1
                add.w   #CY,d1
                muls    #FOC,d3
                divs    d4,d3
                add.w   #CY,d3
.front:         move.w  (a1),d7
                tst.l   box_tex                 ; drawn front face (8x8) ?
                bne.s   .tex
                bsr     rect_bb
                movem.l (sp)+,d0-d7/a0-a1
                rts
.tex:           bsr     rect_tex
.skip:          movem.l (sp)+,d0-d7/a0-a1
                rts
.rec:           bsr     bv_note
                bra.s   .skip

;---------------------------------------------------------------------
; draw_model : draws a MODEL (list of boxes, see DONNEES.S)
;   a2 -> model, d6/d7 = origin (centred world coordinates),
;   d5 = transformation : bit 1 = swap x/y (object turned a quarter
;   of a turn), bit 0 = horizontal mirror (x -> -x), in this order ;
;   bits 8-11 = neighbours of the same kind (1 left 2 right 4 up 8 down)
;   Options of a box (high byte of the last word) :
;     $01 horizontal join (no left/right face against a neighbour)
;     $02 vertical join   (no top/bottom face against a neighbour)
;     $04/$08/$10/$20 box only at the left/right/top/bottom edge
draw_model:
                movem.l d0-d7/a0-a2,-(sp)
                move.w  d6,mdl_ox
                move.w  d7,mdl_oy
                move.w  d5,d0                   ; neighbours -> model frame
                lsr.w   #8,d0
                and.w   #15,d0
                and.w   #3,d5
                move.w  d5,mdl_fl
                btst    #1,d5
                beq.s   .t1
                lea     nb_swap,a0
                move.b  (a0,d0.w),d0
.t1:            btst    #0,d5
                beq.s   .t2
                lea     nb_mir,a0
                move.b  (a0,d0.w),d0
.t2:            move.w  d0,mdl_nb
                bra     .p
.p:             move.w  (a2)+,d0
                cmp.w   #-99,d0
                beq     .x
                move.w  (a2)+,d1
                move.w  (a2)+,d2
                move.w  (a2)+,d3
                move.w  (a2)+,d4
                move.w  (a2)+,d5
                move.w  (a2)+,d6                ; colour set
                move.w  (a2)+,d7                ; drawing (0 = none) + options
                ; --- box only at the edge (different neighbour on that side)
                move.w  d7,-(sp)
                lsr.w   #8,d7
                lsr.w   #2,d7                   ; edge options (4 bits)
                and.w   mdl_nb,d7
                movem.w (sp)+,d7
                bne     .p                      ; neighbour present : box left out
                ; --- faces hidden against a neighbour (model frame)
                move.w  d7,-(sp)
                moveq   #15,d6
                btst    #8,d7
                beq.s   .j1
                move.w  mdl_nb,d7
                and.w   #3,d7
                eor.w   d7,d6
.j1:            move.w  (sp),d7
                btst    #9,d7
                beq.s   .j2
                move.w  mdl_nb,d7
                and.w   #12,d7
                eor.w   d7,d6
.j2:            btst    #1,mdl_fl+1             ; -> world frame
                beq.s   .j3
                lea     nb_swap,a0
                move.b  (a0,d6.w),d6
.j3:            btst    #0,mdl_fl+1
                beq.s   .j4
                lea     nb_mir,a0
                move.b  (a0,d6.w),d6
.j4:            move.w  d6,box_mask
                move.w  (sp)+,d7
                move.w  -2(a2),d7               ; (drawing)
                move.w  -4(a2),d6               ; (colours)
                btst    #1,mdl_fl+1
                beq.s   .ns
                exg     d0,d1
                exg     d2,d3
.ns:            btst    #0,mdl_fl+1
                beq.s   .nm
                neg.w   d0
                neg.w   d2
                exg     d0,d2
.nm:            add.w   mdl_ox,d0
                add.w   mdl_ox,d2
                add.w   mdl_oy,d1
                add.w   mdl_oy,d3
                add.w   #ZMID,d4
                add.w   #ZMID,d5
                lsl.w   #2,d6
                lea     setptr,a1
                move.l  (a1,d6.w),a1
                and.w   #$ff,d7
                beq.s   .nt
                subq.w  #1,d7
                and.w   #15,d7
                lsl.w   #7,d7                   ; 128 bytes per drawing
                lea     tex_data,a0
                adda.w  d7,a0
                move.l  a0,box_tex
.nt:            bsr     draw_box
                clr.l   box_tex
                move.w  #15,box_mask
                bra     .p
.x:             movem.l (sp)+,d0-d7/a0-a2
                rts
nb_swap:        dc.b    0,4,8,12,1,5,9,13,2,6,10,14,3,7,11,15
nb_mir:         dc.b    0,2,1,3,4,6,5,7,8,10,9,11,12,14,13,15
                even

;---------------------------------------------------------------------
; rect_tex : like rect_bb, but filled with the 8x8 drawing box_tex
;   stretched over the rectangle (d0,d1)-(d2,d3)
rect_tex:
                movem.l d0-d7/a0-a3,-(sp)
                move.l  box_tex,a2
                move.w  d2,d4
                sub.w   d0,d4
                addq.w  #1,d4                   ; width
                ble     .x
                move.w  d3,d5
                sub.w   d1,d5
                addq.w  #1,d5                   ; height
                ble     .x
                move.l  #2048,d6                ; x step (8.8)
                divu    d4,d6
                move.l  #2048,d7                ; y step
                divu    d5,d7
                and.l   #$ffff,d7
                moveq   #0,d5                   ; y of the drawing (8.8)
                cmp.w   clip_y0,d1
                bge.s   .t1
                move.w  clip_y0,d5
                sub.w   d1,d5
                mulu    d7,d5
                move.w  clip_y0,d1
.t1:            moveq   #0,d4                   ; x of the drawing at the left edge
                tst.w   d0
                bpl.s   .t2
                move.w  d0,d4
                neg.w   d4
                mulu    d6,d4
                moveq   #0,d0
.t2:            cmp.w   #SCR_W-1,d2
                ble.s   .t3
                move.w  #SCR_W-1,d2
.t3:            cmp.w   clip_y1,d3
                ble.s   .t4
                move.w  clip_y1,d3
.t4:            cmp.w   d2,d0
                bgt     .x
                cmp.w   d3,d1
                bgt     .x
                jsr     bvx_add                 ; (back view : to erase)
                cmp.w   bb_x0,d0
                bge.s   .b1
                move.w  d0,bb_x0
.b1:            cmp.w   bb_y0,d1
                bge.s   .b2
                move.w  d1,bb_y0
.b2:            cmp.w   bb_x1,d2
                ble.s   .b3
                move.w  d2,bb_x1
.b3:            cmp.w   bb_y1,d3
                ble.s   .b4
                move.w  d3,bb_y1
.b4:            sub.w   d0,d2                   ; width - 1
                sub.w   d1,d3                   ; height - 1
                move.w  d3,-(sp)
                mulu    #LINEB,d1
                lea     (a6,d1.l),a0
                add.w   d0,d0
                adda.w  d0,a0
.y:             move.l  d5,d0                   ; line of the drawing
                lsr.l   #8,d0
                cmp.w   #7,d0
                bls.s   .y1
                moveq   #7,d0
.y1:            lsl.w   #4,d0
                lea     (a2,d0.w),a1
                move.l  a0,a3
                move.w  d4,d1
                move.w  d2,d0
.xl:            move.w  d1,d3
                lsr.w   #7,d3
                and.w   #$fffe,d3
                cmp.w   #14,d3
                bls.s   .x1
                moveq   #14,d3
.x1:            move.w  (a1,d3.w),(a3)+
                add.w   d6,d1
                dbra    d0,.xl
                lea     LINEB(a0),a0
                add.l   d7,d5
                subq.w  #1,(sp)
                bpl.s   .y
                addq.l  #2,sp
.x:             movem.l (sp)+,d0-d7/a0-a3
                rts

; rect_bb : filled rectangle d0,d1 - d2,d3 (inclusive), colour d7, screen a6,
;           clipped ; updates the bounding box (erasing)
rect_bb:
                movem.l d0-d6/a0-a2,-(sp)
                tst.w   d0
                bpl.s   .1
                moveq   #0,d0
.1:             cmp.w   clip_y0,d1
                bge.s   .2
                move.w  clip_y0,d1
.2:             cmp.w   #SCR_W-1,d2
                ble.s   .3
                move.w  #SCR_W-1,d2
.3:             cmp.w   clip_y1,d3
                ble.s   .4
                move.w  clip_y1,d3
.4:             cmp.w   d2,d0
                bgt.s   .x
                cmp.w   d3,d1
                bgt.s   .x
                cmp.w   bb_x0,d0
                bge.s   .b1
                move.w  d0,bb_x0
.b1:            cmp.w   bb_y0,d1
                bge.s   .b2
                move.w  d1,bb_y0
.b2:            cmp.w   bb_x1,d2
                ble.s   .b3
                move.w  d2,bb_x1
.b3:            cmp.w   bb_y1,d3
                ble.s   .b4
                move.w  d3,bb_y1
.b4:            jsr     bvx_add                 ; (back view : to erase)
                sub.w   d0,d2
                sub.w   d1,d3
                mulu    #LINEB,d1
                lea     (a6,d1.l),a0
                add.w   d0,d0
                adda.w  d0,a0
                move.w  d7,d6                   ; colour on 2 pixels
                swap    d6
                move.w  d7,d6
.y:             move.l  a0,a2
                move.w  d2,d1
                addq.w  #1,d1
                bsr     span_fill
                lea     LINEB(a0),a0
                dbra    d3,.y
.x:             movem.l (sp)+,d0-d6/a0-a2
.xx:            rts


;---------------------------------------------------------------------
; a0 -> 4 3D points (X,Y,Z), d7 = colour, a6 = screen
; projection : xe = CX + X*FOC/Z , ye = CY + Y*FOC/Z
draw_quad3d:
                movem.l d0-d6/a0-a2,-(sp)
                lea     quad2d,a1
                moveq   #3,d6
.p:             move.w  (a0)+,d0
                move.w  (a0)+,d1
                move.w  (a0)+,d2
                muls    #FOC,d0
                divs    d2,d0
                add.w   #CX,d0
                muls    #FOC,d1
                divs    d2,d1
                add.w   #CY,d1
                move.w  d0,(a1)+
                move.w  d1,(a1)+
                dbra    d6,.p
                lea     quad2d,a0
                bsr     fill_quad
                movem.l (sp)+,d0-d6/a0-a2
                rts

;---------------------------------------------------------------------
; Filled convex quad, clipped to 320x240
; a0 -> 4 2D points (x,y), d7 = colour, a6 = screen
; updates the bounding box bb_x0..bb_y1 (for erasing)
fill_quad:
                movem.l d0-d7/a0-a5,-(sp)
                move.l  a0,a5
                move.w  (a5),d0                 ; completely left or
                move.w  d0,d1                   ;  right of the screen : nothing
                move.w  4(a5),d2
                cmp.w   d0,d2
                bge.s   .q1
                move.w  d2,d0
.q1:            cmp.w   d1,d2
                ble.s   .q2
                move.w  d2,d1
.q2:            move.w  8(a5),d2
                cmp.w   d0,d2
                bge.s   .q3
                move.w  d2,d0
.q3:            cmp.w   d1,d2
                ble.s   .q4
                move.w  d2,d1
.q4:            move.w  12(a5),d2
                cmp.w   d0,d2
                bge.s   .q5
                move.w  d2,d0
.q5:            cmp.w   d1,d2
                ble.s   .q6
                move.w  d2,d1
.q6:            cmp.w   #SCR_W-1,d0
                bgt     .done
                tst.w   d1
                bmi     .done
                move.w  2(a5),d4                ; miny
                move.w  d4,d5                   ; maxy
                lea     6(a5),a0
                moveq   #2,d6
.mm:            move.w  (a0),d0
                cmp.w   d4,d0
                bge.s   .n1
                move.w  d0,d4
.n1:            cmp.w   d5,d0
                ble.s   .n2
                move.w  d0,d5
.n2:            addq.l  #4,a0
                dbra    d6,.mm
                cmp.w   clip_y0,d4
                bge.s   .c1
                move.w  clip_y0,d4
.c1:            cmp.w   clip_y1,d5
                ble.s   .c2
                move.w  clip_y1,d5
.c2:            cmp.w   d5,d4
                bgt     .done
                move.w  d4,fq_miny
                move.w  d5,fq_maxy
                lea     xl_tab,a1
                lea     xr_tab,a2
                move.w  d4,d0
                add.w   d0,d0
                lea     (a1,d0.w),a3
                lea     (a2,d0.w),a4
                move.w  d5,d1
                sub.w   d4,d1
.it:            move.w  #32767,(a3)+
                move.w  #-32768,(a4)+
                dbra    d1,.it
                moveq   #3,d6                   ; 4 edges
                move.l  a5,a0
.ed:            move.w  (a0),d0
                move.w  2(a0),d1
                lea     4(a0),a3
                tst.w   d6
                bne.s   .nx
                move.l  a5,a3
.nx:            move.w  (a3),d2
                move.w  2(a3),d3
                bsr     scan_edge
                addq.l  #4,a0
                dbra    d6,.ed
                ; filling of the lines
                move.w  d7,d6                   ; d6 = colour on 2 pixels
                swap    d6
                move.w  d7,d6
                move.w  d4,d0
                add.w   d0,d0
                lea     (a1,d0.w),a3
                lea     (a2,d0.w),a4
                move.w  d4,d1
                mulu    #LINEB,d1
                lea     (a6,d1.l),a0
                move.w  #32767,d2               ; d2/d3 : min / max x drawn
                move.w  #-32768,d3
.sp:            move.w  (a3)+,d0
                move.w  (a4)+,d1
                tst.w   d0
                bge.s   .k1
                moveq   #0,d0
.k1:            cmp.w   #SCR_W-1,d1
                ble.s   .k2
                move.w  #SCR_W-1,d1
.k2:            cmp.w   d1,d0
                bgt.s   .nl
                cmp.w   d2,d0
                bge.s   .m1
                move.w  d0,d2
.m1:            cmp.w   d3,d1
                ble.s   .m2
                move.w  d1,d3
.m2:            sub.w   d0,d1
                addq.w  #1,d1                   ; d1 = pixels
                add.w   d0,d0
                lea     (a0,d0.w),a2
                move.w  a2,d0                   ; (written as long words)
                btst    #1,d0
                beq.s   .al
                move.w  d6,(a2)+
                subq.w  #1,d1
                beq.s   .nl
.al:            move.w  d1,d0
                lsr.w   #3,d0
                beq.s   .r
                subq.w  #1,d0
.p8:            move.l  d6,(a2)+
                move.l  d6,(a2)+
                move.l  d6,(a2)+
                move.l  d6,(a2)+
                dbra    d0,.p8
.r:             move.w  d1,d0
                and.w   #7,d0
                lsr.w   #1,d0
                beq.s   .r1
                subq.w  #1,d0
.p2:            move.l  d6,(a2)+
                dbra    d0,.p2
.r1:            btst    #0,d1
                beq.s   .nl
                move.w  d6,(a2)+
.nl:            lea     LINEB(a0),a0
                addq.w  #1,d4
                cmp.w   d5,d4
                ble     .sp
                cmp.w   d3,d2                   ; bounding box (erasing) :
                bgt.s   .done                   ;  once per quad
                cmp.w   bb_x0,d2
                bge.s   .b1
                move.w  d2,bb_x0
.b1:            cmp.w   bb_x1,d3
                ble.s   .b2
                move.w  d3,bb_x1
.b2:            move.w  fq_miny,d0
                cmp.w   bb_y0,d0
                bge.s   .b3
                move.w  d0,bb_y0
.b3:            move.w  fq_maxy,d0
                cmp.w   bb_y1,d0
                ble.s   .b4
                move.w  d0,bb_y1
.b4:            tst.w   bvx_on                  ; (back view : to erase)
                beq.s   .done
                move.w  d2,d0
                move.w  fq_miny,d1
                move.w  d3,d2
                move.w  fq_maxy,d3
                jsr     bvx_add
.done:          movem.l (sp)+,d0-d7/a0-a5
                rts

; span_fill : a2 -> 1st pixel, d1 = number of pixels (>0), d6 = colour
;   doubled (2 pixels) ; writes long words (d0, d1, a2 destroyed)
span_fill:
                move.w  a2,d0
                btst    #1,d0                   ; address aligned on 4 ?
                beq.s   .al
                move.w  d6,(a2)+
                subq.w  #1,d1
                beq.s   .x
.al:            move.w  d1,d0
                lsr.w   #3,d0                   ; packs of 8 pixels
                beq.s   .r
                subq.w  #1,d0
.p8:            move.l  d6,(a2)+
                move.l  d6,(a2)+
                move.l  d6,(a2)+
                move.l  d6,(a2)+
                dbra    d0,.p8
.r:             move.w  d1,d0
                and.w   #7,d0
                lsr.w   #1,d0
                beq.s   .r1
                subq.w  #1,d0
.p2:            move.l  d6,(a2)+
                dbra    d0,.p2
.r1:            btst    #0,d1
                beq.s   .x
                move.w  d6,(a2)+
.x:             rts

; edge (d0,d1)-(d2,d3) -> update of the xl/xr tables (a1/a2)
scan_edge:
                movem.l d0-d7/a3-a4,-(sp)
                cmp.w   d1,d3
                bge.s   .ok
                exg     d0,d2
                exg     d1,d3
.ok:            bne.s   .slope
                cmp.w   fq_miny,d1              ; horizontal edge
                blt     .ret
                cmp.w   fq_maxy,d1
                bgt.s   .ret
                bsr.s   .upd
                move.w  d2,d0
                bsr.s   .upd
                bra.s   .ret
.slope:         move.w  d2,d4
                sub.w   d0,d4                   ; dx
                move.w  d3,d5
                sub.w   d1,d5                   ; dy > 0
                ext.l   d4                      ; slope in 16.16 fixed point
                swap    d4                      ;  (one division per edge,
                clr.w   d4                      ;   plus one per line)
                ext.l   d5
                divs.l  d5,d4
                move.w  fq_miny,d2
                cmp.w   d1,d2
                bge.s   .s1
                move.w  d1,d2                   ; start y
.s1:            cmp.w   fq_maxy,d3
                ble.s   .s2
                move.w  fq_maxy,d3              ; end y
.s2:            cmp.w   d3,d2
                bgt.s   .ret
                move.w  d2,d6                   ; x at the start (16.16)
                sub.w   d1,d6
                ext.l   d6
                muls.l  d4,d6
                move.w  d0,d7
                swap    d7
                clr.w   d7
                add.l   d7,d6
                add.l   #$8000,d6               ; (rounding)
                move.w  d2,d7
                add.w   d7,d7
                lea     (a1,d7.w),a3
                lea     (a2,d7.w),a4
                sub.w   d2,d3                   ; lines - 1
.yl:            move.l  d6,d7
                swap    d7
                cmp.w   (a3),d7
                bge.s   .y1
                move.w  d7,(a3)
.y1:            cmp.w   (a4),d7
                ble.s   .y2
                move.w  d7,(a4)
.y2:            addq.l  #2,a3
                addq.l  #2,a4
                add.l   d4,d6
                dbra    d3,.yl
.ret:           movem.l (sp)+,d0-d7/a3-a4
                rts
.upd:           move.w  d1,d5
                add.w   d5,d5
                cmp.w   (a1,d5.w),d0
                bge.s   .u1
                move.w  d0,(a1,d5.w)
.u1:            cmp.w   (a2,d5.w),d0
                ble.s   .u2
                move.w  d0,(a2,d5.w)
.u2:            rts
