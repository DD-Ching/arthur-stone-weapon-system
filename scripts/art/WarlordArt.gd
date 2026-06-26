class_name WarlordArt
extends RefCounted
## The Saxon Warlord (Cerdic) — a burly, fur-clad axe-lord: a HORNED iron helm, a shaggy FUR
## mantle over the shoulders, a broad armoured body, a braided beard + war-paint hint, and a great
## two-handed DANE AXE held across the body with a long haft and a big crescent steel blade that
## catches the light. Drawn on Enemy `e` (a CanvasItem) in LOCAL space (Vector2.ZERO = centre).
##
## Saxon moss-green accents (`e.faction_color()`) trim the fur cloak. When `e.is_general` he is a
## CHIEFTAIN: a heavier mantle, longer horns, a war-totem at his back and a bigger axe — an imposing
## boss who ends the Mount Badon battle. All drawing is allocation-light `_draw` (no assets/shaders/
## threads, no per-frame allocs beyond locals); every Color multiplies `e._alpha` so fades read, and
## every `draw_colored_polygon` is a SIMPLE (non-self-intersecting) quad/triangle.

static func draw(e) -> void:
	var a: float = e._alpha
	var r: float = e.radius
	var fwd: Vector2 = Vector2(cos(e._face), sin(e._face))
	var side: Vector2 = Vector2(-fwd.y, fwd.x)
	var boss: bool = e.is_general

	# A general chieftain looms a head larger so he towers over the raiders he leads.
	var bulk: float = 1.18 if boss else 1.0

	# Saxon moss-green, used to trim the fur cloak and the totem so his allegiance reads at a glance.
	var fc: Color = e.faction_color()
	var moss: Color = Color(fc.r * 0.85 + 0.04, fc.g * 0.85 + 0.06, fc.b * 0.75, a)
	var moss_lo: Color = Color(fc.r * 0.55, fc.g * 0.6, fc.b * 0.5, a * 0.85)

	# ── war-totem (general only) ── a tall tribal standard rising from his back: a dark pole topped
	# with a moss-bound skull-knot, planted BEHIND so the body/cloak sit in front of it.
	if boss:
		var pole_base: Vector2 = -fwd * r * 0.55
		var pole_top: Vector2 = -fwd * r * 0.30 + Vector2(0.0, -(r * 1.85))
		e.draw_line(pole_base, pole_top, Color(0.26, 0.20, 0.15, a), 3.5)
		# A bound cross-bar + a pale skull/horn knot crowning the totem.
		var bar_a: Vector2 = pole_top + side * (r * 0.34) + Vector2(0.0, r * 0.12)
		var bar_b: Vector2 = pole_top - side * (r * 0.34) + Vector2(0.0, r * 0.12)
		e.draw_line(bar_a, bar_b, Color(0.30, 0.23, 0.17, a), 2.5)
		e.draw_line(bar_a, bar_a + side * (r * 0.18) + Vector2(0.0, r * 0.3), moss, 2.0)
		e.draw_line(bar_b, bar_b - side * (r * 0.18) + Vector2(0.0, r * 0.3), moss, 2.0)
		e.draw_circle(pole_top + Vector2(0.0, -r * 0.18), r * 0.22, Color(0.80, 0.78, 0.70, a))
		e.draw_arc(pole_top + Vector2(0.0, -r * 0.18), r * 0.22, 0.0, TAU, 12, moss_lo, 2.0)

	# ── fur mantle ── a shaggy cloak draped over the shoulders, drawn FIRST as a broad fur collar so
	# the armour sits on top. A simple trapezoid fanned to the rear flanks, with a moss-green hem and
	# a ragged ring of fur tufts so it reads as a heavy pelt rather than a cape.
	var fur: Color = Color(0.34, 0.27, 0.20, a)
	var fur_hi: Color = Color(0.46, 0.38, 0.29, a)
	var mantle_w: float = r * (1.18 if boss else 1.02)
	var mantle_back: float = r * (1.5 if boss else 1.3)
	var hem_l: Vector2 = -fwd * mantle_back + side * mantle_w
	var hem_r: Vector2 = -fwd * mantle_back - side * mantle_w
	var sho_l: Vector2 = side * (r * 0.95 * bulk) + fwd * r * 0.1
	var sho_r: Vector2 = -side * (r * 0.95 * bulk) + fwd * r * 0.1
	# Simple (convex) trapezoid: front-left shoulder → rear-left hem → rear-right hem → front-right.
	e.draw_colored_polygon(PackedVector2Array([sho_l, hem_l, hem_r, sho_r]), fur)
	# A moss-green hem stroke along the cloak's trailing edge so the Saxon colour catches the eye.
	e.draw_line(hem_l, -fwd * (mantle_back + r * 0.1), moss, 2.5)
	e.draw_line(-fwd * (mantle_back + r * 0.1), hem_r, moss, 2.5)
	# Shaggy fur tufts: short bright strokes splayed around the collar arc so it reads as a pelt.
	var tufts: int = 9 if boss else 7
	for i in range(tufts):
		var t: float = float(i) / float(tufts - 1)          # 0..1 across the back arc
		var ang: float = PI * 0.45 + t * (PI * 1.1)          # sweep around the rear hemisphere
		var base_dir: Vector2 = fwd * cos(ang) + side * sin(ang)
		var p0: Vector2 = base_dir * (r * 0.72 * bulk)
		var p1: Vector2 = base_dir * (r * 0.98 * bulk)
		e.draw_line(p0, p1, fur_hi, 2.0)

	# ── body ── a broad dark mail torso: a filled disc + a heavy ring + a faint scale-row hint so he
	# reads as armoured, not a hoop.
	var body_r: float = r * 0.6 * bulk
	e.draw_circle(Vector2.ZERO, body_r, Color(0.24, 0.22, 0.20, a * 0.7))
	e.draw_arc(Vector2.ZERO, body_r, 0.0, TAU, 22, Color(0.30, 0.28, 0.26, a), 5.0 * bulk)
	e.draw_arc(Vector2.ZERO, body_r * 0.7, 0.0, TAU, 16, Color(0.40, 0.37, 0.33, a * 0.8), 2.0)
	# A studded belt line across the waist (perpendicular to facing) with a central buckle stud.
	var belt: Vector2 = -fwd * body_r * 0.15
	e.draw_line(belt + side * body_r * 0.85, belt - side * body_r * 0.85, Color(0.18, 0.14, 0.10, a), 3.0)
	e.draw_circle(belt, r * 0.1, Color(0.62, 0.5, 0.24, a))

	# ── horned iron helm ── a rounded grey helm pushed forward over a braided-beard hint, crowned by
	# a pair of curved horns sweeping out and up — the Saxon chieftain's unmistakable mark.
	var helm_c: Vector2 = fwd * r * 0.34
	var helm_r: float = r * 0.36 * bulk
	e.draw_circle(helm_c, helm_r, Color(0.44, 0.43, 0.46, a))
	e.draw_arc(helm_c, helm_r, 0.0, TAU, 14, Color(0.58, 0.57, 0.60, a), 2.0)
	# A nasal-guard bar down the face + two dark eye slits flanking it (a grim glare).
	var brow: Vector2 = helm_c + fwd * helm_r * 0.2
	e.draw_line(brow, helm_c + fwd * helm_r * 0.95, Color(0.30, 0.30, 0.33, a), 2.0)
	e.draw_circle(brow + side * helm_r * 0.45, 1.4, Color(0.06, 0.05, 0.05, a))
	e.draw_circle(brow - side * helm_r * 0.45, 1.4, Color(0.06, 0.05, 0.05, a))
	# Curved horns: a base on each side of the crown, an out-swept mid, a tip hooking up & forward.
	var horn_c: Color = Color(0.88, 0.84, 0.74, a)
	var horn_len: float = (1.0 if boss else 0.8)
	var horn_sides: Array[float] = [1.0, -1.0]
	for s in horn_sides:
		var hb: Vector2 = helm_c + side * helm_r * 0.7 * s - fwd * helm_r * 0.1
		var hm: Vector2 = hb + side * (helm_r * 0.85 * horn_len) * s - fwd * helm_r * 0.1
		var ht: Vector2 = hm + side * (helm_r * 0.35 * horn_len) * s + fwd * helm_r * 0.9 * horn_len
		e.draw_line(hb, hm, horn_c, 3.0 * bulk)
		e.draw_line(hm, ht, horn_c, 2.5 * bulk)

	# ── braided beard ── a blocky reddish beard spilling below the helm toward the body, with a
	# central braid stroke, so even helmed he reads as a bearded war-chief.
	var beard_c: Color = Color(0.52, 0.36, 0.22, a)
	var beard_top: Vector2 = helm_c - fwd * helm_r * 0.2
	var beard_tip: Vector2 = -fwd * (body_r * 0.55)
	e.draw_colored_polygon(PackedVector2Array([
		beard_top + side * helm_r * 0.55,
		beard_tip + side * helm_r * 0.2,
		beard_tip - side * helm_r * 0.2,
		beard_top - side * helm_r * 0.55,
	]), beard_c)
	e.draw_line(beard_top, beard_tip, Color(0.40, 0.27, 0.16, a), 2.0)
	# A streak of war-paint: a short bright moss slash across one cheek.
	e.draw_line(helm_c + side * helm_r * 0.6 + fwd * helm_r * 0.1,
		helm_c + side * helm_r * 0.3 + fwd * helm_r * 0.6, moss, 2.0)

	# ── pauldrons ── chunky fur-capped shoulder guards on each flank: a steel disc under a small fur
	# tuft, reinforcing the bulk of the frame.
	var pa: float = r * 0.82 * bulk
	var pr: float = r * 0.24 * bulk
	for s in horn_sides:
		var c: Vector2 = side * pa * s + fwd * r * 0.05
		e.draw_circle(c, pr, Color(0.32, 0.30, 0.30, a))
		e.draw_arc(c, pr, 0.0, TAU, 12, Color(0.46, 0.43, 0.43, a), 2.0)
		e.draw_line(c - fwd * pr, c - fwd * (pr + r * 0.18), fur_hi, 2.5)

	# ── great Dane axe ── a long haft held ACROSS the body (canted off the facing) with a big
	# crescent steel blade at the far end that catches the light, plus a butt-spike at the near end.
	# Cant the weapon ~25° off forward so it reads as carried across the chest, not as a lance.
	var cant: float = 0.42
	var axis: Vector2 = fwd * cos(cant) + side * sin(cant)
	var perp: Vector2 = Vector2(-axis.y, axis.x)
	var haft_len: float = r + (40.0 if boss else 30.0) * bulk
	var butt: Vector2 = -axis * (r * 0.7)
	var head: Vector2 = axis * haft_len
	e.draw_line(butt, head, Color(0.34, 0.25, 0.16, a), (5.5 if boss else 4.5))   # thick wooden haft
	e.draw_line(butt, butt - axis * (r * 0.22), Color(0.55, 0.55, 0.6, a), 3.0)   # iron butt-spike
	# A pair of binding rings along the haft, a little chieftain detail.
	e.draw_circle(axis * (haft_len * 0.45), 2.0, Color(0.5, 0.46, 0.4, a))
	e.draw_circle(axis * (haft_len * 0.7), 2.0, Color(0.5, 0.46, 0.4, a))
	# The crescent blade: a broad steel arc swept from a top horn to a bottom horn, bellying out
	# AWAY from the haft. Built as a simple quad (back edge near the haft, bellied cutting edge),
	# then a bright edge-line so it "catches the light".
	var blade_span: float = r * (1.05 if boss else 0.85)        # half-height of the blade along perp
	var belly: float = r * (0.85 if boss else 0.68)             # how far the edge bows outward
	var top_horn: Vector2 = head + perp * blade_span
	var bot_horn: Vector2 = head - perp * blade_span
	var edge_mid: Vector2 = head + axis * belly                 # outermost point of the cutting arc
	var back_in: Vector2 = head - axis * (r * 0.14)             # blade root, slightly behind the head
	var steel: Color = Color(0.74, 0.77, 0.82, a)
	var steel_hi: Color = Color(0.92, 0.95, 1.0, a)
	# SIMPLE (convex) quad: top horn → outer edge mid → bottom horn → inner root. Non-self-intersecting.
	e.draw_colored_polygon(PackedVector2Array([top_horn, edge_mid, bot_horn, back_in]), steel)
	# A bright cutting-edge polyline along the bellied side so the blade flashes.
	e.draw_polyline(PackedVector2Array([top_horn, edge_mid, bot_horn]), steel_hi, 2.5)
	# A dark socket where the blade meets the haft.
	e.draw_circle(head, r * 0.13, Color(0.22, 0.20, 0.18, a))
