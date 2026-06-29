extends BattleMap
## The Beacon-Forts — the supply raid. A Saxon host holds three supply forts (beacon-forts)
## across the field, each ringed by a partial wooden STOCKADE and held by a garrison of
## raiders. Arthur and his Camelot allies must storm each fort through its one open gate and
## clear its garrison to SEIZE it; take all the beacon-forts and the Saxon stores burn —
## breaking the invaders' hold on the frontier.
##
## A THIN BattleMap subclass: it places `Base` instances (the reusable capture mechanic),
## rings each with a PARTIAL stockade (placed `Fence` / `GatePost` scenes left OPEN on the
## side facing Arthur, so garrison and hero can both reach the capture circle), dresses each
## fort with banners / drums / crates, and spawns each garrison directly with the shared
## `Spawner`. It reports `bases_total` / `bases_captured` through `_extra_context` so the
## reusable `CaptureBasesObjective` can win, and adds a required `RepelWavesObjective` so the
## relief column must also be broken — you can't win by ignoring the fight.

const LIGHT := preload("res://scenes/LightSoldier.tscn")
const SHIELD := preload("res://scenes/ShieldSoldier.tscn")
const BASE := preload("res://scenes/Base.tscn")
const ALLY := preload("res://scenes/Ally.tscn")
const ALLY_SHIELD := preload("res://scenes/AllyShield.tscn")
const ALLY_SPEAR := preload("res://scenes/AllySpear.tscn")
const FENCE := preload("res://scenes/terrain/Fence.tscn")
const GATE_POST := preload("res://scenes/decor/GatePost.tscn")
const BANNER := preload("res://scenes/decor/FactionBanner.tscn")
const WAR_DRUM := preload("res://scenes/decor/WarDrum.tscn")
const CRATE := preload("res://scenes/Crate.tscn")
const BRAZIER := preload("res://scenes/decor/Brazier.tscn")
const CAMELOT_BANNER := preload("res://scenes/decor/CamelotBanner.tscn")

## Centre of each beacon-fort. 2–3 bases, spread across the field.
const DEPOTS: Array[Vector2] = [
	Vector2(-360.0, -140.0),
	Vector2(360.0, -140.0),
	Vector2(0.0, -360.0),
]
const DEPOT_RADIUS := 150.0
## Stockade ring radius — kept WELL OUTSIDE DEPOT_RADIUS so the palisade never overlaps the
## capture circle (a fence inside it could trap raiders out / block the garrison and stall the
## capture forever). The gate gap on the open side lets the garrison AND Arthur cross freely.
const STOCKADE_RADIUS := 192.0
## Half-width of the OPEN gate gap, in radians of the ring — wide enough for bodies to file in.
const GATE_HALF := 0.62

# ── region identity: bleak hill turf under a flat overcast sky ────────────────
## Set the floor palette + mood FIRST in _ready (the base calls this before any build), so the
## Beacon-Forts read as a dry, wind-scoured ridge of supply hills rather than the flat prototype
## floor. The mood is a gentle desaturating overcast (each channel >= 0.6 so units stay readable).
func _theme() -> void:
	ground_top = Color(0.17, 0.20, 0.14)      # hill turf, lit crest
	ground_bottom = Color(0.14, 0.16, 0.11)   # turf in the hollows
	region_mood = Color(0.86, 0.86, 0.80)     # flat overcast, faintly cold

func _map_title() -> String:
	return "THE BEACON-FORTS"

func _opening_banner() -> String:
	return "STORM THE BEACON-FORTS!"

func _arthur_start() -> Vector2:
	return Vector2(0.0, 360.0)

func _world_bounds() -> Rect2:
	return Rect2(-680.0, -560.0, 1360.0, 1040.0)

# ── walls: a bounding frame, then a partial stockade around each depot ─────────
func _build_walls() -> void:
	# Foundation contract: frame the world FIRST, then add our own walls onto the same body.
	_frame_walls(_world_bounds())
	for centre in DEPOTS:
		_ring_stockade(centre)

## Ring a fort with a PARTIAL palisade: solid fence segments around the arc EXCEPT a gate gap
## on the side facing Arthur's approach (downfield / +y). The gap is framed by a pair of stone
## GatePosts so it reads as a real gateway. Every segment sits on STOCKADE_RADIUS (> capture
## radius), so the capture circle is always reachable through the gate.
func _ring_stockade(centre: Vector2) -> void:
	# Gate faces Arthur: he marches UP the field from +y, so the opening points toward him.
	var gate_dir := (_arthur_start() - centre).normalized()
	var gate_ang := gate_dir.angle()
	# Eight tangent slots around the ring; skip any whose centre falls within the gate gap,
	# AND any that would poke past the world frame (a depot near the edge — e.g. the northern
	# fort — would otherwise embed its back-arc fences INTO the boundary wall).
	var slots := 8
	for i in slots:
		var ang := TAU * float(i) / float(slots)
		if absf(_ang_delta(ang, gate_ang)) < GATE_HALF:
			continue   # leave the gate side open
		var pos := centre + Vector2(cos(ang), sin(ang)) * STOCKADE_RADIUS
		if not _in_field(pos):
			continue   # would clip the frame wall — drop it (back side, against the edge)
		_fence_segment(centre, ang)
	# Two gate posts flanking the open side, just at the edge of the gap.
	_gate_post(centre, gate_ang - GATE_HALF)
	_gate_post(centre, gate_ang + GATE_HALF)

## True when `pos` sits inside the playfield with enough room for a placed fence/post — the
## bounds inset by a fence's half-span, so a segment centred here can't reach the frame wall.
func _in_field(pos: Vector2) -> bool:
	var margin := 112.0   # ~half the 220px fence diagonal, so its OBB stays off the frame wall
	return _world_bounds().grow(-margin).has_point(pos)

## One fence segment laid tangent to the ring at angle `ang` (a chord of the palisade).
## Fence/GatePost are their own StaticBody2D scenes (layer 1), so they're placed under the
## map like every other dropped-in scene — not nested inside the frame's `_walls` body.
func _fence_segment(centre: Vector2, ang: float) -> void:
	var f := FENCE.instantiate()
	add_child(f)
	f.global_position = centre + Vector2(cos(ang), sin(ang)) * STOCKADE_RADIUS
	f.rotation = ang + PI * 0.5   # tangent: long axis perpendicular to the radius

## A stone gate post planted on the ring at angle `ang` (one jamb of the gateway).
func _gate_post(centre: Vector2, ang: float) -> void:
	var p := GATE_POST.instantiate()
	add_child(p)
	p.global_position = centre + Vector2(cos(ang), sin(ang)) * STOCKADE_RADIUS

## Signed smallest angular difference a-b, wrapped to (-PI, PI].
func _ang_delta(a: float, b: float) -> float:
	var d := fmod(a - b + PI, TAU)
	if d < 0.0:
		d += TAU
	return d - PI

# ── allies: a small Camelot retinue that fights for Arthur ──────────────────────
func _spawn_allies() -> void:
	# A short allied line just ahead of Arthur — they hunt the nearest garrison raider. The
	# shared Spawner takes a roster of SCENES (not instances) and lays them along the lane.
	var roster: Array = [ALLY_SHIELD, ALLY_SPEAR, ALLY, ALLY_SHIELD, ALLY_SPEAR]
	var line: Array = Spawner.spawn(self, roster, 260.0, -220.0, 220.0, false, true)
	# Stamp faction colours so the retinue reads as Camelot royal gold / Briton blue.
	var i := 0
	for a in line:
		if not is_instance_valid(a):
			continue
		_tint_faction(a, "camelot" if i % 2 == 0 else "briton")
		i += 1

## Tint an Enemy-backed unit with a faction colour — used by both the allied retinue and the
## fort garrisons, so the "set faction → recolour" step lives in one place.
func _tint_faction(unit, name: String) -> void:
	if not is_instance_valid(unit) or not ("faction" in unit):
		return
	unit.faction = name
	unit.base_color = unit.faction_color()

# ── forts + garrisons ───────────────────────────────────────────────────────
func _build_decor() -> void:
	# Place each capturable Base, ring it with a Saxon garrison, and dress the fort with
	# standards / drums / supply crates. Done in _build_decor so the bases exist before the
	# first objective evaluation (they're static field furniture).
	for idx in DEPOTS.size():
		_place_depot(DEPOTS[idx], idx)
	_scatter_battlefield_props(2, 2, 1, 1)   # lighter smashable clutter — the forts stay the focus
	_dress_region()

## Region scenery: a distant ridge of supply hills along the north edge, a dry dust-drift across
## the field, and a pair of Camelot standards framing Arthur's muster (the central lane stays
## clear). Pure placement of the shared scenery modules — no new mechanic.
func _dress_region() -> void:
	var b := _world_bounds()
	# (1) A far hill ridge silhouette along the world's top (the Saxon supply uplands beyond).
	var bd := RegionBackdrop.new()
	bd.kind = "hills"
	bd.span = b.size.x
	bd.silhouette = Color(0.12, 0.14, 0.11, 0.85)
	bd.haze_top = Color(0.18, 0.20, 0.16, 0.5)
	bd.haze_bottom = Color(0.18, 0.20, 0.16, 0.0)
	add_child(bd)
	bd.position = Vector2((b.position.x + b.end.x) * 0.5, b.position.y)
	# (2) Dry dust drifting on the hill wind, low and pale so it never muddies unit reads.
	var ad := AmbientDrift.new()
	ad.kind = "dust"
	ad.count = 40
	ad.area = b
	ad.tint = Color(0.6, 0.6, 0.5, 0.3)
	ad.drift = Vector2(20.0, -6.0)
	add_child(ad)
	# (3) Camelot royal standards flanking Arthur's muster line (off the central lane).
	for sx: float in [-150.0, 150.0]:
		var banner := _spawn_prop(CAMELOT_BANNER, _arthur_start() + Vector2(sx, 6.0))
		if banner != null and "faction" in banner:
			banner.faction = "camelot"

## Turf texture: a scatter of tiny green-grey blades / flecks over the floor so the hill turf
## reads as living ground rather than a flat fill. Deterministic (seeded RNG) so the static floor
## doesn't flicker between redraws; low alpha so it never competes with units. Drawn behind units.
func _paint_region(b: Rect2) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 0x6EAC04   # fixed → identical every redraw (the floor is static)
	var blade := Color(0.30, 0.36, 0.24, 0.20)
	var fleck := Color(0.22, 0.27, 0.18, 0.16)
	for _i in 420:
		var p := Vector2(b.position.x + rng.randf() * b.size.x, b.position.y + rng.randf() * b.size.y)
		if rng.randf() < 0.6:
			# a short blade leaning slightly with the wind
			var tilt := (rng.randf() - 0.5) * 1.4
			var h := 3.0 + rng.randf() * 3.5
			draw_line(p, p + Vector2(tilt, -h), blade, 1.0)
		else:
			draw_circle(p, 1.0 + rng.randf() * 0.8, fleck)

func _place_depot(centre: Vector2, idx: int) -> void:
	var b := BASE.instantiate()
	add_child(b)
	b.global_position = centre
	if "radius" in b:
		b.radius = DEPOT_RADIUS
	if "label" in b:
		b.label = "FORT %d" % (idx + 1)
	_dress_depot(centre)
	# A garrison of raiders ringing the fort — they hold the fort until defeated. The
	# count scales with the map density dial (web framerate), like every other spawn site.
	var count: int = _scale(3)
	for i in count:
		var ang := TAU * float(i) / float(maxi(count, 1))
		var r := DEPOT_RADIUS * 0.55
		var pos := centre + Vector2(cos(ang), sin(ang)) * r
		var scene: PackedScene = SHIELD if (i % 3 == 0) else LIGHT
		var e = scene.instantiate()
		add_child(e)
		e.global_position = pos
		if "ai_enabled" in e:
			e.ai_enabled = true
		_tint_faction(e, "saxon")        # the Saxon fort guards — cosmetic moss green
		# team stays "raiders" (the default) → they join "targets", so the Base counts them.

## Dress a fort centre with a Saxon standard + war drum, and a small ring of supply crates
## for cover. Pure placement of existing scenes — the banner/drum are decor, the crates are
## physics props (cover Arthur can shove). All kept inside the capture circle (off-centre) so
## they never sit on the gate path or the stockade line.
func _dress_depot(centre: Vector2) -> void:
	var banner := BANNER.instantiate()
	add_child(banner)
	banner.global_position = centre + Vector2(-22.0, -8.0)
	if "faction" in banner:
		banner.faction = "saxon"
	var drum := WAR_DRUM.instantiate()
	add_child(drum)
	drum.global_position = centre + Vector2(28.0, 14.0)
	if "faction" in drum:
		drum.faction = "saxon"
	# The beacon itself — a lit signal-fire brazier on the fort's back rise (away from the +y gate
	# path so it never blocks the garrison/hero crossing), marking the supply fort to be burned.
	var beacon := BRAZIER.instantiate()
	add_child(beacon)
	beacon.global_position = centre + Vector2(0.0, -56.0)
	if "bowl_radius" in beacon:
		beacon.bowl_radius = 15.0
	# A small supply pile — crates as cover, set off-centre so they don't seal the gate.
	var crate_offsets: Array[Vector2] = [
		Vector2(-60.0, -44.0), Vector2(-44.0, -68.0), Vector2(60.0, -44.0),
	]
	for off in crate_offsets:
		var c := CRATE.instantiate()
		add_child(c)
		c.global_position = centre + off

# ── objectives: seize every fort AND break the relief column ──────────────
func _compose_objectives() -> ObjectiveManager:
	var mgr := ObjectiveManager.new()
	mgr.add(CaptureBasesObjective.new("Seize the beacon-forts"))
	# A second REQUIRED goal so the field is never empty and you can't win by sneaking captures
	# while a relief column still stands — the Saxon relief wave must be repelled too.
	mgr.add(RepelWavesObjective.new("Repel the relief"))
	return mgr

# ── a light relief column so RepelWaves has a real fight to resolve ──────────
func _build_wave_spawner() -> WaveSpawner:
	var ws := WaveSpawner.new()
	var w := Wave.new()
	var arr: Array[PackedScene] = [LIGHT]
	w.scenes = arr
	w.count = _scale(2)
	w.lane_y = _world_bounds().position.y + 40.0
	w.x_min = -200.0
	w.x_max = 200.0
	w.team = "raiders"
	w.label = "SAXON RELIEF"
	ws.waves = [w]
	return ws

# ── report fort capture to the objective layer ───────────────────────────────
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
