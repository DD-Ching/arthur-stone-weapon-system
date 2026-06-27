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
	# Burst into launchable Rock debris through the shared shatter (one destruction code path).
	Impact.shatter(DEBRIS, global_position, debris_count, Vector2(300.0, 340.0))

func _draw_type() -> void:
	var fwd := Vector2(cos(_face), sin(_face))
	var side := Vector2(-fwd.y, fwd.x)
	var a := _alpha
	var fc := faction_color()
	var hl := radius * 1.4   # half length (along facing)
	var hw := radius * 1.0   # half width
	var wood_dk := Color(0.30, 0.20, 0.12, a)
	var wood := Color(0.50, 0.36, 0.22, a)
	var wood_lt := Color(0.58, 0.43, 0.28, a)

	# ── two heavy spoked wheels, drawn UNDER the bed (one per side, set back) ──
	var wheel_r := radius * 0.62
	var hub := Color(0.16, 0.12, 0.08, a)
	var rim := Color(0.22, 0.16, 0.10, a)
	for s in [1.0, -1.0]:
		var wc: Vector2 = side * (hw + 4.0) * float(s) - fwd * hl * 0.5
		draw_circle(wc, wheel_r, rim)                                  # tyre
		draw_circle(wc, wheel_r * 0.62, wood_dk)                       # wood disc
		draw_circle(wc, wheel_r * 0.2, hub)                            # hub
		for k in 4:                                                    # spokes
			var ang := float(k) / 4.0 * PI + _face
			var sp := Vector2(cos(ang), sin(ang)) * wheel_r * 0.55
			draw_line(wc - sp, wc + sp, rim, 2.0)

	# ── a forward battering beam / ram so it reads as a charging mass ──
	var ram_base := fwd * hl
	var ram_tip := fwd * (hl + radius * 0.7)
	draw_line(ram_base, ram_tip, wood_dk, 7.0)
	draw_circle(ram_tip, radius * 0.26, Color(0.40, 0.40, 0.44, a))   # iron-shod head
	draw_arc(ram_tip, radius * 0.26, 0.0, TAU, 12, Color(0.6, 0.6, 0.65, a), 2.0)

	# ── cart bed (heavy plank box) ──
	var pts := PackedVector2Array([
		fwd * hl + side * hw, fwd * hl - side * hw,
		-fwd * hl - side * hw, -fwd * hl + side * hw,
	])
	draw_colored_polygon(pts, wood)
	var outline := pts.duplicate()
	outline.append(pts[0])
	draw_polyline(outline, wood_dk, 3.0)
	# Plank lines across the bed for a wooden grain.
	for i in 3:
		var f := -0.4 + 0.4 * float(i)
		draw_line(side * hw + fwd * hl * f, -side * hw + fwd * hl * f, Color(0.34, 0.24, 0.15, a), 1.5)

	# ── raised front board + faction banner, so the kingdom + "front" read ──
	draw_line(fwd * hl + side * hw, fwd * hl - side * hw, wood_lt, 4.0)
	var banner := PackedVector2Array([
		side * (hw * 0.5), -side * (hw * 0.5),
		-side * (hw * 0.5) - fwd * (radius * 0.5),
		side * (hw * 0.5) - fwd * (radius * 0.5),
	])
	draw_colored_polygon(banner, Color(fc.r, fc.g, fc.b, a * 0.9))
	draw_line(side * (hw * 0.5), side * (hw * 0.5) - fwd * (radius * 0.5), wood_dk, 2.0)  # banner pole

	# ── driver braced at the back, reins forward ──
	var driver := -fwd * (hl * 0.45)
	draw_circle(driver, radius * 0.3, Color(0.34, 0.27, 0.30, a))         # torso
	draw_circle(driver + fwd * 2.0, radius * 0.2, Color(0.78, 0.62, 0.5, a))  # head
	draw_line(driver + fwd * 4.0, ram_base * 0.6, Color(0.55, 0.45, 0.32, a), 1.5)  # reins to the front
