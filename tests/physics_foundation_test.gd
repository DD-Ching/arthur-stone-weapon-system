extends Node2D
## Headless test for the physical-world foundation (token PHYSFOUND):
##   - a Breakable SHATTERS on a hard shove (frees itself + bursts debris into the "debris" group),
##   - Impact.shatter honours DEBRIS_BUDGET (a huge request is capped, never unbounded),
##   - Impact.explode hits everything in range (returns a non-zero count),
##   - a Javelin DEFLECTS off a "stone_weapon" body (goes spent) instead of striking through it.
##
## Run: godot --headless --path . res://tests/PhysicsFoundationTest.tscn --quit-after 600 — look for PHYSFOUND_VERDICT.

const CHUNK := preload("res://scenes/props/ChunkDebris.tscn")
const JAVELIN := preload("res://scenes/Javelin.tscn")

var _frame := 0
var _break_target
var _shatter_ok := false
var _explode_ok := false
var _deflect_ok := false

func _ready() -> void:
	# (1) a Breakable that shatters on a hard shove.
	var b := Breakable.new()
	b.debris_scene = CHUNK
	b.debris_count = 5
	b.hard_hit = 400.0
	add_child(b)
	_break_target = b

	# An indestructible Breakable in range, so explode has something to hit (high health/hard_hit).
	var t := Breakable.new()
	t.debris_scene = CHUNK
	t.max_health = 1.0e9
	t.hard_hit = 1.0e9
	t.position = Vector2(40.0, 0.0)
	add_child(t)

	# Fire the shove + the explosion now that both are in the tree + their groups.
	b.apply_knockback(Vector2.DOWN, 900.0)                       # > hard_hit -> shatter + queue_free
	_explode_ok = Impact.explode(self, Vector2.ZERO, 120.0, 600.0, 20.0, 0.3) >= 1

	# (2) shatter budget: request far more chunks than the cap allows.
	Impact.shatter(CHUNK, Vector2(200.0, 200.0), 500)
	var dcount := get_tree().get_nodes_in_group("debris").size()
	_shatter_ok = dcount > 0 and dcount <= Impact.DEBRIS_BUDGET

	# (3) deflect: a javelin meeting a stone_weapon body goes spent without striking.
	var jav = JAVELIN.instantiate()
	add_child(jav)
	jav.launch(Vector2.ZERO, Vector2.RIGHT, 500.0, 8.0, "raiders")
	var stone := Node2D.new()
	stone.add_to_group("stone_weapon")
	add_child(stone)
	jav._on_body_entered(stone)
	_deflect_ok = bool(jav._spent)

func _physics_process(_dt: float) -> void:
	_frame += 1
	if _frame >= 6:
		_report()

func _report() -> void:
	var break_ok: bool = not is_instance_valid(_break_target)   # the breakable shattered + freed
	var ok: bool = break_ok and _shatter_ok and _explode_ok and _deflect_ok
	print("PHYSFOUND_RESULT break=%s shatter=%s explode=%s deflect=%s debris=%d budget=%d" % [
		str(break_ok), str(_shatter_ok), str(_explode_ok), str(_deflect_ok),
		get_tree().get_nodes_in_group("debris").size(), Impact.DEBRIS_BUDGET])
	print("PHYSFOUND_VERDICT %s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)
