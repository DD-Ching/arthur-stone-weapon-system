extends Node2D
## Hold the Ford — Arthur (and a few allies) hold a river crossing against a raider
## warband that attacks in five escalating waves and tries to cross.
##
## This is a LEVEL: it assembles reusable modules and runs the level's own rules. The
## reusable parts live elsewhere — terrain is `TerrainZone`, spawning is `Spawner`,
## all force/scoring is `Impact`, every enemy is a config of `Enemy`. What stays here is
## level-specific: the layout, the 5-wave script, the breach lose / wave-clear win, the
## collapsible bridge, and the log hazards. Drop the same modules in a new scene + tune
## parameters to build a different battle.

const HALF := Vector2(900.0, 560.0)
const GRID_STEP := 100

## Static fences/obstacles (also drawn). World-space Rect2 (top-left + size).
const FENCES := [
	Rect2(-540, -260, 30, 360),   # left funnel wall
	Rect2(510, -260, 30, 360),    # right funnel wall
	Rect2(-300, -360, 220, 28),   # back-left fence behind the line
	Rect2(80, -360, 220, 28),     # back-right fence
]
## Terrain rects (drawn here; the matching TerrainZone rules are spawned over them).
const MUD := [ Rect2(-340, 60, 680, 90) ]
const RIVER := [
	Rect2(-900, 212, 830, 112),   # left of the bridge
	Rect2(70, 212, 830, 112),     # right of the bridge
]
const BRIDGE := Rect2(-70, 200, 140, 136)        ## dry deck (drawn; the gap in the river)
const BRIDGE_GAP := Rect2(-70, 212, 140, 112)    ## becomes deep water once the bridge falls
const MUD_DRAG := 0.86
const WATER_DRAG := 0.93
const CURRENT := Vector2(48.0, 0.0)              ## downstream push (left → right)

## Arthur's home bank: a raider that gets south of this line has broken through.
const DEFENCE_Y := 480.0
const GOAL_POS := Vector2(0.0, 528.0)            ## the allied banner the raiders march at
const CROSS_POS := Vector2(0.0, 268.0)           ## the bridge — the crossing NPCs aim for

# layer bits: arthur=2, enemies/allies=4, props=8
const MASK_UNITS_PROPS := 12     ## enemies + allies + props
const MASK_WITH_ARTHUR := 14     ## + Arthur (so the current shoves him too)

@export var max_breaches := 12        ## raiders allowed across before the ford falls
@export var bridge_max_hp := 200.0
@export var ally_count := 6
@export var wave_interval := 18.0     ## max seconds before the next wave is forced in
@export var wave_clear_threshold := 5 ## launch the next wave once the field thins to this
@export var log_interval := 7.0
@export var max_logs := 4

const LIGHT := preload("res://scenes/LightSoldier.tscn")
const SHIELD := preload("res://scenes/ShieldSoldier.tscn")
const SPEAR := preload("res://scenes/Spearman.tscn")
const CAVALRY := preload("res://scenes/Cavalry.tscn")
const CART := preload("res://scenes/WarCart.tscn")
const BANNER := preload("res://scenes/BannerBearer.tscn")
const ALLY := preload("res://scenes/Ally.tscn")
const LOG := preload("res://scenes/Log.tscn")

@onready var arthur = $Arthur
@onready var hud = $Hud
@onready var walls: StaticBody2D = $Walls

var _won := false
var _lost := false
var _scan_cd := 0.0
var _mud_bodies: Array = []   ## cached enemy+prop+ally list, refreshed periodically
var _waves: Array = []
var _wave := 0                ## waves spawned so far
var _wave_cd := 5.0           ## countdown to the next wave
var _breaches := 0
var _breached := {}           ## ids already counted as having crossed the line
var _bridge_hp := 0.0
var _bridge_down := false
var _bridge_zone: TerrainZone = null   ## deep water over the gap, enabled when the bridge falls
var _crossing: Node2D = null
var _log_cd := 6.0
var _objectives: ObjectiveManager = null   ## this level's win/lose, composed from modules

func _ready() -> void:
	Impact.reset()
	_bridge_hp = bridge_max_hp
	_build_fences()
	_build_goal()
	_build_terrain()
	_waves = [
		{"name": "LIGHT RAIDERS", "col": Color(1.0, 0.82, 0.4), "spawns": [LIGHT, LIGHT, LIGHT, LIGHT, LIGHT, LIGHT]},
		{"name": "SHIELD SOLDIERS", "col": Color(0.72, 0.78, 0.9), "spawns": [SHIELD, SHIELD, SHIELD, SHIELD, SHIELD]},
		{"name": "SPEARS BEHIND SHIELDS", "col": Color(0.8, 0.88, 0.7), "spawns": [SHIELD, SHIELD, SPEAR, SPEAR, SPEAR]},
		{"name": "CAVALRY CHARGE", "col": Color(1.0, 0.55, 0.3), "spawns": [CAVALRY, CAVALRY, CART]},
		{"name": "THE OFFICER", "col": Color(1.0, 0.5, 0.3), "spawns": [BANNER, SHIELD, SHIELD, SPEAR, LIGHT, LIGHT]},
	]
	# Wake the pre-placed garrison (the type scenes ship AI-off so the sandbox stays calm).
	for e in get_tree().get_nodes_in_group("targets"):
		e.ai_enabled = true
	for s in $ShieldWall.get_children():
		s.add_to_group("shieldwall")
	_spawn_allies()
	# Compose this level's win/lose from reusable objectives instead of hand-coding it:
	# repel every wave AND defeat the officer to win; lose if the line is breached.
	_objectives = ObjectiveManager.new()
	_objectives.add(RepelWavesObjective.new()) \
		.add(DefeatOfficerObjective.new()) \
		.add(HoldLineObjective.new())
	arthur.died.connect(_on_arthur_died)
	hud.bind(arthur)
	Impact.popup("THE FORD OF THE STONE KING", arthur.global_position + Vector2(0, -120),
		Color(0.85, 0.8, 0.6), 1.4)
	_evaluate_objectives()
	queue_redraw()

func _build_fences() -> void:
	for r in FENCES:
		var cs := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = r.size
		cs.shape = shape
		cs.position = r.position + r.size * 0.5
		walls.add_child(cs)

## The allied banner at Arthur's bank — the point the raiders march at — plus the bridge
## "crossing" marker that NPCs aim for when they refuse to wade the river.
func _build_goal() -> void:
	var goal := Node2D.new()
	goal.global_position = GOAL_POS
	goal.add_to_group("ford_goal")
	add_child(goal)
	_crossing = Node2D.new()
	_crossing.global_position = CROSS_POS
	_crossing.add_to_group("crossing")
	add_child(_crossing)

## Lay down the terrain RULES as reusable TerrainZones over the drawn rects. Place another
## river/mud anywhere and it behaves identically — this is the modular terrain.
func _build_terrain() -> void:
	for r in RIVER:
		_add_zone(r, WATER_DRAG, CURRENT, true, true, MASK_WITH_ARTHUR)   # deep ford: avoid + drown
	for r in MUD:
		_add_zone(r, MUD_DRAG, Vector2.ZERO, false, false, MASK_UNITS_PROPS)
	# The bridge gap is dry until collapse, then it becomes deep water (kept disabled now).
	_bridge_zone = _add_zone(BRIDGE_GAP, WATER_DRAG, CURRENT, true, true, MASK_WITH_ARTHUR)
	_bridge_zone.monitoring = false
	_bridge_zone.remove_from_group("danger_terrain")

func _add_zone(r: Rect2, drag: float, current: Vector2, dangerous: bool, drown: bool, mask: int) -> TerrainZone:
	var z := TerrainZone.new()
	z.drag = drag
	z.current = current
	z.dangerous = dangerous
	z.drowns_light = drown
	z.drown_mass_max = 0.7   # only the lightest raiders (≈0.55) sink; allies/shields wade out
	z.collision_layer = 0
	z.collision_mask = mask
	z.setup_rect(r)
	add_child(z)
	return z

func _spawn_allies() -> void:
	Spawner.spawn_count(self, ALLY, ally_count, 430.0, -260.0, 260.0)

func _physics_process(delta: float) -> void:
	if not (_won or _lost):
		_wave_cd -= delta
		_log_cd -= delta
	# Run the slow systems a few times a second — they change only on a spawn/defeat.
	_scan_cd -= delta
	if _scan_cd <= 0.0:
		_scan_cd = 0.15
		_mud_bodies = get_tree().get_nodes_in_group("targets") \
			+ get_tree().get_nodes_in_group("props") \
			+ get_tree().get_nodes_in_group("allies")
		_update_waves()
		_check_breaches()
		_evaluate_objectives()
		_maybe_spawn_log()
	# Terrain forces now live in the TerrainZones. The only per-body work left here is the
	# level-specific bridge pounding (a fast prop over the deck chips it).
	for b in _mud_bodies:
		if is_instance_valid(b) and b is RigidBody2D:
			_bridge_pound(b)

# ── waves ───────────────────────────────────────────────────────────────────

func _update_waves() -> void:
	if _won or _lost or _wave >= _waves.size():
		return
	var alive := get_tree().get_nodes_in_group("targets").size()
	# Launch the next wave once the field thins out, or patience runs out.
	if alive <= wave_clear_threshold or _wave_cd <= 0.0:
		_spawn_wave(_wave)
		_wave += 1
		_wave_cd = wave_interval

func _spawn_wave(idx: int) -> void:
	var wave: Dictionary = _waves[idx]
	Impact.popup("WAVE %d / %d — %s" % [idx + 1, _waves.size(), wave["name"]],
		arthur.global_position + Vector2(0, -150), wave["col"], 1.5)
	Audio.play("cavalry_charge", arthur.global_position)   # a war-horn for the incoming wave
	Spawner.spawn(self, wave["spawns"], -HALF.y + 70.0, -380.0, 380.0, true)

# ── "Hold the Ford": breaches + win/lose ────────────────────────────────────

## Count raiders that walk past the defence line (under their own power, not launched).
## Each counts once, then is removed (it "broke through"); enough breaches lose the ford.
func _check_breaches() -> void:
	if _won or _lost:
		return
	for e in get_tree().get_nodes_in_group("targets"):
		if not is_instance_valid(e) or e._dead:
			continue
		if e.global_position.y <= DEFENCE_Y:
			continue
		if _breached.has(e.get_instance_id()):
			continue
		# A launched/stunned body flying past doesn't count — only a raider that marched.
		if e._stun > 0.0 or e.linear_velocity.length() > e.control_regain:
			continue
		_breached[e.get_instance_id()] = true
		_breaches += 1
		Impact.popup("BREACH!", e.global_position + Vector2(0, -30), Color(1.0, 0.4, 0.35), 1.2)
		Audio.play("banner_down", e.global_position)
		e.queue_free()
		# The lose decision belongs to the HoldLine objective, not this counter.

## Tick the composed objectives with the level's live state; they decide win/lose + HUD.
func _evaluate_objectives() -> void:
	if _won or _lost:
		return
	var ctx := {
		"breaches": _breaches, "max_breaches": max_breaches,
		"wave": _wave, "wave_count": _waves.size(),
		"alive": get_tree().get_nodes_in_group("targets").size(),
		"officers": get_tree().get_nodes_in_group("officers").size(),
	}
	_objectives.evaluate(ctx)
	hud.set_objective("HOLD THE FORD   " + _objectives.hud_line(ctx))
	if _objectives.lost:
		_defeat_ford()
	elif _objectives.won:
		_victory()

func _victory() -> void:
	if _won or _lost:
		return
	_won = true
	hud.show_banner("THE FORD HOLDS!", Color(0.5, 0.95, 0.55))
	Impact.popup("VICTORY — THE FORD IS YOURS", arthur.global_position + Vector2(0, -64),
		Color(1.0, 0.85, 0.3), 1.6)

func _defeat_ford() -> void:
	if _won or _lost:
		return
	_lost = true
	hud.show_banner("THE FORD IS LOST", Color(0.95, 0.45, 0.4))

# ── bridge (a level-specific destructible) ──────────────────────────────────

## A fast prop pounding the bridge deck chips its supports; enough damage collapses it,
## turning the dry crossing into deep water — denying the raiders their clean route.
func _bridge_pound(b: RigidBody2D) -> void:
	if _bridge_down or not b.is_in_group("props"):
		return
	if not BRIDGE.has_point(b.global_position):
		return
	var speed := b.linear_velocity.length()
	if speed < 230.0:
		return
	_bridge_hp -= speed * 0.05
	if _bridge_hp <= 0.0:
		_collapse_bridge()

func _collapse_bridge() -> void:
	_bridge_down = true
	if _bridge_zone:
		_bridge_zone.monitoring = true
		_bridge_zone.add_to_group("danger_terrain")
	if _crossing:
		_crossing.remove_from_group("crossing")   # no dry crossing left — they must wade
	Impact.popup("BRIDGE COLLAPSED", BRIDGE.get_center() + Vector2(0, -40), Color(1.0, 0.6, 0.3), 1.5)
	Audio.play("wall_crush", BRIDGE.get_center())
	Impact.impact_fx.emit(20.0)

func _maybe_spawn_log() -> void:
	if _won or _lost or _log_cd > 0.0:
		return
	_log_cd = log_interval
	if get_tree().get_nodes_in_group("logs").size() >= max_logs:
		return
	var log = LOG.instantiate()
	add_child(log)
	log.add_to_group("logs")
	log.global_position = Vector2(-880.0, randf_range(228.0, 308.0))   # upstream edge
	log.linear_velocity = Vector2(120.0, 0.0)

func _on_arthur_died() -> void:
	if _won:
		return
	_lost = true
	hud.show_banner("ARTHUR HAS FALLEN", Color(0.95, 0.4, 0.4))

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("reset_arena"):
		get_tree().reload_current_scene()

# ── drawing (the terrain VISUALS; the rules are the TerrainZones above) ──────

func _draw() -> void:
	var rect := Rect2(-HALF, HALF * 2.0)
	draw_rect(rect, Color(0.17, 0.16, 0.14))            # riverbank ground
	for x in range(-int(HALF.x), int(HALF.x) + 1, GRID_STEP):
		draw_line(Vector2(x, -HALF.y), Vector2(x, HALF.y), Color(1, 1, 1, 0.03), 1.0)
	for y in range(-int(HALF.y), int(HALF.y) + 1, GRID_STEP):
		draw_line(Vector2(-HALF.x, y), Vector2(HALF.x, y), Color(1, 1, 1, 0.03), 1.0)
	for r in RIVER:
		_draw_water(r)
	if _bridge_down:
		_draw_water(BRIDGE_GAP)
		for k in range(5):
			var bx := BRIDGE.position.x + 14.0 + k * 26.0
			draw_line(Vector2(bx, 250), Vector2(bx + 12, 285), Color(0.32, 0.22, 0.13), 4.0)
	else:
		var dmg := clampf(1.0 - _bridge_hp / bridge_max_hp, 0.0, 1.0)
		draw_rect(BRIDGE, Color(0.42, 0.31, 0.19).lerp(Color(0.3, 0.18, 0.12), dmg))
		for px in range(int(BRIDGE.position.x), int(BRIDGE.position.x + BRIDGE.size.x), 18):
			draw_line(Vector2(px, BRIDGE.position.y), Vector2(px, BRIDGE.position.y + BRIDGE.size.y),
				Color(0.3, 0.22, 0.13), 2.0)
		draw_rect(BRIDGE, Color(0.55, 0.42, 0.27), false, 3.0)
	for r in MUD:
		draw_rect(r, Color(0.26, 0.2, 0.12, 0.65))
		draw_rect(r, Color(0.32, 0.25, 0.15), false, 2.0)
	for r in FENCES:
		draw_rect(r, Color(0.34, 0.26, 0.18))
		draw_rect(r, Color(0.5, 0.4, 0.28), false, 3.0)
	# the defence line + the allied banner Arthur is protecting
	draw_line(Vector2(-HALF.x, DEFENCE_Y), Vector2(HALF.x, DEFENCE_Y), Color(0.4, 0.6, 0.95, 0.4), 2.0)
	draw_line(GOAL_POS + Vector2(0, 20), GOAL_POS + Vector2(0, -34), Color(0.55, 0.45, 0.3), 4.0)
	draw_rect(Rect2(GOAL_POS.x, GOAL_POS.y - 34.0, 30.0, 20.0), Color(0.3, 0.55, 0.95))
	draw_rect(rect, Color(0.4, 0.36, 0.3), false, 6.0)  # boundary

func _draw_water(r: Rect2) -> void:
	draw_rect(r, Color(0.16, 0.34, 0.44, 0.78))
	var midy: float = r.position.y + r.size.y * 0.5
	draw_line(Vector2(r.position.x, midy), Vector2(r.position.x + r.size.x, midy),
		Color(0.45, 0.7, 0.8, 0.35), 2.0)
	draw_rect(r, Color(0.3, 0.55, 0.65, 0.5), false, 2.0)
