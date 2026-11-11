;=====================================================================
; PLATEF.S - MOVING PLATFORMS, LIFTS, BUTTONS, PUNCH
;   (included by RICK3D.S ; the settings are in PARAMS.S)
;=====================================================================

;=====================================================================
; MOVING PLATFORMS, BUTTONS AND STICK
;   Lines added at the end of the .MAP (after the map) :
;     P col line width dcol dline speed mode
;       platform of <width> tiles, at (col, line) of the map
;       (row 0 = 1st row), which moves by dcol / dline tiles ;
;       speed in pixels per frame (1-4) ; mode A = back and forth on
;       its own, B = moves when its button is used (there or back),
;       C = one round trip per press, L = lift driven by Rick,
;       D = each press on ONE of its buttons sends it to the other end, where
;           it stops (2 buttons : the bottom one sends it up, the top
;           one sends it back down ; Rick can be on it)
;       [extra] : optional number after the mode : its button moves its
;           trip <extra> tiles further (ex. A between L98 and L90, then
;           between L90 and L82 after the button) ; back to the 1st trip
;           when Rick loses a life
;     S col line n      button at (col, line) that drives platform n
;                       (0 = 1st P line of the file)
;   Punch : fire + left / right, hits a button just in front of Rick.
;=====================================================================
                rsreset
PL_X            rs.w    1               ; position (world units)
PL_Y            rs.w    1
PL_W            rs.w    1               ; width
PL_AX           rs.w    1               ; start
PL_AY           rs.w    1
PL_BX           rs.w    1               ; end
PL_BY           rs.w    1
PL_SPD          rs.w    1
PL_ST           rs.w    1               ; 0 at A, 1 towards B, 2 at B, 3 towards A
PL_AUTO         rs.w    1
PL_DX           rs.w    1               ; move of this frame
PL_DY           rs.w    1
PL_WT           rs.w    1               ; wait at one end (back and forth)
PL_M0           rs.w    1               ; PL_AUTO of the .MAP (for the reset)
PL_EXX          rs.w    1               ; extended end (button : the trip
PL_EXY          rs.w    1               ;  moves further ; = end if no extra)
PL_XT           rs.w    1               ; 1 : trip moved (A = old B, B = extended end)
PL_OAX          rs.w    1               ; trip of the .MAP (for the reset)
PL_OAY          rs.w    1
PL_OBX          rs.w    1
PL_OBY          rs.w    1
PL_SIZE         rs.b    0
                rsreset
SW_X            rs.w    1
SW_Y            rs.w    1
SW_P            rs.w    1
SW_SIZE         rs.b    0
                rsreset
ZP_X            rs.w    1               ; electric arc : deadly zone
ZP_Y            rs.w    1               ;  as long as a button has not
ZP_W            rs.w    1               ;  cut it
ZP_H            rs.w    1
ZP_ON           rs.w    1
ZP_T            rs.w    1               ; 0 = fixed laser beam, 1 = canister
ZP_PON          rs.w    1               ; blinking : frames on (0 = steady)
ZP_POFF         rs.w    1               ;                frames off
ZP_TM           rs.w    1
ZP_ACT          rs.w    1               ; 1 = on right now
ZP_WP           rs.w    1               ; wave between 2 balls : position
ZP_WV           rs.w    1               ;  speed (+/-, in 1/4 pixel per frame)
ZP_WQ           rs.w    1               ;  position in 1/4 pixel
ZP_WW           rs.w    1               ;  width of the wave
ZP_ROD          rs.w    1               ;  height of the rods (towards the ceiling)
ZP_MV           rs.w    1               ; 1 = back-and-forth beam (Z ... 2)
ZP_BX0          rs.w    4               ; canister : drawn box in bgbuf (x0,y0,x1,y1)
ZP_BP           rs.l    1               ;  its pixels in can_pool (0 none, 1 empty, 2 box only)
ZP_SIZE         rs.b    0

; parse_extras : P / S lines after the map (a0 = text)
parse_extras:
                move.w  #-1,end_col             ; (no end of the level)
                clr.w   nplats
                clr.w   nsw
                clr.w   nlz
                clr.w   nzp
                clr.w   nen                     ; (enemies : ENNEMIS.S)
.l:             move.b  (a0)+,d0
                beq     .x
                cmp.b   #';',d0
                beq.s   .skip
                cmp.b   #'P',d0
                beq.s   .plat
                cmp.b   #'S',d0
                beq     .sw
                cmp.b   #'L',d0
                beq     .lz
                cmp.b   #'Z',d0
                beq     .zp
                cmp.b   #'E',d0
                beq     .en
                cmp.b   #'D',d0
                beq     .db
                cmp.b   #'G',d0
                beq     .gn
                cmp.b   #'W',d0
                beq     .wv
                cmp.b   #'F',d0                 ; F col line : end of the level
                beq     .fin
                cmp.b   #'N',d0                 ; N type col line [dir] : enemy
                beq     .enm
                bra     .l
.enm:           bsr     en_parse
                bra     .skip
.fin:           bsr     readsint                ; (top-left cell of Rick,
                move.w  d0,end_col              ;  like the start)
                bsr     readsint
                move.w  d0,end_row
                bra     .skip
.skip:          move.b  (a0)+,d0
                beq     .x
                cmp.b   #10,d0
                bne.s   .skip
                bra     .l
.plat:          move.w  nplats,d0
                cmp.w   #MAXPL,d0
                bhs.s   .skip
                mulu    #PL_SIZE,d0
                lea     plats,a1
                adda.w  d0,a1
                bsr     readsint                ; column
                lsl.w   #3,d0
                move.w  d0,PL_X(a1)
                move.w  d0,PL_AX(a1)
                bsr     readsint                ; line
                lsl.w   #3,d0
                move.w  d0,PL_Y(a1)
                move.w  d0,PL_AY(a1)
                bsr     readsint                ; width
                lsl.w   #3,d0
                move.w  d0,PL_W(a1)
                bsr     readsint                ; x move
                lsl.w   #3,d0
                add.w   PL_AX(a1),d0
                move.w  d0,PL_BX(a1)
                bsr     readsint                ; y move
                lsl.w   #3,d0
                add.w   PL_AY(a1),d0
                move.w  d0,PL_BY(a1)
                bsr     readsint                ; speed
                tst.w   d0
                bgt.s   .sp
                moveq   #1,d0
.sp:            move.w  d0,PL_SPD(a1)
                clr.w   PL_ST(a1)
                clr.w   PL_AUTO(a1)
                clr.w   PL_WT(a1)
                clr.l   PL_DX(a1)
.md:            move.b  (a0),d0                 ; mode
                beq.s   .pok
                cmp.b   #10,d0
                beq.s   .pok
                addq.l  #1,a0
                cmp.b   #'L',d0
                bne.s   .md1
                move.w  #2,PL_AUTO(a1)          ; lift : Rick drives it
                bra.s   .pok
.md1:           cmp.b   #'C',d0                 ; C : one round trip per call
                bne.s   .md3
                move.w  #3,PL_AUTO(a1)
                bra.s   .pok
.md3:           cmp.b   #'D',d0                 ; D : each button sends it to
                bne.s   .md2                    ;  the other end, where it stops
                move.w  #4,PL_M0(a1)
                bra.s   .pok2
.md2:           cmp.b   #'A',d0
                bne.s   .md
                move.w  #1,PL_AUTO(a1)
.pok:           move.w  PL_AUTO(a1),PL_M0(a1)
                cmp.w   #3,PL_AUTO(a1)          ; C : stopped at the start
                bne.s   .pok2
                clr.w   PL_AUTO(a1)
.pok2:          bsr     readopt                 ; [extra travel (tiles) : its
                move.w  PL_BX(a1),PL_EXX(a1)    ;  button moves the trip further]
                move.w  PL_BY(a1),PL_EXY(a1)
                move.l  PL_AX(a1),PL_OAX(a1)    ; (AX,AY)
                move.l  PL_BX(a1),PL_OBX(a1)    ; (BX,BY)
                clr.w   PL_XT(a1)
                tst.w   d0
                ble.s   .pe
                lsl.w   #3,d0
                move.w  PL_BX(a1),d1            ; same direction as A -> B
                cmp.w   PL_AX(a1),d1
                beq.s   .pey
                bgt.s   .pxp
                sub.w   d0,PL_EXX(a1)
                bra.s   .pey
.pxp:           add.w   d0,PL_EXX(a1)
.pey:           move.w  PL_BY(a1),d1
                cmp.w   PL_AY(a1),d1
                beq.s   .pe
                bgt.s   .pyp
                sub.w   d0,PL_EXY(a1)
                bra.s   .pe
.pyp:           add.w   d0,PL_EXY(a1)
.pe:            addq.w  #1,nplats
                bra     .skip
.sw:            move.w  nsw,d0
                cmp.w   #MAXSW,d0
                bhs     .skip
                mulu    #SW_SIZE,d0
                lea     switches,a1
                adda.w  d0,a1
                bsr     readsint
                lsl.w   #3,d0
                move.w  d0,SW_X(a1)
                bsr     readsint
                lsl.w   #3,d0
                move.w  d0,SW_Y(a1)
                bsr     readsint
                move.w  d0,SW_P(a1)
                addq.w  #1,nsw
                bra     .skip
.gn:            moveq   #3,d1                   ; green canister (1 life)
                bra     .zp1
.db:            moveq   #2,d1                   ; bomb canister
                bra     .zp1
.en:            moveq   #1,d1                   ; energy canister
                bra     .zp1
.wv:            move.w  nzp,d0                  ; W left_ball line right_ball [speed] [width]
                cmp.w   #MAXZP,d0               ;  electric wave between 2 balls
                bhs     .skip                   ;  (balls of 2 x 2 tiles)
                mulu    #ZP_SIZE,d0
                lea     zaps,a1
                adda.w  d0,a1
                move.w  #4,ZP_T(a1)
                clr.w   ZP_MV(a1)
                bsr     readsint                ; column of the left ball
                move.w  d0,d2
                addq.w  #2,d0
                lsl.w   #3,d0
                move.w  d0,ZP_X(a1)             ; start of the wave path
                bsr     readsint                ; line (top of the balls)
                lsl.w   #3,d0
                move.w  d0,ZP_Y(a1)
                move.w  #16,ZP_H(a1)
                bsr     readsint                ; column of the right ball
                sub.w   d2,d0
                subq.w  #2,d0
                lsl.w   #3,d0
                move.w  d0,ZP_W(a1)             ; length of the path
                bsr     readopt
                tst.w   d0
                bne.s   .wv1
                moveq   #1,d0
.wv1:           mulu    #WAVE_Q,d0              ; speed 1 = WAVE_Q / 4 pixel per frame
                move.w  d0,ZP_WV(a1)
                clr.w   ZP_WQ(a1)
                bsr     readopt
                tst.w   d0
                bne.s   .wv2
                moveq   #4,d0
.wv2:           lsl.w   #3,d0
                move.w  d0,ZP_WW(a1)
                clr.w   ZP_WP(a1)
                clr.w   ZP_PON(a1)
                clr.w   ZP_ROD(a1)              ; (computed when drawing)
                move.w  #1,ZP_ON(a1)
                move.w  #1,ZP_ACT(a1)
                addq.w  #1,nzp
                bra     .skip
.zp:            moveq   #0,d1                   ; fixed laser beam
.zp1:           move.w  nzp,d0
                cmp.w   #MAXZP,d0
                bhs     .skip
                mulu    #ZP_SIZE,d0
                lea     zaps,a1
                adda.w  d0,a1
                move.w  d1,ZP_T(a1)
                clr.w   ZP_MV(a1)
                clr.w   ZP_PON(a1)
                tst.w   d1
                beq.s   .zp2
                bsr     readsint                ; E col line : 2 x 2 tiles
                lsl.w   #3,d0
                move.w  d0,ZP_X(a1)
                bsr     readsint
                lsl.w   #3,d0
                move.w  d0,ZP_Y(a1)
                move.w  #16,ZP_W(a1)
                move.w  #16,ZP_H(a1)
                move.w  #1,ZP_ON(a1)
                move.w  #1,ZP_ACT(a1)
                clr.w   ZP_PON(a1)
                addq.w  #1,nzp
                bra     .skip
.zp2:                bsr     readsint                ; column
                lsl.w   #3,d0
                move.w  d0,ZP_X(a1)
                bsr     readsint                ; line
                lsl.w   #3,d0
                move.w  d0,ZP_Y(a1)
                bsr     readsint                ; width (tiles)
                lsl.w   #3,d0
                move.w  d0,ZP_W(a1)
                bsr     readsint                ; height (tiles)
                lsl.w   #3,d0
                move.w  d0,ZP_H(a1)
                bsr     readopt                 ; [on off] (frames)
                move.w  d0,ZP_PON(a1)
                move.w  d0,ZP_TM(a1)
                bsr     readopt
                move.w  d0,ZP_POFF(a1)
                bsr     readopt                 ; [1 = scenery : harmless electric
                cmp.w   #1,d0                   ;  bar, without emitters]
                bne.s   .zp4
                move.w  #5,ZP_T(a1)
                clr.w   ZP_PON(a1)              ; (does not blink)
                bra.s   .zp3
.zp4:           cmp.w   #2,d0                   ; [2 = back and forth : a piece of
                bne.s   .zp3                    ;  beam runs from one emitter to
                move.w  #1,ZP_MV(a1)            ;  the other and comes back]
                clr.w   ZP_PON(a1)
                move.w  #ZAP_MV_SPD*4,ZP_WV(a1)
                clr.w   ZP_WQ(a1)
                move.w  #ZAP_MV_W,ZP_WW(a1)
                clr.w   ZP_WP(a1)
.zp3:           move.w  #1,ZP_ON(a1)
                move.w  #1,ZP_ACT(a1)
                addq.w  #1,nzp
                bra     .skip
.lz:            move.w  nlz,d0                  ; trap laser
                cmp.w   #MAXLZ,d0
                bhs     .skip
                mulu    #LZ_SIZE,d0
                lea     lasers,a1
                adda.w  d0,a1
                bsr     readsint
                lsl.w   #3,d0
                addq.w  #4,d0
                move.w  d0,LZ_X0(a1)
                bsr     readsint
                lsl.w   #3,d0
                move.w  d0,LZ_Y0(a1)
                bsr     readsint
                move.w  d0,LZ_DX(a1)
                bsr     readsint
                move.w  d0,LZ_DY(a1)
                bsr     readsint
                add.w   #LZ_GRACE,d0
                move.w  d0,LZ_T(a1)             ; 1st start (frames)
                move.w  d0,LZ_D0(a1)
                bsr     readsint
                move.w  d0,LZ_PER(a1)
                bsr     readopt                 ; [1 = straight down, without aiming]
                move.w  d0,LZ_STR(a1)
                bsr     readopt                 ; [column row : the laser fires
                move.w  d0,LZ_TC(a1)            ;  only once Rick has reached
                bsr     readopt                 ;  this cell]
                move.w  d0,LZ_TR(a1)
                clr.w   LZ_ARM(a1)
                clr.w   LZ_ON(a1)
                clr.w   LZ_EXP(a1)
                clr.w   LZ_TRP(a1)
                addq.w  #1,nlz
                bra     .skip
.x:             movem.l d1/a1-a2,-(sp)          ; lasers of the trap buttons
                lea     switches,a2             ;  (S 300+n) : they never fire
                move.w  nsw,d1                  ;  on their own, ONE shot
                bra.s   .tn                     ;  each time the button is hit
.tl:            move.w  SW_P(a2),d0
                sub.w   #300,d0
                bmi.s   .tx
                cmp.w   nlz,d0
                bhs.s   .tx
                mulu    #LZ_SIZE,d0
                lea     lasers,a1
                adda.w  d0,a1
                move.w  #1,LZ_TRP(a1)
                move.w  #32767,LZ_T(a1)
                move.w  #32767,LZ_D0(a1)
                move.w  #32767,LZ_PER(a1)
.tx:            lea     SW_SIZE(a2),a2
.tn:            dbra    d1,.tl
                movem.l (sp)+,d1/a1-a2
                rts

; readsint : signed number (a0 = text) -> d0.w
; readopt : optional number at the end of the line (else d0 = 0, nothing read)
readopt:
.sp:            move.b  (a0),d0
                cmp.b   #' ',d0
                beq.s   .s1
                cmp.b   #9,d0
                bne.s   .t
.s1:            addq.l  #1,a0
                bra.s   .sp
.t:             cmp.b   #'-',d0
                beq     readsint
                cmp.b   #'0',d0
                blo.s   .z
                cmp.b   #'9',d0
                bls     readsint
.z:             moveq   #0,d0
                rts

readsint:
                moveq   #0,d1
.sk:            move.b  (a0),d0
                beq.s   .z
                cmp.b   #'-',d0
                beq.s   .neg
                cmp.b   #'0',d0
                blo.s   .n
                cmp.b   #'9',d0
                bls.s   .num
.n:             addq.l  #1,a0
                bra.s   .sk
.neg:           moveq   #1,d1
                addq.l  #1,a0
.num:           move.w  d1,-(sp)
                bsr     readint
                move.w  (sp)+,d1
                tst.w   d1
                beq.s   .p
                neg.w   d0
.p:             rts
.z:             moveq   #0,d0
                rts

; update_plats : moves the platforms ; Rick follows the one he is on
update_plats:
                movem.l d0-d4/a0,-(sp)
                lea     plats,a0
                move.w  nplats,d4
                bra     .nx
.lp:            clr.l   PL_DX(a0)
                move.w  PL_ST(a0),d0
                cmp.w   #2,PL_AUTO(a0)          ; lift (on the screw)
                bne.s   .nl
                move.w  nplats,d1               ; d1 = platform number
                subq.w  #1,d1
                sub.w   d4,d1
                cmp.w   rick_onplat,d1
                bne.s   .m                      ; Rick is not on it : it
                move.w  lift_in,d1              ;  finishes a button call
                beq     .m                      ; Rick on it, nothing pressed : it
                                                ;  goes on up to the end (a single
                                                ;  press of up / down is enough)
                move.w  PL_BY(a0),d2            ; up -> the highest end
                cmp.w   PL_AY(a0),d2            ;  (or B if horizontal)
                ble.s   .bh
                btst    #0,d1                   ; A higher than B
                beq.s   .ld
                moveq   #3,d0
                bra.s   .m
.ld:            moveq   #1,d0
                bra.s   .m
.bh:            btst    #0,d1                   ; B higher (or same height)
                beq.s   .ld2
                moveq   #1,d0
                bra.s   .m
.ld2:           moveq   #3,d0
                bra.s   .m
.nl:            tst.w   PL_AUTO(a0)             ; back and forth : leaves again on its own
                bne.s   .na
                cmp.w   #3,PL_M0(a0)            ; mode C reached the end : pause
                bne     .m                      ;  then back to the start where
                cmp.w   #2,d0                   ;  it stops
                bne     .m
                tst.w   PL_WT(a0)
                beq.s   .cr
                subq.w  #1,PL_WT(a0)
                bra     .next
.cr:            moveq   #3,d0
                bra     .m
.na:
                tst.w   PL_WT(a0)               ;  (after a pause at each end)
                beq.s   .nw
                subq.w  #1,PL_WT(a0)
                bra     .next
.nw:            cmp.w   #0,d0
                bne.s   .a2
                moveq   #1,d0
.a2:            cmp.w   #2,d0
                bne.s   .m
                moveq   #3,d0
.m:             move.w  d0,PL_ST(a0)
                move.w  PL_BX(a0),d1            ; target
                move.w  PL_BY(a0),d2
                cmp.w   #1,d0
                beq.s   .go
                move.w  PL_AX(a0),d1
                move.w  PL_AY(a0),d2
                cmp.w   #3,d0
                bne     .next
.go:            sub.w   PL_X(a0),d1             ; x step
                move.w  PL_SPD(a0),d3
                cmp.w   d3,d1
                ble.s   .x1
                move.w  d3,d1
.x1:            neg.w   d3
                cmp.w   d3,d1
                bge.s   .x2
                move.w  d3,d1
.x2:            sub.w   PL_Y(a0),d2             ; y step
                neg.w   d3
                cmp.w   d3,d2
                ble.s   .y1
                move.w  d3,d2
.y1:            neg.w   d3
                cmp.w   d3,d2
                bge.s   .y2
                move.w  d3,d2
.y2:            add.w   d1,PL_X(a0)
                add.w   d2,PL_Y(a0)
                move.w  d1,PL_DX(a0)
                move.w  d2,PL_DY(a0)
                tst.w   d1                      ; arrived ?
                bne.s   .next
                tst.w   d2
                bne.s   .next
                move.w  PL_ST(a0),d0
                addq.w  #1,d0
                and.w   #3,d0                   ; 1 -> 2, 3 -> 0
                move.w  d0,PL_ST(a0)
                move.w  #PLAT_WAIT,PL_WT(a0)    ; pause at the end
.next:          lea     PL_SIZE(a0),a0
.nx:            dbra    d4,.lp
                move.w  rick_onplat,d0          ; Rick standing on it : he follows
                bmi.s   .x
                mulu    #PL_SIZE,d0
                lea     plats,a0
                adda.w  d0,a0
                move.w  PL_DX(a0),d0
                lsl.w   #3,d0
                add.w   d0,rick_xf
                move.w  PL_DY(a0),d0
                lsl.w   #3,d0
                add.w   d0,rick_yf
.x:             movem.l (sp)+,d0-d4/a0
                rts

; plat_floor : d0 = x, d1 = y -> d2 = 1 if the top of a moving
;              platform is on this row at this place (plat_hit = n)
plat_floor:
                movem.l d3/a0,-(sp)
                lea     plats,a0
                moveq   #0,d3
.lp:            cmp.w   nplats,d3
                bhs.s   .no
                cmp.w   PL_Y(a0),d1
                bne.s   .nx
                cmp.w   PL_X(a0),d0
                blt.s   .nx
                move.w  PL_X(a0),d2
                add.w   PL_W(a0),d2
                cmp.w   d2,d0
                bge.s   .nx
                move.w  d3,plat_hit
                moveq   #1,d2
                bra.s   .x
.nx:            lea     PL_SIZE(a0),a0
                addq.w  #1,d3
                bra.s   .lp
.no:            moveq   #0,d2
.x:             movem.l (sp)+,d3/a0
                rts

; poke : stick hit in front of Rick ; uses a button that is hit
poke:
                tst.w   stick_t
                bne     .x
                move.w  #16,stick_t
                lea     sfx_poke,a0
                bsr     sfx_play
                move.w  rick_xf,d0              ; zone hit : x0..x1, y0..y1
                asr.w   #3,d0
                tst.w   rick_dir
                bmi.s   .l
                add.w   #RICK_W-4,d0            ; zone : 4 px inside Rick +
                bra.s   .s                      ;  16 px in front of him
.l:             sub.w   #16,d0
.s:             move.w  d0,d1
                add.w   #20,d1
                move.w  rick_yf,d2
                asr.w   #3,d2
                addq.w  #2,d2
                move.w  d2,d3
                add.w   #RICK_H,d3
                lea     switches,a0
                move.w  nsw,d4
                bra     .nx
.lp:            move.w  SW_X(a0),d5             ; button (8x8) in the zone ?
                addq.w  #8,d5
                cmp.w   d0,d5
                ble     .nn
                cmp.w   SW_X(a0),d1
                ble     .nn
                move.w  SW_Y(a0),d5
                addq.w  #8,d5
                cmp.w   d2,d5
                ble     .nn
                cmp.w   SW_Y(a0),d3
                ble     .nn
                move.w  SW_P(a0),d5             ; drives its platform
                cmp.w   #300,d5                 ; 300+n : trap, triggers laser n
                bge     .tr
                cmp.w   #200,d5                 ; 200+n : cuts beam n
                bge     .zp
                cmp.w   #100,d5                 ; 100+n : cuts laser n
                bge     .lz
                cmp.w   nplats,d5
                bhs     .nn
                movem.l d0-d1/a0-a1,-(sp)
                mulu    #PL_SIZE,d5
                lea     plats,a1
                adda.w  d5,a1
                move.w  PL_EXX(a1),d5           ; extra travel : the button
                cmp.w   PL_BX(a1),d5            ;  sends it further, once
                bne.s   .xt1
                move.w  PL_EXY(a1),d5
                cmp.w   PL_BY(a1),d5
                beq.s   .xt2
.xt1:           tst.w   PL_XT(a1)               ; (already moved)
                bne     .t3
                move.w  #1,PL_XT(a1)            ; new trip : old end -> extended end
                move.l  PL_BX(a1),PL_AX(a1)
                move.w  PL_EXX(a1),PL_BX(a1)
                move.w  PL_EXY(a1),PL_BY(a1)
                bra     .t3
.xt2:           cmp.w   #4,PL_M0(a1)            ; mode D : stopped at one end ->
                beq     .tg                     ;  leaves for the other (even with Rick)
                cmp.w   #3,PL_M0(a1)            ; mode C : leaves if it is at the start
                bne.s   .tb
                tst.w   PL_ST(a1)
                bne.s   .t3
                move.w  #1,PL_ST(a1)
                bra.s   .t3
.tb:            tst.w   PL_AUTO(a1)             ; mode B (called) : the button starts
                bne.s   .tg                     ;  it -> continuous round trips
                move.w  #1,PL_AUTO(a1)          ;  (like in the original)
                clr.w   PL_WT(a1)
                bra.s   .t3
.tg:            move.w  PL_ST(a1),d5
                cmp.w   #0,d5
                bne.s   .t2
                move.w  #1,PL_ST(a1)            ; at A -> leaves for B
.t2:            cmp.w   #2,d5
                bne.s   .t3
                move.w  #3,PL_ST(a1)            ; at B -> back to A
.t3:            lea     sfx_switch,a0
                bsr     sfx_play
                movem.l (sp)+,d0-d1/a0-a1
.nn:            lea     SW_SIZE(a0),a0
.nx:            dbra    d4,.lp
.x:             rts
.zp:            sub.w   #200,d5
                cmp.w   nzp,d5
                bhs.s   .nn
                mulu    #ZP_SIZE,d5
                lea     zaps,a1
                tst.w   ZP_ON(a1,d5.w)
                beq.s   .nn
                clr.w   ZP_ON(a1,d5.w)
                bra.s   .snd
.tr:            sub.w   #300,d5                 ; trap button : the laser fires
                cmp.w   nlz,d5
                bhs     .nn
                mulu    #LZ_SIZE,d5
                lea     lasers,a1
                adda.w  d5,a1
                tst.w   LZ_TRP(a1)              ; one shot per press (not while
                beq     .nn                     ;  the previous one is flying)
                tst.w   LZ_ON(a1)
                bne     .nn
                move.w  #1,LZ_T(a1)
                clr.w   lz_cool
                bra     .snd
.lz:            sub.w   #100,d5
                cmp.w   nlz,d5
                bhs.s   .nn
                mulu    #LZ_SIZE,d5
                lea     lasers,a1
                adda.w  d5,a1
                move.w  #32767,LZ_D0(a1)        ; no longer fires
                move.w  #32767,LZ_T(a1)
.snd:           movem.l d0-d1/a0-a1,-(sp)
                lea     sfx_switch,a0
                bsr     sfx_play
                movem.l (sp)+,d0-d1/a0-a1
                bra     .nn

; draw_mobile : moving platforms, buttons, stick
draw_plats:
                lea     plats,a2
                move.w  nplats,d7
                bra.s   .pn
.pl:            move.w  PL_X(a2),d0
                sub.w   win_ox,d0
                move.w  d0,d2
                add.w   PL_W(a2),d2
                move.w  PL_Y(a2),d1
                sub.w   win_oy,d1
                move.w  d1,d3
                addq.w  #4,d3
                bsr     boxvis
                bne.s   .pk
                jsr     plat_spr                ; cached sprite (SPRITES.S, S key)
                beq.s   .pp
                move.w  #PLAT_Z0,d4             ; tube in the middle of the depth :
                move.w  #PLAT_Z1,d5             ;  does not overlap the walls
                lea     col_mplat,a1
                bsr     draw_box
.pp:            bsr     bb_push
.pk:            lea     PL_SIZE(a2),a2
.pn:            dbra    d7,.pl
                rts

; buttons : drawn in the scenery (build_screen), on the back wall
draw_switches:
;   red block (SW_CUBE high, SW_LEN long in depth, centred on
;   the middle of the depth) sticking out SW_OUT pixels from the wall face
;   on the room side, at the hand height of Rick standing on the room floor.
;   Without a wall beside it : centred on the tile, held by a rod to the back wall.
                move.l  a0,-(sp)
                lea     switches,a2
                move.w  nsw,d7
                bra     .sn
.sl:            moveq   #0,d5                   ; d5 = 1 : no wall (rod)
                clr.w   sw_mir                  ; 1 : the button sticks out to the left
                move.w  SW_X(a2),d0
                move.w  SW_Y(a2),d1
                addq.w  #4,d0
                addq.w  #4,d1
                bsr     solid_px
                beq.s   .free
                addq.w  #8,d0                   ; button IN the wall :
                bsr     solid_px                ;  which face looks into the room ?
                bne.s   .fl
                move.w  SW_X(a2),d2             ; right face
                addq.w  #8,d2
                move.w  d2,d6                   ; d6 = column of the room (px)
                move.w  d2,d4
                addq.w  #SW_OUT,d4
                bra.s   .floor
.fl:            move.w  #1,sw_mir
                move.w  SW_X(a2),d2             ; left face
                move.w  d2,d4
                sub.w   #SW_OUT,d2
                move.w  SW_X(a2),d6
                subq.w  #8,d6
                bra.s   .floor
.free:          move.w  SW_X(a2),d6             ; button in an empty cell
                move.w  d6,d0
                subq.w  #1,d0
                bsr     solid_px
                beq.s   .nl
                move.w  d6,d2                   ; against the left wall
                move.w  d2,d4
                addq.w  #SW_OUT,d4
                bra.s   .floor
.nl:            add.w   #9,d0
                bsr     solid_px
                beq.s   .nr
                move.w  #1,sw_mir
                move.w  d6,d4                   ; against the right wall
                addq.w  #8,d4
                move.w  d4,d2
                subq.w  #SW_OUT,d2
                bra.s   .floor
.nr:            move.w  d6,d2                   ; in the middle of the tile
                addq.w  #2,d2                   ; (4 pixels wide)
                move.w  d2,d4
                addq.w  #4,d4
                moveq   #1,d5
.floor:         move.w  d2,-(sp)                ; (solid_px overwrites d2)
                move.w  d6,d0                   ; floor of the room under the button
                addq.w  #4,d0
                move.w  SW_Y(a2),d1
                addq.w  #4,d1
                moveq   #4,d3
.f1:            bsr     solid_px
                bne.s   .f3
                addq.w  #8,d1
                dbra    d3,.f1
                move.w  SW_Y(a2),d1             ; no floor found
                add.w   #12,d1
.f3:            and.w   #$fff8,d1               ; top of the floor
                sub.w   #16-SW_HAND+1+(SW_CUBE-4)/2,d1 ; centred at hand height
                move.w  (sp)+,d2
                tst.w   d5                      ; against a wall : its face AT THE
                bne.s   .ns                     ;  HEIGHT OF THE BUTTON (the wall may
                move.l  d2,a0                   ;  have a recess at this place)
                move.w  d1,-(sp)
                addq.w  #SW_CUBE/2,d1
                move.w  d6,d0                   ; from the cell of the room
                addq.w  #4,d0
                moveq   #3,d3
                tst.w   sw_mir
                bne.s   .wr
.wl:            bsr     solid_px                ; wall on the left
                bne.s   .wl2
                subq.w  #8,d0
                dbra    d3,.wl
                bra.s   .wd
.wl2:           and.w   #$fff8,d0
                addq.w  #8,d0
                move.l  d0,a0
                move.w  d0,d4
                addq.w  #SW_OUT,d4
                bra.s   .wd
.wr:            bsr     solid_px                ; wall on the right
                bne.s   .wr2
                addq.w  #8,d0
                dbra    d3,.wr
                bra.s   .wd
.wr2:           and.w   #$fff8,d0
                move.w  d0,d4
                subq.w  #SW_OUT,d0
                move.l  d0,a0
.wd:            move.w  (sp)+,d1
                move.l  a0,d2
.ns:            move.w  d2,d0                   ; -> screen coordinates
                move.w  d4,d2
                sub.w   win_ox,d0
                sub.w   win_ox,d2
                sub.w   win_oy,d1
                move.w  d1,d3
                addq.w  #SW_CUBE,d3
                move.w  d5,d6
                bsr     boxvis
                bne.s   .sk
                tst.w   d6
                beq.s   .nt
                movem.w d0-d3,-(sp)             ; rod towards the back wall
                addq.w  #1,d0
                move.w  d0,d2
                addq.w  #2,d2
                add.w   #SW_CUBE/2-1,d1
                move.w  d1,d3
                addq.w  #2,d3
                move.w  #ZMID+SW_LEN/2,d4
                move.w  #ZB,d5
                lea     col_nozzle,a1
                bsr     draw_box
                movem.w (sp)+,d0-d3
.nt:            movem.l d6-d7/a2,-(sp)          ; button : model (TILES.DAT),
                move.w  d0,d6                   ;  origin = wall face
                move.w  d1,d7
                move.w  sw_mir,d5
                beq.s   .nm
                move.w  d2,d6                   ; sticks out to the left : mirror
.nm:            lea     mdl_switch,a2
                bsr     draw_model
                movem.l (sp)+,d6-d7/a2
.sk:            lea     SW_SIZE(a2),a2
.sn:            dbra    d7,.sl
                move.l  (sp)+,a0
                rts

; stick (after Rick)
draw_mobile:
                rts                             ; (the punch is in Rick's pose)
                move.w  stick_t,d4              ; arm : goes out then back
                beq     .x
                cmp.w   #8,d4
                ble.s   .bl
                neg.w   d4
                add.w   #16,d4                  ; 0..8..0
.bl:            lsr.w   #1,d4                   ; reach 0..4
                move.w  rick_xf,d0
                asr.w   #3,d0
                sub.w   win_ox,d0
                move.w  rick_yf,d1
                asr.w   #3,d1
                sub.w   win_oy,d1
                add.w   #SW_HAND,d1             ; at chest height
                move.w  d1,d3
                addq.w  #2,d3
                tst.w   rick_dir
                bmi.s   .bg
                add.w   #RICK_W-4,d0            ; handle : from the chest to the right
                move.w  d0,d2
                addq.w  #2,d2
                add.w   d4,d2
                bsr.s   .slv
                move.w  d2,d0                   ; fist
                addq.w  #2,d2
                bra.s   .fist
.bg:            addq.w  #4,d0                   ; handle to the left
                move.w  d0,d2
                subq.w  #2,d0
                sub.w   d4,d0
                bsr.s   .slv
                move.w  d0,d2                   ; fist
                subq.w  #2,d0
.fist:          subq.w  #1,d1
                addq.w  #1,d3
                move.w  #ZMID-6,d4
                move.w  #ZMID-3,d5
                lea     col_stick,a1
                bsr     draw_box
                bsr     bb_push
                rts
.slv:           movem.w d0-d3,-(sp)
                move.w  #ZMID-6,d4
                move.w  #ZMID-3,d5
                lea     col_arm,a1
                bsr     draw_box
                bsr     bb_push
                movem.w (sp)+,d0-d3
                rts
.x:             rts
; boxvis : is box d0..d3 visible on the screen ? (Z = 1 if yes)
boxvis:         cmp.w   #OX+8,d0
                bgt.s   .no
                cmp.w   #-OX-8,d2
                blt.s   .no
                cmp.w   #OY+8,d1
                bgt.s   .no
                cmp.w   #-OY-8,d3
                blt.s   .no
                cmp.w   d0,d0
                rts
.no:            moveq   #1,d4
                rts

;---------------------------------------------------------------------
; plat_reset : Rick died -> the platforms called by a button
;   (mode B) go back to their start, stopped (press again)
plat_reset:
                movem.l d7/a1,-(sp)
                lea     plats,a1
                move.w  nplats,d7
                bra.s   .n
.l:             tst.w   PL_XT(a1)               ; trip moved by its button :
                beq.s   .l0                     ;  back to the trip of the .MAP
                clr.w   PL_XT(a1)
                move.l  PL_OAX(a1),PL_AX(a1)
                move.l  PL_OBX(a1),PL_BX(a1)
.l0:            cmp.w   #1,PL_M0(a1)            ; (not the back-and-forth A)
                beq.s   .s
                cmp.w   #2,PL_M0(a1)            ; lift L : stays drivable
                beq.s   .rp
                clr.w   PL_AUTO(a1)
.rp:            clr.w   PL_ST(a1)
                clr.w   PL_WT(a1)
                clr.l   PL_DX(a1)
                move.w  PL_AX(a1),PL_X(a1)
                move.w  PL_AY(a1),PL_Y(a1)
.s:             lea     PL_SIZE(a1),a1
.n:             dbra    d7,.l
                movem.l (sp)+,d7/a1
                rts
