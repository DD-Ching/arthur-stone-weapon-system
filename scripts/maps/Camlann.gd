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

# ── theme ──────────────────────────────────────────────────────────────────────
func _map_title() -> String:
	return "THE BATTLE OF CAMLANN"

func _opening_banner() -> String:
	return "END THE TRAITOR!"

func _arthur_start() -> Vector2:
	# Arthur stands at the heart of his line, the rebels pouring down from the north.
	return Vector2(0.0, 280.0)

func _world_bounds() -> Rect2:
	return Rect2(-680.0, -480.0, 1360.0, 980.0)

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

# ── objectives: repel every rebel wave AND defeat Mordred ───────────────────────
func _compose_objectives() -> ObjectiveManager:
	var mgr := ObjectiveManager.new()
	mgr.add(RepelWavesObjective.new("Repel Mordred's rebels"))
	mgr.add(DefeatOfficerObjective.new("Defeat Mordred"))
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

# ── bleak Camlann field: a doom-laden ground, a fallen banner, dramatic theming ─
func _draw() -> void:
	super._draw()
	var b := _world_bounds()
	# A bleak, ashen overlay across the field — the grey light of the legend's final day.
	draw_rect(b, Color(0.10, 0.09, 0.12, 0.55))
	# A blood-dark seam running across the centre of the field, the line of the great clash.
	var mid_y := b.position.y + b.size.y * 0.42
	draw_line(Vector2(b.position.x, mid_y), Vector2(b.end.x, mid_y),
		Color(0.45, 0.12, 0.14, 0.30), 4.0)
	# A FALLEN banner — Mordred's standard, toppled and lying in the dirt at the north field.
	_draw_fallen_banner(Vector2(-300.0, b.position.y + 160.0))
	# Arthur's Camelot banner still standing tall behind his line (the loyal host's rally point).
	var pole := Vector2(0.0, 430.0)
	draw_line(pole, pole + Vector2(0.0, -78.0), Color(0.30, 0.24, 0.16), 4.0)
	draw_rect(Rect2(pole.x, pole.y - 78.0, 30.0, 26.0), Color(0.92, 0.78, 0.30))   # Camelot gold
	# Scattered fallen spears/debris dotting the doomed field.
	var debris := Color(0.20, 0.18, 0.18, 0.5)
	for p in [Vector2(220.0, -120.0), Vector2(-180.0, 40.0), Vector2(360.0, 180.0),
			Vector2(-380.0, -240.0), Vector2(120.0, 300.0)]:
		draw_line(p, p + Vector2(34.0, 10.0), debris, 3.0)

## A toppled enemy standard lying in the dirt — pole askew, the rebel flag fallen flat. Cheap:
## one slanted pole line + a small drooping flag rect, drawn directly so the bleak field reads.
func _draw_fallen_banner(at: Vector2) -> void:
	var pole_end := at + Vector2(70.0, 22.0)
	draw_line(at, pole_end, Color(0.22, 0.18, 0.16), 5.0)               # the toppled pole
	# Mordred's black-purple flag, splayed flat on the ground at the pole's head.
	var rebel := Color(0.52, 0.33, 0.60, 0.85)
	draw_rect(Rect2(pole_end.x - 4.0, pole_end.y - 2.0, 30.0, 18.0), rebel)
	draw_line(pole_end, pole_end + Vector2(26.0, 16.0), rebel, 2.0)
