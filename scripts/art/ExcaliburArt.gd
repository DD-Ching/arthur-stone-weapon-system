class_name ExcaliburArt
extends RefCounted
## A Camelot CHAMPION wielding the radiant Excalibur — a holy blade of light (Lancelot / Gawain /
## Percival share this look). A crested helm, an armoured silhouette and a flowing faction CAPE, but
## the signature is the SWORD: a long white-blue blade wrapped in a soft golden HOLY GLOW, an ornate
## golden crossguard + pommel, a gleaming tip and a few rays of light, so it reads as legendary.
## Drawn on Enemy `e` (a CanvasItem) in LOCAL space (Vector2.ZERO = centre). Beautify it HERE only.
##
## When `e.is_general` (a named champion-general): make it GRANDER — a crown/halo of light, a longer
## and brighter blade, more rays — so the hero stands out on a crowded field.
##
## Allocation-light: cheap `_draw` only (locals + a few short PackedVector2Array polylines, no
## per-frame heap growth); EVERY Color alpha is multiplied by `e._alpha` so the defeat fade works.
## GDScript 4.3-safe: `e` is untyped, so every local that feeds a draw_* call is explicitly typed,
## and every draw_colored_polygon is a simple (non-self-intersecting) triangle.

static func draw(e) -> void:
	var a: float = e._alpha
	var r: float = e.radius
	var fwd: Vector2 = Vector2(cos(e._face), sin(e._face))
	var side: Vector2 = Vector2(-fwd.y, fwd.x)
	var fc: Color = e.faction_color()                # Camelot gold for cape / trim / crest
	var general: bool = e.is_general
	# Champion-generals are scaled up across the board so the hero reads as larger-than-life.
	var s: float = 1.3 if general else 1.0

	# ── Flowing faction cape, trailing BEHIND the facing ──
	# A wide tapered fan of Camelot gold sweeping back from the shoulders, with a darker central
	# fold + a bright hem so it reads as cloth. Drawn first so the armoured body sits over it.
	var rear: Vector2 = -fwd * r * (0.6 * s)
	var spread: float = r * (0.92 * s)
	var trail: float = r * ((2.6 if general else 2.0) * s)
	var cape_lt: Vector2 = rear + side * spread
	var cape_rt: Vector2 = rear - side * spread
	var cape_tip: Vector2 = -fwd * trail
	var cape_col := Color(fc.r, fc.g, fc.b, a * (0.5 if general else 0.42))
	var cape := PackedVector2Array([cape_lt, cape_tip, cape_rt])
	e.draw_colored_polygon(cape, cape_col)
	var fold_col := Color(fc.r * 0.6, fc.g * 0.6, fc.b * 0.6, a * 0.55)
	e.draw_line(rear, cape_tip, fold_col, 2.0 * s)
	var hem_col := Color(
		min(fc.r * 1.25 + 0.1, 1.0), min(fc.g * 1.25 + 0.1, 1.0), min(fc.b * 1.25 + 0.1, 1.0),
		a * 0.6)
	e.draw_line(cape_lt, cape_tip, hem_col, 1.5 * s)
	e.draw_line(cape_rt, cape_tip, hem_col, 1.5 * s)

	# ── Polished plate armour ──
	# A bright steel body ring with a faction-tinted gorget arc across the chest (the forward arc).
	var steel := Color(0.86, 0.88, 0.96, a)
	e.draw_arc(Vector2.ZERO, r * 0.66, 0.0, TAU, 22, steel, 3.0 * s)
	var gorget := Color(fc.r * 0.8 + 0.16, fc.g * 0.8 + 0.16, fc.b * 0.8 + 0.16, a * 0.85)
	e.draw_arc(Vector2.ZERO, r * 0.66, e._face - 0.7, e._face + 0.7, 10, gorget, 2.6 * s)
	# A tiny golden Camelot pauldron stud on each shoulder (perpendicular to the facing).
	var stud := Color(0.96, 0.84, 0.42, a * 0.9)
	e.draw_circle(side * r * 0.66, 2.0 * s, stud)
	e.draw_circle(-side * r * 0.66, 2.0 * s, stud)

	# ── Crested / plumed helm, forward of centre ──
	var helm: Vector2 = fwd * r * 0.42
	e.draw_circle(helm, r * (0.3 * s), Color(0.93, 0.94, 1.0, a))
	# Helm rim as a full ring (no draw_circle outline overload → unambiguous across 4.3 / 4.7).
	e.draw_arc(helm, r * (0.3 * s), 0.0, TAU, 12, Color(0.56, 0.58, 0.68, a), 1.5 * s)
	# A vertical visor slit so the helm reads as a knight's, not a bald dome.
	e.draw_line(helm + side * r * 0.04, helm - side * r * 0.04, Color(0.2, 0.22, 0.3, a), 1.4 * s)
	# Crest plume: a small swept fan of faction colour arcing back over the crown of the helm.
	var crest_base: Vector2 = helm - fwd * r * 0.04
	var crest_col := Color(fc.r, fc.g, fc.b, a)
	var crest := PackedVector2Array([
		crest_base + side * r * 0.16,
		crest_base + fwd * r * (0.32 * s) + side * r * 0.04,
		crest_base + fwd * r * (0.18 * s) - side * r * 0.16,
	])
	e.draw_polyline(crest, crest_col, 2.0 * s)
	e.draw_line(crest_base, crest_base + fwd * r * (0.32 * s), crest_col, 2.2 * s)

	# ── EXCALIBUR: a radiant blade of white-blue steel wrapped in a holy golden glow ──
	# Geometry shared by the glow, the blade and the highlight so they overlay exactly.
	var reach: float = r + (40.0 if general else 30.0)
	var grip: Vector2 = fwd * r * 0.28
	var tip: Vector2 = fwd * reach
	# Soft, wide, low-alpha HOLY GLOW stroke behind the blade — two stacked passes so the halo of
	# light falls off softly toward the edges instead of a single hard band.
	var glow_out := Color(1.0, 0.92, 0.55, a * 0.22)
	var glow_in := Color(1.0, 0.96, 0.7, a * 0.32)
	e.draw_line(grip, tip, glow_out, (12.0 if general else 10.0) * 1.0)
	e.draw_line(grip, tip, glow_in, (7.0 if general else 6.0))
	# The bright blade: white-blue steel, with a thin near-white highlight down its spine.
	var blade_col := Color(0.9, 0.95, 1.0, a)
	e.draw_line(grip, tip, blade_col, (4.0 if general else 3.4))
	e.draw_line(grip + fwd * r * 0.4, tip - fwd * 3.0, Color(1.0, 1.0, 1.0, a * 0.9), 1.4)
	# A gleaming point at the tip (a soft outer flare + a hard white core).
	e.draw_circle(tip, (5.0 if general else 4.0), Color(1.0, 1.0, 0.85, a * 0.45))
	e.draw_circle(tip, (3.0 if general else 2.4), Color(1.0, 1.0, 1.0, a))

	# ── Ornate golden crossguard + grip + pommel ──
	var guard: Vector2 = fwd * (r + 4.0)
	var gold := Color(0.97, 0.83, 0.36, a)
	var gw: float = 7.0 * s
	var ql: Vector2 = guard + side * gw
	var qr: Vector2 = guard - side * gw
	e.draw_line(ql, qr, gold, 3.0 * s)
	# Quillon tips curling toward the blade so the guard reads as ornate, not a plain bar.
	e.draw_line(ql, ql + fwd * (r * 0.18 * s), gold, 2.2 * s)
	e.draw_line(qr, qr + fwd * (r * 0.18 * s), gold, 2.2 * s)
	# A wrapped grip from the guard back to the pommel, and a faction-jewelled pommel knob.
	e.draw_line(guard, grip, Color(0.55, 0.4, 0.22, a), 2.4 * s)
	e.draw_circle(grip, 2.8 * s, gold)
	e.draw_circle(grip, 1.4 * s, crest_col)

	# ── A few rays of light off the blade so it reads as a sword of legend ──
	# Two short sparkle crosses near the tip — cheap explicit lines, no per-frame arrays.
	var spark := Color(1.0, 1.0, 0.92, a * 0.7)
	var near: Vector2 = tip - fwd * (r * 0.5)
	e.draw_line(near - side * 4.0, near + side * 4.0, spark, 1.2)
	e.draw_line(near - fwd * 4.0, near + fwd * 4.0, spark, 1.2)
	var far: Vector2 = tip + fwd * 4.0
	e.draw_line(far - side * 3.0, far + side * 3.0, spark, 1.0)

	if not general:
		return

	# ── LEGENDARY: a crown/halo of holy light around the champion-general ──
	# A faintly glowing golden halo ring + a softer outer ring marks the hero apart on a crowded
	# field; four radiant spokes at the diagonals turn it into a crown of light, not a plain circle.
	var halo := Color(min(fc.r + 0.06, 1.0), min(fc.g + 0.1, 1.0), min(fc.b + 0.1, 1.0), a * 0.5)
	e.draw_arc(Vector2.ZERO, r * 1.18, 0.0, TAU, 30, halo, 2.4)
	e.draw_arc(Vector2.ZERO, r * 1.36, 0.0, TAU, 32, Color(halo.r, halo.g, halo.b, a * 0.25), 1.4)
	var spoke := Color(1.0, 0.96, 0.7, a * 0.6)
	var q: float = 0.7071068
	var d0 := Vector2(q, q)
	var d1 := Vector2(-q, q)
	e.draw_line(d0 * r * 1.22, d0 * r * 1.52, spoke, 2.0)
	e.draw_line(d1 * r * 1.22, d1 * r * 1.52, spoke, 2.0)
	e.draw_line(-d0 * r * 1.22, -d0 * r * 1.52, spoke, 2.0)
	e.draw_line(-d1 * r * 1.22, -d1 * r * 1.52, spoke, 2.0)
	# One more sparkle further out along the legendary blade (reuse the tip from above).
	var mid: Vector2 = tip - fwd * (r * 1.1)
	e.draw_line(mid - side * 5.0, mid + side * 5.0, spoke, 1.2)
	e.draw_line(mid - fwd * 5.0, mid + fwd * 5.0, spoke, 1.2)
