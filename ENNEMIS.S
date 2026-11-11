;=====================================================================
; ENNEMIS.S - ALL THE ENEMIES : types, behaviours, collisions, drawing
;   (included by RICK3D.S ; the settings are in PARAMS.S)
;
; .MAP line (after the map, like the other objects) :
;     N type col line [dir]
;       type : 1 = enemy 1 (London guard robot, level 1)
;       col line : top-left cell of the enemy (2 tiles high, like Rick's
;                  start) ; it falls onto the floor below
;       dir  : 0 = looks right (default), 1 = looks left
;
; Each TYPE (table en_types) has its own behaviour routine, its 2 models
;   (walking side view, on a ladder) and its speeds / ranges / points.
; Generic behaviours (they can be given to any type) :
;   en_patrol : walks left-right, turns at a wall or at the edge of a floor
;   en_seek   : patrol ; when Rick is on the same floor and in range, it
;               walks towards him (and waits at the edge if it cannot go on)
;   en_follow : en_seek + if Rick is in range on another floor, it walks
;               towards him and takes the ladders (up or down) it meets,
;               leaves the ladder on Rick's floor ; stuck -> patrols
;               for EN_GIVEUP frames
; Enemy 1 = en_follow (the guards of Hyde Park climb the ladders).
;
; Touching an enemy kills Rick (like the traps) ; Rick's laser or bomb
;   kills it (points of its type -> score). When Rick loses a life, the
;   living enemies go back to their place ; the killed ones stay dead
;   until the level is loaded again.
; Enemies only move when they are on the screen shown (or just beside).
;=====================================================================

                rsreset                         ; --- an enemy
EN_ST           rs.w    1               ; 0 none / dead, 1 walks, 2 ladder, 3 falls, 4 dying
EN_TY           rs.w    1               ; type (0 = enemy 1)
EN_XF           rs.w    1               ; x * 8 (level, left)
EN_YF           rs.w    1               ; y * 8 (level, top)
EN_DIR          rs.w    1               ; 1 = right, -1 = left
EN_CD           rs.w    1               ; ladder : -1 up, 1 down
EN_LX           rs.w    1               ; ladder : x of its middle (units)
EN_VY           rs.w    1               ; falling speed (1/8)
EN_PH           rs.w    1               ; animation
EN_TM           rs.w    1               ; dying : timer ; follow : patrols while > 0
EN_X0           rs.w    1               ; place in the .MAP (reset)
EN_Y0           rs.w    1
EN_D0           rs.w    1
EN_MN           rs.w    1               ; patrol limits (x * 8 of the left ; type 2)
EN_MX           rs.w    1
EN_FK           rs.l    1               ; en_findlad : last search (x, y, way ; -1 none)
EN_FX           rs.w    1               ;  its result : x of the ladder (-1 : none)
EN_SIZE         rs.b    0

                rsreset                         ; --- a type
ET_BEH          rs.l    1               ; behaviour routine (a2 = enemy, a3 = type)
ET_MSIDE        rs.l    1               ; model : side view (looks right)
ET_MCLB         rs.l    1               ; model : on a ladder
ET_SPD          rs.w    1               ; patrol speed (1/8 unit per frame)
ET_CSPD         rs.w    1               ; chasing speed
ET_LSPD         rs.w    1               ; ladder speed
ET_RX           rs.w    1               ; sees Rick up to RX units horizontally
ET_RY           rs.w    1               ;  and RY vertically (other floor)
ET_PTS          rs.w    1               ; points when killed
ET_HT           rs.w    1               ; top of its hit box (units below the 20 high box)
ET_SIZE         rs.b    0

en_types:       ; enemy 1 : London guard robot (Hyde Park)
                dc.l    en_follow,mdl_en1side,mdl_en1climb
                dc.w    6,9,6,160,160,100,0
                ; enemy 2 : small "bell" droid : patrols between 2 columns
                dc.l    en_bounded,mdl_en2side,mdl_en2side
                dc.w    9,9,0,0,0,100,7
EN_NTYPES       equ     2

;---------------------------------------------------------------------
; en_parse : a0 = text after 'N' (called by parse_extras)
en_parse:
                move.w  nen,d0
                cmp.w   #MAXEN,d0
                bhs.s   .x
                mulu    #EN_SIZE,d0
                lea     enemies,a1
                adda.w  d0,a1
                bsr     readsint                ; type (1..)
                subq.w  #1,d0
                bmi.s   .t0
                cmp.w   #EN_NTYPES,d0
                blo.s   .t1
.t0:            moveq   #0,d0
.t1:            move.w  d0,EN_TY(a1)
                bsr     readsint                ; column
                lsl.w   #6,d0
                move.w  d0,EN_X0(a1)
                bsr     readsint                ; line : feet 2 tiles below
                lsl.w   #6,d0
                add.w   #(16-EN_H)*8,d0
                move.w  d0,EN_Y0(a1)
                bsr     readopt                 ; [1 = looks left]
                move.w  #1,EN_D0(a1)
                cmp.w   #1,d0
                bne.s   .d
                move.w  #-1,EN_D0(a1)
.d:             bsr     readopt                 ; [cmin cmax] : patrol limits
                lsl.w   #6,d0
                move.w  d0,EN_MN(a1)
                bsr     readopt
                lsl.w   #6,d0
                bne.s   .m
                move.w  #$7fff,d0               ; (none)
.m:             move.w  d0,EN_MX(a1)
                bsr     en_place
                addq.w  #1,nen
.x:             rts

; en_place : a1 = enemy -> back at its place of the .MAP
en_place:       move.w  EN_X0(a1),EN_XF(a1)
                move.w  EN_Y0(a1),EN_YF(a1)
                move.w  EN_D0(a1),EN_DIR(a1)
                move.w  #3,EN_ST(a1)            ; (falls onto its floor)
                clr.w   EN_VY(a1)
                clr.w   EN_PH(a1)
                clr.w   EN_TM(a1)
                move.l  #-1,EN_FK(a1)
                rts

; en_reset : Rick lost a life -> the living enemies go back to their place
en_reset:
                movem.l d0/d7/a1,-(sp)
                move.w  nen,d7
                subq.w  #1,d7
                bmi.s   .x
                lea     enemies,a1
.lp:            move.w  EN_ST(a1),d0
                beq.s   .nx
                cmp.w   #4,d0                   ; dying : dead
                bne.s   .pl
                clr.w   EN_ST(a1)
                bra.s   .nx
.pl:            bsr     en_place
.nx:            lea     EN_SIZE(a1),a1
                dbra    d7,.lp
.x:             movem.l (sp)+,d0/d7/a1
                rts

;---------------------------------------------------------------------
; update_enemies : behaviours, falls, weapons, contact with Rick (1 frame)
update_enemies:
                movem.l d0-d7/a0-a4,-(sp)
                move.w  nen,d7
                subq.w  #1,d7
                bmi     .x
                lea     enemies,a2
.lp:            move.w  EN_ST(a2),d0
                beq     .nx
                cmp.w   #4,d0
                bne.s   .alive
                subq.w  #1,EN_TM(a2)            ; dying : blinks, then disappears
                bne     .nx
                clr.w   EN_ST(a2)
                bra     .nx
.alive:         bsr     en_onscr                ; only near the screen shown
                bne     .nx
                move.w  EN_TY(a2),d0
                mulu    #ET_SIZE,d0
                lea     en_types,a3
                adda.w  d0,a3
                tst.w   rick_dead               ; Rick dying : everything waits
                bne     .nx
                cmp.w   #3,EN_ST(a2)
                bne.s   .beh
                bsr     en_fall
                bra.s   .chk
.beh:           move.l  ET_BEH(a3),a0
                jsr     (a0)
.chk:           tst.w   EN_ST(a2)
                beq.s   .nx
                bsr     en_hits
.nx:            lea     EN_SIZE(a2),a2
                dbra    d7,.lp
.x:             movem.l (sp)+,d0-d7/a0-a4
                rts

; en_onscr : a2 = enemy -> Z = 1 if on the screen shown (or just beside)
en_onscr:       move.w  EN_XF(a2),d0
                asr.w   #3,d0
                add.w   #EN_W/2,d0
                sub.w   win_ox,d0
                bpl.s   .a
                neg.w   d0
.a:             cmp.w   #OX+16,d0
                bge.s   .no
                move.w  EN_YF(a2),d0
                asr.w   #3,d0
                add.w   #EN_H/2,d0
                sub.w   win_oy,d0
                bpl.s   .b
                neg.w   d0
.b:             cmp.w   #OY+16,d0
                bge.s   .no
                moveq   #0,d0
                rts
.no:            moveq   #1,d0
                rts

; en_pos : a2 = enemy -> d0 = x (left), d1 = y of the feet (units)
en_pos:         move.w  EN_XF(a2),d0
                asr.w   #3,d0
                move.w  EN_YF(a2),d1
                asr.w   #3,d1
                add.w   #EN_H,d1
                rts

; en_support : d0 = x (left), d1 = y of the feet -> Z = 0 if something
;   holds the enemy (floor under one foot, or a ladder) ; d0/d1 kept
en_support:
                movem.l d0-d1/d3,-(sp)
                move.w  plat_hit,-(sp)
                addq.w  #2,d0
                bsr     floor_px
                bne.s   .y
                add.w   #EN_W-5,d0
                bsr     floor_px
                bne.s   .y
                subq.w  #EN_W/2-3,d0            ; (middle)
                bsr     ladder_px
                beq.s   .y
                moveq   #0,d2
                bra.s   .x
.y:             moveq   #1,d2
.x:             move.w  (sp)+,plat_hit
                movem.l (sp)+,d0-d1/d3
                tst.w   d2
                rts

; en_ground : walking enemy without floor -> falls
en_ground:      bsr     en_pos
                bsr     en_support
                bne.s   .x
                move.w  #3,EN_ST(a2)
                clr.w   EN_VY(a2)
.x:             rts

; en_fall : gravity, lands on the first floor met
en_fall:
                move.w  EN_VY(a2),d3
                addq.w  #GRAV,d3
                cmp.w   #VMAX,d3
                ble.s   .v
                move.w  #VMAX,d3
.v:             move.w  d3,EN_VY(a2)
                move.w  EN_YF(a2),d4
                add.w   d3,d4                   ; new y * 8
                move.w  d4,d5
                asr.w   #3,d5
                add.w   #EN_H,d5                ; new feet
                bsr     en_pos
.lp:            bsr     en_support
                bne.s   .land
                cmp.w   d5,d1
                bge.s   .mv
                addq.w  #1,d1
                bra.s   .lp
.mv:            move.w  d4,EN_YF(a2)
                move.w  lev_h,d0                ; out of the map : gone
                lsl.w   #3,d0
                cmp.w   d0,d1
                blt.s   .x
                clr.w   EN_ST(a2)
.x:             rts
.land:          sub.w   #EN_H,d1
                lsl.w   #3,d1
                move.w  d1,EN_YF(a2)
                clr.w   EN_VY(a2)
                move.w  #1,EN_ST(a2)
                rts

; en_walk : d3 = move (1/8 unit, signed) -> d2 = 0 moved,
;   1 blocked (wall in front, or no floor in front : not moved)
en_walk:
                move.w  EN_XF(a2),d4
                add.w   d3,d4
                move.w  d4,d0
                asr.w   #3,d0                   ; new x
                move.w  EN_YF(a2),d1
                asr.w   #3,d1
                tst.w   d3
                bmi.s   .l
                add.w   #EN_W,d0                ; front : just beside
                bra.s   .w
.l:             subq.w  #1,d0
.w:             addq.w  #3,d1                   ; wall : 3 heights
                bsr     solid_px
                bne.s   .blk
                addq.w  #8,d1
                bsr     solid_px
                bne.s   .blk
                addq.w  #EN_H-13,d1
                bsr     solid_px
                bne.s   .blk
                move.w  d4,d0                   ; floor under the front foot
                asr.w   #3,d0
                add.w   #EN_W-3,d0
                tst.w   d3
                bpl.s   .f
                sub.w   #EN_W-5,d0
.f:             addq.w  #2,d1                   ; (feet)
                move.w  plat_hit,-(sp)
                bsr     floor_px
                move.w  (sp)+,plat_hit
                tst.w   d2
                bne.s   .ok
                bsr     ladder_px
                bne.s   .blk
.ok:            move.w  d4,EN_XF(a2)
                addq.w  #1,EN_PH(a2)
                moveq   #0,d2
                rts
.blk:           moveq   #1,d2
                rts

; en_rick : d4 = x distance to Rick (Rick - enemy, middles),
;           d5 = y distance (Rick's feet - enemy's feet)
en_rick:        move.w  rick_xf,d4
                asr.w   #3,d4
                add.w   #RICK_W/2,d4
                move.w  EN_XF(a2),d0
                asr.w   #3,d0
                add.w   #EN_W/2,d0
                sub.w   d0,d4
                move.w  rick_yf,d5
                asr.w   #3,d5
                add.w   rk_h,d5
                bsr     en_pos
                sub.w   d1,d5
                rts

;---------------------------------------------------------------------
; BEHAVIOURS (a2 = enemy, a3 = its type)

; (a) patrol : left-right between walls / edges
en_patrol:
                cmp.w   #2,EN_ST(a2)            ; on a ladder : goes on
                beq     en_climb
                move.w  ET_SPD(a3),d3
                muls    EN_DIR(a2),d3
                bsr     en_walk
                tst.w   d2
                beq.s   .ok
                neg.w   EN_DIR(a2)
.ok:            bra     en_ground

; (a') bounded patrol : between its 2 limits (and walls / edges), never
;   falls, no ladders (enemy 2)
en_bounded:
                move.w  ET_SPD(a3),d3
                muls    EN_DIR(a2),d3
                move.w  EN_XF(a2),d0
                add.w   d3,d0
                cmp.w   EN_MN(a2),d0
                blt.s   .t
                cmp.w   EN_MX(a2),d0
                bgt.s   .t
                bsr     en_walk
                tst.w   d2
                beq.s   .x
.t:             neg.w   EN_DIR(a2)
.x:             rts

; (b) seek : patrol, walks towards Rick when he is on the same floor
en_seek:
                cmp.w   #2,EN_ST(a2)
                beq     en_climb
                bsr     en_rick
                bsr     en_same
                beq     en_patrol
                bra     en_chase

; en_same : d4 / d5 = distances -> Z = 0 if Rick in range, on the same floor
en_same:        move.w  d5,d0
                bpl.s   .a
                neg.w   d0
.a:             cmp.w   #6,d0
                bge.s   .no
                move.w  d4,d0
                bpl.s   .b
                neg.w   d0
.b:             cmp.w   ET_RX(a3),d0
                bge.s   .no
                moveq   #1,d0
                rts
.no:            moveq   #0,d0
                rts

; en_chase : walks towards Rick (d4 = x distance) ; blocked : waits
;   -> d2 = 1 if blocked
en_chase:       moveq   #0,d2
                move.w  d4,d0
                bpl.s   .a
                neg.w   d0
.a:             cmp.w   #3,d0                   ; just under / over him
                blt.s   .x
                moveq   #1,d0
                tst.w   d4
                bpl.s   .d
                moveq   #-1,d0
.d:             move.w  d0,EN_DIR(a2)
                move.w  ET_CSPD(a3),d3
                muls    d0,d3
                bsr     en_walk
.x:             move.w  d2,-(sp)
                bsr     en_ground
                move.w  (sp)+,d2
                rts

; (c) follow : seek + takes the ladders towards Rick's floor
en_follow:
                cmp.w   #2,EN_ST(a2)
                beq     en_climb
                tst.w   EN_TM(a2)               ; was stuck : patrols a while
                beq.s   .s
                subq.w  #1,EN_TM(a2)
                bra     en_patrol
.s:             bsr     en_rick
                bsr     en_same
                bne     en_chase
                move.w  d4,d0                   ; in range on another floor ?
                bpl.s   .a
                neg.w   d0
.a:             cmp.w   ET_RX(a3),d0
                bge     en_patrol
                move.w  d5,d0
                bpl.s   .b
                neg.w   d0
.b:             cmp.w   ET_RY(a3),d0
                bge     en_patrol
                moveq   #1,d0                   ; ladder towards him here ?
                tst.w   d5
                bpl.s   .c
                moveq   #-1,d0
.c:             movem.l d4-d5,-(sp)
                bsr     en_grab
                movem.l (sp)+,d4-d5
                tst.w   d2
                bne.s   .x
                bsr     en_findlad              ; no : ladder on this floor ?
                tst.w   d2                      ;  -> walks to it (d4)
                bne.s   .go
                bsr     en_rick                 ;  none : walks towards Rick
.go:            bsr     en_chase
                tst.w   d2
                beq.s   .x
                move.w  #EN_GIVEUP,EN_TM(a2)    ; stuck : patrols
                neg.w   EN_DIR(a2)
.x:             rts

; en_findlad : d6 = -1 up / 1 down -> d2 = 1 if a ladder going that way is
;   on this floor (nearest, up to ET_RX units on each side), d4 = x distance
en_findlad:
                movem.l d3/d5/d7,-(sp)
                bsr     en_pos
                add.w   #EN_W/2,d0
                move.w  d0,d5                   ; middle
                tst.w   d6
                bpl.s   .dn
                subq.w  #1,d1                   ; up : ladder at the feet
.dn:            move.w  d0,d3                   ; down : under the feet
                and.w   #-8,d3
                addq.w  #4,d3                   ; middle of the tile
                move.w  d3,d0                   ; same tile, same way as the
                swap    d0                      ;  last search : same result
                move.w  d1,d0                   ;  (the ladders do not change)
                tst.w   d6
                bpl.s   .k
                bset    #15,d0
.k:             cmp.l   EN_FK(a2),d0
                bne.s   .scan
                move.w  EN_FX(a2),d0
                bpl.s   .f
                bra.s   .none
.scan:          move.l  d0,EN_FK(a2)
                move.w  #-1,EN_FX(a2)
                moveq   #8,d7
.lp:            move.w  d3,d0
                sub.w   d7,d0
                bsr     ladder_px
                beq.s   .fd
                move.w  d3,d0
                add.w   d7,d0
                bsr     ladder_px
                beq.s   .fd
                addq.w  #8,d7
                cmp.w   ET_RX(a3),d7
                ble.s   .lp
.none:          moveq   #0,d2
                bra.s   .x
.fd:            move.w  d0,EN_FX(a2)
.f:             move.w  d0,d4
                sub.w   d5,d4
                moveq   #1,d2
.x:             movem.l (sp)+,d3/d5/d7
                rts

; en_grab : d0 = -1 up / 1 down -> d2 = 1 if a ladder is taken
en_grab:
                move.w  d0,d6
                bsr     en_pos
                add.w   #EN_W/2,d0              ; middle
                tst.w   d6
                bpl.s   .dn
                subq.w  #1,d1                   ; up : ladder at the feet
.dn:            bsr     ladder_px               ; down : ladder under the feet
                bne.s   .no
                move.w  d0,d3                   ; middle of the ladder
                and.w   #-8,d3                  ;  (1 or 2 tiles wide)
                move.w  d0,-(sp)
                move.w  d3,d0
                subq.w  #4,d0
                bsr     ladder_px
                bne.s   .r
                addq.l  #2,sp                   ; tile on the left too
                bra.s   .ok
.r:             move.w  d3,d0
                add.w   #12,d0
                bsr     ladder_px
                addq.l  #2,sp
                bne.s   .one
                addq.w  #8,d3                   ; tile on the right too
                bra.s   .ok
.one:           addq.w  #4,d3                   ; single tile (pole)
.ok:            move.w  d3,EN_LX(a2)
                move.w  d6,EN_CD(a2)
                move.w  #2,EN_ST(a2)
                moveq   #1,d2
                rts
.no:            moveq   #0,d2
                rts

; en_climb : on a ladder : first to its middle, then up / down ; leaves
;   it at its top / bottom, or on Rick's floor
en_climb:
                move.w  EN_XF(a2),d0
                asr.w   #3,d0
                add.w   #EN_W/2,d0
                cmp.w   EN_LX(a2),d0
                beq.s   .v
                blt.s   .r
                subq.w  #8,EN_XF(a2)            ; (1 unit per frame)
                rts
.r:             addq.w  #8,EN_XF(a2)
                rts
.v:             move.w  ET_LSPD(a3),d3
                muls    EN_CD(a2),d3
                add.w   d3,EN_YF(a2)
                addq.w  #1,EN_PH(a2)
                bsr     en_pos
                add.w   #EN_W/2,d0              ; d0 = middle, d1 = feet
                tst.w   EN_CD(a2)
                bpl.s   .down
                subq.w  #1,d1                   ; --- up : top passed ?
                bsr     ladder_px
                beq.s   .mid1
                and.w   #-8,d1                  ; feet on the top of the ladder
                addq.w  #8,d1
                bra.s   .walk
.mid1:          addq.w  #1,d1
                bra.s   .mid
.down:          bsr     ladder_px               ; --- down : bottom reached ?
                beq.s   .mid
                and.w   #-8,d1
                sub.w   #EN_W/2,d0
                bsr     en_support
                bne.s   .walk
                move.w  #3,EN_ST(a2)            ; ladder in the air : falls
                clr.w   EN_VY(a2)
                rts
.mid:           move.w  d1,d2                   ; on a floor of Rick's level ?
                and.w   #7,d2
                bne.s   .x
                move.w  rick_yf,d2
                asr.w   #3,d2
                add.w   rk_h,d2
                sub.w   d1,d2
                bpl.s   .p
                neg.w   d2
.p:             cmp.w   #4,d2
                bge.s   .x
                move.w  d0,-(sp)
                move.w  plat_hit,-(sp)
                sub.w   #12,d0                  ; floor beside the ladder ?
                bsr     floor_px
                bne.s   .fl
                add.w   #23,d0
                bsr     floor_px
.fl:            move.w  (sp)+,plat_hit
                move.w  (sp)+,d0
                tst.w   d2
                beq.s   .x
.walk:          sub.w   #EN_H,d1
                lsl.w   #3,d1
                move.w  d1,EN_YF(a2)
                move.w  #1,EN_ST(a2)
.x:             rts

;---------------------------------------------------------------------
; en_hits : Rick's laser / bomb kill the enemy ; contact kills Rick
en_hits:
                bsr     en_pos
                sub.w   #EN_H,d1                ; d0 = left, d1 = top
                add.w   ET_HT(a3),d1            ; (small enemy : lower top)
                tst.w   las_on                  ; --- laser
                beq.s   .nl
                move.w  las_y,d2
                cmp.w   d1,d2
                blt.s   .nl
                move.w  d1,d3
                add.w   #EN_H,d3
                cmp.w   d3,d2
                bge.s   .nl
                move.w  las_x,d2
                move.w  d0,d3
                add.w   #EN_W,d3
                cmp.w   d3,d2
                bge.s   .nl
                add.w   #LAS_LEN,d2
                cmp.w   d0,d2
                ble.s   .nl
                clr.w   las_on
                bra     en_kill
.nl:            cmp.w   #2,bomb_st              ; --- bomb explosion
                bne.s   .nb
                move.w  bomb_x,d2
                addq.w  #2,d2
                sub.w   d0,d2
                sub.w   #EN_W/2,d2
                bpl.s   .bx
                neg.w   d2
.bx:            cmp.w   #BOMB_KILL,d2
                bge.s   .nb
                move.w  bomb_y,d2
                addq.w  #3,d2
                sub.w   d1,d2
                sub.w   #EN_H/2,d2
                bpl.s   .by
                neg.w   d2
.by:            cmp.w   #BOMB_KILL,d2
                blt     en_kill
.nb:            bsr     en_traps                ; --- trap lasers (no points)
                bne     en_die
                tst.w   rick_dead               ; --- contact with Rick
                bne.s   .x
                tst.w   invul_t
                bne.s   .x
                move.w  rick_xf,d2
                asr.w   #3,d2
                move.w  d0,d3
                add.w   #EN_W-EN_HIT,d3
                cmp.w   d3,d2
                bge.s   .x
                add.w   #RICK_W,d2
                move.w  d0,d3
                addq.w  #EN_HIT,d3
                cmp.w   d3,d2
                ble.s   .x
                move.w  rick_yf,d2
                asr.w   #3,d2
                move.w  d1,d3
                add.w   #EN_H,d3
                cmp.w   d3,d2
                bge.s   .x
                add.w   rk_h,d2
                move.w  d1,d3
                addq.w  #EN_HIT,d3
                cmp.w   d3,d2
                ble.s   .x
                move.w  #1,rick_dead            ; Rick is caught
                move.w  #RESPAWN_T,dead_t
                lea     sfx_fall,a0
                bsr     sfx_play
.x:             rts

; en_kill : the enemy dies (blinks), points of its type
en_kill:        moveq   #0,d0
                move.w  ET_PTS(a3),d0
                add.l   d0,score
en_die:         move.w  #4,EN_ST(a2)            ; (trap : no points)
                move.w  #EN_DIE_T,EN_TM(a2)
                lea     sfx_zap,a0
                bra     sfx_play

; en_traps : a trap laser shot (PIEGES.S) in the enemy box d0,d1 ?
;   -> the shot explodes there, Z = 0 if hit
en_traps:
                movem.l d2-d4/d7/a0,-(sp)
                lea     lasers,a0
                move.w  nlz,d7
                bra.s   .nx
.lp:            tst.w   LZ_ON(a0)
                beq.s   .nt
                move.w  LZ_Y(a0),d2
                asr.w   #3,d2
                cmp.w   d1,d2
                blt.s   .nt
                move.w  d1,d3
                add.w   #EN_H,d3
                cmp.w   d3,d2
                bge.s   .nt
                move.w  LZ_X(a0),d3
                asr.w   #3,d3
                move.w  d0,d4                   ; (+/- 4 : 3 px per frame)
                subq.w  #4,d4
                cmp.w   d4,d3
                blt.s   .nt
                add.w   #EN_W+8,d4
                cmp.w   d4,d3
                bge.s   .nt
                clr.w   LZ_ON(a0)               ; explodes on the enemy
                move.w  LZ_PER(a0),LZ_T(a0)
                move.w  #10,LZ_EXP(a0)
                move.w  d3,LZ_EX(a0)
                subq.w  #2,d2
                move.w  d2,LZ_EY(a0)
                moveq   #1,d7
                bra.s   .x
.nt:            lea     LZ_SIZE(a0),a0
.nx:            dbra    d7,.lp
                moveq   #0,d7
.x:             tst.w   d7                      ; (Z : not hit)
                movem.l (sp)+,d2-d4/d7/a0
                rts

;---------------------------------------------------------------------
; draw_enemies : every frame (moving objects, same erase system as Rick)
draw_enemies:
                movem.l d0-d7/a0-a4,-(sp)
                bsr     bb_push                 ; (one rectangle per enemy)
                bsr     bb_reset
                move.w  nen,d7
                subq.w  #1,d7
                bmi.s   .x
                lea     enemies,a3
.lp:            move.w  EN_ST(a3),d0
                beq.s   .nx
                cmp.w   #4,d0                   ; dying : blinks
                bne.s   .d
                btst    #2,EN_TM+1(a3)
                bne.s   .nx
.d:             move.w  d7,-(sp)
                bsr     en_draw1
                move.w  (sp)+,d7
                bsr     bb_push
                bsr     bb_reset
.nx:            lea     EN_SIZE(a3),a3
                dbra    d7,.lp
.x:             movem.l (sp)+,d0-d7/a0-a4
                rts

; en_draw1 : a3 = enemy
en_draw1:
                move.w  EN_XF(a3),d6
                asr.w   #3,d6
                sub.w   win_ox,d6               ; world X of the left
                cmp.w   #-OX-EN_W,d6
                ble     .x
                cmp.w   #OX,d6
                bge     .x
                move.w  EN_YF(a3),d7
                asr.w   #3,d7
                sub.w   win_oy,d7               ; world Y of the top
                cmp.w   #-OY-EN_H,d7
                ble     .x
                cmp.w   #OY,d7
                bge     .x
                move.w  EN_TY(a3),d0
                mulu    #ET_SIZE,d0
                lea     en_types,a4
                adda.w  d0,a4
                ; --- animation (like Rick)
                move.w  EN_PH(a3),d0            ; walk : 4 steps
                lsr.w   #2,d0
                and.w   #3,d0
                add.w   d0,d0
                move.w  .swing(pc,d0.w),en_sl
                clr.w   en_lf
                clr.w   en_lb
                cmp.w   #2,d0
                bne.s   .a1
                move.w  #1,en_lf
.a1:            cmp.w   #6,d0
                bne.s   .a2
                move.w  #1,en_lb
.a2:            move.w  EN_PH(a3),d0            ; ladder : 2 beats
                lsr.w   #3,d0
                and.w   #1,d0
                add.w   d0,d0
                move.w  d0,en_la
                eor.w   #2,d0
                move.w  d0,en_lb2
                ; --- pose
                clr.w   en_mir
                move.l  ET_MCLB(a4),a2
                cmp.w   #2,EN_ST(a3)
                beq.s   .p
                move.l  ET_MSIDE(a4),a2
                tst.w   EN_DIR(a3)
                bpl.s   .p
                move.w  #1,en_mir
.p:             move.w  clip_y0,-(sp)           ; front edge of the floor /
                move.w  clip_y1,-(sp)           ;  ceiling hides it (like Rick)
                bsr     en_clip
                jsr     en_spr                  ; cached sprite (SPRITES.S, S key)
                beq     .end
.part:          move.w  (a2)+,d0
                cmp.w   #-99,d0
                beq     .end
                move.w  (a2)+,d1
                move.w  (a2)+,d2
                move.w  (a2)+,d3
                move.w  (a2)+,-(sp)             ; z0
                move.w  (a2)+,d5                ; z1
                move.w  (a2)+,d4                ; colour set
                lsl.w   #2,d4
                lea     setptr,a1
                move.l  (a1,d4.w),a1
                move.w  (a2)+,d4                ; animation (high byte)
                lsr.w   #8,d4
                btst    #0,d4                   ; front leg
                beq.s   .b0
                add.w   en_sl,d0
                add.w   en_sl,d2
                sub.w   en_lf,d3
.b0:            btst    #1,d4                   ; back leg
                beq.s   .b1
                sub.w   en_sl,d0
                sub.w   en_sl,d2
                sub.w   en_lb,d3
.b1:            btst    #2,d4                   ; front arm
                beq.s   .b2
                sub.w   en_sl,d0
                sub.w   en_sl,d2
.b2:            btst    #3,d4                   ; back arm
                beq.s   .b3
                add.w   en_sl,d0
                add.w   en_sl,d2
.b3:            btst    #4,d4                   ; ladder : limb A
                beq.s   .b4
                sub.w   en_la,d3
                btst    #6,d4
                beq.s   .b4
                sub.w   en_la,d1
.b4:            btst    #5,d4                   ; ladder : limb B
                beq.s   .b5
                sub.w   en_lb2,d3
                btst    #6,d4
                beq.s   .b5
                sub.w   en_lb2,d1
.b5:            tst.w   en_mir                  ; mirror : x -> EN_W - x
                beq.s   .b6
                exg     d0,d2
                neg.w   d0
                neg.w   d2
                add.w   #EN_W,d0
                add.w   #EN_W,d2
.b6:            move.w  (sp)+,d4                ; z0
                add.w   #ZMID,d4
                add.w   #ZMID,d5
                add.w   d6,d0
                add.w   d6,d2
                add.w   d7,d1
                add.w   d7,d3
                movem.l d6-d7/a2-a4,-(sp)
                bsr     draw_box
                movem.l (sp)+,d6-d7/a2-a4
                bra     .part
.end:           move.w  (sp)+,clip_y1
                move.w  (sp)+,clip_y0
.x:             rts
.swing:         dc.w    0,2,0,-2

; en_clip : like rick_clip (DESSRICK.S) for the enemy a3 : the front edge
;   of its floor / ceiling hides the feet / the head
en_clip:
                cmp.w   #2,EN_ST(a3)            ; (on a ladder : no)
                beq     .x
                move.w  EN_XF(a3),d0            ; middle column
                asr.w   #3,d0
                add.w   #EN_W/2,d0
                asr.w   #3,d0
                move.w  EN_YF(a3),d1            ; --- floor under the feet
                asr.w   #3,d1
                add.w   #EN_H,d1
                move.w  d1,d3
                and.w   #7,d3
                bne.s   .ceil
                move.w  d1,-(sp)
                asr.w   #3,d1
                bsr     tile_at
                move.w  (sp)+,d1
                bsr     lipz
                beq.s   .ceil
                sub.w   win_oy,d1
                bpl.s   .ceil
                muls    #FOC,d1
                divs    d3,d1
                add.w   #CY-1,d1
                cmp.w   clip_y1,d1
                bge.s   .ceil
                move.w  d1,clip_y1
.ceil:          move.w  EN_YF(a3),d1            ; --- ceiling above the head
                asr.w   #3,d1
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
                ble.s   .x
                muls    #FOC,d1
                divs    d3,d1
                add.w   #CY,d1
                cmp.w   clip_y0,d1
                ble.s   .x
                move.w  d1,clip_y0
.x:             rts
