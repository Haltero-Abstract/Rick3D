;=====================================================================
; RICK.S - RICK : lives, respawn, moves, jump, ladders
;   (included by RICK3D.S ; the settings are in PARAMS.S)
;=====================================================================

;---------------------------------------------------------------------
; Rick loses a life : respawn, or back to the start of the level (game over)
lose_life:
                tst.w   inf_lives               ; infinite lives (I key) :
                bne     respawn                 ;  no life is lost
                subq.w  #1,lives
                bgt     respawn
                move.w  #1,game_end             ; game over : name, high scores,
                rts                             ;  menu (main_loop -> end_game)

;---------------------------------------------------------------------
; start of the level / respawn (at the entrance of the current screen)
level_start:
                move.w  st_col,d0
                lsl.w   #6,d0                   ; x 8 (tile) x 8 (1/8)
                move.w  d0,cp_xf
                move.w  st_row,d0
                lsl.w   #6,d0
                add.w   #16*8,d0                ; feet 2 tiles below the cell
                move.w  d0,cp_yf
                move.w  #-1,win_tx              ; forces the screen computation
                move.w  #NB_LIVES,lives
                clr.l   score                   ; (game over : score back to 0)
respawn:
                clr.w   las_on
                clr.w   bomb_st
                clr.w   rick_dead
                clr.w   on_ladder
                clr.w   on_ground
                clr.w   rick_vy
                move.w  #AMMO_LAS_MAX,ammo_las
                move.w  #AMMO_BOMB_MAX,ammo_bomb
                move.w  #1,rick_dir
                move.w  cp_xf,rick_xf
                move.w  cp_yf,d0
                sub.w   #RICK_H*8,d0
                move.w  d0,rick_yf
                move.w  #INVUL_N,invul_t        ; 2 s of invulnerability
                movem.l d7/a2,-(sp)
                bsr     lz_reset
                bsr     plat_reset              ; called lifts : back at the start
                movem.l (sp)+,d7/a2
                move.w  #-1,rick_onplat
                move.w  #RICK_H,rk_h
                move.w  #RICK_H/2,rk_h2
                clr.w   walk_ph
                clr.w   climb_ph
                clr.w   stick_t
                clr.w   dead_t
                move.w  #-1,rick_onplat
                bra     check_window            ; (scenery rebuilt only if
                                                ;  the screen changes)

; check_window : screen (32x24 tiles) that holds the centre of Rick ;
;   if it changes : scenery to rebuild + respawn point
check_window:
                move.w  rick_xf,d0              ; direction of the side move
                sub.w   sc_px,d0                ;  since the last time
                move.w  rick_xf,sc_px           ;  (scrolling : only if
                move.w  d0,sc_mv                ;   Rick walks towards the edge)
                move.w  rick_xf,d4
                asr.w   #3,d4                   ; d4 = x
                move.w  rick_yf,d5
                asr.w   #3,d5                   ; d5 = y (top of Rick)
                move.w  win_tx,d0
                bmi     .init
                tst.w   sc_on                   ; scrolling (G key) ?
                bne.s   .gl
                ; --- columns : fixed screens of 32 tiles, changed when
                ;     Rick has completely left
                move.w  d0,d2
                lsl.w   #3,d2                   ; left edge
                move.w  d4,d3
                add.w   #RICK_W,d3
                cmp.w   d2,d3
                ble     .hx
                add.w   #SCR_TW*TILE,d2
                cmp.w   d2,d4
                blt     .vert
                bra     .hx
                ; --- columns : the map scrolls by steps of SC_STEP
                ;     tiles when Rick gets near an edge (SC_EDGE tiles)
.gl:            move.w  d0,d2
                lsl.w   #3,d2                   ; left edge (x)
                move.w  d4,d3
                add.w   #RICK_W,d3              ; d3 = right edge of Rick
                cmp.w   d2,d3                   ; Rick off the screen (B key,
                ble.s   .hx                     ;  respawn) : recompute
                move.w  d2,d6
                add.w   #SCR_TW*TILE,d6
                cmp.w   d6,d4
                bge.s   .hx
                move.w  d2,d6                   ; near the left edge (and going
                add.w   #SC_EDGE*TILE,d6        ;  left) ?
                cmp.w   d6,d4
                bge.s   .hr
                tst.w   sc_mv
                bpl.s   .vert
                tst.w   d0
                ble.s   .vert
                sub.w   #SC_STEP,d0
                bpl.s   .vert
                moveq   #0,d0
                bra.s   .vert
.hr:            tst.w   sc_mv                   ; near the right edge (and going
                ble.s   .vert                   ;  right) ?
                move.w  d2,d6
                add.w   #(SCR_TW-SC_EDGE)*TILE,d6
                cmp.w   d6,d3
                ble.s   .vert
                move.w  lev_w,d6
                sub.w   #SCR_TW,d6
                cmp.w   d6,d0
                bge.s   .vert
                add.w   #SC_STEP,d0
                cmp.w   d6,d0
                ble.s   .vert
                move.w  d6,d0
                bra.s   .vert
.hx:            bsr     .colx
                ; --- rows : the screen follows Rick. Feet below the
                ;     bottom bar (row 22+) -> Rick at the top of the screen ;
                ;     head under the HUD (row 0) -> Rick at the bottom of the screen
.vert:          move.w  win_ty,d1
                tst.w   sc_on                   ; scrolling : steps of
                beq.s   .vs                     ;  SC_VSTEP rows near the
                move.w  d5,d2                   ;  top / bottom of the screen
                asr.w   #3,d2
                sub.w   d1,d2                   ; row of the head (screen)
                move.w  d5,d3
                add.w   rk_h,d3
                subq.w  #1,d3
                asr.w   #3,d3
                sub.w   d1,d3                   ; row of the feet (screen)
                cmp.w   #SCR_TH-1-SC_VEDGE,d3
                ble.s   .vu
                add.w   #SC_VSTEP,d1            ; near the bottom : goes down
                bra.s   .vs
.vu:            cmp.w   #SC_VEDGE,d2
                bge.s   .vs
                sub.w   #SC_VSTEP,d1            ; near the top : goes up
.vs:            move.w  d5,d2
                asr.w   #3,d2
                sub.w   d1,d2                   ; row of the head in the screen
                move.w  d5,d3
                add.w   rk_h,d3
                subq.w  #1,d3
                asr.w   #3,d3                   ; row of the feet (level)
                move.w  d3,d6
                sub.w   d1,d6                   ; ... in the screen
                cmp.w   #SCR_TH-3,d6
                ble.s   .v1
                move.w  d5,d1                   ; too low : Rick at the top
                asr.w   #3,d1
                subq.w  #2,d1
                bra.s   .clamp
.v1:            tst.w   d2
                bgt.s   .clamp
                move.w  d3,d1                   ; too high : Rick at the bottom
                sub.w   #SCR_TH-4,d1
.clamp:         move.w  lev_h,d2
                sub.w   #SCR_TH,d2
                cmp.w   d2,d1
                ble.s   .c1
                move.w  d2,d1
.c1:            tst.w   d1
                bpl.s   .c2
                moveq   #0,d1
.c2:            cmp.w   win_tx,d0
                bne.s   .new
                cmp.w   win_ty,d1
                beq     .x
.new:           clr.w   sc_glide                ; step : the screen will scroll
                clr.w   sc_vglide               ;  (main_loop), on one axis only
                tst.w   sc_on
                beq.s   .ng
                tst.w   win_tx
                bmi.s   .ng
                tst.w   rick_dead
                bne.s   .ng
                tst.w   view_back
                bne.s   .ng
                cmp.w   win_ty,d1
                bne.s   .nv
                move.w  d0,d2                   ; sideways
                sub.w   win_tx,d2
                move.w  d2,sc_glide
                bra.s   .ng
.nv:            cmp.w   win_tx,d0               ; vertically
                bne.s   .ng
                move.w  d1,d2
                sub.w   win_ty,d2
                move.w  d2,sc_vglide
.ng:            move.w  d0,win_tx
                move.w  d1,win_ty
                lsl.w   #3,d0
                add.w   #OX,d0
                move.w  d0,win_ox               ; world X = level x - win_ox
                lsl.w   #3,d1
                add.w   #OY,d1
                move.w  d1,win_oy
                move.w  #1,need_rebuild
                movem.l d7/a2,-(sp)
                bsr     lz_reset                ; new screen : lasers staggered
                movem.l (sp)+,d7/a2
                tst.w   rick_dead
                bne.s   .x
                move.w  rick_xf,cp_xf           ; respawn here
                move.w  rk_h,d0                 ; respawn point = feet
                lsl.w   #3,d0
                add.w   rick_yf,d0
                move.w  d0,cp_yf
.x:             rts
.init:          bsr     .colx                   ; 1st screen : Rick at the bottom
                move.w  d5,d1
                add.w   rk_h,d1
                subq.w  #1,d1
                asr.w   #3,d1
                sub.w   #SCR_TH-4,d1
                move.w  #-2,win_tx              ; (forces the change)
                bra     .clamp
.colx:          move.w  d4,d0                   ; screen column of the centre
                addq.w  #RICK_W/2,d0
                bpl.s   .cx
                moveq   #0,d0
.cx:            lsr.w   #8,d0
                lsl.w   #5,d0
                rts

;---------------------------------------------------------------------
; walk : d6 = move (1/8 unit) -> d2 = 1 if Rick moved
rick_walk:
                move.w  rick_xf,d5
                add.w   d6,d5
                move.w  d5,d0
                asr.w   #3,d0
                tst.w   d6
                bmi.s   .l
                add.w   #RICK_W-1,d0
.l:             move.w  rick_yf,d1              ; head -> feet, steps of 7
                asr.w   #3,d1                   ;  (no tile fits in between)
                move.w  d1,d3
                add.w   rk_h,d3
                subq.w  #1,d3                   ; d3 = last row
.lp:            bsr     solid_px
                bne.s   .no
                cmp.w   d3,d1
                beq.s   .ok
                addq.w  #7,d1
                cmp.w   d3,d1
                ble.s   .lp
                move.w  d3,d1
                bra.s   .lp
.ok:
                move.w  d5,rick_xf
                moveq   #1,d0
                tst.w   d6
                bpl.s   .d
                moveq   #-1,d0
.d:             move.w  d0,rick_dir
                moveq   #1,d2
                rts
.no:            moveq   #0,d2
                rts

; find_ladder : y = d1 ; looks for a ladder under Rick's body
;   (centre, left side, right side, then LAD_GRAB pixels right and
;   left of the body) -> Z = 1 and d0 = x found
find_ladder:
                move.w  rick_xf,d0
                asr.w   #3,d0
                addq.w  #RICK_W/2,d0
                bsr     ladder_px
                beq.s   .x
                subq.w  #RICK_W/2-2,d0
                bsr     ladder_px
                beq.s   .x
                add.w   #RICK_W-4,d0
                bsr     ladder_px
                beq.s   .x
                add.w   #LAD_GRAB+1,d0          ; a bit beside the body : the
                bsr     ladder_px               ;  pipe (in relief) looks
                beq.s   .x                      ;  wider than its cell
                sub.w   #RICK_W+2*LAD_GRAB-1,d0
                bsr     ladder_px
.x:             rts

; grabs the ladder : d0/d1 = x/y (pixels) of a ladder tile
;   -> Rick centred on the ladder (1 or 2 tiles wide)
grab_ladder:
                move.w  #1,on_ladder
                clr.w   on_ground
                clr.w   rick_vy
                asr.w   #3,d1                   ; line of the ladder
                asr.w   #3,d0
                move.w  d0,d4                   ; column
                addq.w  #1,d0
                bsr     tile_at
                bsr     isladc
                bne.s   .nr
                move.w  d4,d0                   ; ladder on the right : centre
                addq.w  #1,d0                   ; = right edge of the column
                lsl.w   #3,d0
                bra.s   .c
.nr:            move.w  d4,d0
                subq.w  #1,d0
                bsr     tile_at
                move.w  d4,d0
                lsl.w   #3,d0
                cmp.b   #'H',d2
                beq.s   .c
                cmp.b   #'U',d2                 ; pipe (2 tiles) : the middle
                beq.s   .c
                addq.w  #4,d0                   ; 1 tile : its middle
.c:             sub.w   #RICK_W/2,d0            ; x of Rick
                move.w  rick_yf,d1
                asr.w   #3,d1
                add.w   rk_h2,d1
                moveq   #8,d3                   ; steps back if he touches a wall
.fr:            move.w  d0,d4
                add.w   #RICK_W-1,d0
                bsr     solid_px
                move.w  d4,d0
                tst.w   d2
                beq.s   .fl
                subq.w  #1,d0
                dbra    d3,.fr
.fl:            moveq   #8,d3
.fl2:           bsr     solid_px
                beq.s   .ok
                addq.w  #1,d0
                dbra    d3,.fl2
.ok:            lsl.w   #3,d0
                move.w  d0,rick_xf
                rts

;---------------------------------------------------------------------
update_rick:
                tst.w   end_t                   ; level finished : Rick waits,
                beq.s   .ne                     ;  then back to the start
                subq.w  #1,end_t
                bne.s   .nex
                move.w  #2,game_end             ; end of the game : name, scores
.nex:           rts
.ne:            tst.w   end_col                 ; end of the level reached ?
                bmi.s   .ne2
                tst.w   rick_dead
                bne.s   .ne2
                move.w  rick_xf,d0              ; middle of Rick : column
                asr.w   #3,d0                   ;  end_col or end_col + 1
                addq.w  #RICK_W/2,d0
                asr.w   #3,d0
                sub.w   end_col,d0
                cmp.w   #1,d0
                bhi.s   .ne2
                move.w  rick_yf,d0              ; feet on the line under the
                asr.w   #3,d0                   ;  top-left cell
                add.w   rk_h,d0
                subq.w  #1,d0
                asr.w   #3,d0
                subq.w  #1,d0
                cmp.w   end_row,d0
                bne.s   .ne2
                move.w  #END_DUR,end_t
                move.w  #END_DUR+INVUL_N,invul_t
                move.l  #t_end,msg_ptr
                move.w  #END_DUR,msg_t
                clr.w   rick_vy
                rts
.ne2:           bsr     get_input
                tst.w   rick_dead               ; dead : no more controls
                beq.s   .alive
                moveq   #0,d7
.alive:
                ; --- button : fire+up = laser, fire+down = bomb, Rick does not move
                moveq   #0,d0
                btst    #7,d7
                beq.s   .nofire
                btst    #0,d7
                beq.s   .f1
                moveq   #1,d0                   ; fire + up
.f1:            btst    #1,d7
                beq.s   .f2
                moveq   #2,d0                   ; fire + down
                btst    #2,d7                   ; fire + down-left : throws
                beq.s   .f1r
                moveq   #4,d0
                move.w  #-1,rick_dir
                bra.s   .f2
.f1r:           btst    #3,d7                   ; fire + down-right : throws
                beq.s   .f2
                moveq   #4,d0
                move.w  #1,rick_dir
.f2:            tst.w   d0                      ; fire + left / right : stick
                bne.s   .f3
                btst    #2,d7
                beq.s   .f2r
                moveq   #3,d0
                move.w  #-1,rick_dir
                bra.s   .f3
.f2r:           btst    #3,d7
                beq.s   .f3
                moveq   #3,d0
                move.w  #1,rick_dir
.f3:            and.b   #$f0,d7                 ; no move and no jump
.nofire:        move.w  fire_old,d1
                move.w  d0,fire_old
                cmp.w   d1,d0                   ; new action only
                beq.s   .nact
                cmp.w   #1,d0
                bne.s   .nl1
                bsr     fire_laser
                bra.s   .nact
.nl1:           cmp.w   #2,d0
                bne.s   .nl2
                bsr     drop_bomb
                bra.s   .nact
.nl2:           cmp.w   #4,d0
                bne.s   .nl3
                bsr     throw_bomb
                bra.s   .nact
.nl3:           cmp.w   #3,d0
                bne.s   .nact
                cmp.w   #RICK_H,rk_h            ; no punch while crouching
                bne.s   .nact
                bsr     poke
.nact:
                clr.w   lift_in                 ; on a lift : up / down
                move.w  rick_onplat,d0          ;  drive it (no jump)
                bmi.s   .nlift
                mulu    #PL_SIZE,d0
                lea     plats,a0
                cmp.w   #2,PL_AUTO(a0,d0.w)
                bne.s   .nlift
                moveq   #3,d1
                and.b   d7,d1
                move.w  d1,lift_in
                and.b   #$fc,d7
.nlift:
                moveq   #0,d6                   ; left / right
                btst    #2,d7
                beq.s   .nl
                moveq   #-WALK,d6
.nl:            btst    #3,d7
                beq.s   .nr
                moveq   #WALK,d6
.nr:            cmp.w   #RICK_H,rk_h          ; crouching : he crawls
                beq.s   .nr2
                asr.w   #1,d6
.nr2:           btst    #0,d7                   ; up released : can jump again
                bne.s   .nr3
                clr.w   up_lock
.nr3:           tst.w   on_ladder
                beq     .free
                move.w  #1,up_lock              ; on the ladder : when leaving it,
                                                ;  up still held = no jump
                ;=========== on the ladder
                tst.w   d6
                beq.s   .climb
                move.b  d7,d0                   ; up / down also held (diagonal) :
                and.b   #3,d0                   ;  he keeps climbing (otherwise he
                bne.s   .climb                  ;  lets go and grabs again every frame)
                bsr     rick_walk                    ; leaving the ladder sideways
                tst.w   d2
                beq.s   .climb
                clr.w   on_ladder
                bra     .grav
.climb:         move.b  d7,d0                   ; animation : moving on the ladder ?
                and.b   #3,d0
                beq.s   .cl0
                addq.w  #1,climb_ph
.cl0:           move.w  rick_xf,d0
                asr.w   #3,d0
                addq.w  #RICK_W/2,d0            ; d0 = centre
                move.w  rick_yf,d5
                asr.w   #3,d5                   ; d5 = y
                btst    #0,d7
                beq.s   .cdn
                move.w  d5,d1                   ; going up : head free ?
                subq.w  #1,d1
                bsr     solid_px
                bne     .after
                move.w  d1,d5
                add.w   rk_h,d1
                subq.w  #1,d1
                bsr     ladder_px
                beq.s   .cst
                clr.w   on_ladder               ; top : standing on it
.cst:           lsl.w   #3,d5
                move.w  d5,rick_yf
                bra     .after
.cdn:           btst    #1,d7
                beq     .after
                move.w  d5,d1                   ; going down : solid floor ?
                add.w   rk_h,d1
                bsr     solid_px
                bne.s   .cd0
                bsr     ladder_px               ; still the ladder under the
                beq.s   .cd1                    ;  feet : go on
                bsr     floor_px                ; walkway (or platform) at the
                beq.s   .cd1                    ;  bottom of the ladder : stand on it
.cd0:           clr.w   on_ladder
                bra     .after
.cd1:           addq.w  #1,d5
                move.w  d5,d1
                add.w   rk_h,d1
                subq.w  #1,d1
                bsr     ladder_px
                beq.s   .cd2
                addq.w  #1,d1
                bsr     ladder_px
                beq.s   .cd2
                clr.w   on_ladder               ; bottom of the ladder in the air
.cd2:           lsl.w   #3,d5
                move.w  d5,rick_yf
                bra     .after
                ;=========== free
.free:          tst.w   d6
                bne.s   .wk
                clr.w   walk_ph                 ; still : resting pose
                bra.s   .nw
.wk:            bsr     rick_walk
                tst.w   d2
                beq.s   .nw
                addq.w  #1,walk_ph              ; walking animation
.nw:            move.w  rick_xf,d0
                asr.w   #3,d0
                addq.w  #RICK_W/2,d0
                move.w  rick_yf,d1
                asr.w   #3,d1
                btst    #0,d7                   ; up : ladder or jump
                beq.s   .gdn
                cmp.w   #RICK_H,rk_h          ; (crouching : no)
                bne.s   .gdn
                move.w  d1,d4
                add.w   rk_h,d1
                subq.w  #1,d1
                bsr     find_ladder
                beq     .grab
                move.w  d4,d1
                addq.w  #8,d1
                bsr     find_ladder
                beq     .grab
                move.w  d4,d1                   ; ... or at head height
                addq.w  #1,d1                   ; (grabbed while jumping)
                bsr     find_ladder
                beq     .grab
                tst.w   on_ground
                beq     .grav
                tst.w   up_lock                 ; (just left a ladder)
                bne     .grav
                move.w  #JUMP_V,rick_vy
                clr.w   on_ground
                lea     sfx_jump,a0
                bsr     sfx_play
                bra     .grav
.gdn:           btst    #1,d7                   ; down : ladder under the feet
                beq     .stand                  ;       or crouch
                tst.w   on_ground
                beq     .grav
                cmp.w   #RICK_H,rk_h
                bne     .grav                   ; already crouching
                add.w   rk_h,d1
                tst.w   d6                      ; down + left / right : he
                bne.s   .crh                    ;  crouches and crawls, even at the top
                bsr     find_ladder             ;  of a ladder (under a wave)
                beq.s   .gdl
.crh:           move.w  #CROUCH_H,rk_h        ; crouches (feet at the same place)
                move.w  #CROUCH_H/2,rk_h2
                add.w   #(RICK_H-CROUCH_H)*8,rick_yf
                bra     .grav
.stand:         cmp.w   #RICK_H,rk_h          ; down released : stand up
                beq     .grav
                move.w  rick_yf,d1              ; room for the head ?
                asr.w   #3,d1
                sub.w   #RICK_H-CROUCH_H,d1
                moveq   #1,d3
.st1:           move.w  rick_xf,d0
                asr.w   #3,d0
                addq.w  #1,d0
                bsr     solid_px
                bne     .grav
                add.w   #RICK_W-3,d0
                bsr     solid_px
                bne     .grav
                addq.w  #4,d1
                dbra    d3,.st1
                move.w  #RICK_H,rk_h
                move.w  #RICK_H/2,rk_h2
                sub.w   #(RICK_H-CROUCH_H)*8,rick_yf
                bra     .grav
.gdl:           bsr     grab_ladder             ; (d1 = y of the ladder)
                addq.w  #8,rick_yf              ; 1 pixel lower
                bra     .after
.grab:          bsr     grab_ladder             ; (d1 = y of the ladder)
                bra     .after
                ;=========== gravity
.grav:          move.w  rick_vy,d0
                add.w   #GRAV,d0
                cmp.w   #VMAX,d0
                ble.s   .vm
                move.w  #VMAX,d0
.vm:            move.w  d0,rick_vy
                move.w  rick_yf,d5
                add.w   d0,d5                   ; d5 = new y (1/8)
                move.w  rick_xf,d6
                asr.w   #3,d6                   ; d6 = x
                tst.w   rick_vy
                bmi.s   .up
                move.w  rick_yf,d4              ; fall : each row crossed
                asr.w   #3,d4
                add.w   rk_h,d4
                move.w  d5,d3
                asr.w   #3,d3
                add.w   rk_h,d3
                subq.w  #1,d3
.dl:            cmp.w   d3,d4
                bgt.s   .fall
                move.w  d6,d0
                addq.w  #1,d0
                move.w  d4,d1
                bsr     floor_px
                bne.s   .land
                add.w   #RICK_W-3,d0
                bsr     floor_px
                bne.s   .land
                addq.w  #1,d4
                bra.s   .dl
.land:          sub.w   rk_h,d4
                lsl.w   #3,d4
                move.w  d4,d5
                clr.w   rick_vy
.fall:          move.w  d5,rick_yf
                bra.s   .after
.up:            move.w  d5,d1                   ; jump : head
                asr.w   #3,d1
                move.w  d6,d0
                addq.w  #1,d0
                bsr     solid_px
                bne.s   .bump
                add.w   #RICK_W-3,d0
                bsr     solid_px
                beq.s   .fall
.bump:          and.w   #$fff8,d1
                addq.w  #8,d1
                lsl.w   #3,d1
                move.w  d1,d5
                clr.w   rick_vy
                bra.s   .fall
                ;=========== on the floor ?
.after:         clr.w   on_ground
                move.w  #-1,rick_onplat
                move.w  #-1,plat_hit
                tst.w   on_ladder
                bne.s   .win
                move.w  rick_xf,d0
                asr.w   #3,d0
                addq.w  #1,d0
                move.w  rick_yf,d1
                asr.w   #3,d1
                add.w   rk_h,d1
                bsr     floor_px
                bne.s   .og
                add.w   #RICK_W-3,d0
                bsr     floor_px
                beq.s   .win
.og:            tst.w   rick_vy
                bmi.s   .win
                move.w  #1,on_ground
                tst.w   plat_hit                ; fixed floor : a lift at the same
                bpl.s   .ph                     ;  level has priority
                move.w  rick_xf,d0
                asr.w   #3,d0
                addq.w  #1,d0
                move.w  rick_yf,d1
                asr.w   #3,d1
                add.w   rk_h,d1
                bsr     plat_floor
                bne.s   .ph
                add.w   #RICK_W-3,d0
                bsr     plat_floor
.ph:            move.w  plat_hit,rick_onplat    ; standing on a moving platform ?
                clr.w   rick_vy
.win:           bra     check_window

;---------------------------------------------------------------------
; for testing : R saves Rick's position, B brings him back there
pos_record:
                tst.w   rick_dead
                bne.s   .x
                move.w  rick_xf,sv_x
                move.w  rk_h,d0                 ; the feet are kept
                lsl.w   #3,d0
                add.w   rick_yf,d0
                move.w  d0,sv_feet
                move.w  #1,sv_ok
                move.l  #t_rec,msg_ptr
                bsr     save_write              ; -> RICK3D.SAV
                beq.s   .ok
                move.l  #t_recerr,msg_ptr
.ok:            move.w  #MSG_DUR,msg_t
.x:             rts
pos_back:
                tst.w   sv_ok
                beq     .no
                tst.w   rick_dead
                bne     .x
                movem.l d0-d7/a0-a2,-(sp)
                move.w  sv_x,rick_xf
                move.w  sv_feet,d0
                sub.w   #RICK_H*8,d0
                move.w  d0,rick_yf
                move.w  #RICK_H,rk_h
                move.w  #RICK_H/2,rk_h2
                clr.w   rick_vy
                clr.w   on_ladder
                clr.w   on_ground
                clr.w   walk_ph
                clr.w   climb_ph
                clr.w   stick_t
                move.w  #-1,rick_onplat
                move.w  #INVUL_N,invul_t        ; 2 s of invulnerability
                move.w  #-1,win_tx              ; screen rebuilt
                bsr     check_window
                movem.l (sp)+,d0-d7/a0-a2
                move.l  #t_back,msg_ptr
                move.w  #MSG_DUR,msg_t
.x:             rts
.no:            move.l  #t_norec,msg_ptr
                move.w  #MSG_DUR,msg_t
                rts

;---------------------------------------------------------------------
; SAVE FILE RICK3D.SAV (next to the LEVEL folder)
;   'R3DS' version.w level.w  position : saved.w x.w feet.w
;   then SV_NSC scores : name 8 bytes + score.l (for later)
;   save_read  : at start (no file : empty table)
;   save_write : at each R ; Z = 1 if written
save_read:
                movem.l d0-d2/a0-a2,-(sp)
                bsr     save_clear
                clr.w   -(sp)                   ; Fopen read
                pea     savname
                move.w  #$3d,-(sp)
                trap    #1
                addq.l  #8,sp
                tst.l   d0
                bmi     .x
                move.w  d0,d2
                pea     savbuf2                 ; Fread
                move.l  #SV_SIZE,-(sp)
                move.w  d2,-(sp)
                move.w  #$3f,-(sp)
                trap    #1
                lea     12(sp),sp
                move.l  d0,d1
                move.w  d2,-(sp)                ; Fclose
                move.w  #$3e,-(sp)
                trap    #1
                addq.l  #4,sp
                cmp.l   #SV_SIZE,d1
                bne.s   .x
                cmp.l   #'R3DS',savbuf2
                bne.s   .x
                cmp.w   #SV_VER,savbuf2+4
                bne.s   .x
                lea     savbuf2,a0              ; valid file : kept
                lea     savbuf,a1
                move.w  #SV_SIZE-1,d0
.cp:            move.b  (a0)+,(a1)+
                dbra    d0,.cp
.x:             movem.l (sp)+,d0-d2/a0-a2
                rts

save_clear:     lea     savbuf,a0               ; header + empty scores
                move.l  #'R3DS',(a0)+
                move.w  #SV_VER,(a0)+
                move.w  #1,(a0)+
                clr.l   (a0)+
                clr.w   (a0)+
                moveq   #SV_NSC-1,d0
.sc:            moveq   #7,d1
.nm:            move.b  #'.',(a0)+
                dbra    d1,.nm
                clr.l   (a0)+
                dbra    d0,.sc
                rts

save_write:
                movem.l d0-d2/a0-a2,-(sp)
                move.w  cur_level,savbuf+6      ; level of the position
                move.w  sv_ok,savbuf+8
                move.w  sv_x,savbuf+10
                move.w  sv_feet,savbuf+12
                clr.w   -(sp)                   ; Fcreate
                pea     savname
                move.w  #$3c,-(sp)
                trap    #1
                addq.l  #8,sp
                tst.l   d0
                bmi.s   .err
                move.w  d0,d2
                pea     savbuf                  ; Fwrite
                move.l  #SV_SIZE,-(sp)
                move.w  d2,-(sp)
                move.w  #$40,-(sp)
                trap    #1
                lea     12(sp),sp
                move.l  d0,d1
                move.w  d2,-(sp)                ; Fclose
                move.w  #$3e,-(sp)
                trap    #1
                addq.l  #4,sp
                cmp.l   #SV_SIZE,d1
                bne.s   .err
                moveq   #0,d0                   ; Z = 1 : ok
                bra.s   .x
.err:           moveq   #1,d0
.x:             movem.l (sp)+,d0-d2/a0-a2       ; (movem does not touch Z)
                rts
