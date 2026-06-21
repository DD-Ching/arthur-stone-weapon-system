class_name StoneWeapon
extends Node2D
## The stone-sword.
##
## Arthur could not pull the sword free, so he lifted the whole stone with it.
## He grips the SWORD HANDLE; the blade runs out of his hand and is buried in a
## huge STONE that forms the heavy head — a sword stuck in a stone, swung like a
## hammer.
##
## This node owns:
##   - the visual (handle -> crossguard -> blade -> stone head, drawn so the
##     blade reads as embedded in the stone),
##   - the swing state machine (ready -> wind-up -> active -> recovery) with
##     hold-to-charge,
##   - an overhead SLAM (raise -> hold -> drop -> recover) with a shockwave,
##   - and the geometry that drives both the attack hitbox (Area2D) and the
##     stone's passive physical body (AnimatableBody2D), so the head is the same
##     object you see, sweep, and shove things with.
##
## Passive presence: while you are merely aiming, the stone body still blocks and
## nudges enemies/props. During the brief active swing (and slam drop) the solid
## body steps aside and the designed impulse takes over, so hits stay controlled.

signal state_changed(state: int)
signal charge_changed(charge: float)
signal hit_landed(shake_strength: float, hit_count: int)
signal too_tired()

enum State { READY, WINDUP, ACTIVE, RECOVERY, SLAM_RAISE, SLAM_HOLD, SLAM_DROP, SLAM_RECOVER }

const SHOCKWAVE := preload("res://scenes/Shockwave.tscn")
const ROCK := preload("res://scenes/Rock.tscn")

@export_group("Timing (seconds)")
@export var windup_time_min := 0.30
@export var charge_time := 0.95
@export var active_time := 0.15
@export var recovery_time_min := 0.5
@export var recovery_time_max := 0.95
@export_subgroup("Slam")
@export var slam_raise_time := 0.36
@export var slam_hold_time := 0.13
@export var slam_drop_time := 0.11
@export var slam_recover_time := 0.6

@export_group("Geometry")
@export var handle_len := 34.0    ## the grip Arthur actually holds (visible between hand and guard)
@export var arm_length := 82.0    ## resting distance of the stone from his hand
@export var stone_radius := 33.0
@export var slam_reach := 98.0    ## how far out front the slam lands
@export var slam_pull := 42.0     ## head distance while reared back for a slam
@export var windup_angle := 2.5
@export var followthrough_angle := 2.8
@export var turn_speed_ready := 4.6   ## heavy: aim tracks the mouse, but lazily
@export var turn_speed_busy := 1.2

@export_group("Impact")
# Knockback / shake magnitudes now live in Impact.gd — the one tuning hub — so a
# swing, a thrown rock, and a bowling enemy all read from the same numbers. What
# stays here is weapon-specific cost.
@export var stamina_cost_min := 16.0
@export var stamina_cost_max := 46.0
@export var slam_stamina_cost := 42.0
@export var slam_shake := 24.0

var state: int = State.READY
var aim_angle := 0.0

var _target_aim := 0.0
var _charge := 0.0
var _active_charge := 0.0
var _release_requested := false
var _state_time := 0.0
var _swing_offset := 0.0
var _recovery_from := 0.0
var _head_dist := 0.0    ## current stone distance from Arthur (drives visual + bodies)
var _lift := 0.0         ## 0..1 "raised overhead" amount, for the slam telegraph
var _slam_struck := false
var _hit_ids := {}
var _hit_count := 0
var _solid_now := true   ## is the passive stone body currently collidable
var _trail: Array = []   ## recent head world positions for the swing trail
var _head_world := Vector2.ZERO  ## last head world position (drives speed)
var _head_speed := 0.0           ## measured head speed in px/s — the swing's "relative_speed"

@onready var hitbox: Area2D = $Hitbox
@onready var stone_body: AnimatableBody2D = $StoneBody
@onready var stone_shape: CollisionShape2D = $StoneBody/CollisionShape2D
@onready var _arthur = get_parent()

func _ready() -> void:
	_head_dist = arm_length
	_head_world = to_global(Vector2(_head_dist, 0.0))
	state_changed.emit(state)

func set_aim_target(angle: float) -> void:
	_target_aim = angle

func is_ready() -> bool:
	return state == State.READY

# --- swing input ------------------------------------------------------------

func press_attack() -> void:
	if state != State.READY:
		return
	if _arthur.stamina < stamina_cost_min:
		too_tired.emit()
		return
	_release_requested = false
	_charge = 0.0
	_change_state(State.WINDUP)

func release_attack() -> void:
	if state == State.WINDUP:
		_release_requested = true

# --- slam input -------------------------------------------------------------

func start_slam() -> void:
	if state != State.READY:
		return
	if not _arthur.try_spend_stamina(slam_stamina_cost):
		too_tired.emit()
		return
	_slam_struck = false
	_change_state(State.SLAM_RAISE)

# --- per-frame --------------------------------------------------------------

func _physics_process(delta: float) -> void:
	_update_aim(delta)
	_state_time += delta
	match state:
		State.READY:
			_swing_offset = lerpf(_swing_offset, 0.0, clampf(6.0 * delta, 0.0, 1.0))
			_head_dist = lerpf(_head_dist, arm_length, clampf(8.0 * delta, 0.0, 1.0))
			_lift = lerpf(_lift, 0.0, clampf(10.0 * delta, 0.0, 1.0))
		State.WINDUP:
			_process_windup(delta)
		State.ACTIVE:
			_process_active()
		State.RECOVERY:
			_process_recovery()
		State.SLAM_RAISE:
			_process_slam_raise(delta)
		State.SLAM_HOLD:
			_process_slam_hold()
		State.SLAM_DROP:
			_process_slam_drop()
		State.SLAM_RECOVER:
			_process_slam_recover(delta)

	rotation = aim_angle + _swing_offset
	# Drive the hit Area2D and the passive stone body to the visible head.
	hitbox.position = Vector2(_head_dist, 0.0)
	stone_body.position = Vector2(_head_dist, 0.0)
	_set_solid(state != State.ACTIVE and state != State.SLAM_DROP)
	_update_trail(delta)
	queue_redraw()

func _update_aim(delta: float) -> void:
	var turn := turn_speed_ready if state == State.READY else turn_speed_busy
	aim_angle = lerp_angle(aim_angle, _target_aim, clampf(turn * delta, 0.0, 1.0))

# --- swing states -----------------------------------------------------------

func _process_windup(delta: float) -> void:
	# Stone Flow (stack 1+) winds the stone up a touch faster.
	var eff_charge_time := charge_time / Impact.charge_speed_mult()
	_charge = clampf(_state_time / eff_charge_time, 0.0, 1.0)
	charge_changed.emit(_charge)
	var pull := windup_angle * _charge_angle_factor(_charge)
	_swing_offset = lerpf(_swing_offset, -pull, clampf(9.0 * delta, 0.0, 1.0))
	if (_release_requested and _state_time >= windup_time_min) or _state_time >= eff_charge_time:
		_fire()

func _fire() -> void:
	var cost := lerpf(stamina_cost_min, stamina_cost_max, _charge)
	if not _arthur.try_spend_stamina(cost):
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
	var eased := 1.0 - pow(1.0 - t, 3.0)
	var from_angle := -windup_angle * _charge_angle_factor(_active_charge)
	_swing_offset = lerpf(from_angle, followthrough_angle, eased)
	_apply_swing_hits()
	if t >= 1.0:
		if _hit_count == 0:
			Impact.note_miss()   # a committed swing that connected with nothing bleeds the combo
		_recovery_from = _swing_offset
		_change_state(State.RECOVERY)

func _process_recovery() -> void:
	# Stone Flow (stack 3+) shortens the exposed recovery.
	var dur := lerpf(recovery_time_min, recovery_time_max, _active_charge) * Impact.recovery_mult()
	var t := clampf(_state_time / dur, 0.0, 1.0)
	_swing_offset = lerpf(_recovery_from, 0.0, 1.0 - pow(1.0 - t, 2.0))
	if t >= 1.0:
		_change_state(State.READY)

func _apply_swing_hits() -> void:
	var origin: Vector2 = _arthur.global_position
	var forward := Vector2.RIGHT.rotated(aim_angle)
	for body in hitbox.get_overlapping_bodies():
		if not (body.has_method("apply_hit") or body.has_method("apply_knockback")):
			continue
		var id := body.get_instance_id()
		if _hit_ids.has(id):
			continue
		_hit_ids[id] = true

		var to: Vector2 = body.global_position - origin
		var dir := to.normalized() if to.length() > 1.0 else forward
		var angle_q := clampf(forward.dot(dir), 0.0, 1.0)   # how head-on the hit is

		# Wall-crush + shield only matter for enemies (the things with apply_hit).
		var pin := 0.0
		var block := 1.0
		if body.has_method("apply_hit"):
			pin = Impact.cushion(self, body.global_position, dir)
			if body.has_method("block_factor") and pin < 0.5:
				block = body.block_factor(dir)

		var r := Impact.resolve_hit({
			"kind": "swing", "attacker_mass": Impact.MASS_STONE,
			"relative_speed": _head_speed, "charge": _active_charge,
			"angle_quality": angle_q, "pin": pin,
		})
		var kb: float = r["knockback"] * block
		if body.has_method("apply_hit"):
			body.apply_hit(dir, kb, r["stun"], r["damage"] * block)
		else:
			body.apply_knockback(dir, kb)   # props: launch them, no damage

		var label: String = r["label"]
		var color: Color = r["color"]
		if block < 0.9 and pin < 0.5:
			label = "BLOCKED"
			color = Color(0.7, 0.75, 0.8)
		Impact.popup(label, body.global_position + Vector2(0, -26), color, 1.0 + 0.3 * _active_charge)
		Impact.add_flow(r["flow_gain"] * (0.4 if block < 0.9 else 1.0))

		_hit_count += 1
		hit_landed.emit(r["shake"], _hit_count)

# --- slam states ------------------------------------------------------------

func _process_slam_raise(delta: float) -> void:
	var t := clampf(_state_time / slam_raise_time, 0.0, 1.0)
	# Drag back and heave the stone up over Arthur's head (top-down: it grows).
	_head_dist = lerpf(arm_length, slam_pull, t)
	_lift = ease_out(t)
	_swing_offset = lerpf(_swing_offset, -0.5, clampf(6.0 * delta, 0.0, 1.0))
	if t >= 1.0:
		_change_state(State.SLAM_HOLD)

func _process_slam_hold() -> void:
	_lift = 1.0
	if _state_time >= slam_hold_time:
		_change_state(State.SLAM_DROP)

func _process_slam_drop() -> void:
	var t := clampf(_state_time / slam_drop_time, 0.0, 1.0)
	# Smash the head out in front and down.
	_head_dist = lerpf(slam_pull, slam_reach, ease_out(t))
	_lift = 1.0 - t
	_swing_offset = lerpf(_swing_offset, 0.0, t)
	if not _slam_struck and t >= 0.9:
		_slam_struck = true
		_do_slam_impact()
	if t >= 1.0:
		_change_state(State.SLAM_RECOVER)

func _process_slam_recover(delta: float) -> void:
	var t := clampf(_state_time / slam_recover_time, 0.0, 1.0)
	_head_dist = lerpf(slam_reach, arm_length, ease_out(t))
	_lift = lerpf(_lift, 0.0, clampf(8.0 * delta, 0.0, 1.0))
	if t >= 1.0:
		_change_state(State.READY)

func _do_slam_impact() -> void:
	var point: Vector2 = _arthur.global_position + Vector2(slam_reach, 0.0).rotated(aim_angle)
	var scene := get_tree().current_scene
	var wave = SHOCKWAVE.instantiate()   # untyped: it's a Node2D, set its world position
	scene.add_child(wave)
	wave.global_position = point
	wave.detonate()                      # impulse AFTER positioning (see Shockwave.detonate)
	# Leave a chunk of debris the player can then launch with a normal swing.
	var rock = ROCK.instantiate()
	scene.add_child(rock)
	rock.global_position = point
	hit_landed.emit(slam_shake, 0)   # one big shake + hit-stop

func ease_out(t: float) -> float:
	return 1.0 - pow(1.0 - t, 3.0)

## How far the head hauls back for a given charge (0 → 45%, 1 → 100% of windup_angle).
## Shared by the wind-up pull and the active swing's starting angle.
func _charge_angle_factor(charge: float) -> float:
	return 0.45 + 0.55 * charge

func _change_state(new_state: int) -> void:
	state = new_state
	_state_time = 0.0
	state_changed.emit(state)

# --- passive stone body + trail --------------------------------------------

func _set_solid(solid: bool) -> void:
	if solid == _solid_now:
		return
	_solid_now = solid
	stone_shape.set_deferred("disabled", not solid)

func _update_trail(delta: float) -> void:
	var head := to_global(Vector2(_head_dist, 0.0))
	_head_speed = minf(head.distance_to(_head_world) / maxf(delta, 0.0001), 3200.0)
	_head_world = head
	if state == State.ACTIVE or state == State.SLAM_DROP:
		_trail.push_back({"pos": head, "age": 0.0})
	for p in _trail:
		p.age += delta
	while _trail.size() > 0 and _trail[0].age > 0.22:
		_trail.pop_front()

# --- drawing ----------------------------------------------------------------

func _draw() -> void:
	_draw_trail()
	var head := Vector2(_head_dist, 0.0)
	var r := stone_radius * (1.0 + 0.45 * _lift)

	# Lift shadow (the stone is overhead): a dark ghost offset back toward Arthur.
	if _lift > 0.01:
		draw_circle(head - Vector2(18.0 * _lift, 0.0), r * 0.9, Color(0, 0, 0, 0.28 * _lift))

	# Blade: runs from the crossguard THROUGH the stone (drawn first, so the
	# stone covers its middle and it reads as embedded).
	var guard := Vector2(handle_len, 0.0)
	draw_line(guard, head + Vector2(r * 0.8, 0.0), Color(0.80, 0.82, 0.90), 6.0)
	draw_line(guard, head, Color(0.62, 0.64, 0.72), 2.0)  # fuller line

	# The stone: heavy mass with shading + cracks.
	var stone_col := Color(0.45, 0.43, 0.49)
	if state == State.WINDUP:
		stone_col = stone_col.lerp(Color(1.0, 0.55, 0.2), _charge)   # charge glow
	draw_circle(head, r, stone_col)
	draw_circle(head - Vector2(r * 0.3, r * 0.3), r * 0.45, stone_col.lightened(0.12))
	draw_circle(head + Vector2(r * 0.35, r * 0.25), r * 0.25, stone_col.darkened(0.22))
	draw_arc(head, r, 0.0, TAU, 28, Color(0.16, 0.15, 0.18), 3.0)
	draw_line(head + Vector2(-r * 0.4, -r * 0.2), head + Vector2(r * 0.1, r * 0.5), Color(0.2, 0.19, 0.22), 2.0)

	# Blade tip poking out the far side of the stone (on top).
	draw_line(head + Vector2(r * 0.7, 0.0), head + Vector2(r + 12.0, 0.0), Color(0.85, 0.87, 0.95), 5.0)

	# Charge ring around the stone while winding up.
	if state == State.WINDUP and _charge > 0.02:
		draw_arc(head, r + 6.0, -PI * 0.5, -PI * 0.5 + TAU * _charge, 32, Color(1.0, 0.7, 0.25, 0.9), 3.0)

	# The HANDLE Arthur actually grips: grip + pommel at his hand, then crossguard.
	draw_line(Vector2(3.0, 0.0), guard, Color(0.34, 0.26, 0.20), 9.0)   # leather grip
	draw_line(Vector2(3.0, 0.0), guard, Color(0.55, 0.45, 0.33), 3.0)   # grip highlight
	draw_circle(Vector2.ZERO, 6.0, Color(0.80, 0.72, 0.45))             # pommel in his hand
	draw_line(guard + Vector2(0.0, -12.0), guard + Vector2(0.0, 12.0), Color(0.88, 0.80, 0.45), 5.0)  # crossguard

func _draw_trail() -> void:
	if _trail.size() < 2:
		return
	for i in range(_trail.size() - 1):
		var a: float = 1.0 - _trail[i].age / 0.22
		var p0: Vector2 = to_local(_trail[i].pos)
		var p1: Vector2 = to_local(_trail[i + 1].pos)
		draw_line(p0, p1, Color(0.95, 0.85, 0.6, clampf(a, 0.0, 1.0) * 0.5), 10.0 * clampf(a, 0.2, 1.0))
