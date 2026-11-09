;=====================================================================
; CLAVIER.S - KEYBOARD AND JOYSTICK (IKBD interrupt, keys)
;   (included by RICK3D.S ; the settings are in PARAMS.S)
;=====================================================================

;---------------------------------------------------------------------
; ACIA interrupt (MFP $118) : reads the IKBD directly
; - joystick packets $FE/$FF -> joy0/joy1
; - other packets (mouse, clock...) ignored
; - keys : keytab[scancode] = $FF pressed / 0 released
;   + each press is stored in keyring (16 keys) for do_keys
my_acia:
                movem.l d0-d1/a0,-(sp)
.loop:          btst    #0,$fffffc04.w          ; MIDI : emptied
                beq.s   .nomidi
                tst.b   $fffffc06.w
.nomidi:        btst    #0,$fffffc00.w          ; keyboard byte received ?
                beq     .done
                move.b  $fffffc02.w,d0
                move.w  pkt_cnt,d1
                beq.s   .new
                subq.w  #1,pkt_cnt
                move.l  pkt_dst,d1
                beq.s   .loop
                move.l  d1,a0
                move.b  d0,(a0)
                bra.s   .loop
.new:           cmp.b   #$f6,d0
                bhs.s   .pkt
                moveq   #0,d1
                move.b  d0,d1
                and.w   #$7f,d1
                lea     keytab,a0
                tst.b   d0
                bmi.s   .brk
                st      (a0,d1.w)               ; press
                move.w  keyw,d0
                lea     keyring,a0
                move.b  d1,(a0,d0.w)
                addq.w  #1,d0
                and.w   #15,d0
                move.w  d0,keyw
                cmp.w   #$01,d1                 ; ESC
                bne.s   .loop
                move.w  #1,quit_flag
                bra.s   .loop
.brk:           sf      (a0,d1.w)               ; release
                bra     .loop
.pkt:           clr.l   pkt_dst
                cmp.b   #$fe,d0
                blo.s   .other
                move.l  #joy0,pkt_dst
                cmp.b   #$ff,d0
                bne.s   .one
                move.l  #joy1,pkt_dst
.one:           move.w  #1,pkt_cnt
                bra     .loop
.other:         moveq   #0,d1
                move.b  d0,d1
                sub.w   #$f6,d1
                move.b  pkt_len(pc,d1.w),d1
                move.w  d1,pkt_cnt
                bra     .loop
.done:          movem.l (sp)+,d0-d1/a0
                bclr    #6,$fffffa11.w          ; end of interrupt (ISRB)
                rte
pkt_len:        dc.b    7,5,2,2,2,2,6,2         ; $F6..$FD
                even

; getkey : d0 = scancode of the next key pressed, -1 if none
getkey:
                move.w  keyr,d1
                cmp.w   keyw,d1
                beq.s   .none
                lea     keyring,a0
                moveq   #0,d0
                move.b  (a0,d1.w),d0
                addq.w  #1,d1
                and.w   #15,d1
                move.w  d1,keyr
                rts
.none:          moveq   #-1,d0
                rts

; command keys (scancodes, French and English keyboards)
do_keys:
.lp:            bsr     getkey
                tst.w   d0
                bmi     .x
                cmp.w   #$27,d0                 ; M (AZERTY)
                beq.s   .mus
                cmp.w   #$32,d0                 ; M (QWERTY)
                beq.s   .mus
                cmp.w   #$19,d0                 ; P
                beq.s   .pause
                cmp.w   #$23,d0                 ; H
                beq.s   .hide
                cmp.w   #$17,d0                 ; I : infinite lives on / off
                beq.s   .inf
                cmp.w   #$22,d0                 ; G : map scrolling on / off
                beq     .glis
                cmp.w   #$2f,d0                 ; V : side view / back view
                beq     .view
                cmp.w   #$20,d0                 ; D : 3D maths DSP / 030
                beq     .d3d
                cmp.w   #$13,d0                 ; R : saves the position
                beq     .rec
                cmp.w   #$30,d0                 ; B : back to the position
                beq     .back
                cmp.w   #$4e,d0                 ; + numeric keypad
                beq     .vup
                cmp.w   #$35,d0                 ; = / + (AZERTY)
                beq     .vup
                cmp.w   #$0d,d0                 ; = / + (QWERTY)
                beq     .vup
                cmp.w   #$4a,d0                 ; - numeric keypad
                beq     .vdn
                cmp.w   #$0c,d0                 ; - (QWERTY) / ) (AZERTY)
                beq     .vdn
                bra     .lp
.mus:           bsr     nextmod
                bra     .lp
.pause:         bsr     togglepause
                bra     .lp
.hide:          not.w   txt_hidden
                bra     .lp
.inf:           not.w   inf_lives
                bra     .lp
.glis:          not.w   sc_on
                and.w   #1,sc_on
                move.w  #-1,win_tx              ; screen rebuilt
                movem.l d0-d7/a0-a6,-(sp)
                bsr     check_window
                movem.l (sp)+,d0-d7/a0-a6
                move.l  #t_glon,msg_ptr
                tst.w   sc_on
                bne.s   .gm
                move.l  #t_gloff,msg_ptr
.gm:            move.w  #MSG_DUR,msg_t
                bra     .lp
.view:          not.w   view_back
                and.w   #1,view_back
                clr.w   bv_in
                move.w  #1,need_rebuild
                bra     .lp
.d3d:           jsr     d3dkey
                move.w  #1,need_rebuild
                bra     .lp
.rec:           bsr     pos_record
                bra     .lp
.back:          bsr     pos_back
                bra     .lp
.vup:           move.w  mastervol,d0
                addq.w  #MUS_VOL_STEP,d0
                cmp.w   #MUS_VOL_MAX,d0
                bls.s   .sv
                moveq   #MUS_VOL_MAX,d0
                bra.s   .sv
.vdn:           move.w  mastervol,d0
                subq.w  #MUS_VOL_STEP,d0
                bpl.s   .sv
                moveq   #0,d0
.sv:            move.w  d0,mastervol
                bsr     setvol
                bra     .lp
.x:             rts

; d7 = joystick state (port 1) + keyboard
get_input:
                move.b  joy1,d7                 ; joystick : port 1 only
                tst.b   keytab+$4b              ; left
                beq.s   .1
                bset    #2,d7
.1:             tst.b   keytab+$4d              ; right
                beq.s   .2
                bset    #3,d7
.2:             tst.b   keytab+$48              ; up
                beq.s   .3
                bset    #0,d7
.3:             tst.b   keytab+$50              ; down
                beq.s   .3b
                bset    #1,d7
.3b:            tst.b   keytab+$39              ; space = fire
                beq.s   .4
                bset    #7,d7
.4:             rts

; frames per second (200 Hz system counter)
countfps:
                addq.w  #1,fpscnt
                move.l  $4ba.w,d0
                move.l  d0,d1
                sub.l   fpsclk,d1
                cmp.l   #200,d1
                blo.s   .out
                move.l  d0,fpsclk
                move.w  fpscnt,fps
                clr.w   fpscnt
.out:           rts
