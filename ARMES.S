;=====================================================================
; ARMES.S - RICK'S WEAPONS : laser and bomb
;   (included by RICK3D.S ; the settings are in PARAMS.S)
;=====================================================================

;=====================================================================
; LASER AND BOMB (like Rick Dangerous 2) - level coordinates
;   laser : one shot at a time, leaves from the chest where Rick looks,
;           stops on a block or at the edge of the screen
;   bomb : dropped at the feet, 1.5 s fuse, then 3D fireball ;
;           Rick dies if he is in the blast (he comes back at the end) ;
;           it goes on even if Rick changes screen (it can be dropped
;           then left behind by a ladder or a screen edge)
;=====================================================================

fire_laser:
                tst.w   las_on
                bne.s   .x
                tst.w   ammo_las
                beq.s   .x
                subq.w  #1,ammo_las
                move.w  #1,las_on
                move.w  rick_dir,las_dir
                move.w  rick_yf,d0
                asr.w   #3,d0
                addq.w  #8,d0
                move.w  d0,las_y
                move.w  rick_xf,d0
                asr.w   #3,d0
                tst.w   rick_dir
                bmi.s   .l
                add.w   #RICK_W,d0
                bra.s   .s
.l:             sub.w   #LAS_LEN,d0
.s:             move.w  d0,las_x
                lea     sfx_laser,a0
                bsr     sfx_play
.x:             rts

; throw_bomb : fire + down diagonal -> the bomb slides away
;   in front of Rick (direction rick_dir) up to a wall or a plate
throw_bomb:
                bsr     drop_bomb
                tst.w   bomb_st
                beq.s   .x
                move.w  rick_dir,d0
                muls    #BOMB_SPD,d0
                move.w  d0,bomb_vx
.x:             rts

; bomb_slide : moves the thrown bomb, makes it fall if there is no floor
bomb_slide:
                movem.l d0-d2,-(sp)
                move.w  bomb_y,d1               ; no floor below : falls
                addq.w  #6,d1
                move.w  bomb_x,d0
                addq.w  #2,d0
                move.w  plat_hit,-(sp)
                bsr     floor_px                ; (moving platforms included)
                move.w  (sp)+,plat_hit
                tst.w   d2
                bne.s   .sol
                addq.w  #2,bomb_y
                bra.s   .x
.sol:           move.w  bomb_vx,d2
                beq.s   .x
                move.w  bomb_x,d0               ; wall in front ?
                add.w   d2,d0
                tst.w   d2
                bmi.s   .l
                addq.w  #3,d0
.l:             move.w  bomb_y,d1
                addq.w  #3,d1
                bsr     solid_px
                bne.s   .stop
                move.w  bomb_vx,d2              ; (solid_px returns d2)
                add.w   d2,bomb_x
                bra.s   .x
.stop:          clr.w   bomb_vx
.x:             movem.l (sp)+,d0-d2
                rts

drop_bomb:
                tst.w   bomb_st
                bne.s   .x
                tst.w   ammo_bomb
                beq.s   .x
                tst.w   on_ground
                beq.s   .x
                subq.w  #1,ammo_bomb
                clr.w   bomb_vx                 ; dropped (throw_bomb throws it)
                move.w  #1,bomb_st
                move.w  #BOMB_FUSE,bomb_t
                move.w  rick_xf,d0
                asr.w   #3,d0
                addq.w  #4,d0
                move.w  d0,bomb_x
                move.w  rick_yf,d0
                asr.w   #3,d0
                add.w   rk_h,d0
                subq.w  #6,d0
                move.w  d0,bomb_y
                lea     sfx_bomb,a0
                bsr     sfx_play
.x:             rts

update_objs:
                tst.w   stick_t                 ; stick
                beq.s   .nst
                subq.w  #1,stick_t
.nst:           tst.w   need_rebuild            ; new screen : the laser stops,
                beq.s   .same                   ;  but the BOMB goes on (fuse,
                clr.w   las_on                  ;  explosion, 'B' plates) even if
.same:                                          ;  Rick went into another screen          ; --- laser
                tst.w   las_on
                beq.s   .nol
                move.w  las_dir,d0
                muls    #LAS_SPD,d0
                add.w   las_x,d0
                move.w  d0,las_x
                tst.w   las_dir                 ; tip of the shot
                bmi.s   .tip
                add.w   #LAS_LEN-1,d0
.tip:           move.w  d0,d1                   ; off the screen ?
                sub.w   win_ox,d1
                cmp.w   #-OX,d1
                blt.s   .lof
                cmp.w   #OX,d1
                bge.s   .lof
                move.w  las_y,d1
                addq.w  #1,d1
                bsr     solid_px
                beq.s   .nol
.lof:           clr.w   las_on
.nol:
                ; --- bomb
                move.w  bomb_st,d0
                beq     .x
                cmp.w   #1,d0                   ; thrown bomb : slides on the floor
                bne.s   .nmv
                bsr     bomb_slide
.nmv:           subq.w  #1,bomb_t
                bne     .x
                cmp.w   #1,d0
                bne.s   .endx
                move.w  #2,bomb_st              ; BOOM
                move.w  #BOMB_EXPL,bomb_t
                lea     sfx_boom,a0
                bsr     sfx_play
                bsr     bomb_break              ; 'B' plates in the blast
                move.w  rick_xf,d0              ; Rick in the blast ?
                asr.w   #3,d0
                addq.w  #RICK_W/2,d0
                move.w  bomb_x,d1
                addq.w  #2,d1
                sub.w   d1,d0
                bpl.s   .ax
                neg.w   d0
.ax:            cmp.w   #BOMB_KILL,d0
                bge.s   .x
                move.w  rick_yf,d0
                asr.w   #3,d0
                add.w   rk_h2,d0
                move.w  bomb_y,d1
                addq.w  #3,d1
                sub.w   d1,d0
                bpl.s   .ay
                neg.w   d0
.ay:            cmp.w   #BOMB_KILL,d0
                bge.s   .x
                move.w  #1,rick_dead
                bra.s   .x
.endx:          clr.w   bomb_st                 ; end of the explosion
                tst.w   rick_dead
                beq.s   .x
                bsr     lose_life
.x:             rts

; drawing of the laser and the bomb (after Rick, same erase system)
draw_objs:
                bsr     draw_mobile
                tst.w   las_on
                beq.s   .nol
                move.w  las_x,d0
                sub.w   win_ox,d0
                move.w  las_y,d1
                sub.w   win_oy,d1
                move.w  d0,d2
                add.w   #LAS_LEN,d2
                move.w  d1,d3
                addq.w  #2,d3
                move.w  #ZMID-2,d4
                move.w  #ZMID+2,d5
                lea     col_laser,a1
                bsr     draw_box
                bsr     bb_push
.nol:           move.w  bomb_st,d0
                beq     .x
                move.w  bomb_x,d6
                sub.w   win_ox,d6
                move.w  bomb_y,d7
                sub.w   win_oy,d7
                cmp.w   #-OX-40,d6              ; bomb left in another
                blt     .x                      ;  screen : it is not drawn
                cmp.w   #OX+40,d6
                bgt     .x
                cmp.w   #-OY-40,d7
                blt     .x
                cmp.w   #OY+40,d7
                bgt     .x
                cmp.w   #2,d0
                beq.s   .boom
                move.w  d6,d0                   ; 4x6 stick of dynamite
                move.w  d7,d1
                addq.w  #2,d1
                move.w  d6,d2
                addq.w  #4,d2
                move.w  d7,d3
                addq.w  #6,d3
                move.w  #ZMID-2,d4
                move.w  #ZMID+2,d5
                lea     col_dyn,a1
                bsr     draw_box
                move.w  d6,d0                   ; sparkling fuse
                addq.w  #1,d0
                move.w  d7,d1
                move.w  d6,d2
                addq.w  #3,d2
                move.w  d7,d3
                addq.w  #2,d3
                move.w  #ZMID-1,d4
                move.w  #ZMID+1,d5
                lea     col_spark1,a1
                btst    #2,bomb_t+1
                beq.s   .sp
                lea     col_spark2,a1
.sp:            bsr     draw_box
                bra     .x
.boom:          moveq   #BOMB_EXPL,d0           ; growing radius : 4..27
                sub.w   bomb_t,d0
                addq.w  #4,d0
                move.w  d0,d5
                add.w   #2,d6                   ; centre of the bomb
                addq.w  #3,d7
                move.w  d6,d0
                sub.w   d5,d0
                move.w  d7,d1
                sub.w   d5,d1
                move.w  d6,d2
                add.w   d5,d2
                move.w  d7,d3
                add.w   d5,d3
                move.w  #ZMID,d4
                sub.w   d5,d4
                add.w   #ZMID,d5
                move.w  bomb_t,d6               ; yellow / orange / red
                lsr.w   #2,d6
                and.w   #3,d6
                lsl.w   #3,d6
                lea     col_fire,a1
                adda.w  d6,a1
                ; 3 boxes in a cross : wide and flat, tall and thin, then the
                ; core (next colour) -> star-shaped fireball
                movem.w d0-d5,-(sp)
                move.w  d3,d6                   ; wide : height / 3
                sub.w   d1,d6
                ext.l   d6
                divs    #3,d6
                add.w   d6,d1
                sub.w   d6,d3
                bsr     draw_box
                movem.w (sp),d0-d5
                move.w  d2,d6                   ; tall : width / 3
                sub.w   d0,d6
                ext.l   d6
                divs    #3,d6
                add.w   d6,d0
                sub.w   d6,d2
                bsr     draw_box
                movem.w (sp)+,d0-d5
                move.w  d2,d6                   ; core : half size
                sub.w   d0,d6
                asr.w   #2,d6
                add.w   d6,d0
                sub.w   d6,d2
                add.w   d6,d1
                sub.w   d6,d3
                add.w   d6,d4
                sub.w   d6,d5
                addq.l  #8,a1
                cmp.l   #col_fire+32,a1
                blo.s   .c
                lea     col_fire,a1
.c:             bsr     draw_box
.x:             bra     bb_push

; bomb_break : every 'B' plate hit by the explosion disappears (with
;   the plates stuck to it) -> black background in the park, wall elsewhere
bomb_break:
                movem.l d0-d7/a0-a2,-(sp)
                move.w  bomb_x,d4               ; centre of the explosion
                addq.w  #2,d4
                move.w  bomb_y,d5
                addq.w  #3,d5
                move.w  d4,d0                   ; columns / lines hit
                sub.w   #BOMB_BRK_R,d0
                asr.w   #3,d0
                move.w  d4,d2
                add.w   #BOMB_BRK_R,d2
                asr.w   #3,d2
                move.w  d5,d1
                sub.w   #BOMB_BRK_R,d1
                asr.w   #3,d1
                move.w  d5,d3
                add.w   #BOMB_BRK_R,d3
                asr.w   #3,d3
                move.w  d1,d6
.ly:            move.w  d0,d7
.lx:            movem.w d0-d3,-(sp)
                move.w  d7,d0
                move.w  d6,d1
                bsr     tile_at
                cmp.b   #'B',d2
                bne.s   .nb
                bsr     break_group
.nb:            movem.w (sp)+,d0-d3
                addq.w  #1,d7
                cmp.w   d2,d7
                ble.s   .lx
                addq.w  #1,d6
                cmp.w   d3,d6
                ble.s   .ly
                movem.l (sp)+,d0-d7/a0-a2
                rts

; break_group : d0/d1 = a 'B' tile -> fill of the group
break_group:
                movem.l d0-d7/a0-a2,-(sp)
                moveq   #'.',d5                 ; what replaces the plate
                move.w  lev_h,d2
                sub.w   #12,d2
                cmp.w   d2,d1
                blt.s   .ch
                moveq   #'k',d5                 ; (park : black sky)
.ch:            lea     brk_stack,a2
                moveq   #0,d7                   ; number of elements
                move.w  d0,(a2)+
                move.w  d1,(a2)+
                addq.w  #1,d7
.pop:           tst.w   d7
                beq.s   .end
                subq.w  #1,d7
                move.w  -(a2),d1
                move.w  -(a2),d0
                bsr     tile_at
                cmp.b   #'B',d2
                bne.s   .pop
                move.w  d1,d2                   ; replace
                mulu    lev_w,d2
                lea     levmap,a0
                adda.l  d2,a0
                move.b  d5,(a0,d0.w)
                cmp.w   #BRK_MAX-4,d7           ; neighbours (limited stack)
                bhs.s   .pop
                addq.w  #1,d0
                bsr.s   .push
                subq.w  #2,d0
                bsr.s   .push
                addq.w  #1,d0
                addq.w  #1,d1
                bsr.s   .push
                subq.w  #2,d1
                bsr.s   .push
                bra.s   .pop
.push:          move.w  d0,(a2)+
                move.w  d1,(a2)+
                addq.w  #1,d7
                rts
.end:           move.w  #1,items_dirty          ; scenery to rebuild (without cutting
                movem.l (sp)+,d0-d7/a0-a2       ;  the explosion)
                rts

