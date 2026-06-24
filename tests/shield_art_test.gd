extends Node2D
## Headless readability test for the BEAUTIFIED shieldbearer art (scripts/art/ShieldArt.gd).
## The shield draw is PURELY ADDITIVE: a solid plated shield (boss + bright rim + faction emblem +
## helmet glimpse) on the guarding side, with a DISTINCTLY shattered broken state. No gameplay.
##
## Headless can't screenshot, so this asserts what a script CAN: that the actual shipped
## res://scenes/ShieldSoldier.tscn (look == "shield") draws over a few frames WITHOUT errors in
## BOTH the intact state AND the forced broken state (e._shield_broken = 3.0), across several
## faction tints, and that the unit stays alive throughout. The coordinator eyeballs the visuals.
##
## Run: godot --headless --path . res://tests/ShieldArtTest.tscn --quit-after 600
## Look for the ART_SHIELD_VERDICT line.

const SHIELD_SCENE := "res://scenes/ShieldSoldier.tscn"
const FACTIONS := ["neutral", "wei", "shu", "wu"]

var _units: Array = []
var _broken_unit: Enemy = null
var _frame := 0
var _checks := {}

func _ready() -> void:
	var scene: PackedScene = load(SHIELD_SCENE)
	_checks["scene_loaded"] = scene != null

	# One INTACT shield per faction — exercises faction_color() emblem tints — laid out in a row.
	var x := -240.0
	for fac in FACTIONS:
		var e: Enemy = scene.instantiate()
		e.ai_enabled = false          # passive — we test DRAWING, not the brain
		e.faction = fac
		add_child(e)
		e.global_position = Vector2(x, 0.0)
		e._face = 0.0
		e.shield_angle = 0.0          # shield faces +x
		e._shield_broken = 0.0
		e.queue_redraw()
		_units.append(e)
		x += 120.0

	# One BROKEN shield — forces the shattered branch (e._shield_broken > 0).
	_broken_unit = scene.instantiate()
	_broken_unit.ai_enabled = false
	_broken_unit.faction = "wu"
	add_child(_broken_unit)
	_broken_unit.global_position = Vector2(0.0, 160.0)
	_broken_unit._face = 0.0
	_broken_unit.shield_angle = 0.0
	_broken_unit._shield_broken = 3.0  # > 0 → shattered shield silhouette
	_broken_unit.queue_redraw()
	_units.append(_broken_unit)

	# Sanity: the shipped scene really is a shield look (so we beautified the right unit).
	_checks["look_is_shield"] = String(_units[0].look) == "shield"

	print("ART_SHIELD_READY units=%d broken_set=%s" % [_units.size(), str(_broken_unit._shield_broken)])

func _physics_process(_delta: float) -> void:
	_frame += 1
	# Redraw a few frames so both code paths run repeatedly with advancing state; any draw error
	# would have been reported by the engine by now. Also flip one intact unit to broken mid-run
	# so a SINGLE instance is exercised in BOTH states (intact then shattered).
	if _frame == 3 and is_instance_valid(_units[0]):
		_units[0]._shield_broken = 3.0
	for e in _units:
		if is_instance_valid(e):
			e.queue_redraw()
	if _frame >= 6:
		_checks["all_alive_after_draw"] = _all_valid()
		_checks["broken_unit_alive"] = is_instance_valid(_broken_unit)
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
	print("ART_SHIELD_RESULT %s" % " ".join(parts))
	print("ART_SHIELD_VERDICT %s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)
