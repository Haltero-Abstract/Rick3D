;=====================================================================
; INIT.S - START, MAIN LOOP AND EXIT
;   (included by RICK3D.S ; the settings are in PARAMS.S)
;=====================================================================

start:
                move.l  4(sp),a5                ; Mshrink
                move.l  12(a5),d0
                add.l   20(a5),d0
                add.l   28(a5),d0
                add.l   #$1100,d0               ; basepage + stack
                move.l  a5,d1
                add.l   d0,d1
                and.l   #-2,d1
                move.l  d1,sp
                move.l  d0,-(sp)
                move.l  a5,-(sp)
                clr.w   -(sp)
                move.w  #$4a,-(sp)
                trap    #1
                lea     12(sp),sp

                ; welcome page : title, credits, keys (ACCUEIL.S)
                jsr     infopage
                tst.w   d0
                bpl.s   .jeu
                clr.w   -(sp)                   ; ESC : Pterm0
                trap    #1
.jeu:
                ; 6x6 TOS system font (Line-A)
                dc.w    $a000
                move.l  (a1),a1                 ; 1st font = 6x6
                move.w  36(a1),fontfirst
                move.l  72(a1),fontoff
                move.l  76(a1),fontdat
                move.w  80(a1),fontw
                dc.w    $a00a                   ; hides the mouse

                clr.l   -(sp)                   ; Super
                move.w  #$20,-(sp)
                trap    #1
                addq.l  #6,sp
                move.l  d0,old_ssp

                move.w  #89,-(sp)               ; mon_type
                trap    #14
                addq.l  #2,sp
                tst.w   d0
                beq     exit_mono
                move.w  #$0024,new_mode         ; RGB/TV : 320x200 TC PAL
                move.l  #40*LINEB,phys_off      ; lines 40..239 are shown
                move.w  #TXT_YV,txt_y
                cmp.w   #2,d0
                bne.s   .rgb
                move.w  #$0114,new_mode         ; VGA : 320x240 TC full screen
                clr.l   phys_off
                move.w  #TXT_YV,txt_y
.rgb:
                clr.w   clip_y0                 ; vertical clipping : everything
                move.w  #SCR_H-1,clip_y1
                move.w  #-1,-(sp)               ; VsetMode(-1)
                move.w  #88,-(sp)
                trap    #14
                addq.l  #4,sp
                move.w  d0,old_mode
                move.w  #2,-(sp)                ; Physbase
                trap    #14
                addq.l  #2,sp
                move.l  d0,old_phys
                move.w  #3,-(sp)                ; Logbase
                trap    #14
                addq.l  #2,sp
                move.l  d0,old_log

                ; saves the Falcon palette and the ST palette
                pea     old_pal
                move.w  #256,-(sp)
                clr.w   -(sp)
                move.w  #94,-(sp)               ; VgetRGB
                trap    #14
                lea     10(sp),sp
                movem.l $ffff8240.w,d0-d7
                movem.l d0-d7,old_stpal

                ; 2 screens in ST-RAM
                clr.w   -(sp)
                move.l  #2*SCRSZ+256,-(sp)
                move.w  #$44,-(sp)              ; Mxalloc
                trap    #1
                addq.l  #8,sp
                tst.l   d0
                beq     exit_nomem
                move.l  d0,scr_mem
                add.l   #255,d0
                clr.b   d0
                move.l  d0,scr0
                add.l   #SCRSZ,d0
                move.l  d0,scr1

                move.l  scr0,a0                 ; clears the 2 screens
                move.w  #2*SCRSZ/16-1,d0
                moveq   #0,d1
.clr:           move.l  d1,(a0)+
                move.l  d1,(a0)+
                move.l  d1,(a0)+
                move.l  d1,(a0)+
                dbra    d0,.clr

                move.l  scr0,d0                 ; Setscreen(log,phys,3,mode)
                add.l   phys_off,d0
                move.w  new_mode,-(sp)
                move.w  #3,-(sp)
                move.l  d0,-(sp)
                move.l  scr1,-(sp)
                move.w  #5,-(sp)
                trap    #14
                lea     14(sp),sp

                ; keyboard + joystick : our own ACIA interrupt
                move.w  #$2700,sr
                move.l  $118.w,old_acia
                move.l  #my_acia,$118.w
                jsr     prof_install            ; Timer D : profiler clock (key T)
                move.w  #$2300,sr
                pea     ikbd_joy
                clr.w   -(sp)
                move.w  #25,-(sp)               ; Ikbdws
                trap    #14
                addq.l  #8,sp

                ; music : ZIK\*.MOD + DSP replay
                bsr     scanmods
                move.w  #-1,curmod
                move.w  #MUS_VOL_INIT,mastervol
                bsr     dspinit
                bsr     sfx_init                ; YM put back in the sound output
                bsr     nextmod                 ; 1st module (alphabetical)

                move.l  $4ba.w,fpsclk           ; frames per second counter
                clr.w   fpscnt
                clr.w   fps

                move.w  #1,cur_back             ; scr0 shown, we draw in scr1
                jsr     ts_backup               ; built-in tile set (for each level)
                jsr     kt_init                 ; keyboard tables (name entry)
                bsr     save_read               ; RICK3D.SAV : position + high scores
                jmp     game_menu               ; level menu, then the level (MENUS.S)

;---------------------------------------------------------------------
main_loop:
                PROF    PR_VBL                  ; (profiler : end of the frame)
                tst.w   game_end                ; game over / end of the level :
                beq.s   .nge                    ;  name, high scores, menu
                jmp     end_game
.nge:
                bsr     do_keys
                tst.w   quit_flag
                bne     quit
                tst.w   view_back               ; back view : still picture
                bne     vb_loop                 ;  (test, game paused)
                bsr     update_plats
                bsr     update_rick
                bsr     update_objs
                bsr     update_enemies
                bsr     update_lasers
                PROF    PR_LOG
                tst.w   need_rebuild
                bne.s   .rb
                tst.w   items_dirty             ; canister picked up : scenery to rebuild
                beq.s   .nr
                clr.w   items_dirty             ; (plates broken : only their
                jsr     bg_dirty                ;  area, in the background)
                beq.s   .nr
.rb:            clr.w   items_dirty
                move.w  sc_glide,d0             ; step : keep the old
                or.w    sc_vglide,d0            ;  scenery for the scrolling
                beq.s   .rb1
                bsr     keep_old
.rb1:           bsr     build_screen
                move.w  sc_glide,d0
                or.w    sc_vglide,d0
                beq.s   .nr
                bsr     glide
                clr.w   sc_glide
                clr.w   sc_vglide
.nr:            PROF    PR_BLD
                bsr     back_ptrs
                tst.w   L_FULL(a4)              ; new scenery : the whole screen
                beq.s   .np
                clr.w   L_FULL(a4)
                bsr     erase_full
                bra.s   .nb1
.np:            move.w  L_YMAX(a4),d0           ; old drawings on the bar ?
                cmp.w   txt_y,d0
                blt.s   .nb0
                clr.w   (a3)                    ; -> text to redraw
.nb0:           cmp.w   #HUD_H,L_YMIN(a4)       ; ... or on the HUD ?
                bge.s   .nb1e
                clr.w   (a5)
.nb1e:          bsr     erase_list
                jsr     spr_erase               ; cached sprites : their spans
.nb1:           move.l  a4,cur_list             ; new list of rectangles
                clr.w   L_CNT(a4)
                clr.w   L_SN(a4)
                move.w  #32767,L_YMIN(a4)
                move.w  #-32768,L_YMAX(a4)
                move.w  #HUD_H,clip_y0          ; moving objects : never on the
                move.w  #SCR_H-1,clip_y1        ;  HUD nor on the text bar
                tst.w   txt_hidden              ;  (more text to redraw
                bne.s   .cl                     ;   -> more jerkiness)
                move.w  txt_y,d0
                subq.w  #1,d0
                move.w  d0,clip_y1
.cl:            PROF    PR_ERA
                bsr     bb_reset
                move.w  #1,spr_rec              ; (cached sprites : noted)
                bsr     draw_zaps               ; (behind Rick)
                PROF    PR_ZAP
                bsr     draw_plats
                PROF    PR_PLT
                bsr     draw_enemies
                PROF    PR_ENM
                bsr     draw_rick
                bsr     bb_push
                PROF    PR_RIK
                bsr     draw_lasers
                PROF    PR_LAS
                bsr     draw_objs
                PROF    PR_OBJ
                clr.w   spr_rec
                clr.w   clip_y0                 ; scenery : the whole screen
                move.w  #SCR_H-1,clip_y1
                bsr     back_ptrs
                move.w  L_YMAX(a4),d0           ; new drawings on the bar ?
                cmp.w   txt_y,d0
                blt.s   .nb2
                clr.w   (a3)
.nb2:           cmp.w   #HUD_H,L_YMIN(a4)       ; ... or on the HUD ?
                bge.s   .nb3
                clr.w   (a5)
.nb3:           bsr     hud_update
                bsr     back_ptrs
                bsr     text_update
                PROF    PR_HUD
                jsr     bg_run                  ; next screen in the background
                PROF    PR_BLD                  ;  (with the time left in the frame)
                bsr     flip
                jsr     bg_fmark                ; (start of the frame : time)
                bsr     countfps
                bsr     sfx_update              ; YM sound effects (1 step / frame)
                tst.b   MGTK_Restart_Done       ; end of the module : next one
                beq.s   .ne
                sf      MGTK_Restart_Done
                bsr     nextmod
.ne:            bra     main_loop

;---------------------------------------------------------------------
; back view (test) : the game is paused, the built picture is shown
vb_loop:
                move.l  $466.w,d0               ; constant game speed :
                move.l  d0,d1                   ;  as many game steps as
                sub.l   bv_clk,d1               ;  screen frames (VBL) passed
                move.l  d0,bv_clk               ;  since the last time
                tst.w   bv_in
                bne.s   .s0
                moveq   #1,d1                   ; (when entering : one step)
.s0:            tst.l   d1
                bgt.s   .s1
                moveq   #1,d1
.s1:            cmp.l   #BV_MAXSTEP,d1          ; (too slow : limited)
                ble.s   .s2
                moveq   #BV_MAXSTEP,d1
.s2:            move.w  d1,bv_steps
.step:          bsr     update_plats            ; the game goes on
                bsr     update_rick
                bsr     update_objs
                bsr     update_enemies
                bsr     update_lasers
                bsr     sfx_update
                subq.w  #1,bv_steps
                bne.s   .step
                tst.w   need_rebuild            ; new screen (or entering) : the
                beq.s   .nb                     ;  side scenery must be rebuilt
                clr.w   need_rebuild            ;  when leaving
                clr.w   items_dirty
                move.w  #1,rlist0+L_FULL
                move.w  #1,rlist1+L_FULL
                tst.w   bv_in
                bne.s   .nb
                move.w  #1,bv_in                ; entering the back view :
                clr.w   txts0                   ;  text and HUD to redraw
                clr.w   txts1                   ;  (once per screen)
                clr.w   huds0
                clr.w   huds1
                move.w  #2,bv_clr               ; clear everything (2 screens)
.nb:            bsr     back_ptrs               ; direct drawing in the hidden screen
                clr.w   L_CNT(a4)
                bsr     bb_reset
                move.w  #CY-BV_BAND/2,clip_y0   ; middle band only
                move.w  #CY+BV_BAND/2-1,clip_y1
                bsr     build_back
                clr.w   bvx_on                  ; (extents : end of drawing)
                clr.w   clip_y0
                move.w  #SCR_H-1,clip_y1
                bsr     hud_update
                bsr     back_ptrs
                bsr     text_update
                bsr     flip
                bsr     countfps
                tst.b   MGTK_Restart_Done
                beq.s   .ne
                sf      MGTK_Restart_Done
                bsr     nextmod
.ne:            bra     main_loop

;---------------------------------------------------------------------
quit:
                pea     ikbd_mouse              ; puts the mouse back
                clr.w   -(sp)
                move.w  #25,-(sp)
                trap    #14
                addq.l  #8,sp
                move.w  #$2700,sr
                move.l  old_acia,$118.w
                jsr     prof_remove
                move.w  #$2300,sr
                jsr     prof_save               ; RICK3D.LOG (profiler)
.flush:         move.w  #11,-(sp)               ; empties the keyboard buffer
                trap    #1
                addq.l  #2,sp
                tst.w   d0
                beq.s   .flushed
                move.w  #7,-(sp)
                trap    #1
                addq.l  #2,sp
                bra.s   .flush
.flushed:
                bsr     sfx_off                 ; YM silent
                bsr     stopmus                 ; stops the music
                bsr     freemod
                bsr     dspexit                 ; original sound system

                move.w  old_mode,-(sp)
                move.w  #3,-(sp)
                move.l  old_phys,-(sp)
                move.l  old_log,-(sp)
                move.w  #5,-(sp)
                trap    #14
                lea     14(sp),sp
                move.w  #37,-(sp)               ; Vsync
                trap    #14
                addq.l  #2,sp

                pea     old_pal
                move.w  #256,-(sp)
                clr.w   -(sp)
                move.w  #93,-(sp)               ; VsetRGB
                trap    #14
                lea     10(sp),sp
                movem.l old_stpal,d0-d7
                movem.l d0-d7,$ffff8240.w

                jsr     pre_free                ; (screens built : memory back)
                move.l  scr_mem,-(sp)           ; Mfree
                move.w  #$49,-(sp)
                trap    #1
                addq.l  #6,sp
exit_nomem:
exit_mono:
                move.l  old_ssp,-(sp)
                move.w  #$20,-(sp)
                trap    #1
                addq.l  #6,sp
                dc.w    $a009                   ; shows the mouse again
                clr.w   -(sp)
                trap    #1
