;=====================================================================
; RICK3D.S - Rick Dangerous 2 tribute in "2.5D" - MAIN FILE
; Atari Falcon 030 - 16-bit True Color - Devpac 3 / vasm
;
; - Scenery in real 3D (extruded blocks, perspective, fixed side camera)
; - Fixed screens that flip (flip-screen) like the original
; - Full screen VGA 320x240 True Color (grid of 20x15 tiles of 16)
; - The scenery of each screen is computed ONCE (bgbuf), then only
;   Rick is erased/redrawn at each VBL (double buffer)
;
; MUSIC : Amiga DSP replay of the MegaPlayer by Simplet / FATAL DESIGN
;           (AMIGADSP.S + AMIGADSP.P56, included as they are, like CUBEDSP)
;           modules in ZIK\*.MOD (alphabetical order, played one after another)
;
; SOUND EFFECTS : YM2149 synthesizer (jump, laser, fall), see sfx_*
;
; Text bar at the bottom (6x6 system font) : FPS, music, volume, help
;
; Controls : joystick (port 1) or arrows : left/right = walk
;             up = jump (or climb a ladder), down = go down
;             fire + up = laser (6)   fire + down = bomb (6)
;             button pressed = Rick does not move
;             keyboard : space = fire, down arrow = down
;             M = next music   P = pause   + / - = volume
;             H = hide / show the text     ESC = quit
; VGA : 320x240 TC full screen / RGB-TV : 320x200 TC (bottom of the screen)
;
; SOURCE LAYOUT (all in the RICK3D folder) :
;   PARAMS.S    ALL THE SETTINGS (music volume, lives, jumps, lasers...)
;   INIT.S      start, main loop, exit
;   CLAVIER.S   keyboard / joystick (IKBD)      ECRAN.S     double buffer
;   HUD.S       top band                        TEXTE.S     bottom bar
;   NIVEAU.S    loading of the .MAP / TILES.DAT, tiles and collisions
;   RICK.S      Rick's moves                    DESSRICK.S  drawing of Rick
;   RENDU3D.S   3D boxes, projection, polygons
;   DECOR.S     building the scenery of a screen
;   PLATEF.S    platforms, lifts, buttons
;   PIEGES.S    trap lasers, beams, canisters
;   ARMES.S     Rick's laser and bomb           SONS.S      YM sound effects
;   ENNEMIS.S   all the enemies (types, behaviours, drawing)
;   MUSIQUE.S   DSP replay                      DONNEES.S   colours, texts...
;   DSP3D.S     3D maths by the DSP (R3D.P56, source OUTILS\R3D.A56)
;   VARIABLE.S  variables (BSS)                 AMIGADSP.S  Simplet's replay
;
; Assemble RICK3D.S alone : the other files are included.
;=====================================================================

                include 'PARAMS.S'

; macro : a 3D point (X,Y,Z) in the buffer pointed to by a0
PT              macro
                move.w  \1,(a0)+
                move.w  \2,(a0)+
                move.w  \3,(a0)+
                endm

;=====================================================================
                section text
;=====================================================================
                include 'PROFIL.S'
                include 'INIT.S'
                include 'CLAVIER.S'
                include 'ECRAN.S'
                include 'HUD.S'
                include 'TEXTE.S'
                include 'NIVEAU.S'
                include 'RICK.S'
                include 'DESSRICK.S'
                include 'RENDU3D.S'
                include 'DECOR.S'
                include 'VUEDOS.S'
                include 'PLATEF.S'
                include 'PIEGES.S'
                include 'ARMES.S'
                include 'ENNEMIS.S'
                include 'SONS.S'
                include 'MUSIQUE.S'
                include 'DSP3D.S'
                include 'ACCUEIL.S'
                include 'MENUS.S'
                include 'PROFIL.S'
                include 'SPRITES.S'
                include 'ZIGZAG.S'
                include 'BGBUILD.S'
                include 'PREBUILD.S'

;=====================================================================
                section data
;=====================================================================
                include 'DONNEES.S'

;=====================================================================
                section bss
;=====================================================================
                include 'VARIABLE.S'

;=====================================================================
; DSP replay by Simplet / FATAL DESIGN (original files, not modified)
;=====================================================================
                section text
                include 'AMIGADSP.S'
