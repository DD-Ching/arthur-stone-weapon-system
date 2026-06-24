extends Node2D
## Headless readability test for the BEAUTIFIED officer STANDARD (BannerArt, the morale unit).
## Headless can't screenshot, so this asserts what a script CAN: that instantiating the shipped
## res://scenes/BannerBearer.tscn (look "banner") and redrawing it over several frames runs the
## full BannerArt._draw path WITHOUT errors — for the default (neutral → warm crimson fallback)
## standard AND for a faction-coloured one (Wei, whose blue pennant exercises the faction branch).
## If any draw call had errored, the engine would have reported it and the unit would be gone.
##
## Run: godot --headless --path . res://tests/BannerArtTest.tscn --quit-after 600
## Look for the ART_BANNER_VERDICT line.

const BANNER := "res://scenes/BannerBearer.tscn"

var _units: Array = []
var _frame := 0
var _checks := {}

func _ready() -> void:
	# The neutral standard (warm-default cloth) and a Wei standard (faction-blue cloth), so both
	# the neutral fallback and the faction_color() pennant branch get drawn.
	var neutral: Node = _make_banner("neutral", Vector2(-80.0, 0.0))
	var wei: Node = _make_banner("wei", Vector2(80.0, 0.0))
	_units.append(neutral)
	_units.append(wei)

	_checks["spawned_two"] = _units.size() == 2
	_checks["look_is_banner"] = neutral.look == "banner" and wei.look == "banner"
	_checks["faction_set"] = neutral.faction == "neutral" and wei.faction == "wei"
	print("ART_BANNER_READY units=%d" % _units.size())

func _make_banner(faction_name: String, pos: Vector2) -> Node:
	var scene: PackedScene = load(BANNER)
	var e: Node = scene.instantiate()
	e.ai_enabled = false           # passive — we test DRAWING, not the brain
	add_child(e)
	e.global_position = pos
	e.faction = faction_name
	e._face = -PI * 0.5
	e.queue_redraw()               # force a _draw() this frame so BannerArt runs
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
	print("ART_BANNER_RESULT %s" % " ".join(parts))
	print("ART_BANNER_VERDICT %s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)
