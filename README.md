# RICK3D — a 2.5D tribute to Rick Dangerous 2 for the Atari Falcon 030

Amateur, non-commercial project made as a tribute to the original game.
68030 assembly (Devpac 3 syntax) + DSP 56001, VGA 320x240 True Color.

## Credits and sources

- **Original game:** Rick Dangerous 2 © 1990 Core Design, published by MicroStyle.
  Level 1 "Hyde Park", Rick, the enemies and the mechanisms (lasers, buttons,
  lifts, canisters…) all come from their game.
- **Level plan:** "Hyde Park – the solution", full level map by Jim Waterman,
  The Rick Dangerous Resource: <https://rickdangerous.co.uk/>
  (converted to `LEVEL1.MAP` by `MAPCONV.PY`).
- **Music replay:** `AMIGADSP.S` / `AMIGADSP.P56` — "Amiga DSP-Replay" from the
  MegaPlayer by **Simplet / FATAL DESIGN** (.MOD player on the Falcon DSP).
  Used unchanged; `MUSIQUE.S` is only the interface.
- **Music:** the `ZIK` folder is empty in this repository (the modules belong to
  their authors). Put Amiga/ProTracker `.MOD` files there (4/6/8 channels): the
  game plays them in alphabetical order, the next one starts at the end of a module.
- **Tools:** vasm (Volker Barthelmann, Frank Wille), Devpac 3 syntax (HiSoft);
  tested in the Hatari emulator and on a real Falcon 030; Python 3 converters.
- **RICK3D code** (2.5D engine, sources, editor, MAPCONV):
  **Haltero / Abstract**, with the help of Claude (Anthropic).

## Building

- Devpac 3: open `RICK3D.S` (it includes all the other `.S` files).
- vasm (PC): `vasmm68k_mot -devpac -nocase -m68030 -Ftos -nosym -o RICK3D.PRG RICK3D.S`
- DSP program: `python OUTILS/ASM56.PY OUTILS/R3D.A56 R3D.P56`

Run `RICK3D.PRG` from its folder (it needs `LEVEL/` and optionally `ZIK/`).

## Memory

- **14 MB Falcon:** at level load every screen of the level is pre-built
  ("PLEASE WAIT… / UNDER CONSTRUCTION" + progress bar, about 8–10 MB per level),
  so screen changes and bomb explosions are instant.
- **4 MB Falcon:** automatic fallback, screens are built in the background while
  playing (message "LOW MEMORY : SCREENS BUILT IN GAME").
- `PRE_MODE equ 0` / `BG_ON equ 0` in `PARAMS.S` force the older modes.

## Controls

| Input | Action |
|---|---|
| Joystick (port 1) or arrows | left / right = walk, up = jump |
| Up / down near a ladder | climb (left / right leaves it) |
| Fire + left / right | punch (presses a button in front of Rick) |
| Down | crouch; left / right while crouched = crawl |
| Fire + up | laser (6 shots) |
| Fire + down | drop a bomb (6): 1.5 s fuse, deadly at close range |
| Fire + down-left / down-right | throw the bomb: it slides a fixed distance, falls off ledges and lands on the scenery |
| Space | fire |
| M / P | next music / pause music |
| + / - | volume |
| H | hide / show the bottom text bar |
| I | infinite lives (testing) |
| R / B | save Rick's position / go back to it (`RICK3D.SAV`) |
| G | scrolling map instead of fixed screens |
| V | back view (experimental) |
| D | 3D maths on the DSP / on the 030 |
| S | characters as cached sprites / full 3D drawing (comparison) |
| T | profiler display in the bottom bar |
| L | write the performance log `RICK3D.LOG` (also written on exit) |
| Esc | quit (video mode, palette and sound restored) |

## Game

- 160 x 256 map of 8x8 tiles, 32 x 24 tiles per screen drawn at 10 px, 6 lives,
  score (green canister = 500 points), level menu, name entry and high scores
  (`RICK3D.SAV`), end-of-level marker.
- **Enemies** (`ENNEMIS.S`): copper guard (patrols, chases Rick, uses ladders)
  and bell droid (patrols between two columns). Contact kills Rick; Rick's laser
  and bombs kill them (100 points); trap lasers kill them too (no points).
- Traps: wall/saucer lasers, trap buttons (one shot per press), electric arcs and
  zigzag beams, moving platforms and lifts, breakable plates (bombs),
  energy / bomb / green canisters.

## Map file (`LEVEL/LEVELn.MAP`)

Text grid, then object lines (editable by hand or with the editor):

| Tile | Meaning |
|---|---|
| `#` `F` | rock / metal frame (solid) |
| `.` `k` | background / black background |
| `=` `-` `G` | walkway, bar, green girder (one-way platforms) |
| `H` `M` `U` | ladder, climbing mast, climbable pipe |
| `T` `u` `w` `N` `g` | barrel, decor pipe, walkable pipe, porthole, lawn |
| `B` | breakable plate |

| Line | Object |
|---|---|
| `P col row width dcol drow speed mode [extension]` | moving platform / lift (modes A, B, C, D, L) |
| `S col row n` | button: n = platform, 100+n laser off, 200+n beam off, 300+n trap laser shot |
| `L col row dx dy start period [mode tcol trow]` | laser trap |
| `Z col row width height [on off type]` | electric arc / zigzag beam |
| `E` / `G` / `D col row` | energy / green (500 pts) / bomb canister |
| `N type col row [dir] [cmin cmax]` | enemy (type 1 guard, type 2 droid) |
| `F col row` | end of the level |

## Performance log (`RICK3D.LOG`)

One line every 32 frames: level, Rick's map position, then the average time per
frame (0.1 ms units; 167 = one VGA frame) of LOG logic, BLD scenery build,
ERA erase, ZAP beams, PLT platforms, ENM enemies, RIK Rick, LAS shots,
OBJ objects, HUD, VBL spare, plus DSP waits, erased words, sprite-cache and
background-build counters.

## Files

| File | Role |
|---|---|
| `RICK3D.S` | main file, includes everything |
| `PARAMS.S` | **all settings** (volume, jump, ammo, speeds, limits, modes) |
| `INIT.S` | start-up, main loop, exit |
| `CLAVIER.S` / `ECRAN.S` | keyboard & joystick / double buffer, erasing |
| `HUD.S` / `TEXTE.S` | top band / bottom text bar |
| `NIVEAU.S` | `.MAP` and `TILES.DAT` loading, tiles, collisions |
| `RICK.S` / `DESSRICK.S` | Rick's movement / drawing |
| `RENDU3D.S` / `DECOR.S` | 3D boxes and polygons / screen scenery |
| `PLATEF.S` / `PIEGES.S` / `ARMES.S` | platforms & buttons / traps & canisters / laser & bomb |
| `ENNEMIS.S` | enemies (types, behaviours, drawing, kills) |
| `SPRITES.S` | cached sprites for characters and platforms |
| `ZIGZAG.S` | fast zigzag beams, canister pickup without rebuild |
| `BGBUILD.S` / `PREBUILD.S` | background screen build / all screens pre-built at load |
| `PROFIL.S` | profiler (MFP Timer D) and `RICK3D.LOG` |
| `SONS.S` / `MUSIQUE.S` | YM sound effects / DSP music interface |
| `DSP3D.S` + `R3D.P56` | 3D maths on the DSP (source `OUTILS/R3D.A56`) |
| `ACCUEIL.S` / `MENUS.S` | title page / level menu, names, high scores |
| `DONNEES.S` / `VARIABLE.S` | data (colours, models, texts) / variables |
| `AMIGADSP.S` / `.P56` | Simplet's DSP replay (unchanged) |
| `OUTILS/EDITEUR.HTML` | level and tile editor (Chrome / Edge) with a real-time 3D preview |
| `OUTILS/MAPCONV.PY` | converts the original PNG plans to `.MAP` |
| `OUTILS/ASM56.PY` | small DSP 56001 assembler (builds `R3D.P56`) |
| `LEVEL/` | maps, tile sets (`TILES.DAT` v8), original level previews |
| `JOURNAL.MD` | change log (French) |
| `LISEZMOI.TXT` | French documentation |
