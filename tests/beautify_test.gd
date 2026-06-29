extends Node2D
## Headless readability test for the FACTION BEAUTIFICATION pass (token BEAUTIFY). The additions
## are PURELY ADDITIVE drawing in Enemy.gd: a modest body tint toward the unit's `faction_color()`,
## a faction emblem ring + cloak/pennant trim, and slightly richer per-`look` silhouettes. None of
## it touches movement / attack / health / AI.
##
## Headless can't screenshot, so this asserts what a script CAN:
##   1. Drawing every (look × faction) combination over a couple of frames runs WITHOUT errors and
##      leaves every unit alive (a draw crash would free / error the node).
##   2. `faction_color()` returns the expected hue per faction (briton≈blue, saxon≈green,
##      rebel≈purple, camelot≈gold, neutral≈grey) — checked by which channel dominates.
##   3. The pure `body_color()` helper reflects allegiance: for briton/saxon/rebel it shifts AWAY
##      from the neutral body colour and TOWARD that faction's colour; neutral stays ~unchanged.
##
## Run: godot --headless --path . res://tests/BeautifyTest.tscn --quit-after 600
## Look for the BEAUTIFY_VERDICT line.

const LOOKS := ["dummy", "soldier", "shield", "heavy", "spear", "banner", "knight"]
const FACTIONS := ["neutral", "camelot", "briton", "saxon", "rebel"]

var _enemies: Array = []
var _frame := 0
var _checks := {}

func _ready() -> void:
	# Build the full matrix: one Enemy of EACH look × EACH faction, drawn at spread-out positions.
	# Built straight from the script (a bare RigidBody2D + CircleShape2D) so any look/faction can be
	# dialled in without depending on a particular .tscn.
	var y := -260.0
	for look_name in LOOKS:
		var x := -300.0
		for fac in FACTIONS:
			var e: Enemy = _make_enemy(look_name, fac, Vector2(x, y))
			# Drive the per-look attack telegraph too: pretend it's mid-windup with a thrust so the
			# spear's warning line / a lunge's charge-lane code path actually executes in _draw.
			e._ai = e.AI.WINDUP
			e._ai_time = 0.1
			e.attack_kind = "thrust"
			_enemies.append(e)
			x += 130.0
		y += 80.0

	# Also force a SHIELDED + a BROKEN-shield + a SUPPORT unit so those branches draw alongside a
	# faction tint (the foundation + this pass must coexist with the v0.15 readability shapes).
	var shield_rebel: Enemy = _make_enemy("shield", "rebel", Vector2(-300.0, 320.0))
	shield_rebel.shielded = true
	var shield_broken: Enemy = _make_enemy("shield", "briton", Vector2(-160.0, 320.0))
	shield_broken.shielded = true
	shield_broken._shield_broken = 2.0
	var support_saxon: Enemy = _make_enemy("banner", "saxon", Vector2(0.0, 320.0))
	support_saxon.is_support = true
	support_saxon.morale_radius = 190.0
	_enemies.append(shield_rebel)
	_enemies.append(shield_broken)
	_enemies.append(support_saxon)

	# ── faction_color() hue assertions ─────────────────────────────────────────────────────────
	# Any Enemy instance suffices; faction_color() reads its own `faction` field, so set + read.
	var probe: Enemy = _enemies[0]
	probe.faction = "briton"
	var c_briton: Color = probe.faction_color()
	probe.faction = "saxon"
	var c_saxon: Color = probe.faction_color()
	probe.faction = "rebel"
	var c_rebel: Color = probe.faction_color()
	probe.faction = "camelot"
	var c_camelot: Color = probe.faction_color()
	probe.faction = "neutral"
	var c_neu: Color = probe.faction_color()
	probe.faction = "neutral"
	# Briton reads blue (blue dominant), Saxon green (green dominant), Rebel purple (red AND blue
	# both above green), Camelot gold (red and green high, blue low).
	_checks["briton_is_blue"] = c_briton.b > c_briton.r and c_briton.b > c_briton.g
	_checks["saxon_is_green"] = c_saxon.g > c_saxon.r and c_saxon.g > c_saxon.b
	_checks["rebel_is_purple"] = c_rebel.r > c_rebel.g and c_rebel.b > c_rebel.g
	_checks["camelot_is_gold"] = c_camelot.r > 0.6 and c_camelot.g > 0.6 and c_camelot.b < 0.5
	# Neutral reads grey: channels roughly equal (max-min spread small) and mid-bright.
	var neu_spread: float = maxf(c_neu.r, maxf(c_neu.g, c_neu.b)) - minf(c_neu.r, minf(c_neu.g, c_neu.b))
	_checks["neutral_is_grey"] = neu_spread < 0.1 and c_neu.r > 0.3 and c_neu.r < 0.95

	# ── body_color() reflects allegiance ───────────────────────────────────────────────────────
	# Build four enemies that differ ONLY by faction and compare their post-tint body colours. The
	# neutral one is the reference; each faction one must be (a) different from neutral and (b)
	# closer to its faction_color than the neutral body is.
	var base_neu: Color = _body_color_for("neutral")
	var all_shift_ok := true
	var all_toward_ok := true
	for fac in ["briton", "saxon", "rebel"]:
		var fc: Color = _faction_color_for(fac)
		var bc: Color = _body_color_for(fac)
		if _color_dist(bc, base_neu) <= 0.001:
			all_shift_ok = false                                   # faction body must differ from neutral
		if _color_dist(bc, fc) >= _color_dist(base_neu, fc):
			all_toward_ok = false                                  # and be CLOSER to its faction colour
	_checks["faction_body_shifts"] = all_shift_ok
	_checks["faction_body_toward_color"] = all_toward_ok
	# Neutral body stays essentially the un-tinted base (no faction shift applied).
	_checks["neutral_body_unshifted"] = _color_dist(base_neu, _enemies[0].base_color) < 0.02

	print("BEAUTIFY_READY enemies=%d" % _enemies.size())

func _make_enemy(look_name: String, fac: String, pos: Vector2) -> Enemy:
	var e := Enemy.new()
	e.look = look_name
	e.faction = fac
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

## A throwaway Enemy with the given faction, returning its pure post-tint body_color(). Freed at
## once — we only want the colour maths, not a node in the tree.
func _body_color_for(fac: String) -> Color:
	var e := Enemy.new()
	e.faction = fac
	var c: Color = e.body_color()
	e.free()
	return c

func _faction_color_for(fac: String) -> Color:
	var e := Enemy.new()
	e.faction = fac
	var c: Color = e.faction_color()
	e.free()
	return c

func _color_dist(a: Color, b: Color) -> float:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()

func _physics_process(_delta: float) -> void:
	_frame += 1
	# Keep redrawing for a couple of frames so the telegraph/emblem/aura code paths run repeatedly
	# with advancing `_t`; a draw-call error would have been reported by the engine by now.
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
	print("BEAUTIFY_RESULT %s" % " ".join(parts))
	print("BEAUTIFY_VERDICT %s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)
