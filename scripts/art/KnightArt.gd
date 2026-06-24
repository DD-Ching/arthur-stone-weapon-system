class_name KnightArt
extends RefCounted
## The ELITE knight silhouette — a champion of the field: a crested/plumed helm, a long swept
## (curved) blade with an ornate crossguard, and a flowing CAPE in the faction colour trailing
## behind the facing. The sharpest, most striking unit, distinct from the bulky-but-blunt heavy.
## Drawn on Enemy `e`. Beautify the knight HERE.
##
## When `e.is_general` (named knight warlords — 呂布 Lu Bu / 關羽 Guan Yu): make it LEGENDARY —
## a grand crest/halo ring, a bigger blade, a richer faction cape — so the warlord stands out.
## Allocation-light: cheap `_draw` only, no per-frame arrays beyond the few short polylines below;
## every alpha is multiplied by `e._alpha`.

static func draw(e) -> void:
	var a: float = e._alpha
	var r: float = e.radius
	var fwd: Vector2 = Vector2(cos(e._face), sin(e._face))
	var side: Vector2 = Vector2(-fwd.y, fwd.x)
	var fc: Color = e.faction_color()
	var general: bool = e.is_general
	# Generals are scaled up across the board so the warlord reads as larger-than-life.
	var s: float = 1.32 if general else 1.0

	# ── Flowing cape in the faction colour, trailing BEHIND the facing ──
	# A wide tapered fan of the kingdom's hue sweeping back from the shoulders, with a darker
	# inner fold so it reads as cloth, not a flat blob. Drawn first so the body sits over it.
	var rear: Vector2 = -fwd * r * (0.62 * s)
	var spread: float = r * (0.95 * s)
	var trail: float = r * ((2.5 if general else 1.9) * s)
	var cape_lt: Vector2 = rear + side * spread
	var cape_rt: Vector2 = rear - side * spread
	var cape_tip: Vector2 = -fwd * trail
	var cape_col := Color(fc.r, fc.g, fc.b, a * (0.5 if general else 0.42))
	var cape := PackedVector2Array([cape_lt, cape_tip, cape_rt])
	e.draw_colored_polygon(cape, cape_col)
	# A central fold + the trailing edge, a touch brighter, to give the cloth a crease and a hem.
	var fold_col := Color(fc.r * 0.62, fc.g * 0.62, fc.b * 0.62, a * 0.55)
	e.draw_line(rear, cape_tip, fold_col, 2.0 * s)
	var hem_col := Color(
		min(fc.r * 1.25 + 0.1, 1.0), min(fc.g * 1.25 + 0.1, 1.0), min(fc.b * 1.25 + 0.1, 1.0),
		a * 0.6)
	e.draw_line(cape_lt, cape_tip, hem_col, 1.6 * s)
	e.draw_line(cape_rt, cape_tip, hem_col, 1.6 * s)

	# ── Polished armour body ring ──
	var steel := Color(0.85, 0.86, 0.92, a)
	e.draw_arc(Vector2.ZERO, r * 0.66, 0.0, TAU, 20, steel, 3.0 * s)
	# A faction-tinted gorget band on the chest (the forward arc) marks allegiance on the armour.
	var band := Color(fc.r * 0.8 + 0.15, fc.g * 0.8 + 0.15, fc.b * 0.8 + 0.15, a * 0.85)
	e.draw_arc(Vector2.ZERO, r * 0.66, e._face - 0.75, e._face + 0.75, 10, band, 2.5 * s)

	# ── Crested / plumed helm, forward of centre ──
	# A bright helm dome, then a crest plume of the faction colour rising up over it.
	var helm: Vector2 = fwd * r * 0.42
	e.draw_circle(helm, r * (0.3 * s), Color(0.92, 0.93, 1.0, a))
	# Helm rim as a full-circle arc (matches the codebase's ring convention; no draw_circle outline
	# overload, which keeps it unambiguous across the 4.3 CI / 4.7 dev split).
	e.draw_arc(helm, r * (0.3 * s), 0.0, TAU, 12, Color(0.55, 0.57, 0.66, a), 1.5 * s)
	# Crest: a small fan of faction-coloured plumes arcing back over the helm.
	var crest_base: Vector2 = helm - fwd * r * 0.05
	var crest_col := Color(fc.r, fc.g, fc.b, a)
	var crest := PackedVector2Array([
		crest_base + side * r * 0.18,
		crest_base + fwd * r * (0.34 * s) + side * r * 0.05,
		crest_base + fwd * r * (0.2 * s) - side * r * 0.18,
	])
	e.draw_polyline(crest, crest_col, 2.2 * s)
	e.draw_line(crest_base, crest_base + fwd * r * (0.34 * s), crest_col, 2.4 * s)

	# ── Long swept (curved) blade with an ornate crossguard ──
	# The blade is the knight's signature: a long, slightly curved sabre, longer for generals.
	var reach: float = r + (30.0 if general else 22.0)
	var base: Vector2 = fwd * r * 0.3
	var tip: Vector2 = fwd * reach + side * (r * 0.18 * s)   # swept curve: tip drifts to one side
	var mid: Vector2 = (base + tip) * 0.5 + side * (r * 0.16 * s)  # control bulge → curved spine
	var blade_col := Color(0.95, 0.96, 1.0, a)
	# Approximate the curved blade as a 3-point polyline (base → curved mid → tip): cheap, no array
	# rebuild beyond this short one, and reads as a sweeping sabre rather than a straight pole.
	var blade := PackedVector2Array([base, mid, tip])
	e.draw_polyline(blade, blade_col, (3.6 if general else 3.0))
	# A bright point at the tip, larger for the legendary blade.
	e.draw_circle(tip, (4.0 if general else 3.0), Color(1.0, 1.0, 1.0, a))
	# Ornate crossguard: a swept bar with two small upturned quillons, gold-toned.
	var guard: Vector2 = fwd * (r + 4.0)
	var gold := Color(0.95, 0.82, 0.4, a)
	var gw: float = 7.0 * s
	var ql: Vector2 = guard + side * gw
	var qr: Vector2 = guard - side * gw
	e.draw_line(ql, qr, gold, 3.0 * s)
	# Upturned quillon tips (curling toward the blade) so the guard reads as ornate, not a plain bar.
	e.draw_line(ql, ql + fwd * (r * 0.16 * s), gold, 2.2 * s)
	e.draw_line(qr, qr + fwd * (r * 0.16 * s), gold, 2.2 * s)
	# A small pommel jewel at the grip in the faction colour.
	e.draw_circle(base, 2.5 * s, crest_col)

	if not general:
		return

	# ── LEGENDARY: a grand crest / halo ring around the warlord ──
	# A faintly glowing faction-coloured halo ring marks the named general apart on a crowded field.
	var halo := Color(fc.r, fc.g, fc.b, a * 0.5)
	e.draw_arc(Vector2.ZERO, r * 1.18, 0.0, TAU, 28, halo, 2.5)
	e.draw_arc(Vector2.ZERO, r * 1.34, 0.0, TAU, 30, Color(fc.r, fc.g, fc.b, a * 0.25), 1.5)
	# Four radiant crest spokes (a regal sunburst) at the diagonals, so the halo reads as a crown
	# of light rather than a plain circle. Four explicit short lines — no per-frame array alloc.
	var spoke := Color(min(fc.r + 0.2, 1.0), min(fc.g + 0.2, 1.0), min(fc.b + 0.2, 1.0), a * 0.6)
	var q: float = 0.7071068
	var d0 := Vector2(q, q)
	var d1 := Vector2(-q, q)
	e.draw_line(d0 * r * 1.2, d0 * r * 1.5, spoke, 2.0)
	e.draw_line(d1 * r * 1.2, d1 * r * 1.5, spoke, 2.0)
	e.draw_line(-d0 * r * 1.2, -d0 * r * 1.5, spoke, 2.0)
	e.draw_line(-d1 * r * 1.2, -d1 * r * 1.5, spoke, 2.0)
