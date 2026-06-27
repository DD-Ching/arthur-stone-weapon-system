extends Breakable
## A wooden barrel — a config of Breakable that rolls/launches like a crate and shatters
## on a hard hit into brown stave chunks. Pure look change: the destruction, launch, and
## hit contracts all come from Breakable. Override `_draw()` for the barrel silhouette
## (rounded body + darker hoop bands).

func _draw() -> void:
	var lit := clampf(_flash / 0.18, 0.0, 1.0)
	var wood := Color(0.46, 0.32, 0.18, _alpha).lerp(Color(1, 1, 1, _alpha), lit)
	var stave := Color(0.36, 0.24, 0.13, _alpha)
	var hoop := Color(0.28, 0.18, 0.1, _alpha)
	var r := radius
	# Body: a slightly bulged barrel (taller than wide reads as upright staves top-down).
	draw_rect(Rect2(-r, -r, r * 2.0, r * 2.0), wood)
	# Vertical staves.
	var x := -r + r * 0.5
	while x < r:
		draw_line(Vector2(x, -r), Vector2(x, r), stave, 1.5)
		x += r * 0.5
	# Two darker hoop bands across the body.
	draw_line(Vector2(-r, -r * 0.45), Vector2(r, -r * 0.45), hoop, 3.0)
	draw_line(Vector2(-r, r * 0.45), Vector2(r, r * 0.45), hoop, 3.0)
	draw_rect(Rect2(-r, -r, r * 2.0, r * 2.0), hoop, false, 2.0)
