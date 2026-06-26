extends Node2D
## Headless test for the ARTHUR-DECOR props unit (token ARTHURDECOR) — Arthurian battlefield
## atmosphere props. Pure code-drawn, web-safe decor maps can place. The test proves each new
## scene instantiates, joins the tree, draws a couple of frames without error, and configures
## correctly:
##   - SwordInStone: the game's emblem — instantiates, joins the "decor" group, exposes a
##     greyish stone_color(), and ticks (its gleam) without error.
##   - RoundTable: joins "decor" and its gold_color() is gold (r > b and g > b), matching
##     Enemy.faction_color("camelot").
##   - CamelotBanner: banner_color() reads the kingdom — camelot gold (r>b, g>b), saxon
##     moss-green (g>r, g>b), rebel purple (b>g) — and each is on the "decor" group; the
##     Camelot blazon charge_color() is Pendragon red (r dominant).
##   - Torch: instantiates, joins "decor", and ticks (its flicker + halo) without error.
##
## Modeled on tests/decor_test.gd (the existing decor unit's test).
## Run: godot --headless --path . res://tests/ArthurDecorTest.tscn --quit-after 600

const SWORD_IN_STONE := preload("res://scenes/decor/SwordInStone.tscn")
const ROUND_TABLE := preload("res://scenes/decor/RoundTable.tscn")
const CAMELOT_BANNER := preload("res://scenes/decor/CamelotBanner.tscn")
const TORCH := preload("res://scenes/decor/Torch.tscn")

var _sword: SwordInStone
var _table: RoundTable
var _camelot: CamelotBanner
var _saxon: CamelotBanner
var _rebel: CamelotBanner
var _torch: Torch
var _frame := 0

func _ready() -> void:
	_sword = SWORD_IN_STONE.instantiate()
	_sword.position = Vector2(-200, 0)
	add_child(_sword)

	_table = ROUND_TABLE.instantiate()
	_table.position = Vector2(-80, 0)
	add_child(_table)

	# One Camelot banner per faction so we can check the colour table.
	_camelot = _make_banner("camelot", Vector2(40, 0))
	_saxon = _make_banner("saxon", Vector2(120, 0))
	_rebel = _make_banner("rebel", Vector2(200, 0))

	_torch = TORCH.instantiate()
	_torch.position = Vector2(0, 120)
	add_child(_torch)

	print("ARTHURDECOR_READY ok")

func _make_banner(fac: String, pos: Vector2) -> CamelotBanner:
	var b: CamelotBanner = CAMELOT_BANNER.instantiate()
	b.faction = fac
	b.position = pos
	add_child(b)
	return b

func _process(_delta: float) -> void:
	_frame += 1
	if _frame >= 4:
		_report()

func _report() -> void:
	# SwordInStone: alive, decor-grouped, and a greyish stone (channels close together).
	var stone := _sword.stone_color()
	var stone_grey: bool = absf(stone.r - stone.g) < 0.1 and absf(stone.g - stone.b) < 0.1
	var sword_ok: bool = is_instance_valid(_sword) and _sword.is_in_group("decor") and stone_grey

	# RoundTable: decor-grouped and its trim is Camelot gold (warm — r and g over b).
	var gold := _table.gold_color()
	var gold_ok: bool = gold.r > gold.b and gold.g > gold.b and gold.r > 0.6
	var table_ok: bool = is_instance_valid(_table) and _table.is_in_group("decor") and gold_ok

	# CamelotBanner colour table, mirroring Enemy.faction_color:
	var cam := _camelot.banner_color()
	var sax := _saxon.banner_color()
	var reb := _rebel.banner_color()
	var cam_ok: bool = cam.r > cam.b and cam.g > cam.b and cam.r > 0.6        # gold
	var sax_ok: bool = sax.g > sax.r and sax.g > sax.b                         # moss green
	var reb_ok: bool = reb.b > reb.g and reb.r > reb.g                         # purple
	var banners_grouped: bool = _camelot.is_in_group("decor") \
		and _saxon.is_in_group("decor") and _rebel.is_in_group("decor")
	# The Camelot blazon is Pendragon red (red dominant).
	var charge := _camelot.charge_color()
	var charge_ok: bool = charge.r > charge.g and charge.r > charge.b
	var banner_ok: bool = cam_ok and sax_ok and reb_ok and banners_grouped and charge_ok

	# Torch: alive, decor-grouped, ticked without error.
	var torch_ok: bool = is_instance_valid(_torch) and _torch.is_in_group("decor")

	print("ARTHURDECOR_RESULT sword=%s table=%s gold=%s | banner cam=%s sax=%s reb=%s charge=%s grouped=%s | torch=%s"
		% [str(sword_ok), str(table_ok), str(gold_ok),
			str(cam_ok), str(sax_ok), str(reb_ok), str(charge_ok), str(banners_grouped),
			str(torch_ok)])
	var ok: bool = sword_ok and table_ok and banner_ok and torch_ok
	print("ARTHURDECOR_VERDICT %s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)
