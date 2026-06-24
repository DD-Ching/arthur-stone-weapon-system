extends Node2D
## Headless test for the DECOR props unit (token DECOR) — faction banners & battlefield decor.
##
## These are pure code-drawn, web-safe atmosphere props maps can place. The test proves each
## scene instantiates, joins the tree, draws a couple of frames without error, and configures
## correctly:
##   - FactionBanner: banner_color() reads the kingdom — wei blue-ish, shu green-ish, wu red-ish;
##     each is on the "decor" group,
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

var _wei: FactionBanner
var _shu: FactionBanner
var _wu: FactionBanner
var _neutral: FactionBanner
var _brazier: Brazier
var _drum: WarDrum
var _gate: GatePost
var _frame := 0

func _ready() -> void:
	# One banner per kingdom so we can check the colour table.
	_wei = _make_banner("wei", Vector2(-200, 0))
	_shu = _make_banner("shu", Vector2(-100, 0))
	_wu = _make_banner("wu", Vector2(0, 0))
	_neutral = _make_banner("neutral", Vector2(100, 0))

	_brazier = BRAZIER.instantiate()
	_brazier.position = Vector2(-200, 120)
	add_child(_brazier)

	_drum = WAR_DRUM.instantiate()
	_drum.faction = "wu"
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
	# Banner colour table: each kingdom's channel should dominate the way Enemy.faction_color does.
	var wei := _wei.banner_color()
	var shu := _shu.banner_color()
	var wu := _wu.banner_color()
	var neu := _neutral.banner_color()
	var wei_ok: bool = wei.b > wei.r and wei.b > wei.g            # blue dominant
	var shu_ok: bool = shu.g > shu.r and shu.g > shu.b            # green dominant
	var wu_ok: bool = wu.r > wu.g and wu.r > wu.b                 # red dominant
	var neu_ok: bool = absf(neu.r - neu.g) < 0.1 and absf(neu.g - neu.b) < 0.1   # grey-ish
	var banners_grouped: bool = _wei.is_in_group("decor") and _shu.is_in_group("decor") \
		and _wu.is_in_group("decor") and _neutral.is_in_group("decor")
	var banner_ok: bool = wei_ok and shu_ok and wu_ok and neu_ok and banners_grouped

	# WarDrum accent mirrors its faction (wu → red dominant) and joins the decor group.
	var drum_accent := _drum.accent_color()
	var drum_ok: bool = _drum.is_in_group("decor") and drum_accent.r > drum_accent.g \
		and drum_accent.r > drum_accent.b

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

	print("DECOR_RESULT wei=%s shu=%s wu=%s neutral=%s grouped=%s | drum_ok=%s brazier_ok=%s | gate_static=%s gate_world=%s gate_shape=%s"
		% [str(wei_ok), str(shu_ok), str(wu_ok), str(neu_ok), str(banners_grouped),
			str(drum_ok), str(brazier_ok),
			str(gate_is_static), str(gate_on_world), str(gate_has_shape)])
	var ok: bool = banner_ok and drum_ok and brazier_ok and gate_ok
	print("DECOR_VERDICT %s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)
