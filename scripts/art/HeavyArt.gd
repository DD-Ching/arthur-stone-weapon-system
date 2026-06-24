class_name HeavyArt
extends RefCounted
## The heavy bruiser silhouette: a thick body ring, pauldron studs, a short stubby haft — a blunt
## bruiser, distinct from the knight's long blade. Drawn on Enemy `e`. Beautify the heavy HERE.
## (Heavy generals — e.is_general, e.g. Zhang Fei / Xiahou Dun — can be made grander here too.)

static func draw(e) -> void:
	var a: float = e._alpha
	var r: float = e.radius
	var fwd: Vector2 = Vector2(cos(e._face), sin(e._face))
	var side: Vector2 = Vector2(-fwd.y, fwd.x)
	e.draw_arc(Vector2.ZERO, r * 0.62, 0.0, TAU, 18, Color(0.2, 0.16, 0.16, a), 4.5)
	e.draw_circle(side * r * 0.72, r * 0.22, Color(0.3, 0.26, 0.26, a))
	e.draw_circle(-side * r * 0.72, r * 0.22, Color(0.3, 0.26, 0.26, a))
	e.draw_line(fwd * r * 0.4, fwd * (r + 9.0), Color(0.34, 0.3, 0.3, a), 4.0)
