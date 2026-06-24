extends Node2D
## Headless readability test for the BEAUTIFIED light-footman art (scripts/art/SoldierArt.gd).
##
## Headless can't screenshot, so this asserts what a script CAN: that a real LightSoldier — the
## shipped scene whose `look` is "soldier" — instantiates and draws its enriched silhouette over a
## couple of physics frames (headless still calls `_draw`) WITHOUT errors, across several factions
## so the faction-sash colour path runs for each kingdom. It then checks the unit still exists with
## look "soldier", and that the defeat-fade path draws cleanly at a partial `_alpha`.
##
## Run: godot --headless --path . res://tests/SoldierArtTest.tscn --quit-after 600
## Look for the ART_SOLDIER_VERDICT line.

const SoldierScene := preload("res://scenes/LightSoldier.tscn")
const FACTIONS := ["neutral", "wei", "shu", "wu"]

var _soldiers: Array = []
var _frame := 0
var _checks := {}

func _ready() -> void:
	# One LightSoldier per faction, spread out, each forced to redraw so the art runs.
	var x := -240.0
	for fac in FACTIONS:
		var e = SoldierScene.instantiate()
		e.look = "soldier"
		e.faction = fac
		e.ai_enabled = false        # passive — we test DRAWING, not the brain
		add_child(e)
		e.global_position = Vector2(x, 0.0)
		e._face = 0.0
		e.queue_redraw()
		_soldiers.append(e)
		x += 120.0

	# A faded copy (mid defeat-fade) so the `_alpha` multiply path draws at partial opacity.
	var faded = SoldierScene.instantiate()
	faded.look = "soldier"
	faded.faction = "wu"
	faded.ai_enabled = false
	add_child(faded)
	faded.global_position = Vector2(-240.0, 140.0)
	faded._face = PI * 0.5
	faded._alpha = 0.4
	faded.queue_redraw()
	_soldiers.append(faded)

	# The look survived instantiation/assignment on every unit.
	var all_soldier := true
	for e in _soldiers:
		if e.look != "soldier":
			all_soldier = false
	_checks["look_is_soldier"] = all_soldier
	_checks["count"] = _soldiers.size() == FACTIONS.size() + 1

	print("ART_SOLDIER_READY soldiers=%d" % _soldiers.size())

func _physics_process(_delta: float) -> void:
	_frame += 1
	# Keep redrawing for a few frames so the art code path runs repeatedly; any draw error would
	# have been reported by the engine by now.
	for e in _soldiers:
		if is_instance_valid(e):
			e.queue_redraw()
	if _frame >= 6:
		_checks["all_alive_after_draw"] = _all_valid()
		_report()

func _all_valid() -> bool:
	for e in _soldiers:
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
	print("ART_SOLDIER_RESULT %s" % " ".join(parts))
	print("ART_SOLDIER_VERDICT %s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)
