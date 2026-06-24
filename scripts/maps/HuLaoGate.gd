class_name HuLaoGate
extends BattleMap
## Hu Lao Gate (虎牢關) — a fortress-gate chokepoint battle, built on the reusable BattleMap base.
##
## The raiders (魏 Wei) pour through a narrow GATE funnel cut into the top wall; Arthur and a
## small allied host (蜀 Shu) hold the courtyard below. This map is a THIN subclass: it only
## overrides the build hooks (walls + the gate funnel, terrain, allies, waves, objectives,
## theme). All orchestration — Arthur, HUD, score, wave driving, breaches, win/lose — lives in
## BattleMap and is never re-implemented here.
##
## Build once, reuse many: the gate is plain `_wall()` rectangles; the waves are `Wave`
## resources composed in code (loose raiders → ShieldWall → spears+shields → Cavalry charge →
## an OfficerGuard whose BannerBearer is the officer to defeat); objectives are the shared
## RepelWaves + DefeatOfficer + HoldLine.

const SHIELD_WALL := preload("res://scenes/formations/ShieldWall.tscn")
const SPEAR_PHALANX := preload("res://scenes/formations/SpearPhalanx.tscn")
const CHARGE_GROUP := preload("res://scenes/formations/ChargeGroup.tscn")
const OFFICER_GUARD := preload("res://scenes/formations/OfficerGuard.tscn")
const ALLIED_HOST := preload("res://scenes/formations/AlliedHost.tscn")
const LIGHT_SOLDIER := preload("res://scenes/LightSoldier.tscn")
const LU_BU := preload("res://scenes/generals/LuBu.tscn")

const GATE_GAP := 150.0          ## width of the funnel mouth the raiders pour through

# ── theme ─────────────────────────────────────────────────────────────────────
func _map_title() -> String:
	return "HU LAO GATE 虎牢關"

func _opening_banner() -> String:
	return "HOLD THE GATE!"

func _arthur_start() -> Vector2:
	return Vector2(0.0, 240.0)

func _world_bounds() -> Rect2:
	return Rect2(-640.0, -440.0, 1280.0, 900.0)

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

# ── allies: a small Shu host holds the courtyard ──────────────────────────────
func _spawn_allies() -> void:
	var host = ALLIED_HOST.instantiate()
	host.position = Vector2(0.0, 320.0)
	host.face = Vector2.UP
	add_child(host)
	# Tint the host Shu green (colour only — team/groups stay as the AlliedHost set them).
	for u in (host.units if "units" in host else []):
		if is_instance_valid(u) and "faction" in u:
			u.faction = "shu"

# ── objectives: repel every wave, defeat the officer, hold the line ───────────
func _compose_objectives() -> ObjectiveManager:
	max_breaches = 14
	defence_line_y = 420.0
	var mgr := ObjectiveManager.new()
	mgr.add(RepelWavesObjective.new("Repel the Wei assault"))
	mgr.add(DefeatOfficerObjective.new("Defeat the Wei officer"))
	mgr.add(HoldLineObjective.new("Hold the gate"))
	return mgr

# ── waves: 5 escalating Wei assaults pouring through the gate gap ──────────────
func _build_wave_spawner() -> WaveSpawner:
	var ws := WaveSpawner.new()
	var lane: float = _world_bounds().position.y + 70.0   # spawn just above the gate, march down
	ws.waves = [
		_loose_wave("LIGHT RAIDERS", LIGHT_SOLDIER, _scale(6), lane),
		_formation_wave("SHIELD WALL", SHIELD_WALL, lane),
		_formation_wave("SPEARS & SHIELDS", SPEAR_PHALANX, lane),
		_formation_wave("CAVALRY CHARGE", CHARGE_GROUP, lane),
		_formation_wave("OFFICER GUARD", OFFICER_GUARD, lane),
		_loose_wave("WARLORD 呂布 LU BU", LU_BU, 1, lane),
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

# ── theme the raiders Wei blue as each wave lands ─────────────────────────────
func _on_wave_spawned(idx: int, units: Array) -> void:
	super._on_wave_spawned(idx, units)
	for u in units:
		if is_instance_valid(u) and "faction" in u:
			u.faction = "wei"

# ── cheap gate dressing on top of the base grid ───────────────────────────────
func _draw() -> void:
	super._draw()
	var b := _world_bounds()
	var gate_y := b.position.y + 150.0
	var half_gap := GATE_GAP * 0.5
	# Gate posts framing the gap.
	var post := Color(0.22, 0.18, 0.16)
	var post_w := 16.0
	draw_rect(Rect2(-half_gap - post_w, gate_y - 18.0, post_w, 60.0), post)
	draw_rect(Rect2(half_gap, gate_y - 18.0, post_w, 60.0), post)
	# A Wei banner above the gate (enemy side) and a Shu banner below (our side).
	var wei := Color(0.30, 0.52, 0.95)
	var shu := Color(0.36, 0.78, 0.42)
	draw_rect(Rect2(-12.0, gate_y - 64.0, 24.0, 40.0), wei)
	draw_rect(Rect2(-12.0, 360.0, 24.0, 40.0), shu)
	# The defence line, drawn faintly so the held line reads.
	draw_line(Vector2(b.position.x, defence_line_y), Vector2(b.end.x, defence_line_y),
		Color(0.8, 0.3, 0.3, 0.18), 2.0)
