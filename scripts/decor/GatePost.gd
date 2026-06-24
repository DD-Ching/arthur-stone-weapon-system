class_name GatePost
extends StaticBody2D
## A solid stone gate post — a decorative obstacle maps place in pairs to frame a gate or
## chokepoint. On the "world" layer (bit 1) so bodies and the steering treat it as a wall,
## like Fence; the drawn stone look is sized to its RectangleShape2D child, so a designer
## just drops it in and resizes the shape. Pure decoration + collision, no per-frame work.

func _draw() -> void:
	var rect := _shape_rect()
	if rect.size == Vector2.ZERO:
		return
	# The stone block: a dark fill with a lighter chiselled edge.
	draw_rect(rect, Color(0.40, 0.39, 0.42))
	draw_rect(rect, Color(0.56, 0.55, 0.58), false, 3.0)
	# A few horizontal mortar courses so the post reads as stacked masonry, not a slab.
	var step := 22.0
	var y := rect.position.y + step
	while y < rect.position.y + rect.size.y:
		draw_line(Vector2(rect.position.x, y), Vector2(rect.position.x + rect.size.x, y),
			Color(0.28, 0.27, 0.30, 0.7), 2.0)
		y += step
	# A flat cap stone across the top, so a pair of posts reads as a gateway.
	var cap := Rect2(rect.position.x - 3.0, rect.position.y - 6.0, rect.size.x + 6.0, 8.0)
	draw_rect(cap, Color(0.48, 0.47, 0.50))
	draw_rect(cap, Color(0.60, 0.59, 0.62), false, 2.0)

func _shape_rect() -> Rect2:
	for c in get_children():
		if c is CollisionShape2D and c.shape is RectangleShape2D:
			var size: Vector2 = c.shape.size
			return Rect2(c.position - size * 0.5, size)
	return Rect2()
