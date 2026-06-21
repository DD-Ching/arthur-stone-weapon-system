extends Node2D
## Headless test for the v0.3 impact + combo system. Deterministic where it can
## be (the scoring formula and Stone Flow are pure), plus one physics check that
## a launched-prop collision actually shoves an enemy and feeds the combo.
##
## Asserts the acceptance-criteria bits that are easy to get subtly wrong:
##   - a PINNED hit (wall crush) scores and damages MORE than the same hit in the
##     open — "wall crush does more damage than normal hits",
##   - charging raises the score,
##   - Stone Flow gains on hits, loses on a miss, and stacks up,
##   - Impact.collide() (rocks / bowling) applies knockback and builds flow.
##
## Run: godot --headless --path . res://tests/ImpactTest.tscn — look for IMPACT_VERDICT.

var dummy
var _frame := 0
var _flow_before := 0.0
var _dummy_start := Vector2.ZERO
var _formula_ok := false
var _flow_ok := false

func _ready() -> void:
	Impact.reset()

	# --- formula: pinned vs open, charged vs not (all at 0 stacks) ---
	var base := {
		"kind": "swing", "attacker_mass": Impact.MASS_STONE,
		"relative_speed": Impact.REF_SPEED, "charge": 0.0, "angle_quality": 1.0, "pin": 0.0,
	}
	var r_open: Dictionary = Impact.resolve_hit(base)
	var pinned := base.duplicate()
	pinned["pin"] = 1.0
	var r_pin: Dictionary = Impact.resolve_hit(pinned)
	var charged := base.duplicate()
	charged["charge"] = 1.0
	var r_charge: Dictionary = Impact.resolve_hit(charged)

	var crush_more: bool = r_pin["score"] > r_open["score"] and r_pin["damage"] > r_open["damage"] \
		and r_pin["knockback"] >= r_open["knockback"] and String(r_pin["label"]) != ""
	var charge_more: bool = r_charge["score"] > r_open["score"]
	_formula_ok = crush_more and charge_more
	print("IMPACT_FORMULA open=%.2f pinned=%.2f charged=%.2f crush_label=%s"
		% [r_open["score"], r_pin["score"], r_charge["score"], String(r_pin["label"])])

	# --- Stone Flow: gain, stack, lose ---
	Impact.reset()
	Impact.add_flow(40.0)
	var stacked: bool = Impact.stacks >= 2 and Impact.flow == 40.0
	var buffed: bool = Impact.charge_speed_mult() > 1.0
	Impact.note_miss()
	var bled: bool = Impact.flow < 40.0
	_flow_ok = stacked and buffed and bled
	print("IMPACT_FLOW stacked=%s buffed=%s after_miss=%.1f" % [str(stacked), str(buffed), Impact.flow])

	# --- physics: a launched rock-speed collision shoves a dummy + builds flow ---
	Impact.reset()
	dummy = load("res://scenes/TargetDummy.tscn").instantiate()
	add_child(dummy)
	dummy.global_position = Vector2(200, 0)
	_dummy_start = dummy.global_position
	_flow_before = Impact.flow

func _physics_process(_delta: float) -> void:
	_frame += 1
	if _frame == 2:
		Impact.collide(dummy, Vector2.RIGHT, 700.0, Impact.MASS_ROCK, "rock", self)
	if _frame >= 40:
		_report()

func _report() -> void:
	var moved: float = dummy.global_position.distance_to(_dummy_start)
	var flow_gain: float = Impact.flow - _flow_before
	var collide_ok: bool = moved > 5.0 and flow_gain > 0.0
	print("IMPACT_COLLIDE moved=%.1f flow_gain=%.1f" % [moved, flow_gain])
	var ok: bool = _formula_ok and _flow_ok and collide_ok
	print("IMPACT_VERDICT %s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)
