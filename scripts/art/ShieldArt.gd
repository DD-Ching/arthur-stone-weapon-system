class_name ShieldArt
extends RefCounted
## The shieldbearer silhouette: a cap + rim on the guarding side, with a DISTINCT broken-shield
## state (dull, thin, cracked) so the player reads "shield down — hit it". Drawn on Enemy `e`.
## Beautify the shield HERE, in isolation. Reads e.shield_angle / e._shield_broken / e.radius / e._alpha.

static func draw(e) -> void:
	var a: float = e._alpha
	var r: float = e.radius
	var sa: float = e.shield_angle
	if e._shield_broken > 0.0:
		# Broken: split the rim into two short, dull, thin arcs with a gap — a snapped shield —
		# plus a jagged spur falling away from the break so it reads as shattered, not just faded.
		var dull := Color(0.42, 0.46, 0.55, a)
		e.draw_arc(Vector2.ZERO, r + 4.0, sa - 0.95, sa - 0.18, 8, dull, 3.0)
		e.draw_arc(Vector2.ZERO, r + 4.0, sa + 0.18, sa + 0.95, 8, dull, 3.0)
		var br := Vector2(cos(sa), sin(sa))
		var bs := Vector2(-br.y, br.x)
		e.draw_line(br * (r + 4.0), br * (r + 11.0) + bs * 4.0, dull, 2.0)
		return
	# Intact: a solid bright rim + a faint inner boss so it reads as a plate, not a thin line.
	e.draw_arc(Vector2.ZERO, r + 5.0, sa - 0.95, sa + 0.95, 18, Color(0.74, 0.76, 0.84, a), 6.0)
	e.draw_arc(Vector2.ZERO, r + 1.5, sa - 0.8, sa + 0.8, 14, Color(0.5, 0.54, 0.64, a * 0.8), 3.0)
