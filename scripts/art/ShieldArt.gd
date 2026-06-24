class_name ShieldArt
extends RefCounted
## The shieldbearer silhouette: a SOLID PLATED round/kite shield on the guarding side
## (e.shield_angle) — a faction-emblem face, a central boss, a bright rim, plus a helmet glimpse.
## The BROKEN state (e._shield_broken > 0) is distinctly SHATTERED — a split rim, radial cracks,
## a dull hanging spur — so the player reads "shield down, hit it". Drawn on Enemy `e`.
## Beautify the shield HERE, in isolation. Allocation-light; e._alpha is multiplied into every alpha.

static func draw(e) -> void:
	var a: float = e._alpha
	var r: float = e.radius
	var sa: float = e.shield_angle
	# Guard axis: `g` points the way the shield faces; `s` is its lateral (the shield's width).
	var g: Vector2 = Vector2(cos(sa), sin(sa))
	var s: Vector2 = Vector2(-g.y, g.x)
	# Centre of the shield plate, stood off the body on the guarding side.
	var c: Vector2 = g * (r + 3.0)

	if e._shield_broken > 0.0:
		_draw_broken(e, a, r, sa, g, s, c)
		return

	# ── A helmet glimpse behind the shield (rear of the body, away from the guard) ──
	var helm: Color = Color(0.50, 0.53, 0.60, a)
	e.draw_circle(-g * (r * 0.34), r * 0.40, helm)
	e.draw_arc(-g * (r * 0.34), r * 0.40, sa + 2.1, sa + 4.18, 8, Color(0.72, 0.75, 0.82, a * 0.9), 1.5)

	# ── Solid plated shield body: a filled convex kite (rounded crown near body, point toward foe) ──
	# `crown` bows back toward the body (-g); `point` juts out past it toward the foe (+g); the kite
	# is widest across the lateral `s`. Vertices walk the perimeter cleanly so it triangulates simply.
	var hw: float = r * 0.92          # half-width across the lateral
	var back: float = r * 0.70        # how far the crown bows back behind centre
	var point: float = r * 1.20       # the kite's pointed tip, out past the body toward the foe
	var plate: PackedVector2Array = _kite(c, g, s, hw, back, point)
	e.draw_colored_polygon(plate, Color(0.40, 0.44, 0.52, a))

	# ── Faction emblem on the face: a coloured chevron converging on the point ──
	var fac: Color = e.faction_color()
	fac.a = a
	var pt: Vector2 = c + g * (point * 0.66)
	e.draw_line(c + s * (hw * 0.7) - g * (back * 0.2), pt, fac, 2.6)
	e.draw_line(c - s * (hw * 0.7) - g * (back * 0.2), pt, fac, 2.6)
	var faint: Color = fac
	faint.a = a * 0.5
	e.draw_line(c - g * (back * 0.4), c + g * (point * 0.5), faint, 2.0)

	# ── Central boss: a raised metal dome with a bright highlight ──
	e.draw_circle(c, r * 0.30, Color(0.30, 0.33, 0.40, a))
	e.draw_circle(c, r * 0.21, Color(0.62, 0.66, 0.74, a))
	e.draw_circle(c - s * (r * 0.06), r * 0.08, Color(0.92, 0.94, 1.0, a))

	# ── Bright rim around the whole plate (heavier on the foe-facing edge to catch light) ──
	var rim: Color = Color(0.82, 0.85, 0.92, a)
	for i in range(plate.size()):
		var p0: Vector2 = plate[i]
		var p1: Vector2 = plate[(i + 1) % plate.size()]
		e.draw_line(p0, p1, rim, 2.4)


static func _draw_broken(e, a: float, r: float, sa: float, g: Vector2, s: Vector2, c: Vector2) -> void:
	# Shield down: a dull, cracked plate, split rim with a gap, and a hanging spur. The colour is
	# desaturated and darker than the intact plate so it reads "broken", not merely faded.
	var dull: Color = Color(0.34, 0.36, 0.42, a)
	var dullrim: Color = Color(0.46, 0.48, 0.54, a * 0.9)
	var hw: float = r * 0.92
	var back: float = r * 0.70
	var point: float = r * 1.20
	# Same kite as the intact plate, but darker/flat — the boss knocked in.
	var plate: PackedVector2Array = _kite(c, g, s, hw, back, point)
	e.draw_colored_polygon(plate, dull)

	# Split rim: two short broken arc segments with a clear gap (the break) on the foe-facing side.
	e.draw_arc(c, r * 0.95, sa - 2.5, sa - 0.55, 8, dullrim, 2.0)
	e.draw_arc(c, r * 0.95, sa + 0.55, sa + 2.5, 8, dullrim, 2.0)

	# Radial cracks across the face, fanning from a caved-in boss.
	var crack: Color = Color(0.12, 0.13, 0.16, a)
	e.draw_line(c, c + g * (point * 0.6), crack, 1.6)
	e.draw_line(c, c + s * (hw * 0.7) - g * (back * 0.2), crack, 1.4)
	e.draw_line(c, c - s * (hw * 0.55) - g * (back * 0.3), crack, 1.4)
	# A caved boss: a dark dent, no bright highlight.
	e.draw_circle(c, r * 0.18, Color(0.20, 0.21, 0.25, a))

	# A jagged spur of rim hanging off the break at the point, falling away to the side.
	var hang: Vector2 = c + g * (point * 0.85)
	e.draw_line(hang, hang + g * 5.0 + s * 7.0, dullrim, 2.0)
	e.draw_line(hang + g * 5.0 + s * 7.0, hang + g * 11.0 + s * 4.0, dullrim, 1.6)


## A simple convex kite shield outline (6 points, clean perimeter walk so triangulation is trivial):
## rounded crown bowing back toward the body (-g), widening across the lateral (s), tapering to a
## point out toward the foe (+g). Returned as a PackedVector2Array so the caller fills + strokes it.
static func _kite(c: Vector2, g: Vector2, s: Vector2, hw: float, back: float, point: float) -> PackedVector2Array:
	return PackedVector2Array([
		c - g * back,                       # crown (rear, near body)
		c - g * (back * 0.4) + s * hw,      # rear shoulder, right
		c + g * (point * 0.35) + s * (hw * 0.8),  # forward flank, right
		c + g * point,                      # point (toward foe)
		c + g * (point * 0.35) - s * (hw * 0.8),  # forward flank, left
		c - g * (back * 0.4) - s * hw,      # rear shoulder, left
	])
