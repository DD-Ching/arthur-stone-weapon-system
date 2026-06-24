class_name KnightArt
extends RefCounted
## The elite knight silhouette: an armoured ring + a long forward-swept blade with a crossguard and
## a crest plume — the sharper, faster threat, distinct from the bulky-but-blunt heavy. Drawn on
## Enemy `e`. Beautify the knight HERE. (Knight generals — e.is_general, e.g. Lu Bu / Guan Yu — can
## be made grander here too.)

static func draw(e) -> void:
	var a: float = e._alpha
	var r: float = e.radius
	var fwd: Vector2 = Vector2(cos(e._face), sin(e._face))
	var side: Vector2 = Vector2(-fwd.y, fwd.x)
	e.draw_arc(Vector2.ZERO, r * 0.66, 0.0, TAU, 18, Color(0.85, 0.86, 0.92, a), 3.0)
	e.draw_line(fwd * r * 0.3, fwd * (r + 22.0), Color(0.92, 0.93, 1.0, a), 3.0)
	e.draw_circle(fwd * (r + 22.0), 3.0, Color(0.95, 0.96, 1.0, a))
	# A crossguard at the blade's base so it reads as a sword, not a pole.
	var guard: Vector2 = fwd * (r + 4.0)
	e.draw_line(guard + side * 5.0, guard - side * 5.0, Color(0.78, 0.79, 0.86, a), 2.5)
	# A short rear crest plume.
	e.draw_line(-fwd * r * 0.4, -fwd * (r + 9.0) + side * 4.0, Color(0.9, 0.4, 0.35, a), 2.5)
