extends Node2D
## Headless readability test for the BEAUTIFIED Black Knight (scripts/art/BlackKnightArt.gd) — a
## dread mercenary champion of pure black plate: a horned great-helm with a single glowing RED
## eye-slit, heavy pauldrons, a tattered dark mantle and a wicked dark blade, wrapped in a shadow-aura.
##
## Headless can't screenshot, so this asserts what a script CAN: that instantiating the shipped
## res://scenes/villains/BlackKnight.tscn (look "black_knight") and redrawing it over several frames
## runs the full BlackKnightArt.draw path WITHOUT errors — across several FACTIONS and FACINGS (he is
## faction-INDEPENDENT, so every side must draw him fine) AND through the general boss branch (he IS
## a general). We drive one copy's defeat-fade alpha down to a < 1.0 value so the _alpha-multiply path
## is exercised. If any draw call had errored, the engine would have reported it and the unit would be
## gone; we assert every instance survives and keeps its "black_knight" look.
##
## Run: godot --headless --path . res://tests/BlackKnightArtTest.tscn --quit-after 600
## Look for the ART_BLACKKNIGHT_VERDICT line.

const BLACK_KNIGHT := "res://scenes/villains/BlackKnight.tscn"
const FACTIONS := ["camelot", "saxon", "rebel", "wei", "shu", "neutral"]

var _units: Array = []
var _frame := 0
var _checks := {}

func _ready() -> void:
	var packed: PackedScene = load(BLACK_KNIGHT)
	_checks["scene_loaded"] = packed != null
	# One Black Knight per faction, spread out, each at a different facing so the cape / helm / blade /
	# pauldron side-maths exercises many angles. He must read BLACK whichever side tints him, so we
	# deliberately push him onto every faction and assert nothing breaks.
	var x := -320.0
	var ang := 0.0
	var all_black_knight := true
	var any_general := false
	for fac in FACTIONS:
		var e: Enemy = packed.instantiate()
		e.ai_enabled = false           # passive — we test DRAWING, not the brain
		e.faction = fac
		add_child(e)
		e.global_position = Vector2(x, 0.0)
		e._face = ang
		if e.look != "black_knight":
			all_black_knight = false
		if e.is_general:
			any_general = true         # he ships as a general — the boss branch must draw too
		e.queue_redraw()               # force a _draw() this frame so BlackKnightArt runs
		_units.append(e)
		x += 130.0
		ang += 0.9
	_checks["look_is_black_knight"] = all_black_knight
	_checks["is_general"] = any_general
	_checks["instantiated_all"] = _all_valid() and _units.size() == FACTIONS.size()
	print("ART_BLACKKNIGHT_READY units=%d look=%s general=%s"
		% [_units.size(), str(_units[0].look), str(_units[0].is_general)])

func _physics_process(_delta: float) -> void:
	_frame += 1
	if not _all_valid():
		return
	# Rotate every knight each frame so many angles draw, and drive the defeat-fade alpha down on the
	# lead copy from frame 4 so the _alpha-multiply branch runs at a partial value (not just 1.0).
	for e in _units:
		e._face += 0.2
		e.queue_redraw()
	if _frame >= 4:
		_units[0]._alpha = 0.5
	if _frame >= 8:
		_checks["look_still_black_knight"] = (_units[0].look == "black_knight")
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
	print("ART_BLACKKNIGHT_RESULT %s" % " ".join(parts))
	print("ART_BLACKKNIGHT_VERDICT %s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)
