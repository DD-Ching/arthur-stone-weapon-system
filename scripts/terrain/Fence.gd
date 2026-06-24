class_name Fence
extends StaticBody2D
## A placeable solid wall on the "world" layer — a fence/barricade that bodies (and the
## navigation steering) treat as an obstacle. Pure decoration + collision: it draws a thin
## fence look sized to its RectangleShape2D child, so a level designer just drops it in and
## resizes the shape. No rules, no per-frame work — the collision shape does all the work.

func _draw() -> void:
	# Size the drawing to the collision shape so resizing the shape resizes the look.
	var rect := _shape_rect()
	if rect.size == Vector2.ZERO:
		return
	draw_rect(rect, Color(0.34, 0.26, 0.18))           # plank fill (matches Battlefield fences)
	draw_rect(rect, Color(0.5, 0.4, 0.28), false, 3.0)  # lighter edge
	# A few vertical posts so a long fence reads as planks, not a slab.
	var step := 26.0
	var x := rect.position.x + step
	while x < rect.position.x + rect.size.x:
		draw_line(Vector2(x, rect.position.y), Vector2(x, rect.position.y + rect.size.y),
			Color(0.5, 0.4, 0.28, 0.6), 2.0)
		x += step

func _shape_rect() -> Rect2:
	for c in get_children():
		if c is CollisionShape2D and c.shape is RectangleShape2D:
			var size: Vector2 = c.shape.size
			return Rect2(c.position - size * 0.5, size)
	return Rect2()
