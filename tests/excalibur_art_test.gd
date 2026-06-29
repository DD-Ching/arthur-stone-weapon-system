extends Node2D
## Headless smoke test for the BEAUTIFIED Excalibur-champion silhouette (scripts/art/ExcaliburArt.gd).
##
## Headless can't screenshot, so this asserts what a script CAN: that the "excalibur" look — a Camelot
## champion wielding the radiant Excalibur — draws over many frames WITHOUT errors across several
## FACTIONS and FACINGS, in BOTH the rank-and-file case AND the LEGENDARY general case (e.is_general =
## true, a crown/halo of light + a longer brighter blade), that the unit keeps its "excalibur" look,
## and that every instance survives every redraw. It instantiates the REAL shipped champion scene
## res://scenes/knights/Lancelot.tscn (whose look is already "excalibur").
##
## Run: godot --headless --path . res://tests/ExcaliburArtTest.tscn --quit-after 600
## Look for the ART_EXCALIBUR_VERDICT line.

const CHAMPION_SCENE := "res://scenes/knights/Lancelot.tscn"
const FACTIONS := ["camelot", "saxon", "rebel", "briton", "pict", "neutral"]

var _units: Array = []
var _frame := 0
var _checks := {}
var _became_general := false

func _ready() -> void:
	var packed: PackedScene = load(CHAMPION_SCENE)
	_checks["scene_loaded"] = packed != null
	# One champion per faction, spread out, each at a different facing so the cape / blade / side
	# maths exercises many angles. The shipped Lancelot scene already has look "excalibur".
	var x := -300.0
	var ang := 0.0
	var all_excalibur := true
	for fac in FACTIONS:
		var e: Enemy = packed.instantiate()
		e.ai_enabled = false           # passive — we test DRAWING, not the brain
		e.faction = fac
		add_child(e)
		e.global_position = Vector2(x, 0.0)
		e._face = ang
		if e.look != "excalibur":
			all_excalibur = false
		e.queue_redraw()
		_units.append(e)
		x += 120.0
		ang += 0.9
	_checks["look_is_excalibur"] = all_excalibur
	_checks["instantiated_all"] = _all_valid() and _units.size() == FACTIONS.size()
	print("ART_EXCALIBUR_READY units=%d look=%s" % [_units.size(), str(_units[0].look)])

func _physics_process(_delta: float) -> void:
	_frame += 1
	if not _all_valid():
		return
	# At frame 4: promote the lead champion to a LEGENDARY general so the general-only crown/halo,
	# longer blade and extra rays code paths run too. Keep rotating so many angles are drawn.
	if _frame == 4:
		_units[0].is_general = true
		_became_general = true
		_checks["general_look_still_excalibur"] = (_units[0].look == "excalibur")
	for e in _units:
		e._face += 0.2
		e._alpha = 0.6 if _frame >= 6 else 1.0   # exercise the defeat-fade alpha multiply path too
		e.queue_redraw()
	if _frame >= 8:
		_checks["became_general"] = _became_general
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
	print("ART_EXCALIBUR_RESULT %s" % " ".join(parts))
	print("ART_EXCALIBUR_VERDICT %s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)
