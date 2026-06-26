class_name SorceressArt
extends RefCounted
## Morgan le Fay — a malevolent ENCHANTRESS of dark magic. Drawn on Enemy `e` (a CanvasItem) in
## LOCAL space (Vector2.ZERO = centre). Beautify the sorceress HERE, in isolation (one agent, one
## file) without touching Enemy.gd or any sibling art. She reads instantly as "the sorceress" vs
## the soldier banners: a graceful skirted ROBE in dark violet, a pointed HOOD shadowing the face,
## a tall STAFF topped with a glowing arcane ORB, and a static swirl of DARK MAGIC around her — a
## runic ring + a few violet/magenta motes. Since `e.is_general`, her presence is imposing: a
## richer aura and a brighter orb. (Enemy.gd separately draws her morale-aura ring; not here.)
##
## Reads e.radius / e._face / e._alpha (MULTIPLY into EVERY alpha) / e.faction_color() / e.is_general.
## Allocation-light _draw only — a GENTLE STATIC swirl, no per-frame motion, no heavy work, no threads.

static func draw(e) -> void:
	var a: float = e._alpha
	if a <= 0.0:
		return
	var r: float = e.radius
	var boss: bool = e.is_general

	# Facing frame — the staff is held to one side, the hood points forward-up.
	var fwd: Vector2 = Vector2(cos(e._face), sin(e._face))
	var side: Vector2 = Vector2(-fwd.y, fwd.x)

	# ── magic palette: her faction is Mordred's rebel black-violet; lean it darker for cloth and
	# brighter/hotter for the arcane glow so the magic pops against the robe. ──
	var fc: Color = e.faction_color()                          # rebel ≈ (0.52, 0.33, 0.60)
	var robe_dark: Color = Color(fc.r * 0.34, fc.g * 0.30, fc.b * 0.46, a)      # deep shadowed violet
	var robe_mid: Color = Color(fc.r * 0.62, fc.g * 0.50, fc.b * 0.78, a)       # lit violet
	var robe_hi: Color = Color(0.62, 0.46, 0.82, a)            # highlight on a fold
	var arcane: Color = Color(0.74, 0.42, 0.95, a)             # bright arcane violet
	var arcane_hot: Color = Color(0.92, 0.58, 1.0, a)          # hot magenta core of the orb
	var trim_gold: Color = Color(0.86, 0.74, 0.42, a)          # a touch of cold gold trim

	# ── flowing SKIRTED ROBE: a graceful gown that flares from the shoulders to a wide trailing
	# hem. A SIMPLE convex-ish polygon (kept simple for the triangulator): narrow at the shoulders,
	# bowing out to a broad hem with a soft point at the centre front. ──
	var sh: float = r * 0.46                                   # shoulder half-width
	var hem_y: float = r * 1.18                                # how far the hem trails below
	var hem: float = r * 0.96                                  # hem half-width
	var robe := PackedVector2Array([
		side * sh + Vector2(0.0, -r * 0.34),                   # right shoulder
		side * (r * 0.66) + Vector2(0.0, r * 0.30),            # right waist, swelling out
		side * hem + Vector2(0.0, hem_y * 0.82),               # right hem corner
		side * (hem * 0.42) + Vector2(0.0, hem_y),             # right of the centre front point
		Vector2(0.0, hem_y + r * 0.14),                        # centre-front hem point (drapes lowest)
		-side * (hem * 0.42) + Vector2(0.0, hem_y),            # left of the centre front point
		-side * hem + Vector2(0.0, hem_y * 0.82),              # left hem corner
		-side * (r * 0.66) + Vector2(0.0, r * 0.30),           # left waist
		-side * sh + Vector2(0.0, -r * 0.34),                  # left shoulder
	])
	e.draw_colored_polygon(robe, robe_dark)

	# A few fold lines down the skirt catch the light — cheap polylines, give the cloth depth.
	var waist: Vector2 = Vector2(0.0, r * 0.12)
	e.draw_line(waist, Vector2(0.0, hem_y + r * 0.10), robe_mid, 2.0)
	e.draw_line(waist + side * (r * 0.12), side * (hem * 0.5) + Vector2(0.0, hem_y * 0.9), robe_mid, 1.4)
	e.draw_line(waist - side * (r * 0.12), -side * (hem * 0.5) + Vector2(0.0, hem_y * 0.9), robe_mid, 1.4)
	# A bright gold hem trim seam tracing the lower edge — a finished, regal gown.
	e.draw_line(side * hem + Vector2(0.0, hem_y * 0.82), Vector2(0.0, hem_y + r * 0.14), trim_gold, 1.4)
	e.draw_line(-side * hem + Vector2(0.0, hem_y * 0.82), Vector2(0.0, hem_y + r * 0.14), trim_gold, 1.4)

	# ── a cinched bodice/sash at the waist (a slim lit band so the silhouette has an hourglass). ──
	e.draw_line(waist + side * (sh * 0.7), waist - side * (sh * 0.7), robe_mid, 3.0)
	e.draw_line(waist + side * (sh * 0.7), waist - side * (sh * 0.7), robe_hi, 1.0)

	# ── pointed HOOD shadowing the face: a tall cowl rising above the body, pulled forward over the
	# brow. SIMPLE triangle for the hood + a darker void where the face hides in shadow. ──
	var hood_tip: Vector2 = fwd * (r * 0.18) + Vector2(0.0, -r - r * 0.72)   # peak, tugged forward
	var hood := PackedVector2Array([
		hood_tip,
		side * (r * 0.50) + Vector2(0.0, -r * 0.10),
		-side * (r * 0.50) + Vector2(0.0, -r * 0.10),
	])
	e.draw_colored_polygon(hood, robe_mid)
	# The hood's own shadow seam, and the dark FACE VOID under the cowl (a small black-violet oval).
	e.draw_line(hood_tip, side * (r * 0.50) + Vector2(0.0, -r * 0.10), robe_dark, 2.0)
	e.draw_line(hood_tip, -side * (r * 0.50) + Vector2(0.0, -r * 0.10), robe_dark, 2.0)
	var face_c: Vector2 = fwd * (r * 0.10) + Vector2(0.0, -r * 0.28)
	e.draw_circle(face_c, r * 0.26, Color(0.06, 0.03, 0.10, a))
	# Two cold glowing eyes in the shadowed face — a malevolent gleam.
	e.draw_circle(face_c + side * (r * 0.10) + fwd * (r * 0.05), 1.5, arcane_hot)
	e.draw_circle(face_c - side * (r * 0.10) + fwd * (r * 0.05), 1.5, arcane_hot)

	# ── tall STAFF held to her side, topped with a glowing arcane ORB. ──
	var staff_x: Vector2 = side * (r * 1.02)
	var staff_base: Vector2 = staff_x + Vector2(0.0, hem_y * 0.78)
	var staff_top: Vector2 = staff_x + Vector2(0.0, -r - r * 0.85)
	e.draw_line(staff_base, staff_top, Color(0.30, 0.22, 0.20, a), 2.6)     # dark wood haft
	e.draw_line(staff_base, staff_top, Color(0.50, 0.40, 0.34, a), 1.0)     # haft highlight
	# A claw/socket cradling the orb: two short prongs framing it.
	e.draw_line(staff_top + side * 3.0, staff_top + Vector2(0.0, -5.0), trim_gold, 1.6)
	e.draw_line(staff_top - side * 3.0, staff_top + Vector2(0.0, -5.0), trim_gold, 1.6)

	# The ORB: a bright hot core, a violet body, and a soft outer glow halo. Brighter for a general.
	var orb_c: Vector2 = staff_top + Vector2(0.0, -7.0)
	var orb_r: float = 5.5 if boss else 4.2
	e.draw_circle(orb_c, orb_r + 3.5, Color(arcane.r, arcane.g, arcane.b, a * 0.22))   # outer glow
	e.draw_circle(orb_c, orb_r, arcane)
	e.draw_circle(orb_c, orb_r * 0.55, arcane_hot)                                      # hot core
	e.draw_circle(orb_c + Vector2(-1.0, -1.2), orb_r * 0.25, Color(1.0, 0.92, 1.0, a)) # specular glint
	# A ring of power around the orb (a thin halo arc).
	e.draw_arc(orb_c, orb_r + 5.0, 0.0, TAU, 18, Color(arcane.r, arcane.g, arcane.b, a * 0.5), 1.2)

	# ── DARK MAGIC swirling around her: a faint RUNIC RING under the body and a few arcane MOTES.
	# All STATIC (no `_t`) and allocation-light — drawn with a fixed phase so it reads as a frozen,
	# ominous swirl rather than animated churn (keeps the single-threaded web build light). ──
	var ring_r: float = r * 1.55 if boss else r * 1.35
	e.draw_arc(Vector2.ZERO, ring_r, 0.0, TAU, 30, Color(arcane.r, arcane.g, arcane.b, a * 0.34), 1.4)
	# A second, broken inner runic ring (an arc with a gap) — looks like a conjured sigil.
	e.draw_arc(Vector2.ZERO, ring_r * 0.74, 0.4, 0.4 + TAU * 0.78,
		22, Color(arcane_hot.r, arcane_hot.g, arcane_hot.b, a * 0.30), 1.2)

	# Arcane motes orbiting the sigil — fixed angles so the swirl is static. A general gets more.
	var mote_count: int = 7 if boss else 5
	for i in range(mote_count):
		var ang: float = (TAU * float(i) / float(mote_count)) + 0.55   # fixed swirl phase
		var rad: float = ring_r * (0.82 + 0.16 * float((i * 5) % 3))   # stagger the radii a touch
		var p: Vector2 = Vector2(cos(ang), sin(ang)) * rad
		var hot: bool = (i % 2) == 0
		var mc: Color = arcane_hot if hot else arcane
		e.draw_circle(p, 2.0 if hot else 1.5, Color(mc.r, mc.g, mc.b, a * 0.85))
		# A short trailing wisp behind each mote (tangential), so the motes feel in motion-frozen orbit.
		var tang: Vector2 = Vector2(-sin(ang), cos(ang))
		e.draw_line(p, p - tang * 5.0, Color(mc.r, mc.g, mc.b, a * 0.40), 1.0)

	# A couple of rising magic wisps streaming up off her free hand / shoulders, opposite the staff.
	var hand: Vector2 = -side * (r * 0.72) + Vector2(0.0, r * 0.06)
	e.draw_circle(hand, 2.0, Color(arcane_hot.r, arcane_hot.g, arcane_hot.b, a * 0.9))   # spell in hand
	e.draw_polyline(PackedVector2Array([
		hand,
		hand + Vector2(-r * 0.10, -r * 0.34),
		hand + Vector2(r * 0.04, -r * 0.64),
		hand + Vector2(-r * 0.08, -r * 0.92),
	]), Color(arcane.r, arcane.g, arcane.b, a * 0.55), 1.4)
