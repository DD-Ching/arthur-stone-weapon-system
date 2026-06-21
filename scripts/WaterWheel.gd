extends Area2D
## The mill water wheel beside the ford — a spinning battlefield hazard.
##
## It turns at a constant rate and BATS any enemy or prop that wanders (or is knocked)
## into it: each body overlapping its area gets a tangential + outward impulse along
## the spin, hard enough to go limp and fly off. "Knock a soldier into the wheel" is
## the funniest physics moment on the field, and a cart or crate shoved in is flung
## back across the line.
##
## No custom physics — it measures who overlaps each frame (Area2D) and applies one
## Godot impulse, debounced through Impact so a single body is batted a few times a
## second rather than every frame. The wheel area does not block movement; bodies pass
## through and get thrown, which keeps it readable and cheap on the web build.

@export var spin_speed := 2.6        ## radians/sec the wheel turns (sign = direction)
@export var throw_force := 760.0     ## impulse magnitude when it bats a body
@export var paddles := 8
@export var radius := 76.0

var _spin := 0.0
var _creak := 0.0

func _ready() -> void:
	add_to_group("hazards")
	monitoring = true

func _physics_process(delta: float) -> void:
	_spin = wrapf(_spin + spin_speed * delta, -PI, PI)
	# Atmosphere: a slow placeholder creak (a future sound hooks onto this).
	_creak -= delta
	if _creak <= 0.0:
		_creak = 1.7
		Audio.play("water_wheel_creak", global_position)

	for body in get_overlapping_bodies():
		if not (body is RigidBody2D) or not is_instance_valid(body):
			continue
		# Debounce so the wheel bats a body ~3x/sec, not every physics frame.
		if not Impact.try_collision_hit(body.get_instance_id(), 0.3):
			continue
		var radial: Vector2 = body.global_position - global_position
		var out := radial.normalized() if radial.length() > 1.0 else Vector2.RIGHT
		var tang := Vector2(-out.y, out.x) * signf(spin_speed)   # along the spin
		var impulse := (tang * 0.85 + out * 0.55).normalized() * throw_force
		body.apply_central_impulse(impulse)
		if body.has_method("stun"):
			body.stun(0.4)                # go limp so the throw reads as physics
		Impact.popup("WATER WHEEL", body.global_position + Vector2(0, -32), Color(0.55, 0.82, 1.0), 1.1)
		Impact.impact_fx.emit(8.0)
		Audio.play("enemy_launch", body.global_position)
		Audio.play("water_splash", body.global_position)
	queue_redraw()

func _draw() -> void:
	var hub := Color(0.30, 0.22, 0.15)
	var wood := Color(0.50, 0.38, 0.24)
	var blade := Color(0.42, 0.32, 0.2)
	# Water pooling under the wheel.
	draw_circle(Vector2.ZERO, radius + 6.0, Color(0.20, 0.34, 0.42, 0.45))
	for i in paddles:
		var a := _spin + float(i) / float(paddles) * TAU
		var d := Vector2(cos(a), sin(a))
		var t := Vector2(-d.y, d.x)
		draw_line(Vector2.ZERO, d * radius, wood, 5.0)                      # spoke
		draw_line(d * radius - t * 13.0, d * radius + t * 13.0, blade, 8.0) # paddle blade
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, Color(0.42, 0.32, 0.2, 0.6), 3.0)
	draw_circle(Vector2.ZERO, radius * 0.16, hub)                           # hub
