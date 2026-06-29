class_name ChangbanMap
extends BattleMap
## The Long Road — an ESCORT / protect battle. Arthur shields the fleeing people of a sacked
## town (carried under a wounded knight's banner) while wave after wave of Saxon raiders crash
## down to cut them off on the road to Camelot. This is the mirror of Hold-the-Ford: there you
## held a line, here you keep ONE unit standing while it is hunted. Win by repelling every wave
## with the banner still alive; lose the instant the banner falls (the ProtectBanner constraint)
## — or if Arthur falls.
##
## A THIN subclass of BattleMap: all orchestration (Arthur, HUD, score screen, wave driving,
## objective ticking, win/lose) lives in the base. Here we only place the ward, script the
## escalating Saxon waves, compose the two objectives, and theme the text. Build once, reuse many.

const ALLY_KNIGHT := preload("res://scenes/AllyKnight.tscn")
const LIGHT := preload("res://scenes/LightSoldier.tscn")
const SPEARMAN := preload("res://scenes/Spearman.tscn")
const SHIELD := preload("res://scenes/ShieldSoldier.tscn")
const BRUTE := preload("res://scenes/Brute.tscn")

# ── flank scenery: existing reusable scenes, PLACED + CONFIGURED (no new art) ───
# Camelot rally banners + war drums crown the escort's rally points; shovable crates/rocks and
# fence rails litter the WINGS. Everything sits out past the spawn lane (|x| large) so the
# CENTRAL retreat corridor the banner flees down stays OPEN — never blocked by clutter, so the
# escort/ward path is clear. The data IS the scenery: adding more is editing the lists below.
const FACTION_BANNER := preload("res://scenes/decor/FactionBanner.tscn")
const WAR_DRUM := preload("res://scenes/decor/WarDrum.tscn")
const CRATE := preload("res://scenes/Crate.tscn")
const ROCK := preload("res://scenes/Rock.tscn")
const FENCE := preload("res://scenes/terrain/Fence.tscn")
const CAMELOT_BANNER := preload("res://scenes/decor/CamelotBanner.tscn")
const TORCH := preload("res://scenes/decor/Torch.tscn")

# ── region identity: a cold, rain-dark road through the far country toward Camelot ──
## Runs FIRST in _ready (before any build) so the floor + mood are themed from frame 0. The Long
## Road is a sodden flight under Saxon pursuit: rain-dark earth underfoot and a cold grey light
## washing the whole field. Kept subtle (every channel >= 0.6) so unit readability never suffers.
func _theme() -> void:
	ground_top = Color(0.16, 0.16, 0.15)      # rain-soaked dark earth, top of the gradient
	ground_bottom = Color(0.13, 0.13, 0.13)   # mud darkening toward the rally point
	region_mood = Color(0.74, 0.78, 0.84)     # cold, overcast rainy grey over the whole world

# ── theme ────────────────────────────────────────────────────────────────────
func _map_title() -> String:
	return "THE LONG ROAD"

func _opening_banner() -> String:
	return "PROTECT THE PEOPLE!"

func _arthur_start() -> Vector2:
	# Arthur stands just ahead of the ward, between it and the raiders pouring from the north.
	return Vector2(0.0, 200.0)

# ── allies: the one ward we must protect ─────────────────────────────────────
func _spawn_allies() -> void:
	# ONE allied ward — a wounded Camelot knight shepherding the fleeing people. The base watches
	# it via `_ward`: ctx `ward_alive` flips false the moment it dies, failing the ProtectBanner
	# constraint and losing the battle. It sits at the rally point behind Arthur.
	var ward = ALLY_KNIGHT.instantiate()
	add_child(ward)
	ward.global_position = Vector2(0.0, 320.0)
	if "faction" in ward:
		ward.faction = "camelot"
	if "enemy_name" in ward:
		ward.enemy_name = "Wounded Knight"
	_ward = ward

# ── decor: dress the FLANKS of the escort route, central retreat lane kept clear ─
func _build_decor() -> void:
	## Pure PLACEMENT + config of existing reusable scenes along the escort route. Raiders pour
	## from the north (lane y≈-300) and the banner flees south to the rally point (~y 320); the
	## fight runs down a central corridor. So all clutter sits out on the WINGS (|x| large) and
	## the central column (|x| < ~150) stays OPEN — the escort/ward path is never blocked. Adding
	## scenery is editing these lists, not writing code.
	super._build_decor()
	var b := _world_bounds()
	# (1) Distant country toward Camelot — far rolling hills hazed by the rain at the world's top edge.
	var bd := RegionBackdrop.new()
	bd.kind = "hills"
	bd.span = b.size.x
	bd.silhouette = Color(0.12, 0.13, 0.16, 0.85)   # cold blue-grey, lost in the downpour
	bd.haze_top = Color(0.62, 0.66, 0.72, 0.45)
	bd.haze_bottom = Color(0.62, 0.66, 0.72, 0.0)
	add_child(bd)
	bd.position = Vector2((b.position.x + b.end.x) * 0.5, b.position.y)
	# (2) Driving rain — "snow" particles tinted cold rain, falling fast + near-vertical as thin streaks.
	var ad := AmbientDrift.new()
	ad.kind = "snow"
	ad.count = 60
	ad.area = b
	ad.tint = Color(0.7, 0.75, 0.85, 0.5)
	ad.drift = Vector2(6.0, 90.0)   # blown slightly with the road, falling hard
	ad.size_px = 1.4                # small = rain streaks, not snowflakes
	add_child(ad)
	# (3) Themed road props: our standard over the ward, torches lighting the rally, the pursuit banner.
	# A Camelot standard planted beside the escorted ward (offset off the central lane so it stays clear).
	_camelot_banner(Vector2(140.0, 300.0), 86.0)
	# A pair of torches flanking the rally point, guttering against the rain (just off the central
	# retreat corridor so they frame the rally without cluttering the escort lane).
	_torch(Vector2(-150.0, 360.0))
	_torch(Vector2(150.0, 360.0))
	# A Saxon standard up at the pursuit edge so the threat axis reads at a glance (off the lane).
	_saxon_banner(Vector2(-180.0, -290.0), 80.0)
	for side in [-1.0, 1.0]:
		# Camelot rally banners crowning each wing — a far one at the northern muster, a near one
		# at the southern rally point behind the ward (their gold reads as "our" people fleeing).
		_banner(Vector2(520.0 * side, -260.0), "camelot", 78.0)
		_banner(Vector2(480.0 * side, 300.0), "camelot", 84.0)
		# A Camelot war-drum on each wing, beating the escort onward.
		_drum(Vector2(560.0 * side, 40.0))
		# A fence rail down the outer flank — field furniture far off the retreat lane.
		_place_fence(Vector2(595.0 * side, 60.0), Vector2(28.0, 240.0))
		# Shovable crates + rocks scattered on the wing — barged aside, never on the centre lane.
		_prop(CRATE, Vector2(440.0 * side, -150.0))
		_prop(CRATE, Vector2(500.0 * side, 150.0))
		_prop(ROCK, Vector2(400.0 * side, -40.0))
		_prop(ROCK, Vector2(470.0 * side, 220.0))

## Drop a camelot/saxon/briton/neutral faction standard, tinting + sizing it per placement.
func _banner(at: Vector2, fac: String, h: float) -> void:
	var bn = FACTION_BANNER.instantiate()
	if "faction" in bn:
		bn.faction = fac
	if "pole_height" in bn:
		bn.pole_height = h
	bn.position = at
	add_child(bn)

## Plant a Camelot (Pendragon) standard at a spot — our colours over the escorted ward.
func _camelot_banner(at: Vector2, h: float) -> void:
	var bn = CAMELOT_BANNER.instantiate()
	if "faction" in bn:
		bn.faction = "camelot"
	if "pole_height" in bn:
		bn.pole_height = h
	bn.position = at
	add_child(bn)

## Plant a Saxon-coloured Pendragon standard (moss-green) at the pursuit edge — the threat axis.
func _saxon_banner(at: Vector2, h: float) -> void:
	var bn = CAMELOT_BANNER.instantiate()
	if "faction" in bn:
		bn.faction = "saxon"
	if "pole_height" in bn:
		bn.pole_height = h
	bn.position = at
	add_child(bn)

## Drop a guttering torch at a spot (rally-point light against the rain).
func _torch(at: Vector2) -> void:
	var t = TORCH.instantiate()
	t.position = at
	add_child(t)

## Drop a Camelot war drum at a spot (gold rim = our camp).
func _drum(at: Vector2) -> void:
	var d = WAR_DRUM.instantiate()
	if "faction" in d:
		d.faction = "camelot"
	d.position = at
	add_child(d)

## Drop a shovable RigidBody prop (Crate / Rock) — placement only, no config.
func _prop(scene: PackedScene, at: Vector2) -> void:
	var p = scene.instantiate()
	add_child(p)
	if "global_position" in p:
		p.global_position = at
	else:
		p.position = at

## Place a Fence (world-layer obstacle) and resize its collision shape so the drawn rail follows.
func _place_fence(at: Vector2, size: Vector2) -> void:
	var f = FENCE.instantiate()
	add_child(f)
	f.position = at
	for c in f.get_children():
		if c is CollisionShape2D and c.shape is RectangleShape2D:
			var rect := RectangleShape2D.new()
			rect.size = size
			c.shape = rect

# ── objectives: protect the ward AND repel the assault ───────────────────────
func _compose_objectives() -> ObjectiveManager:
	var mgr := ObjectiveManager.new()
	# Constraint first: lose the instant the banner falls. (Order is cosmetic — the manager
	# checks every required objective each tick.)
	mgr.add(ProtectBannerObjective.new("Protect the fleeing people"))
	mgr.add(RepelWavesObjective.new("Repel the Saxon pursuit"))
	return mgr

# ── waves: an escalating Saxon pursuit ────────────────────────────────────────
func _build_wave_spawner() -> WaveSpawner:
	var ws := WaveSpawner.new()
	ws.waves = [
		_make_wave([LIGHT], 5, "Saxon Outriders"),                 # 1 — loose pursuers
		_make_wave([LIGHT, SPEARMAN], 8, "Saxon Skirmish Line"),   # 2 — mixed, more of them
		_make_wave([SPEARMAN, SHIELD], 10, "Saxon Shield Push"),   # 3 — spears + shields close in
		_make_wave([SHIELD, BRUTE, LIGHT], 12, "Saxon Vanguard"),  # 4 — heavy vanguard
		_make_wave([BRUTE, SHIELD, SPEARMAN, LIGHT], 14, "Saxon Host"),  # 5 — the full host
	]
	return ws

## Build one loose raider wave: a roster spread across the wide northern lane, scaled by the
## map density dial. The wave arrives well above Arthur and marches down toward the banner.
func _make_wave(roster: Array, n: int, label: String) -> Wave:
	var w := Wave.new()
	# A single-scene roster uses the Spawner "repeat one scene `count` times" shorthand; a
	# multi-type roster lists its units explicitly (the loose-mob path keys off scenes.size()>1),
	# duplicated to reach the wanted size. Both are scaled by the map density dial.
	if roster.size() == 1:
		var arr: Array[PackedScene] = [roster[0]]
		w.scenes = arr
		w.count = _scale(n)
	else:
		w.scenes = _fill_roster(roster, _scale(n))
		w.count = 0
	w.label = label
	w.lane_y = -300.0
	w.x_min = -360.0
	w.x_max = 360.0
	w.scatter = true
	w.team = "raiders"
	return w

## Repeat a roster until it holds `n` scenes (so a multi-type wave actually spawns `n` units,
## cycling through the listed types). Keeps the loose-mob path (scenes.size()>1) honest.
func _fill_roster(roster: Array, n: int) -> Array[PackedScene]:
	var out: Array[PackedScene] = []
	if roster.is_empty():
		return out
	for i in range(n):
		out.append(roster[i % roster.size()])
	return out

# ── theme each wave: tint the raiders Saxon green as they arrive ──────────────
func _on_wave_spawned(idx: int, units: Array) -> void:
	super._on_wave_spawned(idx, units)   # keep the base "WAVE n / N" popup (4.3-safe explicit form)
	# Faction is pure colour flavour (Enemy.faction_color); stamp the pursuers Saxon so the
	# Arthurian theme reads at a glance. No gameplay effect.
	for u in units:
		if is_instance_valid(u) and "faction" in u:
			u.faction = "saxon"

# ── ground dressing: read the retreat ROUTE down the central lane ─────────────
## Region ground motifs, painted by the base at the END of _draw (over the shared floor, behind the
## units). All STATIC — drawn once, no per-frame cost. The escort corridor reads clearly: a trodden
## dirt road down the centre with rain-filled muddy puddles, edge rails + a dashed centre-line, and
## a rally ring (our muster) vs a pursuit ring (the raider lane).
func _paint_region(b: Rect2) -> void:
	var lane_half := 130.0
	# The trodden retreat road — a lighter dirt band down the central corridor (kept clear of decor).
	draw_rect(Rect2(-lane_half, b.position.y, lane_half * 2.0, b.size.y), Color(0.28, 0.24, 0.17, 0.45))
	# Dark, rain-filled muddy puddles scattered down the churned-up road (the long flight in the wet).
	var puddle := Color(0.07, 0.08, 0.09, 0.55)
	var sheen := Color(0.55, 0.60, 0.68, 0.16)   # a cold grey sky-glint on the standing water
	var puddles := [
		Vector2(-58.0, -210.0), Vector2(70.0, -120.0), Vector2(-20.0, -30.0),
		Vector2(86.0, 70.0), Vector2(-92.0, 150.0), Vector2(34.0, 235.0),
		Vector2(-44.0, 300.0), Vector2(96.0, -260.0),
	]
	for i in puddles.size():
		var c: Vector2 = puddles[i]
		var rx := 34.0 + float((i * 13) % 22)     # deterministic varied ovals (no random per frame)
		var ry := rx * 0.5
		_oval(c, rx, ry, puddle)
		_oval(c + Vector2(-rx * 0.25, -ry * 0.3), rx * 0.45, ry * 0.4, sheen)
	# Edge rails framing the open lane so the corridor reads as a road, not just open ground.
	var rail := Color(0.55, 0.47, 0.30, 0.5)
	draw_line(Vector2(-lane_half, b.position.y), Vector2(-lane_half, b.end.y), rail, 2.0)
	draw_line(Vector2(lane_half, b.position.y), Vector2(lane_half, b.end.y), rail, 2.0)
	# Dashed centre-line markers running the length of the road (the path the banner flees down).
	var dash := Color(0.78, 0.72, 0.45, 0.35)
	for y in range(int(b.position.y) + 20, int(b.end.y) - 20, 70):
		draw_line(Vector2(0.0, y), Vector2(0.0, y + 36), dash, 3.0)
	# A Camelot-gold rally ring at the ward's muster point (the escort's goal, behind Arthur).
	draw_arc(Vector2(0.0, 320.0), 70.0, 0.0, TAU, 40, Color(0.36, 0.78, 0.42, 0.30), 3.0)
	# A red pursuit ring up at the raider lane so the threat axis reads at a glance.
	draw_arc(Vector2(0.0, -300.0), 90.0, 0.0, TAU, 40, Color(0.85, 0.35, 0.32, 0.22), 3.0)

## Draw a filled oval (puddle) centred at `c` with radii rx/ry — a cheap scaled-circle polygon.
func _oval(c: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in range(20):
		var a := TAU * float(i) / 20.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(pts, col)
