class_name StoneWeapon
extends Node2D
## The stone-sword — now swung by momentum, not charged.
##
## Arthur grips the SWORD HANDLE; the blade runs out of his hand and is buried in
## a huge STONE that forms the heavy head. Because it is heavy, the head behaves
## like a weight on the end of his arm:
##
##   - it HANGS BEHIND him and sloshes around with real inertia as he moves and as
##     he turns to aim (a spring-damped pendulum, not a cursor),
##   - pressing attack does not "charge" — it APPLIES FORCE: an angular kick that
##     flings the head from behind, around, to the front,
##   - the kick stacks on whatever momentum you already built by moving and whipping
##     your aim, so a clever sweep hits far harder than a flat-footed poke,
##   - how hard a hit lands is read straight off the head's real speed at contact
##     (Impact.resolve_hit's relative_speed) — slow drag pushes, fast whip launches.
##
## The right-mouse SLAM is unchanged: a committed overhead smash with a shockwave.
##
## The head is one object you see, sweep, and shove with: a visual, an Area2D hit
## detector, and an AnimatableBody2D solid body, all driven to the same point.

signal state_changed(state: int)
signal charge_changed(power: float)   ## live swing power 0..1 (head momentum) for the HUD
signal hit_landed(shake_strength: float, hit_count: int)
signal too_tired()

enum State { IDLE, SWING, SLAM_RAISE, SLAM_HOLD, SLAM_DROP, SLAM_RECOVER }

const SHOCKWAVE := preload("res://scenes/Shockwave.tscn")
const ROCK := preload("res://scenes/Rock.tscn")

@export_group("Swing feel")
@export var rest_stiffness := 22.0     ## pull toward the trailing rest (higher = snappier return)
@export var rest_damping := 4.6        ## angular air-resistance (lower = more wobble/momentum)
@export var inertia_gain := 1.1        ## how much Arthur's movement sloshes the head around
@export var max_avel := 30.0           ## cap on angular speed (rad/s)
@export var fling_power := 16.0        ## the angular kick a press applies — "施力"
@export var swing_end_speed := 250.0   ## head speed below which a flung swing is spent
@export var solid_off_speed := 230.0   ## above this the solid stone steps aside for the impulse
@export var lunge_impulse := 165.0     ## forward dash Arthur gets per swing (displacement + momentum)

@export_group("Facing")
@export var face_turn_speed := 9.0     ## how fast Arthur turns to face the cursor

@export_group("Geometry")
@export var handle_len := 34.0    ## the grip Arthur holds (visible between hand and guard)
@export var arm_length := 82.0    ## resting distance of the stone from his hand
@export var stone_radius := 33.0
@export var slam_reach := 98.0    ## how far out front the slam lands
@export var slam_pull := 42.0     ## head distance while reared back for a slam

@export_group("Slam timing (seconds)")
@export var slam_raise_time := 0.36
@export var slam_hold_time := 0.13
@export var slam_drop_time := 0.11
@export var slam_recover_time := 0.6

@export_group("Cost")
# Knockback / shake magnitudes live in Impact.gd (the one tuning hub). What stays
# here is weapon-specific stamina cost.
@export var swing_cost := 20.0
@export var slam_stamina_cost := 42.0
@export var slam_shake := 24.0

var state: int = State.IDLE
var aim_angle := 0.0      ## Arthur's facing (toward the cursor) — drives his facing dot

var _target_aim := 0.0
var _angle := 0.0         ## world angle of the head around Arthur (the pendulum)
var _avel := 0.0          ## angular velocity of the head (rad/s)
var _state_time := 0.0
var _head_dist := 0.0     ## current stone distance from Arthur (drives visual + bodies)
var _lift := 0.0          ## 0..1 "raised overhead" amount, for the slam telegraph
var _slam_struck := false
var _hit_ids := {}
var _hit_count := 0
var _solid_now := true
var _trail: Array = []
var _head_world := Vector2.ZERO
var _head_speed := 0.0    ## measured head speed in px/s — the swing's "relative_speed"
var _arthur_vel_prev := Vector2.ZERO

@onready var hitbox: Area2D = $Hitbox
@onready var stone_body: AnimatableBody2D = $StoneBody
@onready var stone_shape: CollisionShape2D = $StoneBody/CollisionShape2D
@onready var _arthur = get_parent()

func _ready() -> void:
	_head_dist = arm_length
	_angle = _target_aim + PI      # the head starts hanging behind the facing
	aim_angle = _target_aim
	_head_world = to_global(Vector2(_head_dist, 0.0))
	state_changed.emit(state)

func set_aim_target(angle: float) -> void:
	_target_aim = angle

func is_ready() -> bool:
	return state == State.IDLE

# --- input ------------------------------------------------------------------

## Apply force: fling the head from where it is, around, to the front. The kick
## stacks on whatever momentum the head already carries (from moving / whipping
## the aim), so building a sweep first makes the hit harder. You can press again
## mid-swing to re-kick (rhythmic back-and-forth) — each press costs stamina.
func press_attack() -> void:
	if state >= State.SLAM_RAISE:
		return   # committed to a slam
	if not _arthur.try_spend_stamina(swing_cost):
		too_tired.emit()
		return
	var to_front := wrapf(_target_aim - _angle, -PI, PI)
	var dir := signf(to_front)
	if absf(to_front) < 0.2:                       # already near the front
		dir = signf(_avel) if absf(_avel) > 0.1 else 1.0
	_avel = clampf(_avel + fling_power * dir, -max_avel, max_avel)
	# Lunge forward — the swing carries Arthur. Chain presses to sprint/reposition,
	# and the dash speed feeds the head's momentum (a charging swing hits harder).
	if _arthur.has_method("lunge"):
		_arthur.lunge(Vector2.RIGHT.rotated(_target_aim) * lunge_impulse)
	_hit_ids.clear()
	_hit_count = 0
	_change_state(State.SWING)

func release_attack() -> void:
	pass   # no charge to release — kept so existing callers/tests stay valid

func start_slam() -> void:
	if state >= State.SLAM_RAISE:
		return
	if not _arthur.try_spend_stamina(slam_stamina_cost):
		too_tired.emit()
		return
	_slam_struck = false
	_change_state(State.SLAM_RAISE)

# --- per-frame --------------------------------------------------------------

func _physics_process(delta: float) -> void:
	_update_facing(delta)
	_state_time += delta

	# Arthur's acceleration this frame — what makes the heavy head slosh/trail.
	var av: Vector2 = _arthur.velocity if _arthur else Vector2.ZERO
	var accel: Vector2 = (av - _arthur_vel_prev) / maxf(delta, 0.0001)
	accel = accel.limit_length(3000.0)
	_arthur_vel_prev = av

	match state:
		State.IDLE:
			_update_pendulum(delta, accel)
		State.SWING:
			_update_pendulum(delta, accel)
			_apply_swing_hits()
			if (_state_time > 0.06 and _head_speed < swing_end_speed) or _state_time > 1.1:
				if _hit_count == 0:
					Impact.note_miss()   # a committed swing that connected with nothing bleeds the combo
				_change_state(State.IDLE)
		State.SLAM_RAISE:
			_process_slam_raise(delta)
		State.SLAM_HOLD:
			_process_slam_hold()
		State.SLAM_DROP:
			_process_slam_drop()
		State.SLAM_RECOVER:
			_process_slam_recover(delta)

	rotation = _angle
	hitbox.position = Vector2(_head_dist, 0.0)
	stone_body.position = Vector2(_head_dist, 0.0)
	var hot := (state == State.SWING and _head_speed > solid_off_speed) or state == State.SLAM_DROP
	_set_solid(not hot)
	_update_trail(delta)
	charge_changed.emit(clampf(_head_speed / 1500.0, 0.0, 1.0) if state == State.SWING else 0.0)
	queue_redraw()

func _update_facing(delta: float) -> void:
	aim_angle = lerp_angle(aim_angle, _target_aim, clampf(face_turn_speed * delta, 0.0, 1.0))

## The pendulum: a spring pulling the head to its trailing rest (behind the
## facing), plus the pseudo-force from Arthur's acceleration (inertia), minus
## damping. Real momentum, no scripted arc.
func _update_pendulum(delta: float, accel: Vector2) -> void:
	# In IDLE the head hangs BEHIND the facing; a press flips its "home" to the
	# FRONT, so the spring carries the head around to where you point (the fling
	# impulse just gets it there faster + harder). On the way back it settles behind.
	var rest := _target_aim if state == State.SWING else _target_aim + PI
	var diff := wrapf(rest - _angle, -PI, PI)
	var torque := rest_stiffness * diff - rest_damping * _avel
	# pendulum pseudo-force from the moving pivot (Arthur) → tangential component
	torque += (accel.x * sin(_angle) - accel.y * cos(_angle)) / arm_length * inertia_gain
	_avel = clampf(_avel + torque * delta, -max_avel, max_avel)
	_angle = wrapf(_angle + _avel * delta, -PI, PI)
	# a little stretch under speed sells the whip
	var target_dist := arm_length + clampf(absf(_avel) * 0.7, 0.0, 14.0)
	_head_dist = lerpf(_head_dist, target_dist, clampf(10.0 * delta, 0.0, 1.0))
	# The hammer rides UP as it whips (lift reads the momentum), settles when idle.
	var lift_target := clampf(_head_speed / 1800.0, 0.0, 0.5) if state == State.SWING else 0.0
	_lift = lerpf(_lift, lift_target, clampf(8.0 * delta, 0.0, 1.0))

func _apply_swing_hits() -> void:
	var origin: Vector2 = _arthur.global_position
	for body in hitbox.get_overlapping_bodies():
		if not (body.has_method("apply_hit") or body.has_method("apply_knockback")):
			continue
		var id := body.get_instance_id()
		if _hit_ids.has(id):
			continue
		_hit_ids[id] = true

		var to: Vector2 = body.global_position - origin
		var head_dir := Vector2.RIGHT.rotated(_angle)
		var dir := to.normalized() if to.length() > 1.0 else head_dir
		var angle_q := clampf(head_dir.dot(dir), 0.0, 1.0)   # how square the head is on the target

		var pin := 0.0
		var block := 1.0
		if body.has_method("apply_hit"):
			pin = Impact.cushion(self, body.global_position, dir)
			if body.has_method("block_factor") and pin < 0.5:
				block = body.block_factor(dir)

		var r := Impact.resolve_hit({
			"kind": "swing", "attacker_mass": Impact.MASS_STONE,
			"relative_speed": _head_speed, "charge": 0.0,   # power is all momentum now
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
		Impact.popup(label, body.global_position + Vector2(0, -26), color, 1.0 + 0.4 * clampf(_head_speed / 1600.0, 0.0, 1.0))
		Impact.add_flow(r["flow_gain"] * (0.4 if block < 0.9 else 1.0))

		_hit_count += 1
		hit_landed.emit(r["shake"], _hit_count)

# --- slam states ------------------------------------------------------------

func _process_slam_raise(delta: float) -> void:
	# Snap the head to the front (where you point), then heave it up.
	_angle = lerp_angle(_angle, _target_aim, clampf(12.0 * delta, 0.0, 1.0))
	_avel = 0.0
	var t := clampf(_state_time / slam_raise_time, 0.0, 1.0)
	_head_dist = lerpf(arm_length, slam_pull, t)
	_lift = ease_out(t)
	if t >= 1.0:
		_change_state(State.SLAM_HOLD)

func _process_slam_hold() -> void:
	_angle = _target_aim
	_lift = 1.0
	if _state_time >= slam_hold_time:
		_change_state(State.SLAM_DROP)

func _process_slam_drop() -> void:
	_angle = _target_aim
	var t := clampf(_state_time / slam_drop_time, 0.0, 1.0)
	_head_dist = lerpf(slam_pull, slam_reach, ease_out(t))
	_lift = 1.0 - t
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
		# Hand the head back to the pendulum where it is, so it settles naturally.
		_avel = 0.0
		_change_state(State.IDLE)

func _do_slam_impact() -> void:
	var point: Vector2 = _arthur.global_position + Vector2(slam_reach, 0.0).rotated(_target_aim)
	var scene := get_tree().current_scene
	var wave = SHOCKWAVE.instantiate()   # untyped: it's a Node2D, set its world position
	scene.add_child(wave)
	wave.global_position = point
	wave.detonate()                      # impulse AFTER positioning (see Shockwave.detonate)
	var rock = ROCK.instantiate()
	scene.add_child(rock)
	rock.global_position = point
	hit_landed.emit(slam_shake, 0)   # one big shake + hit-stop

func ease_out(t: float) -> float:
	return 1.0 - pow(1.0 - t, 3.0)

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
	if (state == State.SWING and _head_speed > swing_end_speed) or state == State.SLAM_DROP:
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
	var speed_t := clampf(_head_speed / 1500.0, 0.0, 1.0)

	# Lift shadow (the stone is overhead): a dark ghost offset back toward Arthur.
	if _lift > 0.01:
		draw_circle(head - Vector2(18.0 * _lift, 0.0), r * 0.9, Color(0, 0, 0, 0.28 * _lift))

	# Blade: runs from the crossguard THROUGH the stone (drawn first, so the
	# stone covers its middle and it reads as embedded).
	var guard := Vector2(handle_len, 0.0)
	draw_line(guard, head + Vector2(r * 0.8, 0.0), Color(0.80, 0.82, 0.90), 6.0)
	draw_line(guard, head, Color(0.62, 0.64, 0.72), 2.0)  # fuller line

	# The stone: heavy mass that glows hotter the faster it's moving (its momentum
	# is its power) — the only feedback you need to learn "wind up a bigger sweep".
	var stone_col := Color(0.45, 0.43, 0.49)
	if state == State.SWING:
		stone_col = stone_col.lerp(Color(1.0, 0.5, 0.2), speed_t)
	draw_circle(head, r, stone_col)
	draw_circle(head - Vector2(r * 0.3, r * 0.3), r * 0.45, stone_col.lightened(0.12))
	draw_circle(head + Vector2(r * 0.35, r * 0.25), r * 0.25, stone_col.darkened(0.22))
	draw_arc(head, r, 0.0, TAU, 28, Color(0.16, 0.15, 0.18), 3.0)
	draw_line(head + Vector2(-r * 0.4, -r * 0.2), head + Vector2(r * 0.1, r * 0.5), Color(0.2, 0.19, 0.22), 2.0)

	# Blade tip poking out the far side of the stone.
	draw_line(head + Vector2(r * 0.7, 0.0), head + Vector2(r + 12.0, 0.0), Color(0.85, 0.87, 0.95), 5.0)

	# A heat ring when the head is really moving — reads the momentum at a glance.
	if speed_t > 0.25 and state == State.SWING:
		draw_arc(head, r + 6.0, 0.0, TAU, 32, Color(1.0, 0.7, 0.25, speed_t * 0.9), 3.0)

	# The HANDLE Arthur grips: grip + pommel at his hand, then crossguard.
	draw_line(Vector2(3.0, 0.0), guard, Color(0.34, 0.26, 0.20), 9.0)
	draw_line(Vector2(3.0, 0.0), guard, Color(0.55, 0.45, 0.33), 3.0)
	draw_circle(Vector2.ZERO, 6.0, Color(0.80, 0.72, 0.45))
	draw_line(guard + Vector2(0.0, -12.0), guard + Vector2(0.0, 12.0), Color(0.88, 0.80, 0.45), 5.0)

func _draw_trail() -> void:
	if _trail.size() < 2:
		return
	for i in range(_trail.size() - 1):
		var a: float = 1.0 - _trail[i].age / 0.22
		var p0: Vector2 = to_local(_trail[i].pos)
		var p1: Vector2 = to_local(_trail[i + 1].pos)
		draw_line(p0, p1, Color(0.95, 0.85, 0.6, clampf(a, 0.0, 1.0) * 0.5), 10.0 * clampf(a, 0.2, 1.0))
