class_name RedCliffs
extends BattleMap
## The Burning Fords — a tidal ford choked with burning Saxon longships. The Saxon war-fleet,
## beached and chained hull-to-hull, is set ablaze; the survivors leap into the tide and wade the
## ford under a sky of fire. Arthur holds the south bank against the landing that gets across.
##
## This is a THIN BattleMap subclass: it only fills the theme hooks + the build hooks. All the
## orchestration (Arthur, HUD, score screen, wave driving, objectives, win/lose) is the base's.
## What makes it the Burning Fords is composition of the shared modules — water `TerrainZone` bands
## for the ford, several `FireZone` hazards for the burning fleet, a `WaveSpawner` of escalating
## raiders, allies on the south bank — no new mechanic, no copy-pasted level loop.

const ALLY_SHIELD := preload("res://scenes/AllyShield.tscn")
const ALLY_SPEAR := preload("res://scenes/AllySpear.tscn")
const ALLY_KNIGHT := preload("res://scenes/AllyKnight.tscn")
const FIRE_ZONE := preload("res://scenes/hazards/FireZone.tscn")
const LIGHT := preload("res://scenes/LightSoldier.tscn")
const SHIELD := preload("res://scenes/ShieldSoldier.tscn")
const SPEAR := preload("res://scenes/Spearman.tscn")
const HEAVY := preload("res://scenes/HeavyGuard.tscn")

# Bodies (Arthur + units + props) ride the enemy/arthur/prop layers; mask 14 = those layers,
# matching the river current so the flow shoves Arthur too. FireZone burns layer-3 bodies (mask 4).
const _WATER_MASK := 14

func _map_title() -> String:
	return "THE BURNING FORDS"

func _opening_banner() -> String:
	return "THE FLEET BURNS — HOLD THE FORD!"

func _arthur_start() -> Vector2:
	return Vector2(0.0, 300.0)   # the defended south bank

func _world_bounds() -> Rect2:
	return Rect2(-640.0, -440.0, 1280.0, 900.0)

# ── terrain: a flaming river crossing ────────────────────────────────────────
func _build_terrain() -> void:
	var b := _world_bounds()
	# Two deep-water bands across the middle (the river), flowing downstream. drag<1 slows wading
	# units, the current drifts loose bodies + nudges Arthur, dangerous routes raider AI toward the
	# ford, and it drowns the lightest units that stray into deep water — the chokepoint mechanic.
	var river_w := b.size.x
	_add_zone(Rect2(b.position.x, -120.0, river_w, 110.0), 0.93, Vector2(46.0, 0.0), true, true, _WATER_MASK)
	_add_zone(Rect2(b.position.x, -10.0, river_w, 110.0), 0.93, Vector2(52.0, 0.0), true, true, _WATER_MASK)
	# The ford itself: a calm crossing lane down the centre that raider AI aims at (the "crossing"
	# group). Not dangerous and no drown, so a unit can actually get across there.
	_mark_crossing(Vector2(0.0, -55.0))
	_mark_crossing(Vector2(0.0, 55.0))
	# The burning fleet: several FireZones drifting on the water (the chained Saxon longships ablaze).
	# Each burns any body that wades through it — fire that can actually finish a wounded raider.
	_place_fire(Rect2(-560.0, -118.0, 150.0, 104.0), 4.0, 0.4)
	_place_fire(Rect2(-250.0, -116.0, 170.0, 104.0), 5.0, 0.4)
	_place_fire(Rect2(150.0, -116.0, 160.0, 104.0), 4.5, 0.42)
	_place_fire(Rect2(420.0, -8.0, 170.0, 104.0), 5.0, 0.4)
	_place_fire(Rect2(-440.0, -6.0, 150.0, 104.0), 4.0, 0.44)

func _place_fire(world_rect: Rect2, dmg: float, tick: float) -> void:
	var fz := FIRE_ZONE.instantiate()
	fz.burn_dmg = dmg
	fz.tick = tick
	fz.setup_rect(world_rect)
	add_child(fz)

## A "crossing" marker the raider nav aims at when deep water blocks the straight line — funnels
## the warband into the ford instead of drowning en masse (reuses Enemy's avoid_danger nav).
func _mark_crossing(pos: Vector2) -> void:
	var m := Node2D.new()
	m.add_to_group("crossing")
	m.global_position = pos
	add_child(m)

# ── allies: the Briton line on the south bank ────────────────────────────────
func _spawn_allies() -> void:
	# Briton levies front the bank with shields + spears; a Camelot knight anchors the centre.
	# Allies fight FOR Arthur (team "ally"); faction is colour flavour only.
	var shields: Array = Spawner.spawn_count(self, ALLY_SHIELD, _scale(3), 230.0, -180.0, 180.0, false)
	var spears: Array = Spawner.spawn_count(self, ALLY_SPEAR, _scale(3), 270.0, -150.0, 150.0, false)
	for u in shields:
		_set_faction(u, "briton")
	for u in spears:
		_set_faction(u, "briton")
	# A lone Camelot knight anchors the centre — spawned via the same shared Spawner path
	# (it sets ai_enabled + position), not a hand-rolled instantiate block.
	var knights: Array = Spawner.spawn(self, [ALLY_KNIGHT], 260.0, 0.0, 0.0, false)
	for u in knights:
		_set_faction(u, "camelot")

func _set_faction(u, faction: String) -> void:
	if is_instance_valid(u) and "faction" in u:
		u.faction = faction

# ── objectives ───────────────────────────────────────────────────────────────
func _compose_objectives() -> ObjectiveManager:
	# Win by repelling every wave; lose if too many cross the ford onto the south bank.
	max_breaches = 12
	defence_line_y = 200.0
	var mgr := ObjectiveManager.new()
	mgr.add(RepelWavesObjective.new("Repel the Saxon landing"))
	mgr.add(HoldLineObjective.new("Hold the burning ford"))
	return mgr

# ── waves: the Saxon landing, escalating ─────────────────────────────────────
func _build_wave_spawner() -> WaveSpawner:
	var ws := WaveSpawner.new()
	ws.waves = [
		_loose_wave("LIGHT RAIDERS", LIGHT, 6, -380.0),
		_loose_wave("SHIELD LINE", SHIELD, 5, -400.0),
		_mixed_wave("MIXED VAN", [LIGHT, SPEAR, SHIELD], -390.0),
		_loose_wave("HEAVY GUARD", HEAVY, 4, -400.0),
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

# ── theme: stamp the raiders as Saxon (the war-fleet's landing force) ─────────
func _on_wave_spawned(idx: int, units: Array) -> void:
	for u in units:
		_set_faction(u, "saxon")
	super._on_wave_spawned(idx, units)
