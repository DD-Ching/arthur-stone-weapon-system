extends Node2D
## Headless test for the play-feel pass: SWING WEIGHT + BEAM CHARGE PAYOFF.
##
## Two independent assertions, run in sequence:
##
##  1. SWING WEIGHT — holds the attack button and DRAGS the aim across a dummy (a real
##     fast head-speed swing). A scored (non-blocked) hit should commit Arthur's mass into
##     the blow via his existing lunge(): his _dash_vel gains some speed roughly along the
##     swing direction (a heavy hit moves the heavy man). Arthur's own _physics_process is
##     off so his steering can't pollute the measurement — we read the lunge burst directly.
##
##  2. BEAM CHARGE PAYOFF — fires the charge-beam at a LONG charge (2.0s) vs a SHORT one
##     (0.5s) and asserts the long-charge beam is strictly wider AND longer (the charge you
##     held earns a bigger beam). Reads the beam's effective reach/width straight off it.
##
## Run:  godot --headless --path . res://tests/FeelTest.tscn --quit-after 600
## Look for the FEEL_VERDICT line.

var arthur
var dummy
var _frame := 0
var _aim := -1.6
var _dash_after := Vector2.ZERO
var _swing_dir := Vector2.RIGHT       ## the +X direction toward the dummy — the swing should carry Arthur this way
var _short_len := 0.0
var _short_width := 0.0
var _long_len := 0.0
var _long_width := 0.0

func _ready() -> void:
	Impact.reset()
	arthur = load("res://scenes/Arthur.tscn").instantiate()
	dummy = load("res://scenes/TargetDummy.tscn").instantiate()
	add_child(arthur)
	add_child(dummy)
	arthur.global_position = Vector2.ZERO
	dummy.global_position = Vector2(80, 0)   # in front (+X); the dragged head sweeps through it
	arthur.set_physics_process(false)        # we drive the weapon directly; no steering noise
	# Isolate the SCORED swing: neutralise the passive solid body so it can't shove the
	# dummy (or nudge Arthur) before the swing connects — we're testing the scored hit.
	arthur.weapon.stone_body.collision_layer = 0
	arthur.weapon.stone_body.collision_mask = 0
	arthur.weapon.set_aim_target(_aim)
	print("FEEL_READY ok")

func _physics_process(_delta: float) -> void:
	_frame += 1
	# --- Phase 1: drive a fast swing across the dummy (frames 2..24, like the smoke test) ---
	if _frame >= 2 and _frame <= 24:
		arthur.weapon.set_swinging(true)
		_aim += 0.2
		arthur.weapon.set_aim_target(_aim)
	elif _frame == 25:
		arthur.weapon.set_swinging(false)
		# Capture Arthur's lunge burst right after the swing connected — the swing-weight nudge.
		_dash_after = arthur._dash_vel
	# --- Phase 2: fire the two beams and read their scaled reach/width ---
	elif _frame == 40:
		arthur.weapon.aim_angle = 0.0
		arthur.weapon.set_aim_target(0.0)
		var b_short = _fire_and_grab(0.5)
		if b_short:
			_short_len = b_short._len
			_short_width = b_short._width
			b_short.queue_free()   # clear it so the next beam is unambiguous
	elif _frame == 42:
		var b_long = _fire_and_grab(2.0)
		if b_long:
			_long_len = b_long._len
			_long_width = b_long._width
			b_long.queue_free()
	elif _frame >= 60:
		_report()

## Fire a beam at the given charge and return the Beam node just spawned (the newest child).
func _fire_and_grab(charge: float):
	arthur.fire_musou_beam(charge)
	var newest = null
	for c in get_children():
		if c.get_script() == load("res://scripts/Beam.gd"):
			newest = c   # the beam is added under us (the current scene); take the latest
	return newest

func _report() -> void:
	var dash_len: float = _dash_after.length()
	# The lunge should carry Arthur roughly toward the dummy (+X) — a positive dot along the swing dir.
	var dash_along: float = _dash_after.dot(_swing_dir)
	var swing_weight_ok: bool = dash_len > 5.0 and dash_along > 0.0
	var beam_longer: bool = _long_len > _short_len + 1.0
	var beam_wider: bool = _long_width > _short_width + 1.0
	var beam_ok: bool = beam_longer and beam_wider and _short_len > 0.0
	var ok: bool = swing_weight_ok and beam_ok
	print("FEEL_RESULT dash_len=%.1f dash_along=%.1f | short(len=%.0f w=%.1f) long(len=%.0f w=%.1f)"
		% [dash_len, dash_along, _short_len, _short_width, _long_len, _long_width])
	print("FEEL_RESULT swing_weight=%s beam_longer=%s beam_wider=%s"
		% [str(swing_weight_ok), str(beam_longer), str(beam_wider)])
	print("FEEL_VERDICT %s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)
