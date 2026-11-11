;=====================================================================
; TEXTE.S - BOTTOM TEXT BAR (FPS, music, volume, position)
;   (included by RICK3D.S ; the settings are in PARAMS.S)
;=====================================================================

;=====================================================================
; TEXT BAR (6x6 font, white on the darkened scenery)
;   redrawn only if its contents change (cache per screen)
;=====================================================================
text_update:
                tst.w   txt_hidden
                beq.s   .show
                tst.w   (a3)                    ; hidden : the scenery is put back
                beq.s   .x
                clr.w   (a3)
                move.w  txt_y,d0
                mulu    #LINEB,d0
                lea     bgbuf,a0
                adda.l  d0,a0
                lea     (a6,d0.l),a1
                move.w  #BAND_H*LINEB/16-1,d0
.rs:            move.l  (a0)+,(a1)+
                move.l  (a0)+,(a1)+
                move.l  (a0)+,(a1)+
                move.l  (a0)+,(a1)+
                dbra    d0,.rs
.x:             rts
.show:          bsr     build_lines
                tst.w   (a3)
                beq.s   .draw
                lea     linebuf,a0              ; already shown : has it changed ?
                lea     2(a3),a1
                move.w  #2*LINEW/2-1,d0
.cmp:           cmp.w   (a0)+,(a1)+
                dbne    d0,.cmp
                beq.s   .x
                bra     draw_cells              ; only the changed characters
.draw:          lea     linebuf,a0
                lea     2(a3),a1
                move.w  #2*LINEW/2-1,d0
.cp:            move.w  (a0)+,(a1)+
                dbra    d0,.cp
                move.w  #1,(a3)
                bra     draw_band

; builds the 2 text lines in linebuf
build_lines:
                lea     linebuf,a0
                move.w  #2*LINEW-1,d0
.sp:            move.b  #' ',(a0)+
                dbra    d0,.sp
                lea     linebuf,a0
                tst.w   prof_on                 ; profiler (T) : its 2 lines
                bne     prof_lines
                lea     t_fps,a1
                bsr     puts
                move.w  fps,d0
                bsr     fmtnum
                bsr     puts
                addq.l  #2,a0
                tst.w   msg_t                   ; message (R / B) for 2 s
                beq.s   .nomsg                  ;   instead of the music
                subq.w  #1,msg_t
                move.l  msg_ptr,a1
                bsr     puts
                bra     .l2m
.nomsg:         tst.w   musok
                bne.s   .mus
                move.w  muserr,d0               ; no music : error
                lsl.w   #2,d0
                lea     errtab,a1
                move.l  (a1,d0.w),a1
                bsr     puts
                bra.s   .l2
.mus:           lea     t_music,a1
                bsr     puts
                move.w  curmod,d0
                addq.w  #1,d0
                bsr     fmtnum
                bsr     puts
                move.b  #'/',(a0)+
                move.w  nmods,d0
                bsr     fmtnum
                bsr     puts
                addq.l  #1,a0
                bsr     curname
                bsr     puts
                addq.l  #2,a0
                lea     t_vol,a1
                bsr     puts
                move.w  mastervol,d0
                bsr     fmtnum
                bsr     puts
                tst.w   paused
                beq.s   .l2
                addq.l  #2,a0
                lea     t_pause,a1
                bsr     puts
.l2:
.l2m:           tst.w   inf_lives               ; infinite lives : at the end of the line
                beq.s   .l2b
                lea     linebuf+LINEW-10,a0
                lea     t_inf,a1
                bsr     puts
.l2b:           lea     linebuf+LINEW,a0
                tst.w   lvlerr
                beq.s   .pos
                lea     t_lvlerr,a1
                bra     puts
                ; Rick's position to debug the map :
                ;  X / Y  = tile (column / row) under the middle of the feet
                ;  MAP L / C = line / column of this character in the .MAP
                ;  FLOOR  = character of the tile just under the feet
                ;  SCREEN = tile of the top-left corner of the screen
.pos:           move.w  rick_xf,d4
                asr.w   #3,d4
                addq.w  #RICK_W/2,d4
                asr.w   #3,d4                   ; d4 = column
                move.w  rick_yf,d5
                asr.w   #3,d5
                add.w   rk_h,d5
                subq.w  #1,d5
                asr.w   #3,d5                   ; d5 = row of the feet
                lea     t_px,a1
                bsr     puts
                move.w  d4,d0
                bsr     fmtnum
                bsr     puts
                lea     t_py,a1
                bsr     puts
                move.w  d5,d0
                bsr     fmtnum
                bsr     puts
                lea     t_pl,a1
                bsr     puts
                move.w  d5,d0
                add.w   hdr_lines,d0
                addq.w  #1,d0
                bsr     fmtnum
                bsr     puts
                lea     t_pc,a1
                bsr     puts
                move.w  d4,d0
                addq.w  #1,d0
                bsr     fmtnum
                bsr     puts
                lea     t_psol,a1
                bsr     puts
                movem.l d0-d1,-(sp)
                move.w  d4,d0
                move.w  d5,d1
                addq.w  #1,d1
                bsr     tile_at
                movem.l (sp)+,d0-d1
                tst.w   rick_onplat             ; on a moving platform : P
                bmi.s   .sol
                moveq   #'P',d2
.sol:           move.b  d2,(a0)+
                lea     t_pscr,a1
                bsr     puts
                move.w  win_tx,d0
                bsr     fmtnum
                bsr     puts
                move.b  #',',(a0)+
                move.w  win_ty,d0
                bsr     fmtnum
                bra     puts

; copies the string a1 (without the final 0) to a0
puts:           move.b  (a1)+,d0
                beq.s   .x
                move.b  d0,(a0)+
                bra.s   puts
.x:             rts

; d0.w -> decimal digits, a1 = start of the string (end = 0)
fmtnum:
                lea     numbuf+8,a1
                clr.b   (a1)
                and.l   #$ffff,d0
.d:             divu    #10,d0
                swap    d0
                add.b   #'0',d0
                move.b  d0,-(a1)
                clr.w   d0
                swap    d0
                tst.w   d0
                bne.s   .d
                rts

; draws the bar in the screen a6 : darkened scenery + white text
draw_band:
                movem.l d0-d7/a0-a5,-(sp)
                move.w  txt_y,d0
                mulu    #LINEB,d0
                lea     bgbuf,a0
                adda.l  d0,a0
                lea     (a6,d0.l),a1
                move.l  a1,a5                   ; top of the bar
                move.l  #$7bef7bef,d2
                move.w  #BAND_H*LINEB/4-1,d0
.dk:            move.l  (a0)+,d1                ; colour / 2 (2 pixels)
                lsr.l   #1,d1
                and.l   d2,d1
                move.l  d1,(a1)+
                dbra    d0,.dk
                lea     linebuf,a2
                lea     LINEB+2(a5),a4          ; line 1 : y+1, x=1
                bsr.s   .line
                lea     linebuf+LINEW,a2
                lea     8*LINEB+2(a5),a4        ; line 2 : y+8
                bsr.s   .line
                movem.l (sp)+,d0-d7/a0-a5
                rts
.line:          moveq   #COLS-1,d7
.ch:            moveq   #0,d0
                move.b  (a2)+,d0
                cmp.w   #' ',d0
                bls.s   .nc
                sub.w   fontfirst,d0
                bmi.s   .nc
                add.w   d0,d0
                move.l  fontoff,a1
                move.w  (a1,d0.w),d3            ; x of the character (bits)
                move.w  d3,d0
                lsr.w   #3,d0
                move.l  fontdat,a1
                adda.w  d0,a1
                and.w   #7,d3
                move.l  a4,a3
                moveq   #5,d4                   ; 6 lines
.fl:            move.b  (a1),d2
                lsl.w   #8,d2
                move.b  1(a1),d2
                lsl.w   d3,d2
                moveq   #5,d5                   ; 6 pixels : bits 15..10
                move.l  a3,a0
.pb:            add.w   d2,d2
                bcc.s   .p0
                move.w  #$ffff,(a0)
.p0:            addq.l  #2,a0
                dbra    d5,.pb
                lea     LINEB(a3),a3
                adda.w  fontw,a1
                dbra    d4,.fl
.nc:            lea     12(a4),a4               ; next column (6 pixels)
                dbra    d7,.ch
                rts

; draw_cells : the bar is already shown (a3 = its state) : only the
;   characters that changed are redrawn (darkened scenery + character)
draw_cells:
                movem.l d0-d7/a0-a5,-(sp)
                move.w  txt_y,d0
                mulu    #LINEB,d0
                move.l  d0,d6                   ; d6 = offset of the bar
                lea     linebuf,a2
                lea     2(a3),a5
                moveq   #0,d7
.lp:            move.b  (a2,d7.w),d0
                cmp.b   (a5,d7.w),d0
                beq     .nx
                move.b  d0,(a5,d7.w)
                move.w  d7,d1                   ; column, line
                move.l  #LINEB+2,d2             ; line 1 : y+1
                cmp.w   #LINEW,d1
                blo.s   .l1
                sub.w   #LINEW,d1
                move.l  #8*LINEB+2,d2           ; line 2 : y+8
.l1:            cmp.w   #COLS,d1
                bhs     .nx
                mulu    #12,d1
                add.l   d1,d2
                add.l   d6,d2                   ; offset of the cell
                lea     bgbuf,a0
                adda.l  d2,a0
                lea     (a6,d2.l),a4
                move.l  a4,a1
                move.l  #$7bef7bef,d3
                moveq   #6,d4                   ; 7 lines x 6 pixels
.dk:            move.l  (a0),d1
                lsr.l   #1,d1
                and.l   d3,d1
                move.l  d1,(a1)
                move.l  4(a0),d1
                lsr.l   #1,d1
                and.l   d3,d1
                move.l  d1,4(a1)
                move.l  8(a0),d1
                lsr.l   #1,d1
                and.l   d3,d1
                move.l  d1,8(a1)
                lea     LINEB(a0),a0
                lea     LINEB(a1),a1
                dbra    d4,.dk
                moveq   #0,d0                   ; character
                move.b  (a5,d7.w),d0
                cmp.w   #' ',d0
                bls.s   .nx
                sub.w   fontfirst,d0
                bmi.s   .nx
                add.w   d0,d0
                move.l  fontoff,a1
                move.w  (a1,d0.w),d3
                move.w  d3,d0
                lsr.w   #3,d0
                move.l  fontdat,a1
                adda.w  d0,a1
                and.w   #7,d3
                moveq   #5,d4
.fl:            move.b  (a1),d2
                lsl.w   #8,d2
                move.b  1(a1),d2
                lsl.w   d3,d2
                moveq   #5,d5
                move.l  a4,a0
.pb:            add.w   d2,d2
                bcc.s   .p0
                move.w  #$ffff,(a0)
.p0:            addq.l  #2,a0
                dbra    d5,.pb
                lea     LINEB(a4),a4
                adda.w  fontw,a1
                dbra    d4,.fl
.nx:            addq.w  #1,d7
                cmp.w   #2*LINEW,d7
                blo     .lp
                movem.l (sp)+,d0-d7/a0-a5
                rts
