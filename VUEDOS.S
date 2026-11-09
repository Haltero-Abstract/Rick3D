;=====================================================================
; VUEDOS.S - BACK VIEW (test) : the camera turns by 90 degrees around
;   the vertical axis and goes behind Rick ; the room becomes a
;   corridor going away in front of him. V key : side view / back view.
;   (included by RICK3D.S ; the settings are in PARAMS.S)
;
; Principle : all the scenery boxes are aligned on the axes ; turned
; by 90 degrees they still are. So draw_box swaps its axes
; (bv_xform) : level x -> depth, scenery depth -> x (widened
; BV_K times so that the corridor fills the screen), then draws as
; usual. Painter's order : the level columns, from the furthest
; to the nearest.
;=====================================================================

;---------------------------------------------------------------------
; bv_xform : d0..d5 = box (x0 y0 x1 y1 z0 z1) in side view
;   -> the same box seen from behind ; Z = 1 if it is behind the camera
;   (d6, d7 used)
bv_xform:
                clr.w   bv_nf2                  ; near face = original x0 (or x1)
                moveq   #1,d6                   ;  face : hidden by a
                tst.w   bv_dir                  ;  neighbour -> not drawn
                bpl.s   .fb
                moveq   #2,d6
.fb:            and.w   box_mask,d6
                bne.s   .fv
                move.w  #1,bv_nf2
.fv:            or.w    #3,box_mask             ; sides of the corridor : free
                move.w  d4,d6
                move.w  d5,d7
                sub.w   #ZMID,d6                ; depth -> width
                sub.w   #ZMID,d7
                muls    #BV_K,d6
                muls    #BV_K,d7
                tst.w   bv_dir
                bmi.s   .left
                move.w  d0,d4                   ; Rick looks right :
                sub.w   bv_cx,d4                ;  level x -> depth
                move.w  d2,d5
                sub.w   bv_cx,d5
                move.w  d6,d0
                move.w  d7,d2
                bra.s   .y
.left:          move.w  bv_cx,d4                ; left : everything is reversed
                sub.w   d2,d4
                move.w  bv_cx,d5
                sub.w   d0,d5
                neg.w   d7
                neg.w   d6
                move.w  d7,d0
                move.w  d6,d2
.y:             sub.w   bv_cy,d1
                sub.w   bv_cy,d3
                cmp.w   #BV_NEAR,d5             ; completely behind the camera
                ble.s   .no
                cmp.w   #BV_NEAR,d4             ; cut at the near plane
                bge.s   .ok
                move.w  #BV_NEAR,d4
.ok:            moveq   #1,d6                   ; Z = 0 : to draw
                rts
.no:            moveq   #0,d6                   ; Z = 1 : nothing
                rts

;---------------------------------------------------------------------
; build_back : draws the back view in the screen a6 (band clip_y0..y1)
build_back:
                lea     bvx_ext,a0              ; extents drawn in this
                tst.w   cur_back                ;  screen (bands of 8 lines)
                beq.s   .e0
                lea     BVX_N*4(a0),a0
.e0:            move.l  a0,bvx_cur
                move.w  clip_y0,d1              ; black background (drawn band)
                move.w  clip_y1,d2
                tst.w   bv_clr                  ; when entering : the whole screen
                bne.s   .cf                     ;  (leftovers of the side view)
                bsr     bvx_clear               ; else : only what was
                bra     .c9                     ;  drawn in this screen
.cf:            subq.w  #1,bv_clr
                moveq   #0,d1
                move.w  #SCR_H-1,d2
                tst.w   txt_hidden
                bne.s   .c0
                move.w  txt_y,d2
                subq.w  #1,d2
.c0:            move.w  d2,d0
                addq.w  #1,d0
                mulu    #LINEB,d0
                lea     (a6,d0.l),a0            ; end of the area
                move.w  d2,d0
                sub.w   d1,d0
                addq.w  #1,d0
                mulu    #LINEB/40,d0            ; packs of 40 bytes
                subq.w  #1,d0
                moveq   #0,d1
                moveq   #0,d2
                moveq   #0,d3
                moveq   #0,d4
                moveq   #0,d5
                moveq   #0,d6
                moveq   #0,d7
                move.l  d1,a1
                move.l  d1,a2
                move.l  d1,a3
.cl:            movem.l d1-d7/a1-a3,-(a0)
                dbra    d0,.cl
.c9:            move.l  bvx_cur,a0              ; nothing drawn any more
                moveq   #BVX_N-1,d0
.c8:            move.l  #$7fff8000,(a0)+        ; (x0 = 32767, x1 = -32768)
                dbra    d0,.c8
                move.w  #1,bvx_on
                tst.w   bv_ok
                bne.s   .ini
                bsr     bv_init
                move.w  #1,bv_ok
.ini:           clr.l   box_tex
                move.w  #15,box_mask
                ; --- camera : behind Rick, a bit above his head
                move.w  #1,bv_dir
                tst.w   rick_dir
                bpl.s   .d
                move.w  #-1,bv_dir
.d:             move.w  rick_xf,d0
                asr.w   #3,d0
                add.w   #RICK_W/2,d0            ; middle of Rick (level)
                move.w  d0,d1
                asr.w   #3,d1
                move.w  d1,bv_rc                ; his column
                sub.w   win_ox,d0
                move.w  #BV_BACK,d1
                muls    bv_dir,d1
                sub.w   d1,d0
                move.w  d0,bv_cx
                move.w  rick_yf,d0
                asr.w   #3,d0
                move.w  d0,d1
                add.w   rk_h,d1
                asr.w   #3,d1
                move.w  d1,bv_fr                ; row of the feet (floor)
                sub.w   win_oy,d0
                sub.w   #BV_EYE,d0
                move.w  d0,bv_cy
                ; --- Rick's "tunnel" : from the ceiling above his head
                ;     down to the floor under his feet (in his column) ; nothing
                ;     above or below is drawn
                move.w  win_ty,d4
                subq.w  #2,d4                   ; d4 = top limit
                bpl.s   .t0
                moveq   #0,d4
.t0:            move.w  bv_rc,d0
                move.w  rick_yf,d1
                asr.w   #6,d1                   ; row of the head
.tu:            cmp.w   d4,d1
                ble.s   .tu2
                subq.w  #1,d1
                bsr     tile_at
                bsr     isblk
                bne.s   .tu
.tu2:           move.w  d1,bv_rtop              ; (the ceiling row included)
                move.w  win_ty,d4
                add.w   #SCR_TH+2,d4
                cmp.w   lev_h,d4
                ble.s   .t1
                move.w  lev_h,d4
.t1:            move.w  bv_fr,d1
.td:            cmp.w   d4,d1
                bge.s   .td2
                bsr     tile_at
                bsr     isblk
                beq.s   .td1
                addq.w  #1,d1
                bra.s   .td
.td1:           addq.w  #1,d1                   ; (the floor row included)
.td2:           move.w  d1,bv_rbot
                ; --- first solid column in front of Rick (wall that blocks the whole
                ;     screen) : nothing to draw beyond it
                moveq   #1,d7
.fw:            move.w  d7,d0
                muls    bv_dir,d0
                add.w   bv_rc,d0
                move.w  bv_rtop,d1              ; (in the tunnel)
                move.w  bv_rbot,d3
                sub.w   d1,d3
                subq.w  #1,d3
.fr:            bsr     tile_at
                bsr     isblk
                bne.s   .fo                     ; a hole : we see further
                addq.w  #1,d1
                dbra    d3,.fr
                bra.s   .fe                     ; solid column
.fo:            addq.w  #1,d7
                cmp.w   #BV_DIST,d7
                blt.s   .fw
.fe:            move.w  d7,bv_far
                ; (no side walls : only the corridor)
                bsr     bv_slabs                ; floors / ceilings : the same
                move.w  bv_far,d7
                move.w  #1,bv_rec               ; moving objects : noted
                clr.w   bv_nrec                 ;  once, replayed column by
                bsr     bv_dyn                  ;  column
                clr.w   bv_rec
                ; --- columns : from the furthest up to Rick's one
.col:           move.w  d7,d0
                muls    bv_dir,d0
                add.w   bv_rc,d0
                clr.w   bv_floor
                bsr     bv_column
                ; moving objects of this column (Rick, platforms,
                ; beams, lasers, bomb...) : depth filter
                lsl.w   #3,d0
                sub.w   win_ox,d0               ; x of the left edge of the column
                tst.w   bv_dir
                bmi.s   .zl
                sub.w   bv_cx,d0                ; depth : d0 .. d0+8
                move.w  d0,d1
                addq.w  #8,d1
                bra.s   .zf
.zl:            neg.w   d0
                add.w   bv_cx,d0                ; camx - x : from d0-8 to d0
                move.w  d0,d1
                subq.w  #8,d0
.zf:            tst.w   d7                      ; Rick's column : up to his
                bne.s   .z1                     ;  back, not nearer (what is
                move.w  #BV_BACK-RICK_W/2-2,d0  ;  behind him would hide the view)
.z1:            cmp.w   bv_far,d7               ; the furthest one : everything
                bne.s   .z2                     ;  beyond it too
                move.w  #32767,d1
.z2:            move.w  d0,bv_fz0
                move.w  d1,bv_fz1
                bsr     bv_replay
                subq.w  #1,d7
                bpl     .col
                ; --- behind Rick : only the floor (not the walls that
                ;     would hide everything)
                moveq   #-1,d7
.cb:            move.w  d7,d0
                muls    bv_dir,d0
                add.w   bv_rc,d0
                move.w  #1,bv_floor
                bsr     bv_column
                subq.w  #1,d7
                cmp.w   #-BV_BEH,d7
                bge.s   .cb
                clr.l   box_tex
                move.w  #15,box_mask
                rts

;---------------------------------------------------------------------
; bv_column : d0 = level column ; all the rows of the screen
;   (bv_floor : only the floor, under Rick's feet)
;   the blocks whose near face can be seen (one box per run of the same
;   kind, near face with the pattern), then the objects tile by tile.
;   (top / bottom of blocks with a hidden face : bv_slabs)
;   The map is read directly (pointer), with the bv_cls table.
bv_column:
                movem.l d0-d7/a0-a4,-(sp)
                move.w  d0,bv_col
                bmi     .x
                cmp.w   lev_w,d0
                bge     .x
                move.w  bv_rtop,d1              ; tunnel rows
                tst.w   bv_floor
                beq.s   .r0
                move.w  bv_fr,d1
.r0:            move.w  d1,bv_r0
                move.w  bv_rbot,bv_r1
                move.w  bv_r0,d1
                cmp.w   bv_r1,d1
                bge     .x
                mulu    lev_w,d1                ; a0 -> (column, 1st row)
                lea     levmap,a0
                adda.l  d1,a0
                adda.w  d0,a0
                move.w  lev_w,d5                ; d5 = step of a row
                lea     bv_cls,a2
                move.w  bv_dir,d3
                neg.w   d3                      ; d3 = neighbour on the camera side
                ; --- blocks and objects
                move.w  #-1,bv_run
                move.l  a0,a3
                move.w  bv_r0,d7
.b1:            moveq   #0,d2
                move.b  (a3),d2
                move.b  (a2,d2.w),d6
                btst    #0,d6
                beq.s   .b2
                moveq   #0,d1                   ; block : neighbour on the camera side
                move.b  (a3,d3.w),d1
                btst    #0,(a2,d1.w)
                bne.s   .b3
                bsr     bv_bcol                 ; near face visible : run
                tst.w   bv_run
                bmi.s   .bs
                cmp.l   bv_rset,a1
                beq.s   .b9
                bsr     bv_bflush
.bs:            move.w  d7,bv_run
                move.l  a1,bv_rset
                move.l  bv_cpat,bv_rpat
                bra.s   .b9
.b3:            bsr     bv_bflush               ; near face hidden : its top
                bra.s   .b9                     ;  / bottom -> bv_slabs
.b2:            bsr     bv_bflush
                btst    #2,d6                   ; object ?
                beq.s   .b9
.bt:            move.w  bv_col,d0
                move.w  d7,d1
                bsr     bv_tile
.b9:            adda.w  d5,a3
                addq.w  #1,d7
                cmp.w   bv_r1,d7
                blt     .b1
                bsr     bv_bflush
.x:             movem.l (sp)+,d0-d7/a0-a4
                rts

; bv_init : bv_cls table (1 block, 2 back wall behind, 4 object)
bv_init:        movem.l d0-d2/a0,-(sp)
                lea     bv_cls,a0
                move.w  #255,d0
.l:             move.w  d0,d2
                moveq   #0,d1
                cmp.b   #'k',d2
                beq.s   .s
                moveq   #4,d1
                cmp.b   #'x',d2
                beq.s   .s
                moveq   #1,d1
                bsr     isblk
                beq.s   .s
                moveq   #2,d1
                cmp.b   #'.',d2
                beq.s   .s
                moveq   #6,d1
.s:             move.b  d1,(a0,d0.w)
                dbra    d0,.l
                movem.l (sp)+,d0-d2/a0
                rts

; bv_get : d7 = row -> d2 = character (column bv_col)
bv_get:         movem.l d0-d1,-(sp)
                move.w  bv_col,d0
                move.w  d7,d1
                bsr     tile_at
                movem.l (sp)+,d0-d1
                rts

; bv_bcol : d2 = block -> a1 = its colours (back view)
bv_bcol:        lea     bv_rock,a1
                move.l  #pat_rock,bv_cpat
                cmp.b   #'F',d2
                beq.s   .f
                cmp.b   #'B',d2
                bne.s   .g
                lea     bv_frame,a1
                move.l  #pat_plate,bv_cpat
                bra.s   .x
.f:             lea     bv_frame,a1
                move.l  #pat_frame,bv_cpat
.g:             cmp.b   #'g',d2
                bne.s   .x
                lea     bv_grass,a1
                move.l  #pat_grass,bv_cpat
.x:             rts

; bv_bflush : run of blocks bv_run .. d7-1 (colours bv_rset) -> one box
bv_bflush:      tst.w   bv_run
                bmi     .x
                movem.l d0-d7/a0-a1,-(sp)
                moveq   #3,d6                   ; near face + top / bottom
                move.w  bv_col,d0               ;  if free
                move.w  bv_run,d1
                subq.w  #1,d1
                bsr     tile_at
                bsr     isblk
                beq.s   .t
                or.w    #4,d6
.t:             move.w  d7,d1
                bsr     tile_at
                bsr     isblk
                beq.s   .b
                or.w    #8,d6
.b:             move.w  d6,box_mask
                move.l  bv_rset,a1
                move.w  bv_run,d1
                move.w  d7,d3
                bsr     bv_box
                move.w  #ZF,d4
                move.w  #ZB,d5
                move.w  #1,bv_nofront           ; near face : with the pattern
                bsr     draw_box
                clr.w   bv_nofront
                move.w  bv_run,d1
                move.w  d7,d3
                bsr     bv_patface
                move.w  #15,box_mask
                movem.l (sp)+,d0-d7/a0-a1
                move.w  #-1,bv_run
.x:             rts

; bv_box : d1 = 1st row, d3 = row after the end -> d0..d3 box
;   (column bv_col, centred coordinates)
bv_box:         lsl.w   #3,d1
                sub.w   win_oy,d1
                lsl.w   #3,d3
                sub.w   win_oy,d3
                move.w  bv_col,d0
                lsl.w   #3,d0
                sub.w   win_ox,d0
                move.w  d0,d2
                addq.w  #TILE,d2
                rts

;---------------------------------------------------------------------
; bv_tile : d0/d1 = level column/row, d2 = character
bv_tile:
                movem.l d0-d7/a0-a2,-(sp)
                move.w  d0,d6                   ; d6/d7 = corner (centred coord.)
                lsl.w   #3,d6
                sub.w   win_ox,d6
                move.w  d1,d7
                lsl.w   #3,d7
                sub.w   win_oy,d7
                cmp.b   #'k',d2                 ; black background : nothing
                beq     .x
                move.b  d2,bv_ch                ; (bv_column sends only
                                                ;  objects here)
                move.w  d0,d4                   ; -> screen coordinates
                sub.w   win_tx,d4               ;    (nbmask, scell)
                move.w  d1,d5
                sub.w   win_ty,d5
                movem.w d4-d5,-(sp)
                lea     mdl_walkway,a2
                lea     p_same,a0
                cmp.b   #'=',d2
                beq     .mdl
                lea     mdl_bar,a2
                cmp.b   #'-',d2
                beq     .mdl
                lea     mdl_girdbeam,a2
                cmp.b   #'G',d2
                beq     .mdl
                lea     mdl_ladder,a2
                lea     p_lad,a0
                cmp.b   #'H',d2
                beq     .mdl
                lea     mdl_mast,a2
                cmp.b   #'M',d2
                beq     .mdl
                lea     mdl_pylon,a2
                lea     p_x,a0
                bsr     ispyl
                beq     .mdl
                lea     mdl_screwV,a2
                lea     p_v,a0
                cmp.b   #'V',d2
                beq     .mdl
                lea     mdl_screwQ,a2
                lea     p_q,a0
                cmp.b   #'Q',d2
                beq     .mdl
                cmp.b   #'T',d2
                beq     .barrel
                cmp.b   #'U',d2
                beq.s   .pipe
                cmp.b   #'u',d2
                beq.s   .pipe
                cmp.b   #'w',d2
                beq.s   .pipe
                addq.l  #4,sp
                bra     .x
.pipe:          addq.l  #4,sp                   ; pipe : a grey box
                lea     col_pipe1,a1
                move.w  #15,box_mask
                move.w  d6,d0
                move.w  d7,d1
                move.w  d6,d2
                addq.w  #TILE,d2
                move.w  d7,d3
                addq.w  #TILE,d3
                move.w  #PIPE_Z0,d4
                move.w  #PIPE_Z1,d5
                bsr     draw_box
                bra     .x
.barrel:        addq.l  #4,sp                   ; barrel : corner (even, even)
                btst    #0,d0
                bne     .x
                btst    #0,d1
                bne     .x
                lea     mdl_barrel,a2
                moveq   #0,d5
                bsr     draw_model
                bra     .x
.mdl:           movem.w (sp)+,d0-d1             ; neighbours of the same kind
                bsr     nbmask
                move.w  d4,d5
                lsl.w   #8,d5
                cmp.l   #mdl_ladder,a2          ; flat objects (ladders, poles,
                beq.s   .bb                     ;  pylons, screws) : turned to face
                cmp.l   #mdl_mast,a2            ;  the camera, otherwise they are
                beq.s   .bb                     ;  only seen edge-on
                cmp.l   #mdl_pylon,a2
                beq.s   .bb
                cmp.l   #mdl_screwV,a2
                bne.s   .nb
.bb:            move.w  d6,bv_bx
                move.w  #1,bv_bill
.nb:            bsr     draw_model
                clr.w   bv_bill
.x:             movem.l (sp)+,d0-d7/a0-a2
                rts

; p_same : neighbour = same character as the tile (d3 saved by nbmask)
p_same:         cmp.b   bv_ch,d2
                rts

;---------------------------------------------------------------------
; bv_dyn : all the moving objects and the scenery objects that are not
;   in the map (buttons, emitters, canisters...) ; their boxes are
;   noted (bv_note) then replayed column by column (bv_replay)
bv_dyn:         movem.l d0-d7/a0-a6,-(sp)
                bsr     draw_switches
                bsr     draw_nozzles
                bsr     draw_zapemit
                move.w  #1,zp_mode              ; canisters, balls
                bsr     draw_zaps
                clr.w   zp_mode
                bsr     draw_zaps               ; beams
                bsr     draw_plats
                bsr     draw_rick0
                bsr     draw_lasers
                bsr     draw_objs
                clr.l   box_tex
                move.w  #15,box_mask
                movem.l (sp)+,d0-d7/a0-a6
                rts

;---------------------------------------------------------------------
; bv_note : (from draw_box) notes a box d0..d5, a1, box_mask, box_tex
;   with its (middle) depth seen from behind
BV_RSZ          equ     24
bv_note:        move.w  bv_rtop,d6              ; outside the tunnel (above or
                lsl.w   #3,d6                   ;  below) : ignored
                sub.w   win_oy,d6
                cmp.w   d6,d3
                ble.s   .x
                move.w  bv_rbot,d6
                lsl.w   #3,d6
                sub.w   win_oy,d6
                cmp.w   d6,d1
                bge.s   .x
                move.w  bv_nrec,d6
                cmp.w   #BV_MAXR,d6
                bhs.s   .x
                mulu    #BV_RSZ,d6
                lea     bv_recs,a0
                adda.l  d6,a0
                movem.w d0-d5,(a0)
                move.l  a1,12(a0)
                move.w  box_mask,16(a0)
                move.l  box_tex,18(a0)
                move.w  d0,d6                   ; depth of the middle
                add.w   d2,d6
                asr.w   #1,d6
                tst.w   bv_dir
                bmi.s   .l
                sub.w   bv_cx,d6
                bra.s   .s
.l:             neg.w   d6
                add.w   bv_cx,d6
.s:             move.w  d6,22(a0)
                addq.w  #1,bv_nrec
.x:             rts

; bv_replay : redraws the noted boxes whose depth is in
;   bv_fz0 .. bv_fz1 (current column)
bv_replay:      movem.l d0-d7/a0-a2,-(sp)
                move.l  box_tex,-(sp)
                move.w  bv_nrec,d7
                beq.s   .x
                subq.w  #1,d7
                lea     bv_recs,a2
.l:             move.w  22(a2),d6
                cmp.w   bv_fz0,d6
                blt.s   .n
                cmp.w   bv_fz1,d6
                bge.s   .n
                movem.w (a2),d0-d5
                move.l  12(a2),a1
                move.w  16(a2),box_mask
                move.l  18(a2),box_tex
                bsr     draw_box
.n:             lea     BV_RSZ(a2),a2
                dbra    d7,.l
.x:             move.l  (sp)+,box_tex
                move.w  #15,box_mask
                movem.l (sp)+,d0-d7/a0-a2
                rts

;---------------------------------------------------------------------
; bv_slabs : the tops (floors) and bottoms (ceilings) of the blocks whose
;   near face is hidden, merged in depth : one box per run of
;   columns, per row. Drawn before the columns (everything that
;   stands on them or in front comes after). Behind Rick : only the floor.
bv_slabs:       movem.l d0-d7/a0-a4,-(sp)
                lea     bv_cls,a2
                move.w  bv_rtop,d7              ; tunnel rows
.r0:            move.w  #1,bv_sk                ; 1 : top, 2 : bottom
.row:           move.w  #-BV_BEH,d6             ; d6 = column index
                move.w  #-1,bv_run
.col:           move.w  d6,d0
                muls    bv_dir,d0
                add.w   bv_rc,d0                ; column
                bmi     .brk
                cmp.w   lev_w,d0
                bge     .brk
                tst.w   d6                      ; behind Rick : floor only
                bpl.s   .c1
                cmp.w   bv_fr,d7
                blt     .brk
.c1:            move.w  d7,d1
                mulu    lev_w,d1
                lea     levmap,a0
                adda.l  d1,a0
                adda.w  d0,a0                   ; a0 -> tile
                moveq   #0,d2
                move.b  (a0),d2
                btst    #0,(a2,d2.w)
                beq     .brk                    ; not a block
                move.w  bv_dir,d1
                neg.w   d1
                moveq   #0,d3
                move.b  (a0,d1.w),d3            ; neighbour on the camera side : block ?
                btst    #0,(a2,d3.w)
                beq     .brk                    ; (else : done by bv_bflush)
                move.w  lev_w,d1
                cmp.w   #1,bv_sk
                beq.s   .up
                moveq   #0,d3
                move.b  (a0,d1.w),d3            ; bottom : the tile below
                bra.s   .tt
.up:            neg.w   d1
                moveq   #0,d3
                move.b  (a0,d1.w),d3            ; top : the tile above
.tt:            btst    #0,(a2,d3.w)
                bne.s   .brk                    ; face stuck to a block
                bsr     bv_bcol                 ; a1 = colours
                tst.w   bv_run
                bmi.s   .new
                cmp.l   bv_rset,a1
                beq.s   .nx
                bsr     .flush
.new:           move.w  d6,bv_run
                move.l  a1,bv_rset
                bra.s   .nx
.brk:           bsr     .flush
.nx:            addq.w  #1,d6
                cmp.w   bv_far,d6
                ble     .col
                bsr     .flush
                addq.w  #1,bv_sk
                cmp.w   #2,bv_sk
                ble     .row
                addq.w  #1,d7
                cmp.w   bv_rbot,d7
                blt     .r0
                movem.l (sp)+,d0-d7/a0-a4
                rts
                ; run bv_run .. d6-1 (indices) on row d7
.flush:         tst.w   bv_run
                bmi     .fx
                movem.l d0-d7/a0-a1,-(sp)
                move.w  bv_run,d0
                muls    bv_dir,d0
                add.w   bv_rc,d0
                move.w  d6,d2
                subq.w  #1,d2
                muls    bv_dir,d2
                add.w   bv_rc,d2
                cmp.w   d0,d2
                bge.s   .o
                exg     d0,d2
.o:             lsl.w   #3,d0                   ; x : columns d0 .. d2
                sub.w   win_ox,d0
                addq.w  #1,d2
                lsl.w   #3,d2
                sub.w   win_ox,d2
                move.w  d7,d1
                lsl.w   #3,d1
                sub.w   win_oy,d1
                move.w  d1,d3
                addq.w  #TILE,d3
                move.w  #4,box_mask             ; top only
                cmp.w   #1,bv_sk
                beq.s   .m
                move.w  #8,box_mask             ; bottom only
.m:             move.w  #1,bv_nofront
                move.l  bv_rset,a1
                move.w  #ZF,d4
                move.w  #ZB,d5
                bsr     draw_box
                clr.w   bv_nofront
                move.w  #15,box_mask
                movem.l (sp)+,d0-d7/a0-a1
                move.w  #-1,bv_run
.fx:            rts

;---------------------------------------------------------------------
; bv_billb : (back view) turns a box of a flat object by a quarter of
;   a turn around the vertical, around the middle of its tile (bv_bx) :
;   its width (x in the tile) becomes the width on the screen, its
;   depth (z) becomes its thickness. d0 d2 d4 d5 changed.
bv_billb:       movem.l d6-d7,-(sp)
                or.w    #3,box_mask             ; (side faces : free)
                move.w  d0,d6
                sub.w   bv_bx,d6
                subq.w  #4,d6                   ; x in the tile - 4
                muls    #BV_BS,d6
                add.w   #ZMID,d6                ; -> new z0
                move.w  d2,d7
                sub.w   bv_bx,d7
                subq.w  #4,d7
                muls    #BV_BS,d7
                add.w   #ZMID,d7                ; -> new z1
                move.w  d4,d0                   ; old z -> x around the
                sub.w   #ZMID,d0                ;  middle of the tile
                add.w   bv_bx,d0
                addq.w  #4,d0
                move.w  d5,d2
                sub.w   #ZMID,d2
                add.w   bv_bx,d2
                addq.w  #4,d2
                move.w  d6,d4
                move.w  d7,d5
                movem.l (sp)+,d6-d7
                rts

;---------------------------------------------------------------------
; bvx_add : back view : rectangle d0..d2 x d1..d3 (screen, clipped) drawn
;   -> x extents of its bands of 8 lines (erasing of the next frame)
bvx_add:        tst.w   bvx_on
                beq.s   .x
                movem.l d1/d3/a0,-(sp)
                sub.w   #BVX_Y0,d1
                bpl.s   .1
                moveq   #0,d1
.1:             sub.w   #BVX_Y0,d3
                cmp.w   #BV_BAND-1,d3
                ble.s   .2
                move.w  #BV_BAND-1,d3
.2:             cmp.w   d3,d1
                bgt.s   .9
                lsr.w   #3,d1
                lsr.w   #3,d3
                sub.w   d1,d3
                move.l  bvx_cur,a0
                lsl.w   #2,d1
                adda.w  d1,a0
.l:             cmp.w   (a0),d0
                bge.s   .a
                move.w  d0,(a0)
.a:             cmp.w   2(a0),d2
                ble.s   .b
                move.w  d2,2(a0)
.b:             addq.l  #4,a0
                dbra    d3,.l
.9:             movem.l (sp)+,d1/d3/a0
.x:             rts

; bvx_clear : erases (black) the extents noted for the screen a6 (bvx_cur)
bvx_clear:      movem.l d0-d7/a0-a2,-(sp)
                move.l  bvx_cur,a1
                moveq   #0,d6                   ; black
                move.w  #BVX_Y0,d5              ; 1st line of the band
                moveq   #BVX_N-1,d7
.b:             move.w  (a1)+,d0                ; x0
                move.w  (a1)+,d2                ; x1
                tst.w   d0
                bpl.s   .b1
                moveq   #0,d0
.b1:            cmp.w   #SCR_W-1,d2
                ble.s   .b2
                move.w  #SCR_W-1,d2
.b2:            sub.w   d0,d2
                bmi.s   .nb                     ; nothing in this band
                addq.w  #1,d2                   ; pixels
                move.w  d5,d1
                mulu    #LINEB,d1
                lea     (a6,d1.l),a0
                add.w   d0,d0
                adda.w  d0,a0
                moveq   #7,d3
.ln:            move.l  a0,a2
                move.w  d2,d1
                bsr     span_fill
                lea     LINEB(a0),a0
                dbra    d3,.ln
.nb:            addq.w  #8,d5
                dbra    d7,.b
                movem.l (sp)+,d0-d7/a0-a2
                rts

;---------------------------------------------------------------------
; rect_pat : rectangle d0,d1 - d2,d3 (screen, bounds included, not clipped)
;   filled with the 10x10 pattern a0 (the one of the blocks in side view),
;   repeated every d4 pixels (size of a tile at this distance)
rect_pat:       movem.l d0-d7/a0-a4,-(sp)
                tst.w   d4
                ble     .x
                move.l  #2560,d6                ; pattern step (8.8) per pixel
                divu    d4,d6
                and.l   #$ffff,d6
                moveq   #0,d5                   ; start v (8.8)
                cmp.w   clip_y0,d1
                bge.s   .t1
                move.w  clip_y0,d5
                sub.w   d1,d5
                mulu    d6,d5
                divu    #2560,d5
                swap    d5                      ; (rest : modulo 10 tiles)
                and.l   #$ffff,d5
                move.w  clip_y0,d1
.t1:            moveq   #0,d7                   ; start u
                tst.w   d0
                bpl.s   .t2
                move.w  d0,d7
                neg.w   d7
                mulu    d6,d7
                divu    #2560,d7
                swap    d7
                and.l   #$ffff,d7
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
                bsr     bvx_add                 ; (back view : to erase)
                sub.w   d0,d2                   ; width - 1
                sub.w   d1,d3                   ; height - 1
                mulu    #LINEB,d1
                lea     (a6,d1.l),a1
                add.w   d0,d0
                adda.w  d0,a1                   ; a1 -> 1st pixel
                move.l  a0,a4
                lea     rp_off,a3               ; pattern column of each
                move.w  d7,d1                   ;  pixel : computed once
                move.w  d2,d0                   ;  for the whole rectangle
.ut:            move.w  d1,d4
                lsr.w   #7,d4
                and.w   #$fffe,d4
                move.w  d4,(a3)+
                add.w   d6,d1
                cmp.w   #2560,d1
                blo.s   .u1
                sub.w   #2560,d1
.u1:            dbra    d0,.ut
.y:             move.w  d5,d0                   ; pattern row
                lsr.w   #8,d0
                mulu    #20,d0
                lea     (a4,d0.w),a2
                move.l  a1,a3
                lea     rp_off,a0
                move.w  d2,d0
.xl:            move.w  (a0)+,d4
                move.w  (a2,d4.w),(a3)+
                dbra    d0,.xl
                lea     LINEB(a1),a1
                add.w   d6,d5
                cmp.w   #2560,d5
                blo.s   .y1
                sub.w   #2560,d5
.y1:            dbra    d3,.y
.x:             movem.l (sp)+,d0-d7/a0-a4
                rts

; bv_patface : near face of a run of blocks (column bv_col, rows
;   d1 .. d3-1), drawn with the pattern of the block (bv_rpat)
bv_patface:     movem.l d0-d7/a0,-(sp)
                move.w  bv_col,d0
                lsl.w   #3,d0
                sub.w   win_ox,d0               ; x of the left edge
                tst.w   bv_dir
                bmi.s   .l
                sub.w   bv_cx,d0                ; depth of the near face
                bra.s   .z
.l:             neg.w   d0
                add.w   bv_cx,d0
                subq.w  #TILE,d0
.z:             cmp.w   #BV_NEAR,d0
                blt.s   .x                      ; (too close : nothing)
                move.w  d0,d7                   ; d7 = z
                lsl.w   #3,d1
                sub.w   win_oy,d1
                sub.w   bv_cy,d1
                lsl.w   #3,d3
                sub.w   win_oy,d3
                sub.w   bv_cy,d3
                muls    #FOC,d1
                divs    d7,d1
                add.w   #CY,d1
                muls    #FOC,d3
                divs    d7,d3
                add.w   #CY-1,d3
                move.w  #-20*BV_K,d0            ; width of the corridor
                muls    #FOC,d0
                divs    d7,d0
                add.w   #CX,d0
                move.w  #20*BV_K,d2
                muls    #FOC,d2
                divs    d7,d2
                add.w   #CX-1,d2
                move.w  #TILE*FOC,d4            ; a tile, in pixels
                ext.l   d4
                divs    d7,d4
                move.l  bv_rpat,a0
                bsr     rect_pat
.x:             movem.l (sp)+,d0-d7/a0
                rts
