class_name BlackKnightArt
extends RefCounted
## The Black Knight — a dread mercenary champion of pure black plate: a horned closed great-helm
## with a single glowing RED eye-slit, heavy pauldrons, a tattered dark mantle trailing behind the
## facing, and a wicked dark blade with a faint red edge-glow, all wrapped in an ominous shadow-aura.
##
## FACTION-INDEPENDENT: he reads BLACK whichever side tints him — never call e.faction_color(). The
## only colour on him is cold steel edge-light (so the silhouette stays legible) and the dread RED
## of his eye and blade. He IS a general (e.is_general), so the look is built imposing by default and
## grander still when promoted: a wider halo of dread, a longer blade, more red menace.
##
## Drawn on Enemy `e` (a CanvasItem) in LOCAL space (Vector2.ZERO = centre). Allocation-light: cheap
## `_draw` only, no per-frame arrays beyond the few short polygons below; every alpha is multiplied
## by e._alpha so he fades out cleanly on defeat. All draw_colored_polygon shapes are SIMPLE
## (non-self-intersecting) triangles/quads.

static func draw(e) -> void:
	var a: float = e._alpha
	var r: float = e.radius
	var fwd: Vector2 = Vector2(cos(e._face), sin(e._face))
	var side: Vector2 = Vector2(-fwd.y, fwd.x)
	var general: bool = e.is_general
	# He is built imposing by default; promotion to general scales him up further.
	var s: float = 1.22 if general else 1.0

	# ── Ominous shadow-aura ──
	# Two faint near-black rings of dread bleeding outward, drawn first so everything sits over them.
	# Larger / darker for the general so the named champion radiates menace on a crowded field.
	e.draw_circle(Vector2.ZERO, r * (1.45 * s), Color(0.02, 0.0, 0.02, a * (0.16 if general else 0.10)))
	e.draw_circle(Vector2.ZERO, r * (1.12 * s), Color(0.03, 0.01, 0.03, a * (0.22 if general else 0.16)))

	# ── Tattered dark mantle, trailing BEHIND the facing ──
	# A ragged cloak of near-black cloth sweeping back from the shoulders. Drawn as two simple
	# triangles (each a SIMPLE polygon) so the trailing hem reads jagged/torn rather than a clean fan.
	var rear: Vector2 = -fwd * r * (0.58 * s)
	var spread: float = r * (0.92 * s)
	# Keep the trailing point inside the ~radius+40 art budget even at large ship radii (he is r≈29):
	# cap the cape reach so the longest tip (trail + the r*0.30 torn offset) stays within r + 40.
	var trail: float = min(r * ((2.4 if general else 1.95) * s), r + 32.0)
	var cape_lt: Vector2 = rear + side * spread
	var cape_rt: Vector2 = rear - side * spread
	var tip_lt: Vector2 = -fwd * trail + side * (r * 0.30 * s)   # one torn point
	var tip_rt: Vector2 = -fwd * (trail * 0.86) - side * (r * 0.46 * s)  # a second, ragged point
	var cape_col := Color(0.05, 0.05, 0.07, a * 0.62)
	e.draw_colored_polygon(PackedVector2Array([cape_lt, tip_lt, rear]), cape_col)
	e.draw_colored_polygon(PackedVector2Array([rear, tip_rt, cape_rt]), cape_col)
	# A cold steel hem-glint along the trailing edges so the torn silhouette still catches the eye.
	var hem := Color(0.42, 0.45, 0.52, a * 0.5)
	e.draw_line(cape_lt, tip_lt, hem, 1.5 * s)
	e.draw_line(cape_rt, tip_rt, hem, 1.5 * s)
	e.draw_line(rear, -fwd * trail * 0.9, Color(0.08, 0.08, 0.10, a * 0.6), 2.0 * s)

	# ── Gleaming black plate body ──
	# A filled near-black torso disc with a cold steel edge-light ring so the body reads as polished
	# plate, not a void. The forward arc is brightened (light catches the breastplate) for volume.
	e.draw_circle(Vector2.ZERO, r * (0.7 * s), Color(0.07, 0.07, 0.09, a))
	e.draw_arc(Vector2.ZERO, r * (0.7 * s), 0.0, TAU, 22, Color(0.30, 0.32, 0.40, a * 0.9), 2.4 * s)
	# Breastplate sheen: a brighter forward arc where light glances off the curved plate.
	e.draw_arc(Vector2.ZERO, r * (0.7 * s), e._face - 0.85, e._face + 0.85, 12,
		Color(0.52, 0.55, 0.64, a * 0.85), 2.0 * s)

	# ── Heavy pauldrons ──
	# Two broad spiked shoulder-plates flanking the helm. Each is a SIMPLE quad of dark plate with a
	# steel edge-line, giving the champion a wide, hulking, armoured silhouette.
	var sh: Vector2 = fwd * r * (0.12 * s)            # shoulder line, just forward of centre
	var pw: float = r * (0.62 * s)                    # how far out each pauldron reaches
	var pf: float = r * (0.40 * s)                    # forward/back depth of the plate
	for sgn in [1.0, -1.0]:
		var o: Vector2 = side * (sgn * pw)
		var p_in: Vector2 = sh + side * (sgn * r * 0.30 * s)
		var p_out: Vector2 = sh + o
		var p_fwd: Vector2 = p_out + fwd * pf
		var p_back: Vector2 = p_out - fwd * pf
		e.draw_colored_polygon(PackedVector2Array([p_in, p_fwd, p_out, p_back]),
			Color(0.06, 0.06, 0.08, a))
		e.draw_line(p_fwd, p_out, Color(0.40, 0.43, 0.50, a * 0.85), 1.8 * s)
		e.draw_line(p_out, p_back, Color(0.22, 0.24, 0.30, a * 0.8), 1.6 * s)
		# A cruel spike jutting out from the crown of each pauldron.
		e.draw_line(p_out, p_out + side * (sgn * r * 0.28 * s) - fwd * r * 0.06 * s,
			Color(0.34, 0.36, 0.44, a * 0.9), 2.0 * s)

	# ── Horned closed great-helm with a single glowing red eye-slit ──
	var helm: Vector2 = fwd * r * (0.46 * s)
	var helm_r: float = r * (0.34 * s)
	e.draw_circle(helm, helm_r, Color(0.05, 0.05, 0.07, a))
	# Steel rim of the helm (full ring, matching the codebase ring convention).
	e.draw_arc(helm, helm_r, 0.0, TAU, 14, Color(0.34, 0.36, 0.44, a * 0.9), 1.8 * s)
	# A vertical reinforcing brow-ridge down the face of the helm.
	e.draw_line(helm + fwd * helm_r * 0.2, helm - fwd * helm_r * 0.9,
		Color(0.24, 0.26, 0.32, a * 0.8), 1.6 * s)
	# Two swept HORNS curving up and back from the helm — the dread crown.
	var horn_base_l: Vector2 = helm + side * (helm_r * 0.7)
	var horn_base_r: Vector2 = helm - side * (helm_r * 0.7)
	var horn_len: float = r * ((0.95 if general else 0.78) * s)
	var horn_col := Color(0.10, 0.10, 0.13, a)
	var horn_edge := Color(0.40, 0.42, 0.50, a * 0.85)
	# Each horn: base → swept mid → curling tip (a short 3-point polyline; cheap, reads as a curve).
	var hl_mid: Vector2 = horn_base_l + side * (helm_r * 0.5) - fwd * (horn_len * 0.4)
	var hl_tip: Vector2 = horn_base_l + side * (helm_r * 0.4) - fwd * horn_len + fwd * (horn_len * 0.18)
	e.draw_polyline(PackedVector2Array([horn_base_l, hl_mid, hl_tip]), horn_col, 3.0 * s)
	e.draw_polyline(PackedVector2Array([horn_base_l, hl_mid, hl_tip]), horn_edge, 1.2 * s)
	var hr_mid: Vector2 = horn_base_r - side * (helm_r * 0.5) - fwd * (horn_len * 0.4)
	var hr_tip: Vector2 = horn_base_r - side * (helm_r * 0.4) - fwd * horn_len + fwd * (horn_len * 0.18)
	e.draw_polyline(PackedVector2Array([horn_base_r, hr_mid, hr_tip]), horn_col, 3.0 * s)
	e.draw_polyline(PackedVector2Array([horn_base_r, hr_mid, hr_tip]), horn_edge, 1.2 * s)
	# The single glowing RED eye-slit: a short forward bar of dread, with a hot core + a soft glow.
	var eye: Vector2 = helm + fwd * (helm_r * 0.55)
	var eye_w: float = helm_r * 0.5
	e.draw_circle(eye, helm_r * (0.7 if general else 0.55), Color(0.7, 0.02, 0.0, a * 0.32))  # glow
	e.draw_line(eye + side * eye_w, eye - side * eye_w, Color(1.0, 0.18, 0.12, a), 2.6 * s)   # slit
	e.draw_circle(eye, 1.6 * s, Color(1.0, 0.55, 0.4, a))                                      # hot core

	# ── Wicked dark blade with a faint red edge-glow ──
	# A long cruel sword along the facing, longer for the general. Near-black steel with a cold edge
	# highlight on one side and a faint RED malice-glow on the other.
	var reach: float = r + (38.0 if general else 28.0)
	var base: Vector2 = fwd * r * (0.34 * s)
	var tip: Vector2 = fwd * reach + side * (r * 0.10 * s)         # a slight wicked sweep
	var mid: Vector2 = (base + tip) * 0.5 + side * (r * 0.10 * s)
	# Faint red malice-glow tracing the blade (drawn first, thicker, under the steel).
	e.draw_polyline(PackedVector2Array([base, mid, tip]), Color(0.85, 0.08, 0.05, a * 0.45),
		(6.0 if general else 5.0))
	# The blade body: dark steel.
	e.draw_polyline(PackedVector2Array([base, mid, tip]), Color(0.18, 0.19, 0.24, a),
		(4.2 if general else 3.4))
	# Cold edge-highlight along the spine of the blade.
	e.draw_polyline(PackedVector2Array([base, mid, tip]), Color(0.55, 0.58, 0.66, a * 0.85),
		(1.6 if general else 1.4))
	# A wicked point at the tip.
	e.draw_circle(tip, (4.0 if general else 3.2), Color(0.80, 0.82, 0.90, a))
	# Cruel crossguard: a swept dark bar with two down-curved quillons.
	var guard: Vector2 = fwd * (r + 4.0)
	var gw: float = r * (0.32 * s)
	var ql: Vector2 = guard + side * gw
	var qr: Vector2 = guard - side * gw
	var guard_col := Color(0.16, 0.17, 0.21, a)
	e.draw_line(ql, qr, guard_col, 3.2 * s)
	e.draw_line(ql, ql - fwd * (r * 0.18 * s), Color(0.34, 0.36, 0.44, a * 0.85), 2.2 * s)
	e.draw_line(qr, qr - fwd * (r * 0.18 * s), Color(0.34, 0.36, 0.44, a * 0.85), 2.2 * s)
	# A dread red gem set in the pommel at the grip.
	e.draw_circle(base, 2.6 * s, Color(0.85, 0.10, 0.08, a))

	if not general:
		return

	# ── GRANDER (general): a wider halo of dread ──
	# A faint ring of red-black malice and a darker outer shadow mark the named dread champion apart.
	e.draw_arc(Vector2.ZERO, r * 1.6, 0.0, TAU, 30, Color(0.45, 0.03, 0.02, a * 0.30), 2.4)
	e.draw_arc(Vector2.ZERO, r * 1.82, 0.0, TAU, 32, Color(0.04, 0.0, 0.05, a * 0.22), 1.6)
	# Four jagged red rays at the diagonals — a dark crown of dread rather than a clean ring.
	# Four explicit short lines, no per-frame array alloc.
	var ray := Color(0.9, 0.10, 0.06, a * 0.4)
	var q: float = 0.7071068
	var d0 := Vector2(q, q)
	var d1 := Vector2(-q, q)
	e.draw_line(d0 * r * 1.55, d0 * r * 1.95, ray, 2.2)
	e.draw_line(d1 * r * 1.55, d1 * r * 1.95, ray, 2.2)
	e.draw_line(-d0 * r * 1.55, -d0 * r * 1.95, ray, 2.2)
	e.draw_line(-d1 * r * 1.55, -d1 * r * 1.95, ray, 2.2)
