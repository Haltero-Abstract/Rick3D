;=====================================================================
; MUSIQUE.S - MUSIC : DSP replay (modules ZIK\*.MOD), volume
;   (included by RICK3D.S ; the settings are in PARAMS.S)
;=====================================================================

;=====================================================================
; MUSIC : INTERFACE WITH SIMPLET'S DSP REPLAY (AMIGADSP.S)
;   taken from CUBEDSP.S
;=====================================================================

; dspinit : loads the DSP program, saves and sets up the sound
dspinit:
                movem.l d0-d7/a0-a6,-(sp)
                clr.w   dspok
                jsr     d3dinit                 ; Simplet + R3D (Dsp_ExecProg)
                tst.l   d0
                bmi.s   .ko
                move.w  #1,dspok
                bsr     MGTK_Save_Sound
                bsr     MGTK_Init_Sound         ; matrix : DSP -> DAC
                moveq   #REPFREQ,d0
                bsr     MGTK_Set_Replay_Frequency
                sf      MGTK_Restart_Loop       ; end of the module : next one
                jsr     d3dload                 ; R3D answers ? -> d3don
.ko:            movem.l (sp)+,d0-d7/a0-a6
                rts

; dspexit : gives back the original sound system
dspexit:
                tst.w   dspok
                beq.s   .out
                movem.l d0-d7/a0-a6,-(sp)
                bsr     MGTK_Restore_Sound
                movem.l (sp)+,d0-d7/a0-a6
.out:           rts

; startmus : starts the loaded module (musok = 1)
startmus:
                tst.w   musok
                beq.s   .out
                movem.l d0-d7/a0-a6,-(sp)
                sf      MGTK_Restart_Done
                bsr     MGTK_Play_Music         ; installs Timer A
                movem.l (sp)+,d0-d7/a0-a6
                move.w  #1,playing
                bsr     setvol
.out:           rts

; stopmus : stops the replay
stopmus:
                tst.w   playing
                beq.s   .out
                movem.l d0-d7/a0-a6,-(sp)
                bsr     MGTK_Stop_Music
                movem.l (sp)+,d0-d7/a0-a6
                clr.w   playing
                clr.w   paused
.out:           rts

; setvol : master volume 0..64 -> DSP master volumes
setvol:
                move.w  mastervol,d0
                mulu    #1023,d0
                move.w  d0,MGTK_Master_Volume_Left
                move.w  d0,MGTK_Master_Volume_Right
                rts

; togglepause : P -> pause / resume
togglepause:
                tst.w   playing
                beq.s   .out
                movem.l d0-d7/a0-a6,-(sp)
                bsr     MGTK_Pause_Music
                movem.l (sp)+,d0-d7/a0-a6
                not.w   paused
.out:           rts

; scanmods : fills modnames with ZIK\*.MOD -> nmods (sorted)
scanmods:
                clr.w   nmods
                pea     dta                     ; Fsetdta
                move.w  #$1a,-(sp)
                trap    #1
                addq.l  #6,sp
                clr.w   -(sp)                   ; Fsfirst
                pea     modmask
                move.w  #$4e,-(sp)
                trap    #1
                addq.l  #8,sp
.lp:            tst.l   d0
                bne.s   .out
                move.w  nmods,d0
                cmp.w   #MAXMODS,d0
                bhs.s   .out
                mulu    #NAMESZ,d0
                lea     modnames,a0
                adda.l  d0,a0
                lea     dta+30,a1               ; name in the DTA
                moveq   #NAMESZ-2,d1
.cp:            move.b  (a1)+,(a0)+
                dbeq    d1,.cp
                clr.b   (a0)
                addq.w  #1,nmods
                move.w  #$4f,-(sp)              ; Fsnext
                trap    #1
                addq.l  #2,sp
                bra.s   .lp
.out:           lea     modnames,a0
                move.w  nmods,d0
                bra     sortnames

; bubble sort of the names (a0 = table, d0 = count)
sortnames:
                move.l  a0,a4
                move.w  d0,d7
                subq.w  #2,d7
                bmi.s   .out
.pass:          moveq   #0,d6
                move.l  a4,a0
                move.w  d7,d5
.cmp:           lea     NAMESZ(a0),a1
                move.l  a0,a2
                move.l  a1,a3
.c1:            move.b  (a2)+,d0
                move.b  (a3)+,d1
                cmp.b   d1,d0
                bhi.s   .swap
                blo.s   .next
                tst.b   d0
                bne.s   .c1
                bra.s   .next
.swap:          moveq   #NAMESZ-1,d1
                move.l  a0,a2
                move.l  a1,a3
.s1:            move.b  (a2),d0
                move.b  (a3),(a2)+
                move.b  d0,(a3)+
                dbra    d1,.s1
                moveq   #1,d6
.next:          move.l  a1,a0
                dbra    d5,.cmp
                tst.w   d6
                bne.s   .pass
.out:           rts

; nextmod : next module (loops)
nextmod:
                move.w  nmods,d1
                beq.s   .none
                move.w  curmod,d0
                addq.w  #1,d0
                cmp.w   d1,d0
                blo.s   .go
                moveq   #0,d0
.go:            move.w  d0,curmod
                bsr     stopmus
                bsr     freemod
                bsr     loadmod
                bra     startmus
.none:          move.w  #9,muserr               ; no .MOD in ZIK
                clr.w   musok
                rts

; freemod : gives back the module memory
freemod:
                clr.w   musok
                move.l  modbase,d0
                beq.s   .out
                move.l  d0,-(sp)
                move.w  #$49,-(sp)
                trap    #1
                addq.l  #6,sp
                clr.l   modbase
.out:           rts

; loadmod : loads ZIK\<name>, prepares it (MGTK_Init_Module_Samples)
loadmod:
                clr.w   musok
                move.w  #10,muserr              ; no DSP ?
                tst.w   dspok
                beq     .out
                lea     pathbuf,a0              ; "ZIK\" + name
                lea     modmask,a1
                moveq   #3,d1
.p1:            move.b  (a1)+,(a0)+
                dbra    d1,.p1
                bsr     curname
.p2:            move.b  (a1)+,(a0)+
                bne.s   .p2
                move.w  #1,muserr
                clr.w   -(sp)                   ; Fopen
                pea     pathbuf
                move.w  #$3d,-(sp)
                trap    #1
                addq.l  #8,sp
                tst.l   d0
                bmi     .out
                move.w  d0,sndh
                move.w  #2,muserr
                move.w  #2,-(sp)                ; Fseek end -> size
                move.w  sndh,-(sp)
                clr.l   -(sp)
                move.w  #$42,-(sp)
                trap    #1
                lea     10(sp),sp
                move.l  d0,modlen
                clr.w   -(sp)                   ; Fseek start
                move.w  sndh,-(sp)
                clr.l   -(sp)
                move.w  #$42,-(sp)
                trap    #1
                lea     10(sp),sp
                cmpi.l  #2048,modlen
                blo     .close
                move.w  #3,muserr
                move.w  #3,-(sp)                ; Mxalloc module + work area
                move.l  modlen,d0
                add.l   #WORKSZ+16,d0
                move.l  d0,-(sp)
                move.w  #$44,-(sp)
                trap    #1
                addq.l  #8,sp
                tst.l   d0
                ble     .close
                move.l  d0,modbase
                move.w  #4,muserr
                move.l  modbase,-(sp)           ; Fread
                move.l  modlen,-(sp)
                move.w  sndh,-(sp)
                move.w  #$3f,-(sp)
                trap    #1
                lea     12(sp),sp
                cmp.l   modlen,d0
                bne     .close
                move.w  #6,muserr
                movem.l d0-d7/a0-a6,-(sp)
                move.l  modbase,a0
                move.l  modlen,d0
                addq.l  #1,d0
                and.b   #$fe,d0
                add.l   #WORKSZ,d0
                move.l  a0,a1
                adda.l  d0,a1                   ; a1 = end of the work area
                bsr     MGTK_Init_Module_Samples
                ext.l   d0
                move.l  d0,initres
                movem.l (sp)+,d0-d7/a0-a6
                tst.l   initres
                bmi     .close
                clr.w   muserr
                move.w  #1,musok
.close:         move.w  sndh,-(sp)              ; Fclose
                move.w  #$3e,-(sp)
                trap    #1
                addq.l  #4,sp
                tst.w   musok
                bne.s   .out
                bsr     freemod
.out:           rts

; curname : a1 = name of the current module
curname:
                move.w  curmod,d1
                mulu    #NAMESZ,d1
                lea     modnames,a1
                adda.l  d1,a1
                rts
