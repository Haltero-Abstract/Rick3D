;=====================================================================
; NIVEAU.S - LEVEL : loading of the .MAP and of TILES.DAT, tiles, collisions
;   (included by RICK3D.S ; the settings are in PARAMS.S)
;=====================================================================

;---------------------------------------------------------------------
; LEVEL : global map (LEVEL\LEVEL1.MAP), tiles of 8 world units
; (1 unit = 1 pixel of the original game), screen = 32 x 24 tiles.
; Tile classes :
;   #  rock           F  metal frame           (solid)
;   .  background     k  black background      (empty)
;   =  walkway        -  bar       G  girder   (platforms : can be stood
;                                               on, passed through from below)
;   H  ladder / pole to climb
;---------------------------------------------------------------------

; tile_at : d0 = column, d1 = line (level) -> d2.l = character
;           outside the map = rock
tile_at:
                cmp.w   lev_w,d0
                bhs.s   .out
                cmp.w   lev_h,d1
                bhs.s   .out
                move.l  a0,-(sp)
                move.w  d1,d2
                mulu    lev_w,d2
                lea     levmap,a0
                adda.l  d2,a0
                moveq   #0,d2
                move.b  (a0,d0.w),d2
                move.l  (sp)+,a0
                rts
.out:           moveq   #'#',d2
                rts

; issol : d2 = character -> Z = 1 if solid block
issol:
                cmp.b   #'T',d2                 ; barrel : solid (collision)
                beq.s   .x
                cmp.b   #'O',d2                 ; stool : solid (collision)
                bne.s   isblk
.x:             rts
isblk:                                          ; scenery block (faces, patterns)
                cmp.b   #'#',d2
                beq.s   .x
                cmp.b   #'F',d2
                beq.s   .x
                cmp.b   #'B',d2                 ; plate / door to blow up
                beq.s   .x
                cmp.b   #'g',d2                 ; lawn
.x:             rts

; bcol : d6 = character of a block -> the 'B' plate takes the frame colours
bcol:           cmp.b   #'B',d6
                bne.s   .x
                moveq   #'F',d6
.x:             rts

; isladc : d2 = character -> Z = 1 if ladder (H) or pole (M)
isladc:
                cmp.b   #'H',d2
                beq.s   .x
                cmp.b   #'U',d2                 ; climbing pipe
                beq.s   .x
                cmp.b   #'M',d2
.x:             rts

; scell : d0/d1 = column/line of the SCREEN -> d2 = character
scell:
                movem.l d0-d1,-(sp)
                add.w   win_tx,d0
                add.w   win_ty,d1
                bsr     tile_at
                movem.l (sp)+,d0-d1
                rts

; solid_px : d0 = x, d1 = y (world units) -> d2 = 1 if solid (Z = 0)
solid_px:
                movem.l d0-d1,-(sp)
                asr.w   #3,d0
                asr.w   #3,d1
                bsr     tile_at
                bsr     issol
                seq     d2
                and.l   #1,d2
                movem.l (sp)+,d0-d1
                rts

; ladder_px : d0 = x, d1 = y -> Z = 1 if ladder
;   climbing pipe (U) : only its VERTICAL parts (at least 3
;   U tiles on top of each other) ; a horizontal pipe cannot be grabbed,
;   it is walked on (like in Rick Dangerous 2)
ladder_px:
                movem.l d0-d1,-(sp)
                asr.w   #3,d0
                asr.w   #3,d1
                bsr     tile_at
                cmp.b   #'U',d2
                beq.s   .pipe
                movem.l (sp)+,d0-d1
                bra     isladc
.pipe:          move.l  d3,-(sp)
                moveq   #1,d3                   ; vertical length
                move.w  d1,-(sp)
.up:            subq.w  #1,d1
                bsr     tile_at
                cmp.b   #'U',d2
                bne.s   .dn0
                addq.w  #1,d3
                cmp.w   #3,d3
                bhs.s   .yes
                bra.s   .up
.dn0:           move.w  (sp),d1
.dn:            addq.w  #1,d1
                bsr     tile_at
                cmp.b   #'U',d2
                bne.s   .no
                addq.w  #1,d3
                cmp.w   #3,d3
                blo.s   .dn
.yes:           addq.l  #2,sp
                move.l  (sp)+,d3
                movem.l (sp)+,d0-d1
                moveq   #'U',d2
                cmp.b   #'U',d2                 ; Z = 1
                rts
.no:            addq.l  #2,sp
                move.l  (sp)+,d3
                movem.l (sp)+,d0-d1
                moveq   #1,d2                   ; Z = 0
                rts

; floor_px : is the pixel row d1 a floor at x d0 ?
;   solid block : always ; platform / ladder top : only the
;   1st row of the tile, and if the tile above is not the same
;   -> d2 = 1 if floor (Z = 0)
floor_px:
                movem.l d0-d1/d3,-(sp)
                asr.w   #3,d0
                move.w  d1,d3
                asr.w   #3,d1
                bsr     tile_at
                bsr     issol
                beq.s   .yes0
                and.w   #7,d3
                bne.s   .no
                cmp.b   #'=',d2
                beq.s   .plat
                cmp.b   #'-',d2
                beq.s   .plat
                cmp.b   #'w',d2                 ; pipe that can be walked on
                beq.s   .plat
                cmp.b   #'G',d2
                beq.s   .plat
                bsr     isladc
                bne.s   .no
.plat:          move.b  d2,d3
                subq.w  #1,d1
                bsr     tile_at
                cmp.b   d3,d2
                beq.s   .no
.yes0:          moveq   #1,d2
                bra.s   .x
.no:            movem.l (sp),d0-d1              ; moving platforms ?
                bsr     plat_floor
                bra.s   .x
.yes:           moveq   #1,d2
.x:             movem.l (sp)+,d0-d1/d3
                tst.w   d2
                rts

;---------------------------------------------------------------------
; load_tiles : look of the tiles made with the editor (LEVEL\TILES.DAT) ;
;   missing or invalid -> the built-in tile set is kept
load_tiles:
                clr.w   -(sp)                   ; Fopen
                pea     tilname
                move.w  #$3d,-(sp)
                trap    #1
                addq.l  #8,sp
                tst.l   d0
                bmi     .x
                move.w  d0,d7
                pea     filebuf                 ; Fread
                move.l  #TILESET_SZ,-(sp)
                move.w  d7,-(sp)
                move.w  #$3f,-(sp)
                trap    #1
                lea     12(sp),sp
                move.l  d0,d6
                move.w  d7,-(sp)                ; Fclose
                move.w  #$3e,-(sp)
                trap    #1
                addq.l  #4,sp
                lea     filebuf,a0              ; signature
                cmp.l   #'R3DT',(a0)
                bne     .x
                move.w  4(a0),d0                ; version 1 .. 7
                beq     .x
                cmp.w   #7,d0
                bhi     .x
                lsl.w   #2,d0
                lea     ts_sizes,a1
                move.l  -4(a1,d0.w),d5          ; expected size
                lea     tileset,a1
                cmp.l   d5,d6
                bne.s   .old
                cmp.w   #4,d0                   ; version 1 : we keep our
                bne.s   .cp                     ;  header (version 2)
                addq.l  #6,a0
                addq.l  #6,a1
                subq.l  #6,d6
.cp:            move.l  d6,d1
                bra     lt_copy
                ; versions 3 to 6 made by the editor before version 7 : without
                ; the 3 colour sets of the back view (bv_rock..) -> they are skipped
.old:           cmp.w   #3*4,d0
                blo.s   .x
                sub.l   #BV_SZ,d5
                cmp.l   d5,d6
                bne.s   .x
                move.l  #BV_OFS,d1
                bsr     lt_copy
                lea     BV_SZ(a1),a1
                move.l  d6,d1
                sub.l   #BV_OFS,d1
                bra     lt_copy
.x:             rts

; lt_copy : copies d1 bytes (even) from a0 to a1 (a0, a1 move on)
lt_copy:        lsr.l   #1,d1
                subq.w  #1,d1
                bmi.s   .x
.c:             move.w  (a0)+,(a1)+
                dbra    d1,.c
.x:             rts

; loading of the level : LEVEL\LEVEL1.MAP (text)
;   ';' lines = comments, then "width height column line"
;   (Rick's start), then the map, one text line per row.
;   Missing or invalid file : small backup room + message.
load_level:
                clr.w   lvlerr
                clr.w   -(sp)                   ; Fopen
                pea     lvlname
                move.w  #$3d,-(sp)
                trap    #1
                addq.l  #8,sp
                tst.l   d0
                bmi     .fail
                move.w  d0,d7
                pea     filebuf                 ; Fread
                move.l  #FILE_MAX-1,-(sp)
                move.w  d7,-(sp)
                move.w  #$3f,-(sp)
                trap    #1
                lea     12(sp),sp
                move.l  d0,d6
                move.w  d7,-(sp)                ; Fclose
                move.w  #$3e,-(sp)
                trap    #1
                addq.l  #4,sp
                tst.l   d6
                ble     .fail
                lea     filebuf,a0
                clr.b   (a0,d6.l)               ; end of the text
.com:           cmp.b   #';',(a0)               ; comments
                bne.s   .nums
.sk:            move.b  (a0)+,d0
                beq     .fail
                cmp.b   #10,d0
                bne.s   .sk
                bra.s   .com
.nums:          bsr     readint
                move.w  d0,lev_w
                bsr     readint
                move.w  d0,lev_h
                bsr     readint
                move.w  d0,st_col
                bsr     readint
                move.w  d0,st_row
                cmp.w   #SCR_TW,lev_w           ; at least one screen
                blo     .fail
                cmp.w   #SCR_TH,lev_h
                blo     .fail
                moveq   #0,d5
                move.w  lev_w,d5
                mulu    lev_h,d5
                cmp.l   #LEV_MAX,d5
                bhi     .fail
.eol:           move.b  (a0)+,d0                ; end of the line of numbers
                beq     .fail
                cmp.b   #10,d0
                bne.s   .eol
                move.l  a0,d0                   ; lines before the map
                lea     filebuf,a1
                moveq   #0,d1
.hl:            cmp.l   d0,a1
                bhs.s   .hle
                cmp.b   #10,(a1)+
                bne.s   .hl
                addq.w  #1,d1
                bra.s   .hl
.hle:           move.w  d1,hdr_lines
                lea     levmap,a1
.rd:            move.b  (a0)+,d0
                beq.s   .short
                cmp.b   #13,d0
                beq.s   .rd
                cmp.b   #10,d0
                beq.s   .rd
                move.b  d0,(a1)+
                subq.l  #1,d5
                bne.s   .rd
                bra     parse_extras
.short:         move.b  #'#',(a1)+              ; file too short : rock
                subq.l  #1,d5
                bne.s   .short
                move.w  #-1,end_col
                clr.w   nplats
                clr.w   nsw
                clr.w   nlz
                rts
.fail:          move.w  #1,lvlerr
                move.w  #-1,end_col
                clr.w   hdr_lines
                clr.w   nplats
                clr.w   nsw
                clr.w   nlz
                move.w  #SCR_TW,lev_w           ; backup room 32 x 24
                move.w  #SCR_TH,lev_h
                move.w  #4,st_col
                move.w  #18,st_row
                lea     levmap,a1
                moveq   #0,d1
.fy:            moveq   #0,d0
.fx:            moveq   #'.',d2
                tst.w   d0
                beq.s   .fr
                tst.w   d1
                beq.s   .fr
                cmp.w   #SCR_TW-1,d0
                beq.s   .fr
                cmp.w   #SCR_TH-3,d1
                blt.s   .fp
.fr:            moveq   #'#',d2
.fp:            move.b  d2,(a1)+
                addq.w  #1,d0
                cmp.w   #SCR_TW,d0
                blt.s   .fx
                addq.w  #1,d1
                cmp.w   #SCR_TH,d1
                blt.s   .fy
                rts

; readint : a0 = text -> d0.w = next number (skips the rest)
readint:
                moveq   #0,d0
.skip:          move.b  (a0),d1
                beq.s   .x
                cmp.b   #'0',d1
                blo.s   .n
                cmp.b   #'9',d1
                bls.s   .dig
.n:             addq.l  #1,a0
                bra.s   .skip
.dig:           move.b  (a0),d1
                sub.b   #'0',d1
                bcs.s   .x
                cmp.b   #9,d1
                bhi.s   .x
                mulu    #10,d0
                ext.w   d1
                add.w   d1,d0
                addq.l  #1,a0
                bra.s   .dig
.x:             rts
