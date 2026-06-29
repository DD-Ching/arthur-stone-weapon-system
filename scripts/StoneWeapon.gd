class_name StoneWeapon
extends Node2D
## The stone-sword — a heavy stone you drag and whip, not an attack you trigger.
##
## Arthur grips the SWORD HANDLE; the blade runs out of his hand and is buried in
## a huge STONE that forms the heavy head. Because it is heavy, the head behaves
## like a weight on the end of his arm:
##
##   - it FOLLOWS THE CURSOR with weight and lag — a spring-damped pendulum that
##     springs toward where you aim, never snapping to it,
##   - holding attack does not "charge" — while held, DRAGGING the mouse around
##     Arthur applies torque (drag clockwise → swing clockwise) that whips the head
##     and builds real angular speed,
##   - that drag-built speed stacks on the momentum you get from moving and whipping
##     your aim, so a fast sweep hits far harder than a flat-footed poke,
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

enum State { IDLE, SWING, SLAM_RAISE, SLAM_HOLD, SLAM_DROP, SLAM_RECOVER, SPIN }

const SHOCKWAVE := preload("res://scenes/Shockwave.tscn")
const ROCK := preload("res://scenes/Rock.tscn")

@export_group("Swing feel")
@export var follow_stiffness := 13.0   ## how strongly the head springs TOWARD the cursor (heavy = low, laggy)
@export var rest_damping := 4.8        ## angular air-resistance (lower = more wobble/momentum)
@export var inertia_gain := 1.1        ## how much Arthur's movement sloshes the head around
@export var max_avel := 28.0           ## cap on angular speed (rad/s)
@export var drag_gain := 5.2           ## mouse-DRAG torque while swinging — how hard a whip builds speed
@export var swing_stamina_rate := 22.0 ## stamina drained per second while dragging a swing (above regen now → sustained offense depletes, so you burst-and-reposition)
@export var swing_weight_gain := 0.06  ## a SCORED swing hit nudges Arthur along the swing dir, this much per px/s of head speed (landing a heavy hit moves the heavy man)
@export var swing_weight_max := 150.0  ## clamp on that lunge so a heavy hit shoves him a step, never flings him across the map
@export var touch_assist_avel := 7.0   ## angular speed (rad/s) a HELD-steady touch aim ramps the head toward, so a thumb that barely circles still builds a real swing
@export var touch_assist_gain := 9.0   ## how fast the touch assist winds _avel up toward touch_assist_avel
@export var hit_speed_min := 300.0     ## head speed below which contact only PUSHES — a deliberate drag SCORES, but a still/tiny touch just shoves (so a casual contact no longer perma-stunlocks the whole crowd; damage still scales with speed)
@export var solid_off_speed := 280.0   ## above this the solid stone steps aside so the scored impulse lands cleanly (kept just below hit_speed_min)
@export var hit_interval := 0.3        ## a fast head re-hits the same target this often (seconds)

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

@export_group("Spin (musou whirlwind)")
@export var spin_rate := 17.0          ## angular speed of the whirl (rad/s) — a few turns a second
@export var spin_accel := 42.0         ## how fast it winds up to spin_rate
@export var spin_cost := 30.0          ## stamina drained PER SECOND while spinning — a real sink (~3.3s per pool), so spin is a burst not hold-to-win
@export var spin_min_stamina := 42.0   ## won't start below this — you can't instantly re-enter spin after running dry
@export var spin_hit_interval := 0.5   ## how often each enemy can be re-hit by the whirl
@export var spin_stretch := 12.0       ## extra head reach while spinning
@export var spin_speed_ref := 540.0    ## relative_speed during spin — a crowd-CONTROL carve (knock stays below the stagger wall), NOT a screen-delete; the committed swing is the real damage

@export_group("Cost")
# Knockback / shake magnitudes live in Impact.gd (the one tuning hub). What stays
# here is weapon-specific stamina cost.
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
var _spin_clear := 0.0    ## countdown to clear spin hit-dedup so the whirl re-hits
var _swinging := false    ## is the attack button held (drag = swing mode)
var _touch_assist := false ## touch aim-stick is active → assist a barely-circling thumb up to a usable swing
var _prev_aim := 0.0      ## last frame's cursor angle, for the drag's angular velocity
var _mouse_avel := 0.0    ## how fast the cursor is being dragged around Arthur (signed: CW/CCW)
var _hit_clear := 0.0     ## countdown to clear the contact hit-dedup
var _scrape_cd := 0.0     ## throttle for the slow grinding stone_scrape sound

@onready var hitbox: Area2D = $Hitbox
@onready var stone_body: AnimatableBody2D = $StoneBody
@onready var stone_shape: CollisionShape2D = $StoneBody/CollisionShape2D
@onready var _arthur = get_parent()

func _ready() -> void:
	# Tag the solid stone body so projectiles can detect + deflect off it (the stone as a shield).
	# The body's collision shape is only enabled when the stone is slow/parked (see _set_solid),
	# so this naturally means "raise the stone to block arrows", not a free always-on guard.
	stone_body.add_to_group("stone_weapon")
	_head_dist = arm_length
	_angle = _target_aim          # the head rests pointing toward the cursor
	_prev_aim = _target_aim
	aim_angle = _target_aim
	_head_world = to_global(Vector2(_head_dist, 0.0))
	state_changed.emit(state)

func set_aim_target(angle: float) -> void:
	_target_aim = angle

## True while locked into the slam sequence (NOT spin) — you can't swing/slam/spin
## out of a committed slam. Explicit so reordering the enum can't break the guards.
func _slam_committed() -> bool:
	return state >= State.SLAM_RAISE and state <= State.SLAM_RECOVER

# --- input ------------------------------------------------------------------

## Hold the attack button to enter SWING mode: now DRAGGING the mouse around Arthur
## whips the heavy head (drag clockwise → swing clockwise, etc.) and builds real
## angular speed. There is no "press = attack" — a strong hit only comes from real
## motion. set_swinging() is called every frame with the button's held state.
func set_swinging(on: bool) -> void:
	_swinging = on

## TOUCH-SWING ASSIST toggle. Arthur calls this with `true` only while the on-screen
## aim-stick is active (pointer/mouse play passes `false`, so it's UNCHANGED there).
## Circling a thumb is hard, so while it's on a held-steady aim still ramps the head
## toward a usable swing speed (see _update_pendulum) instead of going limp.
func set_touch_assist(on: bool) -> void:
	_touch_assist = on

func start_slam() -> void:
	if _slam_committed() or state == State.SPIN:
		return
	if not _arthur.try_spend_stamina(slam_stamina_cost):
		too_tired.emit()
		return
	_slam_struck = false
	_change_state(State.SLAM_RAISE)

# --- spin / tornado (held) --------------------------------------------------

## The musou whirlwind: hold to whirl the stone around Arthur, launching the whole
## crowd outward. Drains stamina fast; you keep some mobility (you're a tornado, not
## rooted). Called every frame the spin key is held; idempotent once spinning.
func start_spin() -> void:
	if state == State.SPIN:
		return                  # already whirling — idempotent
	if _slam_committed():
		return                  # can't spin out of a committed slam
	if _arthur.stamina < spin_min_stamina:
		too_tired.emit()
		return
	_hit_ids.clear()
	_spin_clear = 0.0
	_change_state(State.SPIN)

## Idempotent + safe to call every frame: a no-op unless we're actually spinning,
## so releasing the spin key mid-slam can never cancel the slam.
func stop_spin() -> void:
	if state != State.SPIN:
		return
	_avel = clampf(_avel, -max_avel, max_avel)
	_change_state(State.IDLE)

# --- per-frame --------------------------------------------------------------

func _physics_process(delta: float) -> void:
	_update_facing(delta)
	_state_time += delta

	# Arthur's acceleration this frame — what makes the heavy head slosh/trail.
	var av: Vector2 = _arthur.velocity if _arthur else Vector2.ZERO
	var accel: Vector2 = (av - _arthur_vel_prev) / maxf(delta, 0.0001)
	accel = accel.limit_length(3000.0)
	_arthur_vel_prev = av

	# How fast the cursor is being dragged AROUND Arthur (signed) — computed every
	# frame so a slam/spin can't leave a stale value that spikes the next swing.
	_mouse_avel = wrapf(_target_aim - _prev_aim, -PI, PI) / maxf(delta, 0.0001)
	_prev_aim = _target_aim

	match state:
		State.IDLE, State.SWING:
			_update_pendulum(delta, accel)
			_apply_swing_hits(delta)
			# Cosmetic state only: SWING while the head is actually moving fast (drives
			# the HUD read-out + the hot glow), IDLE while it just follows the cursor.
			var fast := _head_speed > hit_speed_min
			if fast and state == State.IDLE:
				_change_state(State.SWING)
			elif not fast and state == State.SWING:
				_change_state(State.IDLE)
		State.SLAM_RAISE:
			_process_slam_raise(delta)
		State.SLAM_HOLD:
			_process_slam_hold()
		State.SLAM_DROP:
			_process_slam_drop()
		State.SLAM_RECOVER:
			_process_slam_recover(delta)
		State.SPIN:
			_process_spin(delta)

	rotation = _angle
	hitbox.position = Vector2(_head_dist, 0.0)
	stone_body.position = Vector2(_head_dist, 0.0)
	# Solid (pushes/blocks) while slow; steps aside while fast so the scored impulse
	# does the hitting (and during slam-drop / spin).
	var free := state == State.IDLE or state == State.SWING
	var hot := (free and _head_speed > solid_off_speed) or state == State.SLAM_DROP or state == State.SPIN
	_set_solid(not hot)
	_update_trail(delta)
	var power := 1.0 if state == State.SPIN else clampf(_head_speed / 1500.0, 0.0, 1.0)
	charge_changed.emit(power)
	queue_redraw()

func _update_facing(delta: float) -> void:
	aim_angle = lerp_angle(aim_angle, _target_aim, clampf(face_turn_speed * delta, 0.0, 1.0))

## The control: the head is a heavy pendulum that springs TOWARD the cursor with
## damping (so it follows with weight + lag, never snapping). Holding the attack
## button turns the mouse DRAG into torque, so whipping the cursor around Arthur
## spins the head that way — clockwise drag → clockwise swing — building real
## angular speed instead of taking the shortest path to the cursor.
func _update_pendulum(delta: float, accel: Vector2) -> void:
	# Normal follow: a spring toward the cursor, damped.
	var diff := wrapf(_target_aim - _angle, -PI, PI)
	var torque := follow_stiffness * diff - rest_damping * _avel
	# Arthur's movement sloshes the heavy head (pendulum pseudo-force).
	torque += (accel.x * sin(_angle) - accel.y * cos(_angle)) / arm_length * inertia_gain
	# Swing mode: the drag itself whips the head (its own direction, not shortest path),
	# building real speed. Costs stamina while you're actually dragging.
	if _swinging and absf(_mouse_avel) > 0.25:
		if _arthur.try_spend_stamina(swing_stamina_rate * delta):
			torque += _mouse_avel * drag_gain
	elif _swinging and _touch_assist and absf(_mouse_avel) <= 0.25:
		# TOUCH ASSIST: a thumb barely circling the aim-stick can't build a swing the way a
		# fast mouse-drag does, so a HELD-steady touch aim ramps the head toward a usable whirl
		# (in whichever way it's already turning). Still costs stamina, so it isn't free spin.
		if _arthur.try_spend_stamina(swing_stamina_rate * delta):
			var sign_dir := 1.0 if _avel >= 0.0 else -1.0
			_avel = move_toward(_avel, touch_assist_avel * sign_dir, touch_assist_gain * delta)

	_avel = clampf(_avel + torque * delta, -max_avel, max_avel)
	_angle = wrapf(_angle + _avel * delta, -PI, PI)
	# A little stretch + lift under speed sells the whip.
	var target_dist := arm_length + clampf(absf(_avel) * 0.7, 0.0, 14.0)
	_head_dist = lerpf(_head_dist, target_dist, clampf(10.0 * delta, 0.0, 1.0))
	var lift_target := clampf(_head_speed / 1800.0, 0.0, 0.45)
	_lift = lerpf(_lift, lift_target, clampf(8.0 * delta, 0.0, 1.0))

## Contact damage, straight from physics: only the FAST-moving head scores a hit
## (slow contact is left to the solid stone body to merely push). A target the head
## stays fast against is re-hit every hit_interval, so a sustained swing keeps biting.
func _apply_swing_hits(delta: float) -> void:
	_hit_clear -= delta
	if _hit_clear <= 0.0:
		_hit_ids.clear()
		_hit_clear = hit_interval
	if _head_speed < hit_speed_min:
		# Too slow to be an attack — the solid stone just shoves. If it's grinding
		# against something, play a throttled scrape (the heavy-stone signature sound).
		_scrape_cd -= delta
		if _scrape_cd <= 0.0 and _head_speed > 45.0 and not hitbox.get_overlapping_bodies().is_empty():
			_scrape_cd = 0.35
			Audio.play("stone_scrape", _head_world)
		return

	var origin: Vector2 = _arthur.global_position
	for body in hitbox.get_overlapping_bodies():
		if not (body.has_method("apply_hit") or body.has_method("apply_knockback")):
			continue
		if body.is_in_group("allies"):
			continue   # no friendly fire — the stone only shoves allies, never scores on them
		var id := body.get_instance_id()
		if _hit_ids.has(id):
			continue
		_hit_ids[id] = true

		# WEAPON CLASH: if the enemy is MID-STRIKE when the swinging stone connects, the stone bats
		# its weapon aside — strike cancelled, staggered, knocked back, with a clash spark. The
		# normal scored hit below still lands; this is the extra "weapons physically collide" result.
		if body.has_method("is_striking") and body.has_method("parry_strike") and body.is_striking():
			var cdir: Vector2 = (body.global_position - origin).normalized()
			body.parry_strike(cdir)
			Impact.popup("CLASH!", body.global_position + Vector2(0, -34), Color(1.0, 0.95, 0.7), 1.2)
			Impact.add_flow(Impact.CLASH_FLOW)
			Audio.play("shield_block", body.global_position)

		var to: Vector2 = body.global_position - origin
		var dir := to.normalized() if to.length() > 1.0 else Vector2.RIGHT.rotated(_angle)

		var pin := 0.0
		if body.has_method("apply_hit"):
			pin = Impact.cushion(self, body.global_position, dir)

		var r := Impact.resolve_hit({
			"kind": "swing", "attacker_mass": Impact.MASS_STONE,
			"relative_speed": _head_speed, "charge": 0.0,   # power is all real motion now
			"angle_quality": 1.0, "pin": pin,
		})
		# `scored` = a real damaging hit landed on a FOE (drives the swing-weight lunge below).
		# Props (the else branch) are merely shoved, so they don't count — bumping a loose rock
		# shouldn't yank Arthur forward as if he committed his mass into an enemy.
		var scored := false
		if body.has_method("apply_hit"):
			# The enemy applies its own shield block / break and reports back.
			var res: Dictionary = body.apply_hit(dir, r["knockback"], r["stun"], r["damage"], pin)
			scored = not res["blocked"]
			if scored:
				Impact.popup(r["label"], body.global_position + Vector2(0, -26), r["color"], 1.0 + 0.4 * clampf(_head_speed / 1600.0, 0.0, 1.0))
			Impact.add_flow(r["flow_gain"] * (0.4 if res["blocked"] else 1.0))
		else:
			body.apply_knockback(dir, r["knockback"])   # props: launch them, no damage
			Impact.popup(r["label"], body.global_position + Vector2(0, -26), r["color"], 1.0 + 0.4 * clampf(_head_speed / 1600.0, 0.0, 1.0))
			Impact.add_flow(r["flow_gain"])

		# SWING WEIGHT: a scored (non-blocked) hit on a foe commits Arthur's mass into the blow —
		# a modest, head-speed-scaled lunge along the swing direction. Reuses his existing lunge()
		# (the same capped dash burst), so a heavy hit moves the heavy man a step without flinging
		# him across the field. A blocked hit, or merely shoving a prop, doesn't carry him in.
		if scored and _arthur and _arthur.has_method("lunge"):
			var nudge := clampf(_head_speed * swing_weight_gain, 0.0, swing_weight_max)
			_arthur.lunge(dir * nudge)

		_hit_count += 1
		# Bias the camera shake along the swing direction so a heavy hit kicks the view
		# the way it landed (a directional jolt, not omni rumble).
		hit_landed.emit(r["shake"], _hit_count)
		if _arthur and _arthur.camera and _arthur.camera.has_method("add_shake"):
			_arthur.camera.call("add_shake", r["shake"], dir)
		Audio.play("wall_crush" if pin >= 0.5 else "heavy_swing", body.global_position)

# --- spin / tornado ---------------------------------------------------------

func _process_spin(delta: float) -> void:
	# Bleed stamina; the whirl ends the moment you run dry. A maxed Stone Flow makes the whirl
	# cheaper — building a rampage unlocks an extended "flow-state" tornado (Musou momentum).
	var cost := spin_cost * (0.85 if Impact.flow_mode else 1.0)
	if not _arthur.try_spend_stamina(cost * delta):
		too_tired.emit()
		_change_state(State.IDLE)
		return
	# Wind the head up to a fast steady whirl (keep whichever way it's already going).
	var target_avel := spin_rate * (1.0 if _avel >= 0.0 else -1.0)
	_avel = move_toward(_avel, target_avel, spin_accel * delta)
	_angle = wrapf(_angle + _avel * delta, -PI, PI)
	_head_dist = lerpf(_head_dist, arm_length + spin_stretch, clampf(8.0 * delta, 0.0, 1.0))
	_lift = lerpf(_lift, 0.25, clampf(6.0 * delta, 0.0, 1.0))
	_apply_spin_hits()
	# Clear the per-target dedup every interval so the whirl keeps catching the crowd.
	_spin_clear -= delta
	if _spin_clear <= 0.0:
		_hit_ids.clear()
		_spin_clear = spin_hit_interval

func _apply_spin_hits() -> void:
	var origin: Vector2 = _arthur.global_position
	for body in hitbox.get_overlapping_bodies():
		if not (body.has_method("apply_hit") or body.has_method("apply_knockback")):
			continue
		if body.is_in_group("allies"):
			continue   # no friendly fire — the stone only shoves allies, never scores on them
		var id := body.get_instance_id()
		if _hit_ids.has(id):
			continue
		_hit_ids[id] = true
		# Launch radially OUTWARD from Arthur — the crowd flies off in a ring.
		var to: Vector2 = body.global_position - origin
		var dir := to.normalized() if to.length() > 1.0 else Vector2.RIGHT.rotated(_angle)
		var pin := 0.0
		if body.has_method("apply_hit"):
			pin = Impact.cushion(self, body.global_position, dir)
		var r := Impact.resolve_hit({
			"kind": "swing", "attacker_mass": Impact.MASS_STONE,
			"relative_speed": maxf(_head_speed, spin_speed_ref), "charge": 0.0,
			"angle_quality": 1.0, "pin": pin,
		})
		if body.has_method("apply_hit"):
			# No per-hit BONK popup here — the whirl pummels a whole crowd; the
			# defeats, SHIELD BREAKs, and the KO count carry the feedback without
			# burying the screen in labels (and without the node churn).
			body.apply_hit(dir, r["knockback"], r["stun"], r["damage"], pin)
			Impact.add_flow(r["flow_gain"])
		else:
			body.apply_knockback(dir, r["knockback"])
		_hit_count += 1
		# Steady rumble (half power); the per-hit FREEZE is suppressed by the
		# state == SPIN check in Arthur._on_weapon_hit, not by this scale.
		hit_landed.emit(r["shake"] * 0.5, _hit_count)

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
	# The heaviest move finally LANDS audibly: a deep thud + rocky crack at the impact point.
	Audio.play("slam", point)
	hit_landed.emit(slam_shake, 0)   # one big shake + hit-stop
	# JUICE: a punch-zoom on the smash so the heaviest move snaps the whole frame, biased along
	# the slam direction so the shake reads as "it landed THAT way".
	if _arthur and _arthur.camera:
		var sdir := Vector2.RIGHT.rotated(_target_aim)
		if _arthur.camera.has_method("kick"):
			_arthur.camera.call("kick", 22.0)
		if _arthur.camera.has_method("add_shake"):
			_arthur.camera.call("add_shake", slam_shake, sdir)

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
	if _head_speed > hit_speed_min or state == State.SLAM_DROP or state == State.SPIN:
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
	# A spin radius ring (drawn in the rotating frame, so it appears as a full circle
	# around Arthur) telegraphs the whirlwind's reach.
	if state == State.SPIN:
		draw_arc(Vector2.ZERO, _head_dist, 0.0, TAU, 40, Color(1.0, 0.7, 0.3, 0.35), 4.0)
	var stone_col := Color(0.45, 0.43, 0.49)
	if state == State.SWING or state == State.SPIN:
		stone_col = stone_col.lerp(Color(1.0, 0.5, 0.2), speed_t)
	draw_circle(head, r, stone_col)
	draw_circle(head - Vector2(r * 0.3, r * 0.3), r * 0.45, stone_col.lightened(0.12))
	draw_circle(head + Vector2(r * 0.35, r * 0.25), r * 0.25, stone_col.darkened(0.22))
	draw_arc(head, r, 0.0, TAU, 28, Color(0.16, 0.15, 0.18), 3.0)
	draw_line(head + Vector2(-r * 0.4, -r * 0.2), head + Vector2(r * 0.1, r * 0.5), Color(0.2, 0.19, 0.22), 2.0)

	# Blade tip poking out the far side of the stone.
	draw_line(head + Vector2(r * 0.7, 0.0), head + Vector2(r + 12.0, 0.0), Color(0.85, 0.87, 0.95), 5.0)

	# A heat ring when the head is really moving — reads the momentum at a glance.
	if speed_t > 0.25 and (state == State.SWING or state == State.SPIN):
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
