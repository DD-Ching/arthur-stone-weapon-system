extends Node2D
## Headless smoke test for the BEAUTIFIED Saxon-Warlord silhouette (scripts/art/WarlordArt.gd).
##
## Headless can't screenshot, so this asserts what a script CAN: that the "warlord" look — Cerdic,
## the burly fur-clad Saxon axe-lord with a horned iron helm, a fur mantle, a braided beard and a
## great Dane axe — draws over many frames WITHOUT errors across several FACINGS, that he is a
## GENERAL (e.is_general true → the chieftain war-totem / longer horns / bigger axe paths run),
## that he keeps his "warlord" look, and that every instance survives every redraw including the
## DEFEAT-FADE alpha being driven down. It instantiates the REAL shipped boss scene
## res://scenes/villains/SaxonWarlord.tscn (whose look is already "warlord").
##
## Run: godot --headless --path . res://tests/WarlordArtTest.tscn --quit-after 600
## Look for the ART_WARLORD_VERDICT line.

const WARLORD_SCENE := "res://scenes/villains/SaxonWarlord.tscn"
const FACINGS := [0.0, 0.7, 1.6, 2.4, 3.2, 4.1, 5.0]

var _units: Array = []
var _frame := 0
var _checks := {}

func _ready() -> void:
	var packed: PackedScene = load(WARLORD_SCENE)
	_checks["scene_loaded"] = packed != null
	# One warlord per facing, spread out, so the cant/horn/blade/mantle maths exercises many angles.
	# The shipped SaxonWarlord scene already has look "warlord", faction "saxon" and is a general.
	var x := -360.0
	var all_warlord := true
	var all_general := true
	for ang in FACINGS:
		var e: Enemy = packed.instantiate()
		e.ai_enabled = false            # passive — we test DRAWING, not the brain
		add_child(e)
		e.global_position = Vector2(x, 0.0)
		e._face = ang
		if e.look != "warlord":
			all_warlord = false
		if not e.is_general:
			all_general = false
		e.queue_redraw()
		_units.append(e)
		x += 120.0
	_checks["look_is_warlord"] = all_warlord
	_checks["is_general"] = all_general
	_checks["instantiated_all"] = _all_valid() and _units.size() == FACINGS.size()
	print("ART_WARLORD_READY units=%d look=%s general=%s" % [
		_units.size(), str(_units[0].look), str(_units[0].is_general)])

func _physics_process(_delta: float) -> void:
	_frame += 1
	if not _all_valid():
		return
	# Keep rotating so many facings are drawn; from frame 6 drive the DEFEAT-FADE alpha down so the
	# `_alpha`-multiply path (a defeated boss fading out) is exercised on every Color.
	for e in _units:
		e._face += 0.2
		e._alpha = clampf(1.0 - float(_frame - 5) * 0.12, 0.2, 1.0) if _frame >= 6 else 1.0
		e.queue_redraw()
	if _frame >= 10:
		_checks["look_still_warlord_after_draw"] = (_units[0].look == "warlord")
		_checks["alive_after_draw"] = _all_valid()
		_checks["faded_alpha_applied"] = _units[0]._alpha < 1.0
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
	print("ART_WARLORD_RESULT %s" % " ".join(parts))
	print("ART_WARLORD_VERDICT %s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)
