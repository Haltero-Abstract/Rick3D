# RICK3D — hommage Rick Dangerous 2 en 2.5D, Atari Falcon 030 + DSP

Assembleur 68030, syntaxe Devpac 3. Tests dans Hatari (Falcon 030 16 MHz + DSP, VGA, EmuTOS).
Répondre en français. Historique des changements : `JOURNAL.MD` (à mettre à jour après chaque session).

## Règles de travail
- Toujours repartir des fichiers sur le disque, ne changer que les lignes nécessaires.
- Ne PAS lire un .S en entier : chercher d'abord le label/la routine avec Grep, puis lire seulement la zone utile (offset/limit).
- Ne pas lire `level original\`, les .mp4, .PRG, .zip, ni `OUTILS\EDITEUR.HTML` en entier (135 Ko : Grep d'abord).

## Build
- `RICK3D.S` est le fichier principal, il inclut tous les autres .S.
- vasm : `vasmm68k_mot -devpac -nocase -m68030 -Ftos -nosym -o RICK3D.PRG RICK3D.S`
- DSP : `OUTILS\ASM56.PY` assemble `OUTILS\R3D.A56` → `R3D.P56`.

## Carte des sources
| Fichier | Rôle |
|---|---|
| PARAMS.S | TOUS les réglages (limites MAXPL/MAXSW/MAXLZ/MAXZP, WAVE_Q, LAD_GRAB…) |
| INIT.S | démarrage, boucle principale, sortie |
| CLAVIER.S / ECRAN.S | IKBD / double buffer |
| HUD.S / TEXTE.S | bande du haut / barre du bas |
| NIVEAU.S | chargement .MAP / TILES.DAT, tuiles, collisions |
| RICK.S / DESSRICK.S | déplacements / dessin de Rick |
| RENDU3D.S / DECOR.S | boîtes 3D, projection / construction du décor (hublot `win_draw`) |
| PLATEF.S | plateformes, ascenseurs, boutons |
| PIEGES.S / ARMES.S | lasers, rayons, bonbonnes, ondes / laser et bombe de Rick |
| SONS.S / MUSIQUE.S | effets YM / interface replay DSP |
| DSP3D.S + R3D.P56 | calculs 3D sur le DSP |
| DONNEES.S / VARIABLE.S | données / variables BSS |
| ACCUEIL.S / MENUS.S | page d'accueil / menus |
| AMIGADSP.S/.P56 | replay de Simplet — NE PAS MODIFIER |

## Données
- `level\LEVEL1.MAP`, `level\LEVEL2.MAP`, `level\TILES.DAT` (version 7).
- Éditeur : `OUTILS\EDITEUR.HTML` ; sa constante `GAME_MAX` doit rester identique aux limites de `PARAMS.S`.
- Convertisseur de plans : `OUTILS\MAPCONV.PY`.
