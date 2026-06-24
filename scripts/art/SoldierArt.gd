class_name SoldierArt
extends RefCounted
## The light footman silhouette. Drawn on the Enemy `e` (a CanvasItem) by `UnitArt`.
## Beautify the soldier HERE, in isolation — this file is the only thing that owns the look.
## Reads e.radius / e._face / e._alpha (and may use e.faction_color() / e.is_general for flavour).

static func draw(e) -> void:
	var a: float = e._alpha
	var r: float = e.radius
	var fwd: Vector2 = Vector2(cos(e._face), sin(e._face))
	var side: Vector2 = Vector2(-fwd.y, fwd.x)
	# A short blade along the facing + a small helm dot, plus a tiny round buckler on the off-hand
	# so the lone soldier reads distinct from a spearman.
	e.draw_line(fwd * r * 0.4, fwd * (r + 16.0), Color(0.82, 0.84, 0.9, a), 2.5)
	e.draw_circle(fwd * r * 0.45, r * 0.28, Color(0.95, 0.9, 0.8, a))
	e.draw_arc(-side * r * 0.55, r * 0.3, 0.0, TAU, 10, Color(0.66, 0.68, 0.74, a), 2.0)
