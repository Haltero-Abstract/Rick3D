;=====================================================================
; ACCUEIL.S - WELCOME PAGE (before the game, like the one of 3DREAMS) :
;   TOS text centred on the desktop screen (40 or 80 columns) :
;   title, credits, keys. SPACE = play, ESC = back to the desktop.
;   (included by RICK3D.S)
;=====================================================================

; infopage : d0 = 0 : play ; d0 = -1 : quit
infopage:
                movem.l d1-d7/a0-a6,-(sp)
                dc.w    $a000                   ; Line-A : size of the text screen
                move.w  -44(a0),d6              ; last column
                addq.w  #1,d6                   ; columns
                move.w  -42(a0),d5              ; last line
                addq.w  #1,d5
                sub.w   #INFOH,d5               ; top margin
                asr.w   #1,d5
                bpl.s   .m
                moveq   #0,d5
.m:             bsr     ipalset                 ; black background, white text
                dc.w    $a00a                   ; hides the mouse
                pea     i_cls(pc)
                move.w  #9,-(sp)                ; Cconws
                trap    #1
                addq.l  #6,sp
                lea     infotab,a3
.l:             move.b  (a3)+,d7                ; line (-1 = end)
                bmi.s   .wait
                move.l  a3,a4                   ; length of the text
.n:             tst.b   (a4)+
                bne.s   .n
                move.l  a4,d0
                sub.l   a3,d0
                subq.w  #1,d0
                move.w  d6,d1                   ; column = (width - length) / 2
                sub.w   d0,d1
                asr.w   #1,d1
                bpl.s   .c
                moveq   #0,d1
.c:             lea     i_pos,a0                ; ESC Y line column
                add.b   d5,d7
                add.b   #32,d7
                move.b  d7,2(a0)
                add.b   #32,d1
                move.b  d1,3(a0)
                pea     (a0)
                move.w  #9,-(sp)
                trap    #1
                addq.l  #6,sp
                pea     (a3)
                move.w  #9,-(sp)
                trap    #1
                addq.l  #6,sp
                move.l  a4,a3
                bra.s   .l
.fl:            move.w  #11,-(sp)               ; Cconis : keys pressed before
                trap    #1                      ;  the page appeared are thrown
                addq.l  #2,sp                   ;  away (else a key left in the
                tst.w   d0                      ;  buffer would start or quit
                beq.s   .wait                   ;  at once)
                move.w  #7,-(sp)
                trap    #1
                addq.l  #2,sp
                bra.s   .fl
.wait:          move.w  #7,-(sp)                ; Crawcin : waits for a key
                trap    #1
                addq.l  #2,sp
                swap    d0                      ; scancode
                cmp.b   #$39,d0                 ; SPACE
                beq.s   .go
                cmp.b   #$01,d0                 ; ESC
                bne.s   .wait
                bsr     ipalrst                 ; desktop colours
                pea     i_end(pc)               ; ESC : back to the desktop
                move.w  #9,-(sp)
                trap    #1
                addq.l  #6,sp
                dc.w    $a009                   ; shows the mouse
                moveq   #-1,d0
                bra.s   .out
.go:            bsr     ipalrst                 ; desktop colours
                pea     i_end(pc)
                move.w  #9,-(sp)
                trap    #1
                addq.l  #6,sp
                moveq   #0,d0
.out:           movem.l (sp)+,d1-d7/a0-a6
                rts

;---------------------------------------------------------------------
; ipalset / ipalrst : the page writes with colour 0 on the background
;   colour 15 (or 1 / 3 depending on the planes of the desktop). These colours
;   are the ones chosen on the desktop : they are forced to white and black
;   (ST palette with Setcolor and Falcon palette with VsetRGB), then given
;   back before leaving the page. a0 = Line-A variables for ipalset.
ipalset:
                movem.l d0-d2/a0-a2,-(sp)
                move.w  (a0),d1                 ; planes
                moveq   #15,d0
                cmp.w   #4,d1
                bhs.s   .b
                moveq   #1,d0                   ; 1 or 2 planes : 1 or 3
                lsl.w   d1,d0
                subq.w  #1,d0
.b:             move.w  d0,ipbg
                tst.w   ipsaved                 ; save (the 1st time)
                bne.s   .s
                st      ipsaved
                clr.w   d0
                bsr.s   ipstget
                move.w  d0,ipst
                move.w  ipbg,d0
                bsr.s   ipstget
                move.w  d0,ipst+2
                pea     ipfal                   ; VgetRGB(0,1,ipfal)
                move.w  #1,-(sp)
                clr.w   -(sp)
                move.w  #94,-(sp)
                trap    #14
                lea     10(sp),sp
                pea     ipfal+4                 ; VgetRGB(bg,1,ipfal+4)
                move.w  #1,-(sp)
                move.w  ipbg,-(sp)
                move.w  #94,-(sp)
                trap    #14
                lea     10(sp),sp
.s:             move.w  #$0fff,d1               ; white text, black background
                clr.w   d0
                bsr.s   ipstset
                moveq   #0,d1
                move.w  ipbg,d0
                bsr.s   ipstset
                lea     ipwhite,a0
                clr.w   d0
                bsr.s   ipfset
                lea     ipblack,a0
                move.w  ipbg,d0
                bsr.s   ipfset
                movem.l (sp)+,d0-d2/a0-a2
                rts
ipstget:        moveq   #-1,d1                  ; Setcolor(d0,-1)
ipstset:        move.w  d1,-(sp)                ; Setcolor(d0,d1)
                move.w  d0,-(sp)
                move.w  #7,-(sp)
                trap    #14
                addq.l  #6,sp
                rts
ipfset:         pea     (a0)                    ; VsetRGB(d0,1,a0)
                move.w  #1,-(sp)
                move.w  d0,-(sp)
                move.w  #93,-(sp)
                trap    #14
                lea     10(sp),sp
                rts

ipalrst:
                movem.l d0-d2/a0-a2,-(sp)
                tst.w   ipsaved
                beq.s   .x
                clr.w   ipsaved
                move.w  ipst,d1
                clr.w   d0
                bsr.s   ipstset
                move.w  ipst+2,d1
                move.w  ipbg,d0
                bsr.s   ipstset
                lea     ipfal,a0
                clr.w   d0
                bsr.s   ipfset
                lea     ipfal+4,a0
                move.w  ipbg,d0
                bsr.s   ipfset
.x:             movem.l (sp)+,d0-d2/a0-a2
                rts

i_cls:          dc.b    27,'c','?',27,'b','@'   ; black background (colour 15/3/1), white text (0)
                dc.b    27,'E',27,'f',0         ; clear, cursor hidden
i_end:          dc.b    27,'c','@',27,'b','?',27,'E',0  ; desktop colours
                even

                section data
i_pos:          dc.b    27,'Y',0,0,0
                even
ipwhite:        dc.l    $00ffffff               ; Falcon palette : $00RRGGBB
ipblack:        dc.l    $00000000
ipfal:          ds.l    2                       ; desktop colours 0 and background (Falcon)
ipst:           ds.w    2                       ; desktop colours 0 and background (ST)
ipbg:           ds.w    1                       ; index of the background colour
ipsaved:        ds.w    1
INFOH           equ     25                      ; page height (lines)
; line (0..24), text in English (38 characters max : fits in 40 columns)
infotab:
                dc.b    0,'HALTERO / ABSTRACT',0
                dc.b    1,'PRESENTS',0
                dc.b    3,'--- RICK3D ---',0
                dc.b    4,'Rick Dangerous 2 in 3D',0
                dc.b    6,'Inspired by Rick Dangerous 2',0
                dc.b    7,'(Core Design 1990) : Hyde Park level',0
                dc.b    9,'Atari Falcon 030 + DSP 56001',0
                dc.b    10,'DSP 3D maths inspired by',0
                dc.b    11,'X-Perience Skynet / Abstract (94)',0
                dc.b    13,'Game design ..... Haltero / Abstract',0
                dc.b    14,'DSP MOD replay .. Simplet / Abstract',0
                dc.b    16,'Arrows or joystick, SPACE = fire',0
                dc.b    17,'Up  jump         Down  crouch',0
                dc.b    18,'Fire+up  laser   Fire+down  bomb',0
                dc.b    19,'Fire+down+side : throw the bomb',0
                dc.b    20,'M music  P pause  + - volume',0
                dc.b    21,'V back view      G map scrolling',0
                dc.b    22,'D DSP / 030  H text  I infinite lives',0
                dc.b    23,'R save position  B go back there',0
                dc.b    24,'SPACE play   -   ESC quit',0
                dc.b    -1
                even
                section text
