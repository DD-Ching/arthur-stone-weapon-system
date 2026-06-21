extends Node2D
## Headless test for the Ford battlefield systems (v0.7):
##   - the river CURRENT drifts a loose body downstream (+x),
##   - the WATER WHEEL bats a body placed in it far away (a real launch),
##   - the named AUDIO events fire (the wheel's creak + a splash/launch).
##
## It loads the real Battlefield, freezes its army (AI off, no reinforcements) so only
## the terrain + wheel move things, and drops two test rocks.
##
## Run: godot --headless --path . res://tests/FordTest.tscn — look for FORD_VERDICT.

const ROCK := preload("res://scenes/Rock.tscn")

var bf
var drift_rock
var wheel_rock
var _frame := 0
var _drift_start := Vector2.ZERO
var _wheel_start := Vector2.ZERO
var _events := {}

func _ready() -> void:
	bf = load("res://scenes/Battlefield.tscn").instantiate()
	add_child(bf)
	bf._wave = 99                             # no reinforcement waves during the test
	bf.max_logs = 0                           # no drifting logs to interfere
	for e in get_tree().get_nodes_in_group("targets") + get_tree().get_nodes_in_group("allies"):
		e.ai_enabled = false                  # freeze the army so only terrain/wheel act
	Audio.sfx.connect(_on_sfx)
	drift_rock = ROCK.instantiate()
	bf.add_child(drift_rock)
	drift_rock.global_position = Vector2(540, 300)   # in the right-hand river segment
	wheel_rock = ROCK.instantiate()
	bf.add_child(wheel_rock)
	wheel_rock.global_position = bf.get_node("WaterWheel").global_position   # sitting in the wheel
	_drift_start = drift_rock.global_position
	_wheel_start = wheel_rock.global_position
	print("FORD_READY ok")

func _on_sfx(event: StringName, _pos: Vector2) -> void:
	_events[event] = true

func _physics_process(_delta: float) -> void:
	_frame += 1
	if _frame >= 210:
		_report()

func _report() -> void:
	var drift: float = drift_rock.global_position.x - _drift_start.x
	var batted: float = wheel_rock.global_position.distance_to(_wheel_start)
	var creak: bool = _events.has("water_wheel_creak")
	var wheel_fx: bool = _events.has("water_splash") or _events.has("enemy_launch")
	print("FORD_RESULT drift_x=%.1f wheel_batted=%.1f creak=%s wheel_fx=%s"
		% [drift, batted, str(creak), str(wheel_fx)])
	var ok: bool = drift > 8.0 and batted > 60.0 and creak and wheel_fx
	print("FORD_VERDICT %s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)
