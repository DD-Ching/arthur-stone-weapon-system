class_name SorceressArt
extends RefCounted
## Morgan le Fay — a robed sorceress wielding dark magic. Drawn on Enemy `e`. Beautify the
## sorceress HERE, in isolation (one agent, one file). Reads e.radius/e._face/e._alpha (and may
## use e.faction_color() for the magic hue). This is a starting point.

static func draw(e) -> void:
	var a: float = e._alpha
	var r: float = e.radius
	var fwd: Vector2 = Vector2(cos(e._face), sin(e._face))
	var side: Vector2 = Vector2(-fwd.y, fwd.x)
	# A hooded robe (a downward wedge below the body) in dark violet.
	var robe := Color(0.36, 0.22, 0.42, a)
	e.draw_colored_polygon(PackedVector2Array([
		Vector2(0.0, -r * 0.2), side * r * 0.8 + Vector2(0.0, r * 0.95), -side * r * 0.8 + Vector2(0.0, r * 0.95)
	]), robe)
	# A pointed hood.
	e.draw_colored_polygon(PackedVector2Array([
		Vector2(0.0, -r - 8.0), side * r * 0.35 + Vector2(0.0, -r * 0.3), -side * r * 0.35 + Vector2(0.0, -r * 0.3)
	]), Color(0.30, 0.18, 0.36, a))
	# A staff held to the side, topped with a glowing violet orb.
	var staff_base: Vector2 = side * r * 0.95 + Vector2(0.0, r * 0.5)
	var staff_top: Vector2 = side * r * 0.95 + Vector2(0.0, -r - 8.0)
	e.draw_line(staff_base, staff_top, Color(0.42, 0.30, 0.24, a), 2.5)
	e.draw_circle(staff_top, 4.0, Color(0.72, 0.42, 0.92, a))
	e.draw_arc(staff_top, 8.0, 0.0, TAU, 14, Color(0.72, 0.42, 0.92, a * 0.5), 2.0)
