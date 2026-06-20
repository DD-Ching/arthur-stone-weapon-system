extends RigidBody2D
## A loose rock — a physics prop and a projectile.
##
## A heavy swing or a slam launches it across the arena, where it can bowl into
## enemies. Slams also spawn these as debris, which closes the core puzzle loop:
## slam creates a rock -> swing launches the rock -> rock hits enemies.

@export var radius := 14.0

var _flash := 0.0

func _ready() -> void:
	add_to_group("props")
	add_to_group("hittable")

func apply_knockback(dir: Vector2, strength: float) -> void:
	apply_central_impulse(dir * strength)
	angular_velocity += strength * 0.01   # a little tumble for readability
	_flash = 0.15

func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta)
		queue_redraw()

func _draw() -> void:
	var col := Color(0.5, 0.48, 0.52).lerp(Color(1, 1, 1), clampf(_flash / 0.15, 0.0, 1.0))
	var pts := PackedVector2Array([
		Vector2(-radius, -radius * 0.4), Vector2(-radius * 0.4, -radius),
		Vector2(radius * 0.6, -radius * 0.85), Vector2(radius, radius * 0.2),
		Vector2(radius * 0.3, radius), Vector2(-radius * 0.7, radius * 0.7),
	])
	draw_colored_polygon(pts, col)
	var outline := pts.duplicate()
	outline.append(pts[0])
	draw_polyline(outline, Color(0.25, 0.24, 0.28), 2.0)
