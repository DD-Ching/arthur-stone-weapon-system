class_name YellowTurban
extends BattleMap
## Yellow Turban Rebellion (黃巾之亂) — a SURVIVAL horde map.
##
## 184 AD: the yellow-turban mob (黃巾) rises in a peasant flood. There is no line to hold and
## no officer to fell — only an endless, escalating tide of cheap rebels. Arthur plants himself
## in the open and ENDURES: the battle is won by outlasting the clock OR cutting down enough of
## the swarm (the reusable `SurviveObjective`).
##
## Build once, reuse many: this is a THIN BattleMap subclass. It writes no level loop — it just
## fills `_build_wave_spawner()` with growing loose hordes (Wave resources of the existing cheap
## raider scenes, faction "neutral" → the grey/yellow mob colour) and `_compose_objectives()`
## with a SurviveObjective. The base owns Arthur, the HUD, the score screen, KO + time tracking,
## the wave driving, and win/lose. Short `wave_interval` + high `wave_clear_threshold` keep the
## field packed so the survival pressure never lets up. No breaches — survival, not a defence.

const LIGHT := preload("res://scenes/LightSoldier.tscn")
const SKIRMISHER := preload("res://scenes/Skirmisher.tscn")
const OUTRIDER := preload("res://scenes/Outrider.tscn")

# Light flank scenery — existing reusable props, PLACED not coded. Crates + rocks the mob can
# barge, fences along the outer flanks, and a rebel war drum + standard out on each wing. The
# CENTRAL lane (Arthur's stand) stays clear so the swarm always has an open path in.
const CRATE := preload("res://scenes/Crate.tscn")
const ROCK := preload("res://scenes/Rock.tscn")
const FENCE := preload("res://scenes/terrain/Fence.tscn")
const BANNER := preload("res://scenes/decor/FactionBanner.tscn")
const WAR_DRUM := preload("res://scenes/decor/WarDrum.tscn")

## How long the last-stand lasts, and the body-count that also wins it (either bar fills → win).
@export var survive_seconds := 90.0
@export var ko_target := 120

func _init() -> void:
	# Keep the field a packed swarm: pour the next wave in early (low clock) and the moment the
	# mob thins (high threshold), so the horde never gives Arthur a breather.
	density = 2.0
	wave_interval = 7.0
	wave_clear_threshold = 14
	max_breaches = 0            # survival: no defence line, nothing to "breach"

func _map_title() -> String:
	return "黃巾之亂 — YELLOW TURBAN REBELLION"

func _opening_banner() -> String:
	return "蒼天已死! THE HORDE RISES — SURVIVE!"

func _arthur_start() -> Vector2:
	return Vector2(0.0, 60.0)   # near the middle: the mob closes from every lane

func _world_bounds() -> Rect2:
	return Rect2(-700.0, -480.0, 1400.0, 960.0)

func _compose_objectives() -> ObjectiveManager:
	var mgr := ObjectiveManager.new()
	mgr.add(SurviveObjective.new(survive_seconds, ko_target,
		"Survive the Yellow Turban horde"))
	return mgr

# ── decor: light interactive scenery on the FLANKS (central lane kept clear) ──
func _build_decor() -> void:
	## Pure PLACEMENT of existing reusable props out on the two wings (x past the spawn lanes,
	## inside the ±700 walls) — a rebel war drum + standard mark each wing, a fence rails the outer
	## edge, and a few shovable crates/rocks litter the flank. Nothing sits in the central corridor
	## around Arthur's stand, so the mob always has an open path to close in (survival pressure
	## unchanged). The data IS the scenery — adding more is editing this list, not writing code.
	for side in [-1.0, 1.0]:
		# Rebel camp dressing on the wing (FactionBanner/WarDrum use the wei/shu/wu/neutral enum;
		# "neutral" reads the grey/ochre mob look, matching the yellow-turban rabble).
		_place_decor(BANNER, Vector2(560.0 * side, -260.0), "neutral")
		_place_decor(WAR_DRUM, Vector2(620.0 * side, -200.0), "neutral")
		_place_decor(BANNER, Vector2(560.0 * side, 280.0), "neutral")
		# A fence railing the outer flank (a low vertical rail, resized from the default shape).
		_place_fence(Vector2(650.0 * side, 0.0), Vector2(28.0, 260.0))
		# Shovable props scattered on the wing — the mob barges through them as it pours in.
		_place_prop(CRATE, Vector2(540.0 * side, -60.0))
		_place_prop(CRATE, Vector2(560.0 * side, 120.0))
		_place_prop(ROCK, Vector2(600.0 * side, 40.0))
		_place_prop(ROCK, Vector2(500.0 * side, 200.0))

## Drop a code-drawn decor prop (FactionBanner / WarDrum) at a spot, tinting it to a faction.
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

func _build_wave_spawner() -> WaveSpawner:
	## An escalating rebel flood: each wave is bigger and a touch meaner than the last, arriving
	## from alternating lanes. Cheap rebels only (Light / Skirmisher / Outrider) — the data IS the
	## level, so growing the horde is editing numbers here, not adding code.
	var ws := WaveSpawner.new()
	var waves: Array[Wave] = []
	var lanes := [-440.0, 440.0, -440.0, 440.0, -440.0, 440.0, -440.0, 440.0, -440.0]
	var sizes := [10, 12, 15, 18, 21, 24, 28, 32, 40]
	for i in range(sizes.size()):
		waves.append(_rebel_wave(i, sizes[i], lanes[i]))
	ws.waves = waves
	return ws

## One escalating horde wave. Early waves are raw LightSoldier rebels; mid waves mix in
## Skirmishers (loose javelin throwers); later waves add fast Outriders to pile on the pressure.
func _rebel_wave(idx: int, n: int, lane: float) -> Wave:
	var w := Wave.new()
	var roster: Array[PackedScene] = [LIGHT]
	if idx >= 5:
		roster = [LIGHT, SKIRMISHER, OUTRIDER, LIGHT, OUTRIDER]
	elif idx >= 2:
		roster = [LIGHT, SKIRMISHER, LIGHT]
	if roster.size() == 1:
		# Single-scene roster → the Spawner "repeat N" shorthand (a quick block of LightSoldiers).
		w.scenes = roster
		w.count = n
	else:
		# A mixed mob: repeat the roster pattern up to ~n units so the wave still grows.
		var mixed: Array[PackedScene] = []
		for k in range(n):
			mixed.append(roster[k % roster.size()])
		w.scenes = mixed
		w.count = 0
	w.label = "YELLOW TURBAN MOB"
	w.team = "raiders"          # hostile (joins "targets"); the scenes' faction "neutral" = mob look
	w.lane_y = lane
	w.x_min = -460.0
	w.x_max = 460.0
	w.scatter = true
	return w

func _draw() -> void:
	# A dusty-ochre rebellion ground (the yellow-turban earth) under the base grid lines.
	var b := _world_bounds()
	draw_rect(b, Color(0.20, 0.17, 0.10))
	for x in range(int(b.position.x), int(b.end.x) + 1, 80):
		draw_line(Vector2(x, b.position.y), Vector2(x, b.end.y), Color(1, 1, 1, 0.03), 1.0)
	for y in range(int(b.position.y), int(b.end.y) + 1, 80):
		draw_line(Vector2(b.position.x, y), Vector2(b.end.x, y), Color(1, 1, 1, 0.03), 1.0)
	# A faint yellow muster-ring around Arthur's stand (kept in sync with his start).
	draw_arc(_arthur_start(), 120.0, 0.0, TAU, 48, Color(0.85, 0.78, 0.25, 0.18), 3.0)
