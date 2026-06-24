class_name SpearArt
extends RefCounted
## The spearman silhouette: a long reaching shaft + a clear leaf head, so its threat RANGE reads
## from afar. Drawn on Enemy `e`. Beautify the spear HERE, in isolation.

static func draw(e) -> void:
	var a: float = e._alpha
	var r: float = e.radius
	var fwd: Vector2 = Vector2(cos(e._face), sin(e._face))
	var side: Vector2 = Vector2(-fwd.y, fwd.x)
	var tip: Vector2 = fwd * (r + 34.0)
	e.draw_line(fwd * r * 0.2, tip, Color(0.7, 0.6, 0.45, a), 3.0)
	var barb: Vector2 = fwd * (r + 27.0)
	e.draw_line(barb, barb + side * 4.5, Color(0.85, 0.85, 0.9, a), 2.0)
	e.draw_line(barb, barb - side * 4.5, Color(0.85, 0.85, 0.9, a), 2.0)
	e.draw_circle(tip, 3.0, Color(0.9, 0.9, 0.95, a))
