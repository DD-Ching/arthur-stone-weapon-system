class_name MountBadon
extends BattleMap
## Mount Badon (Mons Badonicus) — a HILLTOP last-stand, built on the reusable BattleMap base.
##
## Arthur's great victory: the Britons crown a hill and an endless SAXON horde climbs the
## slopes to break them. There is no single line to push — only the tide. Arthur plants the
## stone on the crest and ENDURES, holding the hill until the horde is spent (the reusable
## SurviveObjective: outlast the clock OR cut down enough Saxons) WHILE keeping them from
## pouring past the crest (the HoldLine constraint — too many over the top and the hill falls).
##
## Build once, reuse many: this is a THIN BattleMap subclass. It writes no level loop — it
## fills `_build_wave_spawner()` with growing Saxon hordes (Wave resources of the existing
## raider scenes, faction-tinted "saxon" as each wave lands), `_spawn_allies()` with a Briton
## host (AlliedHost tinted "camelot"), `_build_terrain()` with churned-mud slopes that slow
## the climb, and `_compose_objectives()` with Survive + HoldLine. The base owns Arthur, the
## HUD, the score screen, KO + time + breach tracking, the wave driving, and win/lose.

const LIGHT := preload("res://scenes/LightSoldier.tscn")
const SPEARMAN := preload("res://scenes/Spearman.tscn")
const HEAVY := preload("res://scenes/HeavyGuard.tscn")
const BRUTE := preload("res://scenes/Brute.tscn")
const OFFICER_GUARD := preload("res://scenes/formations/OfficerGuard.tscn")
const ALLIED_HOST := preload("res://scenes/formations/AlliedHost.tscn")

## How long the hilltop hold lasts, and the body-count that also wins it (either bar fills → win).
## Exported so a headless test can drive a short, deterministic survival window.
@export var survive_seconds := 75.0
@export var ko_target := 90

func _init() -> void:
	# Keep the slopes packed: pour the next wave in early (low clock) and the instant the horde
	# thins (high threshold), so the Saxon tide never gives the Britons a breather. A generous
	# breach budget — the hold is about endurance, but let too many crest the hill and it falls.
	density = 1.6
	wave_interval = 8.0
	wave_clear_threshold = 12
	max_breaches = 24
	defence_line_y = 300.0      # the crest: a Saxon past this has broken over the top

# ── theme ─────────────────────────────────────────────────────────────────────
func _map_title() -> String:
	return "MOUNT BADON"

func _opening_banner() -> String:
	return "HOLD THE HILL!"

func _arthur_start() -> Vector2:
	return Vector2(0.0, 200.0)   # on the crest, between the host below and the horde above

func _world_bounds() -> Rect2:
	return Rect2(-700.0, -480.0, 1400.0, 960.0)

# ── terrain: churned-mud slopes that slow the Saxon climb ──────────────────────
func _build_terrain() -> void:
	# Two muddy flanks on the slopes below the crest slow the raider/ally body layer (4) with
	# drag<1 — the horde mires as it climbs, but Arthur (a different layer) strides freely. The
	# centre lane stays clear so the main push still funnels onto the crest.
	var b := _world_bounds()
	var slope_y := defence_line_y - 220.0
	var slope_h := 200.0
	var flank_w := 320.0
	_add_zone(Rect2(b.position.x + 40.0, slope_y, flank_w, slope_h),
		0.62, Vector2.ZERO, false, false, 4)
	_add_zone(Rect2(b.end.x - 40.0 - flank_w, slope_y, flank_w, slope_h),
		0.62, Vector2.ZERO, false, false, 4)

# ── allies: a Briton host holds the crest at Arthur's back ─────────────────────
func _spawn_allies() -> void:
	var host = ALLIED_HOST.instantiate()
	host.position = Vector2(0.0, 300.0)
	host.face = Vector2.UP
	add_child(host)
	# Tint the host Camelot blue (colour only — team/groups stay as the AlliedHost set them).
	for u in (host.units if "units" in host else []):
		if is_instance_valid(u) and "faction" in u:
			u.faction = "camelot"

# ── objectives: hold the hill (survive) AND don't let it be overrun (hold line) ─
func _compose_objectives() -> ObjectiveManager:
	var mgr := ObjectiveManager.new()
	mgr.add(SurviveObjective.new(survive_seconds, ko_target, "Hold Mount Badon"))
	mgr.add(HoldLineObjective.new("Don't let the hill be overrun"))
	return mgr

# ── waves: escalating Saxon hordes climbing the hill, a Warlord in the last ────
func _build_wave_spawner() -> WaveSpawner:
	## An escalating Saxon flood: each wave is bigger and meaner. Early waves are raw LightSoldier
	## ceorls; mid waves stiffen with Spearmen; later waves add HeavyGuards and Brutes; the final
	## wave brings a Saxon Warlord (an OfficerGuard formation whose BannerBearer is the officer).
	## The data IS the level — growing the horde is editing numbers here, not adding code.
	var ws := WaveSpawner.new()
	var lane: float = _world_bounds().position.y + 70.0   # spawn above the crest, climb down
	ws.waves = [
		_horde_wave("SAXON CEORLS", 0, _scale(10), lane),
		_horde_wave("SAXON SPEARS", 1, _scale(12), lane),
		_horde_wave("SAXON SHIELDWALL", 2, _scale(14), lane),
		_horde_wave("SAXON HOUSECARLS", 3, _scale(16), lane),
		_horde_wave("THE GREAT HORDE", 4, _scale(20), lane),
		_warlord_wave(lane),
	]
	return ws

## One escalating Saxon horde wave. Early idx is raw LightSoldier ceorls; Spearmen stiffen the
## mid waves; HeavyGuards and Brutes pile onto the late tide. A mixed roster repeated up to ~n
## so the wave still grows in size and weight as the battle wears on.
func _horde_wave(label: String, idx: int, n: int, lane: float) -> Wave:
	var w := Wave.new()
	var roster: Array[PackedScene] = [LIGHT]
	if idx >= 4:
		roster = [LIGHT, SPEARMAN, HEAVY, BRUTE, LIGHT, SPEARMAN]
	elif idx >= 3:
		roster = [LIGHT, SPEARMAN, HEAVY, LIGHT]
	elif idx >= 2:
		roster = [LIGHT, SPEARMAN, LIGHT]
	elif idx >= 1:
		roster = [LIGHT, SPEARMAN]
	if roster.size() == 1:
		# Single-scene roster → the Spawner "repeat N" shorthand (a quick block of ceorls).
		w.scenes = roster
		w.count = n
	else:
		# A mixed horde: repeat the roster pattern up to ~n units so the wave still grows.
		var mixed: Array[PackedScene] = []
		for k in range(n):
			mixed.append(roster[k % roster.size()])
		w.scenes = mixed
		w.count = 0
	w.label = label
	w.team = "raiders"          # hostile (joins "targets"); faction "saxon" tint set on spawn
	w.lane_y = lane
	w.x_min = -540.0
	w.x_max = 540.0
	w.scatter = true
	return w

## The last wave — a Saxon Warlord and his guard. An OfficerGuard formation marches onto the
## crest; its BannerBearer commander is the officer leading the final push.
func _warlord_wave(lane: float) -> Wave:
	var w := Wave.new()
	w.label = "SAXON WARLORD"
	w.formation = OFFICER_GUARD
	w.lane_y = lane
	w.x_min = -10.0
	w.x_max = 10.0
	w.team = "raiders"
	return w

# ── theme the horde Saxon as each wave lands ──────────────────────────────────
func _on_wave_spawned(idx: int, units: Array) -> void:
	super._on_wave_spawned(idx, units)
	for u in units:
		if is_instance_valid(u) and "faction" in u:
			u.faction = "saxon"

# ── hill dressing on top of the base grid ─────────────────────────────────────
func _draw() -> void:
	super._draw()
	var b := _world_bounds()
	# A grassy hill crown under the crest — a lighter band the Britons hold.
	draw_rect(Rect2(b.position.x, defence_line_y, b.size.x, b.end.y - defence_line_y),
		Color(0.16, 0.22, 0.13, 0.55))
	# The hill crest line — the top the Saxons must not break over.
	var crest := Color(0.55, 0.66, 0.42, 0.9)
	draw_line(Vector2(b.position.x, defence_line_y), Vector2(b.end.x, defence_line_y), crest, 3.0)
	# A faint Briton muster-ring around Arthur's stand on the crown.
	draw_arc(_arthur_start(), 120.0, 0.0, TAU, 48, Color(0.40, 0.62, 0.95, 0.18), 3.0)
	# Banners: a Saxon horde banner above the crest (their side), a Briton banner below (ours).
	var saxon := Color(0.78, 0.32, 0.30)        # Saxon red
	var briton := Color(0.34, 0.56, 0.92)       # Camelot/Briton blue
	draw_rect(Rect2(-12.0, defence_line_y - 150.0, 24.0, 44.0), saxon)
	draw_rect(Rect2(-12.0, defence_line_y + 60.0, 24.0, 44.0), briton)
