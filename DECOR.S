;=====================================================================
; DECOR.S - SCENERY : building of the current screen (walls, blocks, fixed objects)
;   (included by RICK3D.S ; the settings are in PARAMS.S)
;=====================================================================

;---------------------------------------------------------------------
; Building of the scenery of the current screen in bgbuf (once per screen)
;  1. back wall (tile by tile, at ZB)
;  2. side faces of the blocks (from the outside towards the centre)
;  3. front faces of the blocks : 10x10 patterns
;  4. platforms, bars, girders, ladders (3D boxes)
build_screen:
                movem.l d0-d7/a0-a6,-(sp)
                jsr     bld_begin               ; (sound goes on, see ZIGZAG.S)
                lea     bgbuf,a6
                tst.w   view_back               ; back view (V key)
                beq.s   .side
                bsr     build_back
                bra     .done
.side:          jsr     bg_take                 ; built in the background (BGBUILD) ?
                bne.s   .full                   ;  yes : scenery + front faces
                bsr     draw_items_nc           ;  ready ; canisters (bg_noitp =
                jsr     bg_canfront             ;  the scenery without them), front
                bra.s   .done                   ;  faces again over them
.full:          tst.w   pre_on                  ; (buffer of a screen built at the
                beq.s   .f0                     ;  loading : not to be overwritten)
                move.l  #bg_noit,bg_noitp
.f0:            jsr     bg_curmap               ; (tiles of this screen : bg_dirty)
                bsr     bld_head
                bsr     draw_items
                moveq   #0,d0                   ; --- 5. front faces of the blocks
                moveq   #0,d1                   ;  (patterns) LAST : the front plane
                moveq   #SCR_TW-1,d2            ;  hides what is behind (walkways,
                moveq   #SCR_TH-1,d3            ;  bars...)
                bsr     bld_front


.done:          ; the 2 screens must get the whole scenery : it is done
                ; when drawing in each of them (never in the screen being
                ; shown -> no scenery built "in sight")
                move.w  #1,rlist0+L_FULL
                move.w  #1,rlist1+L_FULL
                clr.w   txts0                   ; text to redraw
                clr.w   txts1
                clr.w   huds0
                clr.w   huds1
                clr.w   need_rebuild
                jsr     bld_end
                movem.l (sp)+,d0-d7/a0-a6
                rts

;---------------------------------------------------------------------
; bld_front : front faces of the blocks (patterns) of the tiles d0..d2 /
;   d1..d3 of the screen, in a6
bld_front:
                movem.l d0-d7/a0,-(sp)
                move.w  d0,d4                   ; d4 = first column
                move.w  d2,d5                   ; d5 = last column
                move.w  d3,d6                   ; d6 = last row
.p5:            move.w  d4,d0
.p5c:           bsr     scell
                bsr     isblk
                bne.s   .p5n
                lea     pat_rock,a0
                cmp.b   #'g',d2
                bne.s   .p5g
                lea     pat_grass,a0
.p5g:           cmp.b   #'F',d2
                bne.s   .p5p
                lea     pat_frame,a0
.p5p:           cmp.b   #'B',d2
                bne.s   .p5b
                lea     pat_plate,a0
.p5b:           bsr     blit10
.p5n:           BGCHK
                addq.w  #1,d0
                cmp.w   d5,d0
                ble.s   .p5c
                addq.w  #1,d1
                cmp.w   d6,d1
                ble.s   .p5
                movem.l (sp)+,d0-d7/a0
                rts

;---------------------------------------------------------------------
; bld_head : scenery of the screen win_tx / win_ty in a6 (bgbuf, or bgnext
;   for the background build), everything before the canisters and the
;   front faces (bld_tail of build_screen). BGCHK : the background build
;   gives the hand back to the game when its time per frame is used.
bld_head:
                move.l  a6,a0                   ; black background
                move.w  #SCRSZ/16-1,d0
                moveq   #0,d1
.cl:            move.l  d1,(a0)+
                move.l  d1,(a0)+
                move.l  d1,(a0)+
                move.l  d1,(a0)+
                move.w  d0,d2                   ; (background build : every
                and.w   #127,d2                 ;  8 KB, see BGCHK)
                bne.s   .cl0
                BGCHK
.cl0:           dbra    d0,.cl

                ; --- 1. back wall
                moveq   #0,d1
.by:            moveq   #0,d0
.bx:            bsr     scell
                cmp.b   #'k',d2                 ; black background : nothing
                beq.s   .bn
                cmp.b   #'x',d2                 ; park pylon : on black background
                beq.s   .bn
                bsr     isblk
                beq.s   .bn
                move.w  c_wall1,d7
                move.w  d0,d3
                eor.w   d1,d3
                btst    #0,d3
                beq.s   .bc
                move.w  c_wall2,d7
.bc:            movem.w d0-d1,-(sp)
                move.w  d0,d2                   ; X0, X1 at ZB
                lsl.w   #3,d0
                sub.w   #OX,d0
                move.w  d0,d2
                addq.w  #TILE,d2
                move.w  d1,d3
                lsl.w   #3,d1
                sub.w   #OY,d1
                move.w  d1,d3
                addq.w  #TILE,d3
                bsr     projb
                exg     d0,d1
                exg     d2,d3
                bsr     projb
                exg     d0,d1
                exg     d2,d3
                add.w   #CX,d0
                add.w   #CX-1,d2
                add.w   #CY,d1
                add.w   #CY-1,d3
                bsr     rectf
                movem.w (sp)+,d0-d1
.bn:
                BGCHK
                addq.w  #1,d0
                cmp.w   #SCR_TW,d0
                blt     .bx
                addq.w  #1,d1
                cmp.w   #SCR_TH,d1
                blt     .by

                ; --- 1b. portholes (N tiles) : in 3D, dug into the wall
                bsr     build_windows

                ; --- 2. right faces : blocks left of the centre
                moveq   #0,d0
.p1:            moveq   #0,d1
.p1r:           bsr     scell
                bsr     isblk
                bne.s   .p1n
                move.b  d2,d6
                bsr     bcol                    ; (plate : frame colours)
                addq.w  #1,d0
                bsr     scell
                subq.w  #1,d0
                bsr     isblk
                beq.s   .p1n
                move.w  d0,d3
                addq.w  #1,d3
                lsl.w   #3,d3
                sub.w   #OX,d3
                move.w  c_rkside,d7
                cmp.b   #'g',d6
                bne.s   .p1cf
                move.w  c_grside,d7
.p1cf:            cmp.b   #'F',d6
                bne.s   .p1c
                move.w  c_frside,d7
.p1c:           bsr     vface
.p1n:
                BGCHK
                addq.w  #1,d1
                cmp.w   #SCR_TH,d1
                blt.s   .p1r
                addq.w  #1,d0
                cmp.w   #SCR_TW/2-1,d0
                ble.s   .p1

                ; left faces : blocks right of the centre
                moveq   #SCR_TW-1,d0
.p2:            moveq   #0,d1
.p2r:           bsr     scell
                bsr     isblk
                bne.s   .p2n
                move.b  d2,d6
                bsr     bcol                    ; (plate : frame colours)
                subq.w  #1,d0
                bsr     scell
                addq.w  #1,d0
                bsr     isblk
                beq.s   .p2n
                move.w  d0,d3
                lsl.w   #3,d3
                sub.w   #OX,d3
                move.w  c_rkside,d7
                cmp.b   #'g',d6
                bne.s   .p2cf
                move.w  c_grside,d7
.p2cf:            cmp.b   #'F',d6
                bne.s   .p2c
                move.w  c_frside,d7
.p2c:           bsr     vface
.p2n:
                BGCHK
                addq.w  #1,d1
                cmp.w   #SCR_TH,d1
                blt.s   .p2r
                subq.w  #1,d0
                cmp.w   #SCR_TW/2,d0
                bge.s   .p2

                ; bottom faces : blocks above the centre
                moveq   #0,d1
.p3:            moveq   #0,d0
.p3c:           bsr     scell
                bsr     isblk
                bne.s   .p3n
                move.b  d2,d6
                bsr     bcol                    ; (plate : frame colours)
                addq.w  #1,d1
                bsr     scell
                subq.w  #1,d1
                bsr     isblk
                beq.s   .p3n
                move.w  d1,d3
                addq.w  #1,d3
                lsl.w   #3,d3
                sub.w   #OY,d3
                move.w  c_rkbot,d7
                cmp.b   #'g',d6
                bne.s   .p3kf
                move.w  c_grbot,d7
.p3kf:            cmp.b   #'F',d6
                bne.s   .p3k
                move.w  c_frbot,d7
.p3k:           bsr     hface
.p3n:
                BGCHK
                addq.w  #1,d0
                cmp.w   #SCR_TW,d0
                blt.s   .p3c
                addq.w  #1,d1
                cmp.w   #SCR_TH/2-1,d1
                ble.s   .p3

                ; top faces : blocks below the centre
                moveq   #SCR_TH-1,d1
.p4:            moveq   #0,d0
.p4c:           bsr     scell
                bsr     isblk
                bne.s   .p4n
                move.b  d2,d6
                bsr     bcol                    ; (plate : frame colours)
                subq.w  #1,d1
                bsr     scell
                addq.w  #1,d1
                bsr     isblk
                beq.s   .p4n
                move.w  d1,d3
                lsl.w   #3,d3
                sub.w   #OY,d3
                move.w  c_rktop,d7
                cmp.b   #'g',d6
                bne.s   .p4kf
                move.w  c_grtop,d7
.p4kf:            cmp.b   #'F',d6
                bne.s   .p4k
                move.w  c_frtop,d7
.p4k:           bsr     hface
.p4n:
                BGCHK
                addq.w  #1,d0
                cmp.w   #SCR_TW,d0
                blt.s   .p4c
                subq.w  #1,d1
                cmp.w   #SCR_TH/2,d1
                bge.s   .p4

                ; --- 4. objects
                bsr     build_pipes             ; grey pipes (middle of the depth)
                bsr     build_objects
                bsr     draw_switches
                bsr     draw_nozzles
                bsr     draw_zapemit
                rts

;---------------------------------------------------------------------
; PORTHOLES (N tiles) IN 3D
;   A rectangle of N tiles = a porthole, built in real 3D after the
;   back wall :
;   - a tunnel dug into the wall (wn_dep units further than the wall),
;     its 4 steel sides lit from above, and at the end black
;     space and its stars (placed at random, always the same ones) ;
;   - two reflections on the glass ;
;   - a copper frame in relief (wn_ft thick) with a brass lip
;     sticking out more around the glass, and rivets.
;   The perspective shows the sides of the tunnel and of the frame
;   differently depending on where the porthole is on the screen.
;   Colours and settings (widths, reliefs, depth, stars, rivets,
;   reflections) : wc_* and wn_ft.. in the tile set (DONNEES.S), can be changed
;   with the editor (Tile look tab, Porthole) -> TILES.DAT v7.

; build_windows : looks in the screen for the 1st visible cell of each
;   porthole (on the left and above : not N, or edge of the screen)
build_windows:
                movem.l d0-d2,-(sp)
                moveq   #0,d1
.y:             moveq   #0,d0
.x:             bsr     scell
                cmp.b   #'N',d2
                bne.s   .n
                tst.w   d0
                beq.s   .l0
                subq.w  #1,d0
                bsr     scell
                addq.w  #1,d0
                cmp.b   #'N',d2
                beq.s   .n
.l0:            tst.w   d1
                beq.s   .u0
                subq.w  #1,d1
                bsr     scell
                addq.w  #1,d1
                cmp.b   #'N',d2
                beq.s   .n
.u0:            bsr     win_draw
.n:             addq.w  #1,d0
                cmp.w   #SCR_TW,d0
                blt.s   .x
                addq.w  #1,d1
                cmp.w   #SCR_TH,d1
                blt.s   .y
                movem.l (sp)+,d0-d2
                rts

; win_draw : draws the porthole that holds the cell d0 / d1 of the screen
win_draw:
                movem.l d0-d7/a0-a2,-(sp)
                add.w   win_tx,d0               ; -> cell of the level
                add.w   win_ty,d1
.l:             subq.w  #1,d0                   ; top-left corner of the porthole
                bsr     wis
                beq.s   .l
                addq.w  #1,d0
.u:             subq.w  #1,d1
                bsr     wis
                beq.s   .u
                addq.w  #1,d1
                move.w  d0,d4                   ; d4, d5 = corner (level)
                move.w  d1,d5
.w:             addq.w  #1,d0                   ; width
                bsr     wis
                beq.s   .w
                sub.w   d4,d0
                lsl.w   #3,d0
                move.w  d0,d6
                move.w  d4,d0
.h:             addq.w  #1,d1                   ; height
                bsr     wis
                beq.s   .h
                sub.w   d5,d1
                lsl.w   #3,d1
                move.w  d4,d2                   ; -> world coordinates
                sub.w   win_tx,d2
                lsl.w   #3,d2
                sub.w   #OX,d2
                move.w  d2,wn_x0
                add.w   d6,d2
                move.w  d2,wn_x1
                move.w  d5,d2
                sub.w   win_ty,d2
                lsl.w   #3,d2
                sub.w   #OY,d2
                move.w  d2,wn_y0
                add.w   d1,d2
                move.w  d2,wn_y1
                mulu    #131,d4                 ; seed of the stars
                mulu    #71,d5
                add.w   d5,d4
                move.w  d4,wn_seed
                move.w  wn_dep,d0               ; back plane
                bgt.s   .z1
                moveq   #1,d0
.z1:            add.w   #ZB,d0
                move.w  d0,wn_zd
                movem.w wn_x0,d0-d3             ; glass = inside of the frame
                add.w   wn_ft,d0
                add.w   wn_ft,d1
                sub.w   wn_ft,d2
                sub.w   wn_ft,d3
                movem.w d0-d3,wn_hx0
                sub.w   d0,d2
                move.w  d2,wn_hw
                sub.w   d1,d3
                move.w  d3,wn_hh

                ; --- the background : space
                movem.w wn_hx0,d0-d3
                bsr     wn_proj
                subq.w  #1,d2
                subq.w  #1,d3
                move.w  wc_space,d7
                bsr     rectf
                ; --- the stars (one per wn_dens square units)
                tst.w   wn_dens
                ble     .ns
                move.w  wn_hw,d5
                mulu    wn_hh,d5
                divu    wn_dens,d5
                subq.w  #1,d5
                bmi     .ns
                moveq   #0,d6
                move.w  wn_seed,d6
.st:            bsr     wn_rnd
                divu    wn_hw,d0
                swap    d0
                add.w   wn_hx0,d0
                move.w  d0,d4
                bsr     wn_rnd
                divu    wn_hh,d0
                swap    d0
                add.w   wn_hy0,d0
                move.w  d0,d1
                move.w  d4,d0
                move.w  d0,d2
                move.w  d1,d3
                bsr     wn_proj
                move.w  d0,d2
                move.w  d1,d3
                move.w  d0,d4
                bsr     wn_rnd                  ; brightness : 2 out of 4 pale
                rol.w   #3,d0
                and.w   #3,d0
                lea     wc_star,a0
                move.w  (a0,d0.w*2),d7
                cmp.w   #3,d0                   ; the brightest : 2x1
                bne.s   .s1
                addq.w  #1,d2
.s1:            move.w  d4,d0
                bsr     rectf
                dbra    d5,.st
.ns:
                ; --- the sides of the tunnel (only the ones that can be seen)
                movem.w wn_hx0,d0-d3
                move.w  #ZB,d4
                move.w  wn_zd,d5
                tst.w   d0                      ; left side : facing right
                bge.s   .nl
                lea     q3d,a0
                PT      d0,d1,d4
                PT      d0,d1,d5
                PT      d0,d3,d5
                PT      d0,d3,d4
                lea     q3d,a0
                move.w  wc_tun,d7
                bsr     draw_quad3d
.nl:            tst.w   d2                      ; right side
                ble.s   .nr
                lea     q3d,a0
                PT      d2,d1,d4
                PT      d2,d1,d5
                PT      d2,d3,d5
                PT      d2,d3,d4
                lea     q3d,a0
                move.w  wc_tun+2,d7
                bsr     draw_quad3d
.nr:            tst.w   d1                      ; ceiling (in the shade)
                bge.s   .nt
                lea     q3d,a0
                PT      d0,d1,d4
                PT      d2,d1,d4
                PT      d2,d1,d5
                PT      d0,d1,d5
                lea     q3d,a0
                move.w  wc_tun+4,d7
                bsr     draw_quad3d
.nt:            tst.w   d3                      ; floor (lit)
                ble.s   .nb
                lea     q3d,a0
                PT      d0,d3,d4
                PT      d2,d3,d4
                PT      d2,d3,d5
                PT      d0,d3,d5
                lea     q3d,a0
                move.w  wc_tun+6,d7
                bsr     draw_quad3d
.nb:
                ; --- 2 slanted reflections on the glass (top-left corner)
                tst.w   wn_refl
                beq.s   .nrf
                move.w  wn_hw,d6                ; c = half of the smaller side
                cmp.w   wn_hh,d6
                ble.s   .c1
                move.w  wn_hh,d6
.c1:            lsr.w   #1,d6
                move.w  #ZB,d4
                moveq   #2,d5                   ; thickness
                move.w  wc_space+2,d7
                bsr     wn_streak
                addq.w  #5,d6
                moveq   #1,d5
                move.w  wc_space+4,d7
                bsr     wn_streak
.nrf:

                ; --- the copper frame (4 bars in relief)
                lea     wc_ring,a1
                move.w  #ZB,d4
                sub.w   wn_rz,d4
                move.w  #ZB,d5
                movem.w wn_x0,d0-d3             ; top
                move.w  d1,d3
                add.w   wn_ft,d3
                bsr     wn_box15
                movem.w wn_x0,d0-d3             ; bottom
                move.w  d3,d1
                sub.w   wn_ft,d1
                bsr     wn_box15
                movem.w wn_x0,d0-d3             ; left
                add.w   wn_ft,d1
                sub.w   wn_ft,d3
                move.w  d0,d2
                add.w   wn_ft,d2
                bsr     wn_box3
                movem.w wn_x0,d0-d3             ; right
                add.w   wn_ft,d1
                sub.w   wn_ft,d3
                move.w  d2,d0
                sub.w   wn_ft,d0
                bsr     wn_box3
                ; --- the brass lip around the glass
                lea     wc_lip,a1
                move.w  #ZB,d4
                sub.w   wn_lz,d4
                movem.w wn_hx0,d0-d3            ; top
                sub.w   wn_lip,d0
                add.w   wn_lip,d2
                move.w  d1,d3
                sub.w   wn_lip,d1
                bsr     wn_box15
                movem.w wn_hx0,d0-d3            ; bottom
                sub.w   wn_lip,d0
                add.w   wn_lip,d2
                move.w  d3,d1
                add.w   wn_lip,d3
                bsr     wn_box15
                movem.w wn_hx0,d0-d3            ; left
                move.w  d0,d2
                sub.w   wn_lip,d0
                bsr     wn_box3
                movem.w wn_hx0,d0-d3            ; right
                move.w  d2,d0
                add.w   wn_lip,d2
                bsr     wn_box3
                ; --- the rivets : in the middle of the visible part of the frame,
                ;     spread evenly (about every wn_rsp)
                tst.w   wn_rsp
                ble     .x
                move.w  wn_ft,d7
                sub.w   wn_lip,d7
                subq.w  #2,d7
                bmi     .x
                lsr.w   #1,d7
                move.w  d7,wn_ro                ; margin around a rivet
                lea     wc_rivet,a1
                move.w  #ZB-1,d4
                sub.w   wn_rz,d4
                move.w  d4,d5
                addq.w  #1,d5
                move.w  wn_x1,d6                ; top and bottom (corners included)
                sub.w   wn_x0,d6
                sub.w   d7,d6
                sub.w   d7,d6
                subq.w  #2,d6
                move.w  d6,wn_span
                bsr     wn_nint
                clr.w   wn_i
.rh:            move.w  wn_i,d0
                mulu    wn_span,d0
                divu    wn_n,d0
                add.w   wn_x0,d0
                add.w   wn_ro,d0
                move.w  d0,d2
                addq.w  #2,d2
                move.w  wn_y0,d1
                add.w   wn_ro,d1
                move.w  d1,d3
                addq.w  #2,d3
                bsr     wn_box15
                move.w  wn_y1,d3
                sub.w   wn_ro,d3
                move.w  d3,d1
                subq.w  #2,d1
                bsr     wn_box15
                addq.w  #1,wn_i
                move.w  wn_i,d0
                cmp.w   wn_n,d0
                bls.s   .rh
                move.w  wn_y1,d6                ; left and right (without the corners)
                sub.w   wn_y0,d6
                sub.w   wn_ro,d6
                sub.w   wn_ro,d6
                subq.w  #2,d6
                move.w  d6,wn_span
                bsr     wn_nint
                move.w  #1,wn_i
.rv:            move.w  wn_i,d0
                cmp.w   wn_n,d0
                bhs.s   .x
                mulu    wn_span,d0
                divu    wn_n,d0
                add.w   wn_y0,d0
                add.w   wn_ro,d0
                move.w  d0,d1
                move.w  d0,d3
                addq.w  #2,d3
                move.w  wn_x0,d0
                add.w   wn_ro,d0
                move.w  d0,d2
                addq.w  #2,d2
                bsr     wn_box15
                move.w  wn_x1,d2
                sub.w   wn_ro,d2
                move.w  d2,d0
                subq.w  #2,d0
                bsr     wn_box15
                addq.w  #1,wn_i
                bra.s   .rv
.x:             movem.l (sp)+,d0-d7/a0-a2
                rts

; wn_box15 / wn_box3 : box d0-d3, z d4-d5, colours a1 ; all the
;   faces / only left and right (against the neighbouring bars)
wn_box15:       move.w  #15,box_mask
                bra.s   wn_box
wn_box3:        move.w  #3,box_mask
wn_box:         clr.l   box_tex
                bsr     draw_box
                move.w  #15,box_mask
                rts

; wn_nint : wn_span (set to 0 if negative) -> wn_n = number
;   of intervals between the rivets = wn_span / wn_rsp rounded, at least 1
wn_nint:
                movem.l d0-d1,-(sp)
                moveq   #0,d0
                move.w  wn_span,d0
                bpl.s   .p
                moveq   #0,d0
                clr.w   wn_span
.p:             moveq   #0,d1
                move.w  wn_rsp,d1
                lsr.w   #1,d1
                add.l   d1,d0
                divu    wn_rsp,d0
                tst.w   d0
                bne.s   .n
                moveq   #1,d0
.n:             move.w  d0,wn_n
                movem.l (sp)+,d0-d1
                rts

; wn_proj : d0-d3 (x0 y0 x1 y1 world) -> screen, in the back plane
wn_proj:
                muls    #FOC,d0
                divs    wn_zd,d0
                add.w   #CX,d0
                muls    #FOC,d2
                divs    wn_zd,d2
                add.w   #CX,d2
                muls    #FOC,d1
                divs    wn_zd,d1
                add.w   #CY,d1
                muls    #FOC,d3
                divs    wn_zd,d3
                add.w   #CY,d3
                rts

; wn_rnd : random number -> d0.l (0..65535), state d6
wn_rnd:         mulu    #25173,d6
                add.l   #13849,d6
                moveq   #0,d0
                move.w  d6,d0
                ror.w   #7,d0
                and.l   #$ffff,d6
                rts

; wn_streak : reflection = slanted band between x + y = d6 and x + y = d6 + d5
;   (from the top-left corner of the glass), z = d4, colour d7
wn_streak:
                movem.l d0-d6/a0,-(sp)
                move.w  wn_hx0,d0
                move.w  wn_hy0,d1
                lea     q3d,a0
                move.w  d0,d2                   ; (x0 + 1, y0 + c - 1)
                addq.w  #1,d2
                move.w  d1,d3
                add.w   d6,d3
                subq.w  #1,d3
                PT      d2,d3,d4
                move.w  d0,d2                   ; (x0 + c - 1, y0 + 1)
                add.w   d6,d2
                subq.w  #1,d2
                move.w  d1,d3
                addq.w  #1,d3
                PT      d2,d3,d4
                add.w   d5,d2                   ; (x0 + c + e - 1, y0 + 1)
                PT      d2,d3,d4
                move.w  d0,d2                   ; (x0 + 1, y0 + c + e - 1)
                addq.w  #1,d2
                move.w  d1,d3
                add.w   d6,d3
                add.w   d5,d3
                subq.w  #1,d3
                PT      d2,d3,d4
                lea     q3d,a0
                bsr     draw_quad3d
                movem.l (sp)+,d0-d6/a0
                rts

; wis : d0 = column, d1 = line (level) -> Z = 1 if porthole (N)
wis:            movem.l d0-d2,-(sp)
                bsr     tile_at
                cmp.b   #'N',d2
                movem.l (sp)+,d0-d2             ; (movem does not touch Z)
                rts

; projb : d0, d2 (world coordinates) -> projected at ZB (without centre)
projb:
                muls    #FOC,d0
                divs    #ZB,d0
                muls    #FOC,d2
                divs    #ZB,d2
                rts

; rectf : filled rectangle d0,d1 - d2,d3, colour d7, screen a6, clipped
rectf:
                BGCHK                           ; (background build : pause ?)
                movem.l d0-d4/a0-a1,-(sp)
                tst.w   d0
                bpl.s   .1
                moveq   #0,d0
.1:             tst.w   d1
                bpl.s   .2
                moveq   #0,d1
.2:             cmp.w   #SCR_W-1,d2
                ble.s   .3
                move.w  #SCR_W-1,d2
.3:             cmp.w   #SCR_H-1,d3
                ble.s   .4
                move.w  #SCR_H-1,d3
.4:             sub.w   d0,d2
                bmi.s   .x
                sub.w   d1,d3
                bmi.s   .x
                mulu    #LINEB,d1
                lea     (a6,d1.l),a0
                add.w   d0,d0
                adda.w  d0,a0
                move.w  d7,d0                   ; colour on 2 pixels (long words)
                swap    d0
                move.w  d7,d0
.y:             move.l  a0,a1
                move.w  d2,d4
                addq.w  #1,d4                   ; d4 = pixels
                move.l  a1,d1
                btst    #1,d1                   ; long words aligned
                beq.s   .al
                move.w  d0,(a1)+
                subq.w  #1,d4
.al:            move.w  d4,d1
                lsr.w   #1,d1
                bra.s   .l1
.xl:            move.l  d0,(a1)+
.l1:            dbra    d1,.xl
                btst    #0,d4
                beq.s   .nl
                move.w  d0,(a1)+
.nl:            lea     LINEB(a0),a0
                move.w  d3,d1                   ; (background build : every
                and.w   #15,d1                  ;  16 lines, see BGCHK)
                bne.s   .nc
                BGCHK
.nc:            dbra    d3,.y
.x:             movem.l (sp)+,d0-d4/a0-a1
                rts

; blit10 : 10x10 pattern (a0) at column d0 / line d1 of the screen a6
blit10:
                movem.l d0-d2/a0-a1,-(sp)
                mulu    #TPX*LINEB,d1
                lea     (a6,d1.l),a1
                mulu    #TPX*2,d0
                adda.l  d0,a1
                moveq   #TPX-1,d2
.y:             move.l  (a0)+,(a1)+
                move.l  (a0)+,(a1)+
                move.l  (a0)+,(a1)+
                move.l  (a0)+,(a1)+
                move.l  (a0)+,(a1)+
                lea     LINEB-TPX*2(a1),a1
                dbra    d2,.y
                movem.l (sp)+,d0-d2/a0-a1
                rts

; vertical face of a block : d3 = X, d1 = screen line, d7 = colour
vface:
                movem.l d4-d5/a0,-(sp)
                move.w  d1,d4
                lsl.w   #3,d4
                sub.w   #OY,d4
                move.w  d4,d5
                addq.w  #TILE,d5
                lea     q3d,a0
                PT      d3,d4,#ZF
                PT      d3,d4,#ZB
                PT      d3,d5,#ZB
                PT      d3,d5,#ZF
                lea     q3d,a0
                bsr     draw_quad3d
                movem.l (sp)+,d4-d5/a0
                rts

; horizontal face of a block : d0 = screen column, d3 = Y, d7 = colour
hface:
                movem.l d4-d5/a0,-(sp)
                move.w  d0,d4
                lsl.w   #3,d4
                sub.w   #OX,d4
                move.w  d4,d5
                addq.w  #TILE,d5
                lea     q3d,a0
                PT      d4,d3,#ZF
                PT      d5,d3,#ZF
                PT      d5,d3,#ZB
                PT      d4,d3,#ZB
                lea     q3d,a0
                bsr     draw_quad3d
                movem.l (sp)+,d4-d5/a0
                rts

; build_objects : platforms (by continuous rows), bars, girders,
;                 ladders (rungs + continuous uprights)
build_objects:
                bsr     build_pylons            ; lattice pylons (at the back)
                bsr     build_posts             ; green posts (at the back)
                moveq   #0,d1
.row:           moveq   #0,d0
.col:           bsr     scell
                cmp.b   #'=',d2
                beq     .run
                cmp.b   #'-',d2
                beq     .run
                cmp.b   #'G',d2
                beq     .gird
                cmp.b   #'U',d2                 ; climbing pipe : drawn as a pipe
                beq     .next
                bsr     isladc                  ; ladders : 2nd pass (in front)
                bne.s   .nl1
                bsr     .ladb                   ; ...except the bottom of a ladder
                bne     .next                   ;  standing on a walkway / bar :
                bsr     scell                   ;  drawn now, BEHIND the walkway
                bsr     .lad
                bra     .next
.nl1:
                cmp.b   #'T',d2
                beq     .barrel
                cmp.b   #'O',d2
                beq     .stool
                cmp.b   #'o',d2                 ; scenery stool (can be passed under)
                beq     .stool
                cmp.b   #'V',d2
                beq     .screw
                cmp.b   #'Q',d2
                beq     .screw
.next:          addq.w  #1,d0
                cmp.w   #SCR_TW,d0
                blt.s   .col
                addq.w  #1,d1
                cmp.w   #SCR_TH,d1
                blt.s   .row
                ; --- 2nd pass : ladders and poles, always IN FRONT of the
                ;     walkways, bars and girders (like in the original)
                moveq   #0,d1
.lrow:          moveq   #0,d0
.lcol:          bsr     scell
                cmp.b   #'U',d2
                beq.s   .lnx
                bsr     isladc
                bne.s   .lnx
                bsr     .ladb                   ; (already drawn in the 1st pass)
                beq.s   .lnx
                bsr     scell
                bsr     .lad
.lnx:           addq.w  #1,d0
                cmp.w   #SCR_TW,d0
                blt.s   .lcol
                addq.w  #1,d1
                cmp.w   #SCR_TH,d1
                blt.s   .lrow
                rts                             ; (uprights : in the model)
                ; --- walkway / bar : one box per continuous run
.run:           move.b  d2,d6
                cmp.b   #'=',d6                 ; walkway : top row
                bne.s   .r0
                subq.w  #1,d1
                bsr     scell
                addq.w  #1,d1
                cmp.b   #'=',d2
                beq.s   .next
.r0:            move.w  d0,d5                   ; start
.r1:            addq.w  #1,d0
                cmp.w   #SCR_TW,d0
                bge.s   .r2
                bsr     scell
                cmp.b   d6,d2
                beq.s   .r1
.r2:            movem.w d0-d1,-(sp)             ; one tile after the other (model)
                move.w  d0,d4                   ; d4 = end (excluded), d5 = start
                lea     mdl_walkway,a2
                cmp.b   #'=',d6
                beq.s   .rb0
                lea     mdl_bar,a2
.rb0:           move.w  d5,d0
.rb1:           move.w  d0,d6
                lsl.w   #3,d6
                sub.w   #OX,d6
                move.w  d1,d7
                lsl.w   #3,d7
                sub.w   #OY,d7
                move.w  #$300,d3                ; left + right neighbours...
                cmp.w   d5,d0
                bne.s   .rb2
                and.w   #$200,d3                ;  ...except at the start
.rb2:           move.w  d0,d2
                addq.w  #1,d2
                cmp.w   d4,d2
                blt.s   .rb3
                and.w   #$100,d3                ;  ...and at the end
.rb3:           movem.w d4-d5,-(sp)
                move.w  d3,d5
                bsr     draw_model
                movem.w (sp)+,d4-d5
                addq.w  #1,d0
                cmp.w   d4,d0
                blt.s   .rb1
                movem.w (sp)+,d0-d1
                subq.w  #1,d0
                bra     .next
                ; --- green girder : riveted horizontal beam
.gird:          bsr     gird_beam
                bra     .next
                ; --- ladder : rung
.ladb:          addq.w  #1,d1                   ; Z = 1 : walkway / bar just below
                bsr     scell
                subq.w  #1,d1
                cmp.b   #'=',d2
                beq.s   .lb
                cmp.b   #'-',d2
.lb:            rts
.lad:           movem.w d0-d1,-(sp)             ; rung + uprights (model)
                lea     mdl_ladder,a2
                cmp.b   #'M',d2
                bne.s   .ldc
                lea     mdl_mast,a2
.ldc:           lea     p_lad,a0
                bsr     nbmask
                move.w  d4,d5
                lsl.w   #8,d5
                move.w  d0,d6
                lsl.w   #3,d6
                sub.w   #OX,d6
                move.w  d1,d7
                lsl.w   #3,d7
                sub.w   #OY,d7
                bsr     draw_model
                movem.w (sp)+,d0-d1
                rts
                ; --- barrel : 2 x 2 tiles, top-left corner at (even, even)
                ; --- lift screw (V vertical 2 wide, Q horizontal)
.screw:         movem.w d0-d1,-(sp)             ; lift screw (model)
                lea     mdl_screwV,a2
                lea     p_v,a0
                cmp.b   #'Q',d2
                bne.s   .sc1
                lea     mdl_screwQ,a2
                lea     p_q,a0
.sc1:           bsr     nbmask
                move.w  d4,d5
                lsl.w   #8,d5
                move.w  d0,d6
                lsl.w   #3,d6
                sub.w   #OX,d6
                move.w  d1,d7
                lsl.w   #3,d7
                sub.w   #OY,d7
                bsr     draw_model
                movem.w (sp)+,d0-d1
                bra     .next
                ; --- orange stool : seat (top tile) + foot
.stool:         movem.w d0-d1,-(sp)
                subq.w  #1,d1
                bsr     scell
                addq.w  #1,d1
                move.w  d0,d6                   ; corner of the tile
                lsl.w   #3,d6
                sub.w   #OX,d6
                move.w  d1,d7
                lsl.w   #3,d7
                sub.w   #OY,d7
                moveq   #0,d5
                lea     mdl_stoolseat,a2        ; seat (top tile)
                cmp.b   #'O',d2
                beq.s   .stp
                cmp.b   #'o',d2
                bne.s   .std
.stp:           lea     mdl_stoolfoot,a2        ; foot : side depending on the column
                btst    #0,1(sp)
                beq.s   .std
                moveq   #1,d5                   ; mirror
                addq.w  #TILE,d6
.std:           bsr     draw_model
                movem.w (sp)+,d0-d1
                bra     .next
.barrel:        btst    #0,d0                   ; even column (win_tx : x32)
                bne     .next
                move.w  d1,d2
                add.w   win_ty,d2
                btst    #0,d2                   ; even row (in the level)
                bne     .next
                movem.w d0-d1,-(sp)
                lsl.w   #3,d0
                sub.w   #OX,d0
                lsl.w   #3,d1
                sub.w   #OY,d1
                move.w  d0,d6                   ; d6/d7 = corner of the barrel (16 x 16)
                move.w  d1,d7
                lea     mdl_barrel,a2           ; model (editable : TILES.DAT)
                moveq   #0,d5
                bsr     draw_model
                movem.w (sp)+,d0-d1
                bra     .next

; ladder uprights : continuous box per vertical run of H tiles
; whose neighbour (left, then right) is not a ladder
;---------------------------------------------------------------------
; Green girders (like the original) : square 6x6 section ; beams 6
; high, riveted, on which Rick walks (middle plane) ; the
; vertical posts are thinner and go BEHIND Rick.

; gisg : tile (d0,d1) of the screen -> Z = 1 if 'G' (edges : no)
gisg:           movem.l d0-d2,-(sp)
                tst.w   d0
                bmi.s   .no
                cmp.w   #SCR_TW,d0
                bge.s   .no
                tst.w   d1
                bmi.s   .no
                cmp.w   #SCR_TH,d1
                bge.s   .no
                bsr     scell
                cmp.b   #'G',d2
                bra.s   .x
.no:            moveq   #1,d2                   ; Z = 0
.x:             movem.l (sp)+,d0-d2
                rts

; gird_beam : d0,d1 = 'G' tile of the screen (registers preserved)
;   horizontal run of 2+ tiles : a single beam (no joints)
;   single tile : cap if it is the top of a post
gird_beam:      movem.l d0-d7/a0-a2,-(sp)
                move.w  d0,d6                   ; d6 = start
                subq.w  #1,d0
                bsr     gisg
                beq     .x                      ; already drawn with its run
                move.w  d6,d0
.r1:            addq.w  #1,d0
                bsr     gisg
                beq.s   .r1
                move.w  d0,d7                   ; d7 = end (excluded)
                sub.w   d6,d0
                cmp.w   #2,d0
                bge.s   .draw
                move.w  d6,d0                   ; single tile : top ?
                subq.w  #1,d1
                bsr     gisg
                beq     .x
                addq.w  #1,d1
.draw:          move.w  d6,d0                   ; d6 = start, d7 = end (excluded)
.gt:            movem.w d0-d1/d6-d7,-(sp)
                move.w  #$300,d5                ; neighbours in the run
                cmp.w   d6,d0
                bne.s   .g1
                and.w   #$200,d5
.g1:            move.w  d0,d2
                addq.w  #1,d2
                cmp.w   d7,d2
                blt.s   .g2
                and.w   #$100,d5
.g2:            move.w  d0,d6
                lsl.w   #3,d6
                sub.w   #OX,d6
                move.w  d1,d7
                lsl.w   #3,d7
                sub.w   #OY,d7
                lea     mdl_girdbeam,a2
                bsr     draw_model
                movem.w (sp)+,d0-d1/d6-d7
                addq.w  #1,d0
                cmp.w   d7,d0
                blt.s   .gt
.x:             movem.l (sp)+,d0-d7/a0-a2
                rts

; build_pylons : 'X' tiles = green lattice pylon (legs of the
;   saucer) : scenery only, Rick walks in front. Per tile : upright
;   left/right if the neighbour is not 'X', and a half diagonal
;   ('\' or '/' depending on parity) -> an X per square of 2x2 tiles.
; ispyl : d2 = character -> Z = 1 if pylon ('X' on wall, 'x' on black)
ispyl:          cmp.b   #'X',d2
                beq.s   .x
                cmp.b   #'x',d2
.x:             rts

build_pylons:
                moveq   #0,d1
.row:           moveq   #0,d0
.col:           bsr     scell
                bsr     ispyl
                bne     .nx
                movem.l d0-d1,-(sp)             ; pylon : model (uprights at the
                move.w  clip_y0,-(sp)           ;  edge, diagonal \ or /)
                move.w  d1,d7                   ; block just above, below the
                lsl.w   #3,d7                   ;  centre of the screen : the top of the
                sub.w   #OY,d7                  ;  pylon (at the back) must not
                ble.s   .pd                     ;  overflow onto this block -> it is
                subq.w  #1,d1                   ;  cut at the front edge of the block
                bsr     scell
                addq.w  #1,d1
                bsr     isblk
                bne.s   .pd
                move.w  d7,d2
                muls    #FOC,d2
                divs    #ZF,d2
                add.w   #CY,d2
                cmp.w   clip_y0,d2
                ble.s   .pd
                move.w  d2,clip_y0
.pd:            lea     p_x,a0
                bsr     nbmask
                move.w  d4,d5
                lsl.w   #8,d5
                move.w  d0,d6
                lsl.w   #3,d6
                sub.w   #OX,d6
                move.w  d1,d7
                lsl.w   #3,d7
                sub.w   #OY,d7
                add.w   d1,d0                   ; parity : diagonal flipped
                btst    #0,d0
                beq.s   .pm
                or.w    #1,d5                   ; mirror (around the tile)
                addq.w  #TILE,d6
.pm:            lea     mdl_pylon,a2
                bsr     draw_model
                move.w  (sp)+,clip_y0
                movem.l (sp)+,d0-d1
.nx:            addq.w  #1,d0
                cmp.w   #SCR_TW,d0
                blt     .col
                addq.w  #1,d1
                cmp.w   #SCR_TH,d1
                blt     .row
                rts
                ; upright : d0 = offset in the tile (0 or 6)
.rail:          movem.w d6-d7,-(sp)
                add.w   d6,d0
                move.w  d0,d2
                addq.w  #2,d2
                move.w  d7,d1
                move.w  d7,d3
                addq.w  #TILE,d3
                move.w  #GP_Z0,d4
                move.w  #GP_Z1,d5
                lea     col_pylon,a1
                bsr     draw_box
                movem.w (sp)+,d6-d7
                rts

; build_posts : vertical posts ('G' tile with 'G' above or below),
;               one per continuous vertical run, drawn before the rest
build_posts:
                moveq   #0,d0
.col:           moveq   #0,d1
.row:           bsr     gisg
                bne     .nx
                move.w  d1,d5                   ; start of the run
.r1:            addq.w  #1,d1
                bsr     gisg
                beq.s   .r1
                move.w  d1,d4
                sub.w   d5,d4
                cmp.w   #2,d4                   ; at least 2 tiles
                blt.s   .nx
                movem.l d0-d1,-(sp)
                move.w  d1,d3                   ; d3 = end (excluded), d5 = start
                move.w  d5,d1
.pt:            movem.w d0-d1/d3/d5,-(sp)       ; one tile after the other (model)
                move.w  #$c00,d4                ; neighbours above + below...
                cmp.w   d5,d1
                bne.s   .p1
                and.w   #$800,d4                ;  ...except at the top
.p1:            move.w  d1,d2
                addq.w  #1,d2
                cmp.w   d3,d2
                blt.s   .p2
                and.w   #$400,d4                ;  ...and at the bottom
.p2:            move.w  d4,d5
                move.w  d0,d6
                lsl.w   #3,d6
                sub.w   #OX,d6
                move.w  d1,d7
                lsl.w   #3,d7
                sub.w   #OY,d7
                lea     mdl_girdpost,a2
                bsr     draw_model
                movem.w (sp)+,d0-d1/d3/d5
                addq.w  #1,d1
                cmp.w   d3,d1
                blt.s   .pt
.rvx:           movem.l (sp)+,d0-d1
                subq.w  #1,d1
.nx:            addq.w  #1,d1
                cmp.w   #SCR_TH,d1
                blt     .row
                addq.w  #1,d0
                cmp.w   #SCR_TW,d0
                blt     .col
                rts

build_rails:
                moveq   #-1,d6                  ; side : -1 left, +1 right
.side:          moveq   #0,d0
.col:           moveq   #0,d1
.row:           bsr     .israil
                beq.s   .start
                addq.w  #1,d1
                bra.s   .rtest
.start:         move.w  d1,d5                   ; start of the run
.run:           addq.w  #1,d1
                cmp.w   #SCR_TH,d1
                bge.s   .draw
                bsr     .israil
                beq.s   .run
.draw:          movem.w d0-d1/d5-d6,-(sp)
                move.w  d1,d3                   ; Y1
                lsl.w   #3,d3
                sub.w   #OY,d3
                move.w  d5,d1                   ; Y0
                lsl.w   #3,d1
                sub.w   #OY,d1
                lsl.w   #3,d0
                sub.w   #OX,d0
                tst.w   d6
                bmi.s   .lft
                addq.w  #TILE-2,d0
.lft:           move.w  d0,d2
                addq.w  #2,d2
                move.w  #ZMID-2,d4
                move.w  #ZMID+2,d5
                lea     col_lad,a1
                cmp.b   #'M',rail_c
                bne.s   .rc
                lea     col_mast,a1
.rc:            bsr     draw_box
                movem.w (sp)+,d0-d1/d5-d6
.rtest:         cmp.w   #SCR_TH,d1
                blt.s   .row
                addq.w  #1,d0
                cmp.w   #SCR_TW,d0
                blt.s   .col
                neg.w   d6
                bgt.s   .side
                rts
; Z = 1 if (d0,d1) is a ladder whose neighbour on side d6 is not one
.israil:        bsr     scell
                cmp.b   #'U',d2                 ; climbing pipe : no uprights
                beq.s   .no
                bsr     isladc
                bne.s   .no
                move.b  d2,rail_c
                movem.w d0-d1,-(sp)
                add.w   d6,d0
                bsr     scell
                movem.w (sp)+,d0-d1
                bsr     isladc
                beq.s   .no
                cmp.b   d2,d2                   ; Z = 1
                rts
.no:            moveq   #1,d2                   ; Z = 0
                rts

;---------------------------------------------------------------------
; GREY PIPES (tiles u : scenery, U : climbable, w : can be walked on)
;   in the middle of the wall depth (PIPE_Z0..PIPE_Z1). A pipe is 2 tiles
;   thick ; each tile is drawn as 4 quarters of 4x4 whose
;   shade (cylinder lit from the top left) depends on the neighbouring pipes :
;   straight vertical / horizontal, elbow (rounded outer quarter = empty).
ispipe:         cmp.b   #'u',d2                 ; Z = 1 if pipe
                beq.s   .x
                cmp.b   #'U',d2
                beq.s   .x
                cmp.b   #'w',d2
.x:             rts

; pnb : is the cell (d0,d1) of the screen a pipe ? -> Z = 1
pnb:            bsr     scell
                bra.s   ispipe
; psol : is the cell (d0,d1) a solid block ? -> Z = 1
psol:           bsr     scell
                bra     isblk

build_pipes:
                moveq   #0,d1
.row:           moveq   #0,d0
.col:           BGCHK
                bsr     pnb
                bne     .nx
                moveq   #0,d4                   ; neighbouring pipes
                subq.w  #1,d0
                bsr     pnb
                bne.s   .n1
                or.w    #1,d4
.n1:            addq.w  #2,d0
                bsr     pnb
                bne.s   .n2
                or.w    #2,d4
.n2:            subq.w  #1,d0
                subq.w  #1,d1
                bsr     pnb
                bne.s   .n3
                or.w    #4,d4
.n3:            addq.w  #2,d1
                bsr     pnb
                bne.s   .n4
                or.w    #8,d4
.n4:            subq.w  #1,d1
                ; a single horizontal and a single vertical neighbour : elbow... except
                ; if the pipe goes into a wall (then it is straight)
                cmp.w   #5,d4
                beq.s   .cf
                cmp.w   #6,d4
                beq.s   .cf
                cmp.w   #9,d4
                beq.s   .cf
                cmp.w   #10,d4
                bne.s   .draw
.cf:            btst    #0,d4
                beq.s   .cr
                addq.w  #1,d0                   ; pipe on the left : wall on the right ?
                bsr     psol
                subq.w  #1,d0
                bne.s   .cv
                or.w    #2,d4
                bra.s   .draw
.cr:            subq.w  #1,d0                   ; pipe on the right : wall on the left ?
                bsr     psol
                addq.w  #1,d0
                bne.s   .cv
                or.w    #1,d4
                bra.s   .draw
.cv:            btst    #2,d4
                beq.s   .cd
                addq.w  #1,d1                   ; pipe above : wall below ?
                bsr     psol
                subq.w  #1,d1
                bne.s   .draw
                or.w    #8,d4
                bra.s   .draw
.cd:            subq.w  #1,d1                   ; pipe below : wall above ?
                bsr     psol
                addq.w  #1,d1
                bne.s   .draw
                or.w    #4,d4
.draw:          move.w  d4,pipe_fl              ; neighbours (pipe or wall)
                lea     pipe_tab,a0
                lsl.w   #2,d4
                adda.w  d4,a0
                move.l  a0,a2                   ; a2 -> the 4 quarters
                movem.w d0-d1,-(sp)
                lsl.w   #3,d0                   ; corner of the tile (world)
                sub.w   #OX,d0
                lsl.w   #3,d1
                sub.w   #OY,d1
                moveq   #0,d6                   ; quarter : bit 0 = right, bit 1 = bottom
.q:             move.b  (a0)+,d7
                bmi     .qn
                ; faces to draw : only towards the outside of the pipe (not between
                ; two quarters or two pipe tiles : else a staircase pattern)
                moveq   #15,d5
                move.w  d6,d2                   ; d2 = quarter (bit0 right, bit1 bottom)
                and.w   #2,d2                   ; d2 = 2*sy
                btst    #0,d6
                beq.s   .ml0
                tst.b   (a2,d2.w)               ; left quarter of the same row
                bmi.s   .ml1
                bclr    #0,d5
                bra.s   .ml1
.ml0:           btst    #0,pipe_fl+1            ; tile on the left
                beq.s   .mr0
                bclr    #0,d5
.mr0:           tst.b   1(a2,d2.w)              ; right quarter of the same row
                bmi.s   .mv
                bclr    #1,d5
                bra.s   .mv
.ml1:           btst    #1,pipe_fl+1            ; tile on the right
                beq.s   .mv
                bclr    #1,d5
.mv:            move.w  d6,d2
                and.w   #1,d2                   ; d2 = sx
                btst    #1,d6
                beq.s   .mt0
                tst.b   (a2,d2.w)               ; top quarter, same column
                bmi.s   .mb1
                bclr    #2,d5
                bra.s   .mb1
.mt0:           btst    #2,pipe_fl+1            ; tile above
                beq.s   .mb0
                bclr    #2,d5
.mb0:           tst.b   2(a2,d2.w)              ; bottom quarter, same column
                bmi.s   .mok
                bclr    #3,d5
                bra.s   .mok
.mb1:           btst    #3,pipe_fl+1            ; tile below
                beq.s   .mok
                bclr    #3,d5
.mok:           move.w  d5,box_mask
                ext.w   d7
                lsl.w   #3,d7
                lea     col_pipe0,a1
                adda.w  d7,a1
                movem.w d0-d1,-(sp)
                btst    #0,d6
                beq.s   .q1
                addq.w  #4,d0
.q1:            btst    #1,d6
                beq.s   .q2
                addq.w  #4,d1
.q2:            move.w  d0,d2
                addq.w  #4,d2
                move.w  d1,d3
                addq.w  #4,d3
                move.w  #PIPE_Z0,d4
                move.w  #PIPE_Z1,d5
                bsr     draw_box
                movem.w (sp)+,d0-d1
.qn:            addq.w  #1,d6
                cmp.w   #4,d6
                blt     .q
                movem.w (sp)+,d0-d1
.nx:            addq.w  #1,d0
                cmp.w   #SCR_TW,d0
                blt     .col
                addq.w  #1,d1
                cmp.w   #SCR_TH,d1
                blt     .row
                move.w  #15,box_mask            ; all the faces (other boxes)
                rts

;---------------------------------------------------------------------
; nbmask : tile (d0,d1) of the screen, a0 -> test (d2 = character ->
;   Z = 1 if same kind) -> d4 = neighbours of the same kind (1 left
;   2 right 4 up 8 down) ; registers preserved (except d4)
nbmask:         movem.l d0-d3/a0,-(sp)
                moveq   #0,d4
                subq.w  #1,d0
                bsr     scell
                jsr     (a0)
                bne.s   .1
                or.w    #1,d4
.1:             addq.w  #2,d0
                bsr     scell
                jsr     (a0)
                bne.s   .2
                or.w    #2,d4
.2:             subq.w  #1,d0
                subq.w  #1,d1
                bsr     scell
                jsr     (a0)
                bne.s   .3
                or.w    #4,d4
.3:             addq.w  #2,d1
                bsr     scell
                jsr     (a0)
                bne.s   .4
                or.w    #8,d4
.4:             movem.l (sp)+,d0-d3/a0
                rts
; neighbourhood tests
p_lad:          cmp.b   #'U',d2                 ; ladder / pole (not the pipe)
                beq.s   .no
                bra     isladc
.no:            moveq   #1,d2
                rts
p_v:            cmp.b   #'V',d2
                rts
p_q:            cmp.b   #'Q',d2
                rts
p_g:            cmp.b   #'G',d2
                rts
p_x:            bra     ispyl
