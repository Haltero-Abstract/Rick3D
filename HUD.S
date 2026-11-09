;=====================================================================
; HUD.S - TOP HUD (lives, laser, bombs, level name)
;   (included by RICK3D.S ; the settings are in PARAMS.S)
;=====================================================================

;=====================================================================
; RICK'S HUD (at the top) : lives, laser, bombs - like in the real Rick
;   darkened band + 8x8 icons + numbers ; redrawn only if the
;   numbers change or if an object went over it (cache per screen)
;=====================================================================

hud_update:
                move.w  lives,d0
                move.w  ammo_las,d1
                move.w  ammo_bomb,d2
                tst.w   (a5)
                beq.s   .draw
                cmp.w   2(a5),d0
                bne.s   .draw
                cmp.w   4(a5),d1
                bne.s   .draw
                cmp.w   6(a5),d2
                bne.s   .draw
                move.l  score,d3
                cmp.l   8(a5),d3
                bne.s   .draw
                rts
.draw:          move.w  #1,(a5)
                movem.w d0-d2,2(a5)
                move.l  score,8(a5)
                movem.l d0-d7/a0-a5,-(sp)
                lea     bgbuf,a0                ; darkened scenery
                move.l  a6,a1
                move.l  #$7bef7bef,d2
                move.w  #HUD_H*LINEB/4-1,d0
.dk:            move.l  (a0)+,d1
                lsr.l   #1,d1
                and.l   d2,d1
                move.l  d1,(a1)+
                dbra    d0,.dk
                lea     ico_hat,a0              ; lives
                moveq   #4,d0
                bsr     .item
                move.w  lives,d3
                bsr     .num
                lea     ico_laser,a0            ; laser
                moveq   #44,d0
                bsr     .item
                move.w  ammo_las,d3
                bsr     .num
                lea     ico_dyn,a0              ; bombs
                moveq   #84,d0
                bsr     .item
                move.w  ammo_bomb,d3
                bsr     .num
                move.l  score,d0                ; score : 6 digits
                bsr     fmtscore
                move.l  a1,a2
                move.w  #SCORE_X,d0
                moveq   #3,d1
                bsr     put_text
                lea     t_lvlname,a2            ; level name on the right
                move.w  #SCR_W-6*10-4,d0
                moveq   #3,d1
                bsr     put_text
                movem.l (sp)+,d0-d7/a0-a5
                rts
.item:          moveq   #2,d1                   ; icon at (d0, 2)
                bsr     put_icon
                add.w   #11,d0
                rts
.num:           movem.w d0,-(sp)                ; number at (d0, 3)
                move.w  d3,d0
                bsr     fmtnum
                move.l  a1,a2
                movem.w (sp)+,d0
                moveq   #3,d1
                bra     put_text

; fmtscore : d0.l -> a1 = 6 digits with leading zeros (numbuf)
fmtscore:
                movem.l d0-d2,-(sp)
                cmp.l   #999999,d0
                bls.s   .ok
                move.l  #999999,d0
.ok:            lea     numbuf+8,a1
                clr.b   (a1)
                moveq   #5,d2
.d:             divul.l #10,d1:d0               ; d0 = quotient, d1 = remainder
                add.b   #'0',d1
                move.b  d1,-(a1)
                dbra    d2,.d
                movem.l (sp)+,d0-d2
                rts

; put_icon : 8x8 RGB565 icon (a0, 0 = transparent) at (d0, d1), screen a6
put_icon:
                movem.l d0-d3/a0-a1,-(sp)
                mulu    #LINEB,d1
                lea     (a6,d1.l),a1
                add.w   d0,d0
                adda.w  d0,a1
                moveq   #7,d3
.y:             moveq   #7,d2
.x:             move.w  (a0)+,d1
                beq.s   .t
                move.w  d1,(a1)
.t:             addq.l  #2,a1
                dbra    d2,.x
                lea     LINEB-16(a1),a1
                dbra    d3,.y
                movem.l (sp)+,d0-d3/a0-a1
                rts

; put_text : string a2 (end = 0) in white, 6x6 font, at (d0, d1), screen a6
put_text:
                movem.l d0-d5/a0-a4,-(sp)
                mulu    #LINEB,d1
                lea     (a6,d1.l),a4
                add.w   d0,d0
                adda.w  d0,a4
.ch:            moveq   #0,d0
                move.b  (a2)+,d0
                beq.s   .x
                cmp.w   #' ',d0
                bls.s   .nc
                sub.w   fontfirst,d0
                bmi.s   .nc
                add.w   d0,d0
                move.l  fontoff,a1
                move.w  (a1,d0.w),d3
                move.w  d3,d0
                lsr.w   #3,d0
                move.l  fontdat,a1
                adda.w  d0,a1
                and.w   #7,d3
                move.l  a4,a3
                moveq   #5,d4
.fl:            move.b  (a1),d2
                lsl.w   #8,d2
                move.b  1(a1),d2
                lsl.w   d3,d2
                moveq   #5,d5
                move.l  a3,a0
.pb:            add.w   d2,d2
                bcc.s   .p0
                move.w  #$ffff,(a0)
.p0:            addq.l  #2,a0
                dbra    d5,.pb
                lea     LINEB(a3),a3
                adda.w  fontw,a1
                dbra    d4,.fl
.nc:            lea     12(a4),a4
                bra.s   .ch
.x:             movem.l (sp)+,d0-d5/a0-a4
                rts
