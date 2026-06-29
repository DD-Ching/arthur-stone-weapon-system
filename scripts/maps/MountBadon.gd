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
const SAXON_WARLORD := preload("res://scenes/villains/SaxonWarlord.tscn")
const ALLIED_HOST := preload("res://scenes/formations/AlliedHost.tscn")

# Light scenery props (shared scenes) dressed onto the slopes/flanks — placement + config only.
const CRATE := preload("res://scenes/Crate.tscn")
const ROCK := preload("res://scenes/Rock.tscn")
const FENCE := preload("res://scenes/terrain/Fence.tscn")
const FACTION_BANNER := preload("res://scenes/decor/FactionBanner.tscn")
const CAMELOT_BANNER := preload("res://scenes/decor/CamelotBanner.tscn")
const WAR_DRUM := preload("res://scenes/decor/WarDrum.tscn")
const SAXON_ARCHER := preload("res://scenes/villains/SaxonArcher.tscn")  # lobs javelins — the stone can deflect them
const BARREL := preload("res://scenes/props/Barrel.tscn")
const HAYSTACK := preload("res://scenes/props/Haystack.tscn")
const CLAY_POT := preload("res://scenes/props/ClayPot.tscn")
const FIRE_BARREL := preload("res://scenes/props/FireBarrel.tscn")

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
## Mount Badon — the great victory, fought on a bright green hillside at noon. Set the floor to a
## sunlit grass gradient and a near-white warm "noon" mood (subtle; channels stay high so the units
## read cleanly). Runs FIRST in _ready, before any build, so the hill is themed from frame 0.
func _theme() -> void:
	ground_top = Color(0.18, 0.24, 0.15)        # green hill crown
	ground_bottom = Color(0.14, 0.19, 0.12)     # the slope below
	region_mood = Color(1.0, 0.98, 0.90)        # bright warm noon (near white)

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

# ── flank dressing: light scenery on the slopes, central lane kept clear ───────
func _build_decor() -> void:
	## Dress the two slope flanks with EXISTING shared props (placement + config, no new art):
	## Saxon war-drums + standards crowning the horde's side above the crest, a Briton banner at
	## the host's back, and a little muster clutter (rocks, a crate, a fence rail) on each flank.
	## Everything sits out on the wings (|x| large) so the centre push-lane onto the crest stays
	## open and the boss duel reads clean.
	super._build_decor()
	var b := _world_bounds()
	# (1) Distant scenery: a ring of standing stones crowning the far crest, so the hilltop reads as
	# a place. Placed at the world's top-centre, spanning the full width (drawn behind the units).
	var bd := RegionBackdrop.new()
	bd.kind = "stones"
	bd.span = b.size.x
	bd.silhouette = Color(0.12, 0.13, 0.13, 0.9)
	bd.haze_top = Color(0.42, 0.46, 0.38, 0.40)     # warm green-grey noon haze
	bd.haze_bottom = Color(0.42, 0.46, 0.38, 0.0)
	add_child(bd)
	bd.position = Vector2((b.position.x + b.end.x) * 0.5, b.position.y)
	# (2) Sun motes drifting on the bright noon air across the whole hill.
	var ad := AmbientDrift.new()
	ad.kind = "dust"
	ad.count = 40
	ad.area = b
	ad.tint = Color(0.9, 0.85, 0.6, 0.25)
	ad.drift = Vector2(16.0, 6.0)
	ad.size_px = 2.4
	add_child(ad)
	# Saxon war-drums driving the horde, high on each flank above the crest (their side).
	_drum(Vector2(-470.0, 120.0))
	_drum(Vector2(470.0, 120.0))
	# Saxon standards planted on the upper slopes — the Cerdic host's muster markers.
	_banner(Vector2(-360.0, 95.0), "saxon", 74.0)
	_banner(Vector2(360.0, 95.0), "saxon", 74.0)
	# The Briton muster at the host's back, below the crest (our rally point): a Camelot Pendragon
	# pennant flanked by a briton standard.
	_camelot_banner(Vector2(150.0, 420.0))
	_banner(Vector2(-150.0, 420.0), "briton", 84.0)
	# A rail of fencing low on each flank — a bit of field furniture that never blocks the lane.
	_fence(Vector2(-470.0, 250.0))
	_fence(Vector2(470.0, 250.0))
	# Scattered muster clutter (rocks + a crate) on the slope flanks for texture.
	for p in [Vector2(-420.0, 175.0), Vector2(-330.0, 215.0), Vector2(420.0, 175.0),
			Vector2(330.0, 215.0)]:
		_prop(ROCK, p)
	_prop(CRATE, Vector2(-500.0, 200.0))
	_prop(CRATE, Vector2(500.0, 200.0))
	# Smashable battlefield materials on the flanks — barrels, haystacks and pots to shatter, plus
	# a tactical fire-barrel each side (smash it to blow a knot of climbing Saxons off the slope).
	for p in [Vector2(-450.0, 150.0), Vector2(450.0, 150.0), Vector2(-380.0, 255.0), Vector2(380.0, 255.0)]:
		_prop(BARREL, p)
	for p in [Vector2(-540.0, 150.0), Vector2(540.0, 150.0)]:
		_prop(HAYSTACK, p)
	for p in [Vector2(-300.0, 260.0), Vector2(300.0, 260.0), Vector2(-250.0, 175.0), Vector2(250.0, 175.0)]:
		_prop(CLAY_POT, p)
	_prop(FIRE_BARREL, Vector2(-410.0, 110.0))
	_prop(FIRE_BARREL, Vector2(410.0, 110.0))

func _drum(at: Vector2) -> void:
	var d = WAR_DRUM.instantiate()
	if "faction" in d:
		d.faction = "saxon"          # the Saxon horde's drum
	d.position = at
	add_child(d)

func _banner(at: Vector2, fac: String, h: float) -> void:
	var bn = FACTION_BANNER.instantiate()
	if "faction" in bn:
		bn.faction = fac
	if "pole_height" in bn:
		bn.pole_height = h
	bn.position = at
	add_child(bn)

func _camelot_banner(at: Vector2) -> void:
	var bn = CAMELOT_BANNER.instantiate()
	if "faction" in bn:
		bn.faction = "camelot"
	bn.position = at
	add_child(bn)

func _fence(at: Vector2) -> void:
	var f = FENCE.instantiate()
	f.position = at
	add_child(f)

func _prop(scene: PackedScene, at: Vector2) -> void:
	var p = scene.instantiate()
	p.position = at
	add_child(p)

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

# ── objectives: hold the hill (survive), don't be overrun (hold line), AND fell Cerdic ─
func _compose_objectives() -> ObjectiveManager:
	var mgr := ObjectiveManager.new()
	mgr.add(SurviveObjective.new(survive_seconds, ko_target, "Hold Mount Badon"))
	mgr.add(HoldLineObjective.new("Don't let the hill be overrun"))
	# The named-boss gate: outlasting the clock isn't enough — the Saxon Warlord himself (the
	# final wave's is_general Cerdic) must fall before the hill is truly won (reads the "generals"
	# group the base surfaces as ctx["generals"]).
	mgr.add(DefeatGeneralObjective.new("Fell Cerdic"))
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
		_boss_wave(SAXON_WARLORD, "CERDIC, THE SAXON WARLORD", lane),
	]
	return ws

## The true last foe: the Saxon Warlord himself (a named general — the boss healthbar tracks him).
## Exactly ONE, centred, no density scaling — a single climactic duel after his guard is broken.
func _boss_wave(scene: PackedScene, label: String, lane: float) -> Wave:
	var w := Wave.new()
	w.label = label
	var arr: Array[PackedScene] = [scene]
	w.scenes = arr
	w.count = 1
	w.lane_y = lane
	w.x_min = -10.0
	w.x_max = 10.0
	w.team = "raiders"
	return w

## One escalating Saxon horde wave. Early idx is raw LightSoldier ceorls; Spearmen stiffen the
## mid waves; HeavyGuards and Brutes pile onto the late tide. A mixed roster repeated up to ~n
## so the wave still grows in size and weight as the battle wears on.
func _horde_wave(label: String, idx: int, n: int, lane: float) -> Wave:
	var w := Wave.new()
	var roster: Array[PackedScene] = [LIGHT]
	if idx >= 4:
		roster = [LIGHT, SPEARMAN, SAXON_ARCHER, HEAVY, BRUTE, LIGHT, SAXON_ARCHER, SPEARMAN]
	elif idx >= 3:
		roster = [LIGHT, SPEARMAN, SAXON_ARCHER, HEAVY, LIGHT]
	elif idx >= 2:
		roster = [LIGHT, SPEARMAN, SAXON_ARCHER, LIGHT]
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

# ── hill ground motifs (drawn over the shared floor, behind the units) ─────────
## Region ground identity for Mount Badon: a faint slope shade (darker upslope, where the Saxons
## climb), grass-blade flecks scattered across the hillside, a lighter grassy crown the Britons
## hold, the crest line they must not be broken over, and a faint Briton muster-ring on the crown.
## All static + deterministic (no per-frame randomness); the crude inline banner rects are gone —
## proper banner/drum decor scenes stand in their place (see `_build_decor`).
func _paint_region(b: Rect2) -> void:
	# A faint slope shade: darkest at the very top of the hill, fading to nothing at the crest, so
	# the slope reads as rising ground the horde toils up.
	var bands := 8
	for i in range(bands):
		var f0 := float(i) / float(bands)
		var f1 := float(i + 1) / float(bands)
		var y0 := lerpf(b.position.y, defence_line_y, f0)
		var y1 := lerpf(b.position.y, defence_line_y, f1)
		draw_rect(Rect2(b.position.x, y0, b.size.x, y1 - y0),
			Color(0.05, 0.06, 0.04, 0.14 * (1.0 - f0)))
	# A grassy hill crown under the crest — a lighter band the Britons hold.
	draw_rect(Rect2(b.position.x, defence_line_y, b.size.x, b.end.y - defence_line_y),
		Color(0.16, 0.22, 0.13, 0.55))
	# Grass-blade flecks scattered across the whole hillside (deterministic seed → static texture).
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260629
	var grass := Color(0.34, 0.46, 0.22, 0.5)
	for _i in range(220):
		var gx := rng.randf_range(b.position.x, b.end.x)
		var gy := rng.randf_range(b.position.y, b.end.y)
		var hgt := rng.randf_range(3.0, 7.0)
		var lean := rng.randf_range(-1.6, 1.6)
		draw_line(Vector2(gx, gy), Vector2(gx + lean, gy - hgt), grass, 1.0)
	# The hill crest line — the top the Saxons must not break over.
	draw_line(Vector2(b.position.x, defence_line_y), Vector2(b.end.x, defence_line_y),
		Color(0.55, 0.66, 0.42, 0.9), 3.0)
	# A faint Briton muster-ring around Arthur's stand on the crown.
	draw_arc(_arthur_start(), 120.0, 0.0, TAU, 48, Color(0.40, 0.62, 0.95, 0.18), 3.0)
