;=====================================================================
; DSP3D.S - 3D MATHS BY THE DSP (program R3D.P56, source OUTILS\R3D.A56)
;   (included by RICK3D.S ; same principle as CUBEDSP / CUBE3D)
;
;   R3D.P56 is loaded with Simplet's replay (a single Dsp_ExecProg) ;
;   for each box (draw_box) the DSP projects the 8 corners, picks the
;   faces, follows the edges and sends back, line by line, the start and
;   the length to fill. The 030 only fills.
;   Golden rule : we talk to the DSP only when the music is not talking to it
;   (MGTK_Replay_In_Service = 0, interrupts masked), and each
;   command ends with an answer from the DSP.
;   If the DSP does not answer : d3don = 0 and everything is done by the 030.
;=====================================================================

D3D_TMO         equ     200000                  ; max wait for the DSP (loops)

; D3PUT : sends a word to the DSP (a4 = $ffffa202, a5 = $ffffa204)
D3PUT           macro
.p\@:           btst    #1,(a4)
                beq.s   .p\@
                move.l  \1,(a5)
                endm
; D3GET : reads a word from the DSP (d3 = max wait ; too long : .ko)
D3GET           macro
                move.l  d3,d1
.g\@:           btst    #0,(a4)
                bne.s   .h\@
                subq.l  #1,d1
                bne.s   .g\@
                bra     .ko
.h\@:           move.l  (a5),\1
                endm
D3D_MAXW        equ     1100                    ; words read for a box (max)

;---------------------------------------------------------------------
; d3dinit : replaces MGTK_Init_DSP (same job) : Simplet's DSP
;   program (AMIGADSP.P56, unchanged) followed by R3D.P56, sent together
;   by Dsp_ExecProg, then the same connection test.
;   d0 = 0 : ok ; -1 : no DSP
d3dinit:
                movem.l d1-d7/a0-a6,-(sp)
                lea     MGTK_DSP_Replay_Code,a0 ; Simplet first
                lea     d3dcomb,a1
                move.l  #MGTK_DSP_Replay_Size*3,d0
                subq.l  #1,d0
.c1:            move.b  (a0)+,(a1)+
                subq.l  #1,d0
                bpl.s   .c1
                lea     d3dcode,a0              ; then R3D
                move.l  #d3dcend-d3dcode,d0
                subq.l  #1,d0
.c2:            move.b  (a0)+,(a1)+
                subq.l  #1,d0
                bpl.s   .c2
                move.w  #113,-(sp)              ; Dsp_RequestUniqueAbility
                trap    #14
                addq.l  #2,sp
                move.w  d0,-(sp)
                move.l  #MGTK_DSP_Replay_Size+(d3dcend-d3dcode)/3,-(sp)
                pea     d3dcomb
                move.w  #109,-(sp)              ; Dsp_ExecProg
                trap    #14
                lea     12(sp),sp
                move.l  #87654321,$ffffa204.w   ; connection test (Simplet)
                move.l  #100000,d1
.w:             btst    #0,$ffffa202.w
                bne.s   .g
                subq.l  #1,d1
                bne.s   .w
                moveq   #-1,d0
                bra.s   .out
.g:             move.l  $ffffa204.w,d0
                moveq   #0,d0
.out:           movem.l (sp)+,d1-d7/a0-a6
                rts

;---------------------------------------------------------------------
; d3dload : does R3D (loaded by d3dinit) answer ? -> dsp3d = d3don = 1
d3dload:
                movem.l d0-d7/a0-a6,-(sp)
                clr.w   dsp3d
                clr.w   d3don
                tst.w   dspok
                beq.s   .out
                bsr     d3dbegin
                move.l  #$040000,d0             ; PING
                bsr     d3dput
                bmi.s   .ko
                bsr     d3dget
                bmi.s   .ko
                cmp.l   #$5a5a5a,d0
                bne.s   .ko
                bsr     d3dend
                move.w  #1,dsp3d
                move.w  #1,d3don                ; the DSP does the 3D
                bra.s   .out
.ko:            bsr     d3dend
.out:           movem.l (sp)+,d0-d7/a0-a6
                rts

;---------------------------------------------------------------------
; d3dbegin / d3dend : start / end of an exchange with R3D
;   waits until the music has finished talking to the DSP, then masks the
;   interrupts (Timer A of the music included)
d3dbegin:
                move.w  sr,d3dsr
.w:             move.w  #$2700,sr
                tst.b   MGTK_Replay_In_Service
                beq.s   .ok
                move.w  d3dsr,sr                ; the music is talking : wait
                bra.s   .w
.ok:            rts

d3dend:
                move.w  d3dsr,sr
                rts

; d3dput : sends d0 (24 bits) ; N = 1 if the DSP does not answer
d3dput:
                move.l  d1,-(sp)
                move.l  #D3D_TMO,d1
.w:             btst    #1,$ffffa202.w
                bne.s   .ok
                subq.l  #1,d1
                bne.s   .w
                bra.s   d3dfail
.ok:            move.l  d0,$ffffa204.w
                move.l  (sp)+,d1
                tst.w   d3dzero                 ; N = 0
                rts

; d3dget : reads a word from the DSP into d0 ; N = 1 if nothing comes
d3dget:
                move.l  d1,-(sp)
                move.l  #D3D_TMO,d1
.w:             btst    #0,$ffffa202.w
                bne.s   .ok
                subq.l  #1,d1
                bne.s   .w
                bra.s   d3dfail
.ok:            move.l  $ffffa204.w,d0
                and.l   #$ffffff,d0
                move.l  (sp)+,d1
                tst.w   d3dzero                 ; N = 0
                rts

d3dfail:        move.l  (sp)+,d1                ; the DSP no longer answers : 030
                clr.w   dsp3d
                clr.w   d3don
                moveq   #-1,d0
                rts

;---------------------------------------------------------------------
; d3dbox : box d0=X0 d1=Y0 d2=X1 d3=Y1 d4=Z0 d5=Z1, a1 -> colours,
;   a6 = screen. The side faces are filled here ; the front face is
;   returned projected : d7 = 1, d0-d3 = rectangle (draw_box fills it).
;   d7 = 0 : nothing else to do ; d7 = -1 : the DSP does not answer
;   (d0-d5 intact : draw_box does everything on the 030).
;   d4, d5, d6, a1 kept.
d3dbox:
                movem.l d0-d6/a0-a5,-(sp)
                move.w  box_mask,d7             ; allowed faces
                and.l   #15,d7
                tst.w   view_back
                beq.s   .f1
                tst.w   bv_nofront              ; back view : hidden face
                bne.s   .f0
                tst.w   bv_nf2
                bne.s   .f0
.f1:            bset    #4,d7                   ; front face
.f0:            or.l    #$060000,d7             ; BOX command
                lea     $ffffa202.w,a4
                lea     $ffffa204.w,a5
                bsr     d3dbegin
                move.l  d7,d0
                bsr     d3dput                  ; (1st word : does the DSP answer ?)
                bmi     .ko
                movem.l (sp),d0-d5              ; coordinates
                ext.l   d0
                D3PUT   d0
                ext.l   d1
                D3PUT   d1
                ext.l   d2
                D3PUT   d2
                ext.l   d3
                D3PUT   d3
                ext.l   d4
                D3PUT   d4
                ext.l   d5
                D3PUT   d5
                move.w  clip_y0,d0
                ext.l   d0
                D3PUT   d0
                move.w  clip_y1,d0
                ext.l   d0
                D3PUT   d0
                ; --- answer : stored first (interrupts masked as
                ;     short as possible), filled afterwards
                lea     d3dobuf,a0
                move.l  #D3D_TMO,d3
.rd:            D3GET   d0
                and.l   #$ffffff,d0
                move.l  d0,(a0)+
                btst    #23,d0
                beq     .end                    ; $400000 : end
                btst    #22,d0
                bne.s   .frt                    ; $C00000 : front face
                moveq   #1,d2                   ; $800000 : face, 2 chains
.ch:            D3GET   d0                      ; chain : segments of 5 words,
                and.l   #$ffffff,d0             ;  0 at the end
                move.l  d0,(a0)+
                beq.s   .ch2
                D3GET   (a0)+
                D3GET   (a0)+
                D3GET   (a0)+
                D3GET   (a0)+
                bra.s   .ch
.ch2:           dbra    d2,.ch
                bra     .rd
.frt:           D3GET   (a0)+
                D3GET   (a0)+
                D3GET   (a0)+
                D3GET   (a0)+
                bra     .rd
.end:           btst    #0,d0                   ; bounding box
                beq.s   .e1
                D3GET   (a0)+
                D3GET   (a0)+
.e1:            bsr     d3dend
                ; --- filling
                lea     d3dobuf,a3
                clr.w   d3dfr                   ; (no front face)
.dr:            move.l  (a3)+,d0
                btst    #23,d0
                beq     .bb
                btst    #22,d0
                bne     .fr
                move.l  d0,d1                   ; colour : bits 18-19
                swap    d1
                lsr.w   #2,d1
                and.w   #3,d1
                add.w   d1,d1
                move.w  (a1,d1.w),d3            ; colour on 2 pixels
                swap    d3
                move.w  (a1,d1.w),d3
                move.w  d0,d1                   ; n lines
                and.w   #$1ff,d1
                move.w  d1,d3dln
                move.l  d0,d1                   ; ymin : bits 9-16
                lsr.l   #8,d1
                lsr.w   #1,d1
                and.w   #$ff,d1
                mulu    #LINEB,d1
                lea     (a6,d1.l),a0            ; 1st line
                move.l  a3,a4                   ; a4 -> right chain
.sk:            tst.l   (a4)+
                beq.s   .sk2
                lea     16(a4),a4
                bra.s   .sk
.sk2:           bsr     .ldl
                bsr     .ldr
.ln:            move.l  d4,d0                   ; left x
                swap    d0
                move.l  d6,d1                   ; right x
                swap    d1
                tst.w   d0
                bpl.s   .k1
                moveq   #0,d0
.k1:            cmp.w   #SCR_W-1,d1
                ble.s   .k2
                move.w  #SCR_W-1,d1
.k2:            sub.w   d0,d1
                bmi.s   .nl
                addq.w  #1,d1                   ; pixels
                add.w   d0,d0
                lea     (a0,d0.w),a2
                move.w  a2,d0                   ; (written as long words)
                btst    #1,d0
                beq.s   .al
                move.w  d3,(a2)+
                subq.w  #1,d1
                beq.s   .nl
.al:            move.w  d1,d0
                lsr.w   #3,d0
                beq.s   .r
                subq.w  #1,d0
.p8:            move.l  d3,(a2)+
                move.l  d3,(a2)+
                move.l  d3,(a2)+
                move.l  d3,(a2)+
                dbra    d0,.p8
.r:             move.w  d1,d0
                and.w   #7,d0
                lsr.w   #1,d0
                beq.s   .r1
                subq.w  #1,d0
.p2:            move.l  d3,(a2)+
                dbra    d0,.p2
.r1:            btst    #0,d1
                beq.s   .nl
                move.w  d3,(a2)+
.nl:            subq.w  #1,d3dln
                beq.s   .fe
                lea     LINEB(a0),a0
                add.l   d5,d4
                add.l   a5,d6
                subq.w  #1,d2
                bne.s   .n1
                bsr.s   .ldl                    ; next segment (left)
.n1:            subq.w  #1,d7
                bne.s   .ln
                bsr.s   .ldr                    ; next segment (right)
                bra     .ln
.fe:            move.l  a4,a3                   ; end of the face : after the 0
.sk3:           tst.l   (a3)+                   ;  of the right chain
                beq     .dr
                lea     16(a3),a3
                bra.s   .sk3
                ; segment : d2 / d7 = lines, d4 / d6 = x, d5 / a5 = slope
.ldl:           move.l  (a3)+,d2
                move.w  2(a3),d4
                swap    d4
                move.w  6(a3),d4
                move.w  10(a3),d5
                swap    d5
                move.w  14(a3),d5
                lea     16(a3),a3
                rts
.ldr:           move.l  (a4)+,d7
                move.w  2(a4),d6
                swap    d6
                move.w  6(a4),d6
                move.w  10(a4),d0
                swap    d0
                move.w  14(a4),d0
                move.l  d0,a5
                lea     16(a4),a4
                rts
.fr:            move.w  2(a3),d0                ; front face : projected rectangle
                ext.l   d0                      ;  (returned in d0-d3)
                move.l  d0,(sp)
                move.w  6(a3),d0
                ext.l   d0
                move.l  d0,4(sp)
                move.w  10(a3),d0
                ext.l   d0
                move.l  d0,8(sp)
                move.w  14(a3),d0
                ext.l   d0
                move.l  d0,12(sp)
                lea     16(a3),a3
                move.w  #1,d3dfr
                bra     .dr
.bb:            btst    #0,d0                   ; bounding box (erasing)
                beq     .x
                move.l  (a3)+,d0                ; bx0 << 12 | bx1
                move.l  d0,d1
                and.w   #$fff,d1
                lsr.l   #8,d0
                lsr.w   #4,d0
                tst.w   bvx_on                  ; (back view : to erase)
                beq.s   .bv
                movem.l d0-d3,-(sp)
                move.w  d1,d2
                move.l  (a3),d3                 ; by0 << 12 | by1
                move.l  d3,d1
                lsr.l   #8,d1
                lsr.w   #4,d1
                and.w   #$fff,d3
                jsr     bvx_add
                movem.l (sp)+,d0-d3
.bv:
                cmp.w   bb_x0,d0
                bge.s   .b1
                move.w  d0,bb_x0
.b1:            cmp.w   bb_x1,d1
                ble.s   .b2
                move.w  d1,bb_x1
.b2:            move.l  (a3)+,d0                ; by0 << 12 | by1
                move.l  d0,d1
                and.w   #$fff,d1
                lsr.l   #8,d0
                lsr.w   #4,d0
                cmp.w   bb_y0,d0
                bge.s   .b3
                move.w  d0,bb_y0
.b3:            cmp.w   bb_y1,d1
                ble.s   .x
                move.w  d1,bb_y1
.x:             moveq   #0,d7
                move.w  d3dfr,d7                ; 1 : front face to fill
                movem.l (sp)+,d0-d6/a0-a5
                rts
.ko:            bsr     d3dend                  ; the DSP no longer answers
                moveq   #-1,d7
                movem.l (sp)+,d0-d6/a0-a5
                rts

;---------------------------------------------------------------------
; d3dkey : D key : 3D maths by the DSP / by the 030 (comparison)
d3dkey:
                tst.w   dsp3d
                beq.s   .no
                eor.w   #1,d3don
                lea     t_d3don,a0
                tst.w   d3don
                bne.s   .m
                lea     t_d3doff,a0
.m:             move.l  a0,msg_ptr
                move.w  #MSG_DUR,msg_t
                rts
.no:            lea     t_d3dno,a0
                bra.s   .m

;---------------------------------------------------------------------
                section data
                even
d3dcode:        incbin  'R3D.P56'               ; (3 bytes per DSP word)
d3dcend:
                even
d3dzero:        dc.w    0

                section bss
                even
dsp3d:          ds.w    1                       ; R3D loaded and answering
d3don:          ds.w    1                       ; 3D maths by the DSP
d3dsr:          ds.w    1
d3dfr:          ds.w    1                       ; front face to fill
d3dln:          ds.w    1                       ; lines of the face
d3dobuf:        ds.l    D3D_MAXW                ; answer of the DSP (one box)
d3dcomb:        ds.b    3*2048                  ; Simplet + R3D for Dsp_ExecProg

                section text
