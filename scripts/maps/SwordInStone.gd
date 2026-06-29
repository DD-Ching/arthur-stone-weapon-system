class_name SwordInStone
extends BattleMap
## The Sword in the Stone — Arthur's origin trial, built on the reusable BattleMap base.
##
## A churchyard/courtyard with the famous SWORD-IN-THE-STONE at its centre. Arthur has just
## lifted the WHOLE STONE; rival lords and knights refuse to believe a boy is king and ride in
## to challenge him. He stands by the stone with a small loyal retinue (Camelot gold) while
## escalating waves of doubting knights and lords (Mordred's rebels, purple) close in.
##
## This is a THIN subclass — it only overrides the build hooks (walls + the churchyard frame,
## decor for the anvil-stone, allies, waves, objectives, theme). All orchestration — Arthur,
## HUD, score, wave driving, win/lose — lives in BattleMap and is never re-implemented here.
##
## Build once, reuse many: the chapel ruins are plain `_wall()` rectangles; the waves are `Wave`
## resources composed in code (doubting knights → shields → spears+heavies → a rival lord's
## OfficerGuard); objectives are the shared RepelWaves + DefeatOfficer; every raider is tinted
## "rebel" as its wave lands.

const SHIELD_WALL := preload("res://scenes/formations/ShieldWall.tscn")
const SPEAR_PHALANX := preload("res://scenes/formations/SpearPhalanx.tscn")
const OFFICER_GUARD := preload("res://scenes/formations/OfficerGuard.tscn")
const SHIELD_SOLDIER := preload("res://scenes/ShieldSoldier.tscn")
const SPEARMAN := preload("res://scenes/Spearman.tscn")
const HEAVY_GUARD := preload("res://scenes/HeavyGuard.tscn")
const ALLY_KNIGHT := preload("res://scenes/AllyKnight.tscn")
const ALLY := preload("res://scenes/Ally.tscn")

const SWORD_EMBLEM := preload("res://scenes/decor/SwordInStone.tscn")
const CAMELOT_BANNER := preload("res://scenes/decor/CamelotBanner.tscn")
const TORCH := preload("res://scenes/decor/Torch.tscn")
const BRAZIER := preload("res://scenes/decor/Brazier.tscn")

# ── theme ─────────────────────────────────────────────────────────────────────
## The Churchyard at grey dawn: cold flagstone underfoot, a cool dawn light over the courtyard.
## Set FIRST in _ready so the floor + mood are themed from frame 0 (pure — just sets fields).
func _theme() -> void:
	ground_top = Color(0.20, 0.20, 0.23)        # grey stone, lit edge
	ground_bottom = Color(0.16, 0.16, 0.18)     # grey stone, shadowed
	region_mood = Color(0.82, 0.84, 0.95)       # a subtle cool dawn tint (channels stay >= 0.6)

func _map_title() -> String:
	return "THE SWORD IN THE STONE"

func _opening_banner() -> String:
	return "PROVE YOU ARE KING!"

func _arthur_start() -> Vector2:
	# Just below the stone, facing the doubting knights who ride in from above.
	return Vector2(0.0, 150.0)

func _world_bounds() -> Rect2:
	return Rect2(-640.0, -440.0, 1280.0, 900.0)

# ── walls: a low churchyard frame + a couple of interior chapel/wall bits ──────
func _build_walls() -> void:
	var b := _world_bounds()
	_frame_walls(b)
	var t := 24.0
	# A ruined chapel back wall near the top with a central doorway gap the knights file through.
	var chapel_y := b.position.y + 130.0
	var door := 160.0
	var left_w: float = (-door * 0.5) - b.position.x
	_wall(Rect2(b.position.x, chapel_y, left_w, t))
	var right_x := door * 0.5
	_wall(Rect2(right_x, chapel_y, b.end.x - right_x, t))
	# Two short side buttresses lower in the courtyard, framing the duelling ground without
	# boxing Arthur in (the round-table feel: open centre, stone columns to the flanks).
	var col_y := -40.0
	_wall(Rect2(b.position.x + 150.0, col_y, t, 150.0))
	_wall(Rect2(b.end.x - 150.0 - t, col_y, t, 150.0))

# ── allies: a small loyal Camelot retinue rallies around the stone ────────────
func _spawn_allies() -> void:
	# A few loyal squires/knights of Camelot, gold-tinted, flanking the stone below Arthur.
	var spots := [
		Vector2(-120.0, 230.0), Vector2(120.0, 230.0),
		Vector2(-60.0, 290.0), Vector2(60.0, 290.0),
	]
	var roster := [ALLY_KNIGHT, ALLY, ALLY, ALLY_KNIGHT]
	for i in range(spots.size()):
		var scene: PackedScene = roster[i]
		var u = scene.instantiate()
		u.position = spots[i]
		add_child(u)
		if "faction" in u:
			u.faction = "camelot"

# ── objectives: repel every challenger, defeat the rival lord ─────────────────
func _compose_objectives() -> ObjectiveManager:
	var mgr := ObjectiveManager.new()
	mgr.add(RepelWavesObjective.new("Repel the doubting lords"))
	mgr.add(DefeatOfficerObjective.new("Defeat the rival lord"))
	return mgr

# ── waves: 5 escalating challenges of doubting knights, ending on a rival lord ─
func _build_wave_spawner() -> WaveSpawner:
	var ws := WaveSpawner.new()
	var lane: float = _world_bounds().position.y + 70.0   # spawn above the chapel, march down
	ws.waves = [
		_loose_wave("DOUBTING KNIGHTS", SHIELD_SOLDIER, _scale(5), lane),
		_formation_wave("SHIELD WALL", SHIELD_WALL, lane),
		_loose_wave("RIVAL CHALLENGERS", ALLY_KNIGHT, _scale(4), lane),
		_formation_wave("SPEARS & HEAVIES", SPEAR_PHALANX, lane),
		_formation_wave("THE RIVAL LORD'S GUARD", OFFICER_GUARD, lane),
	]
	return ws

func _loose_wave(label: String, scene: PackedScene, count: int, lane: float) -> Wave:
	var w := Wave.new()
	w.label = label
	var arr: Array[PackedScene] = [scene]
	w.scenes = arr
	w.count = count
	w.lane_y = lane
	# File in through the chapel doorway near the centre.
	w.x_min = -80.0
	w.x_max = 80.0
	w.team = "raiders"
	return w

func _formation_wave(label: String, formation: PackedScene, lane: float) -> Wave:
	var w := Wave.new()
	w.label = label
	w.formation = formation
	w.lane_y = lane
	w.x_min = -10.0
	w.x_max = 10.0
	w.team = "raiders"
	return w

# ── tint every challenger Mordred-rebel purple as their wave lands ────────────
func _on_wave_spawned(idx: int, units: Array) -> void:
	super._on_wave_spawned(idx, units)
	for u in units:
		if is_instance_valid(u) and "faction" in u:
			u.faction = "rebel"

# ── decor: the stone-and-sword emblem at centre + churchyard dressing ─────────
## Distant chapel skyline + drifting dawn mist + the legend's stone-and-sword and a Camelot
## standard, plus a little torch/brazier light. Static motifs (flagstone seams, headstones,
## the ruined chapel-wall stubs) are painted by _paint_region behind the units.
func _build_decor() -> void:
	super._build_decor()
	var b := _world_bounds()
	# (1) A distant CHAPEL skyline along the world's top edge — cool slate against a cool haze, so
	# the churchyard reads as having a chapel beyond the back wall the knights file through.
	var bd := RegionBackdrop.new()
	bd.kind = "chapel"
	bd.span = b.size.x
	bd.silhouette = Color(0.13, 0.14, 0.18, 0.9)
	bd.haze_top = Color(0.62, 0.66, 0.78, 0.45)
	bd.haze_bottom = Color(0.62, 0.66, 0.78, 0.0)
	add_child(bd)
	bd.position = Vector2((b.position.x + b.end.x) * 0.5, b.position.y)
	# (2) Gentle grey-dawn MIST drifting across the courtyard.
	var ad := AmbientDrift.new()
	ad.kind = "mist"
	ad.count = 30
	ad.area = b
	ad.tint = Color(0.7, 0.75, 0.85, 0.35)
	ad.drift = Vector2(10.0, -4.0)
	ad.size_px = 3.0
	add_child(ad)
	# (3) The legend itself: the stone-and-sword emblem at the very centre of the courtyard (the
	# centre stone spot), scaled up to read as the duelling-ground centrepiece.
	var emblem := _spawn_prop(SWORD_EMBLEM, Vector2.ZERO)
	if emblem and "stone_size" in emblem:
		emblem.stone_size = 58.0
	# (4) A Camelot standard planted beside the stone (our side).
	var banner = _spawn_prop(CAMELOT_BANNER, Vector2(96.0, 18.0))
	if banner and "faction" in banner:
		banner.faction = "camelot"
	if banner and "pole_height" in banner:
		banner.pole_height = 86.0
	# (5) A little light around the shrine: braziers flank the stone, torches mark the side columns.
	_spawn_prop(BRAZIER, Vector2(-110.0, -30.0))
	_spawn_prop(BRAZIER, Vector2(110.0, -30.0))
	_spawn_prop(TORCH, Vector2(b.position.x + 150.0, -50.0))
	_spawn_prop(TORCH, Vector2(b.end.x - 150.0, -50.0))

## Static churchyard ground motifs, painted over the floor and behind the units: large flagstone
## slabs (faint warm-grey seams), the ruined chapel back-wall stubs by the doorway, and a few
## headstones flanking the duelling ground.
func _paint_region(b: Rect2) -> void:
	# Faint flagstone seams — a coarse grid of large slabs across the courtyard floor.
	var seam := Color(0.55, 0.53, 0.50, 0.10)
	var slab := 168.0
	var x := b.position.x + slab
	while x < b.end.x:
		draw_line(Vector2(x, b.position.y), Vector2(x, b.end.y), seam, 2.0)
		x += slab
	var y := b.position.y + slab
	while y < b.end.y:
		draw_line(Vector2(b.position.x, y), Vector2(b.end.x, y), seam, 2.0)
		y += slab
	# Ruined chapel back-wall stubs framing the doorway the knights file through.
	var chapel_y := b.position.y + 130.0
	var stone := Color(0.24, 0.22, 0.22)
	draw_rect(Rect2(b.position.x + 20.0, chapel_y - 26.0, 60.0, 26.0), stone)
	draw_rect(Rect2(b.end.x - 80.0, chapel_y - 26.0, 60.0, 26.0), stone)
	# Churchyard headstones flanking the duelling ground (small dark rects).
	for hx in [-300.0, -240.0, 240.0, 300.0]:
		draw_rect(Rect2(hx - 11.0, 70.0, 22.0, 38.0), Color(0.27, 0.27, 0.30))
		draw_rect(Rect2(hx - 15.0, 104.0, 30.0, 7.0), Color(0.20, 0.20, 0.22))
