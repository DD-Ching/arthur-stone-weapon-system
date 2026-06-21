extends Node2D
## The battlefield — the test arena grown into a small ancient-battlefield sandbox.
##
## It turns the enemies' AI on, lays down terrain (mud that drags, fences that
## funnel and trip), runs the "Break the Shield Wall" objective, and handles
## win/lose. Like Arena.gd it keeps itself small: the *systems* live in Enemy,
## StoneWeapon, and Impact — this is the stage they perform on.
##
## Fences + mud are data-driven (Rect2 lists), so the thing you crush enemies
## against and the thing that slows them are exactly what you see drawn.

const HALF := Vector2(900.0, 560.0)
const GRID_STEP := 100
const MUD_DRAG := 0.86   ## velocity kept per frame inside mud (slows cavalry/charges)

## Static fences/obstacles (also drawn). World-space Rect2 (top-left + size).
const FENCES := [
	Rect2(-540, -260, 30, 360),   # left funnel wall
	Rect2(510, -260, 30, 360),    # right funnel wall
	Rect2(-300, -360, 220, 28),   # back-left fence behind the line
	Rect2(80, -360, 220, 28),     # back-right fence
]
## Mud bands — slow anything heavy that tries to cross (great for stalling charges).
const MUD := [
	Rect2(-340, 60, 680, 90),
]

@onready var arthur = $Arthur
@onready var hud = $Hud
@onready var walls: StaticBody2D = $Walls

var _won := false
var _lost := false
var _wall_total := 1

func _ready() -> void:
	Impact.reset()
	_build_fences()
	# Wake the army up — the type scenes ship AI-off so the v0.3 sandbox stays calm.
	for e in get_tree().get_nodes_in_group("targets"):
		e.ai_enabled = true
	for s in $ShieldWall.get_children():
		s.add_to_group("shieldwall")
	_wall_total = maxi(1, get_tree().get_nodes_in_group("shieldwall").size())
	arthur.died.connect(_on_arthur_died)
	hud.bind(arthur)
	hud.set_objective("BREAK THE SHIELD WALL   0 / %d" % _wall_total)
	queue_redraw()

func _build_fences() -> void:
	for r in FENCES:
		var cs := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = r.size
		cs.shape = shape
		cs.position = r.position + r.size * 0.5
		walls.add_child(cs)

func _physics_process(_delta: float) -> void:
	# Mud drag on physics bodies (enemies + props). Cheap point-in-rect test.
	for grp in ["targets", "props"]:
		for b in get_tree().get_nodes_in_group(grp):
			if b is RigidBody2D and _in_mud(b.global_position):
				b.linear_velocity *= MUD_DRAG
	if _won or _lost:
		return
	var remaining := get_tree().get_nodes_in_group("shieldwall").size()
	var broken := _wall_total - remaining
	hud.set_objective("BREAK THE SHIELD WALL   %d / %d" % [broken, _wall_total])
	if remaining == 0:
		_won = true
		hud.show_banner("SHIELD WALL BROKEN!", Color(0.5, 0.95, 0.55))
		Impact.popup("FORMATION BROKEN", arthur.global_position + Vector2(0, -64), Color(1.0, 0.85, 0.3), 1.5)

func _in_mud(p: Vector2) -> bool:
	for r in MUD:
		if r.has_point(p):
			return true
	return false

func _on_arthur_died() -> void:
	if _won:
		return
	_lost = true
	hud.show_banner("ARTHUR HAS FALLEN", Color(0.95, 0.4, 0.4))

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("reset_arena"):
		get_tree().reload_current_scene()

func _draw() -> void:
	var rect := Rect2(-HALF, HALF * 2.0)
	draw_rect(rect, Color(0.17, 0.16, 0.14))            # muddy ground
	for x in range(-int(HALF.x), int(HALF.x) + 1, GRID_STEP):
		draw_line(Vector2(x, -HALF.y), Vector2(x, HALF.y), Color(1, 1, 1, 0.03), 1.0)
	for y in range(-int(HALF.y), int(HALF.y) + 1, GRID_STEP):
		draw_line(Vector2(-HALF.x, y), Vector2(HALF.x, y), Color(1, 1, 1, 0.03), 1.0)
	# mud bands
	for r in MUD:
		draw_rect(r, Color(0.26, 0.2, 0.12, 0.65))
		draw_rect(r, Color(0.32, 0.25, 0.15), false, 2.0)
	# fences (same Rect2s that became collision)
	for r in FENCES:
		draw_rect(r, Color(0.34, 0.26, 0.18))
		draw_rect(r, Color(0.5, 0.4, 0.28), false, 3.0)
	draw_rect(rect, Color(0.4, 0.36, 0.3), false, 6.0)  # boundary
