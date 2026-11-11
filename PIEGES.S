;=====================================================================
; PIEGES.S - TRAPS : lasers, beams / arcs, canisters
;   (included by RICK3D.S ; the settings are in PARAMS.S)
;=====================================================================

;=====================================================================
; SAUCER LASERS (traps) : line of the .MAP
;     L col row dx dy start period
;   a laser line leaves from (col, row) when Rick is in this screen,
;   goes down by dy pixels per frame ; dx = 0 : it AIMS at Rick (like in
;   the original, hence the diagonal shots), else dx pixels per frame.
;   It explodes on a block and leaves again <period> frames later (1st
;   start : <start> frames). Deadly.
;=====================================================================
                rsreset
LZ_X0           rs.w    1
LZ_Y0           rs.w    1
LZ_DX           rs.w    1
LZ_DY           rs.w    1
LZ_PER          rs.w    1
LZ_T            rs.w    1
LZ_X            rs.w    1               ; position (1/8 unit)
LZ_Y            rs.w    1
LZ_ON           rs.w    1
LZ_VX           rs.w    1               ; speed (1/8 unit / frame)
LZ_VY           rs.w    1
LZ_EXP          rs.w    1               ; explosion on the floor (frames)
LZ_EX           rs.w    1
LZ_EY           rs.w    1
LZ_D0           rs.w    1               ; initial delay (staggered restart)
LZ_STR          rs.w    1               ; 1 = falls straight down (does not aim at Rick)
LZ_TC           rs.w    1               ; trigger : cell Rick must reach
LZ_TR           rs.w    1               ;  (column, row ; 0 = none)
LZ_ARM          rs.w    1               ; 1 : Rick reached it, the laser fires
LZ_TRP          rs.w    1               ; 1 : laser of a trap button (S 300+n) :
                                        ;  never fires on its own, one shot per press
LZ_SIZE         rs.b    0


; lz_reset : all the slots take their initial (staggered) delay again
lz_reset:
                lea     lasers,a2
                move.w  nlz,d7
                bra.s   .n
.l:             move.w  LZ_D0(a2),LZ_T(a2)
                clr.w   LZ_ON(a2)
                clr.w   LZ_ARM(a2)              ; (trigger : it must be reached again)
                clr.w   LZ_EXP(a2)
                lea     LZ_SIZE(a2),a2
.n:             dbra    d7,.l
                move.w  #LZ_GRACE,lz_cool
                rts

update_lasers:
                bsr     update_zaps
                tst.w   lz_cool
                beq.s   .nc
                subq.w  #1,lz_cool
.nc:            lea     lasers,a2
                move.w  nlz,d7
                bra     .nx
.lp:            tst.w   LZ_EXP(a2)              ; explosion going on
                beq.s   .ne
                subq.w  #1,LZ_EXP(a2)
.ne:            tst.w   LZ_ON(a2)
                bne     .move
                tst.w   LZ_TC(a2)               ; trigger : nothing as long as
                beq.s   .armd                   ;  Rick has not reached its
                tst.w   LZ_ARM(a2)              ;  cell (column, row like the
                bne.s   .armd                   ;  X / Y shown at the bottom)
                move.w  rick_xf,d0
                asr.w   #3,d0
                addq.w  #RICK_W/2,d0
                asr.w   #3,d0
                cmp.w   LZ_TC(a2),d0
                bne     .next
                move.w  rick_yf,d1
                asr.w   #3,d1
                add.w   rk_h,d1
                subq.w  #1,d1
                asr.w   #3,d1
                cmp.w   LZ_TR(a2),d1
                bne     .next
                move.w  #1,LZ_ARM(a2)
                move.w  LZ_D0(a2),LZ_T(a2)      ; delay of the 1st shot from here
.armd:          subq.w  #1,LZ_T(a2)             ; waits for its turn
                bgt     .next
                move.w  LZ_X0(a2),d0            ; only if the slot is
                sub.w   win_ox,d0               ; in Rick's screen
                move.w  LZ_Y0(a2),d1
                sub.w   win_oy,d1
                move.w  d0,d2
                move.w  d1,d3
                bsr     boxvis
                beq.s   .fire
                move.w  LZ_D0(a2),LZ_T(a2)      ; off the screen : initial delay,
                bra     .next                   ;  the shots stay staggered
.fire:          tst.w   rick_dead
                bne     .next
                cmp.w   #2,LZ_STR(a2)           ; mode 2 : falls straight down
                bne.s   .prox                   ;  when Rick walks under it
                move.w  rick_xf,d0
                asr.w   #3,d0
                addq.w  #RICK_W/2,d0
                sub.w   LZ_X0(a2),d0
                bpl.s   .pp
                neg.w   d0
.pp:            cmp.w   #LZ_PROX,d0
                ble.s   .prox
                move.w  #1,LZ_T(a2)             ; not yet : try again
                bra     .next
.prox:
                tst.w   lz_cool                 ; one shot at a time
                beq.s   .ok
                move.w  lz_cool,LZ_T(a2)
                addq.w  #1,LZ_T(a2)
                bra     .next
.ok:            move.w  #LZ_GAP,lz_cool
                move.w  #1,LZ_ON(a2)
                move.w  LZ_X0(a2),d0
                lsl.w   #3,d0
                move.w  d0,LZ_X(a2)
                move.w  LZ_Y0(a2),d0
                lsl.w   #3,d0
                move.w  d0,LZ_Y(a2)
                move.w  LZ_X0(a2),d0            ; emitter set IN the wall or
                move.w  LZ_Y0(a2),d1            ;  the ceiling : the shot leaves from
                addq.w  #4,d1                   ;  the edge of the tile
                bsr     solid_px
                beq.s   .free
                tst.w   LZ_DY(a2)
                bgt.s   .pdn
                move.w  LZ_DX(a2),d0
                beq.s   .free
                bmi.s   .pl
                add.w   #5*8,LZ_X(a2)
                bra.s   .free
.pl:            sub.w   #5*8,LZ_X(a2)
                bra.s   .free
.pdn:           add.w   #8*8,LZ_Y(a2)
.free:          move.w  LZ_DY(a2),d1            ; vertical speed
                bgt.s   .dy
                tst.w   LZ_DX(a2)               ; dy = 0 and dx : horizontal shot
                beq.s   .dy2                    ;  (emitter in a wall)
                clr.w   LZ_VY(a2)
                add.w   #4*8,LZ_Y(a2)           ; middle of the tile
                move.w  LZ_DX(a2),d0
                lsl.w   #3,d0
                move.w  d0,LZ_VX(a2)
                bra     .snd
.dy2:           moveq   #2,d1
.dy:            move.w  d1,d3
                lsl.w   #3,d1
                move.w  d1,LZ_VY(a2)
                move.w  LZ_DX(a2),d0
                bne.s   .fix
                tst.w   LZ_STR(a2)              ; dx 0 : aims at Rick... except in
                beq.s   .aim                    ;  "straight" mode
.fix:           lsl.w   #3,d0                   ; fixed direction
                move.w  d0,LZ_VX(a2)
                bra.s   .snd
.aim:           move.w  rick_yf,d1              ; aims at Rick's feet :
                asr.w   #3,d1                   ;   vx = dx * vy / dy
                add.w   rk_h,d1
                sub.w   LZ_Y0(a2),d1            ; height to travel
                ext.l   d1
                divs    d3,d1                   ; number of frames
                cmp.w   #1,d1
                bge.s   .n1
                moveq   #1,d1
.n1:            move.w  rick_xf,d0
                asr.w   #3,d0
                addq.w  #RICK_W/2,d0
                sub.w   LZ_X0(a2),d0            ; horizontal distance
                muls    #8,d0
                divs    d1,d0
                cmp.w   #24,d0                  ; 3 pixels / frame at most
                ble.s   .c1
                moveq   #24,d0
.c1:            cmp.w   #-24,d0
                bge.s   .c2
                moveq   #-24,d0
.c2:            move.w  d0,LZ_VX(a2)
.snd:           lea     sfx_zap,a0
                cmp.w   #2,cur_level            ; level 2 : snowball, blowpipe sound
                bne.s   .sp
                lea     sfx_blow,a0
.sp:            bsr     sfx_play
.move:          move.w  LZ_VX(a2),d0
                add.w   d0,LZ_X(a2)
                move.w  LZ_VY(a2),d0
                add.w   d0,LZ_Y(a2)
                move.w  LZ_X(a2),d0             ; hits a block ?
                asr.w   #3,d0
                move.w  LZ_Y(a2),d1
                asr.w   #3,d1
                bsr     solid_px
                beq.s   .hit
                clr.w   LZ_ON(a2)               ; explodes
                move.w  LZ_PER(a2),LZ_T(a2)
                move.w  #10,LZ_EXP(a2)
                move.w  d0,LZ_EX(a2)
                subq.w  #2,d1
                move.w  d1,LZ_EY(a2)
                bra     .next
.hit:           tst.w   rick_dead               ; hits Rick ?
                bne.s   .next
                tst.w   invul_t                 ; (invulnerable after respawn)
                bne.s   .next
                move.w  rick_xf,d2
                asr.w   #3,d2
                cmp.w   d2,d0
                blt.s   .next
                add.w   #RICK_W,d2
                cmp.w   d2,d0
                bge.s   .next
                move.w  rick_yf,d2
                asr.w   #3,d2
                cmp.w   d2,d1
                blt.s   .next
                add.w   rk_h,d2
                cmp.w   d2,d1
                bge.s   .next
                move.w  #1,rick_dead            ; Rick is hit
                move.w  #RESPAWN_T,dead_t
                lea     sfx_fall,a0
                bsr     sfx_play
.next:          lea     LZ_SIZE(a2),a2
.nx:            dbra    d7,.lp
                tst.w   invul_t
                beq.s   .ni
                subq.w  #1,invul_t
.ni:            tst.w   dead_t                  ; killed by a laser : wait
                beq.s   .x
                subq.w  #1,dead_t
                bne.s   .x
                bsr     lose_life
.x:             rts

; laser line : 3 small blocks along the diagonal (the tip + 2)
; update_zaps : Rick touches an active electric arc -> death
update_zaps:
                addq.w  #1,zp_ph
                lea     zaps,a2                 ; blinking beams
                move.w  nzp,d7
                bra.s   .pn
.pl:            cmp.w   #4,ZP_T(a2)             ; wave : goes back and forth between the balls
                beq.s   .pm
                tst.w   ZP_MV(a2)               ; back-and-forth beam : the same
                beq.s   .pw
.pm:            move.w  ZP_WQ(a2),d0            ; (position in 1/4 pixel)
                add.w   ZP_WV(a2),d0
                bpl.s   .w1
                moveq   #0,d0
                neg.w   ZP_WV(a2)
.w1:            move.w  ZP_W(a2),d1
                sub.w   ZP_WW(a2),d1
                lsl.w   #2,d1
                cmp.w   d1,d0
                ble.s   .w2
                move.w  d1,d0
                neg.w   ZP_WV(a2)
.w2:            move.w  d0,ZP_WQ(a2)
                asr.w   #2,d0
                move.w  d0,ZP_WP(a2)
.pw:            tst.w   ZP_PON(a2)
                beq.s   .pk
                subq.w  #1,ZP_TM(a2)
                bgt.s   .pk
                eor.w   #1,ZP_ACT(a2)
                move.w  ZP_PON(a2),ZP_TM(a2)
                tst.w   ZP_ACT(a2)
                bne.s   .pk
                move.w  ZP_POFF(a2),ZP_TM(a2)
.pk:            lea     ZP_SIZE(a2),a2
.pn:            dbra    d7,.pl
                tst.w   rick_dead
                bne     .x
                lea     zaps,a2
                move.w  nzp,d7
                bra     .nx
.lp:            tst.w   ZP_ON(a2)
                beq     .nt
                tst.w   ZP_ACT(a2)
                beq     .nt
                cmp.w   #5,ZP_T(a2)             ; scenery : harmless
                beq     .nt
                move.w  ZP_X(a2),d2             ; zone : d2 = x, d3 = width
                move.w  ZP_W(a2),d3
                cmp.w   #4,ZP_T(a2)             ; (wave : only where it is)
                beq.s   .zw
                tst.w   ZP_MV(a2)
                beq.s   .zr
.zw:            add.w   ZP_WP(a2),d2
                move.w  ZP_WW(a2),d3
.zr:            move.w  rick_xf,d0
                asr.w   #3,d0                   ; x0 Rick
                move.w  d2,d1
                add.w   d3,d1
                cmp.w   d1,d0                   ; x0 >= end of zone ?
                bge     .nt
                add.w   #RICK_W,d0
                cmp.w   d2,d0
                ble     .nt
                move.w  ZP_Y(a2),d2             ; height : d2 = top, d3 = bottom
                move.w  d2,d3
                add.w   ZP_H(a2),d3
                cmp.w   #4,ZP_T(a2)             ; wave : low band between the
                bne.s   .zy                     ;  balls -> pass under it CROUCHING
                add.w   #WAVE_Y0,d2             ;  (not standing)
                move.w  ZP_Y(a2),d3
                add.w   #WAVE_Y1,d3
.zy:            move.w  rick_yf,d0
                asr.w   #3,d0
                cmp.w   d3,d0
                bge     .nt
                add.w   rk_h,d0
                cmp.w   d2,d0
                ble     .nt
                tst.w   ZP_T(a2)
                beq.s   .kill
                cmp.w   #4,ZP_T(a2)
                beq.s   .kill
                clr.w   ZP_ON(a2)               ; canister : lasers (or bombs)
                bsr     can_erase               ; (only its box, no rebuild)
                cmp.w   #2,ZP_T(a2)             ;  to the max
                beq.s   .bmb
                cmp.w   #3,ZP_T(a2)             ; green : points only
                beq.s   .vie
                move.w  #AMMO_LAS_MAX,ammo_las
                bra.s   .snd2
.vie:           add.l   #PTS_GREEN,score        ; 500 points, no life (original)
                bra.s   .snd2
.bmb:           move.w  #AMMO_BOMB_MAX,ammo_bomb
.snd2:
                lea     sfx_jump,a0
                bsr     sfx_play
                bra.s   .nt
.kill:          tst.w   invul_t                 ; (invulnerable)
                bne     .nt
                move.w  #1,rick_dead            ; touches the beam
                move.w  #RESPAWN_T,dead_t
                lea     sfx_zap,a0
                bsr     sfx_play
                bra.s   .x
.nt:            lea     ZP_SIZE(a2),a2
.nx:            dbra    d7,.lp
.x:             rts

; draw_zaps : fixed laser beams (crackling) and energy canisters
; draw_nozzles : the laser emitters, drawn in the fixed scenery
;   (small grey nozzle + orange tip, at mid-depth like the shots),
;   stuck under the ceiling (vertical / diagonal shot) or against the wall
;   (horizontal shot), in the notch where the emitter is set
draw_nozzles:
                lea     lasers,a2
                move.w  nlz,d7
                bra     .nn
.nl:            move.w  LZ_X0(a2),d0            ; centre of the tile
                move.w  LZ_Y0(a2),d1
                addq.w  #4,d1
                tst.w   LZ_DY(a2)
                bgt.s   .vert
                tst.w   LZ_DX(a2)
                beq     .nk
                bmi.s   .hl
                ; --- shot to the right : wall on the left
                moveq   #5,d6
.r1:            bsr     solid_px
                bne.s   .r2
                subq.w  #8,d0
                dbra    d6,.r1
                bra     .nk
.r2:            asr.w   #3,d0                   ; right edge of the wall
                addq.w  #1,d0
                lsl.w   #3,d0
                move.w  d0,d2
                addq.w  #5,d2
                moveq   #1,d5                   ; tip on the right
                bra.s   .hz
                ; --- shot to the left : wall on the right
.hl:            moveq   #5,d6
.l1:            bsr     solid_px
                bne.s   .l2
                addq.w  #8,d0
                dbra    d6,.l1
                bra     .nk
.l2:            asr.w   #3,d0                   ; left edge of the wall
                lsl.w   #3,d0
                move.w  d0,d2
                subq.w  #5,d0
                moveq   #-1,d5
.hz:            move.w  d1,d3
                subq.w  #2,d1
                addq.w  #2,d3
                bra.s   .dr
                ; --- shot downwards : ceiling above
.vert:          moveq   #5,d6
.v1:            bsr     solid_px
                bne.s   .v2
                subq.w  #8,d1
                dbra    d6,.v1
                bra.s   .nk
.v2:            asr.w   #3,d1                   ; bottom of the ceiling
                addq.w  #1,d1
                lsl.w   #3,d1
                move.w  d1,d3
                addq.w  #5,d3
                move.w  d0,d2
                subq.w  #2,d0
                addq.w  #2,d2
                moveq   #0,d5
.dr:            sub.w   win_ox,d0               ; -> screen coordinates
                sub.w   win_ox,d2
                sub.w   win_oy,d1
                sub.w   win_oy,d3
                move.w  d5,-(sp)
                bsr     boxvis
                bne.s   .nv
                movem.l d6-d7/a2,-(sp)          ; nozzle model (downwards)
                move.w  d0,d6                   ;  origin : bottom of the ceiling, in the middle
                addq.w  #2,d6
                move.w  d1,d7
                moveq   #0,d5
                move.w  12(sp),d4               ; (direction of the shot)
                beq.s   .md
                move.w  d0,d6                   ; to the right : edge of the wall
                move.w  d1,d7
                addq.w  #2,d7
                moveq   #2,d5                   ;  (turned model)
                tst.w   d4
                bpl.s   .md
                move.w  d2,d6                   ; to the left : turned + mirror
                moveq   #3,d5
.md:            lea     mdl_nozzle,a2
                bsr     draw_model
                movem.l (sp)+,d6-d7/a2
.nv:            addq.l  #2,sp
.nk:            lea     LZ_SIZE(a2),a2
.nn:            dbra    d7,.nl
                rts

;---------------------------------------------------------------------
; draw_zapemit : the emitters of the horizontal electric arcs (Z wider
;   than high) : one at each end, in the fixed scenery, even when cut
draw_zapemit:
                lea     zaps,a2
                move.w  nzp,d7
                bra.s   .n
.l:             tst.w   ZP_T(a2)                ; beam (not canister nor wave)
                bne.s   .k
                move.w  ZP_W(a2),d0
                cmp.w   ZP_H(a2),d0
                ble.s   .k
                movem.l d7/a2,-(sp)
                move.w  ZP_Y(a2),d7             ; bottom row of the zone
                add.w   ZP_H(a2),d7
                subq.w  #8,d7
                sub.w   win_oy,d7
                move.w  ZP_X(a2),d6             ; on the left, turned to the right
                subq.w  #8,d6
                sub.w   win_ox,d6
                move.w  ZP_X(a2),d4
                add.w   ZP_W(a2),d4
                add.w   #8,d4
                sub.w   win_ox,d4               ; (right end, flipped)
                lea     mdl_zapemit,a2
                moveq   #0,d5
                bsr     draw_model
                move.w  d4,d6
                moveq   #1,d5
                bsr     draw_model
                movem.l (sp)+,d7/a2
.k:             lea     ZP_SIZE(a2),a2
.n:             dbra    d7,.l
                rts

draw_items:                                     ; canisters : in the fixed scenery
                movem.l d0-d5/a0-a2,-(sp)
                jsr     bg_ptrs
                lea     bgbuf,a0                ; scenery without them (pickup)
                move.l  bg_noitp,a1
                move.w  #SCRSZ/16-1,d0
.cp:            move.l  (a0)+,(a1)+
                move.l  (a0)+,(a1)+
                move.l  (a0)+,(a1)+
                move.l  (a0)+,(a1)+
                dbra    d0,.cp
                bra.s   draw_items_go
; draw_items_nc : the same, bg_noitp is already the scenery without them
;   (background build, BGBUILD.S)
draw_items_nc:
                movem.l d0-d5/a0-a2,-(sp)
draw_items_go:
                lea     zaps,a0                 ; no box recorded yet
                move.w  nzp,d0
                bra.s   .cn
.cz:            clr.l   ZP_BP(a0)
                lea     ZP_SIZE(a0),a0
.cn:            dbra    d0,.cz
                move.w  #1,can_rec
                move.w  #1,zp_mode
                bsr     draw_zaps
                clr.w   zp_mode
                clr.w   can_rec
                move.l  #can_pool,a1            ; boxes drawn (canister + its
                lea     zaps,a2                 ;  bar) : pixels kept
                move.w  nzp,d5
                bra     .pn
.pl:            cmp.l   #2,ZP_BP(a2)
                bne     .pk
                movem.w ZP_BX0(a2),d0-d3
                sub.w   d0,d2                   ; d2 = width - 1
                sub.w   d1,d3                   ; d3 = height - 1
                move.w  d2,d4
                addq.w  #1,d4
                mulu    d3,d4
                add.w   d2,d4
                addq.l  #1,d4
                add.l   d4,d4
                add.l   a1,d4
                cmp.l   #can_pool+2*CANPOOL_W,d4
                bls.s   .ok
                clr.l   ZP_BP(a2)               ; pool full : rebuild at pickup
                bra.s   .pk
.ok:            move.l  a1,ZP_BP(a2)
                mulu    #LINEB,d1
                add.w   d0,d0
                ext.l   d0
                add.l   d0,d1
                lea     bgbuf,a0
                add.l   d1,a0
.ly:            move.w  d2,d0
                move.l  a0,d1
.lx:            move.w  (a0)+,(a1)+
                dbra    d0,.lx
                move.l  d1,a0
                lea     LINEB(a0),a0
                dbra    d3,.ly
.pk:            lea     ZP_SIZE(a2),a2
.pn:            dbra    d5,.pl
                movem.l (sp)+,d0-d5/a0-a2
                rts

; zigzag : electric line (beams and waves have the same shape) from
;   d0 to d2 (screen x), in the band d1 .. d1+6 : lines of 4 pixels
;   going up and down (0 2 4 2), the oscillation moves every ZZ_SLOW frames
ZZ_SLOW         equ     4
zigzag:
                tst.w   view_back               ; side view : zz_fast (ZIGZAG.S)
                beq     zz_fast
zz_old:
                movem.l d0-d7,-(sp)
                move.w  d2,d7                   ; d7 = end
                move.w  d1,d6                   ; d6 = top of the band
                moveq   #0,d5                   ; d5 = index
                moveq   #0,d3
                move.w  zp_ph,d3
                divu    #ZZ_SLOW,d3             ; d3 = slow phase
.l:             cmp.w   d7,d0
                bge.s   .x
                movem.w d0/d3/d5-d7,-(sp)
                move.w  d5,d4
                add.w   d3,d4
                and.w   #3,d4                   ; height 0 2 4 2 (triangle)
                cmp.w   #3,d4
                bne.s   .h
                moveq   #1,d4
.h:             add.w   d4,d4
                move.w  d6,d1
                add.w   d4,d1
                move.w  d0,d2
                addq.w  #4,d2
                cmp.w   d7,d2
                ble.s   .c
                move.w  d7,d2
.c:             move.w  d1,d3
                addq.w  #2,d3
                move.w  #ZMID-1,d4
                move.w  #ZMID+1,d5
                                                ; (flat line at the middle plane : fast)
                bsr     zap_rect
                movem.w (sp)+,d0/d3/d5-d7
                addq.w  #4,d0
                addq.w  #1,d5
                bra.s   .l
.x:             movem.l (sp)+,d0-d7
                rts

draw_zaps:                                      ; beams : every frame
                lea     zaps,a2
                move.w  nzp,d7
                bra     .nx
.lp:            tst.w   ZP_ON(a2)
                beq     .next
                tst.w   ZP_ACT(a2)
                beq     .next
                cmp.w   #4,ZP_T(a2)             ; wave : balls (fixed) + wave (animated)
                beq     .wave
                tst.w   ZP_T(a2)                ; (canister : only in mode 1,
                sne     d0                      ;  beam : only in mode 0)
                ext.w   d0
                neg.w   d0
                cmp.w   zp_mode,d0
                bne     .next
                move.w  ZP_X(a2),d0
                sub.w   win_ox,d0
                move.w  d0,d2
                add.w   ZP_W(a2),d2
                tst.w   ZP_MV(a2)               ; back-and-forth : the piece of beam
                beq.s   .nmv
                add.w   ZP_WP(a2),d0
                move.w  d0,d2
                add.w   ZP_WW(a2),d2
.nmv:           move.w  ZP_Y(a2),d1
                sub.w   win_oy,d1
                move.w  d1,d3
                add.w   ZP_H(a2),d3
                bsr     boxvis
                bne     .next
                tst.w   ZP_T(a2)
                bne     .can
                cmp.w   #8,ZP_W(a2)             ; 1 tile wide and taller :
                bne.s   .hz                     ;  continuous vertical shot falling
                cmp.w   #8,ZP_H(a2)             ;  from the ceiling (lines going down)
                ble.s   .hz
                addq.w  #2,d0                   ; axis : 4 wide in the middle
                move.w  d0,d2
                addq.w  #4,d2
                move.w  ZP_H(a2),d6
                lsr.w   #3,d6                   ; a line of 5 every 8
                subq.w  #1,d6
                move.w  zp_ph,d5
                add.w   d5,d5
                and.w   #7,d5                   ; offset 0..7 (going down)
.vt:            movem.w d0-d3/d5-d6,-(sp)
                add.w   d5,d1
                move.w  d1,d3
                addq.w  #5,d3
                move.w  ZP_Y(a2),d4             ; (not below the zone)
                add.w   ZP_H(a2),d4
                sub.w   win_oy,d4
                cmp.w   d4,d3
                ble.s   .vt1
                move.w  d4,d3
.vt1:           move.w  #ZMID-1,d4
                move.w  #ZMID+1,d5
                                                ; (flat line at the middle plane : fast)
                bsr     zap_rect
                movem.w (sp)+,d0-d3/d5-d6
                addq.w  #8,d1
                dbra    d6,.vt
                bra     .push
.hz:            add.w   d3,d1                   ; beam : same zigzag as the
                asr.w   #1,d1                   ;  wave, in the middle of its zone
                subq.w  #3,d1
                bsr     zigzag
                bra     .push
.wave:          tst.w   zp_mode
                bne     .balls
                move.w  ZP_X(a2),d0             ; --- the wave (every frame)
                add.w   ZP_WP(a2),d0
                sub.w   win_ox,d0
                move.w  d0,d2
                add.w   ZP_WW(a2),d2
                move.w  ZP_Y(a2),d1
                sub.w   win_oy,d1
                move.w  d1,d3
                add.w   #16,d3
                bsr     boxvis
                bne     .next
                add.w   #WAVE_Y0,d1
                bsr     zigzag
                bra     .push
.balls:         move.w  ZP_X(a2),d0             ; --- balls + rods (fixed scenery)
                sub.w   #16,d0                  ; left ball
                bsr.s   .ball
                move.w  ZP_X(a2),d0
                add.w   ZP_W(a2),d0             ; right ball
                bsr.s   .ball
                bra     .next
                ; ball 2 x 2 tiles at d0 (level x) / ZP_Y, and its rod
.ball:          movem.l d0-d7/a1,-(sp)
                move.w  d0,d6
                move.w  ZP_Y(a2),d7
                move.w  d6,d0                   ; rod : from the top of the ball
                addq.w  #7,d0                   ;  up to the ceiling
                asr.w   #3,d0
                move.w  d7,d1
                asr.w   #3,d1
                moveq   #0,d5                   ; d5 = number of tiles
.rod:           subq.w  #1,d1
                bmi.s   .rodx
                bsr     tile_at
                bsr     issol
                beq.s   .rodx
                cmp.b   #'=',d2
                beq.s   .rodx
                addq.w  #1,d5
                cmp.w   #16,d5
                blt.s   .rod
.rodx:          tst.w   d5
                beq.s   .rod0
                move.w  d6,d0
                sub.w   win_ox,d0
                addq.w  #6,d0
                move.w  d0,d2
                addq.w  #4,d2
                move.w  d7,d3
                sub.w   win_oy,d3
                lsl.w   #3,d5
                move.w  d3,d1
                sub.w   d5,d1
                move.w  #ZMID-2,d4
                move.w  #ZMID+2,d5
                lea     col_plat,a1             ; copper rod
                bsr     draw_box
.rod0:          sub.w   win_ox,d6               ; ball : model (TILES.DAT)
                sub.w   win_oy,d7
                moveq   #0,d5
                move.l  a2,-(sp)
                lea     mdl_ball,a2
                bsr     draw_model
                move.l  (sp)+,a2
                movem.l (sp)+,d0-d7/a1
                rts
.can:           cmp.w   #5,ZP_T(a2)
                beq     .deco
                movem.l d6-d7/a2,-(sp)          ; canister : model (TILES.DAT)
                move.l  a2,can_cur
                move.w  d0,d6
                move.w  d1,d7
                moveq   #0,d5
                move.w  ZP_T(a2),d4
                lea     mdl_canE,a2
                cmp.w   #2,d4
                bne.s   .cg
                lea     mdl_canD,a2             ; bombs
.cg:            cmp.w   #3,d4
                bne.s   .cd
                lea     mdl_canG,a2             ; green
.cd:            bsr     can_model
                movem.l (sp)+,d6-d7/a2
.deco:          movem.l d0-d7,-(sp)             ; electric scenery bar :
                move.w  d0,d6                   ;  grey ends + blue segments
                move.w  d2,d7                   ; d6 = x0, d7 = x1
                move.w  d1,d5                   ; d5 = top of the bottom tile
                add.w   ZP_H(a2),d5
                sub.w   #8,d5
                move.w  d6,d0                   ; left end
                move.w  d0,d2
                addq.w  #4,d2
                move.w  d5,d1
                addq.w  #1,d1
                move.w  d5,d3
                addq.w  #7,d3
                movem.w d4-d7,-(sp)
                move.w  #ZMID-3,d4
                move.w  #ZMID+3,d5
                lea     col_nozzle,a1
                bsr     draw_box
                movem.w (sp),d4-d7
                move.w  d7,d2                   ; right end
                move.w  d2,d0
                subq.w  #4,d0
                move.w  #ZMID-3,d4
                move.w  #ZMID+3,d5
                bsr     draw_box
                movem.w (sp)+,d4-d7
                addq.w  #4,d6                   ; blue segments (3 + 1 gap)
                subq.w  #4,d7
.dg:            cmp.w   d7,d6
                bge.s   .dgx
                move.w  d6,d0
                move.w  d0,d2
                addq.w  #3,d2
                cmp.w   d7,d2
                ble.s   .dg1
                move.w  d7,d2
.dg1:           move.w  d5,d1
                addq.w  #2,d1
                move.w  d5,d3
                addq.w  #6,d3
                movem.w d5-d7,-(sp)
                move.w  #ZMID-2,d4
                move.w  #ZMID+2,d5
                lea     col_zap,a1
                bsr     draw_box
                movem.w (sp)+,d5-d7
                addq.w  #4,d6
                bra.s   .dg
.dgx:           movem.l (sp)+,d0-d7
                bra     .push
.push:          tst.w   zp_mode
                bne.s   .next
                bsr     bb_push
.next:          lea     ZP_SIZE(a2),a2
.nx:            dbra    d7,.lp
                rts

draw_lasers:
                lea     lasers,a2
                move.w  nlz,d7
                bra     .nx
.lp:            tst.w   LZ_ON(a2)
                beq     .exp
                cmp.w   #2,cur_level            ; level 2 : white snowball
                bne.s   .line
                move.w  LZ_X(a2),d0
                asr.w   #3,d0
                sub.w   win_ox,d0
                move.w  LZ_Y(a2),d1
                asr.w   #3,d1
                sub.w   win_oy,d1
                move.w  d0,d2
                move.w  d1,d3
                subq.w  #2,d0
                subq.w  #2,d1
                addq.w  #2,d2
                addq.w  #2,d3
                bsr     boxvis
                bne     .exp
                move.w  LZ_X(a2),d0
                asr.w   #3,d0
                sub.w   win_ox,d0
                move.w  LZ_Y(a2),d1
                asr.w   #3,d1
                sub.w   win_oy,d1
                move.w  d0,d2
                move.w  d1,d3
                subq.w  #2,d0
                subq.w  #2,d1
                addq.w  #2,d2
                addq.w  #2,d3
                move.w  #ZMID-2,d4
                move.w  #ZMID+2,d5
                lea     col_spark2,a1
                bsr     draw_box
                bsr     bb_push
                bra     .exp
.line:          moveq   #2,d6
                move.w  LZ_X(a2),d4
                move.w  LZ_Y(a2),d5
.seg:           move.w  d4,d0
                asr.w   #3,d0
                sub.w   win_ox,d0
                subq.w  #1,d0
                move.w  d0,d2
                addq.w  #2,d2
                move.w  d5,d1
                asr.w   #3,d1
                sub.w   win_oy,d1
                subq.w  #3,d1
                move.w  d1,d3
                addq.w  #3,d3
                movem.w d4-d5,-(sp)
                bsr     boxvis
                bne.s   .nv
                move.w  #ZMID-1,d4
                move.w  #ZMID+1,d5
                                                ; (flat line at the middle plane : fast)
                bsr     zap_rect
.nv:            movem.w (sp)+,d4-d5
                move.w  LZ_VX(a2),d0            ; previous segment (2 frames)
                add.w   d0,d0
                sub.w   d0,d4
                move.w  LZ_VY(a2),d0
                add.w   d0,d0
                sub.w   d0,d5
                dbra    d6,.seg
                bsr     bb_push
.exp:           move.w  LZ_EXP(a2),d6           ; explosion on the floor
                beq.s   .next
                moveq   #12,d5
                sub.w   d6,d5
                asr.w   #1,d5                   ; radius 1..6
                addq.w  #1,d5
                move.w  LZ_EX(a2),d0
                sub.w   win_ox,d0
                move.w  LZ_EY(a2),d1
                sub.w   win_oy,d1
                move.w  d0,d2
                move.w  d1,d3
                sub.w   d5,d0
                sub.w   d5,d1
                add.w   d5,d2
                add.w   d5,d3
                bsr     boxvis
                bne.s   .next
                move.w  #ZMID,d4
                sub.w   d5,d4
                add.w   #ZMID,d5
                lea     col_fire,a1
                btst    #1,d6
                beq.s   .ec
                lea     col_fire+8,a1
.ec:            cmp.w   #2,cur_level            ; level 2 : the snowball bursts white
                bne.s   .ed
                lea     col_spark2,a1
.ed:            bsr     draw_box
                bsr     bb_push
.next:          lea     LZ_SIZE(a2),a2
.nx:            dbra    d7,.lp
                rts

; zap_rect : flat rectangle d0,d1 - d2,d3 (centred world coord.) projected on
;   the middle plane and filled at once (laser lines, waves : much
;   faster than a 3D box) ; registers preserved
; ZPROJ reg,centre : reg = centre + reg x FOC / ZMID (table zp_ptab, a0
;   -> its middle) ; out of the table -> .slow
ZPROJ           macro
                cmp.w   #-512,\1
                blt.s   .slow
                cmp.w   #511,\1
                bgt.s   .slow
                add.w   \1,\1
                move.w  (a0,\1.w),\1
                add.w   #\2,\1
                endm

; zp_mktab : zp_ptab[v] = v x FOC / ZMID (like divs), v = -512..511
zp_mktab:
                movem.l d0-d1/a0,-(sp)
                lea     zp_ptab,a0
                move.w  #-512,d1
.l:             move.w  d1,d0
                muls    #FOC,d0
                divs    #ZMID,d0
                move.w  d0,(a0)+
                addq.w  #1,d1
                cmp.w   #512,d1
                blt.s   .l
                move.w  #1,zp_tok
                movem.l (sp)+,d0-d1/a0
                rts

zap_rect:
                tst.w   view_back               ; back view : a thin box
                beq.s   .side
                movem.l d4-d5/a1,-(sp)
                lea     bv_zcol,a1
                move.w  col_zap,(a1)
                move.w  col_zap,2(a1)
                move.w  col_zap,4(a1)
                move.w  col_zap,6(a1)
                move.w  #ZMID-1,d4
                move.w  #ZMID+1,d5
                bsr     draw_box
                movem.l (sp)+,d4-d5/a1
                rts
.side:          movem.l d0-d3/d7,-(sp)
                tst.w   zp_tok                  ; projection at ZMID : table
                bne.s   .tk                     ;  (4 divs per rectangle before)
                bsr     zp_mktab
.tk:            move.l  a0,-(sp)
                lea     zp_ptab+1024,a0         ; (index 0 in the middle)
                ZPROJ   d0,CX
                ZPROJ   d2,CX
                ZPROJ   d1,CY
                ZPROJ   d3,CY
                move.l  (sp)+,a0
                bra.s   .pj
.slow:          move.l  (sp)+,a0                ; (out of the table)
                movem.l (sp),d0-d3
                muls    #FOC,d0
                divs    #ZMID,d0
                add.w   #CX,d0
                muls    #FOC,d2
                divs    #ZMID,d2
                add.w   #CX,d2
                muls    #FOC,d1
                divs    #ZMID,d1
                add.w   #CY,d1
                muls    #FOC,d3
                divs    #ZMID,d3
                add.w   #CY,d3
.pj:            subq.w  #1,d2                   ; (bounds included)
                subq.w  #1,d3
                cmp.w   d0,d2
                bge.s   .w
                move.w  d0,d2
.w:             cmp.w   d1,d3
                bge.s   .h
                move.w  d1,d3
.h:             move.w  col_zap,d7
                bsr     rect_bb
                movem.l (sp)+,d0-d3/d7
                rts

