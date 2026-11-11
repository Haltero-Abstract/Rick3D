;=====================================================================
; PROFIL.S - PROFILER (key T) : time spent per part of the frame
;   (included twice by RICK3D.S : before INIT.S for the PROF macro,
;    after MENUS.S for the code)
;
;   Clock : MFP Timer D, 2.4576 MHz / 50 = 49152 Hz (1 tick = 20.3 us),
;   counter 256 -> interrupt -> pr_ovf + 1 (192 interrupts / second).
;   Time = pr_ovf * 256 + (256 - TDDR).
;   Each PROF n adds the time since the previous PROF to the part n.
;   Every PR_NFR frames the averages are copied for the text bar :
;   values in 0.1 ms per frame (16.7 ms = one VGA 60 Hz frame).
;   Also counted : DSP waits (polling loops of the host port, per frame)
;   and words copied back by the erasing (per frame, in hundreds).
;=====================================================================

                ifnd    PROF_DEF               ; 1st include (before INIT.S) :
PROF_DEF        equ     1               ;  constants + macro only

PR_NSEC         equ     11              ; parts of the frame
PR_NFR          equ     32              ; frames per average
PR_LOG          equ     0               ; keys + update_* (game logic)
PR_BLD          equ     1               ; rebuild of the scenery / scrolling
PR_ERA          equ     2               ; erasing (scenery copied back)
PR_ZAP          equ     3               ; beams, waves, canisters
PR_PLT          equ     4               ; platforms
PR_ENM          equ     5               ; enemies
PR_RIK          equ     6               ; Rick
PR_LAS          equ     7               ; Rick's shots
PR_OBJ          equ     8               ; objects
PR_HUD          equ     9               ; HUD + text bar
PR_VBL          equ     10              ; flip : waiting for the VBL (spare)

; PROF n : end of part n (all registers kept)
PROF            macro
                tst.w   pr_run                  ; (measured all the time ;
                beq.s   .pf\@                   ;  T only shows it)
                move.l  d1,-(sp)
                moveq   #\1,d1
                jsr     prof_mark
                move.l  (sp)+,d1
.pf\@:
                endm

                else                    ; 2nd include (after MENUS.S) : code

;---------------------------------------------------------------------
; prof_install / prof_remove : Timer D (interrupts already masked)
prof_install:
                move.l  $110.w,pr_oldvec
                move.b  $fffffa1d.w,pr_oldcd    ; TCDCR (C : bits 4-6, D : bits 0-2)
                move.b  $fffffa25.w,pr_olddr
                move.b  $fffffa09.w,d0          ; IERB / IMRB bit 4 = Timer D
                and.b   #$10,d0
                move.b  d0,pr_oldie
                move.b  $fffffa15.w,d0
                and.b   #$10,d0
                move.b  d0,pr_oldim
                move.l  #prof_tdint,$110.w
                and.b   #$f0,$fffffa1d.w        ; Timer D stopped
                clr.b   $fffffa25.w             ; counter 256
                or.b    #4,$fffffa1d.w          ; prescaler 50
                bset    #4,$fffffa09.w
                bset    #4,$fffffa15.w
                clr.l   pr_ovf
                clr.l   pr_last
                move.l  #pr_logbuf,pr_logp      ; log : header
                lea     pr_head,a1
                move.l  pr_logp,a0
.h:             move.b  (a1)+,(a0)+
                bne.s   .h
                subq.l  #1,a0
                move.l  a0,pr_logp
                move.w  #1,pr_run
                rts

prof_remove:
                and.b   #$f0,$fffffa1d.w
                move.b  pr_olddr,$fffffa25.w
                move.b  pr_oldcd,d0
                and.b   #$0f,d0
                or.b    d0,$fffffa1d.w
                bclr    #4,$fffffa09.w
                bclr    #4,$fffffa15.w
                move.b  pr_oldie,d0
                or.b    d0,$fffffa09.w
                move.b  pr_oldim,d0
                or.b    d0,$fffffa15.w
                move.l  pr_oldvec,$110.w
                rts

prof_tdint:     addq.l  #1,pr_ovf
                move.b  #$ef,$fffffa11.w        ; ISRB : end of Timer D
                rte

; d0 = time in ticks
prof_now:
.r:             move.l  pr_ovf,d0
                moveq   #0,d1
                move.b  $fffffa25.w,d1
                cmp.l   pr_ovf,d0               ; interrupt in between : again
                bne.s   .r
                neg.w   d1                      ; 0 -> 256 : 0 elapsed
                and.w   #$ff,d1
                lsl.l   #8,d0
                add.l   d1,d0
                rts

; prof_mark : d1 = part ; adds (now - last) to it
prof_mark:
                movem.l d0/d2/a0-a1,-(sp)
                move.w  d1,d2
                bsr.s   prof_now
                move.l  d0,d1
                sub.l   pr_last,d1
                move.l  d0,pr_last
                lea     pr_acc,a0
                lsl.w   #2,d2
                add.l   d1,(a0,d2.w)
                cmp.w   #PR_VBL*4,d2            ; end of the frame
                bne.s   .x
                addq.w  #1,pr_fcnt
                cmp.w   #PR_NFR,pr_fcnt
                blo.s   .x
                clr.w   pr_fcnt
                lea     pr_acc,a0               ; averages in 0.1 ms :
                lea     pr_show,a1              ;  ticks * 20.345 us / 100 / 32
                moveq   #PR_NSEC-1,d2           ;  = ticks * 13 / 2048
.av:            move.l  (a0),d0
                clr.l   (a0)+
                tst.l   d0
                bpl.s   .av1                    ; (interrupts masked too long :
                moveq   #0,d0                   ;  no negative time)
.av1:
                mulu.l  #13,d0
                moveq   #11,d1
                lsr.l   d1,d0
                move.w  d0,(a1)+
                dbra    d2,.av
                move.l  pr_dsp,d0               ; DSP waits per frame
                clr.l   pr_dsp
                lsr.l   #5,d0
                move.w  d0,(a1)+
                move.l  pr_ew,d0                ; erased words per frame / 100
                clr.l   pr_ew
                lsr.l   #5,d0
                divu    #100,d0
                move.w  d0,(a1)+
                bsr     prof_logrec
.x:             movem.l (sp)+,d0/d2/a0-a1
                rts

; prof_key : T = profiler on / off
prof_key:
                not.w   prof_on
                and.w   #1,prof_on
                rts

;---------------------------------------------------------------------
; LOG : one line every PR_NFR frames (about 2 per second) in pr_logbuf,
;   written to RICK3D.LOG when leaving the game and with the L key.
;   Line : level, map line / column of Rick, D (1 = 3D maths by the DSP),
;   then the 13 values of the text bar (same units).
prof_logrec:
                movem.l d0-d5/a0-a2,-(sp)
                move.l  pr_logp,a0
                cmp.l   #pr_logend-320,a0       ; full : no more lines
                bhs     .x
                move.w  cur_level,d0
                lea     pr_tlv,a2
                bsr     .val
                move.w  rick_xf,d4              ; (same as the text bar)
                asr.w   #3,d4
                addq.w  #RICK_W/2,d4
                asr.w   #3,d4
                move.w  rick_yf,d5
                asr.w   #3,d5
                add.w   rk_h,d5
                subq.w  #1,d5
                asr.w   #3,d5
                move.w  d5,d0
                add.w   hdr_lines,d0
                addq.w  #1,d0
                lea     pr_tl,a2
                bsr     .val
                move.w  d4,d0
                lea     pr_tc,a2
                bsr     .val
                move.w  d3don,d0
                lea     pr_td,a2
                bsr     .val
                lea     pr_names,a2
                lea     pr_show,a1
                moveq   #PR_NSEC+2-1,d3
.l:             move.w  (a1)+,d0
                move.l  a1,-(sp)
                bsr     .val
                move.l  (sp)+,a1
                addq.l  #5,a2
                dbra    d3,.l
                move.w  spr_mk,d0               ; sprites made (SPRITES.S)
                clr.w   spr_mk
                lea     pr_tmk,a2
                bsr     .val
                move.w  spr_fb,d0               ; cached sprites drawn in 3D
                clr.w   spr_fb                  ;  (SPRITES.S) : number,
                lea     pr_tfb,a2               ;  reasons, last place
                bsr     .val
                move.w  spr_fbm,d0
                clr.w   spr_fbm
                lea     pr_tfm,a2
                bsr     .val
                move.w  spr_fbx,d0
                lea     pr_tfx,a2
                bsr     .val
                move.w  spr_fby,d0
                lea     pr_tfy,a2
                bsr     .val
                lea     bg_nh,a1                ; background build (BGBUILD.S) :
                lea     pr_tbg,a2               ;  hits, misses, dropped, snapped,
                moveq   #5,d3                   ;  last screen not ready (x, y)
.bg:            move.w  (a1),d0
                cmp.w   #2,d3
                blt.s   .bg1
                clr.w   (a1)                    ; (counters : per line)
.bg1:           addq.l  #2,a1
                movem.l d3/a1,-(sp)
                bsr     .val
                movem.l (sp)+,d3/a1
.bg2:           tst.b   (a2)+
                bne.s   .bg2
                dbra    d3,.bg
                lea     bgs_tx,a1               ;  the 3 slots : x, y, state
                moveq   #2,d3
.sl:            move.w  (a1),d0
                lea     pr_tsx,a2
                movem.l d3/a1,-(sp)
                bsr     .val
                movem.l (sp),d3/a1
                move.w  6(a1),d0
                lea     pr_tsy,a2
                bsr     .val
                movem.l (sp),d3/a1
                move.w  12(a1),d0
                lea     pr_tss,a2
                bsr     .val
                movem.l (sp)+,d3/a1
                addq.l  #2,a1
                dbra    d3,.sl
                move.b  #13,(a0)+
                move.b  #10,(a0)+
                move.l  a0,pr_logp
.x:             movem.l (sp)+,d0-d5/a0-a2
                rts
                ; name (a2) + number d0 + space
.val:           move.l  a2,a1
.n:             move.b  (a1)+,d1
                beq.s   .n1
                move.b  d1,(a0)+
                bra.s   .n
.n1:            bsr     fmtnum
.d:             move.b  (a1)+,d1
                beq.s   .d1
                move.b  d1,(a0)+
                bra.s   .d
.d1:            move.b  #' ',(a0)+
                rts

; prof_save : writes RICK3D.LOG (Z = 1 : ok)
prof_save:
                movem.l d0-d2/a0-a2,-(sp)
                tst.w   pr_run
                beq.s   .err
                clr.w   -(sp)                   ; Fcreate
                pea     pr_fname
                move.w  #$3c,-(sp)
                trap    #1
                addq.l  #8,sp
                tst.l   d0
                bmi.s   .err
                move.w  d0,d2
                move.l  pr_logp,d0
                sub.l   #pr_logbuf,d0
                pea     pr_logbuf               ; Fwrite
                move.l  d0,-(sp)
                move.w  d2,-(sp)
                move.w  #$40,-(sp)
                trap    #1
                lea     12(sp),sp
                move.w  d2,-(sp)                ; Fclose
                move.w  #$3e,-(sp)
                trap    #1
                addq.l  #4,sp
                moveq   #0,d0
                bra.s   .x
.err:           moveq   #1,d0
.x:             movem.l (sp)+,d0-d2/a0-a2
                rts

; L key : writes the log now (message in the text bar)
prof_logkey:
                bsr     prof_save
                bne.s   .e
                move.l  #pr_tok,msg_ptr
                bra.s   .m
.e:             move.l  #pr_terr,msg_ptr
.m:             move.w  #MSG_DUR,msg_t
                rts

; prof_lines : the 2 lines of the text bar (a0 = linebuf)
prof_lines:
                movem.l d2-d3/a2-a3,-(sp)
                lea     pr_names,a2
                lea     pr_show,a3
                moveq   #0,d3                   ; column
                moveq   #PR_NSEC+2-1,d2
.l:             cmp.w   #6,d3                   ; 6 values per line
                bne.s   .s
                lea     linebuf+LINEW,a0
.s:             move.l  a0,-(sp)
                move.l  a2,a1
                bsr     puts
                addq.l  #5,a2
                move.w  (a3)+,d0
                bsr     fmtnum
                bsr     puts
                move.l  (sp)+,a0
                addq.l  #7,a0                   ; 7 characters per value
                addq.w  #1,d3
                dbra    d2,.l
                movem.l (sp)+,d2-d3/a2-a3
                rts

pr_names:       dc.b    'LOG ',0,'BLD ',0,'ERA ',0,'ZAP ',0,'PLT ',0,'ENM ',0
                dc.b    'RIK ',0,'LAS ',0,'OBJ ',0,'HUD ',0,'VBL ',0,'DSP ',0,'EKW ',0
pr_tlv:         dc.b    'N',0
pr_tl:          dc.b    'L',0
pr_tc:          dc.b    'C',0
pr_td:          dc.b    'D',0
pr_tmk:         dc.b    'SMK ',0                ; sprites made (32 frames)
pr_tbg:         dc.b    'BGH ',0,'BGM ',0,'BGR ',0,'BGS ',0,'MX ',0,'MY ',0
pr_tsx:         dc.b    'SX ',0
pr_tsy:         dc.b    'SY ',0
pr_tss:         dc.b    'SS ',0
pr_tfb:         dc.b    'SFB ',0                ; sprites drawn in 3D (32 frames)
pr_tfm:         dc.b    'SFM ',0                ;  reasons : 2 buckets, 4 not cached
pr_tfx:         dc.b    'SFX ',0                ;  last place (world X, Y + 1000)
pr_tfy:         dc.b    'SFY ',0
pr_fname:       dc.b    'RICK3D.LOG',0
pr_tok:         dc.b    'LOG WRITTEN : RICK3D.LOG',0
pr_terr:        dc.b    'LOG : WRITE ERROR',0
pr_head:        dc.b    'RICK3D LOG - one line every 32 frames (averages)',13,10
                dc.b    'N level, L/C Rick (map line/column), D 1 = 3D on the DSP',13,10
                dc.b    'LOG..VBL : 0.1 ms per frame (16.7 ms = 1 VGA frame) :',13,10
                dc.b    ' LOG logic, BLD rebuild, ERA erasing, ZAP beams/waves, PLT platforms,',13,10
                dc.b    ' ENM enemies, RIK Rick, LAS shots, OBJ objects, HUD hud+text, VBL spare',13,10
                dc.b    'DSP waits for the DSP per frame, EKW erased words per frame / 100',13,10,13,10,0
                even

                endc
