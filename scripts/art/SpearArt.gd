class_name SpearArt
extends RefCounted
## The spearman silhouette: a long reaching shaft + a clear leaf head + a faction pennon, so its
## threat RANGE reads from afar and its allegiance reads up close. Distinct from the short-sword
## soldier — everything here is about LENGTH and the leaf blade. Drawn on Enemy `e` (a CanvasItem).
## Beautify the spear HERE, in isolation. Allocation-light: only the few small local Vectors below,
## and e._alpha is multiplied into every colour.

static func draw(e) -> void:
	var a: float = e._alpha
	var r: float = e.radius
	var fwd: Vector2 = Vector2(cos(e._face), sin(e._face))
	var side: Vector2 = Vector2(-fwd.y, fwd.x)
	var fc: Color = e.faction_color()

	# A small helm dot on the head, so the unit has a body to throw the long spear FROM.
	e.draw_circle(fwd * r * 0.35, r * 0.30, Color(0.84, 0.8, 0.72, a))

	# A small round buckler on the off-hand (rim + faint boss), distinct from the soldier's,
	# tinted toward the faction so a packed line of spears still reads its colours.
	var buck: Vector2 = -side * r * 0.62
	e.draw_arc(buck, r * 0.34, 0.0, TAU, 12, Color(0.6, 0.62, 0.68, a), 2.5)
	e.draw_circle(buck, r * 0.12, Color(fc.r, fc.g, fc.b, a * 0.7))

	# ── the spear ── a long two-handed shaft along the facing; its REACH is the whole point.
	var grip: Vector2 = fwd * r * 0.1            # held near the body
	var neck: Vector2 = fwd * (r + 26.0)         # where the head meets the shaft
	var tip: Vector2 = fwd * (r + 40.0)          # the point — well beyond a sword's reach
	e.draw_line(grip, neck, Color(0.66, 0.55, 0.4, a), 3.0)
	# A darker grip-wrap band near the hands so the haft reads as gripped, not a bare stick.
	e.draw_line(grip, fwd * (r + 4.0), Color(0.4, 0.32, 0.24, a), 4.0)

	# A clear LEAF blade: two edges bowing out to a widest point, then in to the tip — a spearhead,
	# not a knife. Bright steel so the point catches the eye at the end of the long shaft.
	var steel: Color = Color(0.9, 0.92, 0.97, a)
	var belly: Vector2 = fwd * (r + 32.0)        # the blade's widest point
	var halfw: float = 5.0
	e.draw_line(neck, belly + side * halfw, steel, 2.5)   # near edge: neck → belly
	e.draw_line(belly + side * halfw, tip, steel, 2.5)    # near edge: belly → tip
	e.draw_line(neck, belly - side * halfw, steel, 2.5)   # far edge: neck → belly
	e.draw_line(belly - side * halfw, tip, steel, 2.5)    # far edge: belly → tip
	e.draw_line(neck, tip, Color(0.75, 0.78, 0.86, a), 1.5)  # midrib for depth
	e.draw_circle(tip, 2.0, Color(0.96, 0.97, 1.0, a))       # a bright point

	# A small faction PENNON + tassel just behind the head: a triangle of cloth streaming off the
	# off-side of the shaft, plus a couple of short tassel strands, in the faction colour.
	var pen: Vector2 = fwd * (r + 22.0)
	e.draw_colored_polygon(
		PackedVector2Array([pen, pen - side * 9.0 - fwd * 5.0, pen - fwd * 8.0]),
		Color(fc.r, fc.g, fc.b, a * 0.95))
	e.draw_line(pen, pen - side * 4.0 + fwd * 3.0, Color(fc.r, fc.g, fc.b, a * 0.8), 1.5)
	e.draw_line(pen, pen - side * 2.0 + fwd * 4.0, Color(fc.r, fc.g, fc.b, a * 0.8), 1.5)
