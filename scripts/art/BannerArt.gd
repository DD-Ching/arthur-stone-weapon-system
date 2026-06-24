class_name BannerArt
extends RefCounted
## The officer/standard-bearer silhouette: a tall pole with a pennant + a crossbar, so the morale
## unit is plain to spot. Drawn on Enemy `e`. Beautify the banner HERE, in isolation.

static func draw(e) -> void:
	var a: float = e._alpha
	var r: float = e.radius
	e.draw_line(Vector2(0, -r), Vector2(0, -r - 34.0), Color(0.5, 0.4, 0.3, a), 3.0)
	e.draw_rect(Rect2(0, -r - 34.0, 22, 16), Color(0.8, 0.3, 0.25, a))
	e.draw_line(Vector2(-5, -r - 34.0), Vector2(5, -r - 34.0), Color(0.62, 0.5, 0.36, a), 2.0)
