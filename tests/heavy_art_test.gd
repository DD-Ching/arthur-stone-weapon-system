extends Node2D
## Headless smoke test for the HEAVY BRUISER art beautification (scripts/art/HeavyArt.gd).
## The additions are PURELY ADDITIVE `_draw` (a bulky body ring, broad pauldrons, a great-helm,
## and a hauled maul — plus a grander general variant with horns, plume, and a faction war-cloak).
## None of it touches gameplay.
##
## Headless can't screenshot, so this asserts what a script CAN: that the shipped HeavyGuard scene
## (a "heavy" look) draws over a few frames WITHOUT errors as a normal unit AND as a general
## (is_general = true → the grander code path), across every faction (so the cloak/plume colours
## all draw), and that the unit survives every redraw (a draw-call crash would free / error it).
##
## Run: godot --headless --path . res://tests/HeavyArtTest.tscn --quit-after 600
## Look for the ART_HEAVY_VERDICT line.

const HEAVY_SCENE := "res://scenes/HeavyGuard.tscn"
const FACTIONS := ["neutral", "wei", "shu", "wu"]

var _units: Array = []
var _frame := 0
var _checks := {}
var _phase_general := false

func _ready() -> void:
	# Instantiate the SHIPPED HeavyGuard.tscn (look == "heavy") so we test the real configured unit,
	# not a hand-rolled stand-in. One per faction, plus a couple of facings, so the cloak/plume
	# faction colours and the directional maul/pauldrons all exercise their draw paths.
	var heavy_packed: PackedScene = load(HEAVY_SCENE)
	_checks["scene_loaded"] = heavy_packed != null

	var x := -300.0
	for fac in FACTIONS:
		var e = heavy_packed.instantiate()
		e.ai_enabled = false        # passive — we're testing DRAWING, not the brain
		e.faction = fac
		add_child(e)
		e.global_position = Vector2(x, 0.0)
		e._face = 0.6               # an off-axis facing so side/fwd geometry is non-degenerate
		e.queue_redraw()
		_units.append(e)
		x += 130.0

	# Confirm the shipped unit really reads as "heavy" (the look HeavyArt draws), so this test would
	# catch the scene drifting off the heavy look.
	var look_ok := true
	for e in _units:
		if e.look != "heavy":
			look_ok = false
	_checks["units_are_heavy"] = look_ok and _units.size() == FACTIONS.size()

	print("ART_HEAVY_READY units=%d" % _units.size())

func _physics_process(_delta: float) -> void:
	_frame += 1
	# Phase 1 (frames 1..5): draw as NORMAL heavies. Phase 2 (frames 6+): flip every unit to a
	# GENERAL and redraw so the grander branch (horns / plume / war-cloak) runs too.
	if _frame == 6 and not _phase_general:
		_phase_general = true
		for e in _units:
			if is_instance_valid(e):
				e.is_general = true
		_checks["normal_phase_alive"] = _all_valid()

	for e in _units:
		if is_instance_valid(e):
			e.queue_redraw()

	if _frame >= 12:
		_checks["general_phase_alive"] = _all_valid()
		_checks["units_exist"] = _units.size() > 0 and _all_valid()
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
	print("ART_HEAVY_RESULT %s" % " ".join(parts))
	print("ART_HEAVY_VERDICT %s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)
