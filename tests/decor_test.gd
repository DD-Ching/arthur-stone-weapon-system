extends Node2D
## Headless test for the DECOR props unit (token DECOR) — faction banners & battlefield decor.
##
## These are pure code-drawn, web-safe atmosphere props maps can place. The test proves each
## scene instantiates, joins the tree, draws a couple of frames without error, and configures
## correctly:
##   - FactionBanner: banner_color() reads the house — briton blue-ish, saxon green-ish, rebel
##     purple-ish; each is on the "decor" group,
##   - Brazier / WarDrum: instantiate and tick cleanly (WarDrum's accent also tracks its faction),
##   - GatePost: a StaticBody2D on the "world" layer (collision_layer bit 1) with a CollisionShape2D.
##
## Modeled on tests/formations_test.gd + tests/terrain_scenes_test.gd.
## Run: godot --headless --path . res://tests/DecorTest.tscn --quit-after 600

const FACTION_BANNER := preload("res://scenes/decor/FactionBanner.tscn")
const BRAZIER := preload("res://scenes/decor/Brazier.tscn")
const GATE_POST := preload("res://scenes/decor/GatePost.tscn")
const WAR_DRUM := preload("res://scenes/decor/WarDrum.tscn")

const WORLD_LAYER := 1   # bit for 2d_physics/layer_1 "world"

var _briton: FactionBanner
var _saxon: FactionBanner
var _rebel: FactionBanner
var _neutral: FactionBanner
var _brazier: Brazier
var _drum: WarDrum
var _gate: GatePost
var _frame := 0

func _ready() -> void:
	# One banner per house so we can check the colour table.
	_briton = _make_banner("briton", Vector2(-200, 0))
	_saxon = _make_banner("saxon", Vector2(-100, 0))
	_rebel = _make_banner("rebel", Vector2(0, 0))
	_neutral = _make_banner("neutral", Vector2(100, 0))

	_brazier = BRAZIER.instantiate()
	_brazier.position = Vector2(-200, 120)
	add_child(_brazier)

	_drum = WAR_DRUM.instantiate()
	_drum.faction = "rebel"
	_drum.position = Vector2(-100, 120)
	add_child(_drum)

	_gate = GATE_POST.instantiate()
	_gate.position = Vector2(0, 120)
	add_child(_gate)

	print("DECOR_READY ok")

func _make_banner(fac: String, pos: Vector2) -> FactionBanner:
	var b: FactionBanner = FACTION_BANNER.instantiate()
	b.faction = fac
	b.position = pos
	add_child(b)
	return b

func _process(_delta: float) -> void:
	_frame += 1
	if _frame >= 4:
		_report()

func _report() -> void:
	# Banner colour table: each house's channel should dominate the way Enemy.faction_color does.
	var briton := _briton.banner_color()
	var saxon := _saxon.banner_color()
	var rebel := _rebel.banner_color()
	var neu := _neutral.banner_color()
	var briton_ok: bool = briton.b > briton.r and briton.b > briton.g     # blue dominant
	var saxon_ok: bool = saxon.g > saxon.r and saxon.g > saxon.b          # green dominant
	var rebel_ok: bool = rebel.r > rebel.g and rebel.b > rebel.g          # purple (red+blue > green)
	var neu_ok: bool = absf(neu.r - neu.g) < 0.1 and absf(neu.g - neu.b) < 0.1   # grey-ish
	var banners_grouped: bool = _briton.is_in_group("decor") and _saxon.is_in_group("decor") \
		and _rebel.is_in_group("decor") and _neutral.is_in_group("decor")
	var banner_ok: bool = briton_ok and saxon_ok and rebel_ok and neu_ok and banners_grouped

	# WarDrum accent mirrors its faction (rebel → purple: red+blue dominate green) and joins decor.
	var drum_accent := _drum.accent_color()
	var drum_ok: bool = _drum.is_in_group("decor") and drum_accent.r > drum_accent.g \
		and drum_accent.b > drum_accent.g

	# Brazier just needs to exist, be decor, and have ticked without error.
	var brazier_ok: bool = is_instance_valid(_brazier) and _brazier.is_in_group("decor")

	# GatePost: a solid StaticBody2D on the world layer with a rectangle collision shape.
	var gate_is_static: bool = _gate is StaticBody2D
	var gate_on_world: bool = (_gate.collision_layer & WORLD_LAYER) != 0
	var gate_has_shape := false
	for c in _gate.get_children():
		if c is CollisionShape2D and c.shape is RectangleShape2D:
			gate_has_shape = true
			break
	var gate_ok: bool = gate_is_static and gate_on_world and gate_has_shape

	print("DECOR_RESULT briton=%s saxon=%s rebel=%s neutral=%s grouped=%s | drum_ok=%s brazier_ok=%s | gate_static=%s gate_world=%s gate_shape=%s"
		% [str(briton_ok), str(saxon_ok), str(rebel_ok), str(neu_ok), str(banners_grouped),
			str(drum_ok), str(brazier_ok),
			str(gate_is_static), str(gate_on_world), str(gate_has_shape)])
	var ok: bool = banner_ok and drum_ok and brazier_ok and gate_ok
	print("DECOR_VERDICT %s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)
