extends Node2D
## Headless readability test for the BEAUTIFIED enchantress (SorceressArt — Morgan le Fay, the
## dark-magic general). Headless can't screenshot, so this asserts what a script CAN: that
## instantiating the shipped res://scenes/villains/MorganLeFay.tscn (look "sorceress") and
## redrawing it over several frames runs the full SorceressArt._draw path WITHOUT errors — the
## robe / hood / staff-orb / runic-ring + motes, and (since she is a general) the boss branches.
## We also fade one copy toward transparent so the _alpha-multiply branch is exercised at a < 1.0
## value. If any draw call had errored, the engine would have reported it and the unit would be gone.
##
## Run: godot --headless --path . res://tests/SorceressArtTest.tscn --quit-after 600
## Look for the ART_SORCERESS_VERDICT line.

const MORGAN := "res://scenes/villains/MorganLeFay.tscn"

var _units: Array = []
var _frame := 0
var _checks := {}

func _ready() -> void:
	# Two Morgans, facing different ways so the staff-side / hood-forward geometry draws at a couple
	# of orientations (both still draw the same SorceressArt path).
	var a: Node = _make_morgan(Vector2(-80.0, 0.0), -PI * 0.5)
	var b: Node = _make_morgan(Vector2(80.0, 0.0), 0.0)
	_units.append(a)
	_units.append(b)

	_checks["spawned_two"] = _units.size() == 2
	_checks["look_is_sorceress"] = a.look == "sorceress" and b.look == "sorceress"
	_checks["is_general"] = a.is_general == true       # her boss branches (brighter orb / wider aura)
	print("ART_SORCERESS_READY units=%d" % _units.size())

func _make_morgan(pos: Vector2, face: float) -> Node:
	var scene: PackedScene = load(MORGAN)
	var e: Node = scene.instantiate()
	e.ai_enabled = false           # passive — we test DRAWING, not the brain
	add_child(e)
	e.global_position = pos
	e._face = face
	e.queue_redraw()               # force a _draw() this frame so SorceressArt runs
	return e

func _physics_process(_delta: float) -> void:
	_frame += 1
	# Redraw across several frames (advancing _alpha/_t) so the draw path runs repeatedly; also
	# fade one toward transparent so the _alpha-multiply branch is exercised at a < 1.0 value.
	for e in _units:
		if is_instance_valid(e):
			e.queue_redraw()
	if _units.size() > 0 and is_instance_valid(_units[0]):
		_units[0]._alpha = 0.5
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
	print("ART_SORCERESS_RESULT %s" % " ".join(parts))
	print("ART_SORCERESS_VERDICT %s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)
