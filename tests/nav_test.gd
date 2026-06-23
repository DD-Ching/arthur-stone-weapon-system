extends Node2D
## Headless test for the obstacle-navigation module (scripts/ai/Steering.gd).
##
## Puts a solid wall (world layer) directly between a marching raider and its goal, with
## OPEN ENDS. The old AI marched straight in and jammed against the wall forever; with the
## steering whiskers the unit must bend around an end and reach the far (south) side.
##
## Run: godot --headless --path . res://tests/NavTest.tscn — look for NAV_VERDICT.

var _enemy
var _frame := 0
var _start_y := 0.0
var _done := false

func _ready() -> void:
	# A horizontal wall on the WORLD layer (bit 1) spanning x[-300,-40] at y=0 — like a
	# Battlefield fence with the GAP toward the goal side (x > -40). The raider sits behind the
	# wall; its straight line to the goal is blocked, so it must steer to the gap to get south.
	var wall := StaticBody2D.new()
	wall.collision_layer = 1
	wall.collision_mask = 0
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(260.0, 24.0)
	cs.shape = shape
	wall.add_child(cs)
	add_child(wall)
	wall.global_position = Vector2(-170.0, 0.0)   # spans x[-300, -40]
	# The march goal the raider heads for, SOUTH of the wall and toward the gap side.
	var goal := Node2D.new()
	goal.add_to_group("ford_goal")
	add_child(goal)
	goal.global_position = Vector2(0.0, 140.0)
	# A raider NORTH of (behind) the wall, no foe in sight → it marches to the goal and must
	# route around the wall through the gap instead of jamming against it.
	_enemy = load("res://scenes/LightSoldier.tscn").instantiate()
	add_child(_enemy)
	_enemy.global_position = Vector2(-150.0, -90.0)
	_enemy.ai_enabled = true
	_start_y = _enemy.global_position.y
	print("NAV_READY ok")

func _physics_process(_delta: float) -> void:
	if _done:
		return
	_frame += 1
	# Success the moment it has clearly cleared the wall (south of its south edge at y≈12).
	if is_instance_valid(_enemy) and _enemy.global_position.y > 30.0:
		_report(true)
	elif _frame >= 700:
		_report(false)

func _report(ok: bool) -> void:
	_done = true
	var y: float = _enemy.global_position.y if is_instance_valid(_enemy) else _start_y
	print("NAV_RESULT start_y=%.0f final_y=%.0f frames=%d cleared=%s" % [_start_y, y, _frame, str(ok)])
	print("NAV_VERDICT %s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)
