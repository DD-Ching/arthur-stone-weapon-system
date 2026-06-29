extends Node2D
## Headless test for the play-feel pass: SWING WEIGHT + ULTIMATE CHARGE PAYOFF.
##
## Two independent assertions, run in sequence:
##
##  1. SWING WEIGHT — holds the attack button and DRAGS the aim across a dummy (a real
##     fast head-speed swing). A scored (non-blocked) hit should commit Arthur's mass into
##     the blow via his existing lunge(): his _dash_vel gains some speed roughly along the
##     swing direction (a heavy hit moves the heavy man). Arthur's own _physics_process is
##     off so his steering can't pollute the measurement — we read the lunge burst directly.
##
##  2. ULTIMATE CHARGE PAYOFF — unleashes the radial musou burst at a LONG charge (2.0s) vs a
##     SHORT one (0.5s) and asserts the long-charge burst clears a strictly WIDER radius (the
##     charge you held earns a bigger screen-clear). Reads the spawned Shockwave's radius.
##
## Run:  godot --headless --path . res://tests/FeelTest.tscn --quit-after 600
## Look for the FEEL_VERDICT line.

var arthur
var dummy
var _frame := 0
var _aim := -1.6
var _dash_after := Vector2.ZERO
var _swing_dir := Vector2.RIGHT       ## the +X direction toward the dummy — the swing should carry Arthur this way
var _short_radius := 0.0
var _long_radius := 0.0

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
	# --- Phase 2: unleash the two bursts and read their scaled radius ---
	elif _frame == 40:
		var sw_short = _fire_and_grab(0.5)
		if sw_short:
			_short_radius = sw_short.radius
			sw_short.queue_free()   # clear it so the next burst is unambiguous
	elif _frame == 42:
		var sw_long = _fire_and_grab(2.0)
		if sw_long:
			_long_radius = sw_long.radius
			sw_long.queue_free()
	elif _frame >= 60:
		_report()

## Unleash the ultimate at the given charge and return the Shockwave node just spawned (newest).
func _fire_and_grab(charge: float):
	arthur._unleash_musou(charge)
	var newest = null
	for c in get_children():
		if c.is_in_group("shockwave"):
			newest = c   # the burst is added under us (the current scene); take the latest
	return newest

func _report() -> void:
	var dash_len: float = _dash_after.length()
	# The lunge should carry Arthur roughly toward the dummy (+X) — a positive dot along the swing dir.
	var dash_along: float = _dash_after.dot(_swing_dir)
	var swing_weight_ok: bool = dash_len > 5.0 and dash_along > 0.0
	var burst_bigger: bool = _long_radius > _short_radius + 1.0
	var ult_ok: bool = burst_bigger and _short_radius > 0.0
	var ok: bool = swing_weight_ok and ult_ok
	print("FEEL_RESULT dash_len=%.1f dash_along=%.1f | short_radius=%.0f long_radius=%.0f"
		% [dash_len, dash_along, _short_radius, _long_radius])
	print("FEEL_RESULT swing_weight=%s burst_bigger=%s" % [str(swing_weight_ok), str(burst_bigger)])
	print("FEEL_VERDICT %s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)
