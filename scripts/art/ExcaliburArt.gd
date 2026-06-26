class_name ExcaliburArt
extends RefCounted
## A Camelot champion wielding the radiant Excalibur — a holy blade of light. Drawn on Enemy `e`.
## Beautify the Excalibur knight HERE, in isolation (one agent, one file). Reads e.radius/e._face/
## e._alpha (and may use e.faction_color()/e.is_general for grandeur). This is a starting point.

static func draw(e) -> void:
	var a: float = e._alpha
	var r: float = e.radius
	var fwd: Vector2 = Vector2(cos(e._face), sin(e._face))
	var side: Vector2 = Vector2(-fwd.y, fwd.x)
	# An armoured champion ring.
	e.draw_arc(Vector2.ZERO, r * 0.66, 0.0, TAU, 18, Color(0.86, 0.87, 0.95, a), 3.0)
	# Excalibur: a long bright blade with a holy golden glow behind the steel + a gleaming point.
	var tip: Vector2 = fwd * (r + 26.0)
	e.draw_line(fwd * r * 0.3, tip, Color(1.0, 0.9, 0.5, a * 0.4), 6.0)   # the glow
	e.draw_line(fwd * r * 0.3, tip, Color(0.95, 0.96, 1.0, a), 3.5)       # the blade
	e.draw_circle(tip, 3.0, Color(1.0, 1.0, 0.9, a))                       # the gleam
	# A golden crossguard.
	var guard: Vector2 = fwd * (r + 4.0)
	e.draw_line(guard + side * 6.0, guard - side * 6.0, Color(0.92, 0.78, 0.30, a), 3.0)
