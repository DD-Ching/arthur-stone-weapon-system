class_name SoldierArt
extends RefCounted
## The light footman silhouette. Drawn on the Enemy `e` (a CanvasItem) by `UnitArt`.
## Beautify the soldier HERE, in isolation — this file is the only thing that owns the look.
## Reads e.radius / e._face / e._alpha (and may use e.faction_color() / e.is_general for flavour).
##
## Reads as an AGILE LIGHT infantryman, distinct from the bulky shield/heavy units: a sleek
## peaked helm, a short sword held forward, a small round buckler on the off-hand, a hint of a
## tunic/cloak, and a faction-coloured sash worn across the chest. All cheap `_draw` primitives,
## locals only, every alpha multiplied by `e._alpha` so the defeat fade carries through.

static func draw(e) -> void:
	var a: float = e._alpha
	var r: float = e.radius
	var fwd: Vector2 = Vector2(cos(e._face), sin(e._face))
	var side: Vector2 = Vector2(-fwd.y, fwd.x)
	var fc: Color = e.faction_color()

	# Palettes (locals so faded units dim cleanly via `a`).
	var steel: Color = Color(0.84, 0.86, 0.93, a)     # bright blade / helm sheen
	var steel_dim: Color = Color(0.62, 0.65, 0.72, a) # buckler rim / shadowed steel
	var leather: Color = Color(0.46, 0.34, 0.22, a)   # grip / buckler face
	var cloth: Color = Color(0.30, 0.27, 0.24, a)     # tunic / cloak hint
	var sash: Color = Color(fc.r, fc.g, fc.b, a)       # faction scarf across the chest

	# ── Tunic / cloak hint: a short cloth sweep trailing off the rear shoulder, so the body
	# reads as a lightly-clad runner rather than a bare disc. One thin filled wedge.
	var c0: Vector2 = -fwd * r * 0.2 + side * r * 0.45
	var c1: Vector2 = -fwd * (r + 9.0) + side * r * 0.9
	var c2: Vector2 = -fwd * (r + 7.0) - side * r * 0.1
	e.draw_colored_polygon(PackedVector2Array([c0, c1, c2]), cloth)

	# ── Faction sash worn across the chest, from the near shoulder down across to the off-hip.
	# A bold faction-coloured stroke so allegiance reads at a glance, placed differently from
	# Enemy's rear pennant so it doesn't double up. Capped with a small knot at the hip.
	var sh: Vector2 = fwd * r * 0.25 + side * r * 0.78    # near shoulder
	var hip: Vector2 = -fwd * r * 0.2 - side * r * 0.7    # opposite hip
	e.draw_line(sh, hip, sash, 3.0)
	e.draw_circle(hip, r * 0.16, sash)

	# ── Small round buckler on the off-hand (the side AWAY from the sword), held out a touch.
	# A leather face + a bright steel rim + a tiny central boss — clearly a small shield, not the
	# big rim of a shieldbearer.
	var buck: Vector2 = -side * (r * 0.62) + fwd * (r * 0.15)
	e.draw_circle(buck, r * 0.34, leather)
	e.draw_arc(buck, r * 0.34, 0.0, TAU, 14, steel_dim, 2.0)
	e.draw_circle(buck, r * 0.1, steel)

	# ── Sleek peaked helm: a small bright dome forward of centre with a short brow/nose ridge,
	# reading as a light open helm rather than a heavy great-helm.
	var head: Vector2 = fwd * r * 0.4
	e.draw_circle(head, r * 0.28, Color(0.92, 0.88, 0.78, a))   # face/dome
	e.draw_arc(head, r * 0.3, e._face - 2.0, e._face + 2.0, 12, steel, 2.0)  # helm crown sweep
	e.draw_line(head + fwd * r * 0.28, head + fwd * r * 0.5, steel, 1.5)     # brow/nose ridge

	# ── Short sword held forward along the facing: a leather grip + crossguard + a bright blade
	# with a sharpened point. Shorter and lighter than the knight's long blade.
	var grip0: Vector2 = fwd * r * 0.45 + side * r * 0.18
	var guard: Vector2 = fwd * (r + 2.0) + side * r * 0.18
	var tip: Vector2 = fwd * (r + 15.0) + side * r * 0.18
	e.draw_line(grip0, guard, leather, 3.0)                       # grip
	e.draw_line(guard + side * 4.0, guard - side * 4.0, steel_dim, 2.0)  # crossguard
	e.draw_line(guard, tip, steel, 2.5)                          # blade
	e.draw_circle(tip, 1.8, Color(0.96, 0.97, 1.0, a))          # bright point
