class_name DefendCamelot
extends BattleMap
## Defend Camelot — a SIEGE of the castle, built on the reusable BattleMap base.
##
## Arthur and the castle garrison (Camelot gold) hold the GATE of Camelot while a Saxon /
## Mordred-rebel host storms it. The besiegers pour through a single GATE gap cut into the
## south-facing castle wall (a chokepoint funnel, like Hu Lao Gate — but a castle gate with
## corner towers); a raider that pushes past the courtyard DEFENCE LINE has breached the
## castle, and too many breaches lose it. Hold the gate, repel every wave, and fell Mordred's
## siege commander to win.
##
## A THIN BattleMap subclass: it only overrides the build hooks (walls + the gate funnel +
## towers, decor/banners, garrison allies, escalating siege waves, objectives, theme). All
## orchestration — Arthur, HUD, score, wave driving, breaches, win/lose — lives in BattleMap
## and is never re-implemented here.

const SHIELD_WALL := preload("res://scenes/formations/ShieldWall.tscn")
const SPEAR_PHALANX := preload("res://scenes/formations/SpearPhalanx.tscn")
const CHARGE_GROUP := preload("res://scenes/formations/ChargeGroup.tscn")
const OFFICER_GUARD := preload("res://scenes/formations/OfficerGuard.tscn")
const ALLIED_HOST := preload("res://scenes/formations/AlliedHost.tscn")
const LIGHT_SOLDIER := preload("res://scenes/LightSoldier.tscn")
const BRUTE := preload("res://scenes/Brute.tscn")
const ALLY := preload("res://scenes/Ally.tscn")
const ALLY_SHIELD := preload("res://scenes/AllyShield.tscn")
const BLACK_KNIGHT := preload("res://scenes/villains/BlackKnight.tscn")

const GATE_GAP := 160.0          ## width of the castle-gate gap the besiegers pour through
const WALL_Y_OFFSET := 150.0     ## how far below the top frame the castle wall sits
const TOWER := 64.0              ## side of each square corner tower block

# ── theme ─────────────────────────────────────────────────────────────────────
func _map_title() -> String:
	return "DEFEND CAMELOT"

func _opening_banner() -> String:
	return "HOLD THE GATE!"

func _arthur_start() -> Vector2:
	# Arthur stands in the gateway mouth, the last man between the breach and the courtyard.
	return Vector2(0.0, 250.0)

func _world_bounds() -> Rect2:
	return Rect2(-640.0, -440.0, 1280.0, 900.0)

# ── walls: bounding frame + the CASTLE WALL with a central GATE + corner towers ─
func _build_walls() -> void:
	var b := _world_bounds()
	_frame_walls(b)
	var t := 28.0
	var wall_y := b.position.y + WALL_Y_OFFSET     # the castle's south wall line
	var half_gap := GATE_GAP * 0.5
	# Left and right curtain walls, leaving GATE_GAP open in the centre (the gate).
	var left_w: float = (-half_gap) - b.position.x
	_wall(Rect2(b.position.x, wall_y, left_w, t))
	var right_x := half_gap
	var right_w: float = b.end.x - right_x
	_wall(Rect2(right_x, wall_y, right_w, t))
	# Inner gate jambs that taper the gate mouth into the courtyard (the funnel throat).
	var jamb_h := 96.0
	_wall(Rect2(-half_gap - t, wall_y, t, jamb_h))
	_wall(Rect2(half_gap, wall_y, t, jamb_h))
	# Two corner towers — solid square blocks anchoring the curtain wall at the bounds corners.
	_wall(Rect2(b.position.x, wall_y - TOWER * 0.5, TOWER, TOWER))
	_wall(Rect2(b.end.x - TOWER, wall_y - TOWER * 0.5, TOWER, TOWER))

func _build_terrain() -> void:
	# Churned siege mud just inside the gate mouth slows the storming rush (drag < 1). It only
	# affects the raider/ally body layer (4) — Arthur (a different layer) passes through freely.
	var b := _world_bounds()
	var mud := Rect2(-GATE_GAP * 0.7, b.position.y + WALL_Y_OFFSET + 110.0, GATE_GAP * 1.4, 120.0)
	_add_zone(mud, 0.6, Vector2.ZERO, false, false, 4)

# ── allies: the castle garrison holds the courtyard ───────────────────────────
func _spawn_allies() -> void:
	# The main garrison host, formed up behind the gate facing the breach.
	var host = ALLIED_HOST.instantiate()
	host.position = Vector2(0.0, 340.0)
	host.face = Vector2.UP
	add_child(host)
	for u in (host.units if "units" in host else []):
		_tint(u, "camelot")
	# A few loose men-at-arms flanking the gateway so the garrison reads as a real defence.
	var roster: Array = [ALLY_SHIELD, ALLY, ALLY_SHIELD, ALLY]
	var line: Array = Spawner.spawn(self, roster, 300.0, -230.0, 230.0, false, true)
	for a in line:
		_tint(a, "camelot")

## Tint a unit with a faction colour (pure readability flavour — team/groups unchanged).
func _tint(unit, faction_name: String) -> void:
	if is_instance_valid(unit) and "faction" in unit:
		unit.faction = faction_name

# ── objectives: hold the gate, repel the siege, fell the commander ────────────
func _compose_objectives() -> ObjectiveManager:
	# A raider past the courtyard line has breached the castle; 12 breaches lose it.
	max_breaches = 12
	defence_line_y = 430.0
	var mgr := ObjectiveManager.new()
	mgr.add(RepelWavesObjective.new("Repel the siege"))
	mgr.add(DefeatOfficerObjective.new("Fell the siege commander"))
	mgr.add(HoldLineObjective.new("Hold the gate"))
	return mgr

# ── waves: escalating siege assaults pouring through the gate gap ──────────────
func _build_wave_spawner() -> WaveSpawner:
	var ws := WaveSpawner.new()
	var lane: float = _world_bounds().position.y + 70.0   # spawn above the wall, march down
	ws.waves = [
		_loose_wave("SAXON RAIDERS", LIGHT_SOLDIER, _scale(6), lane),
		_formation_wave("SHIELD WALL", SHIELD_WALL, lane),
		_formation_wave("SPEAR PHALANX", SPEAR_PHALANX, lane),
		_loose_wave("BATTERING BRUTES", BRUTE, _scale(4), lane),
		_formation_wave("CAVALRY CHARGE", CHARGE_GROUP, lane),
		_formation_wave("MORDRED'S GUARD", OFFICER_GUARD, lane),
		_loose_wave("THE BLACK KNIGHT", BLACK_KNIGHT, 1, lane),
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

# ── theme each besieger wave: Saxon moss-green, with Mordred's guard the rebels ─
func _on_wave_spawned(idx: int, units: Array) -> void:
	super._on_wave_spawned(idx, units)
	# The final commander wave is Mordred's rebels (black-purple); the rest are Saxons.
	var fac := "rebel" if idx >= _wave_count() - 1 else "saxon"
	for u in units:
		_tint(u, fac)

# ── castle dressing on top of the base grid ───────────────────────────────────
func _draw() -> void:
	super._draw()
	var b := _world_bounds()
	var wall_y := b.position.y + WALL_Y_OFFSET
	var t := 28.0
	var half_gap := GATE_GAP * 0.5
	var stone := Color(0.30, 0.29, 0.33)
	var stone_dark := Color(0.20, 0.19, 0.23)
	# Curtain-wall stone facing over the collision rects, left and right of the gate.
	draw_rect(Rect2(b.position.x, wall_y, (-half_gap) - b.position.x, t), stone)
	draw_rect(Rect2(half_gap, wall_y, b.end.x - half_gap, t), stone)
	# Crenellations (merlons) along the top of each curtain section.
	_draw_crenellations(b.position.x, -half_gap, wall_y, stone_dark)
	_draw_crenellations(half_gap, b.end.x, wall_y, stone_dark)
	# Corner towers, drawn over their collision blocks, with a darker crenellated cap.
	for tx in [b.position.x, b.end.x - TOWER]:
		var tr := Rect2(tx, wall_y - TOWER * 0.5, TOWER, TOWER)
		draw_rect(tr, stone)
		draw_rect(Rect2(tr.position.x, tr.position.y, tr.size.x, 8.0), stone_dark)
	# Gate posts framing the gap.
	var post := Color(0.18, 0.16, 0.18)
	var post_w := 18.0
	draw_rect(Rect2(-half_gap - post_w, wall_y - 20.0, post_w, t + 40.0), post)
	draw_rect(Rect2(half_gap, wall_y - 20.0, post_w, t + 40.0), post)
	# The Camelot / Pendragon banner over the gate (gold field), the defenders' colour.
	var gold := Color(0.92, 0.78, 0.30)
	draw_line(Vector2(0.0, wall_y - 74.0), Vector2(0.0, wall_y - 20.0), Color(0.5, 0.42, 0.16), 2.0)
	draw_rect(Rect2(-14.0, wall_y - 70.0, 28.0, 46.0), gold)
	# A small defenders' standard inside the courtyard too.
	draw_rect(Rect2(-12.0, 360.0, 24.0, 40.0), gold)
	# The courtyard defence line, drawn faintly so the held line reads.
	draw_line(Vector2(b.position.x, defence_line_y), Vector2(b.end.x, defence_line_y),
		Color(0.85, 0.3, 0.3, 0.18), 2.0)

## A row of crenellation merlons along the top edge of a curtain-wall span [x0, x1].
func _draw_crenellations(x0: float, x1: float, wall_y: float, col: Color) -> void:
	var merlon_w := 18.0
	var step := 32.0
	var x := x0 + 4.0
	while x + merlon_w <= x1:
		draw_rect(Rect2(x, wall_y - 12.0, merlon_w, 12.0), col)
		x += step
