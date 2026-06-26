class_name MordredArt
extends RefCounted
## Mordred, the TRAITOR PRINCE — the usurper knight who would be king, and the final boss of the
## Battle of Camlann. Drawn on Enemy `e` (a CanvasItem) in LOCAL space (Vector2.ZERO = centre).
## Beautify the traitor HERE, in isolation (one agent, one file) without touching Enemy.gd or any
## sibling art. He reads instantly as a FALLEN champion — kin to the Camelot knights but corrupted:
## dark ornate ARMOUR in rebel black-purple, a broken spiked CROWN clamped over the helm, a flowing
## rebel CAPE trailing behind, a cruel dark BLADE with a faint violet edge, and an AURA OF TREACHERY
## (a dark/violet shadow-halo around him). His look is "mordred"; his faction is "rebel".
##
## Since `e.is_general` (he IS the named usurper general), make him GRANDER — a richer broken crown,
## a longer blade, a heavier shadow-halo and more menace — so the boss towers over the rabble.
##
## Reads e.radius / e._face / e._alpha (MULTIPLY into EVERY alpha) / e.faction_color() / e.is_general.
## Allocation-light cheap `_draw` only — no image assets, no shaders, no threads, no per-frame arrays
## beyond the few short polygons/polylines below; STATIC (no `_t`) so nothing churns on the web build.
## SIMPLE (non-self-intersecting) polygons only.

static func draw(e) -> void:
	var a: float = e._alpha
	if a <= 0.0:
		return
	var r: float = e.radius
	var general: bool = e.is_general
	var s: float = 1.28 if general else 1.0

	var fwd: Vector2 = Vector2(cos(e._face), sin(e._face))
	var side: Vector2 = Vector2(-fwd.y, fwd.x)
	var fc: Color = e.faction_color()                          # rebel black-purple ≈ (0.52, 0.33, 0.60)

	# ── palette: lean the rebel hue DARKER for plate and HOTTER/brighter for the treacherous glow ──
	var plate_dark: Color = Color(fc.r * 0.30, fc.g * 0.22, fc.b * 0.40, a)     # shadowed black-violet plate
	var plate_mid: Color = Color(fc.r * 0.58, fc.g * 0.42, fc.b * 0.72, a)      # lit plate
	var plate_hi: Color = Color(fc.r * 0.82 + 0.12, fc.g * 0.58, fc.b * 0.92, a) # edge highlight on plate
	var cape_col: Color = Color(fc.r * 0.66, fc.g * 0.42, fc.b * 0.80, a)       # rebel cape body
	var violet: Color = Color(0.66, 0.34, 0.92, a)                             # treacherous violet glow
	var violet_hot: Color = Color(0.82, 0.50, 1.0, a)                          # hot core of the glow
	var crown_gold: Color = Color(0.70, 0.60, 0.34, a)                         # tarnished, fallen gold
	var blade_steel: Color = Color(0.40, 0.36, 0.46, a)                        # dark, cold steel

	# ── AURA OF TREACHERY: a dark shadow pooled under him + a faint violet halo ring, drawn FIRST so
	# the body sits over it. A general gets a heavier, wider shadow and a second outer ring. STATIC. ──
	var shadow_r: float = r * (1.45 if general else 1.22)
	e.draw_circle(Vector2.ZERO, shadow_r, Color(fc.r * 0.18, fc.g * 0.12, fc.b * 0.24, a * 0.42))
	e.draw_arc(Vector2.ZERO, shadow_r, 0.0, TAU, 30, Color(violet.r, violet.g, violet.b, a * 0.46), 1.6 * s)
	if general:
		e.draw_arc(Vector2.ZERO, shadow_r * 1.18, 0.0, TAU, 34,
			Color(violet.r, violet.g, violet.b, a * 0.24), 1.4)
		# Four ragged shadow-spikes at the diagonals — treachery clawing outward (no per-frame alloc).
		var q: float = 0.7071068
		var d0: Vector2 = Vector2(q, q)
		var d1: Vector2 = Vector2(-q, q)
		var spk: Color = Color(violet.r, violet.g, violet.b, a * 0.34)
		e.draw_line(d0 * shadow_r * 1.05, d0 * shadow_r * 1.34, spk, 2.0)
		e.draw_line(d1 * shadow_r * 1.05, d1 * shadow_r * 1.34, spk, 2.0)
		e.draw_line(-d0 * shadow_r * 1.05, -d0 * shadow_r * 1.34, spk, 2.0)
		e.draw_line(-d1 * shadow_r * 1.05, -d1 * shadow_r * 1.34, spk, 2.0)

	# ── flowing rebel CAPE trailing BEHIND the facing: a wide tapered fan of dark purple sweeping back
	# from the shoulders, with a brighter hem and a central fold so it reads as torn royal cloth. A
	# SIMPLE triangle-fan polygon (convex), longer for the general. ──
	var rear: Vector2 = -fwd * (r * 0.58 * s)
	var spread: float = r * (0.92 * s)
	var trail: float = r * ((2.6 if general else 2.0) * s)
	var cape_lt: Vector2 = rear + side * spread
	var cape_rt: Vector2 = rear - side * spread
	var cape_tip: Vector2 = -fwd * trail
	var cape := PackedVector2Array([cape_lt, cape_tip, cape_rt])
	e.draw_colored_polygon(cape, Color(cape_col.r * 0.7, cape_col.g * 0.7, cape_col.b * 0.7, a * 0.5))
	# A central fold crease (darker) + the two trailing edges (a touch brighter hem) → cloth, not blob.
	e.draw_line(rear, cape_tip, Color(plate_dark.r, plate_dark.g, plate_dark.b, a * 0.6), 2.0 * s)
	var hem_col := Color(cape_col.r * 1.1, cape_col.g * 0.9, cape_col.b * 1.1, a * 0.62)
	e.draw_line(cape_lt, cape_tip, hem_col, 1.6 * s)
	e.draw_line(cape_rt, cape_tip, hem_col, 1.6 * s)

	# ── dark ornate ARMOURED body: a heavy plate ring with a faction-tinted gorget band across the
	# chest (the forward arc) and two bright edge highlights so the steel reads as ornate, not flat. ──
	e.draw_arc(Vector2.ZERO, r * 0.66, 0.0, TAU, 22, plate_dark, 3.6 * s)
	e.draw_arc(Vector2.ZERO, r * 0.66, e._face - 0.85, e._face + 0.85, 12, plate_mid, 2.6 * s)
	# A bright forward gorget seam catching the light at the throat (a short lit arc on the chest).
	e.draw_arc(Vector2.ZERO, r * 0.66, e._face - 0.4, e._face + 0.4, 8, plate_hi, 1.6 * s)
	# A pauldron stud on each shoulder (side points) — small ornate rivets in tarnished gold.
	e.draw_circle(side * (r * 0.6), 2.0 * s, crown_gold)
	e.draw_circle(-side * (r * 0.6), 2.0 * s, crown_gold)

	# ── closed dark HELM forward of centre, with two cold violet eye-slits glaring out. ──
	var helm: Vector2 = fwd * r * 0.40
	e.draw_circle(helm, r * (0.30 * s), Color(plate_dark.r * 1.1, plate_dark.g * 1.1, plate_dark.b * 1.15, a))
	e.draw_arc(helm, r * (0.30 * s), 0.0, TAU, 12, plate_mid, 1.4 * s)
	# A grim visor brow line + two narrow violet eye-glows under it.
	e.draw_line(helm + side * (r * 0.2) + fwd * (r * 0.04), helm - side * (r * 0.2) + fwd * (r * 0.04),
		Color(0.05, 0.03, 0.08, a), 2.0 * s)
	e.draw_circle(helm + side * (r * 0.10) + fwd * (r * 0.12), 1.6 * s, violet_hot)
	e.draw_circle(helm - side * (r * 0.10) + fwd * (r * 0.12), 1.6 * s, violet_hot)

	# ── broken/spiked dark CROWN clamped over the helm: the usurper's stolen crown. A ring band of
	# tarnished gold with jagged spikes rising from it — one spike SNAPPED short (broken) to mark the
	# crown he was never meant to wear. Spikes are explicit short lines (no per-frame array alloc).
	# Anchored to the helm in the FACING FRAME (the spikes radiate FORWARD along `fwd`, like the other
	# units' crests) so the crown stays over the brow whichever way Mordred faces — top-down, the head
	# reads toward the facing. ──
	var brow: Vector2 = helm + fwd * (r * 0.18 * s)
	# Crown band: a short arc hugging the brow of the helm (front-facing).
	e.draw_arc(brow, r * (0.30 * s), e._face - 1.15, e._face + 1.15, 12, crown_gold, 2.4 * s)
	# Five crown spikes fanning out over the brow; the centre one is the TALLEST, an outer one is BROKEN.
	var spike_n: int = 5
	for i in range(spike_n):
		var t: float = (float(i) / float(spike_n - 1)) - 0.5      # -0.5 .. +0.5 across the brow
		var base_p: Vector2 = brow + side * (t * r * 0.62 * s)
		# height: tall in the centre, shorter at the edges; one edge spike snapped short (broken crown).
		var tall: float = r * (0.40 * s) * (1.0 - abs(t) * 0.9)
		var broken: bool = (i == spike_n - 1)                     # right-most spike is snapped
		var h: float = tall * (0.42 if broken else 1.0)
		var tip_p: Vector2 = base_p + fwd * h                     # spikes radiate forward, facing-relative
		e.draw_line(base_p, tip_p, crown_gold, (2.6 if i == 2 else 2.0) * s)
		if broken:
			# a jagged snap stub leaning off the break, so it clearly reads as broken, not just short.
			e.draw_line(tip_p, tip_p + side * (r * 0.10 * s) + fwd * (r * 0.04 * s),
				Color(crown_gold.r * 0.8, crown_gold.g * 0.8, crown_gold.b * 0.8, a), 1.6 * s)
		else:
			# a tiny dark-violet jewel on each intact spike-tip — corrupted regalia.
			e.draw_circle(tip_p, 1.6 * s, Color(violet.r, violet.g, violet.b, a * 0.9))

	# ── cruel dark BLADE held forward: a long straight sword in cold dark steel with a faint VIOLET
	# edge glow running its length, an ornate dark crossguard, and a violet pommel jewel. Longer and
	# meaner for the general. The blade is the traitor's signature — a corrupted champion's sword. ──
	var reach: float = r + (34.0 if general else 24.0)
	var base_b: Vector2 = fwd * (r * 0.30)
	var tip_b: Vector2 = fwd * reach
	# faint violet edge glow UNDER the blade (drawn first, slightly offset to one side as the lit edge).
	e.draw_line(base_b + side * (1.6 * s), tip_b + side * (1.6 * s),
		Color(violet.r, violet.g, violet.b, a * 0.5), (5.0 if general else 4.0))
	# the dark blade body over the glow.
	e.draw_line(base_b, tip_b, blade_steel, (3.4 if general else 2.8))
	# a thin cold fuller highlight down the spine + a violet point at the tip.
	e.draw_line(base_b, tip_b, Color(0.58, 0.54, 0.66, a * 0.7), 1.0)
	e.draw_circle(tip_b, (3.5 if general else 2.6), violet_hot)
	# ornate dark crossguard: a swept bar with two down-curled quillons, dark steel with gold edging.
	var guard: Vector2 = fwd * (r + 4.0)
	var gw: float = 7.0 * s
	var ql: Vector2 = guard + side * gw
	var qr: Vector2 = guard - side * gw
	e.draw_line(ql, qr, blade_steel, 3.2 * s)
	e.draw_line(ql, qr, crown_gold, 1.2 * s)
	# down-curled quillon tips (curling back toward the grip) so the guard reads cruel and ornate.
	e.draw_line(ql, ql - fwd * (r * 0.16 * s), crown_gold, 2.0 * s)
	e.draw_line(qr, qr - fwd * (r * 0.16 * s), crown_gold, 2.0 * s)
	# a violet pommel jewel at the grip — the dark heart of the blade.
	e.draw_circle(base_b, 2.6 * s, Color(violet.r, violet.g, violet.b, a))
