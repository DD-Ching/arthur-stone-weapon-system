extends Node2D
## Headless integration smoke test for the core mechanic (drag-to-swing control).
##
## Spawns Arthur and one dummy in front, holds the attack button, and DRAGS the aim
## across the dummy (a real mouse-swing). Asserts the swing:
##   - launched the dummy (knockback from real head speed)
##   - cost stamina (draining while dragging)
##   - emitted hit_landed
##
## Arthur's own _physics_process is disabled so his mouse-aim doesn't fight the test;
## we drive the weapon's aim + swing state directly (the weapon processes itself).
##
## Run:  godot --headless --path . res://tests/SwingSmokeTest.tscn
## Look for the SMOKE_VERDICT line in the output.

var arthur
var dummy
var _frame := 0
var _hit := false
var _stamina_start := 0.0
var _stamina_min := 1.0e9
var _dummy_start := Vector2.ZERO
var _aim := -1.6

func _ready() -> void:
	arthur = load("res://scenes/Arthur.tscn").instantiate()
	dummy = load("res://scenes/TargetDummy.tscn").instantiate()
	add_child(arthur)
	add_child(dummy)
	arthur.global_position = Vector2.ZERO
	dummy.global_position = Vector2(80, 0)   # in front; the dragged head sweeps through it
	arthur.set_physics_process(false)
	# Isolate the swing: neutralise the passive stone body so it can't shove the
	# dummy before the swing connects (we're testing the scored hit, not presence).
	arthur.weapon.stone_body.collision_layer = 0
	arthur.weapon.stone_body.collision_mask = 0
	arthur.weapon.hit_landed.connect(func(_s, _n): _hit = true)
	arthur.weapon.set_aim_target(_aim)
	print("SMOKE_READY ok")

func _physics_process(_delta: float) -> void:
	_frame += 1
	if _frame == 2:
		_stamina_start = arthur.stamina
		_dummy_start = dummy.global_position
	# Hold the button and drag the aim across the dummy (angle 0) — a real swing.
	if _frame >= 2 and _frame <= 24:
		arthur.weapon.set_swinging(true)
		_aim += 0.2
		arthur.weapon.set_aim_target(_aim)
	else:
		arthur.weapon.set_swinging(false)
		arthur.weapon.set_aim_target(_aim)
	if _frame > 2:
		_stamina_min = minf(_stamina_min, arthur.stamina)
	if _frame >= 140:
		_report()

func _report() -> void:
	var moved: float = dummy.global_position.distance_to(_dummy_start)
	var spent: float = _stamina_start - _stamina_min
	print("SMOKE_RESULT moved=%.1f spent_stamina=%.1f hit_signal=%s final_state=%d"
		% [moved, spent, str(_hit), arthur.weapon.state])
	var ok: bool = moved > 5.0 and spent > 1.0 and _hit
	print("SMOKE_VERDICT %s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)
