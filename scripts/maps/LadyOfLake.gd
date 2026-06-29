class_name LadyOfLake
extends BattleMap
## The Lady of the Lake — Avalon's misty mere. At the heart of the lake the Lady's arm rises
## from the water, offering Excalibur; on the shore Arthur and a few Camelot knights hold the
## bank while Saxon and rebel warbands wade in to contest the sword. Clear the guardians ringing
## the two mystical SHRINES on the shore and you CLAIM EXCALIBUR — Avalon is yours.
##
## A THIN BattleMap subclass: it only composes the shared modules. The lake is one big water
## `TerrainZone` (`_add_zone`) that drifts loose bodies on a slow current and DROWNS the lightest
## foes who stray off the shore into the deep — the chokepoint that makes wading in costly. The
## shrines are the reusable `Base` capture mechanic (group "bases"), reported to the shared
## `CaptureBasesObjective` through `_extra_context`. No new mechanic, no copy-pasted level loop.

const LIGHT := preload("res://scenes/LightSoldier.tscn")
const SHIELD := preload("res://scenes/ShieldSoldier.tscn")
const SPEAR := preload("res://scenes/Spearman.tscn")
const HEAVY := preload("res://scenes/HeavyGuard.tscn")
const BASE := preload("res://scenes/Base.tscn")
const ALLY_KNIGHT := preload("res://scenes/AllyKnight.tscn")
const ALLY_SHIELD := preload("res://scenes/AllyShield.tscn")
const ALLY_SPEAR := preload("res://scenes/AllySpear.tscn")

# Light flank scenery — existing reusable props, PLACED not coded. A few crates + rocks the
# warband can shove, fences flanking the shore lanes, and a faction standard + war drum per camp.
const CRATE := preload("res://scenes/Crate.tscn")
const ROCK := preload("res://scenes/Rock.tscn")
const FENCE := preload("res://scenes/terrain/Fence.tscn")
const BANNER := preload("res://scenes/decor/FactionBanner.tscn")
const WAR_DRUM := preload("res://scenes/decor/WarDrum.tscn")

# Bodies (Arthur + units + props) ride the enemy/arthur/prop layers; mask 14 = those layers,
# matching RedCliffs' water so the lake's drift/drown acts on the same bodies the river did.
const _WATER_MASK := 14

## The misty central lake (Avalon). Bodies inside it are slowed, drifted on a slow current, and
## the very lightest foes drown — so the shore is the place to actually stand and fight.
const _LAKE := Rect2(-360.0, -300.0, 720.0, 420.0)

## The two mystical shrines (group "bases"), set on the shore where the fight happens — NOT in the
## deep water (a shrine in the lake could never be reached). Capture by clearing their guardians.
const SHRINES: Array[Vector2] = [
	Vector2(-440.0, 300.0),
	Vector2(440.0, 300.0),
]
const SHRINE_RADIUS := 150.0

func _map_title() -> String:
	return "THE LADY OF THE LAKE"

func _opening_banner() -> String:
	return "CLAIM EXCALIBUR!"

func _arthur_start() -> Vector2:
	return Vector2(0.0, 320.0)   # the southern shore, between the two shrines

func _world_bounds() -> Rect2:
	return Rect2(-640.0, -440.0, 1280.0, 900.0)

# ── terrain: the misty lake of Avalon ────────────────────────────────────────
func _build_terrain() -> void:
	# One big central lake: drag<1 slows wading, a slow current drifts loose bodies (and nudges
	# Arthur), `dangerous` routes raider AI around the deep water toward the shore, and `drown`
	# removes the lightest units that stray into it — the chokepoint that funnels the fight onto
	# the shore where the shrines sit.
	_add_zone(_LAKE, 0.9, Vector2(14.0, 8.0), true, true, _WATER_MASK)
	# The shore GAPS: open ground left + right of the lake (x beyond its ±360 edges, inside the
	# ±640 world walls). When the deep water blocks a raider's straight line south, its nav steers
	# to the nearest "crossing" marker — so the warband FUNNELS around the mere through these flank
	# lanes toward the shrines, instead of routing arbitrarily across the drowning deep. Two per
	# side (across the deep belt) so the redirect holds the whole way around the water.
	for cy in [-200.0, 0.0]:
		_mark_crossing(Vector2(-500.0, cy))   # west shore gap
		_mark_crossing(Vector2(500.0, cy))    # east shore gap

# ── shrines + guardians ──────────────────────────────────────────────────────
func _build_decor() -> void:
	# Place each capturable shrine and ring it with a guardian band. Done in _build_decor so the
	# bases exist before the first objective evaluation (they're static field furniture), exactly
	# like Guandu's depots.
	for idx in SHRINES.size():
		_place_shrine(SHRINES[idx], idx)
	_place_flank_scenery()

## Light interactive scenery on the flank shore lanes (the gaps the crossings funnel through),
## keeping the lake + shrine approaches clear. Pure PLACEMENT of existing reusable props — a war
## drum + standard mark each camp, a short fence walls the outer lane, and a couple of shovable
## crates/rocks give the warband something to barge through as it rounds the mere.
func _place_flank_scenery() -> void:
	for side in [-1.0, 1.0]:
		var faction := "rebel" if side < 0.0 else "camelot"   # decor colour flavour only (Arthurian houses)
		# Camp standard + war drum just outside the lake on each shore lane.
		_place_decor(BANNER, Vector2(560.0 * side, -120.0), faction)
		_place_decor(WAR_DRUM, Vector2(560.0 * side, -40.0), faction)
		# A short fence along the outer edge of the lane (resize its shape to a low rail).
		_place_fence(Vector2(575.0 * side, 110.0), Vector2(28.0, 170.0))
		# Shovable props strewn in the lane the warband rounds the lake through. Kept clear of the
		# shrine capture rings (centres ±440,300 r150) so nothing crowds a capture point.
		_place_prop(CRATE, Vector2(520.0 * side, 120.0))
		_place_prop(ROCK, Vector2(540.0 * side, 60.0))
		_place_prop(ROCK, Vector2(470.0 * side, -90.0))

## Drop a code-drawn decor prop (FactionBanner / WarDrum) at a spot, tinting it to a kingdom.
func _place_decor(scene: PackedScene, pos: Vector2, faction: String) -> void:
	var d = scene.instantiate()
	add_child(d)
	d.global_position = pos
	if "faction" in d:
		d.faction = faction

## Drop a shovable RigidBody prop (Crate / Rock) at a spot — no config, just placement.
func _place_prop(scene: PackedScene, pos: Vector2) -> void:
	var p = scene.instantiate()
	add_child(p)
	p.global_position = pos

## Place a Fence (world-layer obstacle) and resize its collision shape so the drawn rail follows.
func _place_fence(pos: Vector2, size: Vector2) -> void:
	var f = FENCE.instantiate()
	add_child(f)
	f.global_position = pos
	for c in f.get_children():
		if c is CollisionShape2D and c.shape is RectangleShape2D:
			var rect := RectangleShape2D.new()
			rect.size = size
			c.shape = rect

## A "crossing" marker the raider nav aims at when deep water blocks the straight line — funnels
## the warband around the mere through the shore gaps (reuses Enemy's avoid_danger nav, exactly as
## RedCliffs' ford does).
func _mark_crossing(pos: Vector2) -> void:
	var m := Node2D.new()
	m.add_to_group("crossing")
	m.global_position = pos
	add_child(m)

func _place_shrine(centre: Vector2, idx: int) -> void:
	var b := BASE.instantiate()
	add_child(b)
	b.global_position = centre
	if "radius" in b:
		b.radius = SHRINE_RADIUS
	if "label" in b:
		b.label = "SHRINE %d" % (idx + 1)
	# A mystical look: the captor's flag reads Camelot gold once the shrine is claimed; the
	# guardians' Saxon green while contested.
	if "enemy_color" in b:
		b.enemy_color = Color(0.40, 0.46, 0.27)    # Saxon moss-green (held by the enemy)
	if "captured_color" in b:
		b.captured_color = Color(0.92, 0.78, 0.30) # Camelot gold (claimed for Arthur)
	# A guardian band ringing the shrine — they hold it until defeated. Count scales with the
	# density dial (web framerate), like every other spawn site.
	var count: int = _scale(3)
	for i in count:
		var ang := TAU * float(i) / float(maxi(count, 1))
		var r := SHRINE_RADIUS * 0.55
		var pos := centre + Vector2(cos(ang), sin(ang)) * r
		var scene: PackedScene = SHIELD if (i % 3 == 0) else LIGHT
		var e = scene.instantiate()
		add_child(e)
		e.global_position = pos
		if "ai_enabled" in e:
			e.ai_enabled = true
		_tint_faction(e, "saxon")    # shrine guardians — cosmetic Saxon green
		# team stays "raiders" (the default) → they join "targets", so the Base counts them.

## Tint an Enemy-backed unit with a faction colour (no gameplay effect) — used by both the
## allied retinue and the shrine guardians, so "set faction → recolour" lives in one place.
func _tint_faction(unit, name: String) -> void:
	if not is_instance_valid(unit) or not ("faction" in unit):
		return
	unit.faction = name
	if "base_color" in unit and unit.has_method("faction_color"):
		unit.base_color = unit.faction_color()

# ── allies: a few Camelot knights on the shore ───────────────────────────────
func _spawn_allies() -> void:
	# A short Camelot line just ahead of Arthur — they hunt the nearest guardian. The shared
	# Spawner takes a roster of SCENES (not instances) and lays them along the lane.
	var roster: Array = [ALLY_SHIELD, ALLY_KNIGHT, ALLY_SPEAR, ALLY_SHIELD, ALLY_SPEAR]
	var line: Array = Spawner.spawn(self, roster, 280.0, -240.0, 240.0, false, true)
	for a in line:
		_tint_faction(a, "camelot")   # Camelot gold retinue

# ── objectives: claim every shrine (waves are a bonus) ───────────────────────
func _compose_objectives() -> ObjectiveManager:
	var mgr := ObjectiveManager.new()
	mgr.add(CaptureBasesObjective.new("Claim the shrines of Avalon"))
	return mgr

# ── waves: warbands wading in to contest the lake ────────────────────────────
func _build_wave_spawner() -> WaveSpawner:
	var ws := WaveSpawner.new()
	ws.waves = [
		_loose_wave("RAIDERS", LIGHT, 5, -380.0),
		_loose_wave("SHIELD LINE", SHIELD, 4, -390.0),
		_mixed_wave("MIXED VAN", [LIGHT, SPEAR, SHIELD], -390.0),
		_loose_wave("HEAVY GUARD", HEAVY, 3, -400.0),
	]
	return ws

func _loose_wave(label: String, scene: PackedScene, count: int, lane_y: float) -> Wave:
	var w := Wave.new()
	w.label = label
	var arr: Array[PackedScene] = [scene]
	w.scenes = arr
	w.count = _scale(count)
	w.lane_y = lane_y
	w.x_min = -360.0
	w.x_max = 360.0
	w.team = "raiders"
	return w

func _mixed_wave(label: String, scenes_in: Array, lane_y: float) -> Wave:
	var w := Wave.new()
	w.label = label
	# Repeat the roster `density`-many times so a mixed wave still scales with the framerate dial.
	var arr: Array[PackedScene] = []
	for _r in range(_scale(2)):
		for s in scenes_in:
			arr.append(s)
	w.scenes = arr
	w.count = 0
	w.lane_y = lane_y
	w.x_min = -360.0
	w.x_max = 360.0
	w.team = "raiders"
	return w

# ── theme: stamp each incoming wave as a Saxon/rebel warband ──────────────────
func _on_wave_spawned(idx: int, units: Array) -> void:
	# Alternate Saxon green / Mordred's rebel purple so the warbands read as two contesting hosts.
	var faction := "saxon" if idx % 2 == 0 else "rebel"
	for u in units:
		_tint_faction(u, faction)
	super._on_wave_spawned(idx, units)

# ── report shrine capture to the objective layer ─────────────────────────────
func _extra_context(ctx: Dictionary) -> void:
	var total := 0
	var held := 0
	for b in get_tree().get_nodes_in_group("bases"):
		if not is_instance_valid(b):
			continue
		total += 1
		if b.has_method("is_captured") and b.is_captured():
			held += 1
	ctx["bases_total"] = total
	ctx["bases_captured"] = held

# ── drawing: a shimmering misty lake + the Lady's arm raising Excalibur ───────
func _draw() -> void:
	super._draw()   # the base grid/background first
	var t := float(Time.get_ticks_msec()) * 0.001

	# The lake body: a deep blue fill with a brighter rim, shimmering faintly.
	var lake := _LAKE
	draw_rect(lake, Color(0.12, 0.22, 0.34, 0.92))
	draw_rect(lake, Color(0.36, 0.62, 0.78, 0.5), false, 3.0)
	# A handful of horizontal shimmer bands that drift, suggesting water + mist on the surface.
	var bands := 6
	for i in bands:
		var fy := float(i) / float(bands - 1)
		var y := lerpf(lake.position.y + 24.0, lake.end.y - 24.0, fy)
		var sway := sin(t * 0.8 + float(i) * 1.3) * 10.0
		var a := 0.10 + 0.05 * sin(t * 1.4 + float(i))
		draw_line(Vector2(lake.position.x + 30.0 + sway, y),
			Vector2(lake.end.x - 30.0 + sway, y), Color(0.7, 0.86, 0.95, a), 2.0)
	# Soft mist patches over the lake.
	for i in 4:
		var mx := lerpf(lake.position.x + 80.0, lake.end.x - 80.0, float(i) / 3.0)
		var my := lake.get_center().y + sin(t * 0.5 + float(i) * 2.0) * 30.0
		draw_circle(Vector2(mx, my), 60.0, Color(0.85, 0.9, 0.95, 0.05))

	# The Lady's arm rising at the centre, lifting Excalibur — a hint, not a unit.
	var c := lake.get_center()
	var rise := sin(t * 0.9) * 6.0
	# A faint halo around the sword.
	draw_circle(c + Vector2(0.0, -70.0 + rise), 46.0, Color(0.85, 0.92, 1.0, 0.06))
	# The arm: forearm + a hand wrapping the hilt.
	draw_line(c + Vector2(0.0, 18.0), c + Vector2(0.0, -34.0 + rise), Color(0.78, 0.80, 0.84), 9.0)
	draw_circle(c + Vector2(0.0, -34.0 + rise), 8.0, Color(0.80, 0.82, 0.86))   # fist on the hilt
	# Excalibur: a cross-guard, a blade, and a gleam at the tip.
	var hilt := c + Vector2(0.0, -42.0 + rise)
	draw_line(hilt + Vector2(-14.0, 0.0), hilt + Vector2(14.0, 0.0), Color(0.85, 0.74, 0.36), 5.0)  # guard
	draw_line(hilt, c + Vector2(0.0, -120.0 + rise), Color(0.92, 0.95, 1.0), 5.0)                    # blade
	draw_circle(c + Vector2(0.0, -120.0 + rise), 4.0, Color(1.0, 1.0, 0.85, 0.9))                    # tip gleam
	# Title under the lake.
	draw_string(ThemeDB.fallback_font, Vector2(lake.position.x, lake.position.y - 16.0),
		"AVALON", HORIZONTAL_ALIGNMENT_CENTER, lake.size.x, 16, Color(0.82, 0.9, 0.98, 0.7))

	# Keep the surface animating.
	queue_redraw()
