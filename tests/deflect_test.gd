extends Node2D
## Headless test that LOCKS IN the stone-deflects-arrows contract (token DEFLECT).
##
## The parked/swung STONE (its solid body, in group "stone_weapon") is a shield as well
## as a club: a Javelin that meets it is knocked out of the air instead of striking
## through. This is what makes archers BLOCKABLE — raise the stone and the volley breaks
## on it. The contract has two halves, and both must hold for the block to be meaningful:
##   - DEFLECT: a Javelin meeting a body in group "stone_weapon" goes _spent WITHOUT
##              calling the target's take_damage, and the DEFLECT effect fires
##              (Impact.add_flow rises — the clean-block reward);
##   - SPECIFIC: a Javelin meeting a NORMAL opposing foe (not stone_weapon) still lands
##              its hit, so the deflect is the stone's privilege, not a blanket miss.
##
## Uses the mock-body pattern from tests/physics_foundation_test.gd: a bare Node2D in the
## "stone_weapon" group, fed straight to javelin._on_body_entered(stone).
##
## Run: godot --headless --path . res://tests/DeflectTest.tscn --quit-after 600
## Look for the DEFLECT_VERDICT line.

const JAVELIN := preload("res://scenes/Javelin.tscn")

var _deflect_spent := false       ## the deflected javelin went _spent
var _deflect_no_damage := false   ## ...without striking the target
var _deflect_flow := false        ## ...and the DEFLECT flow reward fired
var _foe_struck := false          ## a normal opposing foe still takes the hit
var _foe_not_spent_early := false ## (sanity) the foe javelin only spent on the real hit
var _frame := 0

func _ready() -> void:
	_test_deflect()
	_test_specific_hit()

## A javelin aimed at a take_damage target, then met by a stone_weapon body: it must
## DEFLECT — spend itself, leave the target untouched, and pay the clean-block flow.
func _test_deflect() -> void:
	# A mock target that records whether its take_damage was ever called. The stone sits
	# between the thrower and this target, so a correct deflect never touches it.
	var target := _StruckSpy.new()
	add_child(target)
	target.global_position = Vector2(400.0, 0.0)

	var jav: Javelin = JAVELIN.instantiate()
	add_child(jav)
	jav.launch(Vector2.ZERO, Vector2.RIGHT, 500.0, 8.0, "raiders")

	var flow_before: float = Impact.flow
	# The swung stone's solid body — a bare Node2D in the "stone_weapon" group, exactly
	# the foundation-test pattern. Feeding it to _on_body_entered IS the deflect event.
	var stone := Node2D.new()
	stone.add_to_group("stone_weapon")
	add_child(stone)
	jav._on_body_entered(stone)

	_deflect_spent = bool(jav._spent)
	_deflect_no_damage = not target.was_struck            # the target was never hit
	_deflect_flow = Impact.flow > flow_before             # the DEFLECT reward landed

## A javelin meeting a NORMAL opposing foe (no stone_weapon membership) must still strike
## it — proving the deflect is specific to the stone, not a blanket "javelin never hits".
func _test_specific_hit() -> void:
	var foe := _StruckSpy.new()
	foe.add_to_group("ally")          # the opposing team for a "raiders" javelin
	add_child(foe)
	foe.global_position = Vector2(0.0, 400.0)

	var jav: Javelin = JAVELIN.instantiate()
	add_child(jav)
	jav.launch(Vector2.ZERO, Vector2.DOWN, 500.0, 8.0, "raiders")
	_foe_not_spent_early = not jav._spent                 # not spent before it meets anything
	jav._on_body_entered(foe)
	_foe_struck = foe.was_struck and bool(jav._spent)     # struck the foe + spent itself

func _physics_process(_dt: float) -> void:
	_frame += 1
	if _frame >= 6:
		_report()

func _report() -> void:
	var ok := _deflect_spent and _deflect_no_damage and _deflect_flow \
		and _foe_struck and _foe_not_spent_early
	print("DEFLECT_RESULT spent=%s no_damage=%s flow=%s foe_struck=%s foe_clean_pre=%s" % [
		str(_deflect_spent), str(_deflect_no_damage), str(_deflect_flow),
		str(_foe_struck), str(_foe_not_spent_early)])
	print("DEFLECT_VERDICT %s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)

## A minimal combatant stand-in: exposes take_damage like Arthur/an ally and records
## whether it was ever struck, so the test can assert the deflect spared it.
class _StruckSpy extends Node2D:
	var was_struck := false
	func take_damage(_amount: float, _from_pos: Vector2 = Vector2.ZERO) -> bool:
		was_struck = true
		return true
