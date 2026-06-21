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

@export_group("Movement")
@export var max_speed := 158.0
@export var accel := 620.0     ## low → slow to reach top speed (he is hauling a rock)
@export var friction := 480.0  ## modest → he keeps drifting when you stop steering
@export var dash_friction := 520.0   ## how fast a swing-lunge bleeds off
@export var max_dash_speed := 340.0  ## cap on stacked lunges — heavy, not a rocket

@export_group("Stamina")
@export var max_stamina := 100.0
@export var stamina_regen := 24.0
@export var regen_delay := 0.65  ## pause before stamina starts coming back after a swing

var stamina := 0.0
var _regen_cooldown := 0.0
var _hitstop_token := 0
var _steer := Vector2.ZERO     ## input-driven velocity (carries momentum)
var _dash_vel := Vector2.ZERO  ## swing-lunge burst, decays on its own

@onready var weapon: StoneWeapon = $StoneWeapon
@onready var camera = $Camera2D  ## untyped: GameCamera adds add_shake() at runtime

func _ready() -> void:
	stamina = max_stamina
	weapon.hit_landed.connect(_on_weapon_hit)
	weapon.state_changed.connect(_on_weapon_state_changed)
	weapon.charge_changed.connect(_on_weapon_charge_changed)
	weapon.too_tired.connect(_on_weapon_too_tired)
	Impact.impact_fx.connect(_on_impact_fx)   # shake/hit-stop from props + bowling hits
	stamina_changed.emit(stamina, max_stamina)

func _physics_process(delta: float) -> void:
	_handle_aim()
	_handle_attack()
	_handle_movement(delta)
	_handle_stamina(delta)
	queue_redraw()

func _handle_aim() -> void:
	var to_mouse := get_global_mouse_position() - global_position
	if to_mouse.length() > 4.0:
		weapon.set_aim_target(to_mouse.angle())

func _handle_attack() -> void:
	if Input.is_action_just_pressed("attack"):
		weapon.press_attack()
	if Input.is_action_just_released("attack"):
		weapon.release_attack()
	if Input.is_action_just_pressed("slam"):
		weapon.start_slam()

func _handle_movement(delta: float) -> void:
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	# Stone Flow (stack 2+) grants a little extra mobility — still hauling a rock.
	var mult := _speed_multiplier() * Impact.move_mult()
	if dir != Vector2.ZERO:
		_steer = _steer.move_toward(dir * max_speed * mult, accel * delta)
	else:
		_steer = _steer.move_toward(Vector2.ZERO, friction * delta)
	# The swing-lunge is a separate burst that bleeds off on its own, so it reads as
	# a dash you can chain rather than something your steering eats.
	_dash_vel = _dash_vel.move_toward(Vector2.ZERO, dash_friction * delta)
	velocity = _steer + _dash_vel
	move_and_slide()

## A forward burst from a swing — displacement that stacks (chain swings to sprint
## across the field), capped so Arthur stays heavy rather than turning into a rocket.
func lunge(impulse: Vector2) -> void:
	_dash_vel = (_dash_vel + impulse).limit_length(max_dash_speed)

## While the weapon is busy you are far less mobile — that is the cost of power.
func _speed_multiplier() -> float:
	match weapon.state:
		StoneWeapon.State.SWING:
			return 0.6    # committed mid-swing — but the lunge is carrying you forward
		StoneWeapon.State.SLAM_RAISE:
			return 0.24   # heaving the stone overhead
		StoneWeapon.State.SLAM_HOLD:
			return 0.14   # frozen at the top of the lift
		StoneWeapon.State.SLAM_DROP:
			return 0.3
		StoneWeapon.State.SLAM_RECOVER:
			return 0.2    # planted, wide open
		_:
			return 1.0   # IDLE

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

func _on_weapon_hit(shake_strength: float, _count: int) -> void:
	if camera and camera.has_method("add_shake"):
		camera.call("add_shake", shake_strength)
	_do_hit_stop(clampf(shake_strength * 0.006, 0.02, 0.10))

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

func _state_name(state: int) -> String:
	match state:
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
	draw_circle(Vector2.ZERO, 17.0, Color(0.85, 0.74, 0.55))
	draw_arc(Vector2.ZERO, 17.0, 0.0, TAU, 20, Color(0.25, 0.2, 0.15), 3.0)
	var face := Vector2.RIGHT.rotated(weapon.aim_angle) * 10.0 if weapon else Vector2.ZERO
	draw_circle(face, 5.0, Color(0.2, 0.18, 0.16))
