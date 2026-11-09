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
