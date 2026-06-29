class_name Arthur
extends CharacterBody2D
## Arthur — the chosen one who flunked the test.
##
## He lifted the entire stone along with the sword, so he is strong, slow, and a
## bit of a liability. This script owns his body: momentum-based movement, the
## stamina pool, and forwarding weapon events to the camera and HUD.
##
## Movement is intentionally floaty: a low acceleration means he is slow to get
## going (dead weight), and a modest friction means he keeps sliding after you
## let go (momentum). While the weapon is busy, his top speed is throttled hard.

signal stamina_changed(current: float, maximum: float)
signal weapon_state_changed(state_name: String, charge: float)
signal exhausted()
signal health_changed(current: float, maximum: float)
signal died()
signal musou_changed(current: float, maximum: float)   ## the musou rage gauge — fills as you fight, for the HUD

## The ULTIMATE reuses the slam's Shockwave (the one shared radial-launch path) — just
## bigger: a huge radius + impulse + stun centred on Arthur clears the whole screen.
const SHOCKWAVE := preload("res://scenes/Shockwave.tscn")
const MUSOU_CHARGE_MAX := 2.5   ## seconds you can build the rage burst (charge longer → wider clear)
const HAPTIC_HIT_FLOOR := 12.0  ## min hit-shake that buzzes a touch device (a meaty clash/slam, not every light tap)
## The musou ULTIMATE — a screen-clearing RADIAL burst (the iconic Musou crowd-wipe). Charge scales
## the radius from a wide circle around Arthur to the whole screen; it launches + fells the horde.
const MUSOU_RADIUS_MIN := 340.0
const MUSOU_RADIUS_MAX := 640.0   ## clears a CLUSTER you position, not the whole screen
const MUSOU_IMPULSE := 1700.0
const MUSOU_STUN := 1.4
const MUSOU_DAMAGE_MULT := 2.5    ## wipes chaff, leaves elites/bosses standing (a reset, not an "I win")
const MUSOU_COOLDOWN := 12.0      ## hard floor between ults — an earned panic button, not a rotation filler

@export_group("Movement")
@export var max_speed := 185.0
@export var accel := 740.0     ## a juggernaut who closes on the horde — but can't freely kite the whole map
@export var friction := 480.0  ## modest → he keeps drifting when you stop steering
@export var dash_friction := 520.0   ## how fast a swing-lunge bleeds off
@export var max_dash_speed := 310.0  ## cap on stacked lunges — heavy, not a rocket

@export_group("Stamina")
@export var max_stamina := 100.0
@export var stamina_regen := 22.0
@export var regen_delay := 0.7   ## a real recover gate: sustained offense drains you, forcing burst-and-reposition
@export var low_stamina_threshold := 25.0  ## below this, a readable SOFT slowdown tapers in (not a hard stop) — running dry should sap you, not cliff

@export_group("Health")
@export var max_health := 140.0
@export var invuln_time := 0.26  ## i-frames after a hit: short, so a CROWD can punish bad positioning (a single duelist still can't chain-melt) — the master difficulty lever

@export_group("Musou")
## The rage gauge. Fills from landing hits, scoring KOs, and taking damage; at full
## it powers a screen-clearing ULTIMATE (a huge radial launch centred on Arthur).
@export var max_musou := 300.0
@export var musou_kill_gain := 8.0    ## gauge added per enemy you fell — the ult is earned by FIGHTING WELL
@export var musou_hurt_gain := 5.0    ## small: suffering no longer charges your win button (was the "tank-then-nuke" exploit)

var stamina := 0.0
var health := 0.0
var musou := 0.0               ## current rage charge, 0..max_musou
var _musou_charge := 0.0       ## seconds the Q ult has been charged (held), 0..MUSOU_CHARGE_MAX
var _ult_cd := 0.0             ## cooldown remaining before the ult can be charged/fired again
var _regen_cooldown := 0.0
var _hitstop_token := 0
var _hurt := 0.0               ## red hit-flash, seconds remaining
var _invuln := 0.0
var _steer := Vector2.ZERO     ## input-driven velocity (carries momentum)
var _dash_vel := Vector2.ZERO  ## swing-lunge burst, decays on its own
var _last_aim := 0.0           ## last drawn facing — redraw only when it changes
var _touch_cache = null        ## the on-screen touch controls (mobile), or null on desktop
var _last_kills := 0           ## previous Impact.kills, so each NEW KO feeds the musou gauge once

@onready var weapon: StoneWeapon = $StoneWeapon
@onready var camera = $Camera2D  ## untyped: GameCamera adds add_shake() at runtime

func _ready() -> void:
	stamina = max_stamina
	health = max_health
	add_to_group("player")
	weapon.hit_landed.connect(_on_weapon_hit)
	weapon.state_changed.connect(_on_weapon_state_changed)
	weapon.charge_changed.connect(_on_weapon_charge_changed)
	weapon.too_tired.connect(_on_weapon_too_tired)
	Impact.impact_fx.connect(_on_impact_fx)   # shake/hit-stop from props + bowling hits
	Impact.kills_changed.connect(_on_kills_changed)   # each KO feeds the musou gauge
	_last_kills = Impact.kills
	stamina_changed.emit(stamina, max_stamina)
	health_changed.emit(health, max_health)
	musou_changed.emit(musou, max_musou)

func _physics_process(delta: float) -> void:
	if _hurt > 0.0:
		_hurt = maxf(0.0, _hurt - delta)
	if _invuln > 0.0:
		_invuln = maxf(0.0, _invuln - delta)
	if _ult_cd > 0.0:
		_ult_cd = maxf(0.0, _ult_cd - delta)
	_handle_aim()
	# Lead the camera a touch toward where the stone is aimed (musou look-ahead).
	if camera and camera.has_method("set_focus"):
		camera.call("set_focus", Vector2.RIGHT.rotated(weapon.aim_angle))
	_handle_attack(delta)
	_handle_movement(delta)
	_handle_stamina(delta)
	# Only redraw when something visible changes (hurt flash, i-frame blink, or the
	# facing dot turning) — moving is a transform, not a redraw.
	if _hurt > 0.0 or _invuln > 0.0 or absf(weapon.aim_angle - _last_aim) > 0.001:
		_last_aim = weapon.aim_angle
		queue_redraw()

## An enemy attack connected. Brief i-frames, a knock away from the source, a
## hurt flash, and the combo breaks. Returns true if the hit actually landed.
func take_damage(amount: float, from_pos: Vector2 = Vector2.ZERO) -> bool:
	if health <= 0.0 or _invuln > 0.0:
		return false
	health = maxf(0.0, health - amount)
	_hurt = 0.35
	_invuln = invuln_time
	# Spin INTERRUPT: a hit landing while you're whirling knocks you out of the spin, so
	# standing-and-spinning into a shield/spear wall is punished instead of being free.
	# stop_spin() is idempotent — a no-op unless we're actually in SPIN.
	if weapon and weapon.state == StoneWeapon.State.SPIN:
		weapon.stop_spin()
	add_musou(musou_hurt_gain)   # suffering stokes the rage — taking a hit charges the gauge
	Impact.note_damage()
	if camera and camera.has_method("add_shake"):
		camera.call("add_shake", 12.0)
	if from_pos != Vector2.ZERO:
		lunge((global_position - from_pos).normalized() * 45.0)   # a small shove — no longer a free escape from the crowd
	health_changed.emit(health, max_health)
	if health <= 0.0:
		died.emit()
	return true

## On a touchscreen the right stick owns aiming (the mouse is stale on mobile), and on
## desktop nothing changes — `_touch_controls()` is null so we fall through to the cursor.
func _handle_aim() -> void:
	var tc = _touch_controls()
	if tc and tc.active_ui:
		# TOUCH-SWING ASSIST: circling a thumb is hard, so while the aim-stick is held the
		# weapon ramps a barely-circling aim up to a usable swing (pointer play is untouched
		# because this only ever turns on under an active touch stick).
		weapon.set_touch_assist(tc.aim_active)
		if tc.aim_active:
			weapon.set_aim_target(tc.aim_angle)
		return
	weapon.set_touch_assist(false)
	var to_mouse := get_global_mouse_position() - global_position
	if to_mouse.length() > 4.0:
		weapon.set_aim_target(to_mouse.angle())

## The on-screen touch controls, cached. They live under the HUD and announce themselves
## via the "touch_controls" group; null when there's no HUD (e.g. the swing smoke test).
func _touch_controls():
	if _touch_cache == null or not is_instance_valid(_touch_cache):
		_touch_cache = get_tree().get_first_node_in_group("touch_controls")
	return _touch_cache

func _handle_attack(delta: float) -> void:
	# Q is the CHARGE-BEAM ultimate: HOLD musou (while you have gauge) to CHARGE, RELEASE to fire a
	# sustained light beam for as long as you charged (the gauge you spent → the beam you spray —
	# "charge however long, spray that long"). The early return is load-bearing: a held/charging Q
	# must not also swing/slam. Guarded so a build without the `musou` action is a clean no-op.
	if InputMap.has_action("musou"):
		if Input.is_action_pressed("musou") and musou > 0.0 and _ult_cd <= 0.0:
			_musou_charge = minf(_musou_charge + delta, MUSOU_CHARGE_MAX)
			add_musou(-(max_musou / MUSOU_CHARGE_MAX) * delta)   # holding drains the gauge into charge
			weapon.stop_spin()
			weapon.set_swinging(false)
			return
		elif _musou_charge > 0.0:   # released (or the gauge ran dry) → unleash the burst
			_unleash_musou(_musou_charge)
			_musou_charge = 0.0
			return
	# Hold to whirl (the musou tornado); takes priority over swing/slam while held.
	# The early return is load-bearing: holding spin must not also fire a swing/slam
	# in the same frame. stop_spin() is idempotent — safe to call every frame.
	if Input.is_action_pressed("spin"):
		weapon.start_spin()
		return
	weapon.stop_spin()
	# Hold the attack button to enter swing mode — the mouse DRAG does the swinging.
	weapon.set_swinging(Input.is_action_pressed("attack"))
	if Input.is_action_just_pressed("slam"):
		weapon.start_slam()

func _handle_movement(delta: float) -> void:
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	# Fold in the touch stick (zero on desktop / when untouched, so this is a no-op there).
	var tc = _touch_controls()
	if tc:
		dir = (dir + tc.move_vec).limit_length(1.0)
	# Stone Flow (stack 2+) grants a little extra mobility — still hauling a rock.
	var mult := _speed_multiplier() * Impact.move_mult()
	if dir != Vector2.ZERO:
		_steer = _steer.move_toward(dir * max_speed * mult, accel * delta)
	else:
		_steer = _steer.move_toward(Vector2.ZERO, friction * delta)
	# The swing-lunge is a separate burst that bleeds off on its own, so it reads as
	# a dash you can chain rather than something your steering eats.
	_dash_vel = _dash_vel.move_toward(Vector2.ZERO, dash_friction * delta)
	# Hard cap so stacked lunges + buffs can never turn the heavy man into a rocket.
	velocity = (_steer + _dash_vel).limit_length(max_speed + max_dash_speed)
	move_and_slide()

## A forward burst from a swing — displacement that stacks (chain swings to sprint
## across the field), capped so Arthur stays heavy rather than turning into a rocket.
func lunge(impulse: Vector2) -> void:
	_dash_vel = (_dash_vel + impulse).limit_length(max_dash_speed)

## While the weapon is busy you are far less mobile — that is the cost of power.
## On TOP of that, running low on stamina saps your speed: a readable SOFT slowdown
## that tapers in below `low_stamina_threshold` instead of an abrupt cliff, so a near-
## empty pool feels like wading rather than a sudden, un-fun stop.
func _speed_multiplier() -> float:
	var base := _weapon_speed_multiplier()
	return base * _low_stamina_taper()

## The weapon-state mobility penalty — the cost of power. (Split out so the low-stamina
## taper composes cleanly and the per-state numbers stay readable.)
func _weapon_speed_multiplier() -> float:
	match weapon.state:
		StoneWeapon.State.SPIN:
			return 0.82   # a moving tornado — you carve through the crowd, not rooted
		StoneWeapon.State.SLAM_RAISE:
			return 0.42   # heaving the stone overhead, but still advancing
		StoneWeapon.State.SLAM_HOLD:
			return 0.32   # braced at the top of the lift
		StoneWeapon.State.SLAM_DROP:
			return 0.45
		StoneWeapon.State.SLAM_RECOVER:
			return 0.4    # planted, but recovering quicker than before
		_:
			return 1.0   # IDLE

## A soft low-stamina slowdown: 1.0 at/above the threshold, tapering DOWN toward a small
## non-zero crawl as the pool empties (so a tired Arthur wades, he doesn't freeze). Even a
## truly empty pool only reaches LOW_STAMINA_FLOOR — running dry saps your speed, it never
## stops you dead. A readable slope, not an abrupt cliff.
const LOW_STAMINA_FLOOR := 0.45   ## slowest the taper alone ever drags you (at empty) — a crawl, never a freeze
func _low_stamina_taper() -> float:
	if stamina >= low_stamina_threshold:
		return 1.0
	var t := clampf(stamina / maxf(low_stamina_threshold, 0.001), 0.0, 1.0)
	return lerpf(LOW_STAMINA_FLOOR, 1.0, t)

func _handle_stamina(delta: float) -> void:
	if _regen_cooldown > 0.0:
		_regen_cooldown -= delta
	elif stamina < max_stamina:
		# Stone Flow mode regens slower, so the powered-up state stays a window you
		# spend, not a place you park — keeps the combat clock ticking.
		var rate := stamina_regen * (0.7 if Impact.flow_mode else 1.0)
		stamina = minf(max_stamina, stamina + rate * delta)
		stamina_changed.emit(stamina, max_stamina)

## Spend stamina if we can afford it. Returns false when too tired (caller fizzles).
func try_spend_stamina(cost: float) -> bool:
	if stamina < cost:
		return false
	stamina -= cost
	_regen_cooldown = regen_delay
	stamina_changed.emit(stamina, max_stamina)
	return true

## Add to the musou rage gauge (clamped 0..max), and announce the change to the HUD.
## Only emits when the value actually moved, so it never spams a maxed/empty gauge.
func add_musou(amount: float) -> void:
	var before := musou
	musou = clampf(musou + amount, 0.0, max_musou)
	if not is_equal_approx(musou, before):
		musou_changed.emit(musou, max_musou)

## Each new KO (the shared Impact musou counter) feeds the gauge a little.
func _on_kills_changed(k: int, milestone: String) -> void:
	if k > _last_kills:
		add_musou(musou_kill_gain * float(k - _last_kills))
	_last_kills = k
	# A KO MILESTONE (RAMPAGE! / WARLORD! / …) snaps the screen — escalating Musou spectacle on top
	# of the HUD's gold pulse, so a rising rampage is FELT, not just a number.
	if milestone != "":
		if camera and camera.has_method("kick"):
			camera.call("kick", 30.0)
		if camera and camera.has_method("add_shake"):
			camera.call("add_shake", 18.0)
		Impact.popup(milestone, global_position + Vector2(0.0, -112.0), Color(1.0, 0.8, 0.32), 1.8)
		Audio.play("ko_milestone", global_position)   # a rising stinger so the rampage is HEARD too

func _on_weapon_hit(shake_strength: float, _count: int) -> void:
	if camera and camera.has_method("add_shake"):
		camera.call("add_shake", shake_strength)
	# Landing a heavy hit feeds the musou gauge — bigger hits charge it faster (modest, so the ult
	# is built by sustained good play, not a couple of swings).
	add_musou(shake_strength * 0.2)
	# The whirlwind hits constantly — a freeze per hit would stutter it to a crawl,
	# so spin gets only the rumble, not the hit-stop.
	if weapon.state != StoneWeapon.State.SPIN:
		_do_hit_stop(clampf(shake_strength * 0.006, 0.02, 0.10))
	# JUICE (touch only): a short rumble on a meaty clash/slam — NOT on the constant spin
	# whirl (which would buzz the phone forever). Guarded — desktop has no touch controls
	# (null) and the method is optional, so this is a clean no-op there.
	if weapon.state != StoneWeapon.State.SPIN and shake_strength >= HAPTIC_HIT_FLOOR:
		var tc = _touch_controls()   # reuse the cached lookup, not a fresh group scan per hit
		if tc and tc.has_method("_haptic"):
			tc._haptic(12)

## A brief, real-time freeze on impact — the cheapest way to make a hit feel like
## it connected with something heavy. Bigger hits freeze a touch longer. The
## token guard means overlapping hits don't restore time early.
func _do_hit_stop(duration: float) -> void:
	Engine.time_scale = 0.06
	_hitstop_token += 1
	var token := _hitstop_token
	await get_tree().create_timer(duration, true, false, true).timeout
	if token == _hitstop_token:
		Engine.time_scale = 1.0

## A scored hit from a non-weapon source (a launched rock/crate, a bowling enemy,
## a slam). Same camera shake + hit-stop language as a swing, scaled down a bit so
## ambient chain-reactions don't lock up the screen.
func _on_impact_fx(strength: float) -> void:
	if camera and camera.has_method("add_shake"):
		camera.call("add_shake", strength)
	# Always freeze a touch on a connected prop/bowling hit — it's already scaled
	# well below a swing's hit-stop, so even rapid chains won't lock the screen.
	_do_hit_stop(clampf(strength * 0.005, 0.02, 0.07))

func _on_weapon_state_changed(state: int) -> void:
	weapon_state_changed.emit(_state_name(state), 0.0)

func _on_weapon_charge_changed(power: float) -> void:
	weapon_state_changed.emit("POWER", power)

func _on_weapon_too_tired() -> void:
	Impact.note_exhausted()   # running dry mid-combo breaks Stone Flow
	exhausted.emit()

## The musou ULTIMATE — a screen-clearing RADIAL burst centred on Arthur (the iconic Musou
## crowd-wipe, the design the class doc describes). A longer charge widens the clear from a circle
## around you to the whole screen and snaps the camera harder. Reuses the shared Shockwave radial
## path + the Enemy hit path; the reserved top-tier kick/shake/announce sell the biggest moment.
func _unleash_musou(charge: float) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		scene = get_parent()   # headless harnesses often add Arthur straight under the test root
	if scene == null:
		return
	var power := clampf(charge / MUSOU_CHARGE_MAX, 0.0, 1.0)
	var sw = SHOCKWAVE.instantiate()   # untyped: a Node2D
	scene.add_child(sw)
	sw.global_position = global_position
	sw.radius = lerpf(MUSOU_RADIUS_MIN, MUSOU_RADIUS_MAX, power)
	sw.impulse = MUSOU_IMPULSE
	sw.stun_time = MUSOU_STUN
	sw.damage_mult = MUSOU_DAMAGE_MULT
	sw.life = 0.7
	sw.detonate()
	# RESERVED top-tier juice — the single biggest moment in the game snaps the frame.
	if camera and camera.has_method("kick"):
		camera.call("kick", lerpf(34.0, 64.0, power))
	if camera and camera.has_method("add_shake"):
		camera.call("add_shake", lerpf(24.0, 40.0, power))
	# A bold centre-screen announce (ASCII + gold per the web-font tofu rule) + a dedicated ROAR.
	Impact.popup("MUSOU!", global_position + Vector2(0.0, -96.0), Color(1.0, 0.85, 0.3), 2.2)
	Audio.play("musou_roar", global_position)
	_ult_cd = MUSOU_COOLDOWN   # block back-to-back ults regardless of gauge — the ult is earned

## Back-compat alias (HUD / headless test / a build that calls it directly): empty the gauge and
## unleash a full-power radial burst centred on Arthur.
func trigger_musou_ultimate() -> void:
	musou = 0.0
	musou_changed.emit(musou, max_musou)
	_unleash_musou(MUSOU_CHARGE_MAX)

func _state_name(state: int) -> String:
	match state:
		StoneWeapon.State.SPIN:
			return "SPIN!"
		StoneWeapon.State.SWING:
			return "SWING!"
		StoneWeapon.State.SLAM_RAISE, StoneWeapon.State.SLAM_HOLD:
			return "SLAM!"
		StoneWeapon.State.SLAM_DROP:
			return "SMASH!"
		StoneWeapon.State.SLAM_RECOVER:
			return "RECOVER"
		_:
			return "READY"

func _draw() -> void:
	# Placeholder Arthur: a stout little figure with a dot showing his facing.
	var body_col := Color(0.85, 0.74, 0.55)
	if _hurt > 0.0:
		body_col = body_col.lerp(Color(1.0, 0.3, 0.3), clampf(_hurt / 0.35, 0.0, 1.0))
	# Blink while invulnerable so the i-frames are readable.
	if _invuln > 0.0 and int(_invuln * 30.0) % 2 == 0:
		body_col = body_col.darkened(0.25)
	draw_circle(Vector2.ZERO, 17.0, body_col)
	draw_arc(Vector2.ZERO, 17.0, 0.0, TAU, 20, Color(0.25, 0.2, 0.15), 3.0)
	var face := Vector2.RIGHT.rotated(weapon.aim_angle) * 10.0 if weapon else Vector2.ZERO
	draw_circle(face, 5.0, Color(0.2, 0.18, 0.16))
