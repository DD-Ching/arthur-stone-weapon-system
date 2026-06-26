extends Node2D
## Headless test for the combat-feel / anti-spin-to-win pass. It asserts:
##   - the whirl is a REAL fight: a spinning Arthur launches a nearby enemy outward,
##   - SPIN INTERRUPT: an enemy hit that lands WHILE the stone is whirling forces the
##     weapon OUT of the SPIN state (Arthur.take_damage → weapon.stop_spin()), so
##     standing-and-spinning into a shield/spear wall is punished instead of being free, and
##   - the SCREEN-CLEAR NERF: spin_speed_ref (the relative_speed the whirl feeds the
##     impact formula) is now well below the old free-clear value (< 1000).
##
## Run: godot --headless --path . res://tests/SpinBalanceTest.tscn --quit-after 600
## Look for the SPINBAL_VERDICT line.

var arthur
var dummy
var _frame := 0
var _spinning_seen := false   ## we actually reached the SPIN state before the hit
var _state_after_hit := -1    ## weapon state immediately after the enemy hit lands
var _hit_applied := false
var _dummy_start := Vector2.ZERO

func _ready() -> void:
	arthur = load("res://scenes/Arthur.tscn").instantiate()
	add_child(arthur)
	arthur.global_position = Vector2.ZERO
	arthur.set_physics_process(false)                # drive the weapon directly
	arthur.weapon.stone_body.collision_layer = 0     # isolate: the whirl's hitbox does the work
	arthur.weapon.stone_body.collision_mask = 0
	arthur.weapon.set_aim_target(0.0)
	# A real enemy inside the whirl's reach — the spin must actually launch it (so the
	# "interrupt while genuinely fighting" is meaningful, not a hit on an idle whirl).
	dummy = load("res://scenes/TargetDummy.tscn").instantiate()
	add_child(dummy)
	dummy.global_position = Vector2(92, 0)
	_dummy_start = dummy.global_position
	print("SPINBAL_READY ok")

func _physics_process(_delta: float) -> void:
	_frame += 1
	arthur.weapon.set_aim_target(0.0)
	if _frame == 2:
		arthur.weapon.start_spin()
	elif _frame == 30:
		# By now the whirl has been launching the dummy for ~28 frames — confirm we are
		# genuinely whirling, THEN land an enemy hit on Arthur. The hit must drive the
		# weapon out of SPIN via the interrupt in take_damage().
		_spinning_seen = arthur.weapon.state == StoneWeapon.State.SPIN
		arthur._invuln = 0.0   # ensure the hit isn't eaten by i-frames
		_hit_applied = arthur.take_damage(10.0, Vector2(0, -100))
		_state_after_hit = arthur.weapon.state
	elif _frame >= 42:
		_report()

func _report() -> void:
	var ref: float = arthur.weapon.spin_speed_ref
	var launched: bool = dummy.global_position.distance_to(_dummy_start) > 20.0   # flung by the whirl
	var interrupted: bool = _state_after_hit != StoneWeapon.State.SPIN
	var nerfed: bool = ref < 1000.0
	print("SPINBAL_RESULT spinning_seen=%s launched=%s hit_applied=%s state_after_hit=%d interrupted=%s spin_speed_ref=%.1f nerfed=%s"
		% [str(_spinning_seen), str(launched), str(_hit_applied), _state_after_hit, str(interrupted), ref, str(nerfed)])
	var ok: bool = _spinning_seen and launched and _hit_applied and interrupted and nerfed
	print("SPINBAL_VERDICT %s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)
