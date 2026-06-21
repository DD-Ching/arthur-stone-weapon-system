extends RigidBody2D
## A loose physics prop — a rock or a crate — that doubles as a projectile.
##
## A heavy swing or a slam launches it across the arena, where it can bowl into
## enemies for a real, scored impact ("ROCK HIT" / "CRATE HIT" + combo). Slams
## also spawn rocks as debris, closing the loop: slam drops a rock → a swing
## launches it → the rock hits an enemy.
##
## One script, two looks: set `crate = true` for a box. Both share the same
## launch + contact-scoring behaviour.

@export var crate := false
@export var radius := 14.0          ## rock radius / crate half-extent (visual)

var _flash := 0.0

func _ready() -> void:
	add_to_group("props")
	add_to_group("hittable")
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

## Launched by a swing or slam. Impulse + a little spin for readability.
func apply_knockback(dir: Vector2, strength: float) -> void:
	apply_central_impulse(dir * strength)
	angular_velocity += strength * 0.01
	_flash = 0.15

func _on_body_entered(body: Node) -> void:
	if not is_instance_valid(body) or not body.is_in_group("targets"):
		return
	var speed := linear_velocity.length()
	if speed < Impact.BOWL_MIN_SPEED:
		return
	if not Impact.try_collision_hit(body.get_instance_id()):
		return
	var dir: Vector2 = (body.global_position - global_position).normalized()
	var m: float = Impact.MASS_CRATE if crate else Impact.MASS_ROCK
	Impact.collide(body, dir, speed, m, "crate" if crate else "rock", self)

func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta)
		queue_redraw()

func _draw() -> void:
	var lit := clampf(_flash / 0.15, 0.0, 1.0)
	if crate:
		var col := Color(0.55, 0.42, 0.27).lerp(Color(1, 1, 1), lit)
		var r := radius
		draw_rect(Rect2(-r, -r, r * 2.0, r * 2.0), col)
		draw_rect(Rect2(-r, -r, r * 2.0, r * 2.0), Color(0.3, 0.22, 0.14), false, 2.5)
		draw_line(Vector2(-r, -r), Vector2(r, r), Color(0.3, 0.22, 0.14), 2.0)
		draw_line(Vector2(-r, r), Vector2(r, -r), Color(0.3, 0.22, 0.14), 2.0)
		return
	var col := Color(0.5, 0.48, 0.52).lerp(Color(1, 1, 1), lit)
	var pts := PackedVector2Array([
		Vector2(-radius, -radius * 0.4), Vector2(-radius * 0.4, -radius),
		Vector2(radius * 0.6, -radius * 0.85), Vector2(radius, radius * 0.2),
		Vector2(radius * 0.3, radius), Vector2(-radius * 0.7, radius * 0.7),
	])
	draw_colored_polygon(pts, col)
	var outline := pts.duplicate()
	outline.append(pts[0])
	draw_polyline(outline, Color(0.25, 0.24, 0.28), 2.0)
