class_name HuLaoGate
extends BattleMap
## The Marches — a Saxon frontier assault on a fortress-gate chokepoint, built on the reusable
## BattleMap base.
##
## The Saxon raiders pour through a narrow GATE funnel cut into the top wall; Arthur and a small
## Camelot garrison hold the courtyard below. This map is a THIN subclass: it only overrides the
## build hooks (walls + the gate funnel, terrain, allies, waves, objectives, theme). All
## orchestration — Arthur, HUD, score, wave driving, breaches, win/lose — lives in BattleMap and
## is never re-implemented here.
##
## Build once, reuse many: the gate is plain `_wall()` rectangles; the waves are `Wave`
## resources composed in code (loose raiders -> ShieldWall -> spears+shields -> Cavalry charge ->
## an OfficerGuard whose BannerBearer is the warlord Octa to defeat); objectives are the shared
## RepelWaves + DefeatOfficer + HoldLine.

const SHIELD_WALL := preload("res://scenes/formations/ShieldWall.tscn")
const SPEAR_PHALANX := preload("res://scenes/formations/SpearPhalanx.tscn")
const CHARGE_GROUP := preload("res://scenes/formations/ChargeGroup.tscn")
const OFFICER_GUARD := preload("res://scenes/formations/OfficerGuard.tscn")
const ALLIED_HOST := preload("res://scenes/formations/AlliedHost.tscn")
const LIGHT_SOLDIER := preload("res://scenes/LightSoldier.tscn")
const OCTA := preload("res://scenes/generals/LuBu.tscn")

# Code-drawn decor that dresses the frontier gate (placed via the base `_spawn_prop` helper).
const TORCH := preload("res://scenes/decor/Torch.tscn")
const BRAZIER := preload("res://scenes/decor/Brazier.tscn")
const CAMELOT_BANNER := preload("res://scenes/decor/CamelotBanner.tscn")
const FACTION_BANNER := preload("res://scenes/decor/FactionBanner.tscn")
const WAR_DRUM := preload("res://scenes/decor/WarDrum.tscn")

const GATE_GAP := 150.0          ## width of the funnel mouth the raiders pour through

# ── theme ─────────────────────────────────────────────────────────────────────
func _map_title() -> String:
	return "The Marches"

## The Marches palette: a churned-mud courtyard under an overcast frontier dusk. Set FIRST in
## _ready (before any build) so the floor + mood tint read this region from frame 0.
func _theme() -> void:
	ground_top = Color(0.20, 0.17, 0.13)        # churned mud, lit edge
	ground_bottom = Color(0.15, 0.13, 0.10)     # churned mud, deep shadow
	region_mood = Color(0.80, 0.78, 0.74)       # gentle overcast-dusk grey (kept readable, >= 0.6)

func _opening_banner() -> String:
	return "HOLD THE FRONTIER!"

func _arthur_start() -> Vector2:
	return Vector2(0.0, 240.0)

func _world_bounds() -> Rect2:
	return Rect2(-640.0, -440.0, 1280.0, 900.0)

func _build_decor() -> void:
	_scatter_battlefield_props()   # smashable barrels/pots/hay + a fire-barrel on the flanks
	var b := _world_bounds()
	var gate_y := b.position.y + 150.0
	var half_gap := GATE_GAP * 0.5
	# A dark frontier fort looms on the far (Saxon) edge under the overcast dusk.
	var bd := RegionBackdrop.new()
	bd.kind = "castle"
	bd.span = b.size.x
	bd.silhouette = Color(0.11, 0.10, 0.10, 0.9)
	bd.haze_top = Color(0.22, 0.21, 0.20, 0.45)
	bd.haze_bottom = Color(0.22, 0.21, 0.20, 0.0)
	add_child(bd)
	bd.position = Vector2((b.position.x + b.end.x) * 0.5, b.position.y)
	# Dust kicked off the churned mud drifts across the chokepoint.
	var ad := AmbientDrift.new()
	ad.kind = "dust"
	ad.area = b
	ad.tint = Color(0.6, 0.55, 0.45, 0.3)
	ad.drift = Vector2(18.0, -6.0)
	add_child(ad)
	# Gate dressing: torches on the posts + braziers flanking the throat, lighting the dusk fight.
	_spawn_prop(TORCH, Vector2(-half_gap - 34.0, gate_y + 16.0))
	_spawn_prop(TORCH, Vector2(half_gap + 34.0, gate_y + 16.0))
	_spawn_prop(BRAZIER, Vector2(-half_gap - 110.0, gate_y + 64.0))
	_spawn_prop(BRAZIER, Vector2(half_gap + 110.0, gate_y + 64.0))
	# Standards (proper rippling decor, off the central lane): the Saxon host above the gate, a
	# Camelot standard with the garrison holding the courtyard below.
	var saxon_banner = _spawn_prop(FACTION_BANNER, Vector2(half_gap + 130.0, gate_y - 6.0))
	if saxon_banner and "faction" in saxon_banner:
		saxon_banner.faction = "saxon"
	var saxon_drum = _spawn_prop(WAR_DRUM, Vector2(-half_gap - 130.0, gate_y - 4.0))
	if saxon_drum and "faction" in saxon_drum:
		saxon_drum.faction = "saxon"
	var camelot_banner = _spawn_prop(CAMELOT_BANNER, Vector2(-150.0, 356.0))
	if camelot_banner and "faction" in camelot_banner:
		camelot_banner.faction = "camelot"

# ── walls: bounding frame + an interior GATE funnel near the top ───────────────
func _build_walls() -> void:
	var b := _world_bounds()
	_frame_walls(b)
	# The gate is a wall spanning the top interior with a central gap; short inner jambs below
	# the gap taper the courtyard mouth (the funnel throat). Built from plain _wall() rects so it
	# joins the world collision layer the raider nav routes around.
	var t := 24.0
	var gate_y := b.position.y + 150.0          # how far down the gate wall sits
	var half_gap := GATE_GAP * 0.5
	# Left and right gate walls, leaving GATE_GAP open in the centre.
	var left_w: float = (-half_gap) - b.position.x
	_wall(Rect2(b.position.x, gate_y, left_w, t))
	var right_x := half_gap
	var right_w: float = b.end.x - right_x
	_wall(Rect2(right_x, gate_y, right_w, t))
	# Two short inner jambs framing the gap that taper the courtyard mouth.
	var jamb_h := 90.0
	_wall(Rect2(-half_gap - t, gate_y, t, jamb_h))
	_wall(Rect2(half_gap, gate_y, t, jamb_h))

func _build_terrain() -> void:
	# A patch of churned, sticky mud just inside the gate mouth slows the raider rush (drag<1),
	# affecting only the raider/ally body layer (4) — Arthur (a different layer) passes freely.
	var b := _world_bounds()
	var mud := Rect2(-GATE_GAP * 0.7, b.position.y + 250.0, GATE_GAP * 1.4, 110.0)
	_add_zone(mud, 0.6, Vector2.ZERO, false, false, 4)

# ── allies: a small Camelot garrison holds the courtyard ──────────────────────
func _spawn_allies() -> void:
	var host = ALLIED_HOST.instantiate()
	host.position = Vector2(0.0, 320.0)
	host.face = Vector2.UP
	add_child(host)
	# Tint the host Camelot gold (colour only — team/groups stay as the AlliedHost set them).
	for u in (host.units if "units" in host else []):
		if is_instance_valid(u) and "faction" in u:
			u.faction = "camelot"

# ── objectives: repel every wave, defeat the officer, hold the line ───────────
func _compose_objectives() -> ObjectiveManager:
	max_breaches = 14
	defence_line_y = 420.0
	var mgr := ObjectiveManager.new()
	mgr.add(RepelWavesObjective.new("Repel the Saxon assault"))
	mgr.add(DefeatOfficerObjective.new("Break the warlord Octa"))
	mgr.add(HoldLineObjective.new("Hold the gate"))
	return mgr

# ── waves: 5 escalating Saxon assaults pouring through the gate gap ────────────
func _build_wave_spawner() -> WaveSpawner:
	var ws := WaveSpawner.new()
	var lane: float = _world_bounds().position.y + 70.0   # spawn just above the gate, march down
	ws.waves = [
		_loose_wave("LIGHT RAIDERS", LIGHT_SOLDIER, _scale(6), lane),
		_formation_wave("SHIELD WALL", SHIELD_WALL, lane),
		_formation_wave("SPEARS & SHIELDS", SPEAR_PHALANX, lane),
		_formation_wave("CAVALRY CHARGE", CHARGE_GROUP, lane),
		_formation_wave("OFFICER GUARD", OFFICER_GUARD, lane),
		_loose_wave("OCTA, SAXON WARLORD", OCTA, 1, lane),
	]
	return ws

func _loose_wave(label: String, scene: PackedScene, count: int, lane: float) -> Wave:
	var w := Wave.new()
	w.label = label
	var arr: Array[PackedScene] = [scene]
	w.scenes = arr
	w.count = count
	w.lane_y = lane
	# Spread along the gate mouth so they enter through the gap, not into a jamb.
	w.x_min = -GATE_GAP * 0.5 + 20.0
	w.x_max = GATE_GAP * 0.5 - 20.0
	w.team = "raiders"
	return w

func _formation_wave(label: String, formation: PackedScene, lane: float) -> Wave:
	var w := Wave.new()
	w.label = label
	w.formation = formation
	w.lane_y = lane
	# Centre the formation on the gate gap.
	w.x_min = -10.0
	w.x_max = 10.0
	w.team = "raiders"
	return w

# ── theme the raiders Saxon green as each wave lands ───────────────────────────
func _on_wave_spawned(idx: int, units: Array) -> void:
	super._on_wave_spawned(idx, units)
	for u in units:
		if is_instance_valid(u) and "faction" in u:
			u.faction = "saxon"

# ── churned-mud ground motifs (behind the units) ──────────────────────────────
## Wheel-ruts and boot-churn scoured into the frontier mud — drawn over the base floor, under the
## units. Deterministic (no randf), so it's static work that costs nothing per frame.
func _paint_region(b: Rect2) -> void:
	var cx := (b.position.x + b.end.x) * 0.5
	# A pair of parallel cart-ruts dragging down the central march lane toward the courtyard.
	var rut := Color(0.10, 0.09, 0.07, 0.5)
	for s in [-1.0, 1.0]:
		var sf := float(s)
		var pts := PackedVector2Array()
		for i in range(13):
			var f := float(i) / 12.0
			var y := lerpf(b.position.y + 170.0, b.end.y - 60.0, f)
			var x := cx + sf * 26.0 + sf * sin(f * PI) * 20.0
			pts.append(Vector2(x, y))
		for i in range(pts.size() - 1):
			draw_line(pts[i], pts[i + 1], rut, 3.0)
	# Scattered churn arcs trampled across the field (deterministic placement).
	var streak := Color(0.11, 0.10, 0.08, 0.4)
	for i in range(18):
		var fx := float((i * 113) % 1000) / 1000.0
		var fy := float((i * 271) % 1000) / 1000.0
		var c := Vector2(lerpf(b.position.x + 90.0, b.end.x - 90.0, fx),
			lerpf(b.position.y + 210.0, b.end.y - 60.0, fy))
		var a0 := float((i * 53) % 628) / 100.0
		draw_arc(c, 12.0 + float(i % 5) * 4.0, a0, a0 + 1.6, 8, streak, 2.0)

# ── cheap gate dressing on top of the base floor ───────────────────────────────
func _draw() -> void:
	super._draw()
	var b := _world_bounds()
	var gate_y := b.position.y + 150.0
	var half_gap := GATE_GAP * 0.5
	# Gate posts framing the gap (the banners + drum are now proper rippling decor scenes).
	var post := Color(0.22, 0.18, 0.16)
	var post_w := 16.0
	draw_rect(Rect2(-half_gap - post_w, gate_y - 18.0, post_w, 60.0), post)
	draw_rect(Rect2(half_gap, gate_y - 18.0, post_w, 60.0), post)
	# The defence line, drawn faintly so the held line reads.
	draw_line(Vector2(b.position.x, defence_line_y), Vector2(b.end.x, defence_line_y),
		Color(0.8, 0.3, 0.3, 0.18), 2.0)
