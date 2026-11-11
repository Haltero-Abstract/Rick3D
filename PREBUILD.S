;=====================================================================
; PREBUILD.S - ALL THE SCREENS OF THE LEVEL BUILT AT LOADING
;   (included by RICK3D.S at the end of the code ; settings PRE_* in PARAMS.S)
;
; Fixed screens (no scrolling) : the columns of screens are 32 tiles wide
; (check_window) and the rows are put on a grid of PRE_STEP rows (pre_snap :
; the row chosen keeps Rick inside, see check_window). At the loading of a
; level, every screen of that grid with something else than rock is built
; once (scenery + front faces, without the canisters) in a block of memory
; (Malloc), with, for the screens with breakable plates ('B'), the same
; screen without its plates. A screen change is then a copy (no build) ;
; a bomb takes the area of the broken plates from the screen without them.
; Not enough memory : the screens are built during the game (BGBUILD.S),
; with a message in the text bar.
;=====================================================================

                rsreset                         ; --- a screen built
PE_BUF          rs.l    1               ; its scenery
PE_VAR          rs.l    1               ; the same without its plates (0 none)
PE_MAP          rs.l    1               ; its tiles (32 x 24) when built
PE_TX           rs.w    1
PE_TY           rs.w    1
PE_DIRTY        rs.w    1               ; 1 : map changed, no longer right
PE_SIZE         rs.b    0

;---------------------------------------------------------------------
; pre_free : the block is given back (new level, quit)
pre_free:
                movem.l d0-d2/a0-a2,-(sp)
                clr.w   pre_on
                move.l  pre_mem,d0
                beq.s   .x
                clr.l   pre_mem
                move.l  d0,-(sp)                ; Mfree
                move.w  #$49,-(sp)
                trap    #1
                addq.l  #6,sp
.x:             movem.l (sp)+,d0-d2/a0-a2
                rts

; pre_rowty : d1 = row of the grid -> d1 = its first line (ty)
pre_rowty:
                mulu    #PRE_STEP,d1
                move.l  d0,-(sp)
                move.w  lev_h,d0
                sub.w   #SCR_TH,d0
                bpl.s   .a
                moveq   #0,d0
.a:             cmp.w   d0,d1
                ble.s   .x
                move.w  d0,d1
.x:             move.l  (sp)+,d0
                rts

; pre_count : -> pre_n screens (and their tx / ty), pre_nb with plates
pre_count:
                movem.l d0-d7/a0,-(sp)
                clr.w   pre_n
                clr.w   pre_nb
                move.w  lev_h,d7                ; rows of the grid :
                sub.w   #SCR_TH,d7              ;  (lev_h - 24) / STEP + 1,
                bpl.s   .r0                     ;  + 1 if it does not fall
                moveq   #0,d7                   ;  exactly on the last one
.r0:            move.w  d7,pre_tymax            ; (last first line)
                ext.l   d7
                divu    #PRE_STEP,d7
                move.l  d7,d0
                swap    d0
                tst.w   d0
                beq.s   .r1
                addq.w  #1,d7
.r1:            addq.w  #1,d7
                move.w  d7,pre_rows
                move.w  lev_w,d6                ; columns : (lev_w + 31) / 32
                add.w   #SCR_TW-1,d6
                lsr.w   #5,d6
                move.w  d6,pre_cols
                lea     pre_ents,a0
                moveq   #0,d4                   ; column
.c:             moveq   #0,d5                   ; row of the grid
.r:             move.w  d5,d1
                bsr     pre_rowty
                move.w  d4,d0
                lsl.w   #5,d0                   ; tx
                movem.w d0-d1,-(sp)
                bsr     pre_scan                ; d2 : 0 rock only, 1, 2 plates
                movem.w (sp)+,d0-d1
                tst.w   d2
                beq.s   .n
                cmp.w   #PRE_MAX,pre_n
                bhs.s   .n
                move.w  d0,PE_TX(a0)
                move.w  d1,PE_TY(a0)
                clr.l   PE_VAR(a0)
                clr.w   PE_DIRTY(a0)
                cmp.w   #2,d2
                bne.s   .nb
                move.l  #1,PE_VAR(a0)           ; (one to build)
                addq.w  #1,pre_nb
.nb:            lea     PE_SIZE(a0),a0
                addq.w  #1,pre_n
.n:             addq.w  #1,d5
                cmp.w   d7,d5
                blt.s   .r
                addq.w  #1,d4
                cmp.w   d6,d4
                blt.s   .c
                movem.l (sp)+,d0-d7/a0
                rts

; pre_scan : d0/d1 = tx / ty -> d2 = 0 rock only ('#', 'F'), 1 something,
;   2 with plates
pre_scan:
                movem.l d0-d1/d3-d5,-(sp)
                moveq   #0,d5
                move.w  d0,d3
                move.w  d1,d4
                moveq   #SCR_TH-1,d1
.y:             moveq   #SCR_TW-1,d0
.x:             movem.w d0-d1,-(sp)
                add.w   d3,d0
                add.w   d4,d1
                jsr     tile_at
                movem.w (sp)+,d0-d1
                cmp.b   #'#',d2
                beq.s   .n
                cmp.b   #'F',d2
                beq.s   .n
                tst.w   d5
                bne.s   .b
                moveq   #1,d5
.b:             cmp.b   #'B',d2
                bne.s   .n
                moveq   #2,d5
.n:             dbra    d0,.x
                dbra    d1,.y
                move.w  d5,d2
                movem.l (sp)+,d0-d1/d3-d5
                rts

;---------------------------------------------------------------------
; pre_load : (start_level) counts, allocates and builds all the screens
pre_load:
                movem.l d0-d7/a0-a6,-(sp)
                bsr     pre_free
                clr.w   pre_nomem
                ifeq    PRE_MODE
                bra     .x
                endif
                jsr     bg_reset                ; (background build : buffers
                move.l  #bg_noit,bg_noitp       ;  as at the start)
                move.l  #bgnext,bgs_buf
                move.l  #bgnext2,bgs_buf+4
                move.l  #bgnext3,bgs_buf+8
                bsr     pre_count
                tst.w   pre_n
                beq     .x
                moveq   #0,d0                   ; size : screens, tiles,
                move.w  pre_n,d0                ;  screens without plates
                mulu    #SCRSZ/16,d0
                lsl.l   #4,d0
                moveq   #0,d1
                move.w  pre_n,d1
                mulu    #SCR_TW*SCR_TH,d1
                add.l   d1,d0
                moveq   #0,d1
                move.w  pre_nb,d1
                mulu    #SCRSZ/16,d1
                lsl.l   #4,d1
                add.l   d1,d0
                move.l  d0,d7                   ; d7 = size
                move.l  #-1,-(sp)               ; Malloc(-1) : largest block
                move.w  #$48,-(sp)
                trap    #1
                addq.l  #6,sp
                sub.l   #PRE_RESERVE,d0
                cmp.l   d7,d0
                blt     .nomem
                move.l  d7,-(sp)                ; Malloc
                move.w  #$48,-(sp)
                trap    #1
                addq.l  #6,sp
                tst.l   d0
                beq     .nomem
                move.l  d0,pre_mem
                move.l  d0,a1                   ; --- pointers
                lea     pre_ents,a0
                move.w  pre_n,d6
                subq.w  #1,d6
.p:             move.l  a1,PE_BUF(a0)
                add.l   #SCRSZ,a1
                tst.l   PE_VAR(a0)
                beq.s   .p1
                move.l  a1,PE_VAR(a0)
                add.l   #SCRSZ,a1
.p1:            move.l  a1,PE_MAP(a0)
                lea     SCR_TW*SCR_TH(a1),a1
                lea     PE_SIZE(a0),a0
                dbra    d6,.p
                ; --- building, with a progress bar (the music goes on :
                ;     3D by the 030, the DSP stays free for it)
                movem.w win_tx,d0-d3            ; (window kept)
                movem.w d0-d3,-(sp)
                move.w  d3don,-(sp)
                clr.w   d3don
                move.w  pre_n,d6
                add.w   pre_nb,d6
                move.w  d6,pre_tot
                clr.w   pre_done
                move.l  scr0,a0                 ; both screens black
                bsr     pre_clr
                move.l  scr1,a0
                bsr     pre_clr
                bsr     pre_task
                move.w  (sp)+,d3don
                movem.w (sp)+,d0-d3
                movem.w d0-d3,win_tx
                move.w  #1,pre_on
                bra.s   .x
.nomem:         move.w  #1,pre_nomem            ; (message in the game)
                move.l  #t_prenomem,msg_ptr
                move.w  #MSG_DUR*3,msg_t
.x:             movem.l (sp)+,d0-d7/a0-a6
                rts

; pre_setwin : d0 / d1 = tx / ty -> win_tx .. win_oy
pre_setwin:
                move.w  d0,win_tx
                move.w  d1,win_ty
                lsl.w   #3,d0
                add.w   #OX,d0
                move.w  d0,win_ox
                lsl.w   #3,d1
                add.w   #OY,d1
                move.w  d1,win_oy
                rts

; pre_task : builds all the screens of pre_ents (progress bar between them)
pre_task:
                movem.l d0-d7/a0-a6,-(sp)
                lea     pre_ents,a5
                move.w  pre_n,d7
                subq.w  #1,d7
.b:             bsr     pre_show
                move.w  PE_TX(a5),d0
                move.w  PE_TY(a5),d1
                bsr     pre_setwin
                move.l  PE_MAP(a5),a0
                jsr     bg_snapmap
                move.l  PE_BUF(a5),a6
                bsr     pre_build1
                addq.w  #1,pre_done
                move.l  PE_VAR(a5),d0
                beq.s   .nv
                move.l  d0,a6                   ; the same without its plates
                move.w  #1,bg_nob
                bsr     pre_build1
                clr.w   bg_nob
                addq.w  #1,pre_done
.nv:            lea     PE_SIZE(a5),a5
                dbra    d7,.b
                movem.l (sp)+,d0-d7/a0-a6
                rts

; pre_show : text + progress bar in the text bar of the 2 screens
pre_show:
                movem.l d0-d7/a0-a6,-(sp)
                move.w  txt_y,-(sp)             ; --- message in the middle
                move.w  #PRE_MSGY,txt_y
                lea     linebuf,a0
                move.w  #2*LINEW-1,d0
.s2:            move.b  #' ',(a0)+
                dbra    d0,.s2
                lea     linebuf+(COLS-14)/2,a0
                lea     t_prew,a1
                jsr     puts
                lea     linebuf+LINEW+(COLS-18)/2,a0
                lea     t_prec,a1
                jsr     puts
                bsr     pre_band
                move.w  (sp)+,txt_y
                lea     linebuf,a0              ; --- progress at the bottom
                move.w  #2*LINEW-1,d0
.sp:            move.b  #' ',(a0)+
                dbra    d0,.sp
                lea     linebuf+1,a0
                lea     t_preb,a1
                jsr     puts
                move.w  pre_done,d0
                jsr     fmtnum
                jsr     puts
                move.b  #'/',(a0)+
                move.w  pre_tot,d0
                jsr     fmtnum
                jsr     puts
                lea     linebuf+LINEW+1,a0      ; bar : COLS-2 characters
                move.w  pre_done,d0
                mulu    #COLS-2,d0
                divu    pre_tot,d0
                subq.w  #1,d0
                bmi.s   .nb
.bar:           move.b  #'#',(a0)+
                dbra    d0,.bar
.nb:            bsr     pre_band
                movem.l (sp)+,d0-d7/a0-a6
                rts

; pre_clr : screen a0 black
pre_clr:
                move.w  #SCRSZ/16-1,d0
                moveq   #0,d1
.l:             move.l  d1,(a0)+
                move.l  d1,(a0)+
                move.l  d1,(a0)+
                move.l  d1,(a0)+
                dbra    d0,.l
                rts

; pre_band : linebuf -> band at txt_y of the 2 screens (black under it)
pre_band:
                move.w  txt_y,d0
                mulu    #LINEB,d0
                lea     bgbuf,a0
                adda.l  d0,a0
                move.w  #BAND_H*LINEB/4-1,d0
.cl:            clr.l   (a0)+
                dbra    d0,.cl
                move.l  scr0,a6
                jsr     draw_band
                move.l  scr1,a6
                jsr     draw_band
                rts

; pre_build1 : scenery + front faces of the window in a6
pre_build1:
                movem.l d0-d7/a0-a6,-(sp)
                clr.w   clip_y0
                move.w  #SCR_H-1,clip_y1
                jsr     bld_head
                moveq   #0,d0
                moveq   #0,d1
                moveq   #SCR_TW-1,d2
                moveq   #SCR_TH-1,d3
                jsr     bld_front
                movem.l (sp)+,d0-d7/a0-a6
                rts

;---------------------------------------------------------------------
; pre_find : d0 / d1 = screen -> a0 = its entry (Z = 0), or Z = 1 none
pre_find:
                movem.l d2,-(sp)
                lea     pre_ents,a0
                move.w  pre_n,d2
                bra.s   .n
.l:             cmp.w   PE_TX(a0),d0
                bne.s   .s
                cmp.w   PE_TY(a0),d1
                beq.s   .y
.s:             lea     PE_SIZE(a0),a0
.n:             dbra    d2,.l
                movem.l (sp)+,d2
                moveq   #0,d2                   ; (Z = 1)
                rts
.y:             movem.l (sp)+,d2
                tst.l   PE_BUF(a0)              ; (Z = 0)
                rts

; pre_take : (bg_take) Z = 1 : the screen win_tx / win_ty is built : copied
;   to bgbuf, its buffer is the scenery without the canisters, its tiles
pre_take:
                tst.w   pre_on
                beq.s   .no
                movem.l d0-d1/a0-a1,-(sp)
                move.w  win_tx,d0
                move.w  win_ty,d1
                bsr     pre_find
                beq.s   .no2
                tst.w   PE_DIRTY(a0)
                bne.s   .no2
                move.l  PE_BUF(a0),a1
                move.l  a1,bg_noitp
                jsr     bg_copy
                move.l  PE_MAP(a0),a0
                lea     cur_map,a1
                move.w  #SCR_TW*SCR_TH/4-1,d0
.cm:            move.l  (a0)+,(a1)+
                dbra    d0,.cm
                addq.w  #1,bg_nh                ; (log : hits)
                movem.l (sp)+,d0-d1/a0-a1
                moveq   #0,d0                   ; Z = 1
                rts
.no2:           movem.l (sp)+,d0-d1/a0-a1
.no:            moveq   #1,d0
                rts

; pre_snap : (check_window, fixed screens) d0 / d1 = new screen : the row
;   of the grid nearest to d1 where Rick is inside (head row >= 1, feet
;   row <= SCR_TH-3)
pre_snap:
                tst.w   pre_on
                beq.s   .x
                tst.w   sc_on
                bne.s   .x
                movem.l d0/d2-d7,-(sp)
                move.w  rick_yf,d2
                asr.w   #3,d2
                move.w  d2,d3
                asr.w   #3,d2                   ; d2 = head row (level)
                add.w   rk_h,d3
                subq.w  #1,d3
                asr.w   #3,d3                   ; d3 = feet row
                move.w  #32767,d5               ; best distance
                move.w  d1,d6                   ; best row
                moveq   #0,d4                   ; row of the grid
.l:             move.w  d4,d7                   ; d7 = its first line
                mulu    #PRE_STEP,d7
                cmp.w   pre_tymax,d7
                ble.s   .k
                move.w  pre_tymax,d7
.k:             move.w  d2,d0                   ; head - ty >= 1 ?
                sub.w   d7,d0
                cmp.w   #1,d0
                blt.s   .n
                move.w  d3,d0                   ; feet - ty <= SCR_TH-3 ?
                sub.w   d7,d0
                cmp.w   #SCR_TH-3,d0
                bgt.s   .n
                move.w  d7,d0                   ; distance to d1
                sub.w   d1,d0
                bpl.s   .a
                neg.w   d0
.a:             cmp.w   d5,d0
                bge.s   .n
                move.w  d0,d5
                move.w  d7,d6
.n:             addq.w  #1,d4
                cmp.w   pre_rows,d4
                blt.s   .l
                move.w  d6,d1
                movem.l (sp)+,d0/d2-d7
.x:             rts

;---------------------------------------------------------------------
; pre_bomb : (bg_dirty) the map changed : every screen built is checked :
;   area of the broken plates taken from its screen without plates when
;   exact (as bg_nobuse), otherwise marked to build again (PE_DIRTY).
;   -> d0 = 0 : the current screen done (bgbuf, both screens), 1 : the
;   current screen did not change, 2 : it changed and is not done
pre_bomb:
                movem.l d1-d7/a0-a5,-(sp)
                movem.w win_tx,d0-d3            ; (window of the game)
                movem.w d0-d3,pre_wsave
                moveq   #1,d0
                move.w  d0,pre_res
                lea     pre_ents,a5
                move.w  pre_n,pre_cnt           ; (d4-d7 : the changes)
.e:             move.w  PE_TX(a5),d0            ; (only the screens near the
                move.w  bomb_x,d2               ;  bomb : PRE_NEAR tiles)
                asr.w   #3,d2
                sub.w   d0,d2                   ; bomb column - tx
                cmp.w   #-PRE_NEAR,d2
                blt     .n
                cmp.w   #SCR_TW+PRE_NEAR,d2
                bgt     .n
                move.w  PE_TY(a5),d1
                move.w  bomb_y,d2
                asr.w   #3,d2
                sub.w   d1,d2
                cmp.w   #-PRE_NEAR,d2
                blt     .n
                cmp.w   #SCR_TH+PRE_NEAR,d2
                bgt     .n
                bsr     pre_setwin
                move.l  PE_MAP(a5),a1
                bsr     pre_diff                ; d4-d7 : changes, N : none
                bmi     .n
                movem.w d4-d7,bg_px0
                move.w  PE_TX(a5),d0            ; the current screen ?
                cmp.w   pre_wsave,d0
                bne.s   .o
                move.w  PE_TY(a5),d0
                cmp.w   pre_wsave+2,d0
                bne.s   .o
                move.w  #2,pre_res
                tst.l   PE_VAR(a5)
                beq.s   .dc
                tst.w   PE_DIRTY(a5)
                bne.s   .dc
                bsr     pre_exact
                bne.s   .dc
                movem.w pre_wsave,d0-d3         ; (game window for bg_area)
                movem.w d0-d3,win_tx
                move.l  PE_VAR(a5),a2
                move.l  PE_BUF(a5),a3           ; (its buffer, even if bgbuf
                bsr     pre_bufarea             ;  came from a full build)
                jsr     bg_area                 ; bgbuf, bg_noitp (= its buffer),
                clr.w   pre_res                 ;  canisters, both screens
                addq.w  #1,bg_nb
                bra.s   .snap
.dc:            move.w  #1,PE_DIRTY(a5)
                bra.s   .snap
.o:             tst.l   PE_VAR(a5)              ; another screen
                beq.s   .d
                tst.w   PE_DIRTY(a5)
                bne.s   .d
                bsr     pre_exact
                bne.s   .d
                move.l  PE_VAR(a5),a2           ; area : its buffer only
                move.l  PE_BUF(a5),a3
                bsr     pre_bufarea
                bra.s   .snap
.d:             move.w  #1,PE_DIRTY(a5)
.snap:          move.w  PE_TX(a5),d0            ; its tiles now
                move.w  PE_TY(a5),d1
                bsr     pre_setwin
                move.l  PE_MAP(a5),a0
                jsr     bg_snapmap
.n:             lea     PE_SIZE(a5),a5
                subq.w  #1,pre_cnt
                bne     .e
                movem.w pre_wsave,d0-d3
                movem.w d0-d3,win_tx
                move.w  pre_res,d0
                movem.l (sp)+,d1-d7/a0-a5
                tst.w   d0
                rts

; pre_diff : (window set) tiles vs (a1) -> d4-d7 bounding box, N if none
;   (read in the map directly : fast ; outside the map : '#')
pre_diff:
                movem.l d0-d3/a0-a2,-(sp)
                move.w  #32767,d4
                move.w  #32767,d5
                moveq   #-1,d6
                moveq   #-1,d7
                moveq   #0,d1
.y:             move.w  win_ty,d3               ; a2 -> line of the map (0 : out)
                add.w   d1,d3
                sub.l   a2,a2
                cmp.w   lev_h,d3
                bhs.s   .y0
                mulu    lev_w,d3
                lea     levmap,a2
                adda.l  d3,a2
                adda.w  win_tx,a2
.y0:            moveq   #0,d0
.x:             moveq   #'#',d2
                move.l  a2,d3
                beq.s   .o
                move.w  win_tx,d3
                add.w   d0,d3
                cmp.w   lev_w,d3
                bhs.s   .o
                move.b  (a2,d0.w),d2
.o:             cmp.b   (a1)+,d2
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
                blt     .y
                movem.l (sp)+,d0-d3/a0-a2
                tst.w   d6
                rts

; pre_exact : (window set, a5 = entry, d4-d7 = changes) Z = 1 if the
;   changed tiles were plates and no plate is left within 3 tiles
pre_exact:
                movem.l d0-d3/a0,-(sp)
                move.l  PE_MAP(a5),a0
                move.w  d5,d1
.cy:            move.w  d4,d0
.cx:            move.w  d1,d3
                mulu    #SCR_TW,d3
                add.w   d0,d3
                move.b  (a0,d3.w),d3            ; old tile
                jsr     scell
                cmp.b   d3,d2
                beq.s   .cn
                cmp.b   #'B',d3
                bne.s   .no
.cn:            addq.w  #1,d0
                cmp.w   d6,d0
                ble.s   .cx
                addq.w  #1,d1
                cmp.w   d7,d1
                ble.s   .cy
                move.w  d5,d1
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
                movem.l (sp)+,d0-d3/a0
                moveq   #0,d0                   ; Z = 1
                rts
.no:            movem.l (sp)+,d0-d3/a0
                moveq   #1,d0
                rts

; pre_bufarea : area bg_px0..bg_py1 (+ 2 tiles) of a2 -> a3 (buffers only)
pre_bufarea:
                movem.l d0-d5/a0-a1,-(sp)
                movem.w bg_px0,d0-d3
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
                move.w  d1,d4
                mulu    #LINEB,d4
                add.w   d0,d0
                add.w   d0,d4                   ; (< 64 KB + ...)
                ext.l   d0
                move.w  d1,d4
                mulu    #LINEB,d4
                add.l   d0,d4
                lea     (a2,d4.l),a0
                lea     (a3,d4.l),a1
                lsr.w   #1,d0
                sub.w   d0,d2                   ; width - 1
                sub.w   d1,d3                   ; height - 1
.ly:            move.w  d2,d5
                movem.l a0-a1,-(sp)
.lx:            move.w  (a0)+,(a1)+
                dbra    d5,.lx
                movem.l (sp)+,a0-a1
                lea     LINEB(a0),a0
                lea     LINEB(a1),a1
                dbra    d3,.ly
                movem.l (sp)+,d0-d5/a0-a1
                rts
