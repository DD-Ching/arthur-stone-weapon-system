extends Node2D
## Headless test for the raider-toughness pass (unit DIFFIC):
##   The squishy raiders (LightSoldier / Skirmisher / Archer / Spearman / ...) had so
##   little HP that a single flat swing one-shot them, making a crowd no real clock.
##   This unit is PURE per-instance .tscn stat tuning (max_health up, attack_damage up);
##   no script change. This test pins that contract on the canonical squishy raider:
##
##   - TOUGHER:  scenes/LightSoldier.tscn now boots with max_health >= 30 (was ~22), so
##               its starting `health` (set to max_health on _ready) clears the floor.
##   - SURVIVES: after ONE modest, deliberately sub-lethal hit it is still up — health > 0
##               and not _dead — proving a flat swing no longer one-shots it.
##
## We assert a sane floor, not an exact final HP, so future feel-tuning of the numbers
## does not falsely break the suite.
##
## Run: godot --headless --path . res://tests/DifficultyTest.tscn --quit-after 600
## Look for the DIFFIC_VERDICT line.

const HEALTH_FLOOR := 30.0     ## LightSoldier must boot at least this tough.
const HIT_DAMAGE := 18.0       ## one modest swing — sub-lethal vs a >=30 HP raider.

var _soldier                   ## the LightSoldier instance under test
var _checks := {}
var _frame := 0

func _ready() -> void:
	_soldier = load("res://scenes/LightSoldier.tscn").instantiate()
	_soldier.team = "raiders"   # set before add_child so _ready() joins the raider groups
	_soldier.ai_enabled = false # static target: we only exercise stats / apply_hit here
	add_child(_soldier)         # _ready() now runs and sets health = max_health
	_soldier.global_position = Vector2.ZERO

	# TOUGHER — the toughness pass raised max_health well clear of one-swing range, and
	# the live `health` boots to that same value.
	var mh: float = _soldier.max_health
	_checks["max_health_raised"] = mh >= HEALTH_FLOOR
	_checks["boots_full_hp"] = _soldier.health >= HEALTH_FLOOR

	print("DIFFIC_READY max_health=%s health=%s" % [str(mh), str(_soldier.health)])

func _physics_process(_delta: float) -> void:
	_frame += 1
	# Let it settle a couple of physics frames, then land ONE modest sub-lethal hit and
	# prove it is still standing.
	if _frame == 30:
		var h0: float = _soldier.health
		# dir, strength, stun, damage, pin — a real but modest blow, not a brute-kill.
		_soldier.apply_hit(Vector2.DOWN, 300.0, 0.1, HIT_DAMAGE, 0.0)
		_checks["hit_chipped_hp"] = _soldier.health < h0
		_checks["survived_one_hit"] = _soldier.health > 0.0 and not _soldier._dead
		print("DIFFIC_HIT before=%s after=%s dead=%s" % [str(h0), str(_soldier.health), str(_soldier._dead)])
	if _frame == 40:
		_report()

func _report() -> void:
	var ok := true
	var parts: Array = []
	for k in _checks:
		ok = ok and _checks[k]
		parts.append("%s=%s" % [k, str(_checks[k])])
	print("DIFFIC_RESULT ", " ".join(parts))
	print("DIFFIC_VERDICT %s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)
