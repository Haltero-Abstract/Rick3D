# -*- coding: utf-8 -*-
"""
MAPCONV.PY - convertit les plans du niveau (images PNG, tuiles de 8x8)
en fichier texte de niveau pour RICK3D (LEVEL\\LEVEL1.MAP).

Chaque tuile 8x8 de l'image est classee d'apres ses couleurs :
  #  roche / exterieur (hachures)          -> bloc plein
  F  cadre metallique a rivets             -> bloc plein
  .  interieur (mur du fond)               -> vide
  k  interieur sombre (fond noir)          -> vide
  =  passerelle orange                     -> plateforme (on monte dessus)
  -  barre metallique                      -> plateforme
  G  poutre verte                          -> plateforme
  X  pylone en treillis du parc            -> decor (Rick passe devant)
  H  echelle                               -> echelle
Les sprites (Rick, ennemis), consoles, lampes... deviennent du vide.

Usage : python MAPCONV.PY <dossier des PNG> <sortie.MAP> [apercu.png]
"""
import sys, os
from collections import Counter
from PIL import Image

NAMES = {(33,165,33):'G',(0,99,66):'g',(0,0,0):'k',(231,198,99):'Y',(66,66,99):'d',
         (99,99,132):'m',(198,198,231):'W',(132,132,165):'l',(99,66,0):'b',(198,99,0):'o',
         (165,66,66):'r',(198,66,0):'R',(231,132,99):'s',(33,66,231):'B',(33,132,231):'c'}

# morceaux du plan : fichier, colonne, ligne (en tuiles) dans le niveau
PARTS = [('hp4a', 0, 192), ('hp4', 32, 104), ('hp2', 64, 0),
         ('hp3', 96, 116), ('hp3a', 128, 166)]
W, H = 160, 256
START = (35, 248)
NOLADDER = [(122, 189, 2, 3),   # faux barreaux (compteur mal reconnu)
            (39, 182, 1, 2),    # (robot au pied de l'echelle)
            (84, 9, 6, 3)]      # cadre de la fenetre du chef (eclairs jaunes)
LADDER = [(37, 182, 2, 2)]      # bas d'echelle cache par le robot
MAST = [(61, 166, 2, 2)]        # bas du ressort (tube clair)
DECOR = [(45, 181, 1, 2),       # tube vert (decor, pas une poutre)
         (105, 252, 1, 2),      # bonbonne verte du parc
         (86, 78, 1, 1), (69, 194, 1, 1), (119, 253, 1, 1), (134, 170, 1, 1)]  # bonbonnes de bombes (lignes D)
STOOLS = [(112, 205, 2, 3)]
STOOLSD = [(80, 225, 2, 3), (82, 225, 2, 3)]   # tabourets de decor (on passe dessous l'onde)
SOLID = []
BREAK = [(92, 252, 3, 2), (32, 210, 3, 2), (40, 166, 3, 2), (52, 166, 3, 2),
         (112, 178, 3, 2), (118, 178, 3, 2), (64, 214, 3, 2)]   # plaques : sautent a la bombe ('B')
BARS = []
# vis des ascenseurs (l'ascenseur = ligne P ... L dans la carte)
SCREWS = [(37, 196, 219), (61, 155, 167), (69, 173, 187), (89, 135, 151), (101, 208, 219)]
SCREWH = [(112, 125, 9),         # vis horizontales (ascenseur qui va de cote)
          (37, 213, 19)]          #  (au-dessus du sol electrifie)  # col, rangee, largeur, hauteur (releves a la main)        # tuile du coin haut-gauche de Rick au depart (parc)

def classify(c):
    """c = Counter des couleurs d'une tuile -> classe brute"""
    top = [k for k, _ in c.most_common(3)]
    n = lambda *ks: sum(c[k] for k in ks)
    if set(c) <= {'m', 'l'}:
        return '#'
    if top[0] == 'm' and 'W' in top and c['W'] >= 8:
        return 'F'
    if n('R', 'b') >= 20:
        return 'o'                       # orange : passerelle ou decor (tri plus loin)
    if c['Y'] >= 6 and c['o'] >= 6 and n('R', 'b') < 8 and c['s'] < 10 and c['k'] >= 10:
        return 'h'                       # echelle probable
    if c['W'] >= 8 and c['k'] >= 6 and top[0] in 'klW' and c['B'] + c['c'] < 6 \
       and c['G'] + c['Y'] >= 2:
        return '-'                       # barre metallique (voyants verts)
    if c['G'] >= 4 and c['W'] + c['l'] + c['m'] >= 24 and c['k'] >= 12:
        return '-'                       # tube a voyants verts (on monte dessus)
    if c['k'] >= 26 and c['d'] < 8 and c['G'] < 12:
        return 'k'                       # ciel etoile, arbres sombres
    if n('G', 'g') >= 24 and c['G'] >= 12:
        return 'G'
    if c['k'] >= 40:
        return 'k'
    return '.'

def tilebytes(im, x, y):
    return bytes(sum((im.getpixel((x*8+i, y*8+j)) for j in range(8) for i in range(8)), ()))

def convert(src):
    # ressort / mat a grimper : motif exact releve dans hp2 (colonne 25)
    ref = Image.open(os.path.join(src, 'hp2_BJtw.png')).convert('RGB')
    coil = {tilebytes(ref, 25, 140), tilebytes(ref, 25, 141)}
    # echelles fines grises (hp3, colonnes 12-13)
    ref3 = Image.open(os.path.join(src, 'hp3_BJtw.png')).convert('RGB')
    coil |= {tilebytes(ref3, x, y) for x in (12, 13) for y in (2, 3)}
    coils = []
    # tonneaux : motifs exacts releves dans hp4 (colonnes 24-27, rangees 36-39)
    ref4 = Image.open(os.path.join(src, 'hp4_BJtw.png')).convert('RGB')
    barrel = {tilebytes(ref4, x, y) for x in range(24, 28) for y in range(36, 40)}
    barrels = []
    raw = [['#'] * W for _ in range(H)]
    cnts = [[None] * W for _ in range(H)]
    for name, cx, cy in PARTS:
        im = Image.open(os.path.join(src, name + '_BJtw.png')).convert('RGB')
        tw, th = im.size[0] // 8, im.size[1] // 8
        px = im.load()
        for ty in range(th):
            for tx in range(tw):
                c = Counter(NAMES[px[tx*8+i, ty*8+j]] for i in range(8) for j in range(8))
                raw[cy+ty][cx+tx] = classify(c)
                cnts[cy+ty][cx+tx] = c
                tb = tilebytes(im, tx, ty)
                if tb in coil:
                    coils.append((cx+tx, cy+ty))
                elif tb in barrel:
                    barrels.append((cx+tx, cy+ty))
    m = [row[:] for row in raw]
    # passerelles : tuile orange posee sur une 2e rangee orange, en ligne de 3+
    for y in range(H - 1):
        x = 0
        while x < W:
            ok = lambda xx: (raw[y][xx] == 'o' and raw[y+1][xx] == 'o') or raw[y][xx] == 'h'
            if raw[y][x] == 'o' and raw[y+1][x] == 'o':
                x0 = x
                while x < W and ok(x):          # (une echelle peut traverser)
                    x += 1
                xs = [i for i in range(x0, x) if raw[y][i] == 'o']
                if len(xs) >= 3:
                    for i in xs:
                        m[y][i] = '='
                        m[y+1][i] = 'w'          # dessous de passerelle (vide)
            else:
                x += 1
    for y in range(H):
        for x in range(W):
            if m[y][x] == 'o':
                m[y][x] = '.'                    # orange isole : decor
            elif m[y][x] == 'w':
                m[y][x] = '.'
    # echelles : colonnes de 'h' (trous de 1-2 tuiles bouches : sprites)
    for x in range(W):
        y = 0
        while y < H:
            if raw[y][x] == 'h':
                y0 = y
                while y < H and (raw[y][x] == 'h' or
                                 (y + 2 < H and raw[y][x] in '.k=o' and
                                  ('h' in (raw[y+1][x], raw[y+2][x])))):
                    y += 1
                if y - y0 >= 3:
                    for i in range(y0, y):
                        m[i][x] = 'H'
                else:
                    for i in range(y0, y):
                        if m[i][x] == 'h':
                            m[i][x] = '.'
            else:
                y += 1
    for y in range(H):
        for x in range(W):
            if m[y][x] == 'h':
                m[y][x] = '.'
    # barres : 1 tuile d'epaisseur, au moins 2 de long (sinon tuyau, decor)
    bar = [[m[y][x] == '-' for x in range(W)] for y in range(H)]
    for y in range(H):
        for x in range(W):
            if bar[y][x]:
                thin = not (y > 0 and bar[y-1][x]) and not (y + 1 < H and bar[y+1][x])
                long_ = (x > 0 and bar[y][x-1]) or (x + 1 < W and bar[y][x+1])
                if not (thin and long_):
                    m[y][x] = '.'
    # bouts des barres (embouts a boulons) : on prolonge d'une tuile
    for y in range(H):
        for x in range(1, W - 1):
            if m[y][x] == '-':
                for xx in (x - 1, x + 1):
                    c = cnts[y][xx]
                    if m[y][xx] in '.k' and c and c['W'] + c['l'] >= 12 \
                       and (m[y][xx - 1] if xx < x else m[y][xx + 1]) != '-':
                        m[y][xx] = '+'
    for y in range(H):
        for x in range(W):
            if m[y][x] == '+':
                m[y][x] = '-'
    # une echelle fait 2 tuiles de large : colonne isolee -> on double
    for y in range(H):
        for x in range(W - 1):
            if m[y][x] == 'H' and m[y][x+1] not in 'H#F' and (x == 0 or m[y][x-1] != 'H'):
                if x + 1 < W and m[y][x+1] in '.k':
                    m[y][x+1] = 'H'
    # pelouse du parc (2 dernieres rangees) : sol plein 'g'
    for y in (H - 2, H - 1):
        for x in range(W):
            if m[y][x] not in 'H#F':
                m[y][x] = 'g'
    # mats a grimper -> 'M' (comme une echelle, autre couleur), prolonges
    # vers le bas jusqu'au sol, 2 tuiles de large (cote libre), et un palier
    # de chaque cote de leur sommet (le haut du mat sert aussi de sol)
    for x, y in coils:
        m[y][x] = 'M'
    for x, y in coils:
        yy = y + 1
        while yy < H and m[yy][x] in '.k' and not (
                cnts[yy][x] and cnts[yy][x]['W'] + cnts[yy][x]['l'] >= 12):   # (gros tuyau)
            m[yy][x] = 'M'
            yy += 1
    cols = {}
    for x, y in coils:
        cols.setdefault(x, []).append(y)
    done = set()
    for x, ys in cols.items():
        if x in done:
            continue
        ys.sort()
        y0 = ys[0]
        for y in ys:
            if y != y0 and m[y - 1][x] != 'M':
                y0 = y
        starts = sorted({y for y in ys if y == 0 or m[y - 1][x] != 'M'})
        for y0 in starts:
            y1 = y0
            while y1 + 1 < H and m[y1 + 1][x] == 'M':
                y1 += 1
            if x + 1 in cols or x - 1 in cols:   # deja 2 de large
                s_ = 1 if x + 1 in cols else -1
                done.add(x + s_)
            else:
                free = lambda xx: sum(1 for y in range(y0, y1 + 1) if m[y][xx] in '.k-M')
                s_ = 1 if free(x + 1) >= free(x - 1) else -1
                for y in range(y0, y1 + 1):
                    if m[y][x + s_] in '.k-':
                        m[y][x + s_] = 'M'
            xa = min(x, x + s_)
            yt = y0 - 1                      # sommet : une rangee plus haut
            if yt >= 0 and m[yt][x] in '.k-' and m[yt][x + s_] in '.k-':
                m[yt][xa] = m[yt][xa + 1] = 'M'
                for xx in (xa - 1, xa + 2):
                    if m[yt][xx] in '.k':
                        m[yt][xx] = '-'
    # pylones en treillis du parc (pieds de soucoupe) : 'X', decor seul.
    # Chaque groupe de 'G' des 12 dernieres rangees -> son rectangle.
    seen = set()
    for y in range(H - 12, H):
        for x in range(W):
            if m[y][x] == 'G' and (x, y) not in seen:
                pile, grp = [(x, y)], []
                seen.add((x, y))
                while pile:
                    a, b = pile.pop()
                    grp.append((a, b))
                    for na, nb in ((a+1, b), (a-1, b), (a, b+1), (a, b-1)):
                        if 0 <= na < W and H - 12 <= nb < H and m[nb][na] == 'G' and (na, nb) not in seen:
                            seen.add((na, nb))
                            pile.append((na, nb))
                xs = [a for a, _ in grp]
                ys = [b for _, b in grp]
                for b in range(min(ys), max(ys) + 1):
                    for a in range(min(xs), max(xs) + 1):
                        if m[b][a] in 'G.k':
                            m[b][a] = 'X'
    # bonbonnes / tubes a liquide vert : couvercle cuivre ou metal au-dessus
    # d'une petite colonne de 'G' (3 tuiles au plus) -> decor
    for x in range(W):
        y = 0
        while y < H:
            if m[y][x] == 'G':
                y0 = y
                while y < H and m[y][x] == 'G':
                    y += 1
                c = cnts[y0 - 1][x] if y0 > 0 else None
                lone = all(m[i][x - 1] != 'G' and m[i][x + 1] != 'G' for i in range(y0, y)
                           if 0 < x < W - 1)
                cs = cnts[y0][x]
                cap = (c and (c['o'] + c['s'] >= 4 or c['W'] + c['l'] >= 12)) or \
                      (cs and cs['o'] + cs['s'] >= 4)
                if y - y0 <= 3 and lone and cap:
                    for i in range(y0, y):
                        m[i][x] = '.'
            else:
                y += 1
    # tours en treillis dans les batiments : colonnes de 'G' de 2 de large
    # (suite horizontale de 2 exactement, avec du 'G' dessus ou dessous)
    for y in range(H):
        x = 0
        while x < W:
            if m[y][x] == 'G':
                x0 = x
                while x < W and m[y][x] == 'G':
                    x += 1
                if x - x0 == 2 and any(0 <= yy < H and m[yy][xx] in 'GX'
                                       for xx in (x0, x0 + 1) for yy in (y - 1, y + 1)):
                    m[y][x0] = m[y][x0 + 1] = 'X'
            else:
                x += 1
    for y in range(H - 2, -1, -1):           # bouts isoles au sommet
        for x in range(W):
            if m[y][x] == 'G' and m[y + 1][x] == 'X' and \
               (x == 0 or m[y][x - 1] != 'G') and (x + 1 >= W or m[y][x + 1] != 'G'):
                m[y][x] = 'X'
    # pylones : 'x' dans le parc (ciel noir derriere), 'X' dans les
    # batiments (mur du fond derriere) ; l'ombre noire dessinee a cote
    # des tours dans l'original devient du mur (l'ombre reste sur le fond)
    for y in range(H):
        for x in range(W):
            if m[y][x] == 'X':
                if y >= H - 12:
                    m[y][x] = 'x'
                else:
                    for xx in (x - 1, x + 1):
                        if 0 <= xx < W and m[y][xx] == 'k':
                            m[y][xx] = '.'
    for x0, y0, w, h in NOLADDER:
        for y in range(y0, y0 + h):
            for x in range(x0, x0 + w):
                if m[y][x] == 'H':
                    m[y][x] = '.'
    for x0, y0, w, h in LADDER:
        for y in range(y0, y0 + h):
            for x in range(x0, x0 + w):
                m[y][x] = 'H'
    for lst, ch in ((SOLID, 'F'), (BREAK, 'B'), (BARS, '-')):
        for x0, y0, w, h in lst:
            for y in range(y0, y0 + h):
                for x in range(x0, x0 + w):
                    m[y][x] = ch
    for x0, y0, w, h in MAST:
        for y in range(y0, y0 + h):
            for x in range(x0, x0 + w):
                m[y][x] = 'M'
    for x0, y0, y1 in SCREWS:
        for y in range(y0, y1 + 1):
            if m[y][x0] == 'M':       # un seul axe de vis
                m[y][x0] = 'V'
            if m[y][x0 + 1] == 'M':
                m[y][x0 + 1] = '.'
        for y in (y0 - 1, y0, y1, y1 + 1):  # (le tube = l'ascenseur)
            for x in range(x0 - 2, x0 + 4):
                if m[y][x] == '-':
                    m[y][x] = '.'
    for x0, y0, w in SCREWH:
        for x in range(x0, x0 + w):
            m[y0][x] = 'Q'
        for x in range(x0 + w, x0 + w + 3):
            if m[y0][x] == '-':
                m[y0][x] = '.'
    for x0, y0, w, h in DECOR:
        for y in range(y0, y0 + h):
            for x in range(x0, x0 + w):
                m[y][x] = '.'
    # tabourets orange (marchepied pour les tonneaux) : 'O' plein
    for x0, y0, w, h in STOOLS:
        for y in range(y0, y0 + h):
            for x in range(x0, x0 + w):
                m[y][x] = 'O'
    for x0, y0, w, h in STOOLSD:
        for y in range(y0, y0 + h):
            for x in range(x0, x0 + w):
                m[y][x] = 'o'
    # tonneaux : blocs pleins 'T'
    for x, y in barrels:
        m[y][x] = 'T'
    return m

COL = {'o': (160, 80, 20), 'V': (120, 120, 140), 'Q': (120, 120, 140), 'x': (120, 200, 60), 'O': (230, 110, 20), 'X': (120, 200, 60), 'M': (150, 150, 170), 'T': (200, 110, 30), 'g': (20, 120, 20), '#': (70, 70, 90), 'F': (200, 200, 230), '.': (40, 40, 60), 'k': (0, 0, 0),
       '=': (230, 120, 0), '-': (160, 160, 200), 'G': (30, 170, 30), 'H': (240, 220, 80)}

def preview(m, src, out):
    big = Image.new('RGB', (W * 8 * 2 + 16, H * 8), (255, 255, 255))
    for name, cx, cy in PARTS:
        big.paste(Image.open(os.path.join(src, name + '_BJtw.png')).convert('RGB'), (cx*8, cy*8))
    p = big.load()
    for y in range(H):
        for x in range(W):
            col = COL[m[y][x]]
            for j in range(8):
                for i in range(8):
                    p[W*8 + 16 + x*8 + i, y*8 + j] = col
    big.save(out)

if __name__ == '__main__':
    src, out = sys.argv[1], sys.argv[2]
    m = convert(src)
    # on garde les lignes ajoutees a la main apres la carte (P, S, ;)
    extra = []
    if os.path.exists(out):
        lines = open(out).read().split('\n')
        body = [l for l in lines if l.strip() and not l.startswith(';')]
        if len(body) > H + 1:
            extra = [l.rstrip('\r') for l in lines[lines.index(body[H]) + 1:] if l.strip()]
    if not extra:
        extra = ['; --- objets : P plateforme mobile, S bouton (voir LISEZMOI) ---',
                 '; P col ligne largeur dcol dligne vitesse A|B',
                 '; S col ligne numero_de_plateforme']
        extra += '; --- lasers de la soucoupe : L col rangee dx dy depart periode (dx 0 = vise Rick) ---\nL 37 240 0 2 20 240\nL 41 240 0 2 60 240\nL 45 240 0 2 100 240\nL 49 240 0 2 140 240\nL 53 240 0 2 180 240\nL 57 240 0 2 220 240\nL 72 240 0 2 40 200\nL 86 240 0 2 140 200'.split('\n')
        extra += ["; --- E col ligne : bonbonne d'energie (recharge les lasers)",
                  '; --- Z col ligne largeur hauteur : rayon laser fixe ; bouton : S col ligne 200+n (100+n = coupe le laser L n)',
                  'E 119 202',
                  '; rayon laser entre les deux barres (emetteur dans le mur), coupe par le bouton de gauche',
                  'Z 100 193 4 1', 'S 115 191 201',
                  '; bouton de droite = piege : le creneau du plafond tire sur Rick',
                  'L 121 184 0 2 30000 30000', 'S 124 191 308']
    with open(out, 'w', newline='\r\n') as f:
        f.write('; RICK3D - niveau 1 : HYDE PARK (genere par MAPCONV.PY)\n')
        f.write('; largeur hauteur depart_colonne depart_ligne (en tuiles de 8)\n')
        f.write('; # roche  F cadre  . fond  k fond noir  = passerelle  - barre\n')
        f.write('; G poutre verte  X pylone (decor)  H echelle  M mat  g pelouse  T tonneau  O tabouret\n')
        f.write('%d %d %d %d\n' % (W, H, START[0], START[1]))
        for row in m:
            f.write(''.join(row) + '\n')
        for l in extra:
            f.write(l + '\n')
    if len(sys.argv) > 3:
        preview(m, src, sys.argv[3])
    print('ok', out)
