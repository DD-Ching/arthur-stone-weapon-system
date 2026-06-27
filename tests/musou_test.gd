extends Node2D
## Headless test for the MUSOU gauge + the CHARGE-BEAM ultimate.
##
## Fills Arthur's musou gauge, aims along +X, fires the ultimate (the public trigger, which now
## sprays a sustained light beam), and asserts:
##   - the line of enemies IN the beam's path are damaged/felled,
##   - an off-path control to the side is UNHARMED (the beam is DIRECTIONAL, not radial),
##   - the musou gauge resets back toward 0 after firing,
##   - add_musou() emits `musou_changed` (the HUD's hook).
##
## Drives Arthur's state directly (his _physics_process is off) so nothing fights the test. Run:
##   godot --headless --path . res://tests/MusouTest.tscn --quit-after 600 — look for MUSOU_VERDICT.

var arthur
var path_enemies := []
var _control = null
var _start_health := []
var _control_start := 0.0
var _frame := 0
var _signal_fired := false
var _musou_full := 0.0
var _musou_after := 0.0
var _fired := false

func _ready() -> void:
	Impact.reset()
	arthur = load("res://scenes/Arthur.tscn").instantiate()
	add_child(arthur)
	arthur.global_position = Vector2.ZERO
	arthur.set_physics_process(false)   # we drive the ultimate directly
	arthur.musou_changed.connect(func(_c, _m): _signal_fired = true)
	# Aim the stone along +X so the beam fires that way.
	if "weapon" in arthur and arthur.weapon:
		arthur.weapon.aim_angle = 0.0
		if arthur.weapon.has_method("set_aim_target"):
			arthur.weapon.set_aim_target(0.0)
	# A line of light soldiers along the +X beam path (within the beam's reach).
	for i in 5:
		var e = load("res://scenes/LightSoldier.tscn").instantiate()
		add_child(e)
		e.global_position = Vector2(140.0 + float(i) * 120.0, 0.0)
		path_enemies.append(e)
	# An off-path control well to the side — a DIRECTIONAL beam must leave it untouched.
	_control = load("res://scenes/LightSoldier.tscn").instantiate()
	add_child(_control)
	_control.global_position = Vector2(0.0, 420.0)
	print("MUSOU_READY ok")

func _physics_process(_delta: float) -> void:
	_frame += 1
	if _frame == 2:
		for e in path_enemies:
			_start_health.append(e.health)
		_control_start = _control.health
		arthur.add_musou(arthur.max_musou)        # fill → should emit musou_changed
		_musou_full = arthur.musou
		arthur.trigger_musou_ultimate()           # fires the charge-beam along +X
		_musou_after = arthur.musou
		_fired = true
	elif _frame >= 70:
		_report()

func _report() -> void:
	var hit := 0
	for i in range(path_enemies.size()):
		var e = path_enemies[i]
		if (not is_instance_valid(e)) or e._dead or e.health < _start_health[i] - 0.01:
			hit += 1
	var control_unharmed: bool = is_instance_valid(_control) and not _control._dead \
		and _control.health > _control_start - 0.01
	var ok: bool = _fired and _signal_fired \
		and _musou_full >= arthur.max_musou - 0.01 \
		and _musou_after <= arthur.max_musou * 0.5 \
		and hit >= 4 and control_unharmed
	print("MUSOU_RESULT path_hit=%d/5 control_unharmed=%s musou_full=%.1f musou_after=%.1f signal=%s fired=%s"
		% [hit, str(control_unharmed), _musou_full, _musou_after, str(_signal_fired), str(_fired)])
	print("MUSOU_VERDICT %s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)
