;=====================================================================
; DONNEES.S - DATA : texts, colours, patterns, sound tables
;   (included by RICK3D.S ; the settings are in PARAMS.S)
;=====================================================================

ikbd_joy:       dc.b    $14                     ; joystick in event mode
ikbd_mouse:     dc.b    $08                     ; relative mouse
                even

modmask:        dc.b    'ZIK\*.MOD',0
                even
errtab:         dc.l    e0,e1,e2,e3,e4,e5,e6,e7,e8,e9,e10,e11
e0:             dc.b    '! UNKNOWN ERROR',0
e1:             dc.b    '! CANNOT OPEN THE MODULE',0
e2:             dc.b    '! FILE TOO SMALL FOR A MODULE',0
e3:             dc.b    '! NOT ENOUGH ST-RAM FOR MODULE',0
e4:             dc.b    '! READ ERROR',0
e5:             dc.b    '! NOT ENOUGH ST-RAM FOR SOUND',0
e6:             dc.b    '! MODULE REFUSED BY MEGAPLAYER',0
e7:             dc.b    '! BAD SONG LENGTH IN MODULE',0
e8:             dc.b    '! SOUND SYSTEM ALREADY IN USE',0
e9:             dc.b    '! NO .MOD FILE IN ZIK\',0
e10:            dc.b    '! DSP NOT AVAILABLE',0
e11:            dc.b    '! DSP REPLAY NOT ANSWERING',0
t_fps:          dc.b    'FPS ',0
t_music:        dc.b    'MUSIC ',0
t_vol:          dc.b    'VOL ',0
t_pause:        dc.b    '** PAUSE **',0
t_inf:          dc.b    'INF LIVES',0
t_rec:          dc.b    'POSITION SAVED (B = GO BACK THERE)',0
t_back:         dc.b    'BACK TO THE SAVED POSITION',0
t_end:          dc.b    'WELL DONE ! END OF THE LEVEL',0
t_recerr:       dc.b    'POSITION SAVED (FILE NOT WRITTEN)',0
savname:        dc.b    'RICK3D.SAV',0
t_glon:         dc.b    'MAP SCROLLING : ON (G)',0
t_gloff:        dc.b    'MAP SCROLLING : OFF (G)',0
t_d3don:        dc.b    '3D MATHS : DSP (D)',0
t_d3doff:       dc.b    '3D MATHS : 030 (D)',0
t_preb:         dc.b    'SCREENS : ',0
t_prew:         dc.b    'PLEASE WAIT...',0
t_prec:         dc.b    'UNDER CONSTRUCTION',0
t_prenomem:     dc.b    'LOW MEMORY : SCREENS BUILT IN GAME',0
t_spron:        dc.b    'CHARACTERS : CACHED SPRITES (S)',0
t_sproff:       dc.b    'CHARACTERS : 3D DRAWING (S)',0
t_d3dno:        dc.b    'NO DSP : 3D MATHS ON THE 030',0
t_norec:        dc.b    'NO POSITION : PRESS R TO SAVE ONE',0
t_lvlname:      dc.b    'HYDE PARK',0,0,0       ; (12 bytes : MENUS.S)
t_px:           dc.b    'X',0
t_py:           dc.b    ' Y',0
t_pl:           dc.b    '  .MAP L',0
t_pc:           dc.b    ' C',0
t_psol:         dc.b    '  FLOOR ',0
t_pscr:         dc.b    '  SCREEN ',0
t_las:          dc.b    'LASER ',0
t_bomb:         dc.b    ' BOMB ',0
                even

; sound effects : voice, duration, period, step, 8.8 volume, volume step, noise
; (YM period : frequency = 125000 / period Hz)
sfx_jump:       dc.w    0,14,480,-26,13<<8,-(13<<8)/14,0   ; rising "bloop"
sfx_laser:      dc.w    1,16,28,14,15<<8,-(15<<8)/16,0     ; falling "pew"
sfx_bomb:       dc.w    2,24,0,0,11<<8,-(11<<8)/24,4       ; fuse : high hiss
sfx_boom:       dc.w    2,50,0,0,15<<8,-(15<<8)/50,31      ; explosion : low noise
sfx_zap:        dc.w    1,10,40,6,10<<8,-(10<<8)/10,0      ; saucer laser
sfx_blow:       dc.w    1,8,70,8,13<<8,-(13<<8)/8,10       ; blowpipe "pfuit" (snowballs, level 2)
sfx_poke:       dc.w    1,4,90,-10,12<<8,-(12<<8)/4,0      ; stick : small "knock"
sfx_switch:     dc.w    0,12,160,0,13<<8,-(13<<8)/12,0     ; button : beep
sfx_fall:       dc.w    2,40,180,12,15<<8,-(15<<8)/40,24   ; fall : low + noise

col_spark1:     dc.w    $FFE0,$C600,$FFF0,$A500    ; yellow spark
col_spark2:     dc.w    $FFFF,$C618,$FFFF,$A514    ; white spark
col_fire:       dc.w    $FFE0,$FD20,$FFF0,$E4A0    ; yellow
                dc.w    $FC00,$C300,$FD80,$A280    ; orange
                dc.w    $F800,$B000,$FA00,$8800    ; red
                dc.w    $FD20,$C400,$FE60,$A300    ; light orange


; RICK'S POSES. Standing box : 12 x 20 (x forwards = right, the
; mirror is done when he looks left). A part :
;   dc.w x0,x1,y0,y1,z0,z1,anim   (z around the middle of the corridor ;
;                                  negative z = towards the camera)
;   dc.l colours
; anim : 1 front leg  2 back leg  4 front arm  8 back arm
;        16/32 limb A/B of the ladder (alternate climbing), 64 = arm
; Order = drawing order (from the back towards the camera).
LEGF            equ     1
LEGB            equ     2
ARMF            equ     4
ARMB            equ     8
LADA            equ     16
LADB            equ     32
LADARM          equ     64

lvlname:        dc.b    'LEVEL\LEVEL1.MAP',0
tilname:        dc.b    'LEVEL\TILES.DAT',0,0,0,0 ; (TILESn.DAT : MENUS.S)
t_lvlerr:       dc.b    '! LEVEL\LEVEL1.MAP MISSING OR INVALID',0
                even

; colours of the scenery objects : face, side, top, bottom

; barrel : narrow at the top and bottom, bulging in the middle, 2 hoops
col_stick:      dc.w    $FDD4,$B40D,$FEF8,$9309    ; fist (arm stretched)

; HUD icons (8x8, RGB565, 0 = transparent)
ico_hat:        dc.w    $0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000
                dc.w    $0000,$0000,$8AC5,$8AC5,$8AC5,$8AC5,$0000,$0000
                dc.w    $0000,$8AC5,$8AC5,$8AC5,$8AC5,$8AC5,$8AC5,$0000
                dc.w    $0000,$8AC5,$8AC5,$8AC5,$8AC5,$8AC5,$8AC5,$0000
                dc.w    $0000,$28C1,$28C1,$28C1,$28C1,$28C1,$28C1,$0000
                dc.w    $59A2,$8AC5,$8AC5,$8AC5,$8AC5,$8AC5,$8AC5,$59A2
                dc.w    $0000,$59A2,$59A2,$59A2,$59A2,$59A2,$59A2,$0000
                dc.w    $0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000
ico_laser:      dc.w    $0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000
                dc.w    $0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000
                dc.w    $0000,$0000,$0000,$9041,$9041,$9041,$0000,$0000
                dc.w    $E0E2,$E0E2,$E0E2,$E0E2,$E0E2,$E0E2,$FF27,$FFFF
                dc.w    $E0E2,$E0E2,$E0E2,$E0E2,$E0E2,$E0E2,$FF27,$FFFF
                dc.w    $0000,$0000,$0000,$9041,$9041,$9041,$0000,$0000
                dc.w    $0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000
                dc.w    $0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000
ico_dyn:        dc.w    $0000,$0000,$0000,$0000,$FF27,$0000,$0000,$0000
                dc.w    $0000,$0000,$0000,$FF27,$FC60,$FF27,$0000,$0000
                dc.w    $0000,$0000,$0000,$0000,$28C1,$0000,$0000,$0000
                dc.w    $0000,$0000,$0000,$E0E2,$E0E2,$E0E2,$0000,$0000
                dc.w    $0000,$0000,$0000,$E0E2,$E0E2,$9041,$0000,$0000
                dc.w    $0000,$0000,$0000,$E0E2,$E0E2,$9041,$0000,$0000
                dc.w    $0000,$0000,$0000,$E0E2,$E0E2,$9041,$0000,$0000
                dc.w    $0000,$0000,$0000,$9041,$9041,$9041,$0000,$0000

; front faces of the blocks : 10x10 patterns (RGB565)

;=====================================================================
; TILE SET (look) : contiguous block, replaced by LEVEL\TILES.DAT
; if it exists (file made by OUTILS\EDITEUR.HTML, same layout)
;=====================================================================
tileset:        dc.b    'R3DT'
                dc.w    8                       ; version (8 : + enemies ; 1 without plate, 2 without objects, 3 without models, 4/5 : 13/22 models, 6 without portholes)
; front faces of the blocks : 10x10 patterns (RGB565)
pat_rock:       dc.w    $6B31,$41EA,$4A4D,$4A4D,$4A4D,$6B31,$41EA,$4A4D,$4A4D,$4A4D
                dc.w    $41EA,$4A4D,$4A4D,$4A4D,$6B31,$41EA,$4A4D,$4A4D,$4A4D,$6B31
                dc.w    $4A4D,$4A4D,$4A4D,$6B31,$41EA,$4A4D,$4A4D,$4A4D,$6B31,$41EA
                dc.w    $4A4D,$4A4D,$6B31,$41EA,$4A4D,$4A4D,$4A4D,$6B31,$41EA,$4A4D
                dc.w    $4A4D,$6B31,$41EA,$4A4D,$4A4D,$4A4D,$6B31,$41EA,$4A4D,$4A4D
                dc.w    $6B31,$41EA,$4A4D,$4A4D,$4A4D,$6B31,$41EA,$4A4D,$4A4D,$4A4D
                dc.w    $41EA,$4A4D,$4A4D,$4A4D,$6B31,$41EA,$4A4D,$4A4D,$4A4D,$6B31
                dc.w    $4A4D,$4A4D,$4A4D,$6B31,$41EA,$4A4D,$4A4D,$4A4D,$6B31,$41EA
                dc.w    $4A4D,$4A4D,$6B31,$41EA,$4A4D,$4A4D,$4A4D,$6B31,$41EA,$4A4D
                dc.w    $4A4D,$6B31,$41EA,$4A4D,$4A4D,$4A4D,$6B31,$41EA,$4A4D,$4A4D
pat_frame:      dc.w    $D6BD,$D6BD,$D6BD,$D6BD,$D6BD,$D6BD,$D6BD,$D6BD,$D6BD,$630F
                dc.w    $D6BD,$B599,$B599,$B599,$B599,$B599,$B599,$B599,$B599,$630F
                dc.w    $D6BD,$B599,$2947,$B599,$B599,$B599,$B599,$2947,$B599,$630F
                dc.w    $D6BD,$B599,$B599,$D6BD,$B599,$B599,$B599,$B599,$D6BD,$630F
                dc.w    $D6BD,$B599,$B599,$B599,$B599,$B599,$B599,$B599,$B599,$630F
                dc.w    $D6BD,$B599,$B599,$B599,$B599,$B599,$B599,$B599,$B599,$630F
                dc.w    $D6BD,$B599,$B599,$B599,$B599,$B599,$B599,$B599,$B599,$630F
                dc.w    $D6BD,$B599,$2947,$B599,$B599,$B599,$B599,$2947,$B599,$630F
                dc.w    $D6BD,$B599,$B599,$D6BD,$B599,$B599,$B599,$B599,$D6BD,$630F
                dc.w    $630F,$630F,$630F,$630F,$630F,$630F,$630F,$630F,$630F,$630F
pat_grass:      dc.w    $3D46,$5E48,$5E48,$3D46,$5E48,$5E48,$3D46,$5E48,$5E48,$3D46
                dc.w    $5E48,$5E48,$3D46,$5E48,$5E48,$3D46,$5E48,$5E48,$3D46,$5E48
                dc.w    $2CA5,$3525,$2CA5,$2CA5,$2CA5,$2CA5,$3525,$1B63,$2CA5,$2CA5
                dc.w    $2CA5,$2CA5,$2CA5,$2CA5,$3525,$1B63,$2CA5,$2CA5,$2CA5,$3525
                dc.w    $2CA5,$2CA5,$3525,$1B63,$2CA5,$2CA5,$2CA5,$3525,$2CA5,$2CA5
                dc.w    $3525,$1B63,$2CA5,$2CA5,$2CA5,$3525,$2CA5,$2CA5,$2CA5,$2CA5
                dc.w    $2CA5,$2CA5,$2CA5,$3525,$2CA5,$2CA5,$2CA5,$2CA5,$3525,$2CA5
                dc.w    $2CA5,$3525,$2CA5,$2CA5,$2CA5,$2CA5,$3525,$2CA5,$1B63,$2CA5
                dc.w    $2CA5,$2CA5,$2CA5,$2CA5,$3525,$2CA5,$1B63,$2CA5,$2CA5,$3525
                dc.w    $2CA5,$2CA5,$3525,$2CA5,$1B63,$2CA5,$2CA5,$3525,$2CA5,$2CA5
; block colours (back wall, side / top / bottom)
c_wall1         dc.w    $39CB                   ; back wall (checkerboard)
c_wall2         dc.w    $3189                   
c_rkside        dc.w    $39CA                   ; rock : side, top, bottom
c_rktop         dc.w    $62EF                   
c_rkbot         dc.w    $2947                   
c_frside        dc.w    $8414                   ; metal frame
c_frtop         dc.w    $CE5C                   
c_frbot         dc.w    $52AD                   
c_grside        dc.w    $1C64                   ; lawn
c_grtop         dc.w    $4E6A                   
c_grbot         dc.w    $0B42                   
; object colours : face, side, top, bottom
col_plat:       dc.w    $D362,$9221,$F507,$6980    ; orange walkway
col_bar:        dc.w    $AD59,$6B71,$DEFE,$528C    ; metal bar
col_gird:       dc.w    $2D45,$1363,$5E8B,$0A82    ; green girder
col_gpost:      dc.w    $2504,$1302,$3E07,$0A42    ; green post (darker)
col_pylon:      dc.w    $9EC9,$5D65,$C7AE,$4C44    ; pylon uprights (green-yellow)
col_rivet:      dc.w    $9F4D,$5E89,$BFF0,$3D07    ; rivets
col_lad:        dc.w    $E5EB,$ABC5,$FEF0,$82C2    ; ladder
col_mast:       dc.w    $9CF6,$6B6F,$C61B,$4A4B    ; pole (grey metal)
col_screw:      dc.w    $AD75,$6B6F,$CE79,$4A4B    ; lift screw
col_thread:     dc.w    $4A69,$3186,$632C,$2104    ; threads
col_barrel:     dc.w    $CB64,$9222,$E46A,$6961    ; barrel
col_ring:       dc.w    $6942,$4921,$8A43,$3100    ; hoop
col_bartop:     dc.w    $A2A3,$7982,$B30A,$5941    ; lid
col_mplat:      dc.w    $5EF7,$3D50,$8FFB,$2C2D    ; moving platform
col_switch:     dc.w    $F800,$A000,$FC10,$7800    ; button
col_glass:      dc.w    $2A79,$1953,$3B1F,$10CC    ; canister glass
col_greencan:   dc.w    $1D85,$1363,$3F0B,$0A82    ; green canister
col_bombcan:    dc.w    $9CF3,$6B4D,$BDF7,$4A49    ; bomb canister (grey)
col_redband:    dc.w    $C186,$8904,$E2CB,$6082    ; red band
col_zap:        dc.w    $5F7F,$2BBF,$AFFF,$1A1F    ; blue laser
ts_v1_end:                                     ; (end of version 1)
; plate / door to blow up with a bomb ('B')
pat_plate:      dc.w    $D6BD,$D6BD,$D6BD,$D6BD,$D6BD,$D6BD,$D6BD,$D6BD,$D6BD,$630F
                dc.w    $D6BD,$2947,$8C71,$8C71,$8C71,$8C71,$8C71,$8C71,$2947,$630F
                dc.w    $D6BD,$8C71,$7BCF,$7BCF,$7BCF,$7BCF,$7BCF,$7BCF,$8C71,$630F
                dc.w    $D6BD,$8C71,$8C71,$8C71,$8C71,$8C71,$8C71,$8C71,$8C71,$630F
                dc.w    $D6BD,$8C71,$7BCF,$7BCF,$7BCF,$7BCF,$7BCF,$7BCF,$8C71,$630F
                dc.w    $D6BD,$8C71,$8C71,$8C71,$8C71,$8C71,$8C71,$8C71,$8C71,$630F
                dc.w    $D6BD,$FE60,$2104,$FE60,$2104,$FE60,$2104,$FE60,$2104,$630F
                dc.w    $D6BD,$2104,$FE60,$2104,$FE60,$2104,$FE60,$2104,$FE60,$630F
                dc.w    $D6BD,$2947,$8C71,$8C71,$8C71,$8C71,$8C71,$8C71,$2947,$630F
                dc.w    $630F,$630F,$630F,$630F,$630F,$630F,$630F,$630F,$630F,$630F
ts_v2_end:                                     ; (end of version 2)
; version 3 : colours of the objects (bubbles, pipes, lasers) and of Rick
col_ball:       dc.w    $10A2,$0841,$2945,$0020    ; black ball (wave)
col_nozzle:     dc.w    $4A69,$3186,$8C71,$2104    ; laser nozzle (grey)
col_tip:        dc.w    $FD20,$C380,$FEE0,$9200    ; tip of the nozzle (orange)
bv_rock:        dc.w    $39CA,$4A49,$62EF,$2947    ; back view : rock (near, sides, top, bottom)
bv_frame:       dc.w    $8414,$AD55,$CE5C,$52AD    ;  metal frame
bv_grass:       dc.w    $1C64,$2D66,$4E6A,$0B42    ;  lawn
col_pipe0:      dc.w    $D6BD,$9CF7,$E73E,$8C71    ; pipe : highlight
col_pipe1:      dc.w    $9CF7,$6B4F,$B5B8,$6311    ; pipe : mid grey
col_pipe2:      dc.w    $6311,$4A2B,$7BD3,$39EB    ; pipe : shadow
col_pipe3:      dc.w    $39EB,$2945,$5290,$2104    ; pipe : deep shadow
col_laser:      dc.w    $F800,$A000,$FC10,$8000    ; bright red
col_dyn:        dc.w    $D104,$8882,$F208,$6041    ; red dynamite
col_body:       dc.w    $C58A,$83C6,$E68E,$6283    ; khaki shirt
col_legs:       dc.w    $8B07,$5984,$A3CA,$4122    ; trousers
col_head:       dc.w    $FDD4,$B40D,$FEF8,$9309    ; face
col_hat:        dc.w    $7284,$4182,$9386,$4182    ; hat
col_arm:        dc.w    $B4E8,$7B86,$D60C,$5A63    ; sleeves
col_pack:       dc.w    $6A63,$4962,$8B66,$3101    ; backpack
col_hair:       dc.w    $F508,$B365,$FE8D,$8A83    ; hair (blond-orange : Rick lost his hat in the intro)
col_eye:        dc.w    $0841,$0841,$0841,$0841    ; eye
ts_v3_end:                                     ; (end of version 3)
; version 4 : 16 8x8 drawings (RGB565) for the front face of the objects,
;   then the 3D MODELS of the objects (shapes and sizes) : 16 boxes max
;   per object, each box = x0,y0,x1,y1,z0,z1 (z around the middle of
;   the depth), colour set (index in setptr), drawing (1..16,
;   0 = none ; for Rick : high byte = animation). End : -99.
tex_data:       dcb.w   16*64,0
mdl_barrel:    ; Barrel (2x2 tiles)
                dc.w    3,0,13,16,-5,5,10,0
                dc.w    2,1,14,15,-6,6,10,0
                dc.w    1,3,15,13,-7,7,10,0
                dc.w    1,4,15,5,-8,8,11,0
                dc.w    1,11,15,12,-8,8,11,0
                dc.w    4,0,12,1,-4,4,12,0
                dc.w    -99
                dcb.w   79,0
mdl_stoolseat: ; Stool : seat
                dc.w    0,0,8,4,-5,5,0,0
                dc.w    -99
                dcb.w   119,0
mdl_stoolfoot: ; Stool : foot
                dc.w    5,0,8,8,-3,3,0,0
                dc.w    -99
                dcb.w   119,0
mdl_canE:      ; Blue canister (lasers)
                dc.w    2,0,14,3,-5,5,1,0
                dc.w    2,13,14,16,-5,5,1,0
                dc.w    3,3,13,13,-4,4,15,0
                dc.w    9,3,11,5,-5,-4,19,0
                dc.w    7,5,10,7,-5,-4,19,0
                dc.w    6,7,10,8,-5,-4,19,0
                dc.w    7,8,9,10,-5,-4,19,0
                dc.w    5,10,8,13,-5,-4,19,0
                dc.w    -99
                dcb.w   63,0
mdl_canG:      ; Green canister (500 points)
                dc.w    2,0,14,3,-5,5,1,0
                dc.w    2,13,14,16,-5,5,1,0
                dc.w    3,3,13,13,-4,4,16,0
                dc.w    9,3,11,5,-5,-4,19,0
                dc.w    7,5,10,7,-5,-4,19,0
                dc.w    6,7,10,8,-5,-4,19,0
                dc.w    7,8,9,10,-5,-4,19,0
                dc.w    5,10,8,13,-5,-4,19,0
                dc.w    -99
                dcb.w   63,0
mdl_canD:      ; Bomb canister
                dc.w    2,0,14,3,-5,5,1,0
                dc.w    2,13,14,16,-5,5,1,0
                dc.w    3,3,13,13,-4,4,17,0
                dc.w    3,6,13,9,-5,5,18,0
                dc.w    -99
                dcb.w   95,0
mdl_switch:    ; Button (sticks out of the wall to the right)
                dc.w    0,0,2,8,-6,6,14,0
                dc.w    -99
                dcb.w   119,0
mdl_nozzle:    ; Laser emitter (shoots downwards)
                dc.w    -2,0,2,5,-3,3,21,0
                dc.w    -1,5,1,6,-2,2,22,0
                dc.w    -99
                dcb.w   111,0
mdl_ball:      ; Black ball (wave)
                dc.w    1,4,15,12,-7,7,20,0
                dc.w    4,1,12,15,-5,5,20,0
                dc.w    9,9,12,12,-8,-7,19,0
                dc.w    -99
                dcb.w   103,0
mdl_rickstand: ; Rick standing (no hat : spiky hair)
                dc.w    5,8,7,13,4,6,33,2048
                dc.w    4,14,7,20,1,4,30,512
                dc.w    1,8,3,14,-3,3,34,0
                dc.w    3,7,9,14,-4,4,29,0
                dc.w    5,14,8,20,-4,-1,30,256
                dc.w    4,2,9,7,-3,3,31,0
                dc.w    4,2,5,6,-3,3,35,0
                dc.w    9,4,10,6,-1,1,31,0
                dc.w    7,3,8,4,-4,-3,36,0
                dc.w    5,8,7,13,-6,-4,33,1024
                dc.w    5,13,7,14,-6,-4,31,1024
                dc.w    3,0,9,2,-3,3,35,0
                dc.w    4,-1,5,0,-2,2,35,0
                dc.w    7,-1,8,0,-2,2,35,0
                dc.w    8,2,9,3,-3,-1,35,0
                dc.w    -99
                dcb.w   7,0
mdl_rickcrouch: ; Rick crawling (down key)
                dc.w    8,18,12,20,4,6,33,2048
                dc.w    -3,17,3,20,1,4,30,512
                dc.w    2,14,10,19,-4,4,29,0
                dc.w    3,12,8,14,-3,3,34,0
                dc.w    -4,18,3,20,-4,-1,30,256
                dc.w    10,13,15,18,-3,3,31,0
                dc.w    10,13,11,17,-3,3,35,0
                dc.w    13,14,14,15,-4,-3,36,0
                dc.w    10,18,15,20,-6,-4,33,1024
                dc.w    15,18,17,20,-6,-4,31,1024
                dc.w    10,11,16,13,-3,3,35,0
                dc.w    11,10,12,11,-2,2,35,0
                dc.w    14,10,15,11,-2,2,35,0
                dc.w    14,13,15,14,-3,-1,35,0
                dc.w    -99
                dcb.w   15,0
mdl_rickladder: ; Rick on the ladder
                dc.w    3,14,6,20,-2,2,30,4096
                dc.w    6,14,9,20,-2,2,30,8192
                dc.w    2,7,10,14,-3,3,29,0
                dc.w    0,4,2,10,-2,2,33,24576
                dc.w    0,3,2,4,-2,2,31,24576
                dc.w    10,4,12,10,-2,2,33,20480
                dc.w    10,3,12,4,-2,2,31,20480
                dc.w    3,2,9,7,-3,3,35,0
                dc.w    3,8,9,13,-6,-3,34,0
                dc.w    2,0,10,2,-3,3,35,0
                dc.w    3,-1,4,0,-2,2,35,0
                dc.w    7,-1,8,0,-2,2,35,0
                dc.w    -99
                dcb.w   31,0
mdl_rickpunch: ; Rick : punch
                dc.w    5,8,7,13,4,6,33,2048
                dc.w    4,14,7,20,1,4,30,512
                dc.w    1,8,3,14,-3,3,34,0
                dc.w    3,7,9,14,-4,4,29,0
                dc.w    5,14,8,20,-4,-1,30,256
                dc.w    4,2,9,7,-3,3,31,0
                dc.w    4,2,5,6,-3,3,35,0
                dc.w    9,4,10,6,-1,1,31,0
                dc.w    7,3,8,4,-4,-3,36,0
                dc.w    5,8,8,10,-6,-4,33,0
                dc.w    7,10,10,12,-6,-4,33,0
                dc.w    9,11,12,13,-6,-4,31,0
                dc.w    3,0,9,2,-3,3,35,0
                dc.w    4,-1,5,0,-2,2,35,0
                dc.w    7,-1,8,0,-2,2,35,0
                dc.w    -99
                dcb.w   7,0
mdl_walkway:   ; Walkway (=) : 1 tile
                dc.w    0,0,8,3,-20,20,0,256
                dc.w    -99
                dcb.w   119,0
mdl_bar:       ; Bar (-) : 1 tile
                dc.w    0,0,8,2,-20,20,1,256
                dc.w    -99
                dcb.w   119,0
mdl_ladder:    ; Ladder (H) : 1 tile
                dc.w    0,3,8,5,-2,2,6,256
                dc.w    0,0,2,8,-2,2,6,1536
                dc.w    6,0,8,8,-2,2,6,2560
                dc.w    -99
                dcb.w   103,0
mdl_mast:      ; Pole (M) : 1 tile
                dc.w    0,3,8,5,-2,2,7,256
                dc.w    0,0,2,8,-2,2,7,1536
                dc.w    6,0,8,8,-2,2,7,2560
                dc.w    -99
                dcb.w   103,0
mdl_screwV:    ; Vertical screw (V) : 1 tile
                dc.w    2,0,6,8,2,6,8,512
                dc.w    2,2,6,3,1,2,9,0
                dc.w    2,6,6,7,1,2,9,0
                dc.w    -99
                dcb.w   103,0
mdl_screwQ:    ; Horizontal screw (Q) : 1 tile
                dc.w    0,2,8,5,2,6,8,256
                dc.w    2,2,3,5,1,2,9,0
                dc.w    6,2,7,5,1,2,9,0
                dc.w    -99
                dcb.w   103,0
mdl_girdbeam:  ; Horizontal green girder (G)
                dc.w    0,0,8,6,-3,3,2,256
                dc.w    3,2,5,4,-4,-3,5,0
                dc.w    -99
                dcb.w   111,0
mdl_girdpost:  ; Green girder : post (G)
                dc.w    1,0,7,8,4,10,3,512
                dc.w    3,3,5,5,3,4,5,0
                dc.w    -99
                dcb.w   111,0
mdl_pylon:     ; Lattice pylon (X)
                dc.w    0,0,2,8,4,10,4,1536
                dc.w    6,0,8,8,4,10,4,2560
                dc.w    0,0,2,2,5,9,3,0
                dc.w    2,2,4,4,5,9,3,0
                dc.w    4,4,6,6,5,9,3,0
                dc.w    6,6,8,8,5,9,3,0
                dc.w    -99
                dcb.w   79,0
mdl_zapemit:    ; Electric arc emitter (sticks out to the right)
                dc.w    1,6,5,8,-3,3,21,0
                dc.w    2,1,4,6,-2,2,21,0
                dc.w    4,2,8,3,-1,1,22,0
                dc.w    4,5,8,6,-1,1,22,0
                dc.w    1,0,5,1,-2,2,21,0
                dc.w    -99
                dcb.w   87,0
ts_v6_end:                                     ; (end of version 6)
; version 7 : PORTHOLES (N tile, DECOR.S win_draw)
;   6 sets of 4 RGB565 colours, then 8 settings
wc_ring:        dc.w    $9A84,$6182,$C4A8,$40E1    ; frame : face, sides, top, bottom
wc_lip:         dc.w    $E5CB,$93A6,$FF12,$6A83    ; lip around the glass
wc_rivet:       dc.w    $D5F1,$8BCA,$F716,$5A66    ; rivets
wc_tun:         dc.w    $4A6C,$2947,$18E5,$6B71    ; tunnel : left side, right side, ceiling, floor
wc_space:       dc.w    $0022,$6C96,$4B11,$0000    ; space, reflection 1, reflection 2, (free)
wc_star:        dc.w    $52D0,$52D0,$953A,$FFFF    ; stars (pale .. bright)
wn_ft:          dc.w    8                          ; frame width (world units, 8 = 1 tile)
wn_lip:         dc.w    2                          ; lip width
wn_rz:          dc.w    4                          ; frame relief (towards Rick)
wn_lz:          dc.w    7                          ; lip relief
wn_dep:         dc.w    16                         ; depth of the tunnel behind the wall
wn_dens:        dc.w    20                         ; one star per n square units (0 = none)
wn_rsp:         dc.w    8                          ; gap between the rivets (0 = none)
wn_refl:        dc.w    1                          ; reflections on the glass (0 = no)
ts_v7_end:                                     ; (end of version 7)
; version 8 : ENEMIES (ENNEMIS.S) : 5 colour sets (setptr 37..41), then
;   (+ 41 cream, then) their models (16 boxes max, same layout and animation bits as Rick)
col_enbody:     dc.w    $D365,$9222,$F50A,$6161    ; guard robot : copper body
col_enband:     dc.w    $94B5,$5AED,$CE5A,$39E8    ;  grey bands
col_envisor:    dc.w    $3E47,$1C03,$7F8F,$12C2    ;  green visor
col_endark:     dc.w    $6982,$40E1,$9283,$28A0    ;  dark copper (legs, far arm)
col_encream:    dc.w    $F6B5,$B4F0,$FFBA,$8BAC    ; bell droid : cream band
mdl_en1side:   ; Enemy 1 (London guard robot) : side view, looks right
                dc.w    2,0,10,6,-4,4,37,0
                dc.w    1,1,11,5,-3,3,37,0
                dc.w    1,5,11,7,-4,4,38,0
                dc.w    8,2,12,5,-3,3,39,0
                dc.w    2,7,10,14,-4,4,37,0
                dc.w    1,11,11,13,-5,5,38,0
                dc.w    4,8,7,13,4,6,40,2048
                dc.w    3,14,6,20,1,4,40,512
                dc.w    6,14,9,20,-4,-1,40,256
                dc.w    2,18,6,20,1,4,38,512
                dc.w    6,18,10,20,-4,-1,38,256
                dc.w    4,8,7,12,-6,-4,37,1024
                dc.w    4,12,7,14,-6,-4,38,1024
                dc.w    4,-1,6,0,-1,1,38,0
                dc.w    -99
                dcb.w   15,0
mdl_en1climb:  ; Enemy 1 : on a ladder (seen from behind)
                dc.w    2,0,10,5,-4,4,37,0
                dc.w    1,5,11,7,-4,4,38,0
                dc.w    2,7,10,14,-4,4,37,0
                dc.w    2,11,10,13,-5,5,38,0
                dc.w    0,4,2,10,-2,2,37,24576
                dc.w    0,3,2,4,-2,2,38,24576
                dc.w    10,4,12,10,-2,2,37,20480
                dc.w    10,3,12,4,-2,2,38,20480
                dc.w    3,14,6,20,-2,2,40,4096
                dc.w    6,14,9,20,-2,2,40,8192
                dc.w    -99
                dcb.w   47,0
mdl_en2side:   ; Enemy 2 (small bell droid) : looks right
                dc.w    4,18,8,20,-2,2,40,0
                dc.w    0,15,12,18,-5,5,37,0
                dc.w    0,14,12,15,-5,5,41,0
                dc.w    1,12,11,14,-4,4,18,0
                dc.w    2,9,10,12,-4,4,37,0
                dc.w    9,10,12,13,-3,3,39,0
                dc.w    5,7,7,9,-1,1,38,0
                dc.w    5,6,7,7,-1,1,37,0
                dc.w    -99
                dcb.w   63,0
tileset_end:
TILESET_SZ      equ     tileset_end-tileset
TILESET_V1      equ     ts_v1_end-tileset
TILESET_V2      equ     ts_v2_end-tileset
TILESET_V3      equ     ts_v3_end-tileset
TILESET_V4      equ     mdl_walkway-tileset    ; (version 4 : 13 models)
TILESET_V5      equ     mdl_zapemit-tileset    ; (version 5 : 22 models)
TILESET_V6      equ     ts_v6_end-tileset      ; (version 6 : without the portholes)
TILESET_V7      equ     ts_v7_end-tileset      ; (version 7 : without the enemies)
BV_OFS          equ     bv_rock-tileset         ; colours of the back view (missing
BV_SZ           equ     3*8                     ;  from the editor files before v7)
ts_sizes:       dc.l    TILESET_V1,TILESET_V2,TILESET_V3,TILESET_V4,TILESET_V5,TILESET_V6,TILESET_V7,TILESET_SZ
MDL_SZ          equ     256                     ; a model = 16 boxes x 8 words

setptr:         ; colour sets by index (same order as the editor)
                dc.l    col_plat
                dc.l    col_bar
                dc.l    col_gird
                dc.l    col_gpost
                dc.l    col_pylon
                dc.l    col_rivet
                dc.l    col_lad
                dc.l    col_mast
                dc.l    col_screw
                dc.l    col_thread
                dc.l    col_barrel
                dc.l    col_ring
                dc.l    col_bartop
                dc.l    col_mplat
                dc.l    col_switch
                dc.l    col_glass
                dc.l    col_greencan
                dc.l    col_bombcan
                dc.l    col_redband
                dc.l    col_zap
                dc.l    col_ball
                dc.l    col_nozzle
                dc.l    col_tip
                dc.l    col_pipe0
                dc.l    col_pipe1
                dc.l    col_pipe2
                dc.l    col_pipe3
                dc.l    col_laser
                dc.l    col_dyn
                dc.l    col_body
                dc.l    col_legs
                dc.l    col_head
                dc.l    col_hat
                dc.l    col_arm
                dc.l    col_pack
                dc.l    col_hair
                dc.l    col_eye
                dc.l    col_enbody              ; 37.. : enemies (version 8)
                dc.l    col_enband
                dc.l    col_envisor
                dc.l    col_endark
                dc.l    col_encream             ; 41
box_mask:       dc.w    15                         ; allowed faces (draw_box)
spr_on:         dc.w    SPR_ON_INIT                ; cached sprites (S key, SPRITES.S)
pipe_tab:       ; 16 cases (neighbours L=1 R=2 U=4 D=8) x 4 quarters (top-l, top-r, bottom-l, bottom-r) : shade 0..3, -1 = empty
                dc.b    1,1,1,1    ; 0
                dc.b    1,1,0,0    ; 1
                dc.b    1,1,0,0    ; 2
                dc.b    1,1,0,0    ; 3
                dc.b    1,0,1,0    ; 4
                dc.b    1,1,1,-1    ; 5
                dc.b    1,0,-1,0    ; 6
                dc.b    1,1,2,2    ; 7
                dc.b    1,0,1,0    ; 8
                dc.b    1,-1,0,0    ; 9
                dc.b    -1,0,0,0    ; 10
                dc.b    1,1,0,0    ; 11
                dc.b    1,0,1,0    ; 12
                dc.b    1,2,1,2    ; 13
                dc.b    1,0,1,0    ; 14
                dc.b    1,0,0,0    ; 15
                even
