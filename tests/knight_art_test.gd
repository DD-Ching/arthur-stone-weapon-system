extends Node2D
## Headless smoke test for the BEAUTIFIED elite-knight silhouette (KnightArt.gd).
##
## Headless can't screenshot, so this asserts what a script CAN: that the knight `look` draws
## over several frames WITHOUT errors in BOTH the rank-and-file case AND the LEGENDARY general
## case (e.is_general = true, a faction cape/halo), that the unit keeps its "knight" look, and
## that the instance survives every redraw. It instantiates the real res://scenes/LightSoldier.tscn
## and flips its `look` to "knight" (no shipped .tscn selects "knight", so we drive it directly).
##
## Run: godot --headless --path . res://tests/KnightArtTest.tscn --quit-after 600
## Look for the ART_KNIGHT_VERDICT line.

const KNIGHT_SCENE := "res://scenes/LightSoldier.tscn"

var _e: Enemy
var _frame := 0
var _checks := {}
var _became_general := false

func _ready() -> void:
	var packed: PackedScene = load(KNIGHT_SCENE)
	var e: Enemy = packed.instantiate()
	e.look = "knight"
	e.ai_enabled = false        # passive — we test DRAWING, not the brain
	add_child(e)
	e.global_position = Vector2.ZERO
	e._face = 0.0
	_e = e
	_checks["instantiated"] = is_instance_valid(_e)
	_checks["look_is_knight"] = (_e.look == "knight")
	_e.queue_redraw()
	print("ART_KNIGHT_READY look=%s general=%s" % [str(_e.look), str(_e.is_general)])

func _physics_process(_delta: float) -> void:
	_frame += 1
	if not is_instance_valid(_e):
		return
	# Frames 1..3: draw the ordinary elite knight. At frame 4: promote to a LEGENDARY general with
	# a faction (Saxon) and keep redrawing so the general-only halo/cape/sunburst code paths run too.
	if _frame == 4:
		_e.is_general = true
		_e.faction = "saxon"
		_became_general = true
		_checks["general_look_still_knight"] = (_e.look == "knight")
	_e._face += 0.2            # rotate so the cape/blade/side maths exercise many angles
	_e.queue_redraw()
	if _frame >= 8:
		_checks["became_general"] = _became_general
		_checks["alive_after_draw"] = is_instance_valid(_e)
		_report()

func _report() -> void:
	var ok := true
	var parts: PackedStringArray = PackedStringArray()
	for k in _checks.keys():
		parts.append("%s=%s" % [k, str(_checks[k])])
		if not _checks[k]:
			ok = false
	print("ART_KNIGHT_RESULT %s" % " ".join(parts))
	print("ART_KNIGHT_VERDICT %s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)
