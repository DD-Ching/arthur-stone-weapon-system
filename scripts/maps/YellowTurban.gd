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
