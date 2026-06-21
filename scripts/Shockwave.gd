extends Node2D
## The visual + physical burst left by an overhead slam.
##
## On spawn it applies a radial impulse (with distance falloff) to everything
## hittable nearby and stuns enemies, then plays a short expanding ring + cracks
## + dust that fade and free themselves. Cheap, but it reads as IMPACT.

@export var radius := 160.0
@export var impulse := 760.0
@export var life := 0.55
@export var stun_time := 0.9

var _t := 0.0

func _ready() -> void:
	add_to_group("shockwave")

## Call this AFTER setting global_position. Kept out of _ready() on purpose:
## add_child() runs _ready() synchronously, before the spawner can position us,
## so computing the radial impulse there would measure from the wrong origin.
func detonate() -> void:
	for group in ["targets", "props"]:
		for body in get_tree().get_nodes_in_group(group):
			if not is_instance_valid(body):
				continue
			var to: Vector2 = body.global_position - global_position
			var dist := to.length()
			if dist >= radius:
				continue
			var falloff := 1.0 - dist / radius           # full force at centre
			var dir := to.normalized() if dist > 0.01 else Vector2.RIGHT
			var strength := impulse * falloff
			if body.has_method("apply_hit"):
				# Enemies take real damage + stun and feed a little Stone Flow. Pass
				# `pin` so a slam that pins a shielded enemy to a wall bypasses the
				# shield (the brief's wall-crush rule), and honour the block result
				# the same way the swing does (no SLAM! label / 0.4x flow when blocked).
				var pin := Impact.cushion(self, body.global_position, dir)
				var res: Dictionary = body.apply_hit(dir, strength, stun_time * falloff,
					Impact.DMG_BASE * Impact.SLAM_DAMAGE_MULT * falloff, pin)
				var blocked: bool = res["blocked"]
				Impact.add_flow(Impact.SLAM_FLOW_BASE * falloff * (0.4 if blocked else 1.0))
				if falloff > 0.2 and not blocked:   # label any enemy that took a meaningful hit
					Impact.popup("SLAM!", body.global_position + Vector2(0, -26), Color(1.0, 0.8, 0.3))
			elif body.has_method("apply_knockback"):
				body.apply_knockback(dir, strength)   # props just launch

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
	if _t >= life:
		queue_free()

func _draw() -> void:
	var p := clampf(_t / life, 0.0, 1.0)
	var a := 1.0 - p
	var r := radius * p
	# Expanding shock rings.
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, Color(1.0, 0.95, 0.7, a * 0.85), 5.0)
	draw_arc(Vector2.ZERO, r * 0.66, 0.0, TAU, 48, Color(0.85, 0.72, 0.5, a * 0.5), 3.0)
	# Ground cracks radiating out (snap to near-full length quickly, then linger).
	var crack_len := radius * 0.5 * minf(1.0, p * 2.5)
	for i in range(8):
		var ang := float(i) / 8.0 * TAU + 0.2
		draw_line(Vector2.ZERO, Vector2(cos(ang), sin(ang)) * crack_len,
			Color(0.12, 0.10, 0.09, a), 3.0)
	# Dust puffs riding the leading edge.
	for i in range(10):
		var ang := float(i) / 10.0 * TAU + p * 1.5
		draw_circle(Vector2(cos(ang), sin(ang)) * r * 0.92, 7.0 * (1.0 - p),
			Color(0.62, 0.57, 0.52, a * 0.6))
