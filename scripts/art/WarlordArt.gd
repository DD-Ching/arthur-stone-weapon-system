class_name WarlordArt
extends RefCounted
## The Saxon Warlord (Cerdic) — a burly, fur-clad axe-lord with a horned helm and a great
## two-handed axe, in Saxon moss-green accents. Drawn on Enemy `e` in LOCAL space. Beautify the
## warlord HERE, in isolation. When e.is_general, make him more imposing. A starting point.

static func draw(e) -> void:
	var a: float = e._alpha
	var r: float = e.radius
	var fwd: Vector2 = Vector2(cos(e._face), sin(e._face))
	var side: Vector2 = Vector2(-fwd.y, fwd.x)
	# A burly fur-cloaked body.
	e.draw_arc(Vector2.ZERO, r * 0.7, 0.0, TAU, 18, Color(0.40, 0.34, 0.26, a), 4.0)
	# A horned helm.
	var helm: Vector2 = fwd * r * 0.4
	e.draw_circle(helm, r * 0.3, Color(0.50, 0.50, 0.54, a))
	e.draw_line(helm + side * r * 0.3, helm + side * r * 0.55 + Vector2(0.0, -r * 0.2), Color(0.9, 0.88, 0.8, a), 2.0)
	e.draw_line(helm - side * r * 0.3, helm - side * r * 0.55 + Vector2(0.0, -r * 0.2), Color(0.9, 0.88, 0.8, a), 2.0)
	# A great axe along the facing.
	var head: Vector2 = fwd * (r + 22.0)
	e.draw_line(fwd * r * 0.2, head, Color(0.45, 0.35, 0.25, a), 3.0)
	e.draw_line(head + side * r * 0.4, head - side * r * 0.4, Color(0.70, 0.72, 0.78, a), 3.0)
