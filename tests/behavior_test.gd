extends Node2D
## Headless behaviour test for the v0.2 mechanics, complementing the swing smoke
## test. It asserts:
##   - passive presence: the resting stone shoves an overlapping enemy out (the
##     weapon is solid even when not attacking),
##   - overhead slam: it spawns a shockwave, knocks back a nearby enemy, and
##     drops a chunk of debris (a launchable rock).
##
## Run: godot --headless --path . res://tests/BehaviorTest.tscn
## Look for the BEHAVIOR_VERDICT line.

var arthur
var dummy_passive
var dummy_slam
var _frame := 0
var _passive_start := Vector2.ZERO
var _slam_start := Vector2.ZERO
var _passive_moved := 0.0
var _props_before := 0
var _shock_seen := false

func _ready() -> void:
	arthur = load("res://scenes/Arthur.tscn").instantiate()
	add_child(arthur)
	arthur.global_position = Vector2.ZERO
	dummy_passive = load("res://scenes/TargetDummy.tscn").instantiate()
	add_child(dummy_passive)
	dummy_passive.global_position = Vector2(92, 0)   # overlapping the resting stone
	dummy_slam = load("res://scenes/TargetDummy.tscn").instantiate()
	add_child(dummy_slam)
	dummy_slam.global_position = Vector2(150, 0)      # near the slam point, clear of the stone
	arthur.weapon.set_aim_target(0.0)
	# Record baselines NOW, before the first physics step ejects the overlapping dummy.
	_passive_start = dummy_passive.global_position
	_slam_start = dummy_slam.global_position
	print("BEHAVIOR_READY ok")

func _physics_process(_delta: float) -> void:
	_frame += 1
	arthur.weapon.set_aim_target(0.0)   # hold aim along +X
	if _frame == 28:
		# Measure passive push BEFORE any attack, then start the slam.
		_passive_moved = dummy_passive.global_position.distance_to(_passive_start)
		_props_before = get_tree().get_nodes_in_group("props").size()
		arthur.weapon.start_slam()
	elif _frame > 28 and get_tree().get_nodes_in_group("shockwave").size() > 0:
		_shock_seen = true
	if _frame >= 150:
		_report()

func _report() -> void:
	var slam_moved: float = dummy_slam.global_position.distance_to(_slam_start)
	var props_after: int = get_tree().get_nodes_in_group("props").size()
	var debris: bool = props_after > _props_before
	print("BEHAVIOR_RESULT passive_push=%.1f slam_knock=%.1f shockwave=%s debris=%s"
		% [_passive_moved, slam_moved, str(_shock_seen), str(debris)])
	var ok: bool = _passive_moved > 4.0 and slam_moved > 10.0 and _shock_seen and debris
	print("BEHAVIOR_VERDICT %s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)
