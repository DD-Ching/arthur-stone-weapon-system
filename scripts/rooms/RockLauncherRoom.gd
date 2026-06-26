extends Node2D
## Rock Launcher Room — a self-contained challenge level whose intended solution is to
## LAUNCH props (rocks / crates) at the enemies rather than wade in with the stone.
##
## This is a LEVEL: it assembles reusable modules and runs the level's own rule. The
## reusable parts live elsewhere — the prop→enemy hit is `Impact.collide` (fired by
## `Rock.gd` on contact), the gap is a `TerrainZone` (deep water), every enemy is a
## config of `Enemy`, and the win/lose is composed from `Objective`/`ObjectiveManager`.
## What stays here is level-specific: the layout (Arthur + a supply pile on one side, a
## raider line on a far ledge across a chasm) and the single "clear them all" objective.
##
## Why launching is the intended answer: a deep-water chasm splits the room. Wading into
## it drowns Arthur (he loses health fast and is shoved back to his bank), so he can't just
## cross and melee. The chasm's collision mask ignores props, so a thrown rock sails clean
## across the water. The raiders garrison the far ledge — their march goal (a `ford_goal`)
## sits on the ledge and the chasm is `danger_terrain` they route around — so they hold out
## of melee reach, leaving Arthur to bowl the supply rocks/crates into them.

const HALF := Vector2(620.0, 360.0)
const GRID_STEP := 100

## The chasm splitting the room: deep water Arthur can't safely cross (it drowns him),
## but a launched prop flies right over. World-space Rect2 (top-left + size).
const CHASM := Rect2(-150.0, -360.0, 300.0, 720.0)
## Health Arthur loses per drowning hit. take_damage's i-frames (~0.6s) pace these, so a
## full wade across (~2.5s) lands several — enough to threaten his 140 HP and shove him home.
const DROWN_HIT := 42.0
const ARTHUR_X := -360.0        ## Arthur's home bank x
const LEDGE_X := 360.0          ## the far ledge the raiders hold

const ROCK := preload("res://scenes/Rock.tscn")
const CRATE := preload("res://scenes/Crate.tscn")
const LIGHT := preload("res://scenes/LightSoldier.tscn")
const SHIELD := preload("res://scenes/ShieldSoldier.tscn")
const HEAVY := preload("res://scenes/HeavyGuard.tscn")

## How many of each prop to stock the supply pile with — exported so the challenge is
## tuned by config, not by editing logic. The raider roster is built in _ready if unset.
@export var rock_supply := 6
@export var crate_supply := 3
@export var enemy_roster: Array[PackedScene] = []

@onready var arthur = $Arthur
@onready var walls: StaticBody2D = $Walls

var _objectives: ObjectiveManager = null
var _status: Label = null
var _enemy_total := 0
var _won := false
var _lost := false
var _scan_cd := 0.0
var _started := false   ## true once enemies have actually spawned (so an empty first frame
                        ## isn't mistaken for "all defeated")

func _ready() -> void:
	Impact.reset()
	_build_bounds()
	_build_chasm()
	_build_goal()
	_build_status_label()
	if enemy_roster.is_empty():
		enemy_roster = [LIGHT, LIGHT, SHIELD, LIGHT, HEAVY, SHIELD]
	_spawn_supply()
	_spawn_enemies()
	# The win/lose is one reusable objective: clear every raider on the ledge.
	_objectives = ObjectiveManager.new()
	_objectives.add(ClearRoomObjective.new())
	arthur.died.connect(_on_arthur_died)
	Impact.popup("LAUNCH THE ROCKS!", arthur.global_position + Vector2(0, -90),
		Color(0.85, 0.78, 0.55), 1.4)
	_evaluate()
	queue_redraw()

## The four outer walls (world layer) keep everyone inside the room.
func _build_bounds() -> void:
	var t := 30.0
	_add_wall(Rect2(-HALF.x - t, -HALF.y - t, HALF.x * 2.0 + t * 2.0, t))            # top
	_add_wall(Rect2(-HALF.x - t, HALF.y, HALF.x * 2.0 + t * 2.0, t))                 # bottom
	_add_wall(Rect2(-HALF.x - t, -HALF.y - t, t, HALF.y * 2.0 + t * 2.0))            # left
	_add_wall(Rect2(HALF.x, -HALF.y - t, t, HALF.y * 2.0 + t * 2.0))                 # right

func _add_wall(r: Rect2) -> void:
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = r.size
	cs.shape = shape
	cs.position = r.position + r.size * 0.5
	walls.add_child(cs)

## The deep-water chasm: a reusable TerrainZone placed purely as `danger_terrain` so the
## raiders' avoid-danger steering routes around it (toward the ledge crossing) instead of
## wading across. Its mask is 0 — it applies no physics force; Arthur's drowning is the
## level's own rule (`_punish_wade`, via Arthur's existing take_damage), because Arthur is a
## CharacterBody2D that TerrainZone's drown path (RigidBody2D-only) can't touch.
func _build_chasm() -> void:
	var z := TerrainZone.new()
	z.dangerous = true          # → group "danger_terrain"; enemies route around it
	z.drowns_light = false      # units never enter (mask 0); Arthur is drowned by the room
	z.splash = false
	z.collision_layer = 0
	z.collision_mask = 0
	z.setup_rect(CHASM)
	add_child(z)

## The raiders' march goal + a crossing marker, both on the far ledge. The goal makes the
## garrison HOLD the ledge (they only break off to fight a foe inside sight range), and the
## crossing gives their avoid-danger steering somewhere to aim instead of wading the chasm.
func _build_goal() -> void:
	var goal := Node2D.new()
	goal.global_position = Vector2(LEDGE_X, 0.0)
	goal.add_to_group("ford_goal")
	add_child(goal)
	var crossing := Node2D.new()
	crossing.global_position = Vector2(LEDGE_X, 0.0)
	crossing.add_to_group("crossing")
	add_child(crossing)

## A small fixed Label that shows the level status — this level's OWN HUD, so we never
## touch the shared Hud. (A CanvasLayer keeps it fixed on screen, not in world space.)
func _build_status_label() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_status = Label.new()
	_status.position = Vector2(20.0, 20.0)
	_status.add_theme_font_size_override("font_size", 22)
	_status.add_theme_color_override("font_color", Color(0.9, 0.85, 0.65))
	layer.add_child(_status)
	# Mobile: this room builds its own status layer (not the shared Hud), so add the touch
	# controls here too — otherwise the trial has no joysticks on a phone.
	layer.add_child(preload("res://scenes/ui/TouchControls.tscn").instantiate())

## Stock the supply pile beside Arthur: rocks + crates to launch. They sit on Arthur's side
## of the chasm so the obvious move is to swing/slam them across into the raider line.
func _spawn_supply() -> void:
	for i in rock_supply:
		var rock := ROCK.instantiate()
		add_child(rock)
		rock.global_position = Vector2(ARTHUR_X + 70.0 + (i % 3) * 34.0, -60.0 + (i / 3) * 40.0)
	for i in crate_supply:
		var crate := CRATE.instantiate()
		add_child(crate)
		crate.global_position = Vector2(ARTHUR_X + 60.0 + (i % 3) * 40.0, 120.0 + (i / 3) * 42.0)

## Line the raiders up on the far ledge, across the chasm. AI is on so they react, but their
## march goal (the ledge ford_goal) and the danger-terrain chasm keep them garrisoned there
## — out of melee reach until Arthur's launched props reach them.
func _spawn_enemies() -> void:
	var n := enemy_roster.size()
	for i in n:
		var e: Enemy = enemy_roster[i].instantiate()
		add_child(e)
		e.ai_enabled = true
		var y: float
		if n <= 1:
			y = 0.0
		else:
			y = lerpf(-220.0, 220.0, float(i) / float(n - 1))
		e.global_position = Vector2(LEDGE_X, y)
	_enemy_total = n
	_started = true

func _physics_process(delta: float) -> void:
	_punish_wade()
	_scan_cd -= delta
	if _scan_cd <= 0.0:
		_scan_cd = 0.15
		_evaluate()

## Deep water is lethal: while Arthur stands in the chasm he takes drowning hits and is
## shoved back toward his bank, so wading across to melee is a death sentence. This is the
## level's own rule (TerrainZone can't drown a CharacterBody2D), reusing Arthur's existing
## take_damage + its built-in lunge-off-the-hit and i-frames (which pace the hits). Passing
## a from_pos on the chasm's far side makes each hit lunge him back home.
func _punish_wade() -> void:
	if _won or _lost or not is_instance_valid(arthur):
		return
	if not CHASM.has_point(arthur.global_position):
		return
	if arthur.has_method("take_damage"):
		var from_pos := Vector2(CHASM.position.x + CHASM.size.x * 0.5, arthur.global_position.y)
		arthur.take_damage(DROWN_HIT, from_pos)

## Tick the objective with the live raider count; it decides win, and update the label.
func _evaluate() -> void:
	if _won or _lost:
		return
	var alive := _alive_enemies()
	var ctx := {"alive": alive, "total": _enemy_total, "started": _started}
	_objectives.evaluate(ctx)
	if _status:
		_status.text = "ROCK LAUNCHER ROOM   " + _objectives.hud_line(ctx)
	if _objectives.won:
		_victory()

## Live raiders still on the field (a defeated enemy leaves "targets" the instant it dies,
## before its fade-out, because Enemy._defeat drops the groups immediately).
func _alive_enemies() -> int:
	var c := 0
	for e in get_tree().get_nodes_in_group("targets"):
		if is_instance_valid(e) and not e._dead:
			c += 1
	return c

func _victory() -> void:
	if _won or _lost:
		return
	_won = true
	if _status:
		_status.text = "ROOM CLEARED!   (press R to restart)"
		_status.add_theme_color_override("font_color", Color(0.5, 0.95, 0.55))
	Impact.popup("ROOM CLEARED!", arthur.global_position + Vector2(0, -64),
		Color(0.5, 0.95, 0.55), 1.6)

func _on_arthur_died() -> void:
	if _won:
		return
	_lost = true
	if _status:
		_status.text = "ARTHUR HAS FALLEN   (press R to restart)"
		_status.add_theme_color_override("font_color", Color(0.95, 0.4, 0.4))

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("reset_arena"):
		get_tree().reload_current_scene()

# ── drawing: the floor, the chasm, and the far ledge ─────────────────────────

func _draw() -> void:
	var rect := Rect2(-HALF, HALF * 2.0)
	draw_rect(rect, Color(0.18, 0.17, 0.15))               # stone floor
	for x in range(-int(HALF.x), int(HALF.x) + 1, GRID_STEP):
		draw_line(Vector2(x, -HALF.y), Vector2(x, HALF.y), Color(1, 1, 1, 0.03), 1.0)
	for y in range(-int(HALF.y), int(HALF.y) + 1, GRID_STEP):
		draw_line(Vector2(-HALF.x, y), Vector2(HALF.x, y), Color(1, 1, 1, 0.03), 1.0)
	# the far ledge the raiders hold (drawn before the chasm so the water reads on top)
	var ledge_x: float = CHASM.position.x + CHASM.size.x
	draw_rect(Rect2(ledge_x, -HALF.y, HALF.x - ledge_x, HALF.y * 2.0), Color(0.22, 0.18, 0.14, 0.5))
	# the chasm (deep water)
	draw_rect(CHASM, Color(0.12, 0.28, 0.4, 0.85))
	draw_rect(CHASM, Color(0.3, 0.55, 0.68, 0.55), false, 3.0)
	var midx: float = CHASM.position.x + CHASM.size.x * 0.5
	draw_line(Vector2(midx, CHASM.position.y), Vector2(midx, CHASM.position.y + CHASM.size.y),
		Color(0.4, 0.68, 0.8, 0.3), 2.0)
	draw_rect(rect, Color(0.4, 0.36, 0.3), false, 6.0)     # boundary
