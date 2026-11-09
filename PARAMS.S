;=====================================================================
; PARAMS.S - ALL THE GAME SETTINGS
;
; This is WHERE the values are changed : music volume, lives,
; ammunition, jumps, laser speed... then RICK3D.S is assembled again.
; Units : "world unit" = 1 pixel of the original game (a tile = 8) ;
;          speeds are in 1/8 of a unit per frame (60 frames / s on
;          VGA, 50 on RGB/TV) ; durations are in frames.
;=====================================================================

;---------------------------------------------------------------------
; MUSIC (DSP replay, modules ZIK\*.MOD)
;---------------------------------------------------------------------
MUS_VOL_INIT    equ     20              ; volume at start (0 = mute .. 64 = max)
MUS_VOL_STEP    equ     4               ; step of the + / - keys
MUS_VOL_MAX     equ     64              ; max volume of the replay (do not go over 64)
REPFREQ         equ     2               ; frequency of the DSP replay : 2 = 32780 Hz
MAXMODS         equ     64              ; max number of modules in ZIK\
NAMESZ          equ     14              ; (size of an 8.3 file name)
WORKSZ          equ     20832           ; (MegaPlayer work area : do not touch)

;---------------------------------------------------------------------
; SOUND EFFECTS (YM2149 synthesizer)
;---------------------------------------------------------------------
YM_GAIN         equ     $c0             ; YM input gain in the mixer :
                                        ;  $00..$f0 (steps of 1.5 dB) ; higher = louder
                                        ; (the sounds themselves : sfx_* tables in DONNEES.S)

;---------------------------------------------------------------------
; RICK : size, walk, jump
;---------------------------------------------------------------------
RICK_W          equ     12              ; collision width
LAD_GRAB        equ     4               ; ladder / pipe grabbed up to 4 pixels beside Rick
RICK_H          equ     20              ; collision height (2 tiles : he must crawl)
DRAW_H          equ     20              ; drawn height
CROUCH_H        equ     12              ; crouching height (down)
WALK            equ     10              ; walking speed (10 = 1.25 unit / frame)
GRAV            equ     1               ; gravity (added to the speed at each frame)
JUMP_V          equ     -24             ; jump start speed : -24 = jump of 34 units
                                        ;  (measured on the original ; more negative = higher)
VMAX            equ     32              ; max falling speed

;---------------------------------------------------------------------
; LIVES, AMMUNITION, RESPAWN
;---------------------------------------------------------------------
NB_LIVES        equ     6               ; lives at start (and after a game over)
MAX_LIVES       equ     6               ; max lives
PTS_GREEN       equ     500             ; points of a green canister (like the original)
SCORE_X         equ     124             ; x of the score in the top HUD
                                        ; (I key in game : infinite lives, for testing)
SV_VER          equ     1               ; RICK3D.SAV : version
SV_NSC          equ     10              ; number of scores kept
SV_SIZE         equ     14+SV_NSC*12
WAVE_Q          equ     2               ; wave between 2 balls (W) : speed 1 of the .MAP = WAVE_Q/4
                                        ;  pixel per frame (2 -> 1/2 pixel ; 4 = the old speed)
ZAP_MV_SPD      equ     2               ; back-and-forth Z beam : speed (units/frame)
ZAP_MV_W        equ     24              ;  length of the piece of beam (3 tiles)
SC_STEP         equ     8               ; side view : the map scrolls by 8 tiles...
SC_EDGE         equ     6               ;  ... when Rick is 6 tiles from an edge
SC_VSTEP        equ     6               ;  vertically : 6 rows (quarter of a screen)...
SC_VEDGE        equ     4               ;  ... when Rick is 4 rows from the top / bottom
SC_NFR          equ     10              ;  scrolling in 10 frames
BV_K            equ     2               ; back view : width of the corridor = depth x BV_K
BV_BACK         equ     104              ;  camera : distance behind Rick
BV_EYE          equ     10              ;  height above the top of Rick
BV_NEAR         equ     16              ;  near plane (cut in front)
BV_DIST         equ     28              ;  columns shown in front of Rick
BVX_N           equ     BV_BAND/8               ; back view : bands of 8 lines
BVX_Y0          equ     CY-BV_BAND/2            ;  (erasing : what was drawn)
BV_BAND         equ     168             ;  height of the drawn band (lines)
BV_MAXR         equ     512             ;  moving objects noted per frame
BV_MAXSTEP      equ     6               ;  max game steps per frame (constant speed)
BV_BS           equ     2               ;  turned flat objects : width x BV_BS (x BV_K)
BV_BEH          equ     8               ;  floor columns behind Rick
MSG_DUR         equ     120             ; duration of the R / B messages in the bar (frames)
AMMO_LAS_MAX    equ     6               ; laser shots (start, respawn, canister)
AMMO_BOMB_MAX   equ     6               ; bombs (start, respawn, canister)
RESPAWN_T       equ     50              ; frames between death and respawn
INVUL_N         equ     120             ; invulnerability after respawn (Rick blinks)
END_DUR         equ     180             ; end of the level reached : message, then restart (frames)

;---------------------------------------------------------------------
; RICK'S WEAPONS
;---------------------------------------------------------------------
LAS_LEN         equ     10              ; length of the laser line
LAS_SPD         equ     5               ; laser speed (units / frame)
BOMB_SPD        equ     2               ; thrown bomb (fire + down diagonal) : speed
BOMB_FUSE       equ     90              ; fuse : frames before the explosion
BOMB_EXPL       equ     24              ; duration of the explosion
BOMB_KILL       equ     22              ; deadly radius of the explosion
BOMB_BRK_R      equ     24              ; radius in which a 'B' plate blows up

;---------------------------------------------------------------------
; TRAP LASERS (L lines of the .MAP)
;---------------------------------------------------------------------
LZ_GRACE        equ     60              ; respite when entering a screen (frames)
LZ_GAP          equ     36              ; minimum gap between two shots of the same screen
LZ_PROX         equ     20              ; laser mode 2 : fires when Rick is less than 20 px away (horizontally)
SW_CUBE         equ     8               ; button : width / height (world pixels)
SW_LEN          equ     12              ; button : length in depth (3 x, stays between ZF and ZB)
SW_OUT          equ     2               ; buttons : how far they stick out of the wall face (pixels)
PIPE_Z0         equ     ZMID-8          ; grey pipes : in the middle of the wall depth
PIPE_Z1         equ     ZMID+8          ;  (16 deep = 2 tiles, like their width)
SW_HAND         equ     7               ; height of the punching arm (from the top of Rick) = height of the buttons
WAVE_Y0         equ     8               ; wave between 2 balls (W) : deadly zone from
WAVE_Y1         equ     20              ;  top of the balls + 8 to + 20 : Rick standing
                                        ;  (16 high) is hit, crouching (12) is not

;---------------------------------------------------------------------
; PLATFORMS / LIFTS (P lines of the .MAP)
;---------------------------------------------------------------------
PLAT_WAIT       equ     60              ; back-and-forth (mode A) : pause at each end
                                        ;  (frames ; 60 = 1 s) to be able to get on it

;---------------------------------------------------------------------
; LIMITS (max number of objects read from the .MAP ; beyond that they are ignored,
;   the editor warns when saving : keep its GAME_MAX identical)
;---------------------------------------------------------------------
MAXPL           equ     48              ; platforms / lifts (P)
MAXSW           equ     48              ; buttons (S)
MAXLZ           equ     64              ; trap lasers (L)
MAXZP           equ     64              ; beams + canisters (Z E G D)
LEV_MAX         equ     100000          ; map : max width x height (level 2 : 288 x 271)
FILE_MAX        equ     120000          ; max size of the .MAP file

;---------------------------------------------------------------------
; DISPLAY : bottom text bar and top HUD
;---------------------------------------------------------------------
HUD_H           equ     12              ; height of the HUD band (lives, laser, bombs)
BAND_H          equ     15              ; height of the text bar (2 lines of 6x6)
TXT_YV          equ     SCR_H-BAND_H    ; position of the bar (VGA : at the very bottom)
COLS            equ     53              ; characters per line (53 x 6 = 318 pixels)
LINEW           equ     54              ; (bytes of a text line)
TXTST           equ     2+2*LINEW       ; (state per screen : shown + cache)

;---------------------------------------------------------------------
; CAMERA AND 3D DEPTH
;---------------------------------------------------------------------
CX              equ     160             ; projection centre on the screen
CY              equ     120
ZF              equ     256             ; front plane of the blocks
ZB              equ     296             ; back plane of the blocks (depth = ZB - ZF)
FOC             equ     320             ; focal : 1 world unit = 1.25 pixel at ZF
ZMID            equ     (ZF+ZB)/2       ; middle plane (Rick, ladders, girders)
GB_Z0           equ     ZMID-3          ; green girders : square section 6 x 6
GB_Z1           equ     ZMID+3
GP_Z0           equ     ZMID+4          ; green posts and pylons (behind Rick)
GP_Z1           equ     ZMID+10
PLAT_Z0         equ     ZMID-6          ; moving platforms / lifts : tube
PLAT_Z1         equ     ZMID+6          ;  12 deep (does not overlap the walls)

;---------------------------------------------------------------------
; TECHNICAL (screen, tiles : do not change without changing the code)
;---------------------------------------------------------------------
SCR_W           equ     320             ; True Color screen 320 x 240
SCR_H           equ     240
LINEB           equ     640             ; bytes per line (16 bits / pixel)
SCRSZ           equ     SCR_H*LINEB     ; 153600
TILE            equ     8               ; a tile = 8 world units
SCR_TW          equ     32              ; a game screen = 32 x 24 tiles
SCR_TH          equ     24
TPX             equ     10              ; a tile = 10 pixels at ZF
OX              equ     128             ; centre of the screen (world units)
OY              equ     96
MAXR            equ     32              ; rectangles to erase per frame
BRK_MAX         equ     64              ; (stack to blow up a plate)
YM_SEL          equ     $ffff8800       ; YM2149 registers
YM_WR           equ     $ffff8802
