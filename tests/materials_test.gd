extends Node2D
## Headless test for the basic smashable materials (token MATERIALS): each of the four
## props is a CONFIG of Breakable, so hitting each one past its shatter threshold must:
##   - free the prop (it queue_free()s when it shatters), and
##   - grow the shared "debris" group (Impact.shatter burst its chunks), and
##   - for SupplyCrate, drop a hurlable Rock (a new "props" Rock node appears) — the
##     slam -> rock -> throw loop.
##
## Run: godot --headless --path . res://tests/MaterialsTest.tscn --quit-after 600 — look for MATERIALS_VERDICT.

const BARREL := preload("res://scenes/props/Barrel.tscn")
const SUPPLY_CRATE := preload("res://scenes/props/SupplyCrate.tscn")
const CLAY_POT := preload("res://scenes/props/ClayPot.tscn")
const FENCE := preload("res://scenes/props/BreakableFence.tscn")

var _frame := 0
var _props := {}            # name -> instance (cleared as each frees)
var _rock_before := 0
var _debris_before := 0
var _supply_crate
var _reported := false

func _ready() -> void:
	# A big shove — comfortably past every prop's hard_hit threshold so each shatters outright.
	var big := 1200.0
	var specs := [
		["Barrel", BARREL, Vector2(0.0, 0.0)],
		["SupplyCrate", SUPPLY_CRATE, Vector2(120.0, 0.0)],
		["ClayPot", CLAY_POT, Vector2(240.0, 0.0)],
		["BreakableFence", FENCE, Vector2(360.0, 0.0)],
	]
	_debris_before = get_tree().get_nodes_in_group("debris").size()
	_rock_before = _count_rocks()

	for spec in specs:
		var name: String = spec[0]
		var scene: PackedScene = spec[1]
		var pos: Vector2 = spec[2]
		var p = scene.instantiate()
		add_child(p)
		p.global_position = pos
		_props[name] = p
		if name == "SupplyCrate":
			_supply_crate = p

	# Hit each one past its threshold via the shared launch contract.
	for name in _props:
		var p = _props[name]
		p.apply_knockback(Vector2.DOWN, big)

func _physics_process(_dt: float) -> void:
	_frame += 1
	# Give the deferred free + the dropped Rock's _ready (group join) a few frames to settle.
	if _frame >= 8 and not _reported:
		_report()

func _count_rocks() -> int:
	var n := 0
	for p in get_tree().get_nodes_in_group("props"):
		if is_instance_valid(p) and p.get_script() == load("res://scripts/Rock.gd"):
			n += 1
	return n

func _report() -> void:
	_reported = true
	# (1) every prop freed itself on shatter.
	var freed_all := true
	var freed_detail := ""
	for name in _props:
		var ok: bool = not is_instance_valid(_props[name])
		freed_detail += "%s=%s " % [name, str(ok)]
		freed_all = freed_all and ok

	# (2) the shared debris group grew (chunks burst out).
	var debris_after := get_tree().get_nodes_in_group("debris").size()
	var debris_ok: bool = debris_after > _debris_before

	# (3) SupplyCrate dropped a hurlable Rock (a new "props" Rock appeared).
	var rock_after := _count_rocks()
	var rock_ok: bool = rock_after > _rock_before

	var ok: bool = freed_all and debris_ok and rock_ok
	print("MATERIALS_RESULT %sfreed_all=%s debris %d->%d (ok=%s) rocks %d->%d (ok=%s)" % [
		freed_detail, str(freed_all), _debris_before, debris_after, str(debris_ok),
		_rock_before, rock_after, str(rock_ok)])
	print("MATERIALS_VERDICT %s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)
