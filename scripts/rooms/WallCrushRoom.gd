extends Node2D
## Wall-Crush Training — a tight challenge room that teaches the wall-crush bonus.
##
## This is a LEVEL: it assembles the same reusable modules every other level uses and
## runs only its own thin rules. The reusable parts stay reusable — every wall is a
## StaticBody2D on layer 1 ("world", what `Impact.cushion` raycasts for); every enemy is a
## config of `Enemy`; all force/scoring is `Impact`; the win/lose is composed from the
## `Objective`/`ObjectiveManager` modules. What lives HERE is level-specific: the cramped
## layout, the enemies pre-placed with their backs to a wall, and the "clear them all" win.
##
## The room is built so the intended solution is to PIN a raider against a wall: each
## raider stands in a shallow alcove, so a strike that drives it into the wall behind it
## lands with `Impact`'s no-cushion crush bonus instead of just knocking it across open
## floor. The status Label tallies how many were finished with a wall-crush — pure flavour,
## the win only needs the room cleared.

const HALF := Vector2(560.0, 360.0)   ## half-extent of the cramped arena (fits 1280×720)
const GRID_STEP := 80
const WALL_T := 40.0                  ## thickness of the boundary + interior walls

const LIGHT := preload("res://scenes/LightSoldier.tscn")
const SHIELD := preload("res://scenes/ShieldSoldier.tscn")
const HEAVY := preload("res://scenes/HeavyGuard.tscn")

## Interior obstacles, world-space Rect2 (top-left + size). They both COLLIDE (layer 1) and
## are DRAWN from the same rects, so the wall you crush against is exactly the one you see.
## Two stubby pillars + two centre nubs carve the room into alcoves to pin raiders into.
const WALLS := [
	Rect2(-360.0, -60.0, WALL_T, 200.0),   # left pillar
	Rect2(320.0, -140.0, WALL_T, 200.0),   # right pillar
	Rect2(-90.0, -360.0, 180.0, WALL_T),   # top centre nub (alcove behind it)
	Rect2(-90.0, 320.0, 180.0, WALL_T),    # bottom centre nub
]

## Each raider is placed with a wall ≈30–48px behind it (within Impact's 50px CRUSH_RANGE),
## relative to Arthur at the centre — so a strike that drives it outward pins it. Each spot
## is clear of every wall at spawn (centre-to-wall > radius, no penetration/jitter). `pos` is
## the placement; `into` documents the strike direction that pins it (informational only).
const SPOTS := [
	{"scene": LIGHT, "pos": Vector2(-512.0, 40.0), "into": Vector2(-1.0, 0.0)},   # left boundary wall
	{"scene": SHIELD, "pos": Vector2(-292.0, 30.0), "into": Vector2(-1.0, 0.0)},  # left pillar (right face)
	{"scene": LIGHT, "pos": Vector2(512.0, -40.0), "into": Vector2(1.0, 0.0)},    # right boundary wall
	{"scene": HEAVY, "pos": Vector2(290.0, -30.0), "into": Vector2(1.0, 0.0)},    # right pillar (left face)
	{"scene": LIGHT, "pos": Vector2(0.0, -272.0), "into": Vector2(0.0, -1.0)},    # top nub
	{"scene": SHIELD, "pos": Vector2(0.0, 272.0), "into": Vector2(0.0, 1.0)},     # bottom nub
]

@onready var arthur = $Arthur
@onready var hud = $Hud
@onready var walls: StaticBody2D = $Walls

var _status: Label = null
var _objectives: ObjectiveManager = null
var _enemies: Array = []          ## the raiders placed at spawn (for the live count)
var _total := 0
var _crush_kos := 0               ## raiders finished while pinned to a wall
var _won := false
var _scan_cd := 0.0

func _ready() -> void:
	Impact.reset()
	_build_walls()
	_spawn_enemies()
	_build_status_label()
	# Compose the win from the reusable objective modules instead of hand-coding it: the room
	# is won the instant the field is cleared.
	_objectives = ObjectiveManager.new()
	_objectives.add(ClearRoomObjective.new())
	hud.bind(arthur)
	Impact.popup("WALL-CRUSH TRAINING", arthur.global_position + Vector2(0, -110),
		Color(1.0, 0.55, 0.25), 1.4)
	Impact.popup("PIN THEM TO THE WALL", arthur.global_position + Vector2(0, -78),
		Color(0.9, 0.8, 0.6), 1.0)
	_update_status()
	queue_redraw()

## Boundary walls (4 sides) + the interior obstacles, all StaticBody2D shapes on layer 1.
func _build_walls() -> void:
	var bx := HALF.x + WALL_T
	_add_wall(Rect2(-bx, -HALF.y - WALL_T, bx * 2.0, WALL_T))          # top
	_add_wall(Rect2(-bx, HALF.y, bx * 2.0, WALL_T))                    # bottom
	_add_wall(Rect2(-HALF.x - WALL_T, -HALF.y, WALL_T, HALF.y * 2.0))  # left
	_add_wall(Rect2(HALF.x, -HALF.y, WALL_T, HALF.y * 2.0))            # right
	for r in WALLS:
		_add_wall(r)

func _add_wall(r: Rect2) -> void:
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = r.size
	cs.shape = shape
	cs.position = r.position + r.size * 0.5   # Rect2 is top-left; the shape is centred
	walls.add_child(cs)

## Place each raider in its alcove with AI on (they advance on Arthur), so the player must
## strike them back into the wall they came from.
func _spawn_enemies() -> void:
	for spot in SPOTS:
		var scene: PackedScene = spot["scene"]
		var e = scene.instantiate()
		add_child(e)
		e.global_position = spot["pos"]
		e.ai_enabled = true
		_enemies.append(e)
	_total = _enemies.size()

## Our OWN status Label (we never touch Hud.gd). A thin CanvasLayer keeps it on-screen.
func _build_status_label() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_status = Label.new()
	_status.position = Vector2(24.0, 120.0)
	_status.add_theme_font_size_override("font_size", 20)
	_status.add_theme_color_override("font_color", Color(1.0, 0.85, 0.55))
	layer.add_child(_status)

func _physics_process(delta: float) -> void:
	_scan_cd -= delta
	if _scan_cd > 0.0:
		return
	_scan_cd = 0.15
	_tally_crush_kos()
	_update_status()
	_evaluate()

## Live count of raiders still standing (a defeated Enemy sets `_dead` immediately, then
## lingers to fade — count only the live ones).
func _alive() -> int:
	var n := 0
	for e in _enemies:
		if is_instance_valid(e) and not e._dead:
			n += 1
	return n

## Tally each newly-defeated raider as a wall-crush KO if a wall sat right behind it along
## the way it was last shoved — read straight from the shared `Impact.cushion` raycast, so
## the test's notion of a crush and the room's are the SAME function (no new physics here).
func _tally_crush_kos() -> void:
	for e in _enemies:
		if not is_instance_valid(e) or not e._dead:
			continue
		if e.has_meta("wc_counted"):
			continue
		e.set_meta("wc_counted", true)
		var dir: Vector2 = e.linear_velocity if e is RigidBody2D else Vector2.ZERO
		if dir.length() < 1.0:
			dir = Vector2.RIGHT
		if Impact.cushion(self, e.global_position, dir) > 0.0:
			_crush_kos += 1

func _evaluate() -> void:
	if _won:
		return
	_objectives.evaluate({"alive": _alive(), "total": _total})
	if _objectives.won:
		_victory()

func _victory() -> void:
	if _won:
		return
	_won = true
	_update_status()
	hud.show_banner("ROOM CLEARED!", Color(0.5, 0.95, 0.55))
	Impact.popup("ROOM CLEARED — %d / %d BY WALL CRUSH" % [_crush_kos, _total],
		arthur.global_position + Vector2(0, -64), Color(1.0, 0.85, 0.3), 1.5)

func _update_status() -> void:
	if _status == null:
		return
	var alive := _alive()
	var down := _total - alive
	var line := "WALL-CRUSH TRAINING\nRAIDERS DOWN  %d / %d\nWALL CRUSHES  %d" % [down, _total, _crush_kos]
	if _won:
		line += "\nROOM CLEARED!"
	_status.text = line

## True once the room has recognised the win — read by the headless test.
func is_cleared() -> bool:
	return _won

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("reset_arena"):
		get_tree().reload_current_scene()

# ── drawing (the wall VISUALS; the bodies are the same Rect2s above) ──────────

func _draw() -> void:
	var rect := Rect2(-HALF, HALF * 2.0)
	draw_rect(rect, Color(0.15, 0.14, 0.17))             # floor
	for x in range(-int(HALF.x), int(HALF.x) + 1, GRID_STEP):
		draw_line(Vector2(x, -HALF.y), Vector2(x, HALF.y), Color(1, 1, 1, 0.04), 1.0)
	for y in range(-int(HALF.y), int(HALF.y) + 1, GRID_STEP):
		draw_line(Vector2(-HALF.x, y), Vector2(HALF.x, y), Color(1, 1, 1, 0.04), 1.0)
	# the bounding walls (drawn as a frame just outside the floor)
	var ot := WALL_T
	draw_rect(Rect2(-HALF.x - ot, -HALF.y - ot, HALF.x * 2.0 + ot * 2.0, ot), Color(0.32, 0.26, 0.3))
	draw_rect(Rect2(-HALF.x - ot, HALF.y, HALF.x * 2.0 + ot * 2.0, ot), Color(0.32, 0.26, 0.3))
	draw_rect(Rect2(-HALF.x - ot, -HALF.y, ot, HALF.y * 2.0), Color(0.32, 0.26, 0.3))
	draw_rect(Rect2(HALF.x, -HALF.y, ot, HALF.y * 2.0), Color(0.32, 0.26, 0.3))
	for r in WALLS:
		draw_rect(r, Color(0.30, 0.27, 0.33))
		draw_rect(r, Color(0.55, 0.45, 0.5), false, 3.0)   # lip — the crush face
	draw_rect(rect, Color(0.5, 0.42, 0.46), false, 5.0)   # inner boundary line


## A thin level-local objective: the room is won the instant the field is cleared. Kept here
## (an inner class) because it is this room's only rule — every reusable bit lives in the
## modules it composes (`Objective`, `ObjectiveManager`).
class ClearRoomObjective extends Objective:
	func _init() -> void:
		title = "Clear the room"
		required = true

	func evaluate(ctx: Dictionary) -> void:
		# Done only once raiders existed AND the field is now empty, so the objective never
		# fires before the room is populated.
		if int(ctx.get("total", 0)) > 0 and int(ctx.get("alive", 999)) <= 0:
			_done = true

	func fragment(ctx: Dictionary) -> String:
		return "CLEARED" if _done else "RAIDERS %d" % int(ctx.get("alive", 0))
