extends Node2D
## Headless smoke test for the BEAUTIFIED Mordred silhouette (scripts/art/MordredArt.gd).
##
## Headless can't screenshot, so this asserts what a script CAN: that the "mordred" look — the
## traitor prince, a fallen Camelot champion in rebel black-purple with a broken crown, a rebel
## cape, a cruel violet-edged blade and an aura of treachery — draws over many FRAMES and FACINGS
## WITHOUT errors, in BOTH the rank-and-file path AND the LEGENDARY general path (e.is_general),
## that the unit keeps its "mordred" look, and that every instance survives every redraw including
## while the DEFEAT-FADE alpha drives down toward 0. It instantiates the REAL shipped final-boss
## scene res://scenes/villains/Mordred.tscn (whose look is already "mordred", is_general = true).
##
## Run: godot --headless --path . res://tests/MordredArtTest.tscn --quit-after 600
## Look for the ART_MORDRED_VERDICT line.

const MORDRED_SCENE := "res://scenes/villains/Mordred.tscn"
const FACINGS := [0.0, 0.9, 1.8, 2.7, 3.6, 4.5, 5.4]

var _units: Array = []
var _frame := 0
var _checks := {}
var _demoted_general := false

func _ready() -> void:
	var packed: PackedScene = load(MORDRED_SCENE)
	_checks["scene_loaded"] = packed != null
	# One Mordred per facing, spread out, so the cape / blade / crown / side maths exercises many
	# angles. The shipped Mordred scene already has look "mordred" and is_general = true.
	var x := -360.0
	var all_mordred := true
	var all_general := true
	for ang in FACINGS:
		var e: Enemy = packed.instantiate()
		e.ai_enabled = false           # passive — we test DRAWING, not the brain
		add_child(e)
		e.global_position = Vector2(x, 0.0)
		e._face = ang
		if e.look != "mordred":
			all_mordred = false
		if not e.is_general:
			all_general = false
		e.queue_redraw()
		_units.append(e)
		x += 120.0
	_checks["look_is_mordred"] = all_mordred
	_checks["is_general"] = all_general
	_checks["instantiated_all"] = _all_valid() and _units.size() == FACINGS.size()
	print("ART_MORDRED_READY units=%d look=%s general=%s" % [
		_units.size(), str(_units[0].look), str(_units[0].is_general)])

func _physics_process(_delta: float) -> void:
	_frame += 1
	if not _all_valid():
		return
	# At frame 4: demote the LAST unit to a rank-and-file (non-general) so the NON-general code path
	# (shorter blade, no shadow-spikes, plainer crown) runs too — the scene is general by default.
	if _frame == 4:
		_units[-1].is_general = false
		_demoted_general = true
		_checks["nongeneral_look_still_mordred"] = (_units[-1].look == "mordred")
	for e in _units:
		e._face += 0.2
		# Drive the DEFEAT-FADE alpha down toward 0 so the alpha-multiply + early-out path both run.
		e._alpha = max(0.0, 1.0 - 0.12 * float(_frame))
		e.queue_redraw()
	if _frame >= 9:
		_checks["demoted_one"] = _demoted_general
		_checks["look_still_mordred_after_fade"] = (_units[0].look == "mordred")
		_checks["alive_after_draw"] = _all_valid()
		_report()

func _all_valid() -> bool:
	for e in _units:
		if not is_instance_valid(e):
			return false
	return true

func _report() -> void:
	var ok := true
	var parts: PackedStringArray = PackedStringArray()
	for k in _checks.keys():
		parts.append("%s=%s" % [k, str(_checks[k])])
		if not _checks[k]:
			ok = false
	print("ART_MORDRED_RESULT %s" % " ".join(parts))
	print("ART_MORDRED_VERDICT %s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)
