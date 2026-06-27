extends Node2D
## A short-lived debris chunk flung out when something shatters (via Impact.shatter).
##
## Deliberately NOT a physics body: it's a plain Node2D that integrates its own velocity with a
## little drag + spin, then frees itself on a fade timer. That keeps "smash the whole battlefield"
## cheap on the single-threaded web build — no RigidBody solve, no collision, just a flying _draw.
## It joins the "debris" group so Impact.shatter can enforce a global budget on concurrent chunks.

@export var chunk_color := Color(0.5, 0.36, 0.22)
@export var life := 0.85

var _vel := Vector2.ZERO
var _t := 0.0
var _alpha := 1.0
var _spin := 0.0
var _r := 4.0

func _ready() -> void:
	add_to_group("debris")
	_spin = randf_range(-12.0, 12.0)
	_r = randf_range(2.5, 5.5)
	rotation = randf() * TAU

## The launch contract Impact.shatter calls (same name props use) — fling the chunk outward.
func apply_knockback(dir: Vector2, strength: float) -> void:
	_vel = dir * (strength * 0.5)   # chunks are light: scale a prop-launch impulse down to a fling

func _process(delta: float) -> void:
	_t += delta
	position += _vel * delta
	_vel = _vel.move_toward(Vector2.ZERO, 520.0 * delta)   # air drag
	rotation += _spin * delta
	_alpha = clampf(1.0 - _t / life, 0.0, 1.0)
	if _t >= life:
		queue_free()
	else:
		queue_redraw()

func _draw() -> void:
	var c := Color(chunk_color.r, chunk_color.g, chunk_color.b, _alpha)
	# A little jagged shard.
	draw_colored_polygon(PackedVector2Array([
		Vector2(-_r, -_r * 0.6), Vector2(_r, -_r * 0.4),
		Vector2(_r * 0.6, _r), Vector2(-_r * 0.8, _r * 0.7),
	]), c)
