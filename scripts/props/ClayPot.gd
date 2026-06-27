extends Breakable
## A fragile clay pot — a config of Breakable tuned to SHATTER on almost any scored hit
## (low max_health + low hard_hit) into a spray of small reddish shards. Pure look + tuning:
## the destruction comes from Breakable; this just draws the pot and lets the exports do the
## work (set on the .tscn: low health, low hard_hit, high debris_count, "SMASH" label).

func _draw() -> void:
	var lit := clampf(_flash / 0.18, 0.0, 1.0)
	var clay := Color(0.72, 0.34, 0.24, _alpha).lerp(Color(1, 1, 1, _alpha), lit)
	var rim := Color(0.52, 0.22, 0.15, _alpha)
	var r := radius
	# Round terracotta pot body.
	draw_circle(Vector2.ZERO, r, clay)
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 20, rim, 2.0)
	# A narrower neck/mouth ring on top for a pot read.
	draw_arc(Vector2(0.0, -r * 0.15), r * 0.55, 0.0, TAU, 14, rim, 2.0)
	# A small highlight so it reads as ceramic, not a ball.
	draw_circle(Vector2(-r * 0.3, -r * 0.3), r * 0.18, Color(1, 1, 1, 0.25 * _alpha))
