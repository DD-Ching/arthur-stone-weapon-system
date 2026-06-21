extends Node2D
## Headless test for the v0.5 musou systems:
##   - the SPIN whirlwind launches a ring of enemies outward and drains stamina,
##   - the KO counter increments and fires a milestone on the round numbers.
##
## Run: godot --headless --path . res://tests/SpinTest.tscn — look for SPIN_VERDICT.

var arthur
var dummies := []
var _frame := 0
var _stamina0 := 0.0
var _ko_ok := false

func _ready() -> void:
	# KO counter unit check (deterministic).
	Impact.reset()
	var got_milestone := {"v": ""}
	Impact.kills_changed.connect(func(_k, ms): if ms != "": got_milestone["v"] = ms)
	for _i in 10:
		Impact.add_kill()
	_ko_ok = Impact.kills == 10 and got_milestone["v"] == "RAMPAGE!"
	Impact.reset()

	# Spin physics check: a ring of dummies around Arthur.
	arthur = load("res://scenes/Arthur.tscn").instantiate()
	add_child(arthur)
	arthur.global_position = Vector2.ZERO
	arthur.set_physics_process(false)                # drive the weapon directly
	arthur.weapon.stone_body.collision_layer = 0     # isolate: the whirl's hitbox does the work
	arthur.weapon.stone_body.collision_mask = 0
	arthur.weapon.set_aim_target(0.0)
	for i in 6:
		var d = load("res://scenes/TargetDummy.tscn").instantiate()
		add_child(d)
		var a := float(i) / 6.0 * TAU
		d.global_position = Vector2(cos(a), sin(a)) * 92.0
		dummies.append(d)
	print("SPIN_READY ok")

func _physics_process(_delta: float) -> void:
	_frame += 1
	arthur.weapon.set_aim_target(0.0)
	if _frame == 2:
		_stamina0 = arthur.stamina
		arthur.weapon.start_spin()
	elif _frame >= 55:
		_report()

func _report() -> void:
	var launched := 0
	for d in dummies:
		if is_instance_valid(d) and d.global_position.length() > 100.0:   # flung outward from the 92 ring
			launched += 1
	var spent: float = _stamina0 - arthur.stamina
	print("SPIN_RESULT launched=%d/6 stamina_spent=%.1f ko_unit=%s state=%d"
		% [launched, spent, str(_ko_ok), arthur.weapon.state])
	var ok: bool = launched >= 3 and spent > 5.0 and _ko_ok
	print("SPIN_VERDICT %s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)
