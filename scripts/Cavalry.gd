class_name Cavalry
extends Enemy
## A mounted charger — the battlefield's big momentum threat.
##
## It reuses everything from Enemy (physics body, knockback, bowling, defeat, the
## KO count) and replaces only the brain: instead of walking up and poking, it
## circles at range, telegraphs a lane, then CHARGES in a mostly-straight line.
## A charge is dangerous to Arthur and plows through the enemy's own crowd (the
## charging body bowls fodder aside via Enemy's contact monitor) — but it commits:
## a solid hit while it's charging staggers it and BREAKS the charge, and it
## overshoots and has to wheel around, leaving it open. Speed and timing, not raw
## strength — exactly the brief's cavalry rule.

enum Charge { REPOSITION, TELEGRAPH, CHARGE, RECOVER }

@export var charge_speed := 430.0
@export var reposition_speed := 120.0
@export var telegraph_time := 0.85
@export var charge_dur := 3.0         ## a long committed dash — 3x the old charge distance
@export var recover_dur := 1.3
@export var charge_damage := 18.0
@export var trigger_range := 720.0    ## commits from farther, to match the longer charge
@export var charge_lane := 750.0      ## drawn length of the telegraph / charge (3x)

var _cstate := Charge.REPOSITION
var _ctime := 0.0
var _charge_dir := Vector2.RIGHT
var _ring := 1.0
var _hit_player := false

func _physics_process(delta: float) -> void:
	if _dead or not ai_enabled:
		return
	# Struck hard mid-charge → the charge breaks and it's left reeling (vulnerable).
	if _stun > 0.0:
		if _cstate == Charge.CHARGE:
			Impact.popup("CHARGE BROKEN", global_position + Vector2(0, -32), Color(1.0, 0.7, 0.3), 1.2)
			_cstate = Charge.RECOVER
			_ctime = 0.0
		return
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
		if _player == null:
			return

	var speed := linear_velocity.length()
	_ctime += delta
	var to_p: Vector2 = _player.global_position - global_position
	var dist := to_p.length()
	var dir := to_p / maxf(dist, 0.001)

	match _cstate:
		Charge.REPOSITION:
			_face = dir.angle()
			if speed <= control_regain:
				var tangent := Vector2(-dir.y, dir.x) * _ring          # circle the player
				var pull := dir * clampf((dist - 300.0) * 0.01, -1.0, 1.0)
				var desired := (tangent + pull).normalized() * reposition_speed
				linear_velocity = linear_velocity.move_toward(desired, 700.0 * delta)
			if _ctime > 1.6 and dist < trigger_range:
				_cstate = Charge.TELEGRAPH
				_ctime = 0.0
				_charge_dir = dir
		Charge.TELEGRAPH:
			_face = _charge_dir.angle()
			if speed <= control_regain:
				linear_velocity = linear_velocity.move_toward(Vector2.ZERO, 900.0 * delta)
			if _ctime >= telegraph_time:
				_cstate = Charge.CHARGE
				_ctime = 0.0
				_hit_player = false
				Impact.popup("CAVALRY CHARGE", global_position + Vector2(0, -34), Color(1.0, 0.5, 0.3), 1.2)
				Audio.play("cavalry_charge", global_position)
		Charge.CHARGE:
			_face = _charge_dir.angle()
			linear_velocity = linear_velocity.move_toward(_charge_dir * charge_speed, 1400.0 * delta)
			if not _hit_player and dist < radius + 30.0 and _player.has_method("take_damage"):
				if _player.take_damage(charge_damage, global_position):
					_hit_player = true
			if _ctime >= charge_dur:
				_cstate = Charge.RECOVER
				_ctime = 0.0
		Charge.RECOVER:
			linear_velocity = linear_velocity.move_toward(Vector2.ZERO, 350.0 * delta)
			if _ctime >= recover_dur:
				_cstate = Charge.REPOSITION
				_ctime = 0.0
				_ring = -_ring   # wheel around the other way next time

# ── visuals (override Enemy's) ──────────────────────────────────────────────

func _draw_type() -> void:
	var fwd := Vector2(cos(_face), sin(_face))
	var side := Vector2(-fwd.y, fwd.x)
	var a := _alpha
	var fc := faction_color()
	# Hide colours so the warhorse reads as muscle, not a flat blob.
	var hide_dk := Color(0.30, 0.22, 0.16, a)   # shadowed underside / hindquarter
	var hide := Color(0.42, 0.31, 0.23, a)      # body
	var hide_lt := Color(0.50, 0.38, 0.28, a)   # lit shoulder / head

	# ── legs (a hint, under the body) — fore + hind pairs, splayed for a gallop ──
	var leg_col := Color(0.26, 0.19, 0.14, a)
	draw_line(fwd * 12.0 + side * 4.0, fwd * 22.0 + side * 9.0, leg_col, 3.0)   # foreleg
	draw_line(fwd * 12.0 - side * 4.0, fwd * 20.0 - side * 8.0, leg_col, 3.0)
	draw_line(-fwd * 10.0 + side * 4.0, -fwd * 20.0 + side * 9.0, leg_col, 3.0) # hind leg
	draw_line(-fwd * 10.0 - side * 4.0, -fwd * 18.0 - side * 8.0, leg_col, 3.0)

	# ── tail streaming off the rump ──
	draw_line(-fwd * (radius * 0.85), -fwd * (radius * 1.45) + side * 7.0, hide_dk, 3.5)
	draw_line(-fwd * (radius * 0.85), -fwd * (radius * 1.5) - side * 5.0, hide_dk, 2.5)

	# ── horse body: overlapping ovals along the facing (hind, barrel, shoulder) ──
	draw_circle(-fwd * 9.0, radius * 0.74, hide_dk)
	draw_circle(Vector2.ZERO, radius * 0.86, hide)
	draw_circle(fwd * 9.0, radius * 0.78, hide_lt)

	# ── neck + head out front ──
	var neck := fwd * (radius * 0.62)
	var head := fwd * (radius * 1.05) - side * 1.0
	draw_line(neck, head, hide_lt, radius * 0.5)         # thick neck
	draw_circle(head, radius * 0.3, hide_lt)             # head
	draw_circle(fwd * (radius * 1.25) - side * 2.0, radius * 0.16, hide_lt)  # muzzle
	# Mane along the crest of the neck.
	for i in 3:
		var f := 0.65 + 0.13 * float(i)
		draw_line(fwd * (radius * f) + side * 2.0, fwd * (radius * f) - side * 5.0, hide_dk, 2.0)

	# ── faction caparison draped over the horse's flank ──
	var cap := Color(fc.r, fc.g, fc.b, a * 0.85)
	var drape := PackedVector2Array([
		-fwd * 2.0 + side * (radius * 0.55),
		fwd * 6.0 + side * (radius * 0.7),
		fwd * 4.0 + side * (radius * 1.15),
		-fwd * 8.0 + side * (radius * 1.0),
	])
	draw_colored_polygon(drape, cap)

	# ── rider: a saddled torso + helmeted head, leaning into the charge ──
	var seat := -fwd * 2.0
	draw_circle(seat, radius * 0.46, Color(0.34, 0.27, 0.34, a))           # torso / cloak
	var rider_cloak := Color(fc.r * 0.8, fc.g * 0.8, fc.b * 0.8, a * 0.9)
	draw_line(seat - fwd * 2.0, -fwd * (radius * 0.7) - side * 3.0, rider_cloak, 4.0)  # cloak streaming back
	draw_circle(fwd * 3.0, radius * 0.26, Color(0.78, 0.62, 0.5, a))       # head
	draw_arc(fwd * 3.0, radius * 0.27, PI, TAU, 8, Color(0.7, 0.72, 0.78, a), 2.5)     # helmet brim
	# Helmet crest in the faction colour.
	draw_line(fwd * 3.0 - fwd * 4.0, fwd * 3.0 - fwd * 9.0 - side * 2.0, cap, 2.5)

	# ── lance held forward along the facing, with a small pennon ──
	var grip := seat + side * 6.0
	var lance_tip := fwd * (radius * 1.7) + side * 6.0
	draw_line(grip, lance_tip, Color(0.62, 0.5, 0.36, a), 2.5)             # shaft
	draw_circle(lance_tip, 2.5, Color(0.9, 0.9, 0.95, a))                  # steel head
	var pennon := PackedVector2Array([
		lance_tip - fwd * (radius * 0.4),
		lance_tip - fwd * (radius * 0.4) - side * 6.0,
		lance_tip - fwd * (radius * 0.7) - side * 2.0,
	])
	draw_colored_polygon(pennon, Color(fc.r, fc.g, fc.b, a))

func _draw_attack_telegraph() -> void:
	if _dead:
		return
	if _cstate == Charge.TELEGRAPH:
		var t := clampf(_ctime / maxf(telegraph_time, 0.01), 0.0, 1.0)
		draw_line(Vector2.ZERO, _charge_dir * charge_lane, Color(1.0, 0.4, 0.2, 0.25 + 0.5 * t), 5.0)
