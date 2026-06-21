class_name WarCart
extends Cavalry
## A relic war cart — a big, heavy charging mass. It reuses the cavalry charge
## brain (reposition → telegraph → charge → recover) but it is far heavier and
## tankier: it plows soldiers aside, barely flinches from a light hit, and a solid
## blow staggers it and breaks the charge. When it's finally wrecked it **flips**
## and bursts into launchable debris — chunks Arthur can then fling back into the
## army. "If full physics is hard, fake it with velocity + spawned debris" — done.

const DEBRIS := preload("res://scenes/Rock.tscn")
@export var debris_count := 3

func _defeat() -> void:
	super._defeat()   # standard: dead, KO count, DOWN!, flow
	Impact.popup("CART FLIPPED", global_position + Vector2(0, -42), Color(1.0, 0.6, 0.3), 1.4)
	var scene := get_tree().current_scene
	if scene == null:
		return
	for _i in debris_count:
		var d = DEBRIS.instantiate()
		scene.add_child(d)
		d.global_position = global_position + Vector2(randf_range(-22.0, 22.0), randf_range(-22.0, 22.0))
		d.apply_knockback(Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized(), 320.0)

func _draw_type() -> void:
	var fwd := Vector2(cos(_face), sin(_face))
	var side := Vector2(-fwd.y, fwd.x)
	var hl := radius * 1.4   # half length (along facing)
	var hw := radius * 1.0   # half width
	# Cart bed.
	var pts := PackedVector2Array([
		fwd * hl + side * hw, fwd * hl - side * hw,
		-fwd * hl - side * hw, -fwd * hl + side * hw,
	])
	draw_colored_polygon(pts, Color(0.5, 0.36, 0.22, _alpha))
	var outline := pts.duplicate()
	outline.append(pts[0])
	draw_polyline(outline, Color(0.3, 0.2, 0.12, _alpha), 3.0)
	# Plank lines + two wheels.
	draw_line(side * hw - fwd * hl * 0.2, -side * hw - fwd * hl * 0.2, Color(0.32, 0.22, 0.14, _alpha), 2.0)
	draw_circle(side * hw - fwd * hl * 0.6, radius * 0.4, Color(0.18, 0.13, 0.09, _alpha))
	draw_circle(-side * hw - fwd * hl * 0.6, radius * 0.4, Color(0.18, 0.13, 0.09, _alpha))
