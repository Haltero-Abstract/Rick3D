;=====================================================================
; SONS.S - YM2149 SOUND EFFECTS
;   (included by RICK3D.S ; the settings are in PARAMS.S)
;=====================================================================

;=====================================================================
; YM2149 SOUND EFFECTS
;   3 voices (A, B, C), one per kind of effect. Each effect : duration in
;   frames, start period + step per frame (glissando), 8.8 volume +
;   step, optional white noise. sfx_update moves one step per frame.
;   YM writes under $2700 : the TOS also selects registers
;   (port A : floppy drive) in its interrupts.
;=====================================================================

; effect descriptor
                rsreset
FX_CHAN         rs.w    1               ; voice 0..2
FX_LEN          rs.w    1               ; duration (frames)
FX_PER          rs.w    1               ; start tone period
FX_DPER         rs.w    1               ; period step / frame
FX_VOL          rs.w    1               ; start volume (8.8)
FX_DVOL         rs.w    1               ; volume step / frame (8.8)
FX_NOISE        rs.w    1               ; 0 = no noise, else noise period

; state of a voice
                rsreset
CH_LEFT         rs.w    1
CH_PER          rs.w    1
CH_DPER         rs.w    1
CH_VOL          rs.w    1
CH_DVOL         rs.w    1
CH_NOISE        rs.w    1
CH_SIZE         rs.b    0

; writes d1.b into the YM register d0.b
ym_write:
                move.w  sr,-(sp)
                move.w  #$2700,sr
                move.b  d0,YM_SEL.w
                move.b  d1,YM_WR.w
                move.w  (sp)+,sr
                rts

; sfx_init : the PSG is added to the matrix (DSP) towards the DAC.
; On the Falcon the YM reaches the DAC only through the codec ADC :
;   ADCINPUT = PSG (left + right), ADDERIN = ADC + matrix,
;   ADC input gain raised (the PSG is weak next to the DSP).
; Done by the XBIOS Soundcmd (130) : registers guaranteed by the TOS.

soundcmd        macro                   ; Soundcmd(mode, value)
                move.w  \2,-(sp)
                move.w  \1,-(sp)
                move.w  #130,-(sp)
                trap    #14
                addq.l  #6,sp
                endm

sfx_init:
                movem.l d0-d2/a0-a2,-(sp)
                soundcmd #5,#3                  ; ADCINPUT : PSG left and right
                soundcmd #2,#YM_GAIN            ; LTGAIN
                soundcmd #3,#YM_GAIN            ; RTGAIN
                moveq   #3,d0                   ; ADDERIN : ADC (+ matrix if DSP)
                tst.w   dspok
                bne.s   .m
                moveq   #1,d0
.m:             soundcmd #4,d0
                movem.l (sp)+,d0-d2/a0-a2
                bra     sfx_off

; sfx_off : silences the 3 voices
sfx_off:
                lea     sfx_ch,a0
                moveq   #3*CH_SIZE/2-1,d0
.c:             clr.w   (a0)+
                dbra    d0,.c
                moveq   #8,d0                   ; volumes A, B, C = 0
                moveq   #0,d1
                bsr     ym_write
                moveq   #9,d0
                bsr     ym_write
                moveq   #10,d0
                bsr     ym_write
                moveq   #-1,d2                  ; all off
                bra     sfx_mixer

; sfx_play : a0 = effect to start (replaces the current effect of its voice)
sfx_play:
                movem.l d0/a1,-(sp)
                move.w  FX_CHAN(a0),d0
                mulu    #CH_SIZE,d0
                lea     sfx_ch,a1
                adda.w  d0,a1
                move.w  FX_LEN(a0),CH_LEFT(a1)
                move.w  FX_PER(a0),CH_PER(a1)
                move.w  FX_DPER(a0),CH_DPER(a1)
                move.w  FX_VOL(a0),CH_VOL(a1)
                move.w  FX_DVOL(a0),CH_DVOL(a1)
                move.w  FX_NOISE(a0),CH_NOISE(a1)
                movem.l (sp)+,d0/a1
                rts

; sfx_update : one step per frame for each active voice
sfx_update:
                movem.l d0-d4/a0,-(sp)
                moveq   #-1,d2                  ; mixer : bits at 0 = active
                lea     sfx_ch,a0
                moveq   #0,d3                   ; voice
.ch:            tst.w   CH_LEFT(a0)
                beq.s   .idle
                subq.w  #1,CH_LEFT(a0)
                move.w  CH_PER(a0),d4           ; period (12 bits)
                move.w  d3,d0
                add.w   d0,d0                   ; registers 0/1, 2/3, 4/5
                move.b  d4,d1
                bsr     ym_write
                addq.w  #1,d0
                move.w  d4,d1
                lsr.w   #8,d1
                and.b   #$0f,d1
                bsr     ym_write
                move.w  CH_VOL(a0),d1           ; volume 0..15
                lsr.w   #8,d1
                moveq   #8,d0
                add.w   d3,d0
                bsr     ym_write
                tst.w   d4                      ; period 0 = noise only
                beq.s   .nt
                bclr    d3,d2                   ; tone active
.nt:                move.w  CH_NOISE(a0),d1
                beq.s   .nn
                moveq   #6,d0                   ; noise period
                bsr     ym_write
                move.w  d3,d0
                addq.w  #3,d0
                bclr    d0,d2                   ; noise active
.nn:            move.w  CH_DPER(a0),d0          ; glissando
                add.w   d0,CH_PER(a0)
                move.w  CH_DVOL(a0),d0          ; decay
                add.w   d0,CH_VOL(a0)
                bpl.s   .next
                clr.w   CH_VOL(a0)
                bra.s   .next
.idle:          moveq   #8,d0                   ; free voice : volume 0
                add.w   d3,d0
                moveq   #0,d1
                bsr     ym_write
.next:          lea     CH_SIZE(a0),a0
                addq.w  #1,d3
                cmp.w   #3,d3
                blo.s   .ch
                bsr     sfx_mixer
                movem.l (sp)+,d0-d4/a0
                rts

; sfx_mixer : register 7 = d2 (bits 0..5), bits 6-7 are kept
;             (direction of ports A/B : floppy drive, printer)
sfx_mixer:
                move.w  sr,-(sp)
                move.w  #$2700,sr
                move.b  #7,YM_SEL.w
                move.b  YM_SEL.w,d1
                and.b   #$c0,d1
                and.b   #$3f,d2
                or.b    d2,d1
                move.b  d1,YM_WR.w
                move.w  (sp)+,sr
                rts
