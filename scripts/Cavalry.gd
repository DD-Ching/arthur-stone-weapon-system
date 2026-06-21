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
	# Horse: two overlapping ovals along the facing, a head out front.
	draw_circle(-fwd * 9.0, radius * 0.72, Color(0.38, 0.29, 0.22, _alpha))
	draw_circle(fwd * 7.0, radius * 0.92, Color(0.43, 0.32, 0.25, _alpha))
	draw_circle(fwd * (radius * 0.75), radius * 0.32, Color(0.3, 0.22, 0.18, _alpha))
	# Rider on top.
	draw_circle(Vector2.ZERO, radius * 0.42, Color(0.7, 0.5, 0.35, _alpha))

func _draw_attack_telegraph() -> void:
	if _dead:
		return
	if _cstate == Charge.TELEGRAPH:
		var t := clampf(_ctime / maxf(telegraph_time, 0.01), 0.0, 1.0)
		draw_line(Vector2.ZERO, _charge_dir * charge_lane, Color(1.0, 0.4, 0.2, 0.25 + 0.5 * t), 5.0)
