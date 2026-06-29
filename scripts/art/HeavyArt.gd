class_name HeavyArt
extends RefCounted
## The heavy bruiser silhouette: a thick armoured body ring, broad pauldrons, a heavy great-helm,
## and a big maul/club hauled along the facing — a slow TANK that reads as blunt and immovable,
## distinct from the knight's sharp blade. Drawn on Enemy `e`. Beautify the heavy HERE.
##
## When `e.is_general` (heavy warlords like Baldulf / Drust), the unit becomes GRANDER: a wider frame, a
## horned + plumed great-helm, a heavier maul, and a faction-coloured war-cloak streaming behind.
## All drawing is allocation-light `_draw` (no assets/shaders/threads/per-frame allocs); every
## colour multiplies `e._alpha` into its alpha so fades read correctly.

static func draw(e) -> void:
	var a: float = e._alpha
	var r: float = e.radius
	var fwd: Vector2 = Vector2(cos(e._face), sin(e._face))
	var side: Vector2 = Vector2(-fwd.y, fwd.x)
	var boss: bool = e.is_general

	# Generals stand a head bigger: scale the whole frame up so they tower over the line.
	var bulk: float = 1.22 if boss else 1.0

	# ── war-cloak (generals only) ── a faction-coloured cape streaming out behind, drawn FIRST so
	# the body/helm sit on top of it. A wide triangle fanned from the shoulders down the rear.
	if boss:
		var fc: Color = e.faction_color()
		var cloak: Color = Color(fc.r * 0.75 + 0.05, fc.g * 0.75 + 0.05, fc.b * 0.75 + 0.05, a * 0.9)
		var trim: Color = Color(fc.r * 1.1, fc.g * 1.1, fc.b * 1.1, a)
		var nape: Vector2 = -fwd * r * 0.30
		var hem_l: Vector2 = -fwd * (r * 1.55) + side * (r * 0.92)
		var hem_r: Vector2 = -fwd * (r * 1.55) - side * (r * 0.92)
		var cloak_pts := PackedVector2Array([nape, hem_l, -fwd * (r * 1.78), hem_r])
		e.draw_colored_polygon(cloak_pts, cloak)
		# A bright hem stroke so the cloak's edge catches the eye.
		e.draw_line(hem_l, -fwd * (r * 1.78), trim, 2.5)
		e.draw_line(-fwd * (r * 1.78), hem_r, trim, 2.5)

	# ── body ── a thick dark plate ring; a faint inner ring fills it so it reads as armour, not a
	# hoop. Generals get a brighter rivet ring on top for grandeur.
	var ring_c: Color = Color(0.20, 0.16, 0.16, a)
	var body_r: float = r * 0.64 * bulk
	e.draw_circle(Vector2.ZERO, body_r, Color(0.26, 0.22, 0.22, a * 0.55))
	e.draw_arc(Vector2.ZERO, body_r, 0.0, TAU, 22, ring_c, 5.0 * bulk)
	if boss:
		e.draw_arc(Vector2.ZERO, body_r * 0.78, 0.0, TAU, 18, Color(0.42, 0.36, 0.30, a), 2.5)

	# ── pauldrons ── broad armoured shoulder plates on each flank: a filled disc + a rim so they
	# read as big rounded steel, the bruiser's signature bulk.
	var pa: float = r * 0.78 * bulk
	var pr: float = r * 0.26 * bulk
	var pauld: Color = Color(0.34, 0.30, 0.30, a)
	var pauld_rim: Color = Color(0.46, 0.42, 0.42, a)
	var sides: Array[float] = [1.0, -1.0]
	for s in sides:
		var c: Vector2 = side * pa * s
		e.draw_circle(c, pr, pauld)
		e.draw_arc(c, pr, 0.0, TAU, 12, pauld_rim, 2.0)

	# ── great-helm ── a blunt rounded helm pushed forward, with a dark visor slit across it, so the
	# heavy reads as fully encased steel rather than a bare head.
	var helm_c: Vector2 = fwd * r * 0.30
	var helm_r: float = r * 0.40 * bulk
	e.draw_circle(helm_c, helm_r, Color(0.40, 0.37, 0.38, a))
	e.draw_arc(helm_c, helm_r, 0.0, TAU, 12, Color(0.52, 0.49, 0.50, a), 2.0)
	# Visor slit (a short dark line across the helm, perpendicular to facing).
	var visor: Vector2 = helm_c + fwd * helm_r * 0.35
	e.draw_line(visor + side * helm_r * 0.7, visor - side * helm_r * 0.7, Color(0.12, 0.10, 0.10, a), 2.5)

	if boss:
		# General's helm crest: a pair of curved HORNS + a tall plume, the unmistakable warlord mark.
		var horn_c: Color = Color(0.85, 0.82, 0.70, a)
		var horn_sides: Array[float] = [1.0, -1.0]
		for s in horn_sides:
			var base: Vector2 = helm_c + side * helm_r * 0.7 * s - fwd * helm_r * 0.2
			var mid: Vector2 = base + side * (helm_r * 0.6) * s - fwd * helm_r * 0.5
			var horn_tip: Vector2 = mid + side * (helm_r * 0.2) * s - fwd * helm_r * 0.7
			e.draw_line(base, mid, horn_c, 3.0)
			e.draw_line(mid, horn_tip, horn_c, 2.5)
		# A tall faction-coloured plume rising forward from the helm crown.
		var fc2: Color = e.faction_color()
		var plume_top: Vector2 = helm_c + fwd * (helm_r + r * 0.55)
		e.draw_line(helm_c + fwd * helm_r * 0.4, plume_top, Color(fc2.r, fc2.g, fc2.b, a), 3.5)
		e.draw_circle(plume_top, 3.0 * bulk, Color(fc2.r * 1.1, fc2.g * 1.1, fc2.b * 1.1, a))

	# ── maul/club ── a thick blunt-headed weapon hauled along the facing: a heavy haft + a fat
	# rectangular hammer-head, the bruiser's crushing tool (bigger for a general).
	var haft_w: float = (5.0 if boss else 4.0)
	var haft_base: Vector2 = fwd * r * 0.45
	var head_c: Vector2 = fwd * (r + (16.0 if boss else 11.0) * bulk)
	e.draw_line(haft_base, head_c, Color(0.30, 0.24, 0.20, a), haft_w)      # wooden haft
	# Blunt hammer head: a short thick perpendicular bar capping the haft.
	var hw: float = r * (0.34 if boss else 0.28) * bulk
	var hh: float = r * 0.14 * bulk
	var head_outer: Vector2 = head_c + fwd * hh
	var head_inner: Vector2 = head_c - fwd * hh
	var head_col: Color = Color(0.40, 0.36, 0.36, a)
	var head_quad := PackedVector2Array([
		head_inner + side * hw, head_outer + side * hw,
		head_outer - side * hw, head_inner - side * hw,
	])
	e.draw_colored_polygon(head_quad, head_col)
	e.draw_polyline(PackedVector2Array([
		head_inner + side * hw, head_outer + side * hw,
		head_outer - side * hw, head_inner - side * hw, head_inner + side * hw,
	]), Color(0.55, 0.50, 0.48, a), 2.0)
