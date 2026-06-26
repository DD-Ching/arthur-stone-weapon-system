class_name MordredArt
extends RefCounted
## Mordred, the traitor prince — a usurper knight in rebel black-purple with a dark crown and a
## cruel blade. Drawn on Enemy `e` (a CanvasItem) in LOCAL space. Beautify the traitor HERE, in
## isolation (one agent, one file). When e.is_general, make him grander. This is a starting point.

static func draw(e) -> void:
	var a: float = e._alpha
	var r: float = e.radius
	var fwd: Vector2 = Vector2(cos(e._face), sin(e._face))
	var side: Vector2 = Vector2(-fwd.y, fwd.x)
	var fc: Color = e.faction_color()   # rebel black-purple
	# Dark armoured body ring.
	e.draw_arc(Vector2.ZERO, r * 0.66, 0.0, TAU, 20, Color(fc.r * 0.85, fc.g * 0.7, fc.b * 0.95, a), 3.0)
	# A cruel blade.
	e.draw_line(fwd * r * 0.3, fwd * (r + 24.0), Color(0.78, 0.78, 0.86, a), 3.0)
	# A small dark crown above the brow (the usurper).
	var brow: Vector2 = fwd * r * 0.42 + Vector2(0.0, -r * 0.55)
	e.draw_line(brow + side * r * 0.28, brow - side * r * 0.28, Color(0.86, 0.74, 0.38, a), 2.0)
