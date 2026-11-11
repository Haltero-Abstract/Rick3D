;=====================================================================
; BGBUILD.S - NEXT SCREEN BUILT IN THE BACKGROUND
;   (included by RICK3D.S at the end of the code ; settings BG_* in PARAMS.S)
;
; When Rick walks (or climbs / falls) towards a scrolling zone, the
; screen that will come is guessed and its scenery is built in bgnext,
; with the time left in each frame (BG_FRAME), while the game goes on : bld_head
; (DECOR.S) runs as a separate task with its own stack, and gives the
; hand back at the BGCHK points (draw_box, loops of bld_head) when its
; time is used. At the screen change, build_screen takes bgnext if it is
; the right screen (the end is done at once if needed) and only does the
; canisters and the front faces ; otherwise everything as before.
; The variables shared with the game (window, clipping, bounding box,
; draw_model...) are swapped at each change of task (bg_vtab).
;=====================================================================

; variables swapped between the game and the build (words)
bg_vtab:        dc.l    win_tx,win_ty,win_ox,win_oy,d3don
                dc.l    clip_y0,clip_y1,bb_x0,bb_y0,bb_x1,bb_y1
                dc.l    box_mask,box_tex,box_tex+2
                dc.l    mdl_ox,mdl_oy,mdl_fl,mdl_nb,zp_mode,can_rec
                dc.l    bg_nob
bg_vend:
BG_NV           equ     (bg_vend-bg_vtab)/4

; bg_swap : the variables of bg_vtab <-> bg_vsave
bg_swap:
                movem.l d0/a0-a2,-(sp)
                lea     bg_vtab,a0
                lea     bg_vsave,a1
                moveq   #BG_NV-1,d0
.l:             move.l  (a0)+,a2
                move.w  (a2),-(sp)
                move.w  (a1),(a2)
                move.w  (sp)+,(a1)+
                dbra    d0,.l
                movem.l (sp)+,d0/a0-a2
                rts

;---------------------------------------------------------------------
; bg_run : every frame (main loop) : guesses the next screen, starts the
;   build of it in a free slot (2 slots : the built screens are kept until
;   used, a new level or a rebuild), and gives it the time left in the frame
bg_run:
                ifeq    BG_ON
                rts
                endif
                movem.l d0-d7/a0-a6,-(sp)
                bsr     bg_ptrs
                move.w  rick_yf,d0              ; vertical way of Rick
                move.w  d0,d7
                sub.w   bg_py,d7
                move.w  d0,bg_py
                tst.w   view_back
                bne     .x
                tst.w   rick_dead
                bne     .x
                tst.w   win_tx
                bmi     .x
                tst.w   bg_patch                ; plates broken : the current
                beq.s   .ng                     ;  screen first (bg_dirty)
                move.w  bg_pslot,d2
                add.w   d2,d2
                lea     bgs_st,a0
                cmp.w   #2,(a0,d2.w)
                bne.s   .gp
                bsr     bg_apply                ; built : the area is patched
                bra     .x
.gp:            move.l  #BG_FRAMEP,d4           ; (more time for it)
                bra     .go2
.ng:            tst.w   pre_on                  ; (all built at the loading :
                bne     .x                      ;  nothing to guess)
                tst.w   bg_cur                  ; screen without its plates :
                bpl.s   .ng2                    ;  before the neighbours
                bsr     bg_nobneed
                beq.s   .ng2
                moveq   #2,d2
                move.w  win_tx,d0
                move.w  win_ty,d1
                bsr     bg_start
                bra     .go
.ng2:           bsr     bg_guess
                tst.w   d0
                bmi.s   .go                     ; nothing guessed : goes on
                cmp.w   bg_gx,d0                ; same guess for how long ?
                bne.s   .chg
                cmp.w   bg_gy,d1
                bne.s   .chg
                cmp.w   #999,bg_gn
                bhs.s   .st
                addq.w  #1,bg_gn
                bra.s   .st
.chg:           move.w  d0,bg_gx
                move.w  d1,bg_gy
                clr.w   bg_gn
.st:            bsr     bg_find                 ; already built / being built ?
                bpl.s   .go
                tst.w   bg_cur                  ; another one being built : it
                bpl.s   .go                     ;  is finished first (no restart)
                cmp.w   #BG_STABLE,bg_gn        ; (the guess must stay the same
                blo.s   .go                     ;  BG_STABLE frames)
                bsr     bg_slot                 ; d2 = slot to use
                bsr     bg_start
.go:            move.l  #BG_FRAME,d4
                cmp.w   #2,bg_cur               ; (screen without plates while a
                bne.s   .go2                    ;  bomb burns : more time)
                tst.w   bomb_st
                beq.s   .go2
                move.l  #BG_FRAMEP,d4
.go2:           tst.w   bg_cur
                bmi.s   .x
                jsr     prof_now                ; time left in this frame
                sub.l   bg_fst,d0
                move.l  d4,d1
                sub.l   d0,d1
                cmp.l   #BG_MIN,d1
                blt.s   .x                      ; (too little : next frame)
                move.l  d1,bg_bud
                bsr     bg_resume
.x:             movem.l (sp)+,d0-d7/a0-a6
                rts

; bg_find : d0/d1 = screen -> d2 = its slot (state 1 or 2), -1 none (N)
bg_find:
                moveq   #1,d2
.l:             move.w  d2,d3
                add.w   d3,d3
                lea     bgs_st,a0
                tst.w   (a0,d3.w)
                beq.s   .n
                lea     bgs_tx,a0
                cmp.w   (a0,d3.w),d0
                bne.s   .n
                lea     bgs_ty,a0
                cmp.w   (a0,d3.w),d1
                beq.s   .x
.n:             dbra    d2,.l
.x:             tst.w   d2
                rts

; bg_slot : -> d2 = slot for a new build : a free one, else the oldest
bg_slot:
                lea     bgs_st,a0
                moveq   #0,d2
                tst.w   (a0)
                beq.s   .x
                moveq   #1,d2
                tst.w   2(a0)
                beq.s   .x
                move.w  bg_lru,d2               ; both built : the oldest
.x:             move.w  d2,d3
                eor.w   #1,d3
                move.w  d3,bg_lru               ; (the other is the oldest now)
                rts

; bg_fmark : (main loop, just after the flip) start of the frame
bg_fmark:
                movem.l d0-d1,-(sp)
                jsr     prof_now
                move.l  d0,bg_fst
                movem.l (sp)+,d0-d1
                rts

; bg_guess : d7 = vertical move -> d0/d1 = next screen (tiles), d0 = -1 none
;   (same steps as check_window, RICK.S)
bg_guess:
                tst.w   sc_on
                beq     bg_gflip
                move.w  rick_xf,d4
                asr.w   #3,d4                   ; d4 = left of Rick
                move.w  d4,d3
                add.w   #RICK_W,d3              ; d3 = right
                move.w  win_tx,d2
                lsl.w   #3,d2                   ; d2 = left edge of the screen
                move.w  win_tx,d0
                move.w  win_ty,d1
                tst.w   sc_mv
                ble.s   .l
                move.w  d2,d6                   ; --- going right
                add.w   #(SCR_TW-SC_EDGE-BG_PRE)*TILE,d6
                cmp.w   d6,d3
                ble.s   .v
                move.w  lev_w,d6
                sub.w   #SCR_TW,d6
                cmp.w   d6,d0
                bge.s   .v
                add.w   #SC_STEP,d0
                cmp.w   d6,d0
                ble.s   .ok
                move.w  d6,d0
                bra.s   .ok
.l:             tst.w   sc_mv
                bpl.s   .v
                move.w  d2,d6                   ; --- going left
                add.w   #(SC_EDGE+BG_PRE)*TILE,d6
                cmp.w   d6,d4
                bge.s   .v
                tst.w   d0
                ble.s   .v
                sub.w   #SC_STEP,d0
                bpl.s   .ok
                moveq   #0,d0
                bra.s   .ok
.v:             move.w  rick_yf,d5              ; --- vertically
                asr.w   #3,d5
                tst.w   d7
                beq.s   .no
                bmi.s   .up
                add.w   rk_h,d5                 ; going down : row of the feet
                subq.w  #1,d5
                asr.w   #3,d5
                sub.w   d1,d5
                cmp.w   #SCR_TH-1-SC_VEDGE-BG_PRE/2,d5
                ble.s   .no
                move.w  lev_h,d6
                sub.w   #SCR_TH,d6
                cmp.w   d6,d1
                bge.s   .no
                add.w   #SC_VSTEP,d1
                cmp.w   d6,d1
                ble.s   .ok
                move.w  d6,d1
                bra.s   .ok
.up:            asr.w   #3,d5                   ; going up : row of the head
                sub.w   d1,d5
                cmp.w   #SC_VEDGE+BG_PRE/2,d5
                bge.s   .no
                tst.w   d1
                ble.s   .no
                sub.w   #SC_VSTEP,d1
                bpl.s   .ok
                moveq   #0,d1
.ok:            rts
.no:            moveq   #-1,d0
                rts

; bg_gflip : the same for the fixed screens (no scrolling), guessed from
;   the way Rick moves, wherever he is : on a ladder (or falling) : the
;   screen above / below (check_window puts Rick 2 rows from the top going
;   down, 4 rows from the bottom going up ; +-1 row : see bg_snap) ;
;   walking : the screen on the left / right ; standing : no change
bg_gflip:
                move.w  win_tx,d0
                move.w  win_ty,d1
                tst.w   d7
                beq.s   .h
                tst.w   on_ladder               ; vertically : on a ladder,
                bne.s   .v                      ;  or falling (not a jump)
                tst.w   on_ground
                bne.s   .h
                tst.w   d7
                bmi.s   .h
                cmp.w   #8*4,rick_vy
                blt.s   .h
.v:             tst.w   d7
                bmi.s   .up
                add.w   #SCR_TH-6,d1            ; (head on row 20 -> row 2)
                bra.s   .cl
.up:            sub.w   #SCR_TH-6,d1            ; (feet on row 2 -> row 20)
.cl:            move.w  lev_h,d6                ; (same limits)
                sub.w   #SCR_TH,d6
                cmp.w   d6,d1
                ble.s   .c1
                move.w  d6,d1
.c1:            tst.w   d1
                bpl.s   .c2
                moveq   #0,d1
.c2:            cmp.w   win_ty,d1
                beq.s   .no
                rts
.h:             tst.w   sc_mv                   ; walking
                beq.s   bg_gnear
                bmi.s   .l
                add.w   #SCR_TW,d0              ; right
                move.w  lev_w,d6
                sub.w   #SCR_TW-1,d6
                cmp.w   d6,d0
                bge.s   bg_gnear
                rts
.l:             sub.w   #SCR_TW,d0              ; left
                bmi.s   bg_gnear
                rts
.no:            bra     bg_gnear

; bg_gnear : nothing clear : the neighbour on the side of the nearest edge
;   of the screen (built once, then nothing to do while it stays the same)
bg_gnear:
                move.w  rick_xf,d4
                asr.w   #3,d4                   ; d4 = left of Rick (units)
                move.w  win_tx,d2
                lsl.w   #3,d2
                sub.w   d2,d4                   ; d4 = distance to the left edge
                move.w  #SCR_TW*TILE-RICK_W,d5
                sub.w   d4,d5                   ; d5 = to the right edge
                move.w  rick_yf,d6
                asr.w   #3,d6
                move.w  win_ty,d2
                lsl.w   #3,d2
                sub.w   d2,d6                   ; d6 = to the top
                move.w  #SCR_TH*TILE,d7
                sub.w   rk_h,d7
                sub.w   d6,d7                   ; d7 = to the bottom
                move.w  win_tx,d0
                move.w  win_ty,d1
                moveq   #0,d2                   ; d2 = side : 0 L 1 R 2 U 3 D
                move.w  d4,d3                   ; d3 = smallest distance
                tst.w   d0                      ; (no screen on that side :
                bgt.s   .a                      ;  not taken)
                move.w  #32767,d3
.a:             move.w  lev_w,d4
                sub.w   #SCR_TW*2,d4
                cmp.w   d4,d0
                bgt.s   .b
                cmp.w   d3,d5
                bge.s   .b
                move.w  d5,d3
                moveq   #1,d2
.b:             tst.w   d1
                ble.s   .c
                cmp.w   d3,d6
                bge.s   .c
                move.w  d6,d3
                moveq   #2,d2
.c:             move.w  lev_h,d4
                sub.w   #SCR_TH,d4
                cmp.w   d4,d1
                bge.s   .d
                cmp.w   d3,d7
                bge.s   .d
                move.w  d7,d3
                moveq   #3,d2
.d:             cmp.w   #32767,d3
                beq.s   .no
                add.w   d2,d2
                move.w  .j(pc,d2.w),d2
                jmp     .j(pc,d2.w)
.j:             dc.w    .gl-.j,.gr-.j,.gu-.j,.gd-.j
.gl:            sub.w   #SCR_TW,d0
                rts
.gr:            add.w   #SCR_TW,d0
                rts
.gu:            sub.w   #SCR_TH-6,d1
                bpl.s   .x
                moveq   #0,d1
.x:             rts
.gd:            add.w   #SCR_TH-6,d1
                cmp.w   d4,d1
                ble.s   .x
                move.w  d4,d1
                rts
.no:            moveq   #-1,d0
                rts

; bg_start : d0/d1 = screen, d2 = slot -> new build task (its stack,
;   its variables)
bg_start:
                movem.l d0-d3/a0-a1,-(sp)
                move.w  d2,bg_cur
                move.w  d2,d3
                add.w   d3,d3
                lea     bgs_tx,a0
                move.w  d0,(a0,d3.w)
                lea     bgs_ty,a0
                move.w  d1,(a0,d3.w)
                lea     bgs_st,a0
                move.w  #1,(a0,d3.w)
                add.w   d3,d3
                lea     bgs_buf,a0
                move.l  (a0,d3.w),bg_tbuf
                lea     bgt_stack_end,a0         ; stack : return address
                move.l  #bg_task,-(a0)          ;  (bg_task) + 15 registers
                moveq   #14,d2
.r:             clr.l   -(a0)
                dbra    d2,.r
                move.l  a0,bg_tsp
                lea     bg_vsave,a1             ; its variables (order of bg_vtab)
                move.w  d0,(a1)+                ; win_tx
                move.w  d1,(a1)+                ; win_ty
                lsl.w   #3,d0
                add.w   #OX,d0
                move.w  d0,(a1)+                ; win_ox
                lsl.w   #3,d1
                add.w   #OY,d1
                move.w  d1,(a1)+                ; win_oy
                ifeq    BLD_DSP
                clr.w   (a1)+                   ; d3don : 3D by the 030
                else
                move.w  d3don,(a1)+
                endif
                clr.w   (a1)+                   ; clip_y0
                move.w  #SCR_H-1,(a1)+          ; clip_y1
                move.w  #32767,(a1)+            ; bb
                move.w  #32767,(a1)+
                move.w  #-32768,(a1)+
                move.w  #-32768,(a1)+
                move.w  #15,(a1)+               ; box_mask
                clr.l   (a1)+                   ; box_tex
                clr.l   (a1)+                   ; mdl_ox, mdl_oy
                clr.l   (a1)+                   ; mdl_fl, mdl_nb
                clr.l   (a1)+                   ; zp_mode, can_rec
                cmp.w   #2,bg_cur               ; bg_nob : slot 2 = the screen
                seq     d3                      ;  without its plates
                ext.w   d3
                move.w  d3,(a1)+
                movem.l (sp)+,d0-d3/a0-a1
                rts

; bg_task : the build task itself
bg_task:
                move.w  bg_cur,d0               ; tiles of this screen (bg_dirty)
                mulu    #SCR_TW*SCR_TH,d0
                lea     bgs_map,a0
                adda.l  d0,a0
                bsr     bg_snapmap
                move.l  bg_tbuf,a6
                jsr     bld_head
                moveq   #0,d0                   ; + the front faces (the canisters
                moveq   #0,d1                   ;  are drawn at the change, and
                moveq   #SCR_TW-1,d2            ;  the front faces again over them)
                moveq   #SCR_TH-1,d3
                jsr     bld_front
                move.w  bg_cur,d0               ; done
                add.w   d0,d0
                lea     bgs_st,a0
                move.w  #2,(a0,d0.w)
                move.w  #-1,bg_cur
.w:             bsr.s   bg_yield                ; (never resumed when done)
                bra.s   .w

; bg_resume : (game) gives the hand to the task until its time is used
bg_resume:
                movem.l d0-d7/a0-a6,-(sp)
                move.l  sp,bg_msp
                jsr     prof_now
                move.l  d0,bg_t0
                bsr     bg_swap
                move.w  #1,bg_in
                move.l  bg_tsp,sp
                movem.l (sp)+,d0-d7/a0-a6
                rts                             ; -> into the task

; bg_yield : (task) gives the hand back to the game
bg_yield:
                movem.l d0-d7/a0-a6,-(sp)
                move.l  sp,bg_tsp
                clr.w   bg_in
                bsr     bg_swap
                move.l  bg_msp,sp
                movem.l (sp)+,d0-d7/a0-a6
                rts                             ; -> back from bg_resume

; bg_check : (task, BGCHK) time of this frame used -> pause
bg_check:
                tst.w   bg_nolimit
                bne.s   .x
                movem.l d0-d1,-(sp)
                jsr     prof_now
                sub.l   bg_t0,d0
                cmp.l   bg_bud,d0
                movem.l (sp)+,d0-d1             ; (flags kept)
                blo.s   .x
                bsr.s   bg_yield
.x:             rts

;---------------------------------------------------------------------
; bg_take : (build_screen) Z = 1 : a slot holds the screen win_tx / win_ty
;   (the end of its build is done now if needed) : it is copied to bgbuf
;   and its buffer becomes the scenery without the canisters (bg_noitp).
;   Z = 0 : not built : the build in progress is dropped, and the built
;   screens too (the full build may follow a change of the map)
bg_take:
                ifne    BG_ON
                jsr     pre_take                ; all built at the loading ?
                beq     .pre
                movem.l d1-d3/a0-a1,-(sp)
                bsr     bg_ptrs
                tst.w   bg_patch                ; (bomb area of the old screen :
                beq.s   .np                     ;  no longer needed)
                clr.w   bg_patch
                move.w  bg_pslot,d2
                add.w   d2,d2
                lea     bgs_st,a0
                clr.w   (a0,d2.w)
                move.w  bg_pslot,d2
                cmp.w   bg_cur,d2
                bne.s   .np
                move.w  #-1,bg_cur
.np:            clr.w   bgs_st+4                ; (screen without its plates :
                cmp.w   #2,bg_cur               ;  the old screen's)
                bne.s   .n2
                move.w  #-1,bg_cur
.n2:            move.w  win_tx,d0
                move.w  win_ty,d1
                bsr     bg_find
                bmi.s   .no
                move.w  d2,d3
                add.w   d3,d3
                lea     bgs_st,a0
                cmp.w   #2,(a0,d3.w)
                beq.s   .ok
                move.w  #1,bg_nolimit           ; being built : the end now
                bsr     bg_resume
                clr.w   bg_nolimit
.ok:            lea     bgs_st,a0
                clr.w   (a0,d3.w)               ; slot free again
                move.w  d2,d0                   ; (its tiles : the current ones)
                mulu    #SCR_TW*SCR_TH,d0
                lea     bgs_map,a0
                adda.l  d0,a0
                lea     cur_map,a1
                move.w  #SCR_TW*SCR_TH/4-1,d0
.cm:            move.l  (a0)+,(a1)+
                dbra    d0,.cm
                add.w   d3,d3
                lea     bgs_buf,a0
                move.l  (a0,d3.w),a1            ; built screen -> bgbuf, its
                move.l  bg_noitp,(a0,d3.w)      ;  buffer -> bg_noitp, the old
                move.l  a1,bg_noitp             ;  one -> the slot
                bsr     bg_copy
                addq.w  #1,bg_nh                ; (log : hits)
                movem.l (sp)+,d1-d3/a0-a1
                moveq   #0,d0                   ; Z = 1
                rts
.pre:           rts                             ; (Z = 1)
.no:            addq.w  #1,bg_nm                ; (log : misses : screen built,
                move.w  win_tx,bg_mx            ;  guess, slots)
                move.w  win_ty,bg_my
                bsr     bg_reset
                movem.l (sp)+,d1-d3/a0-a1
                endif
                moveq   #1,d0
                rts

; bg_reset : no build, no built screen (new level, full build)
bg_reset:
                move.w  #-1,bg_cur
                clr.l   bgs_st
                clr.w   bgs_st+4
                clr.w   bg_patch
                rts

; bg_ptrs : the buffers (1st time)
bg_ptrs:
                tst.l   bg_noitp
                bne.s   .x
                move.l  #bg_noit,bg_noitp
                move.l  #bgnext,bgs_buf
                move.l  #bgnext2,bgs_buf+4
                move.l  #bgnext3,bgs_buf+8
                move.w  #-1,bg_cur
                clr.l   bgs_st
                clr.w   bgs_st+4
.x:             rts

; bg_copy : the built screen (a1) -> bgbuf
bg_copy:
                movem.l d0-d7/a0-a5,-(sp)
                move.l  a1,a0
                lea     bgbuf,a1
                move.w  #SCRSZ/40-1,d0          ; 40 bytes per movem
.l:             movem.l (a0)+,d1-d7/a2-a4
                movem.l d1-d7/a2-a4,(a1)
                lea     40(a1),a1
                dbra    d0,.l
                movem.l (sp)+,d0-d7/a0-a5
                rts

; bg_snap : (check_window, fixed screens) d0/d1 = new screen : if a slot
;   holds the same column and a row 1-3 away where Rick is still well
;   inside the screen (head row >= 1, feet row <= SCR_TH-3), that row is
;   taken (the guess of the rows can be one off)
bg_snap:
                ifne    BG_ON
                movem.l d2-d6/a0,-(sp)
                tst.l   bg_noitp
                beq.s   .x
                tst.w   sc_on                   ; (fixed screens only)
                bne.s   .x
                moveq   #1,d2
.l:             move.w  d2,d3
                add.w   d3,d3
                lea     bgs_st,a0
                tst.w   (a0,d3.w)
                beq.s   .n
                lea     bgs_tx,a0
                cmp.w   (a0,d3.w),d0
                bne.s   .n
                lea     bgs_ty,a0
                move.w  (a0,d3.w),d4            ; d4 = its row
                move.w  d4,d5
                sub.w   d1,d5
                beq.s   .x                      ; (the same)
                bpl.s   .a
                neg.w   d5
.a:             cmp.w   #3,d5
                bhi.s   .n
                move.w  rick_yf,d5
                asr.w   #3,d5
                move.w  d5,d6
                asr.w   #3,d5
                sub.w   d4,d5                   ; head row
                ble.s   .n
                add.w   rk_h,d6
                subq.w  #1,d6
                asr.w   #3,d6
                sub.w   d4,d6                   ; feet row
                cmp.w   #SCR_TH-3,d6
                bgt.s   .n
                move.w  d4,d1                   ; taken
                addq.w  #1,bg_ns                ; (log)
                bra.s   .x
.n:             dbra    d2,.l
.x:             movem.l (sp)+,d2-d6/a0
                endif
                rts

; bg_canfront : after the canisters (draw_items_nc) : the front faces again
;   over the tiles of their boxes (ZP_BX0, screen pixels : 10 per tile)
bg_canfront:
                movem.l d0-d7/a0-a2,-(sp)
                lea     zaps,a2
                move.w  nzp,d7
                bra.s   .n
.l:             cmp.l   #2,ZP_BP(a2)            ; (box recorded)
                bls.s   .nx
                movem.w ZP_BX0(a2),d0-d3
                ext.l   d0
                divu    #TPX,d0
                ext.l   d1
                divu    #TPX,d1
                ext.l   d2
                divu    #TPX,d2
                ext.l   d3
                divu    #TPX,d3
                jsr     bld_front
.nx:            lea     ZP_SIZE(a2),a2
.n:             dbra    d7,.l
                movem.l (sp)+,d0-d7/a0-a2
                rts

;---------------------------------------------------------------------
; bg_snapmap : the tiles of the screen win_tx / win_ty -> (a0), 32 x 24
bg_snapmap:
                movem.l d0-d2/a0,-(sp)
                moveq   #0,d1
.y:             moveq   #0,d0
.x:             jsr     scell
                move.b  d2,(a0)+
                addq.w  #1,d0
                cmp.w   #SCR_TW,d0
                blt.s   .x
                addq.w  #1,d1
                cmp.w   #SCR_TH,d1
                blt.s   .y
                movem.l (sp)+,d0-d2/a0
                rts

; bg_curmap : (build_screen, full build) tiles of the screen built
bg_curmap:
                move.l  a0,-(sp)
                lea     cur_map,a0
                bsr.s   bg_snapmap
                move.l  (sp)+,a0
                rts

; bg_dirty : (main loop, items_dirty) the map changed (plates broken by a
;   bomb) : Z = 1 : no full build : the area of the changed tiles is built
;   again in the background (whole screen in a slot, then only that area is
;   copied into bgbuf, bg_noitp and the 2 screens : bg_apply) ; the built
;   screens with changed tiles are dropped. Z = 0 : nothing changed in the
;   screen (canister not recorded) : full build as before
bg_dirty:
                ifeq    BG_ON
                moveq   #1,d0
                rts
                endif
                movem.l d1-d7/a0-a2,-(sp)
                tst.w   view_back
                bne     .full
                tst.w   win_tx
                bmi     .full
                bsr     bg_ptrs
                tst.w   pre_on                  ; all built at the loading :
                beq.s   .np0                    ;  each screen checked
                jsr     pre_bomb
                beq     .done                   ; (current one done)
                cmp.w   #1,d0
                beq     .full                   ; (current one unchanged)
.np0:           move.w  #32767,d4               ; bounding box of the changes
                move.w  #32767,d5
                moveq   #-1,d6
                moveq   #-1,d7
                lea     cur_map,a0
                moveq   #0,d1
.y:             moveq   #0,d0
.x:             jsr     scell
                cmp.b   (a0)+,d2
                beq.s   .s
                cmp.w   d4,d0
                bge.s   .a
                move.w  d0,d4
.a:             cmp.w   d5,d1
                bge.s   .b
                move.w  d1,d5
.b:             cmp.w   d6,d0
                ble.s   .c
                move.w  d0,d6
.c:             cmp.w   d7,d1
                ble.s   .s
                move.w  d1,d7
.s:             addq.w  #1,d0
                cmp.w   #SCR_TW,d0
                blt.s   .x
                addq.w  #1,d1
                cmp.w   #SCR_TH,d1
                blt.s   .y
                tst.w   d6
                bmi     .full                   ; nothing changed here
                tst.w   bg_patch                ; (already one : both areas)
                beq.s   .p1
                cmp.w   bg_px0,d4
                ble.s   .p2
                move.w  bg_px0,d4
.p2:            cmp.w   bg_py0,d5
                ble.s   .p3
                move.w  bg_py0,d5
.p3:            cmp.w   bg_px1,d6
                bge.s   .p4
                move.w  bg_px1,d6
.p4:            cmp.w   bg_py1,d7
                bge.s   .p1
                move.w  bg_py1,d7
.p1:            movem.w d4-d7,bg_px0
                tst.w   bg_patch                ; (no area pending : the screen
                bne.s   .p5                     ;  without plates if ready)
                bsr     bg_nobuse
                bne.s   .p5
                move.l  bgs_buf+8,a2            ; yes : its area at once
                bsr     bg_area
                lea     cur_map,a0
                bsr     bg_snapmap
                addq.w  #1,bg_nb                ; (log)
                movem.l (sp)+,d1-d7/a0-a2
                moveq   #0,d0                   ; Z = 1
                rts
.p5:            lea     cur_map,a0              ; (the new tiles : current)
                bsr     bg_snapmap
                bsr     bg_slotcheck            ; built screens : still right ?
                tst.w   bg_cur                  ; a build in progress : dropped
                bmi.s   .nc
                addq.w  #1,bg_nr
                move.w  bg_cur,d2
                add.w   d2,d2
                lea     bgs_st,a0
                clr.w   (a0,d2.w)
                move.w  #-1,bg_cur
.nc:            bsr     bg_slot
                move.w  win_tx,d0
                move.w  win_ty,d1
                bsr     bg_start                ; this screen, in the background
                move.w  d2,bg_pslot
                move.w  #1,bg_patch
                addq.w  #1,bg_np                ; (log : patches)
                movem.l (sp)+,d1-d7/a0-a2
                moveq   #0,d0                   ; Z = 1
                rts
.done:          lea     cur_map,a0              ; (tiles of the current screen)
                bsr     bg_snapmap
                movem.l (sp)+,d1-d7/a0-a2
                moveq   #0,d0
                rts
.full:          movem.l (sp)+,d1-d7/a0-a2
                moveq   #1,d0
                rts

; bg_slotcheck : the built screens whose tiles are no longer the ones of
;   the map are dropped
bg_slotcheck:
                movem.l d0-d7/a0-a1,-(sp)
                move.w  win_tx,d6
                move.w  win_ty,d7
                moveq   #1,d3
.l:             move.w  d3,d4
                add.w   d4,d4
                lea     bgs_st,a0
                cmp.w   #2,(a0,d4.w)
                bne.s   .n
                lea     bgs_tx,a0
                move.w  (a0,d4.w),win_tx        ; (scell : its screen)
                lea     bgs_ty,a0
                move.w  (a0,d4.w),win_ty
                move.w  d3,d0
                mulu    #SCR_TW*SCR_TH,d0
                lea     bgs_map,a1
                adda.l  d0,a1
                moveq   #0,d1
.y:             moveq   #0,d0
.x:             jsr     scell
                cmp.b   (a1)+,d2
                bne.s   .drop
                addq.w  #1,d0
                cmp.w   #SCR_TW,d0
                blt.s   .x
                addq.w  #1,d1
                cmp.w   #SCR_TH,d1
                blt.s   .y
                bra.s   .n
.drop:          lea     bgs_st,a0
                clr.w   (a0,d4.w)
                addq.w  #1,bg_nr
.n:             dbra    d3,.l
                move.w  d6,win_tx
                move.w  d7,win_ty
                movem.l (sp)+,d0-d7/a0-a1
                rts

; bg_apply : the screen with the plates broken is built (slot bg_pslot) :
;   its area (changed tiles + 2 around : side faces, shadows) -> bgbuf,
;   bg_noitp, then the canisters again, and the area is erased on the 2
;   screens (no full build, no erase_full)
bg_apply:
                movem.l d0-d7/a0-a4,-(sp)
                clr.w   bg_patch
                move.w  bg_pslot,d2
                move.w  d2,d3
                add.w   d3,d3
                lea     bgs_st,a0
                clr.w   (a0,d3.w)               ; (slot free again)
                add.w   d3,d3
                lea     bgs_buf,a0
                move.l  (a0,d3.w),a2            ; a2 = built screen
                bsr.s   bg_area
                movem.l (sp)+,d0-d7/a0-a4
                rts

; bg_area : the area bg_px0..bg_py1 (tiles, + 2 around) of the built screen
;   a2 -> bgbuf, bg_noitp, canisters again, erased on the 2 screens
bg_area:
                movem.l d0-d7/a0-a4,-(sp)
                movem.w bg_px0,d0-d3            ; tiles -> pixels (10 per tile)
                subq.w  #2,d0
                bpl.s   .a
                moveq   #0,d0
.a:             subq.w  #2,d1
                bpl.s   .b
                moveq   #0,d1
.b:             addq.w  #2,d2
                cmp.w   #SCR_TW-1,d2
                ble.s   .c
                moveq   #SCR_TW-1,d2
.c:             addq.w  #2,d3
                cmp.w   #SCR_TH-1,d3
                ble.s   .d
                moveq   #SCR_TH-1,d3
.d:             mulu    #TPX,d0
                mulu    #TPX,d1
                mulu    #TPX,d2
                add.w   #TPX-1,d2
                mulu    #TPX,d3
                add.w   #TPX-1,d3
                movem.w d0-d3,-(sp)
                move.w  d1,d4                   ; copy of the rectangle
                mulu    #LINEB,d4
                move.w  d0,d5
                add.w   d5,d5
                ext.l   d5
                add.l   d5,d4
                lea     (a2,d4.l),a0
                lea     bgbuf,a1
                adda.l  d4,a1
                move.l  bg_noitp,a3
                adda.l  d4,a3
                sub.w   d0,d2                   ; width - 1
                sub.w   d1,d3                   ; height - 1
.ly:            move.w  d2,d5
                movem.l a0/a1/a3,-(sp)
.lx:            move.w  (a0),(a1)+
                move.w  (a0)+,(a3)+
                dbra    d5,.lx
                movem.l (sp)+,a0/a1/a3
                lea     LINEB(a0),a0
                lea     LINEB(a1),a1
                lea     LINEB(a3),a3
                dbra    d3,.ly
                lea     bgbuf,a6                ; canisters of the area again
                jsr     draw_items_nc
                jsr     bg_canfront
                movem.w (sp)+,d0-d3
                move.l  cur_list,-(sp)          ; area erased on both screens
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
                movem.l (sp)+,d0-d7/a0-a4
                rts

;---------------------------------------------------------------------
; THE SCREEN WITHOUT ITS PLATES (slot 2) : when the current screen has
;   breakable plates ('B') and Rick has bombs, it is built in advance
;   with every 'B' replaced (like break_group, ARMES.S) ; when a bomb breaks
;   plates, their area is taken from it at once (bg_dirty).
; bg_nobc : (tile_at, while building slot 2) 'B' -> what replaces it
bg_nobc:
                cmp.b   #'B',d2
                bne.s   .x
                moveq   #'.',d2
                move.l  d0,-(sp)
                move.w  lev_h,d0
                sub.w   #12,d0
                cmp.w   d0,d1
                blt.s   .p
                moveq   #'k',d2                 ; (park : black sky)
.p:             move.l  (sp)+,d0
.x:             rts

; bg_nobneed : Z = 0 if slot 2 must be built (plates in cur_map, bombs)
bg_nobneed:
                movem.l d0/a0,-(sp)
                tst.w   ammo_bomb
                beq.s   .no
                lea     bgs_st+4,a0             ; slot 2 : already for this screen ?
                tst.w   (a0)
                beq.s   .sc
                move.w  bgs_tx+4,d0
                cmp.w   win_tx,d0
                bne.s   .sc
                move.w  bgs_ty+4,d0
                cmp.w   win_ty,d0
                beq.s   .no
.sc:            lea     cur_map,a0              ; plates in this screen ?
                move.w  #SCR_TW*SCR_TH-1,d0
.l:             cmp.b   #'B',(a0)+
                dbeq    d0,.l
                bne.s   .no
                moveq   #1,d0                   ; Z = 0 : yes
                bra.s   .x
.no:            moveq   #0,d0                   ; Z = 1
.x:             movem.l (sp)+,d0/a0
                rts

; bg_nobuse : (bg_dirty) d4-d7 = tiles changed (screen) : Z = 1 if slot 2
;   (finished now if needed) gives their area exactly : it is for this
;   screen, the changed tiles were plates, and no plate left within 3
;   tiles of the area (slot 2 has them removed too)
bg_nobuse:
                movem.l d0-d3/a0-a2,-(sp)
                move.w  bgs_st+4,d0
                beq     .no
                move.w  bgs_tx+4,d0
                cmp.w   win_tx,d0
                bne     .no
                move.w  bgs_ty+4,d0
                cmp.w   win_ty,d0
                bne     .no
                move.w  d5,d1                   ; changed tiles : were 'B' ?
.cy:            move.w  d4,d0
.cx:            move.w  d1,d2
                mulu    #SCR_TW,d2
                add.w   d0,d2
                lea     cur_map,a0
                move.b  (a0,d2.w),d3            ; (old tile)
                jsr     scell                   ; (new tile)
                cmp.b   d3,d2
                beq.s   .cn
                cmp.b   #'B',d3
                bne     .no
.cn:            addq.w  #1,d0
                cmp.w   d6,d0
                ble.s   .cx
                addq.w  #1,d1
                cmp.w   d7,d1
                ble.s   .cy
                move.w  d5,d1                   ; plates left near the area ?
                subq.w  #3,d1
.ry:            move.w  d4,d0
                subq.w  #3,d0
.rx:            jsr     scell
                cmp.b   #'B',d2
                beq.s   .no
                addq.w  #1,d0
                move.w  d6,d2
                addq.w  #3,d2
                cmp.w   d2,d0
                ble.s   .rx
                addq.w  #1,d1
                move.w  d7,d2
                addq.w  #3,d2
                cmp.w   d2,d1
                ble.s   .ry
                cmp.w   #1,bgs_st+4             ; being built : the end now
                bne.s   .ok
                cmp.w   #2,bg_cur
                bne.s   .no
                move.w  #1,bg_nolimit
                bsr     bg_resume
                clr.w   bg_nolimit
.ok:            movem.l (sp)+,d0-d3/a0-a2
                moveq   #0,d0                   ; Z = 1
                rts
.no:            movem.l (sp)+,d0-d3/a0-a2
                moveq   #1,d0
                rts
