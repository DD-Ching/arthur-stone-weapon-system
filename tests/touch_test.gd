extends Node2D
## Headless test for the TouchControls module (mobile play).
##
## Drives synthetic screen-touch events at the virtual sticks + buttons and asserts:
##   - the LEFT stick produces an analog move vector in the dragged direction;
##   - the RIGHT stick, dragged past the deadzone, both aims (its angle) AND presses the
##     existing `attack` action (so circling it whips the stone — the desktop mechanic);
##   - rotating the right stick changes the aim angle;
##   - the SLAM / SPIN buttons press their existing actions, and release on lift.
##
## Run: godot --headless --path . res://tests/TouchControlsTest.tscn — look for TOUCH_VERDICT.

var _tc
var _frame := 0

func _ready() -> void:
	_tc = load("res://scenes/ui/TouchControls.tscn").instantiate()
	_tc.force_on = true   # no real touchscreen in headless — show + arm the UI anyway
	add_child(_tc)

func _physics_process(_delta: float) -> void:
	_frame += 1
	if _frame == 2:
		_report()

func _report() -> void:
	var vp: Vector2 = _tc._vp
	var checks := {}

	# 1) LEFT stick: press, then drag up → move_vec points up; drag right → points right.
	var lbase := Vector2(vp.x * 0.2, vp.y * 0.7)
	_touch(0, lbase, true)
	_drag(0, lbase + Vector2(0, -100))
	checks["move_up"] = _tc.move_vec.y < -0.5 and absf(_tc.move_vec.x) < 0.2
	_drag(0, lbase + Vector2(100, 0))
	checks["move_right"] = _tc.move_vec.x > 0.5 and absf(_tc.move_vec.y) < 0.2
	_touch(0, lbase, false)
	checks["move_release"] = _tc.move_vec == Vector2.ZERO

	# 2) RIGHT stick: a bare press (no drag) must NOT yet aim or press attack…
	var rbase := Vector2(vp.x * 0.7, vp.y * 0.5)
	_touch(1, rbase, true)
	checks["aim_idle"] = (not _tc.aim_active) and (not Input.is_action_pressed("attack"))
	# …dragging it out engages the swing (aim + the existing attack action), pointing right.
	_drag(1, rbase + Vector2(100, 0))
	checks["aim_right"] = _tc.aim_active and Input.is_action_pressed("attack") and absf(_tc.aim_angle) < 0.2
	# Rotating the stick (circling the thumb) sweeps the aim — this is what whips the head.
	_drag(1, rbase + Vector2(0, -100))
	checks["aim_rotated"] = absf(_tc.aim_angle - (-PI * 0.5)) < 0.25
	# Lifting the stick drops swing mode (releases attack).
	_touch(1, rbase, false)
	checks["aim_release"] = (not _tc.aim_active) and (not Input.is_action_pressed("attack"))

	# 3) SLAM / SPIN buttons press + release their existing actions.
	_touch(2, _tc._slam_c, true)
	checks["slam_press"] = Input.is_action_pressed("slam")
	_touch(2, _tc._slam_c, false)
	checks["slam_release"] = not Input.is_action_pressed("slam")
	_touch(3, _tc._spin_c, true)
	checks["spin_press"] = Input.is_action_pressed("spin")
	_touch(3, _tc._spin_c, false)
	checks["spin_release"] = not Input.is_action_pressed("spin")

	var ok := true
	var parts: Array = []
	for k in checks:
		ok = ok and checks[k]
		parts.append("%s=%s" % [k, str(checks[k])])
	print("TOUCH_RESULT ", " ".join(parts))
	print("TOUCH_VERDICT %s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)

func _touch(index: int, pos: Vector2, pressed: bool) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = index
	ev.position = pos
	ev.pressed = pressed
	_tc._input(ev)

func _drag(index: int, pos: Vector2) -> void:
	var ev := InputEventScreenDrag.new()
	ev.index = index
	ev.position = pos
	_tc._input(ev)
