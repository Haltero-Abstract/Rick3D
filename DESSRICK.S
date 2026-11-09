;=====================================================================
; DESSRICK.S - DRAWING OF RICK (small animated 3D boxes)
;   (included by RICK3D.S ; the settings are in PARAMS.S)
;=====================================================================

;---------------------------------------------------------------------
; Rick = small 3D boxes centred in the middle of the scenery depth

draw_rick:
                move.w  clip_y0,-(sp)           ; Rick is in the middle of the
                move.w  clip_y1,-(sp)           ;  depth : the front edge of the
                bsr     rick_clip               ;  floor (or the ceiling) hides him
                bsr     draw_rick0
                move.w  (sp)+,clip_y1
                move.w  (sp)+,clip_y0
                rts

;---------------------------------------------------------------------
; rick_clip : floor above the centre of the screen -> its front edge (closer
;   than Rick) hides the bottom of the legs ; ceiling below the centre ->
;   its front edge hides the top of the head. clip_y1 / clip_y0 are reduced.
rick_clip:
                movem.l d0-d3,-(sp)
                tst.w   on_ladder
                bne     .x
                move.w  rick_xf,d0              ; middle column of Rick
                asr.w   #3,d0
                add.w   #RICK_W/2,d0
                asr.w   #3,d0
                ; --- floor under the feet
                move.w  rick_yf,d1
                asr.w   #3,d1
                add.w   rk_h,d1                 ; Y of the feet
                move.w  d1,d3
                and.w   #7,d3
                bne.s   .ceil                   ; not standing exactly on a tile
                move.w  d1,-(sp)
                asr.w   #3,d1
                bsr     tile_at
                move.w  (sp)+,d1
                bsr     lipz
                beq.s   .ceil
                sub.w   win_oy,d1               ; world Y (0 = screen centre)
                bpl.s   .ceil                   ; below the centre : nothing to hide
                muls    #FOC,d1
                divs    d3,d1
                add.w   #CY-1,d1                ; last visible line
                cmp.w   clip_y1,d1
                bge.s   .ceil
                move.w  d1,clip_y1
                ; --- ceiling above the head
.ceil:          move.w  rick_yf,d1
                asr.w   #3,d1                   ; Y of the top of Rick
                move.w  d1,d3
                and.w   #7,d3
                bne.s   .x
                move.w  d1,-(sp)
                asr.w   #3,d1
                subq.w  #1,d1
                bsr     tile_at
                move.w  (sp)+,d1
                bsr     lipz
                beq.s   .x
                sub.w   win_oy,d1
                ble.s   .x                      ; above the centre : nothing
                muls    #FOC,d1
                divs    d3,d1
                add.w   #CY,d1                  ; 1st visible line
                cmp.w   clip_y0,d1
                ble.s   .x
                move.w  d1,clip_y0
.x:             movem.l (sp)+,d0-d3
                rts

; lipz : d2 = character -> d3 = Z of its front face (0 = none ; Z = 0)
lipz:           move.w  #ZF,d3
                bsr     isblk                   ; solid block
                beq.s   .ok
                cmp.b   #'=',d2                 ; walkway
                beq.s   .ok
                cmp.b   #'-',d2                 ; bar
                beq.s   .ok
                move.w  #PIPE_Z0,d3
                cmp.b   #'w',d2                 ; pipe that can be walked on
                beq.s   .ok
                moveq   #0,d3
.ok:            tst.w   d3
                rts

draw_rick0:
                btst    #2,invul_t+1            ; invulnerable : blinks
                bne     .end
                ; --- animation
                move.w  walk_ph,d0              ; walk : 4 steps
                lsr.w   #3,d0
                and.w   #3,d0
                add.w   d0,d0
                move.w  .swing(pc,d0.w),an_sl
                clr.w   an_lf
                clr.w   an_lb
                cmp.w   #2,d0                   ; step 1 : lifts the front leg
                bne.s   .a1
                move.w  #1,an_lf
.a1:            cmp.w   #6,d0                   ; step 3 : lifts the back leg
                bne.s   .a2
                move.w  #1,an_lb
.a2:            move.w  climb_ph,d0             ; ladder : 2 beats
                lsr.w   #3,d0
                and.w   #1,d0
                add.w   d0,d0
                move.w  d0,an_la                ; 0 or 2
                eor.w   #2,d0
                move.w  d0,an_lb2               ; 2 or 0
                ; --- pose
                lea     mdl_rickstand,a2
                clr.w   an_mir                  ; 1 : mirror (looks left)
                tst.w   rick_dir
                bpl.s   .p1
                move.w  #1,an_mir
.p1:            cmp.w   #RICK_H,rk_h
                beq.s   .p2
                lea     mdl_rickcrouch,a2
.p2:            tst.w   on_ladder
                beq.s   .p25
                lea     mdl_rickladder,a2          ; from behind : no mirror
                clr.w   an_mir
                bra.s   .p3
.p25:           tst.w   stick_t                 ; punch (standing)
                beq.s   .p3
                cmp.w   #RICK_H,rk_h
                bne.s   .p3
                lea     mdl_rickpunch,a2
.p3:            clr.w   rk_pass
                move.l  a2,rk_mdl
.p3b:           move.w  rick_xf,d6
                asr.w   #3,d6
                sub.w   win_ox,d6               ; world X of the left corner
                move.w  rick_yf,d7
                asr.w   #3,d7
                add.w   rk_h,d7
                sub.w   #DRAW_H,d7              ; top of the standing box
                sub.w   win_oy,d7               ; world Y
                ; --- parts (model) : x0,y0,x1,y1,z0,z1, colours, anim<<8
.part:          move.w  (a2)+,d0
                cmp.w   #-99,d0
                beq     .end
                move.w  (a2)+,d1
                move.w  (a2)+,d2
                move.w  (a2)+,d3
                move.w  (a2)+,d5
                move.w  d5,-(sp)                ; z0
                move.w  (a2)+,d5                ; z1
                move.w  (a2)+,d4                ; colour set
                lsl.w   #2,d4
                lea     setptr,a1
                move.l  (a1,d4.w),a1
                move.w  (a2)+,d4                ; animation (high byte)
                lsr.w   #8,d4
                btst    #0,d4                   ; front leg : + step
                beq.s   .b0
                add.w   an_sl,d0
                add.w   an_sl,d2
                sub.w   an_lf,d3
.b0:            btst    #1,d4                   ; back leg : - step
                beq.s   .b1
                sub.w   an_sl,d0
                sub.w   an_sl,d2
                sub.w   an_lb,d3
.b1:            btst    #2,d4                   ; front arm : - step
                beq.s   .b2
                sub.w   an_sl,d0
                sub.w   an_sl,d2
.b2:            btst    #3,d4                   ; back arm : + step
                beq.s   .b3
                add.w   an_sl,d0
                add.w   an_sl,d2
.b3:            btst    #4,d4                   ; ladder : limb A
                beq.s   .b4
                sub.w   an_la,d3
                btst    #6,d4                   ; (arm : goes up as a whole)
                beq.s   .b4
                sub.w   an_la,d1
.b4:            btst    #5,d4                   ; ladder : limb B
                beq.s   .b5
                sub.w   an_lb2,d3
                btst    #6,d4
                beq.s   .b5
                sub.w   an_lb2,d1
.b5:            tst.w   an_mir                  ; mirror : x -> RICK_W - x
                beq.s   .b6
                exg     d0,d2
                neg.w   d0
                neg.w   d2
                add.w   #RICK_W,d0
                add.w   #RICK_W,d2
.b6:
                tst.w   view_back               ; back view : first the
                beq.s   .b7                     ;  parts furthest from
                move.w  d0,d4                   ;  the camera (2 passes)
                add.w   d2,d4
                cmp.w   #RICK_W,d4              ; d4 >= RICK_W : front half
                sge     d4                      ;  (where Rick looks)
                tst.w   bv_dir
                bpl.s   .bf
                not.b   d4
.bf:            tst.w   rk_pass
                beq.s   .bp0
                not.b   d4                      ; 2nd pass : the other half
.bp0:           tst.b   d4
                bne.s   .b7
                addq.l  #2,sp                   ; (not in this pass)
                bra     .part
.b7:
                move.w  (sp)+,d4                ; z0
                add.w   #ZMID,d4
                add.w   #ZMID,d5
                add.w   d6,d0
                add.w   d6,d2
                add.w   d7,d1
                add.w   d7,d3
                movem.l d6-d7/a2,-(sp)
                bsr     draw_box
                movem.l (sp)+,d6-d7/a2
                bra     .part
.end:           tst.w   view_back
                beq.s   .e2
                tst.w   rk_pass
                bne.s   .e2
                move.w  #1,rk_pass              ; 2nd pass (near half)
                move.l  rk_mdl,a2
                bra     .p3b
.e2:            rts
.swing:         dc.w    0,2,0,-2
