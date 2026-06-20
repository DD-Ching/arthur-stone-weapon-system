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

@export_group("Stamina")
@export var max_stamina := 100.0
@export var stamina_regen := 24.0
@export var regen_delay := 0.65  ## pause before stamina starts coming back after a swing

var stamina := 0.0
var _regen_cooldown := 0.0
var _hitstop_token := 0

@onready var weapon: StoneWeapon = $StoneWeapon
@onready var camera = $Camera2D  ## untyped: GameCamera adds add_shake() at runtime

func _ready() -> void:
	stamina = max_stamina
	weapon.hit_landed.connect(_on_weapon_hit)
	weapon.state_changed.connect(_on_weapon_state_changed)
	weapon.charge_changed.connect(_on_weapon_charge_changed)
	weapon.too_tired.connect(_on_weapon_too_tired)
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
	var mult := _speed_multiplier()
	if dir != Vector2.ZERO:
		velocity = velocity.move_toward(dir * max_speed * mult, accel * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
	move_and_slide()

## While the weapon is busy you are far less mobile — that is the cost of power.
func _speed_multiplier() -> float:
	match weapon.state:
		StoneWeapon.State.WINDUP:
			return 0.35   # bracing — barely shuffling
		StoneWeapon.State.ACTIVE:
			return 0.6    # dragged along by the swing's momentum
		StoneWeapon.State.RECOVERY:
			return 0.22   # fully committed, fully exposed
		StoneWeapon.State.SLAM_RAISE:
			return 0.24   # heaving the stone overhead
		StoneWeapon.State.SLAM_HOLD:
			return 0.14   # frozen at the top of the lift
		StoneWeapon.State.SLAM_DROP:
			return 0.3
		StoneWeapon.State.SLAM_RECOVER:
			return 0.2    # planted, wide open
		_:
			return 1.0

func _handle_stamina(delta: float) -> void:
	if _regen_cooldown > 0.0:
		_regen_cooldown -= delta
	elif stamina < max_stamina:
		stamina = minf(max_stamina, stamina + stamina_regen * delta)
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

func _on_weapon_state_changed(state: int) -> void:
	weapon_state_changed.emit(_state_name(state), 0.0)

func _on_weapon_charge_changed(charge: float) -> void:
	weapon_state_changed.emit("WINDING", charge)

func _on_weapon_too_tired() -> void:
	exhausted.emit()

func _state_name(state: int) -> String:
	match state:
		StoneWeapon.State.WINDUP:
			return "WINDING"
		StoneWeapon.State.ACTIVE:
			return "SWING!"
		StoneWeapon.State.RECOVERY:
			return "RECOVER"
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
