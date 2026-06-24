extends Node2D
## Headless test for the placeable terrain SCENES (unit #7 — token TERRAIN_SCN).
##
## These wrap the shared TerrainZone module as drop-in building blocks. The test proves the
## authored scenes actually carry their rules:
##   - RiverZone drifts a loose RigidBody2D downstream (+x) via its current, and
##     simultaneously DAMPS its speed via drag (a body launched into it slows),
##   - Fence is a solid StaticBody2D on the "world" layer with a collision shape.
##
## Modeled on tests/ford_test.gd (which drives a body through the river current). Bodies are
## the real Rock prop (collision_layer 8 = props), which the zones' mask (12) acts on.
##
## Run: godot --headless --path . res://tests/TerrainScenesTest.tscn --quit-after 600

const RIVER_ZONE := preload("res://scenes/terrain/RiverZone.tscn")
const FENCE := preload("res://scenes/terrain/Fence.tscn")
const ROCK := preload("res://scenes/Rock.tscn")

const WORLD_LAYER := 1   # bit for 2d_physics/layer_1 "world"

var drift_rock: RigidBody2D
var damp_rock: RigidBody2D
var fence: StaticBody2D
var _frame := 0
var _drift_start := Vector2.ZERO
var _damp_start_speed := 0.0

func _ready() -> void:
	# A river segment centred on the origin; its rect comes from the scene's RectangleShape2D.
	var river: TerrainZone = RIVER_ZONE.instantiate()
	river.global_position = Vector2.ZERO
	add_child(river)

	# Drift body: starts at rest in the middle of the river — only the current should move it.
	drift_rock = ROCK.instantiate()
	add_child(drift_rock)
	drift_rock.global_position = Vector2.ZERO
	drift_rock.linear_velocity = Vector2.ZERO
	_drift_start = drift_rock.global_position

	# Damp body: launched FAST along -x (against the current) so drag is what reins it in;
	# proves the drag rule bites independently of the current's push.
	damp_rock = ROCK.instantiate()
	add_child(damp_rock)
	damp_rock.global_position = Vector2(-120.0, 30.0)
	damp_rock.linear_velocity = Vector2(-400.0, 0.0)
	_damp_start_speed = damp_rock.linear_velocity.length()

	# The Fence building block.
	fence = FENCE.instantiate()
	add_child(fence)
	fence.global_position = Vector2(0.0, 400.0)

	print("TERRAIN_SCN_READY ok")

func _physics_process(_delta: float) -> void:
	_frame += 1
	if _frame >= 120:
		_report()

func _report() -> void:
	var drift: float = drift_rock.global_position.x - _drift_start.x
	var damp_speed: float = damp_rock.linear_velocity.length()

	# Fence checks: a StaticBody2D on the world layer with a rectangle collision shape.
	var fence_is_static: bool = fence is StaticBody2D
	var fence_on_world: bool = (fence.collision_layer & WORLD_LAYER) != 0
	var fence_has_shape := false
	for c in fence.get_children():
		if c is CollisionShape2D and c.shape is RectangleShape2D:
			fence_has_shape = true
			break

	# The current pushes +x; drag damps the fast body well below its launch speed.
	var drifted: bool = drift > 8.0
	var damped: bool = damp_speed < _damp_start_speed * 0.85
	var fence_ok: bool = fence_is_static and fence_on_world and fence_has_shape

	print("TERRAIN_SCN_RESULT drift_x=%.1f damp_speed=%.1f (from %.1f) fence_static=%s fence_world=%s fence_shape=%s"
		% [drift, damp_speed, _damp_start_speed, str(fence_is_static), str(fence_on_world), str(fence_has_shape)])
	var ok: bool = drifted and damped and fence_ok
	print("TERRAIN_SCN_VERDICT %s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)
