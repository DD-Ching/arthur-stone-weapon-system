class_name StoneWeapon
extends Node2D
## The stone-sword.
##
## Arthur could not pull the sword free, so he lifted the whole stone with it.
## This node owns the swing state machine, the sweeping hitbox, and all of the
## "this thing is far too heavy" game feel. It is deliberately self-contained:
## it asks its parent (Arthur) for stamina and tells the camera to shake, but it
## does not reach into anyone's internals.
##
## The whole point of the design is the trade-off: a swing is a *commitment*.
## You pay a slow wind-up and a long, exposed recovery for one heavy, high-impact
## sweep. Missing should hurt. Connecting should feel great.

signal state_changed(state: int)
signal charge_changed(charge: float)
signal hit_landed(shake_strength: float, hit_count: int)
signal too_tired()

enum State { READY, WINDUP, ACTIVE, RECOVERY }

@export_group("Timing (seconds)")
## Minimum wind-up, even for a quick tap. This is the commitment you can't skip.
@export var windup_time_min := 0.28
## Hold the attack this long during wind-up to reach a full charge.
@export var charge_time := 0.9
## The actual sweep is short and fast — the heaviness is in the wind-up/recovery.
@export var active_time := 0.16
## Vulnerable tail after a tap swing.
@export var recovery_time_min := 0.45
## Vulnerable tail after a full charge — the bigger the hit, the longer you pay.
@export var recovery_time_max := 0.85

@export_group("Swing geometry")
@export var arm_length := 72.0
@export var stone_radius := 30.0
## How far back (radians) the head is hauled during wind-up.
@export var windup_angle := 2.5
## How far through (radians) the head sweeps on the active swing.
@export var followthrough_angle := 2.7
## Aim tracks the mouse quickly when idle...
@export var turn_speed_ready := 5.0
## ...and sluggishly while mid-swing (the stone fights you).
@export var turn_speed_busy := 1.3

@export_group("Impact")
@export var knockback_min := 360.0
@export var knockback_max := 920.0
@export var stamina_cost_min := 16.0
@export var stamina_cost_max := 44.0
@export var shake_min := 4.0
@export var shake_max := 15.0

var state: int = State.READY
var aim_angle := 0.0  ## the world-space direction Arthur is facing

var _target_aim := 0.0
var _charge := 0.0
var _active_charge := 0.0
var _holding := false
var _release_requested := false
var _state_time := 0.0
var _swing_offset := 0.0   ## added to aim_angle to produce the swing arc
var _recovery_from := 0.0
var _hit_ids := {}         ## instance ids already struck this swing (no double hits)
var _hit_count := 0

@onready var hitbox: Area2D = $Hitbox
@onready var _arthur = get_parent()  ## untyped on purpose — dynamic stamina calls

func _ready() -> void:
	state_changed.emit(state)

func set_aim_target(angle: float) -> void:
	_target_aim = angle

func is_ready() -> bool:
	return state == State.READY

## Attack button pressed: begin winding up if we are idle and not exhausted.
func press_attack() -> void:
	if state != State.READY:
		return
	if _arthur.stamina < stamina_cost_min:
		too_tired.emit()
		return
	_holding = true
	_release_requested = false
	_charge = 0.0
	_change_state(State.WINDUP)

## Attack button released: commit the swing (once the minimum wind-up is paid).
func release_attack() -> void:
	_holding = false
	if state == State.WINDUP:
		_release_requested = true

func _physics_process(delta: float) -> void:
	_update_aim(delta)
	_state_time += delta
	match state:
		State.READY:
			_swing_offset = lerpf(_swing_offset, 0.0, clampf(6.0 * delta, 0.0, 1.0))
		State.WINDUP:
			_process_windup(delta)
		State.ACTIVE:
			_process_active()
		State.RECOVERY:
			_process_recovery()
	rotation = aim_angle + _swing_offset
	queue_redraw()

func _update_aim(delta: float) -> void:
	var turn := turn_speed_ready if state == State.READY else turn_speed_busy
	aim_angle = lerp_angle(aim_angle, _target_aim, clampf(turn * delta, 0.0, 1.0))

func _process_windup(delta: float) -> void:
	_charge = clampf(_state_time / charge_time, 0.0, 1.0)
	charge_changed.emit(_charge)
	var pull := windup_angle * (0.45 + 0.55 * _charge)
	_swing_offset = lerpf(_swing_offset, -pull, clampf(9.0 * delta, 0.0, 1.0))
	var fully_charged := _state_time >= charge_time
	var committed := _release_requested and _state_time >= windup_time_min
	if fully_charged or committed:
		_fire()

func _fire() -> void:
	var cost := lerpf(stamina_cost_min, stamina_cost_max, _charge)
	if not _arthur.try_spend_stamina(cost):
		# Too exhausted to follow through — stumble straight into recovery.
		too_tired.emit()
		_active_charge = 0.0
		_recovery_from = _swing_offset
		_change_state(State.RECOVERY)
		return
	_active_charge = _charge
	_hit_ids.clear()
	_hit_count = 0
	_change_state(State.ACTIVE)

func _process_active() -> void:
	var t := clampf(_state_time / active_time, 0.0, 1.0)
	var eased := 1.0 - pow(1.0 - t, 3.0)  # ease-out: the head snaps through the arc
	var from_angle := -windup_angle * (0.45 + 0.55 * _active_charge)
	_swing_offset = lerpf(from_angle, followthrough_angle, eased)
	_apply_hits()
	if t >= 1.0:
		_recovery_from = _swing_offset
		_change_state(State.RECOVERY)

func _process_recovery() -> void:
	var dur := lerpf(recovery_time_min, recovery_time_max, _active_charge)
	var t := clampf(_state_time / dur, 0.0, 1.0)
	var eased := 1.0 - pow(1.0 - t, 2.0)
	_swing_offset = lerpf(_recovery_from, 0.0, eased)
	if t >= 1.0:
		_change_state(State.READY)

func _apply_hits() -> void:
	for body in hitbox.get_overlapping_bodies():
		if not body.is_in_group("targets"):
			continue
		var id := body.get_instance_id()
		if _hit_ids.has(id):
			continue
		_hit_ids[id] = true
		var origin: Vector2 = _arthur.global_position
		var dir := body.global_position - origin
		if dir.length() < 1.0:
			dir = Vector2.RIGHT.rotated(aim_angle)
		dir = dir.normalized()
		var force := lerpf(knockback_min, knockback_max, _active_charge)
		if body.has_method("apply_knockback"):
			body.call("apply_knockback", dir, force)
		_hit_count += 1
		hit_landed.emit(lerpf(shake_min, shake_max, _active_charge), _hit_count)

func _change_state(new_state: int) -> void:
	state = new_state
	_state_time = 0.0
	state_changed.emit(state)

func _draw() -> void:
	# Everything below is drawn in local space along +X; the node's rotation
	# (set in _physics_process) is what actually sweeps the head through the arc.
	var head := Vector2(arm_length, 0.0)
	var stone_col := Color(0.42, 0.40, 0.45)
	if state == State.WINDUP:
		stone_col = stone_col.lerp(Color(1.0, 0.55, 0.2), _charge)  # glows as it charges
	elif state == State.ACTIVE:
		stone_col = stone_col.lerp(Color(1, 1, 1), 0.35)
	# Haft / arm Arthur is dragging
	draw_line(Vector2.ZERO, head, Color(0.30, 0.22, 0.16), 7.0)
	# The blade poking out the far side of the stone (still stuck in it)
	draw_line(head, head + Vector2(stone_radius + 34.0, 0.0), Color(0.78, 0.80, 0.88), 5.0)
	# The stone itself
	draw_circle(head, stone_radius, stone_col)
	draw_arc(head, stone_radius, 0.0, TAU, 24, Color(0.18, 0.17, 0.20), 3.0)
	# A little hilt cross where the blade meets the stone
	draw_line(head + Vector2(stone_radius, -10.0), head + Vector2(stone_radius, 10.0), Color(0.9, 0.85, 0.5), 4.0)
