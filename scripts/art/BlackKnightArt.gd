class_name BlackKnightArt
extends RefCounted
## The Black Knight — a dread mercenary champion in BLACK plate (faction-INDEPENDENT: he reads
## black whatever side tints him), with a closed great-helm, a red eye-glow and a wicked dark
## blade. Drawn on Enemy `e` in LOCAL space. Beautify HERE, in isolation. This is a starting point.

static func draw(e) -> void:
	var a: float = e._alpha
	var r: float = e.radius
	var fwd: Vector2 = Vector2(cos(e._face), sin(e._face))
	# Black plate body ring.
	e.draw_arc(Vector2.ZERO, r * 0.66, 0.0, TAU, 20, Color(0.16, 0.16, 0.20, a), 3.5)
	# A closed helm with a single red eye-glow.
	var helm: Vector2 = fwd * r * 0.42
	e.draw_circle(helm, r * 0.3, Color(0.12, 0.12, 0.15, a))
	e.draw_circle(helm + fwd * r * 0.1, 1.6, Color(0.95, 0.2, 0.15, a))
	# A wicked dark blade.
	e.draw_line(fwd * r * 0.3, fwd * (r + 26.0), Color(0.32, 0.32, 0.38, a), 3.5)
