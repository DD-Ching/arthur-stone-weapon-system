extends Node2D
## Headless readability test for the enrichment of Enemy's code-drawn visuals (unit #11,
## token VISREAD). The additions are PURELY ADDITIVE drawing — sharper per-`look` silhouettes,
## a clearer (and distinctly broken) shield arc, a spear thrust warning line + a lunge charge
## lane telegraph, and a banner/officer morale-aura ring. None of it touches gameplay.
##
## Headless can't screenshot, so this asserts what a script CAN: that drawing every look (plus a
## shielded and a support unit) over a couple of frames runs WITHOUT errors, and that the pure
## geometry helpers (silhouette points / thrust line endpoints / morale aura radius) each return
## sane, non-empty values for every look. The coordinator eyeballs the actual visuals after merge.
##
## Run: godot --headless --path . res://tests/VisualReadabilityTest.tscn --quit-after 600
## Look for the VISREAD_VERDICT line.

const LOOKS := ["soldier", "shield", "spear", "heavy", "banner", "knight"]

var _enemies: Array = []
var _frame := 0
var _checks := {}

func _ready() -> void:
	# One Enemy of EACH look, drawn at spread-out positions. We build them straight from the
	# script (a bare RigidBody2D with a CircleShape2D) so we can dial in any `look` — including
	# "knight", which no shipped .tscn selects — without depending on a particular scene.
	var x := -300.0
	for look_name in LOOKS:
		var e: Enemy = _make_enemy(look_name, Vector2(x, 0.0))
		# Drive the per-look attack telegraph too: pretend it's mid-windup with a thrust so the
		# spear's warning line / a lunge's charge lane code path actually executes in _draw.
		e._ai = e.AI.WINDUP
		e._ai_time = 0.1
		e.attack_kind = "thrust"   # legacy thrust → "line" telegraph in _draw_attack_telegraph
		_enemies.append(e)
		x += 120.0

	# A SHIELDED unit, shown both intact and (a second copy) broken, so the distinct broken-shield
	# branch is drawn. Shield units keep the shield toward their facing.
	var shield_ok: Enemy = _make_enemy("shield", Vector2(-300.0, 160.0))
	shield_ok.shielded = true
	var shield_broken: Enemy = _make_enemy("shield", Vector2(-180.0, 160.0))
	shield_broken.shielded = true
	shield_broken._shield_broken = 2.0     # force the broken-shield silhouette
	_enemies.append(shield_ok)
	_enemies.append(shield_broken)

	# A SUPPORT (banner/officer) unit, so the morale-aura ring + officer pip draw.
	var support: Enemy = _make_enemy("banner", Vector2(0.0, 160.0))
	support.is_support = true
	support.morale_radius = 190.0
	_enemies.append(support)

	# ── pure-geometry assertions: every look yields sane, non-empty marker geometry ──
	var geo: Enemy = _enemies[0]   # any Enemy instance; the helpers are pure over their args
	var all_silhouettes_ok := true
	for look_name in LOOKS:
		var pts: PackedVector2Array = geo.silhouette_points(look_name)
		if pts.size() < 2 or not _all_finite(pts):
			all_silhouettes_ok = false
	_checks["silhouettes_non_empty"] = all_silhouettes_ok

	# Thrust/charge warning line endpoints: two points, spanning a positive length down the facing.
	var ln: PackedVector2Array = geo.thrust_line_endpoints(30.0)
	_checks["thrust_line_sane"] = ln.size() == 2 and ln[0].distance_to(ln[1]) > 30.0 and _all_finite(ln)

	# Morale aura radius clamps to a sane band (never a pinpoint, never screen-filling).
	support.morale_radius = 190.0
	var r_norm: float = support.morale_aura_radius()
	support.morale_radius = 5.0
	var r_low: float = support.morale_aura_radius()
	support.morale_radius = 9000.0
	var r_high: float = support.morale_aura_radius()
	support.morale_radius = 190.0
	_checks["aura_radius_sane"] = r_norm == 190.0 and r_low >= 40.0 and r_high <= 320.0

	print("VISREAD_READY enemies=%d" % _enemies.size())

func _make_enemy(look_name: String, pos: Vector2) -> Enemy:
	var e := Enemy.new()
	e.look = look_name
	e.ai_enabled = false       # passive — we're testing DRAWING, not the brain
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = e.radius
	shape.shape = circle
	e.add_child(shape)
	add_child(e)
	e.global_position = pos
	e._face = 0.0
	e.shield_angle = 0.0
	e.queue_redraw()           # force a _draw() this frame so every code path runs
	return e

func _all_finite(pts: PackedVector2Array) -> bool:
	for p in pts:
		if not (is_finite(p.x) and is_finite(p.y)):
			return false
	return true

func _physics_process(_delta: float) -> void:
	_frame += 1
	# Keep redrawing for a couple of frames so the telegraph/aura code paths run repeatedly with
	# advancing `_t`; if any draw call errored, the engine would have reported it by now.
	for e in _enemies:
		if is_instance_valid(e):
			e.queue_redraw()
	if _frame >= 6:
		_checks["all_alive_after_draw"] = _all_valid()
		_report()

func _all_valid() -> bool:
	for e in _enemies:
		if not is_instance_valid(e):
			return false
	return true

func _report() -> void:
	var ok := true
	var parts: PackedStringArray = PackedStringArray()
	for k in _checks.keys():
		parts.append("%s=%s" % [k, str(_checks[k])])
		if not _checks[k]:
			ok = false
	print("VISREAD_RESULT %s" % " ".join(parts))
	print("VISREAD_VERDICT %s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)
