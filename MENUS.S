;=====================================================================
; MENUS.S - LEVEL MENU, HIGH SCORES, NAME ENTRY (in the game screen)
;   game_menu : after the welcome page and after each game : choice of
;   the level, then the level is loaded and played (main_loop).
;   end_game : game over (6 lives lost) or end of the level reached :
;   name of the player if his score enters the table, high scores page,
;   then back to the level menu.
;   The 10 best scores are kept in RICK3D.SAV (with the saved position).
;   (included by RICK3D.S)
;=====================================================================

NB_LEVELS       equ     5
COL_WHITE       equ     $ffff
COL_YELLOW      equ     $ffe0
COL_GREY        equ     $6b4d
COL_RED         equ     $f9a6
COL_CYAN        equ     $5e7f

;---------------------------------------------------------------------
game_menu:
                bsr     level_menu              ; cur_level = chosen level
                tst.w   quit_flag
                bne     quit
                bsr     start_level
                jmp     main_loop

end_game:
                clr.w   view_back
                bsr     hs_enter                ; name (if the score is good enough)
                bsr     hs_page                 ; the 10 best scores
                clr.w   game_end
                clr.w   quit_flag               ; (ESC in these pages : no exit)
                bra     game_menu

;---------------------------------------------------------------------
; start_level : loads LEVEL\LEVELn.MAP (+ TILES.DAT for level 1,
;   TILESn.DAT for the others) and starts the level (new game)
start_level:
                move.w  cur_level,d0
                add.b   #'0',d0
                move.b  d0,lvlname+11           ; LEVEL\LEVELn.MAP
                move.b  d0,t_lvlerr+13
                lea     tilname,a1              ; tiles of the level
                lea     t_til1,a0
                cmp.w   #1,cur_level
                beq.s   .t1
                lea     t_tiln,a0
.t1:            move.b  (a0)+,(a1)+
                bne.s   .t1
                cmp.w   #1,cur_level
                beq.s   .t2
                move.b  d0,tilname+11           ; LEVEL\TILESn.DAT
.t2:            lea     tsdef,a0                ; built-in tile set back (the
                lea     tileset,a1              ;  previous level may have
                move.l  #TILESET_SZ-1,d1        ;  replaced it)
.cp:            move.b  (a0)+,(a1)+
                subq.l  #1,d1
                bpl.s   .cp
                bsr     load_tiles
                bsr     load_level
                jsr     spr_flush               ; new models / colours : sprites again
                jsr     pre_load                ; all the screens built (PREBUILD.S)
                move.w  cur_level,d0            ; name in the HUD
                subq.w  #1,d0
                mulu    #12,d0
                lea     lvnames,a0
                adda.w  d0,a0
                lea     t_lvlname,a1
.nm:            move.b  (a0)+,(a1)+
                bne.s   .nm
                clr.w   game_end
                clr.w   end_t
                bsr     level_start
                bsr     sv_apply                ; saved position of this level
                move.w  #1,rlist0+L_FULL        ; everything redrawn
                move.w  #1,rlist1+L_FULL
                clr.w   txts0
                clr.w   txts1
                clr.w   huds0
                clr.w   huds1
                move.w  #1,need_rebuild
                rts

; sv_apply : the position saved with R is used only in its own level
sv_apply:
                clr.w   sv_ok
                move.w  cur_level,d0
                cmp.w   savbuf+6,d0
                bne.s   .x
                move.w  savbuf+8,sv_ok
                move.w  savbuf+10,sv_x
                move.w  savbuf+12,sv_feet
.x:             rts

; ts_backup : copy of the built-in tile set (before the 1st TILES.DAT)
ts_backup:
                lea     tileset,a0
                lea     tsdef,a1
                move.l  #TILESET_SZ-1,d1
.cp:            move.b  (a0)+,(a1)+
                subq.l  #1,d1
                bpl.s   .cp
                rts

; kt_init : keyboard tables of the TOS (letters of the name)
kt_init:
                move.l  #-1,-(sp)
                move.l  #-1,-(sp)
                move.l  #-1,-(sp)
                move.w  #16,-(sp)               ; Keytbl
                trap    #14
                lea     14(sp),sp
                move.l  d0,a0
                move.l  (a0),kt_unsh
                move.l  4(a0),kt_shift
                rts

; key2ascii : d0 = scancode -> d0 = character (A-Z 0-9 space - .), 0 = none
key2ascii:
                movem.l d1/a0,-(sp)
                cmp.w   #$39,d0                 ; space
                beq.s   .sp
                and.w   #$7f,d0
                move.l  kt_unsh,a0
                move.b  (a0,d0.w),d1
                cmp.b   #'a',d1
                blo.s   .n1
                cmp.b   #'z',d1
                bhi.s   .n1
                sub.b   #32,d1                  ; upper case
                bra.s   .ok
.n1:            cmp.b   #'A',d1
                blo.s   .n2
                cmp.b   #'Z',d1
                bls.s   .ok
.n2:            cmp.b   #'0',d1
                blo.s   .n3
                cmp.b   #'9',d1
                bls.s   .ok
.n3:            cmp.b   #'-',d1
                beq.s   .ok
                cmp.b   #'.',d1
                beq.s   .ok
                move.l  kt_shift,a0             ; AZERTY : digits with shift
                move.b  (a0,d0.w),d1
                cmp.b   #'0',d1
                blo.s   .no
                cmp.b   #'9',d1
                bls.s   .ok
.no:            moveq   #0,d0
                bra.s   .x
.sp:            moveq   #' ',d1
.ok:            moveq   #0,d0
                move.b  d1,d0
.x:             movem.l (sp)+,d1/a0
                rts

keyflush:       move.w  keyw,keyr
                move.b  joy1,mj_prev
                rts

; mjoy : joystick (port 1) : d1 = bits pressed since the last call
;   (0 up, 1 down, 7 fire)
mjoy:
                move.b  joy1,d1
                move.b  mj_prev,d2
                move.b  d1,mj_prev
                not.b   d2
                and.b   d2,d1
                rts

;---------------------------------------------------------------------
; level_menu : choice of the level (only the levels whose .MAP exists)
level_menu:
                bsr     lv_scan
                move.w  cur_level,d0
                lea     lvok,a0
                tst.b   (a0,d0.w)
                bne.s   .s
                move.w  #1,cur_level
.s:             bsr     keyflush
.lp:            bsr     page_clear
                lea     t_mtitle,a2
                move.w  #COL_YELLOW,d6
                moveq   #3,d7
                moveq   #22,d1
                bsr     put_center
                moveq   #1,d5                   ; the 5 levels
.ln:            lea     lvline,a1
                move.b  #' ',(a1)
                move.b  #' ',1(a1)
                cmp.w   cur_level,d5
                bne.s   .l1
                move.b  #'>',(a1)
.l1:            move.b  d5,d0
                add.b   #'0',d0
                move.b  d0,2(a1)
                move.b  #' ',3(a1)
                move.b  #' ',4(a1)
                move.w  d5,d0
                subq.w  #1,d0
                mulu    #12,d0
                lea     lvmenu,a0
                adda.w  d0,a0
                lea     5(a1),a1
.l2:            move.b  (a0)+,(a1)+
                bne.s   .l2
                move.w  #COL_WHITE,d6
                cmp.w   cur_level,d5
                bne.s   .l3
                move.w  #COL_YELLOW,d6
.l3:            lea     lvok,a0
                tst.b   (a0,d5.w)
                bne.s   .l4
                move.w  #COL_GREY,d6
.l4:            lea     lvline,a2
                moveq   #2,d7
                move.w  #40,d0
                move.w  d5,d1
                mulu    #24,d1
                add.w   #46,d1
                bsr     put_textc
                addq.w  #1,d5
                cmp.w   #NB_LEVELS,d5
                bls     .ln
                lea     t_msoon,a2              ; legend
                move.w  #COL_GREY,d6
                moveq   #1,d7
                move.w  #186,d1
                bsr     put_center
                lea     t_mhelp1,a2
                move.w  #COL_CYAN,d6
                move.w  #204,d1
                bsr     put_center
                lea     t_mhelp2,a2
                move.w  #216,d1
                bsr     put_center
                bsr     flip
                tst.w   quit_flag               ; ESC : back to the desktop
                bne     .x
                bsr     mjoy
                btst    #7,d1
                bne     .go
                btst    #0,d1
                bne.s   .up
                btst    #1,d1
                bne.s   .dn
                bsr     getkey
                tst.w   d0
                bmi     .lp
                cmp.w   #$48,d0
                beq.s   .up
                cmp.w   #$50,d0
                beq.s   .dn
                cmp.w   #$39,d0                 ; space
                beq     .go
                cmp.w   #$1c,d0                 ; return
                beq     .go
                cmp.w   #$72,d0                 ; enter
                beq     .go
                cmp.w   #$1f,d0                 ; S : high scores
                beq.s   .sc
                cmp.w   #$02,d0                 ; 1..5
                blo     .lp
                cmp.w   #$01+NB_LEVELS,d0
                bhi     .lp
                subq.w  #1,d0
                lea     lvok,a0
                tst.b   (a0,d0.w)
                beq     .lp
                move.w  d0,cur_level
                bra.s   .go
.up:            move.w  cur_level,d0
.u1:            subq.w  #1,d0
                beq     .lp
                lea     lvok,a0
                tst.b   (a0,d0.w)
                beq.s   .u1
                move.w  d0,cur_level
                bra     .lp
.dn:            move.w  cur_level,d0
.d1:            addq.w  #1,d0
                cmp.w   #NB_LEVELS,d0
                bhi     .lp
                lea     lvok,a0
                tst.b   (a0,d0.w)
                beq.s   .d1
                move.w  d0,cur_level
                bra     .lp
.sc:            move.w  #-1,hs_rank
                bsr     hs_page
                clr.w   quit_flag
                bsr     keyflush
                bra     .lp
.go:            move.w  cur_level,d0
                lea     lvok,a0
                tst.b   (a0,d0.w)
                beq     .lp
.x:             rts

; lv_scan : lvok[n] = 1 if LEVEL\LEVELn.MAP exists
lv_scan:
                moveq   #1,d5
.l:             move.b  d5,d0
                add.b   #'0',d0
                move.b  d0,lvlname+11
                lea     lvok,a0
                clr.b   (a0,d5.w)
                clr.w   -(sp)                   ; Fopen
                pea     lvlname
                move.w  #$3d,-(sp)
                trap    #1
                addq.l  #8,sp
                tst.l   d0
                bmi.s   .n
                move.w  d0,-(sp)                ; Fclose
                move.w  #$3e,-(sp)
                trap    #1
                addq.l  #4,sp
                lea     lvok,a0
                move.b  #1,(a0,d5.w)
.n:             addq.w  #1,d5
                cmp.w   #NB_LEVELS,d5
                bls.s   .l
                rts

;---------------------------------------------------------------------
; hs_enter : the score enters the table -> the player types his name
hs_enter:
                move.w  #-1,hs_rank
                move.l  score,d0
                beq     .x
                lea     savbuf+14,a0            ; rank : 1st score lower
                moveq   #0,d1
.f:             cmp.l   8(a0),d0
                bhi.s   .fd
                lea     12(a0),a0
                addq.w  #1,d1
                cmp.w   #SV_NSC,d1
                blo.s   .f
                bra     .x                      ; not good enough
.fd:            move.w  d1,hs_rank
                clr.w   nm_len
                clr.b   nm_buf
                bsr     keyflush
                clr.w   quit_flag
.lp:            bsr     page_clear
                lea     t_gover,a2
                move.w  #COL_RED,d6
                cmp.w   #2,game_end
                bne.s   .t
                lea     t_wdone,a2
                move.w  #COL_YELLOW,d6
.t:             moveq   #3,d7
                moveq   #26,d1
                bsr     put_center
                lea     t_yscore,a1             ; YOUR SCORE 001234
                lea     hs_line,a0
.c1:            move.b  (a1)+,(a0)+
                bne.s   .c1
                subq.l  #1,a0
                move.l  score,d0
                bsr     fmtscore
.c2:            move.b  (a1)+,(a0)+
                bne.s   .c2
                lea     hs_line,a2
                move.w  #COL_WHITE,d6
                moveq   #2,d7
                moveq   #76,d1
                bsr     put_center
                lea     t_newhs,a2
                move.w  #COL_CYAN,d6
                move.w  #108,d1
                bsr     put_center
                lea     t_yname,a2
                move.w  #COL_WHITE,d6
                moveq   #1,d7
                move.w  #136,d1
                bsr     put_center
                lea     nm_buf,a0               ; the name + cursor
                lea     hs_line,a1
                moveq   #7,d2
.c3:            move.b  (a0)+,d0
                beq.s   .c4
                move.b  d0,(a1)+
                dbra    d2,.c3
                bra.s   .c5
.c4:            move.b  #'_',(a1)+              ; free places
                subq.l  #1,a0
                dbra    d2,.c4
.c5:            clr.b   (a1)
                move.w  nm_len,d0               ; blinking cursor
                cmp.w   #8,d0
                bhs.s   .c6
                btst    #4,$469.w               ; (_vbclock)
                beq.s   .c6
                lea     hs_line,a1
                move.b  #' ',(a1,d0.w)
.c6:            lea     hs_line,a2
                move.w  #COL_YELLOW,d6
                moveq   #3,d7
                move.w  #152,d1
                bsr     put_center
                lea     t_nhelp,a2
                move.w  #COL_GREY,d6
                moveq   #1,d7
                move.w  #210,d1
                bsr     put_center
                bsr     flip
                tst.w   quit_flag               ; ESC : the name as it is
                bne.s   .ok
                jsr     getkey
                tst.w   d0
                bmi     .lp
                cmp.w   #$1c,d0                 ; return / enter : ok
                beq.s   .ok
                cmp.w   #$72,d0
                beq.s   .ok
                cmp.w   #$0e,d0                 ; backspace
                bne.s   .k
                move.w  nm_len,d0
                beq     .lp
                subq.w  #1,d0
                move.w  d0,nm_len
                lea     nm_buf,a0
                clr.b   (a0,d0.w)
                bra     .lp
.k:             bsr     key2ascii
                tst.w   d0
                beq     .lp
                move.w  nm_len,d1
                cmp.w   #8,d1
                bhs     .lp
                lea     nm_buf,a0
                move.b  d0,(a0,d1.w)
                clr.b   1(a0,d1.w)
                addq.w  #1,nm_len
                bra     .lp
.ok:            clr.w   quit_flag
                tst.w   nm_len                  ; no name : RICK
                bne.s   .in
                move.l  #'RICK',nm_buf
                clr.b   nm_buf+4
.in:            move.w  #SV_NSC-2,d1            ; entries rank..8 -> one lower
                lea     savbuf+14,a0
.sh:            cmp.w   hs_rank,d1
                blt.s   .put
                move.w  d1,d0
                mulu    #12,d0
                lea     (a0,d0.w),a1
                moveq   #11,d2
.sb:            move.b  (a1,d2.w),12(a1,d2.w)
                dbra    d2,.sb
                subq.w  #1,d1
                bra.s   .sh
.put:           move.w  hs_rank,d0
                mulu    #12,d0
                lea     (a0,d0.w),a1
                lea     nm_buf,a0               ; name : 8 characters
                moveq   #7,d2
.pn:            move.b  (a0)+,d0
                bne.s   .pc
                moveq   #' ',d0
                subq.l  #1,a0
.pc:            move.b  d0,(a1)+
                dbra    d2,.pn
                move.l  score,(a1)
                bsr     save_write              ; -> RICK3D.SAV
.x:             rts

;---------------------------------------------------------------------
; hs_page : the 10 best scores (hs_rank : line in yellow, -1 = none)
hs_page:
                bsr     keyflush
                move.w  #600,hs_t               ; 12 s at most
.lp:            bsr     page_clear
                lea     t_hstitle,a2
                move.w  #COL_YELLOW,d6
                moveq   #3,d7
                moveq   #14,d1
                bsr     put_center
                moveq   #0,d5
.ln:            lea     hs_line,a1              ; " 1  NAME....  001234"
                move.w  d5,d0
                addq.w  #1,d0
                move.b  #' ',(a1)
                cmp.w   #10,d0
                blo.s   .r1
                move.b  #'1',(a1)
                sub.w   #10,d0
.r1:            add.b   #'0',d0
                move.b  d0,1(a1)
                move.b  #' ',2(a1)
                move.b  #' ',3(a1)
                lea     4(a1),a1
                move.w  d5,d0
                mulu    #12,d0
                lea     savbuf+14,a0
                adda.w  d0,a0
                moveq   #7,d2
.nm:            move.b  (a0)+,(a1)+
                dbra    d2,.nm
                move.b  #' ',(a1)+
                move.b  #' ',(a1)+
                move.l  (a0),d0
                move.l  a1,-(sp)
                bsr     fmtscore
                move.l  (sp)+,a0
.cs:            move.b  (a1)+,(a0)+
                bne.s   .cs
                lea     hs_line,a2
                move.w  #COL_WHITE,d6
                cmp.w   hs_rank,d5
                bne.s   .c
                move.w  #COL_YELLOW,d6
.c:             moveq   #2,d7
                move.w  d5,d1
                mulu    #16,d1
                add.w   #52,d1
                bsr     put_center
                addq.w  #1,d5
                cmp.w   #SV_NSC,d5
                blo     .ln
                lea     t_hshelp,a2
                move.w  #COL_CYAN,d6
                moveq   #1,d7
                move.w  #218,d1
                bsr     put_center
                jsr     flip
                subq.w  #1,hs_t
                beq.s   .x
                tst.w   quit_flag
                bne.s   .x
                bsr     mjoy
                btst    #7,d1
                bne.s   .x
                jsr     getkey
                tst.w   d0
                bmi     .lp
                cmp.w   #$39,d0
                beq.s   .x
                cmp.w   #$1c,d0
                beq.s   .x
                cmp.w   #$72,d0
                bne     .lp
.x:             clr.w   quit_flag
                move.w  #-1,hs_rank
                rts

;---------------------------------------------------------------------
; page_clear : hidden screen (a6) all black
page_clear:
                jsr     back_ptrs
                move.l  a6,a0
                moveq   #0,d0
                move.w  #SCRSZ/32-1,d1
.c:             move.l  d0,(a0)+
                move.l  d0,(a0)+
                move.l  d0,(a0)+
                move.l  d0,(a0)+
                move.l  d0,(a0)+
                move.l  d0,(a0)+
                move.l  d0,(a0)+
                move.l  d0,(a0)+
                dbra    d1,.c
                rts

; put_center : string a2, colour d6, size d7 (1..3), centred, line d1
put_center:
                movem.l d0/a0,-(sp)
                move.l  a2,a0
                moveq   #0,d0
.l:             tst.b   (a0)+
                beq.s   .e
                addq.w  #1,d0
                bra.s   .l
.e:             mulu    #6,d0
                mulu    d7,d0
                neg.w   d0
                add.w   #SCR_W,d0
                asr.w   #1,d0
                bpl.s   .p
                moveq   #0,d0
.p:             bsr.s   put_textc
                movem.l (sp)+,d0/a0
                rts

; put_textc : string a2 (end = 0), 6x6 font enlarged d7 times (1..3),
;   colour d6 (RGB565), at (d0, d1), screen a6
put_textc:
                movem.l d0-d7/a0-a4,-(sp)
                move.w  d7,pt_sc
                mulu    #LINEB,d1
                lea     (a6,d1.l),a4
                add.w   d0,d0
                adda.w  d0,a4
.ch:            moveq   #0,d0
                move.b  (a2)+,d0
                beq     .x
                cmp.w   #' ',d0
                bls     .nc
                sub.w   fontfirst,d0
                bmi     .nc
                add.w   d0,d0
                move.l  fontoff,a1
                move.w  (a1,d0.w),d3
                move.w  d3,d0
                lsr.w   #3,d0
                move.l  fontdat,a1
                adda.w  d0,a1
                and.w   #7,d3
                move.l  a4,a3
                moveq   #5,d4                   ; 6 lines of the character
.fl:            move.b  (a1),d2
                lsl.w   #8,d2
                move.b  1(a1),d2
                lsl.w   d3,d2
                move.w  pt_sc,d1
                subq.w  #1,d1
.sy:            move.w  d2,d5
                move.l  a3,a0
                moveq   #5,d0                   ; 6 columns
.px:            move.w  pt_sc,d7
                subq.w  #1,d7
                add.w   d5,d5
                bcc.s   .p0
.pw:            move.w  d6,(a0)+
                dbra    d7,.pw
                bra.s   .pn
.p0:            addq.w  #1,d7
                add.w   d7,d7
                adda.w  d7,a0
.pn:            dbra    d0,.px
                lea     LINEB(a3),a3
                dbra    d1,.sy
                adda.w  fontw,a1
                dbra    d4,.fl
.nc:            move.w  pt_sc,d0
                mulu    #12,d0
                adda.w  d0,a4
                bra     .ch
.x:             movem.l (sp)+,d0-d7/a0-a4
                rts

;---------------------------------------------------------------------
                section data
t_mtitle:       dc.b    'SELECT LEVEL',0
t_msoon:        dc.b    'GREY : LEVEL NOT READY YET',0
t_mhelp1:       dc.b    'UP / DOWN OR 1-5 : CHOOSE    SPACE / FIRE : PLAY',0
t_mhelp2:       dc.b    'S : HIGH SCORES    ESC : QUIT',0
t_gover:        dc.b    'GAME OVER',0
t_wdone:        dc.b    'WELL DONE !',0
t_yscore:       dc.b    'SCORE ',0
t_newhs:        dc.b    'NEW HIGH SCORE !',0
t_yname:        dc.b    'ENTER YOUR NAME',0
t_nhelp:        dc.b    'LETTERS / DIGITS   BACKSPACE : ERASE   RETURN : OK',0
t_hstitle:      dc.b    'HIGH SCORES',0
t_hshelp:       dc.b    'SPACE / FIRE : CONTINUE',0
t_til1:         dc.b    'LEVEL\TILES.DAT',0
t_tiln:         dc.b    'LEVEL\TILES0.DAT',0
                ; names in the menu (12 bytes each)
lvmenu:         dc.b    'HYDE PARK',0,0,0
                dc.b    'ICE CAVERNS',0
                dc.b    'VEGETABLIA',0,0
                dc.b    'MUD MINES',0,0,0
                dc.b    'FAT GUY HQ',0,0
                ; names in the HUD (10 characters max, 12 bytes each)
lvnames:        dc.b    'HYDE PARK',0,0,0
                dc.b    'FREEZIA',0,0,0,0,0
                dc.b    'VEGETABLIA',0,0
                dc.b    'MUD MINES',0,0,0
                dc.b    'FAT GUY HQ',0,0
                even
cur_level:      dc.w    1
hs_rank:        dc.w    -1

                section bss
tsdef:          ds.b    TILESET_SZ              ; built-in tile set (copy)
                even
kt_unsh:        ds.l    1
kt_shift:       ds.l    1
game_end:       ds.w    1                       ; 1 = game over, 2 = end of the level
pt_sc:          ds.w    1
hs_t:           ds.w    1
nm_len:         ds.w    1
nm_buf:         ds.b    10
lvok:           ds.b    NB_LEVELS+2
lvline:         ds.b    24
hs_line:        ds.b    40
mj_prev:        ds.b    1
                even
                section text
