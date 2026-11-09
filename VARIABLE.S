;=====================================================================
; VARIABLE.S - VARIABLES (BSS area)
;   (included by RICK3D.S ; the settings are in PARAMS.S)
;=====================================================================

old_ssp:        ds.l    1
old_phys:       ds.l    1
old_log:        ds.l    1
old_mode:       ds.w    1
new_mode:       ds.w    1
phys_off:       ds.l    1
txt_y:          ds.w    1
clip_y0:        ds.w    1
clip_y1:        ds.w    1
scr_mem:        ds.l    1
scr0:           ds.l    1
scr1:           ds.l    1
cur_back:       ds.w    1
rp_off:         ds.w    SCR_W           ; rect_pat : pattern column of each pixel
up_lock:        ds.w    1               ; up held since the ladder : no jump
bvx_on:         ds.w    1               ; back view : drawn extents noted
bvx_cur:        ds.l    1               ;  (extents of the current screen)
bvx_ext:        ds.l    2*BVX_N         ;  x0,x1 per band of 8 lines, 2 screens
old_acia:       ds.l    1
pkt_cnt:        ds.w    1
pkt_dst:        ds.l    1
keyw:           ds.w    1
keyr:           ds.w    1
keyring:        ds.b    16
keytab:         ds.b    128
joy0:           ds.b    1
joy1:           ds.b    1
                even
fire_old:       ds.w    1                       ; 0 / 1 laser / 2 bomb
rick_dir:       ds.w    1                       ; 1 = right, -1 = left
rick_dead:      ds.w    1
las_on:         ds.w    1
las_x:          ds.w    1
las_y:          ds.w    1
las_dir:        ds.w    1
bomb_st:        ds.w    1                       ; 0 / 1 fuse / 2 explosion
bomb_t:         ds.w    1
bomb_vx:        ds.w    1                       ; thrown bomb : speed
bomb_x:         ds.w    1
bomb_y:         ds.w    1
ammo_las:       ds.w    1
stick_t:        ds.w    1                       ; stick (frames left)
rail_c:         ds.b    1
                even
lift_in:        ds.w    1                       ; up (1) / down (2) on a lift
rick_onplat:    ds.w    1                       ; platform under Rick (-1)
plat_hit:       ds.w    1
nplats:         ds.w    1
nsw:            ds.w    1
plats:          ds.b    MAXPL*PL_SIZE
nlz:            ds.w    1
nzp:            ds.w    1
zp_ph:          ds.w    1
zp_mode:        ds.w    1
items_dirty:    ds.w    1
zaps:           ds.b    MAXZP*ZP_SIZE
dead_t:         ds.w    1
invul_t:        ds.w    1
lz_cool:        ds.w    1
lasers:         ds.b    MAXLZ*LZ_SIZE
switches:       ds.b    MAXSW*SW_SIZE
ammo_bomb:      ds.w    1
sfx_ch:         ds.b    3*CH_SIZE               ; state of the 3 YM voices
quit_flag:      ds.w    1
need_rebuild:   ds.w    1
rick_xf:        ds.w    1                       ; x * 8 (level)
on_ladder:      ds.w    1
rk_h:         ds.w    1                       ; height (20 standing, 13 crouching)
rk_h2:        ds.w    1                       ; half
walk_ph:        ds.w    1                       ; animation phases
climb_ph:       ds.w    1
an_sl:          ds.w    1                       ; legs : step
an_lf:          ds.w    1                       ;   lifts front leg
an_lb:          ds.w    1                       ;   lifts back leg
an_la:          ds.w    1                       ; ladder : leg / arm A
an_lb2:         ds.w    1                       ;   leg / arm B
an_mir:         ds.w    1
lev_w:          ds.w    1                       ; map (tiles)
lev_h:          ds.w    1
st_col:         ds.w    1                       ; Rick's start
st_row:         ds.w    1
end_col:        ds.w    1                       ; end of the level (F line) : top-left
end_row:        ds.w    1                       ;  cell of Rick (col -1 = none)
end_t:          ds.w    1                       ; level finished : frames before the restart
lvlerr:         ds.w    1
win_tx:         ds.w    1                       ; current screen (tiles)
win_ty:         ds.w    1
win_ox:         ds.w    1                       ; world X = x - win_ox
win_oy:         ds.w    1
cp_xf:          ds.w    1                       ; respawn point
cp_yf:          ds.w    1
rick_yf:        ds.w    1                       ; y * 8 (level)
rick_vy:        ds.w    1
on_ground:      ds.w    1
rlist0:         ds.b    L_SIZE                  ; drawn rectangles (screen 0)
rlist1:         ds.b    L_SIZE
cur_list:       ds.l    1
bb_x0:          ds.w    1
bb_y0:          ds.w    1
bb_x1:          ds.w    1
bb_y1:          ds.w    1
fq_miny:        ds.w    1
fq_maxy:        ds.w    1
quad2d:         ds.w    8
q3d:            ds.w    12
xl_tab:         ds.w    SCR_H
xr_tab:         ds.w    SCR_H
; text
fontfirst:      ds.w    1
fontoff:        ds.l    1
fontdat:        ds.l    1
fontw:          ds.w    1
txt_hidden:     ds.w    1
fps:            ds.w    1
fpscnt:         ds.w    1
fpsclk:         ds.l    1
numbuf:         ds.b    16
linebuf:        ds.b    2*LINEW
txts0:          ds.b    TXTST                   ; text state of scr0
txts1:          ds.b    TXTST                   ; text state of scr1
huds0:          ds.w    6                       ; HUD state : shown, lives, laser, bombs, score (long)
huds1:          ds.w    6
score:          ds.l    1                       ; points (6 digits at the top)
lives:          ds.w    1
hdr_lines:      ds.w    1                       ; lines of the .MAP before the map
                even
; music
dspok:          ds.w    1
playing:        ds.w    1
paused:         ds.w    1
musok:          ds.w    1
muserr:         ds.w    1
sndh:           ds.w    1
mastervol:      ds.w    1
nmods:          ds.w    1
curmod:         ds.w    1
initres:        ds.l    1
modbase:        ds.l    1
modlen:         ds.l    1
dta:            ds.b    44
modnames:       ds.b    MAXMODS*NAMESZ
pathbuf:        ds.b    32
old_stpal:      ds.w    16
old_pal:        ds.l    256
bgbuf:          ds.w    SCR_W*SCR_H
bgold:          ds.w    SCR_W*SCR_H     ; previous scenery (scrolling)
sc_glide:       ds.w    1               ; current step (tiles, +/-)
sc_s:           ds.w    1
sc_p:           ds.w    1
sc_y1:          ds.w    1
sc_k:           ds.w    1
sc_ox:          ds.w    1
sc_oy:          ds.w    1
sc_d:           ds.w    1
sc_vglide:      ds.w    1               ; vertical step (rows, +/-)
sc_px:          ds.w    1
sc_mv:          ds.w    1
sc_on:          ds.w    1               ; 1 = scrolling (G key)
levmap:         ds.b    LEV_MAX
                even
brk_stack:      ds.l    BRK_MAX
                even
filebuf:        ds.b    FILE_MAX
                even
sw_y0:          ds.w    1               ; buttons : drawing height
pipe_fl:        ds.w    1               ; pipes : neighbours of the current tile
inf_lives:      ds.w    1               ; infinite lives (I key), for testing
box_tex:        ds.l    1               ; 8x8 drawing of the front face (0 = plain colour)
mdl_fl:         ds.w    1               ; draw_model : transformation
mdl_ox:         ds.w    1               ;  origin
mdl_oy:         ds.w    1
sw_mir:         ds.w    1               ; button : mirror
mdl_nb:         ds.w    1               ; draw_model : neighbours (model frame)
savbuf:         ds.b    SV_SIZE         ; RICK3D.SAV (position + scores)
savbuf2:        ds.b    SV_SIZE         ; reading
                even
view_back:      ds.w    1               ; 1 = back view (V key)
bv_dir:         ds.w    1               ; direction of the look (+1 / -1)
bv_cx:          ds.w    1               ; camera (centred coordinates, side view)
bv_cy:          ds.w    1
bv_rc:          ds.w    1               ; Rick's column
bv_fr:          ds.w    1               ; row of his feet
bv_floor:       ds.w    1
rk_pass:        ds.w    1
rk_mdl:         ds.l    1
bv_nofront:     ds.w    1
bv_col:         ds.w    1
bv_r0:          ds.w    1
bv_r1:          ds.w    1
bv_run:         ds.w    1
bv_rset:        ds.l    1
bv_clr:         ds.w    1
bv_far:         ds.w    1
bv_nf2:         ds.w    1
bv_fz0:         ds.w    1
bv_fz1:         ds.w    1
bv_zcol:        ds.w    4
bv_in:          ds.w    1
bv_rec:         ds.w    1
bv_nrec:        ds.w    1
bv_recs:        ds.b    24*BV_MAXR
bv_sk:          ds.w    1
bv_clk:         ds.l    1
bv_steps:       ds.w    1
bv_bill:        ds.w    1
bv_bx:          ds.w    1
bv_cpat:        ds.l    1
bv_rpat:        ds.l    1
bv_rtop:        ds.w    1
bv_rbot:        ds.w    1
bv_ok:          ds.w    1
bv_cls:         ds.b    256
bv_ch:          ds.w    1
sv_ok:          ds.w    1               ; position saved (R key) ?
sv_x:           ds.w    1
sv_feet:        ds.w    1
msg_t:          ds.w    1               ; message in the bar (frames)
msg_ptr:        ds.l    1
wn_x0:          ds.w    1               ; current porthole : frame (world)
wn_y0:          ds.w    1
wn_x1:          ds.w    1
wn_y1:          ds.w    1
wn_hx0:         ds.w    1               ;  glass
wn_hy0:         ds.w    1
wn_hx1:         ds.w    1
wn_hy1:         ds.w    1
wn_hw:          ds.w    1
wn_hh:          ds.w    1
wn_seed:        ds.w    1
wn_zd:          ds.w    1               ;  back plane (ZB + wn_dep)
wn_ro:          ds.w    1               ;  rivets : margin, length, intervals
wn_span:        ds.w    1
wn_n:           ds.w    1
wn_i:           ds.w    1
