extends Node2D
## Headless integration smoke test for the core mechanic.
##
## Spawns Arthur and one dummy, aims the weapon straight at the dummy, drives a
## real swing through its state machine, and asserts that the swing actually:
##   - launched the dummy (knockback)
##   - cost stamina
##   - emitted hit_landed
##
## Run:  godot --headless --path . res://tests/SwingSmokeTest.tscn
## Look for the SMOKE_VERDICT line in the output.

var arthur
var dummy
var _frame := 0
var _hit := false
var _stamina_start := 0.0
var _stamina_min := 1.0e9  # lowest stamina seen — stamina regenerates, so net change misleads
var _dummy_start := Vector2.ZERO

func _ready() -> void:
	arthur = load("res://scenes/Arthur.tscn").instantiate()
	dummy = load("res://scenes/TargetDummy.tscn").instantiate()
	add_child(arthur)
	add_child(dummy)
	arthur.global_position = Vector2.ZERO
	dummy.global_position = Vector2(72, 0)  # straight along aim, inside the head's path
	# Isolate the swing: neutralise the passive stone body so it can't shove the
	# dummy before the swing connects (we're testing the attack hit, not presence).
	arthur.weapon.stone_body.collision_layer = 0
	arthur.weapon.stone_body.collision_mask = 0
	arthur.weapon.hit_landed.connect(func(_s, _n): _hit = true)
	print("SMOKE_READY ok")

func _physics_process(_delta: float) -> void:
	_frame += 1
	match _frame:
		2:
			_stamina_start = arthur.stamina
			_dummy_start = dummy.global_position
			arthur.weapon.set_aim_target(0.0)   # aim +X, at the dummy
			arthur.weapon.press_attack()
		4:
			arthur.weapon.release_attack()       # weapon still enforces the minimum wind-up
		_:
			if _frame > 2:
				_stamina_min = minf(_stamina_min, arthur.stamina)
			if _frame >= 140:
				_report()

func _report() -> void:
	# Explicit types: dummy/arthur are untyped (Variant), so := cannot infer here.
	var moved: float = dummy.global_position.distance_to(_dummy_start)
	var spent: float = _stamina_start - _stamina_min  # peak stamina drawn during the swing
	print("SMOKE_RESULT moved=%.1f spent_stamina=%.1f hit_signal=%s final_state=%d"
		% [moved, spent, str(_hit), arthur.weapon.state])
	var ok: bool = moved > 5.0 and spent > 1.0 and _hit
	print("SMOKE_VERDICT %s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)
