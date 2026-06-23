extends Node2D
## Headless test for the data-driven Ability system (scripts/abilities/).
##
## Drives each new move kind directly (no AI flakiness) and asserts:
##   - JAVELIN: execute() spawns a projectile that flies and damages an opposing-team foe;
##   - POUND:   execute() deals an instant radial AoE to a foe in range;
##   - SELECTION: AbilityLibrary.choose() prefers the gap-closer (leap) when far and the
##                melee (slash) when close, honouring each move's range band;
##   - FRIENDLY FIRE: a raider's pound does NOT hurt another raider.
##
## Run: godot --headless --path . res://tests/AbilitiesTest.tscn — look for ABIL_VERDICT.

var _user            ## a raider (the attacker)
var _pound_foe       ## an ally in pound range
var _jav_foe         ## an ally down the javelin's flight path
var _friendly        ## another raider (must NOT be hit by the raider's pound)
var _jav_h0 := 0.0
var _frame := 0
var _checks := {}

func _ready() -> void:
	_user = _spawn("res://scenes/LightSoldier.tscn", "raiders", Vector2.ZERO)
	_pound_foe = _spawn("res://scenes/TargetDummy.tscn", "ally", Vector2(0.0, 60.0))
	_jav_foe = _spawn("res://scenes/TargetDummy.tscn", "ally", Vector2(250.0, 0.0))
	_friendly = _spawn("res://scenes/TargetDummy.tscn", "raiders", Vector2(0.0, -55.0))

	# POUND — instant radial AoE around the user. Records health deltas right away.
	var pound_h0: float = _pound_foe.health
	var friendly_h0: float = _friendly.health
	AbilityLibrary.get_move("pound").execute(_user, _pound_foe, Vector2(0.0, 1.0))
	_checks["pound_hits_foe"] = _pound_foe.health < pound_h0
	_checks["pound_spares_ally"] = _friendly.health == friendly_h0   # friendly fire OFF

	# JAVELIN — spawns a flying projectile; assert it lands a few frames later.
	_jav_h0 = _jav_foe.health
	AbilityLibrary.get_move("javelin").execute(_user, _jav_foe, Vector2.RIGHT)

	# SELECTION — range-driven choice between a gap-closer and a melee.
	var set_ := AbilityLibrary.build_for(PackedStringArray(["leap", "slash"]))
	var far = AbilityLibrary.choose(set_, 150.0, {})
	var near = AbilityLibrary.choose(set_, 18.0, {})
	_checks["pick_far_is_leap"] = far != null and far.id == "leap"
	_checks["pick_near_is_slash"] = near != null and near.id == "slash"
	print("ABIL_READY ok")

func _physics_process(_delta: float) -> void:
	_frame += 1
	if _frame >= 60:
		_checks["javelin_hits_foe"] = _jav_foe.health < _jav_h0
		_report()

func _spawn(path: String, team: String, pos: Vector2):
	var n = load(path).instantiate()
	n.team = team          # set before add_child so _ready() joins the right groups
	n.ai_enabled = false   # passive — we drive the abilities directly
	add_child(n)
	n.global_position = pos
	return n

func _report() -> void:
	var ok := true
	var parts: Array = []
	for k in _checks:
		ok = ok and _checks[k]
		parts.append("%s=%s" % [k, str(_checks[k])])
	print("ABIL_RESULT ", " ".join(parts))
	print("ABIL_VERDICT %s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)
