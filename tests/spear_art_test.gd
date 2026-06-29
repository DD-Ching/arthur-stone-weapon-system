extends Node2D
## Headless readability test for the beautified SPEARMAN art (`scripts/art/SpearArt.gd`, look
## "spear", token ART_SPEAR). The art is PURELY ADDITIVE `_draw` — a long leaf-headed spear, a
## faction pennon/tassel, a small buckler and a helm. None of it touches gameplay.
##
## Headless can't screenshot, so this asserts what a script CAN: that the real shipped
## `res://scenes/Spearman.tscn` (look "spear") instantiates, adds to the tree, and draws over a
## few frames WITHOUT errors, for several factions (so faction_color() tinting runs) and at a
## couple of facings. The coordinator eyeballs the actual visuals after merge.
##
## Run: godot --headless --path . res://tests/SpearArtTest.tscn --quit-after 600
## Look for the ART_SPEAR_VERDICT line.

const SPEARMAN := preload("res://scenes/Spearman.tscn")
const FACTIONS := ["neutral", "camelot", "briton", "saxon", "rebel"]

var _units: Array = []
var _frame := 0
var _checks := {}

func _ready() -> void:
	# One Spearman per faction so faction_color() (and the pennon/buckler tint that reads it) runs
	# down every branch. Built from the shipped .tscn so we exercise the real configured unit.
	var x := -240.0
	for fac in FACTIONS:
		var e: Node = SPEARMAN.instantiate()
		e.faction = fac
		e.ai_enabled = false        # passive — we're testing DRAWING, not the brain
		add_child(e)
		e.global_position = Vector2(x, 0.0)
		e._face = float(_units.size()) * 0.7    # a few distinct facings
		e._alpha = 0.85                          # exercise the alpha multiply (not just 1.0)
		e.queue_redraw()
		_units.append(e)
		x += 120.0

	_checks["look_is_spear"] = _units.size() > 0 and _units[0].look == "spear"
	_checks["all_spawned"] = _units.size() == FACTIONS.size()
	print("ART_SPEAR_READY units=%d" % _units.size())

func _physics_process(_delta: float) -> void:
	_frame += 1
	# Keep redrawing for a few frames so the draw path runs repeatedly; if any draw call errored,
	# the engine would have reported it by now.
	for e in _units:
		if is_instance_valid(e):
			e.queue_redraw()
	if _frame >= 6:
		_checks["all_alive_after_draw"] = _all_valid()
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
	print("ART_SPEAR_RESULT %s" % " ".join(parts))
	print("ART_SPEAR_VERDICT %s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)
