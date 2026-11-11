# RICK3D — journal des modifications (5 et 6 novembre 2026)

Résumé du travail fait sur RICK3D (Rick Dangerous 2 en 3D, Falcon 030), pour le reprendre dans le projet « jeux atari Rick Dangerous 2 en 3D ».
Dossier : `Documents\ChatGPT\RICK3D`. Jeu testé dans Hatari (Falcon 030 16 MHz + DSP, VGA, EmuTOS).

## Règle de travail
- Toujours repartir des fichiers sur le disque (`level\LEVEL1.MAP`, `level\TILES.DAT`, sources), jamais d'une copie gardée ailleurs.
- Ne changer que les lignes nécessaires, vérifier le fichier sur le disque après l'écriture.

## Décor
- **Hublot (tuile `N`)** : un rectangle de `N` = un hublot en vraie 3D (`DECOR.S` `win_draw`).
  - Tunnel creusé dans le mur, avec l'espace étoilé au fond.
  - Cadre en cuivre en relief, lèvre en laiton plus saillante, rivets répartis régulièrement, 2 reflets sur la vitre.
  - 3 hublots placés au niveau 1 : (44,136) 8×4, (72,128) 8×4, (84,128) 4×4.
- **TILES.DAT version 7** : couleurs et réglages du hublot (largeurs, reliefs, profondeur, étoiles, rivets, reflets), modifiables dans l'éditeur (Apparence des tuiles → Décor → Hublot, avec aperçus 3D).
- **Bug corrigé** : l'éditeur n'écrivait pas les 3 jeux de couleurs de la vue de dos (`bv_rock`, `bv_frame`, `bv_grass`), donc le jeu refusait TILES.DAT. L'éditeur les écrit maintenant (v7) et le jeu accepte aussi les anciens fichiers.

## Pièges et armes
- **Bombe** : elle continue (mèche, explosion, plaques `B`) même si Rick change d'écran (`ARMES.S`).
- **Ondes électriques (`W`)** : position au quart de pixel, vitesse divisée par 2. Réglage `WAVE_Q` dans `PARAMS.S` (4 = ancienne vitesse, 2 par défaut, 1 = quart). Vitesse 1 du .MAP = ½ pixel par image.

- **Niveau 2 : boules de neige** : les lasers `L` sont dessinés en boule blanche (éclatement blanc) et tirent avec le son `sfx_blow` (« pfuit » de sarbacane, `DONNEES.S`) quand `cur_level=2` (`PIEGES.S`). L'éditeur (thème 2) affiche aussi une boule de neige à la place du laser.

## Plateformes
- **Mode D** : chaque appui sur un de ses boutons l'envoie à l'autre bout, où elle s'arrête (Rick dessus ou non). Ex. 2 boutons : celui du bas la fait monter, celui du haut la fait redescendre.
- **Éditeur** : le pointillé d'un bouton va vers le bout du trajet le plus proche (départ ou arrivée en pointillés).
- **Ascenseur piloté (L)** : revient à son départ quand Rick perd une vie (comme B, C, D). Le mode A n'est pas remis à zéro.
- **Poser une plateforme au ras d'un sol** : la mettre sur la ligne du sol, pas sur la case vide au-dessus.

## Rick
- **Échelles et tuyaux** : attrapés jusqu'à 4 pixels à côté du corps (`LAD_GRAB` dans `PARAMS.S`), car le tuyau en relief paraît plus large que sa case.
- **Diagonale sur une échelle / un tuyau** : haut ou bas appuyé = il grimpe (avant il lâchait et rattrapait à chaque image).
- **Bas + gauche/droite** : s'accroupir et ramper tout de suite, même en haut d'une échelle (sortir sous une onde).

## Limites du jeu (`PARAMS.S`)
| Objets | Avant | Maintenant |
|---|---|---|
| Plateformes (`MAXPL`) | 16 | 48 |
| Boutons (`MAXSW`) | 16 | 48 |
| Lasers (`MAXLZ`) | 40 | 64 |
| Rayons, bonbonnes, ondes (`MAXZP`) | 32 | 64 |

L'éditeur prévient à l'enregistrement si une limite est dépassée (`GAME_MAX`, à garder identique à `PARAMS.S`).

## Fichiers modifiés
`DECOR.S`, `DONNEES.S`, `VARIABLE.S`, `NIVEAU.S`, `ARMES.S`, `PIEGES.S`, `PLATEF.S`, `PARAMS.S`, `RICK.S`, `RICK3D.PRG`, `OUTILS\EDITEUR.HTML`, `LISEZMOI.TXT`, `level\LEVEL1.MAP` (hublots, ascenseur `P 44 112`).

## 2026-11-10 — Ennemis (ENNEMIS.S)
- Nouveau ENNEMIS.S : table de types, comportements en_patrol / en_seek / en_follow (échelles) / en_bounded. MAXEN=32.
- Ennemi 1 garde cuivré (suit Rick, échelles, 100 pts) placé G1..G14 ; ennemi 2 droïde cloche (patrouille cmin-cmax, 100 pts) D1..D8.
- Ligne carte : N type col row [dir] [cmin cmax] (row = L-1, dir 0=droite 1=gauche).
- TILES.DAT v8 (couleurs 37-41, modèles en1side/en1climb/en2side) ; éditeur : objet Ennemi + Aperçu 3D.
- Modifiés : PARAMS VARIABLE RICK3D INIT RICK PLATEF NIVEAU DONNEES, EDITEUR.HTML, LEVEL1.MAP, TILES.DAT, RICK3D.PRG.
- Limites : pas dans la vue de dos, tués = morts jusqu'au rechargement, ignorent plateformes mobiles.

## 2026-11-10 — Profileur (touche T) + effacement plus rapide
- PROFIL.S (nouveau, inclus 2 fois) : horloge MFP Timer D (49152 Hz), macro PROF n dans la boucle principale.
  Touche T : la barre du bas affiche le temps moyen par image (0,1 ms, moyenne sur 32 images) :
  LOG logique, BLD reconstruction, ERA effacement, ZAP rayons/ondes, PLT plateformes, ENM ennemis, RIK Rick,
  LAS tirs, OBJ objets, HUD hud+texte, VBL attente VBL (marge), DSP attentes du port hôte DSP / image, EKW mots effacés /100 / image.
- Mesure Hatari 16 MHz : RIK = 7,0 ms (DSP) / 10,8 ms (030, touche D) pour ~15 boîtes : les personnages en boîtes 3D sont le gros coût,
  chaque ennemi visible coûte autant que Rick. Effacement et lasers < 0,5 ms dans Hatari (à vérifier sur vrai Falcon).
- ECRAN.S erase_one : copie par mots longs déroulée (au lieu de mot à mot).
- Modifiés : PROFIL.S, RICK3D.S, INIT.S, CLAVIER.S, TEXTE.S, ECRAN.S, DSP3D.S, RICK3D.PRG.

## 2026-11-10 — Log de performances RICK3D.LOG
- Les mesures tournent en permanence ; une ligne toutes les 32 images dans un tampon de 64 Ko (~5 min).
- Fichier RICK3D.LOG écrit en quittant le jeu et avec la touche L (message dans la barre). T affiche toujours les valeurs.
- Ligne : N niveau, L/C de Rick, D (1 = 3D sur DSP), puis LOG..VBL (0,1 ms/image), DSP (attentes), EKW.
- Variables du profileur déplacées dans VARIABLE.S ; PROFIL.S inclus après MENUS.S (portée des bsr).

## 2026-11-10 — Sprites pré-calculés (SPRITES.S)
- Rick et ennemis : chaque (modèle, pas d'animation, miroir, zone 8x8 + phase X/Y) dessiné une fois en 3D dans un écran caché (couleur transparente $F81F), stocké en segments opaques par ligne, recopié en move.l. Pool 512 Ko, vidé au chargement du niveau ou si plein.
- Touche S : sprites / ancien dessin 3D (comparaison). Vue de dos et bords d'écran : ancien dessin.
- Hatari 16 MHz : RIK 67 -> 4, ennemi 43 -> 4 (0,1 ms). Différences visuelles : 0 à 1 pixel sur quelques bords.
- Modifiés : SPRITES.S (nouveau), PARAMS, RICK3D, DESSRICK, ENNEMIS, VARIABLE, DONNEES, CLAVIER, MENUS, RICK3D.PRG.

## 2026-11-11 — Sprites v2/v3 + barre du bas + effacement par segments
- Cache de sprites par zones de ~38 px (SPR_BSH=5, plus de phases), sprite décalé à la position exacte : touché même en marchant. Hatari : RIK en marche 17 -> 3-7.
- TEXTE.S draw_cells : la barre du bas ne redessine que les caractères changés (HUD 20 -> 4,5 en marchant).
- Sprites effacés par leurs propres segments depuis bgbuf (spr_erase, MAXS=24 par écran) ; erase_one aligné + movem.l.
- Lasers : effacement par rectangles conservé (coût mesuré trop faible).
- Modifiés : PARAMS, SPRITES, TEXTE, ECRAN, VARIABLE, INIT, RICK3D.PRG.

## 2026-11-11 — v4 perfs + bombes
- SPRITES.S : sprites découpés au bord gauche/droit (plus de retour au dessin 3D), réessai de construction près du bord, ennemis hors écran ignorés.
- ENNEMIS.S : résultat de la recherche d'échelle (en_findlad) mémorisé par ennemi (EN_FK/EN_FX).
- PIEGES.S + ZIGZAG.S (nouveau) : table de projection zp_ptab, zigzag rapide zz_fast (vue de côté). Hatari : ZAP -51..62 %, LOG -28 % écran échelle départ.
- Bombes (ARMES.S) : glissade limitée à BOMB_DIST=24, BOMB_SPD=1, chute pixel par pixel avec gravité (BOMB_FALLMAX=4) et pose sur le décor (bomb_floor).
- Modifiés : ARMES ENNEMIS MENUS PARAMS PIEGES RICK3D SPRITES VARIABLE ZIGZAG(nouveau) RICK3D.PRG.

## 2026-11-11 — Bombe relancée + gel bonbonne
- Bombe : throw_bomb ne relance plus une bombe déjà posée (le joystick qui oscille entre bas+feu et diagonale+feu la relançait) ; distance comptée en pixels réellement parcourus.
- Bonbonne : ramassage sans reconstruction complète de l'écran (avant ~0,5-0,8 s de gel) : bg_noit (décor sans bonbonnes), pixels des bonbonnes dans can_pool, can_erase restaure seulement la zone.
- Modifiés : ARMES INIT PARAMS PLATEF PIEGES VARIABLE ZIGZAG RICK3D.PRG (+170 Ko de BSS).

## 2026-11-11 — v5 : plateformes en sprites + diagnostic
- Plateformes mobiles dessinées par le cache de sprites (plat_spr) ; segments d'une seule couleur remplis (moins de lectures) ; découpage au bord par segments.
- Log : nouveaux champs SMK (sprites construits), SFB (dessins 3D de secours), SFM (raison : 2 hors zones, 4 non cachable), SFX/SFY (position +1000).
- Les points chauds Falcon (ENM ~70 écran L235-238, ZAP 27-37 salles des rayons, LOG 31-40) ne se reproduisent pas dans Hatari.
- Modifiés : PLATEF PROFIL SPRITES VARIABLE RICK3D.PRG.

## 2026-11-11 — Bombe : glissade doublée
- PARAMS.S BOMB_DIST 24 -> 48 (~4 largeurs de Rick).

## 2026-11-11 — Les lasers des pièges tuent les ennemis
- ENNEMIS.S : en_traps (tir de piège dans la boîte ennemie -> explose, ennemi meurt sans points), en_kill scindé en en_kill (points) + en_die.

## 2026-11-11 — v6 son pendant le changement d ecran
- BLD_DSP=0 (PARAMS.S) : decor construit par le 030, DSP libre pour la musique ; effets sonores avances par la file VBL pendant build_screen (bld_begin/bld_end dans ZIGZAG.S).

## 2026-11-11 — v7 construction du decor en arriere-plan
- BGBUILD.S (nouveau) : ecran suivant predit et construit en tache de fond (12,2 ms/image max), echange au changement d ecran. BG_ON=0 dans PARAMS.S = ancien comportement.

## 2026-11-11 — v8 arriere-plan + bombe
- BGBUILD.S : 2 ecrans prepares gardes, prediction echelle/chute/marche, bg_snap (ligne +/-3), plus de reconstructions a l arret. Log : BGH BGM BGR BGS MX MY SX SY SS.
- Bombe : sol teste des 2 cotes, portee par les plateformes mobiles (bomb_plat), s arrete en atterrissant apres une chute.

## 2026-11-11 — v9 explosion sans gel
- Plaques cassees par une bombe : zone reconstruite en arriere-plan (bg_dirty/bg_apply), ecrans prepares gardes ; constructions en cours plus jamais abandonnees.

## 2026-11-11 — v10 plaques disparaissent tout de suite
- 3e ecran prepare (bgnext3) = ecran courant sans plaques B, applique instantanement a l explosion. NIVEAU.S tile_at : substitution des B pendant cette construction.

## 2026-11-11 — v11 ecrans pre-construits au chargement
- PREBUILD.S (nouveau) : tous les ecrans construits au chargement (PLEASE WAIT / UNDER CONSTRUCTION + barre). Niveau 1 ~7,7 Mo. Sans assez de memoire (4 Mo) : mode arriere-plan. PRE_MODE=0 dans PARAMS.S pour desactiver.
