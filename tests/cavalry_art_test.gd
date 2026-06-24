extends Node2D
## Headless readability test for the BEAUTIFIED mounted units — the Cavalry (warhorse + rider)
## and the WarCart (wheeled chariot). Both override Enemy._draw_type() with their own mounted
## draw; this asserts that drawing them (across factions, over a couple of frames) runs WITHOUT
## errors and leaves the bodies intact. Purely visual — no gameplay change.
##
## Headless can't screenshot, so this asserts what a script CAN: that we can instantiate the real
## scenes, add them to the tree, force a redraw, step a few physics frames, and find both alive and
## crash-free. We also spin one of each through the three kingdoms so faction_color() (used by the
## caparison / banner / pennon) is exercised on every hue.
##
## Run: godot --headless --path . res://tests/CavalryArtTest.tscn --quit-after 600
## Look for the ART_CAVALRY_VERDICT line.

const CAVALRY := preload("res://scenes/Cavalry.tscn")
const WARCART := preload("res://scenes/WarCart.tscn")
const FACTIONS := ["neutral", "wei", "shu", "wu"]

var _units: Array = []
var _frame := 0
var _checks := {}

func _ready() -> void:
	var x := -300.0
	for fac in FACTIONS:
		var cav = CAVALRY.instantiate()
		cav.ai_enabled = false          # passive — we test DRAWING, not the charge brain
		add_child(cav)
		cav.global_position = Vector2(x, -80.0)
		cav.faction = fac
		cav._face = 0.0
		cav._alpha = 0.8                # exercise the alpha-fade multiply on every colour
		cav.queue_redraw()
		_units.append(cav)

		var cart = WARCART.instantiate()
		cart.ai_enabled = false
		add_child(cart)
		cart.global_position = Vector2(x, 80.0)
		cart.faction = fac
		cart._face = 0.0
		cart._alpha = 0.8
		cart.queue_redraw()
		_units.append(cart)

		x += 160.0

	_checks["instantiated_both"] = _units.size() == FACTIONS.size() * 2
	# Both scenes resolved to their intended scripts (Cavalry / WarCart-extends-Cavalry).
	_checks["cavalry_is_cavalry"] = _units[0] is Cavalry
	_checks["warcart_is_warcart"] = _units[1] is WarCart and _units[1] is Cavalry

	print("ART_CAVALRY_READY units=%d" % _units.size())

func _physics_process(_delta: float) -> void:
	_frame += 1
	for u in _units:
		if is_instance_valid(u):
			u.queue_redraw()        # keep every draw path running with advancing _t
	if _frame >= 6:
		_checks["all_alive_after_draw"] = _all_valid()
		_report()

func _all_valid() -> bool:
	for u in _units:
		if not is_instance_valid(u):
			return false
	return true

func _report() -> void:
	var ok := true
	var parts: PackedStringArray = PackedStringArray()
	for k in _checks.keys():
		parts.append("%s=%s" % [k, str(_checks[k])])
		if not _checks[k]:
			ok = false
	print("ART_CAVALRY_RESULT %s" % " ".join(parts))
	print("ART_CAVALRY_VERDICT %s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)
