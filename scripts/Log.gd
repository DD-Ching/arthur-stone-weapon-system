extends RigidBody2D
## A floating log — a drifting river hazard. Spawned upstream, it rides the ford's
## current downstream (the Battlefield's water force carries any prop), and a
## fast-moving log bowls raiders like a launched rock. Arthur can also swing it.
##
## Same launch + contact-scoring contract as Rock (group "props", apply_knockback,
## body_entered → Impact.collide), so the weapon and terrain treat it as a prop.

@export var length := 70.0
@export var thick := 14.0
var _flash := 0.0

func _ready() -> void:
	add_to_group("props")
	add_to_group("hittable")
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func apply_knockback(dir: Vector2, strength: float) -> void:
	apply_central_impulse(dir * strength)
	angular_velocity += strength * 0.006
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
	Impact.collide(body, dir, speed, Impact.MASS_ROCK * 1.4, "rock", self)

func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta)
		queue_redraw()

func _draw() -> void:
	var lit := clampf(_flash / 0.15, 0.0, 1.0)
	var bark := Color(0.4, 0.29, 0.17).lerp(Color(1, 1, 1), lit)
	var ring := Color(0.55, 0.42, 0.26).lerp(Color(1, 1, 1), lit)
	var hl := length * 0.5
	var hw := thick * 0.5
	draw_rect(Rect2(-hl, -hw, length, thick), bark)
	draw_rect(Rect2(-hl, -hw, length, thick), Color(0.26, 0.18, 0.11), false, 2.0)
	draw_circle(Vector2(-hl, 0.0), hw, ring)        # cut end rings
	draw_circle(Vector2(hl, 0.0), hw, ring)
	draw_circle(Vector2(hl, 0.0), hw * 0.45, Color(0.32, 0.23, 0.14))
