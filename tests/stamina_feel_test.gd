extends Node2D
## Headless test for the SOFT low-stamina band (combat-feel pass). It asserts that
## running low on stamina is a readable TAPER, not an un-fun hard stop:
##   - at full stamina (weapon IDLE) the mobility multiplier is the normal 1.0,
##   - below `low_stamina_threshold` the multiplier is REDUCED but strictly > 0
##     (you wade, you don't freeze), and
##   - even at a near-empty pool it stays > 0 (only a truly hard 0 floor cuts in).
##
## Run: godot --headless --path . res://tests/StaminaFeelTest.tscn --quit-after 600
## Look for the STAMFEEL_VERDICT line.

var arthur
var _frame := 0
var _full := 0.0
var _low := 0.0
var _empty := 0.0

func _ready() -> void:
	arthur = load("res://scenes/Arthur.tscn").instantiate()
	add_child(arthur)
	arthur.global_position = Vector2.ZERO
	arthur.set_physics_process(false)   # we sample _speed_multiplier() directly
	arthur.weapon.set_aim_target(0.0)
	print("STAMFEEL_READY ok")

func _physics_process(_delta: float) -> void:
	_frame += 1
	# Let the weapon settle into IDLE (so the weapon-state base multiplier is 1.0 and the
	# only thing moving the number is the low-stamina taper we're testing).
	if _frame == 4:
		arthur.stamina = arthur.max_stamina
		_full = arthur._speed_multiplier()
		# Comfortably below the threshold, but not empty — should be a partial slowdown.
		arthur.stamina = arthur.low_stamina_threshold * 0.4
		_low = arthur._speed_multiplier()
		# Truly empty — the hard floor; must STILL be > 0 (a crawl, never a freeze).
		arthur.stamina = 0.0
		_empty = arthur._speed_multiplier()
	elif _frame >= 12:
		_report()

func _report() -> void:
	var weapon_idle: bool = arthur.weapon.state == StoneWeapon.State.IDLE
	# A taper: low < full (reduced), low > 0 (not a hard stop), and even empty stays > 0.
	var reduced: bool = _low < _full
	var not_zero: bool = _low > 0.0 and _empty > 0.0
	var full_ok: bool = is_equal_approx(_full, 1.0)
	print("STAMFEEL_RESULT idle=%s full=%.3f low=%.3f empty=%.3f reduced=%s not_zero=%s"
		% [str(weapon_idle), _full, _low, _empty, str(reduced), str(not_zero)])
	var ok: bool = weapon_idle and full_ok and reduced and not_zero
	print("STAMFEEL_VERDICT %s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)
