class_name Camlann
extends BattleMap
## The Battle of Camlann — the FINAL battle of the Arthurian legend, where King Arthur faces
## the traitor Mordred and his rebel host on a bleak, doom-laden field. This is the climactic
## last stand: escalating waves of Mordred's rebels crash down, culminating in a final BOSS
## wave led by the traitor's own banner (an OfficerGuard whose BannerBearer is "MORDRED").
##
## A THIN BattleMap subclass: all orchestration (Arthur, HUD, score screen, wave driving,
## objective ticking, win/lose) lives in the base. Here we only script the escalating rebel
## waves, place a few loyal Round-Table allies, compose the two objectives (repel every wave +
## defeat Mordred), and theme the bleak field. Build once, reuse many — every unit is a shared
## scene, faction-tinted "rebel" for Mordred's army and "camelot" for Arthur's loyal knights.
## (The integrator will swap in a dedicated Mordred unit later; for now the OfficerGuard's
## BannerBearer is the DefeatOfficer target.)

const SHIELD := preload("res://scenes/ShieldSoldier.tscn")
const SPEARMAN := preload("res://scenes/Spearman.tscn")
const HEAVY := preload("res://scenes/HeavyGuard.tscn")
const BRUTE := preload("res://scenes/Brute.tscn")
const CAVALRY := preload("res://scenes/Cavalry.tscn")
const OFFICER_GUARD := preload("res://scenes/formations/OfficerGuard.tscn")
const MORDRED := preload("res://scenes/villains/Mordred.tscn")

const ALLY := preload("res://scenes/Ally.tscn")
# The Knights of the Round Table stand with Arthur at his last battle (the radiant "excalibur" look),
# and Morgan le Fay (the "sorceress") rides with Mordred's host.
const LANCELOT := preload("res://scenes/knights/Lancelot.tscn")
const GAWAIN := preload("res://scenes/knights/Gawain.tscn")
const PERCIVAL := preload("res://scenes/knights/Percival.tscn")
const BEDIVERE := preload("res://scenes/knights/Bedivere.tscn")
const MORGAN := preload("res://scenes/villains/MorganLeFay.tscn")

# Light scenery props (shared scenes) dressed onto the flanks — placement + config only.
const CRATE := preload("res://scenes/Crate.tscn")
const ROCK := preload("res://scenes/Rock.tscn")
const FENCE := preload("res://scenes/terrain/Fence.tscn")
const FACTION_BANNER := preload("res://scenes/decor/FactionBanner.tscn")
const WAR_DRUM := preload("res://scenes/decor/WarDrum.tscn")
const CAMELOT_BANNER := preload("res://scenes/decor/CamelotBanner.tscn")

# ── theme ──────────────────────────────────────────────────────────────────────
## Paint Camlann's identity FIRST (runs before any build): an ashen mauve-grey floor under a
## blood-red dusk tint — the bleak light of the legend's final, doom-laden day. The mood stays
## gentle (each channel >= 0.66) so the rebel/loyal hosts still read clearly across the field.
func _theme() -> void:
	ground_top = Color(0.17, 0.15, 0.16)        # ashen mauve-grey, top
	ground_bottom = Color(0.13, 0.11, 0.12)     # darker ashen, toward the loyal line
	region_mood = Color(0.92, 0.70, 0.66)       # blood-red dusk (subtle CanvasModulate tint)

func _map_title() -> String:
	return "THE BATTLE OF CAMLANN"

func _opening_banner() -> String:
	return "END THE TRAITOR!"

func _arthur_start() -> Vector2:
	# Arthur stands at the heart of his line, the rebels pouring down from the north.
	return Vector2(0.0, 280.0)

func _world_bounds() -> Rect2:
	return Rect2(-680.0, -480.0, 1360.0, 980.0)

# ── flank dressing: light scenery on the wings, central clash-lane kept clear ──
func _build_decor() -> void:
	## Dress the doomed field's flanks with EXISTING shared props (placement + config, no new art):
	## a rebel war-drum + standard on each northern wing (Mordred's host), Arthur's blue standard at
	## the loyal line's back, a fence rail on each flank, and a little battle-clutter of rocks + a
	## crate. All sit out on the wings (|x| large) so the centre lane the bosses march down stays
	## open and the final duel reads clean (the toppled banner in _draw stays at centre-north).
	super._build_decor()
	_dress_region()                # distant blasted treeline + drifting embers (sense of place)
	_scatter_battlefield_props()   # smashable battlefield clutter on the flanks (clear of the duel lane)
	# Rebel war-drums on the northern wings, driving Mordred's host down the field.
	_drum(Vector2(-500.0, -360.0))
	_drum(Vector2(500.0, -360.0))
	# Rebel standards planted on the wings (neutral-grey muster markers for the foe).
	_banner(Vector2(-560.0, -300.0), "neutral", 78.0)
	_banner(Vector2(560.0, -300.0), "neutral", 78.0)
	# Mordred's blazoned rebel standard, TOPPLED low in the dirt at the north field (the proper decor
	# scene at a short pole, in place of the old inline draw_rect fallen-banner).
	_camelot_banner(Vector2(-300.0, _world_bounds().position.y + 160.0), "rebel", 30.0)
	# Arthur's Camelot standard, blazoned with the Pendragon dragon, still flying tall behind the loyal
	# line — the rally point (the proper decor scene in place of the old inline gold banner block).
	_camelot_banner(Vector2(0.0, 430.0), "camelot", 86.0)
	# Arthur's Camelot-blue muster standard alongside it (rally cluster, off the central duel lane).
	_banner(Vector2(180.0, 430.0), "camelot", 86.0)
	# A rail of fencing on each flank — field furniture clear of the lane.
	_fence(Vector2(-520.0, 60.0))
	_fence(Vector2(520.0, 60.0))
	# Scattered battle-clutter (rocks + a crate) on the flanks for texture on the bleak field.
	for p in [Vector2(-470.0, -120.0), Vector2(-400.0, 140.0), Vector2(470.0, -120.0),
			Vector2(400.0, 140.0)]:
		_prop(ROCK, p)
	_prop(CRATE, Vector2(-560.0, 20.0))
	_prop(CRATE, Vector2(560.0, 20.0))

## Distant scenery + ambient particles that give the doomed field a sense of place: a blasted-oak
## treeline silhouette along the north edge, and ash-grey embers drifting up over the whole field.
func _dress_region() -> void:
	var b := _world_bounds()
	var bd := RegionBackdrop.new()
	bd.kind = "treeline"                                   # the blasted oaks ringing the last field
	bd.span = b.size.x
	bd.band_h = 160.0
	bd.silhouette = Color(0.09, 0.08, 0.09, 0.92)          # near-black, dead trees
	bd.haze_top = Color(0.34, 0.18, 0.18, 0.42)            # a blood-dusk haze fading into the field
	bd.haze_bottom = Color(0.34, 0.18, 0.18, 0.0)
	add_child(bd)
	bd.position = Vector2((b.position.x + b.end.x) * 0.5, b.position.y)
	var ad := AmbientDrift.new()
	ad.kind = "embers"
	ad.count = 40
	ad.area = b
	ad.tint = Color(0.7, 0.4, 0.35, 0.4)                   # ash grey-red embers
	ad.drift = Vector2(10.0, -24.0)                        # drifting gently up the field
	ad.size_px = 2.4
	add_child(ad)

func _camelot_banner(at: Vector2, fac: String, h: float) -> void:
	var bn = CAMELOT_BANNER.instantiate()
	if "faction" in bn:
		bn.faction = fac
	if "pole_height" in bn:
		bn.pole_height = h
	bn.position = at
	add_child(bn)

func _drum(at: Vector2) -> void:
	var d = WAR_DRUM.instantiate()
	if "faction" in d:
		d.faction = "rebel"          # ring it rebel (the traitor host's drum)
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

func _fence(at: Vector2) -> void:
	var f = FENCE.instantiate()
	f.position = at
	add_child(f)

func _prop(scene: PackedScene, at: Vector2) -> void:
	var p = scene.instantiate()
	p.position = at
	add_child(p)

# ── allies: a few loyal Round-Table knights stand with Arthur ───────────────────
func _spawn_allies() -> void:
	# A short loyal line just ahead of Arthur — they hunt the nearest rebel. The shared Spawner
	# takes a roster of SCENES (not instances) and lays them along the lane; we stamp the
	# Camelot gold colour so the loyal host reads against Mordred's black-purple rebels.
	var roster: Array = [BEDIVERE, LANCELOT, ALLY, GAWAIN, PERCIVAL]
	var line: Array = Spawner.spawn(self, roster, 360.0, -240.0, 240.0, false, true)
	for a in line:
		if is_instance_valid(a) and "faction" in a:
			a.faction = "camelot"

# ── objectives: repel every rebel wave, break the banner guard, AND fell the named bosses ─
func _compose_objectives() -> ObjectiveManager:
	var mgr := ObjectiveManager.new()
	mgr.add(RepelWavesObjective.new("Repel Mordred's rebels"))
	# The banner guard's commander still gates (the OfficerGuard's is_support BannerBearer).
	mgr.add(DefeatOfficerObjective.new("Break the banner guard"))
	# The named-boss gate: victory now requires felling the named generals — Morgan le Fay AND
	# Mordred the Traitor (both is_general, so they join the "generals" group the base surfaces
	# as ctx["generals"]). No number of cleared waves wins until the traitor himself is down.
	mgr.add(DefeatGeneralObjective.new("Defeat Mordred"))
	return mgr

# ── waves: escalating rebel assaults, ending in Mordred's banner guard ──────────
func _build_wave_spawner() -> WaveSpawner:
	var ws := WaveSpawner.new()
	var lane: float = _world_bounds().position.y + 80.0   # spawn at the north edge, march down
	ws.waves = [
		_loose_wave([SHIELD, SPEARMAN], 8, "REBEL VANGUARD", lane),
		_loose_wave([SPEARMAN, SHIELD, HEAVY], 10, "REBEL SHIELD LINE", lane),
		_loose_wave([HEAVY, BRUTE, SHIELD], 12, "REBEL HEAVY HOST", lane),
		_loose_wave([BRUTE, CAVALRY, SPEARMAN, SHIELD], 14, "REBEL CHARGE", lane),
		_officer_wave("MORDRED'S BANNER GUARD", lane),
		_boss_wave(MORGAN, "MORGAN LE FAY", lane),
		_boss_wave(MORDRED, "MORDRED, THE TRAITOR", lane),
	]
	return ws

## The true final foe: the traitor Mordred himself (a named general — the boss healthbar tracks
## him). Exactly ONE, centred, no density scaling — a single climactic duel after his guard falls.
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

## A loose rebel mob: a roster spread wide across the northern lane, scaled by the density dial.
func _loose_wave(roster: Array, n: int, label: String, lane: float) -> Wave:
	var w := Wave.new()
	w.label = label
	if roster.size() == 1:
		var arr: Array[PackedScene] = [roster[0]]
		w.scenes = arr
		w.count = _scale(n)
	else:
		w.scenes = _fill_roster(roster, _scale(n))
		w.count = 0
	w.lane_y = lane
	w.x_min = -380.0
	w.x_max = 380.0
	w.scatter = true
	w.team = "raiders"
	return w

## The FINAL boss wave: Mordred's banner guard marches in as a cohesive block. Its BannerBearer
## (the OfficerGuard commander, an is_support raider) is the DefeatOfficer target — "MORDRED".
func _officer_wave(label: String, lane: float) -> Wave:
	var w := Wave.new()
	w.label = label
	w.formation = OFFICER_GUARD
	w.lane_y = lane
	w.x_min = -10.0
	w.x_max = 10.0
	w.team = "raiders"
	return w

## Repeat a roster until it holds `n` scenes, so a multi-type wave spawns `n` units cycling
## through the listed types (keeps the loose-mob path, scenes.size()>1, honest).
func _fill_roster(roster: Array, n: int) -> Array[PackedScene]:
	var out: Array[PackedScene] = []
	if roster.is_empty():
		return out
	for i in range(n):
		out.append(roster[i % roster.size()])
	return out

# ── theme each wave: tint the rebels Mordred's black-purple as they arrive ──────
func _on_wave_spawned(idx: int, units: Array) -> void:
	super._on_wave_spawned(idx, units)   # keep the base "WAVE n / N" popup
	for u in units:
		if is_instance_valid(u) and "faction" in u:
			u.faction = "rebel"

# ── bleak Camlann ground motifs (static, behind the units) ──────────────────────
## The doom-laden floor dressing, painted over the shared region floor and BEHIND the units (so it
## never darkens a fighter): a thin ashen film, the blood-dark seam of the great clash, a toppled
## flag splayed in the dirt at the north field, and scattered fallen-spear debris across the field.
## All static — the standing banners are now proper decor scenes; nothing here animates, so there is
## no per-frame draw override (this runs once via the base's _draw).
func _paint_region(b: Rect2) -> void:
	# A thin ashen film across the field — the grey light of the legend's final day (kept light so
	# the floor still reads under the blood-dusk mood tint).
	draw_rect(b, Color(0.10, 0.09, 0.12, 0.28))
	# A blood-dark seam running across the centre of the field, the line of the great clash.
	var mid_y := b.position.y + b.size.y * 0.42
	draw_line(Vector2(b.position.x, mid_y), Vector2(b.end.x, mid_y),
		Color(0.45, 0.12, 0.14, 0.30), 4.0)
	# A splayed flag-cloth lying flat in the dirt at the foot of the toppled rebel standard.
	var rebel := Color(0.52, 0.33, 0.60, 0.55)
	draw_rect(Rect2(-238.0, b.position.y + 172.0, 30.0, 18.0), rebel)
	# Scattered fallen spears/debris dotting the doomed field.
	var debris := Color(0.20, 0.18, 0.18, 0.5)
	for p in [Vector2(220.0, -120.0), Vector2(-180.0, 40.0), Vector2(360.0, 180.0),
			Vector2(-380.0, -240.0), Vector2(120.0, 300.0)]:
		draw_line(p, p + Vector2(34.0, 10.0), debris, 3.0)
