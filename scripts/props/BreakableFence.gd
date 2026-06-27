extends Breakable
## A destructible wooden fence segment — a config of Breakable that draws like the solid
## terrain `Fence` (plank fill + lighter edge + vertical posts), but on a smashable body that
## shatters into plank chunks on a hard hit. The look is sized to `radius` (the half-extent of
## its CollisionShape2D), so a designer just resizes the shape + radius to make a longer rail.

@export var length := 60.0   ## half-length of the rail (matches the CollisionShape2D extent)

func _draw() -> void:
	var lit := clampf(_flash / 0.18, 0.0, 1.0)
	var plank := Color(0.34, 0.26, 0.18, _alpha).lerp(Color(1, 1, 1, _alpha), lit)
	var edge := Color(0.5, 0.4, 0.28, _alpha)
	var rect := Rect2(-length, -radius, length * 2.0, radius * 2.0)
	draw_rect(rect, plank)                       # plank fill (matches terrain Fence)
	draw_rect(rect, edge, false, 3.0)            # lighter edge
	# Vertical posts so a long rail reads as planks, not a slab.
	var step := 26.0
	var x := rect.position.x + step
	while x < rect.position.x + rect.size.x:
		draw_line(Vector2(x, rect.position.y), Vector2(x, rect.position.y + rect.size.y),
			Color(edge.r, edge.g, edge.b, 0.6 * _alpha), 2.0)
		x += step
