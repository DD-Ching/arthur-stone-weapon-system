class_name BannerArt
extends RefCounted
## The officer/standard-bearer silhouette: a grand military STANDARD — a tall pole topped by a
## spear-finial and a crossbar, with a large FLOWING pennant in the faction colour, tassels, and
## a darker fold so it reads as cloth catching the wind. This is the MORALE unit (the banner you
## protect or the officer you defeat), so it must read clearly from across the field. Drawn on
## Enemy `e` (a CanvasItem) in LOCAL space (Vector2.ZERO = centre). Beautify the banner HERE, in
## isolation. Reads e.radius / e._alpha / e.faction / e.faction_color(). Allocation-light _draw only.

static func draw(e) -> void:
	var a: float = e._alpha
	var r: float = e.radius

	# Faction cloth colour — but neutral's flat grey makes a dull standard, so fall back to a warm
	# crimson-gold for the unaligned officer. Allied/raider factions keep their kingdom hue.
	var cloth: Color = e.faction_color()
	if String(e.faction) == "neutral":
		cloth = Color(0.82, 0.28, 0.22)   # warm crimson default
	cloth.a = a

	# ── pole geometry (LOCAL space; the standard rises ABOVE the unit) ──
	var base: Vector2 = Vector2(0.0, -r + 2.0)          # where the shaft meets the body
	var top: Vector2 = Vector2(0.0, -r - 40.0)          # just under the finial
	var wood: Color = Color(0.46, 0.34, 0.22, a)
	var wood_hi: Color = Color(0.62, 0.48, 0.32, a)
	e.draw_line(base, top, wood, 3.0)
	e.draw_line(base + Vector2(-0.9, 0.0), top + Vector2(-0.9, 0.0), wood_hi, 1.0)  # shaft highlight

	# ── spear-point finial crowning the pole ──
	var tip: Vector2 = Vector2(0.0, -r - 50.0)
	var gold: Color = Color(0.92, 0.80, 0.34, a)
	var gold_dim: Color = Color(0.68, 0.55, 0.22, a)
	e.draw_colored_polygon(
		PackedVector2Array([tip, top + Vector2(-3.5, 0.0), top + Vector2(3.5, 0.0)]), gold)
	e.draw_circle(top + Vector2(0.0, 1.0), 2.4, gold_dim)   # collar bead under the blade

	# ── crossbar the pennant hangs from, with a tassel at each end ──
	var bar_y: float = -r - 36.0
	var bar_half: float = 9.0
	e.draw_line(Vector2(-bar_half, bar_y), Vector2(bar_half, bar_y), gold_dim, 2.0)
	_tassel(e, Vector2(-bar_half, bar_y), gold, cloth)
	_tassel(e, Vector2(bar_half, bar_y), gold, cloth)

	# ── the FLOWING pennant: a large swallow-tailed banner with a gentle static fold ──
	# Built from the crossbar down the upper shaft. The fly edge bows out then notches into a
	# forked tail; a couple of interior verts give it a soft S-curve so it reads as cloth in wind.
	var hx: float = bar_half                # hoist clings to the pole side of the bar
	var hy0: float = bar_y + 1.0            # top of cloth
	var hy1: float = bar_y + 24.0           # bottom of cloth at the hoist
	var fly: float = 26.0                   # how far the banner streams out
	var poly: PackedVector2Array = PackedVector2Array([
		Vector2(-hx, hy0),                  # top, against the pole
		Vector2(-hx + fly * 0.55, hy0 + 1.5),   # upper fly, lifted
		Vector2(-hx + fly, hy0 + 5.0),          # leading tip, billowed out
		Vector2(-hx + fly * 0.72, hy0 + 12.0),  # ← inward notch (the swallow tail fork)
		Vector2(-hx + fly, hy1 + 4.0),          # lower trailing tip
		Vector2(-hx + fly * 0.5, hy1 + 1.0),    # lower fly, sagging
		Vector2(-hx, hy1),                  # bottom, against the pole
	])
	e.draw_colored_polygon(poly, cloth)

	# A darker fold band sweeping across the cloth gives it depth (a static catch of light),
	# and a thin trim along the top + bottom edges frames it as a finished standard.
	var shade: Color = Color(cloth.r * 0.62, cloth.g * 0.62, cloth.b * 0.62, a * 0.85)
	e.draw_line(Vector2(-hx + 3.0, hy0 + 8.0), Vector2(-hx + fly * 0.78, hy0 + 9.5), shade, 3.0)
	var trim: Color = Color(
		minf(cloth.r + 0.18, 1.0), minf(cloth.g + 0.18, 1.0), minf(cloth.b + 0.18, 1.0), a)
	e.draw_line(Vector2(-hx, hy0), Vector2(-hx + fly, hy0 + 5.0), trim, 1.2)   # top edge
	e.draw_line(Vector2(-hx, hy1), Vector2(-hx + fly * 0.5, hy1 + 1.0), trim, 1.2)  # bottom edge

	# A small faction-coloured emblem disc on the cloth marks whose standard this is.
	e.draw_circle(Vector2(-hx + fly * 0.3, (hy0 + hy1) * 0.5 + 1.0), 2.6, trim)

## A hanging tassel (cord + tuft) at a crossbar knot. Pulled out so we avoid a typed loop over an
## untyped array literal, which trips GDScript 4.3's Variant inference.
static func _tassel(e, knot: Vector2, gold: Color, cloth: Color) -> void:
	e.draw_circle(knot, 1.8, gold)
	e.draw_line(knot, knot + Vector2(0.0, 7.0), gold, 1.4)        # tassel cord
	e.draw_circle(knot + Vector2(0.0, 7.5), 1.6, cloth)          # tassel tuft
