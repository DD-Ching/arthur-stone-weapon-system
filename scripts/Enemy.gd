class_name Enemy
extends RigidBody2D
## A physics enemy. One script, several flavours — each enemy *type* is just this
## scene with different exported values (mass, health, look, shield), so adding a
## type costs a .tscn, not a class.
##
## It is a real RigidBody2D: it collides with walls, props, and other enemies,
## gets shoved by the stone even when you are only aiming, and launches when hit.
## Crucially it can BOWL — when it is flung fast into another enemy, that counts
## as a real impact (damage, combo, "BOWLING HIT"). Heavy types barely fly (good
## as moving cover); light types sail across the room (great bowling balls).
##
## Mass lives on the body (set per scene), so the same knockback impulse launches
## a light soldier far and a heavy guard barely — see Impact.BASE_KNOCK.

@export var enemy_name := "Dummy"
@export_enum("dummy", "soldier", "shield", "heavy") var look := "dummy"
@export var radius := 16.0
@export var base_color := Color(0.78, 0.32, 0.33)
@export var max_health := 1.0e9         ## dummies: effectively a punching bag
@export var shielded := false
@export var shield_angle := PI          ## which way the shield faces (radians); PI = toward -X
@export var shield_block := 0.22        ## fraction of a frontal hit that gets through

var health := 0.0
var hit_count := 0
var _flash := 0.0      ## white "just hit" flash, seconds remaining
var _stun := 0.0       ## stun seconds remaining
var _t := 0.0          ## free-running clock (stun spin, etc.)
var _dead := false
var _alpha := 1.0      ## fade-out on defeat
var _chain := 0        ## consecutive enemies this body has bowled while still flying

func _ready() -> void:
	add_to_group("targets")
	add_to_group("hittable")
	health = max_health
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

# ── taking a hit ────────────────────────────────────────────────────────────

## Low-level: an impulse + a flash. Used by the slam shockwave and by anything
## that only wants to shove (kept for back-compat with the swing/tests).
func apply_knockback(dir: Vector2, strength: float) -> void:
	apply_central_impulse(dir * strength)
	_flash = 0.18
	hit_count += 1

## Full hit: knockback + stun + damage + maybe defeat. Used by the weapon swing
## and by Impact.collide() for props/bowling.
func apply_hit(dir: Vector2, strength: float, stun_time: float, dmg: float) -> void:
	apply_knockback(dir, strength)
	if stun_time > 0.0:
		stun(stun_time)
	health -= dmg
	if health <= 0.0 and not _dead:
		_defeat()

## How much of a frontal hit a shield lets through (1.0 = no shield / flanked).
## A hit pushes the target along `dir`; the shield blocks if it faces into that.
func block_factor(dir: Vector2) -> float:
	if not shielded or _dead:
		return 1.0
	var facing := Vector2.RIGHT.rotated(shield_angle)
	if facing.dot(dir) < -0.35:   # force comes from the shielded side
		return shield_block
	return 1.0

func stun(duration: float) -> void:
	_stun = maxf(_stun, duration)

func _defeat() -> void:
	_dead = true
	_chain = 0
	set_deferred("collision_layer", 0)   # stop colliding, keep sliding out
	Impact.popup("DOWN!", global_position + Vector2(0, -28), Color(1.0, 0.9, 0.4), 1.1)
	Impact.add_flow(10.0)

# ── bowling: flung into another enemy ───────────────────────────────────────

func _on_body_entered(body: Node) -> void:
	if _dead or not is_instance_valid(body):
		return
	if not body.is_in_group("targets"):
		return
	var speed := linear_velocity.length()
	if speed < Impact.BOWL_MIN_SPEED:
		return
	# Only the faster body initiates, so a collision is scored once, not twice.
	if body is RigidBody2D and body.linear_velocity.length() > speed:
		return
	if not Impact.try_collision_hit(body.get_instance_id()):
		return
	_chain += 1
	var dir: Vector2 = (body.global_position - global_position).normalized()
	Impact.collide(body, dir, speed, Impact.MASS_ENEMY, "bowling", self, _chain)

# ── per-frame ───────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	_t += delta
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta)
	if _stun > 0.0:
		_stun = maxf(0.0, _stun - delta)
	if linear_velocity.length() < 60.0:
		_chain = 0   # came to rest — a fresh launch starts a new chain
	if _dead:
		_alpha = maxf(0.0, _alpha - delta * 1.6)
		if _alpha <= 0.0:
			queue_free()
	# Only redraw when something visible is actually animating. A hit sets _flash
	# (>0), which covers the frame the hit-counter changes; a static enemy keeps its
	# last drawn frame. Saves a redraw per idle enemy per frame on the web build.
	if _flash > 0.0 or _stun > 0.0 or _alpha < 1.0:
		queue_redraw()

# ── drawing ─────────────────────────────────────────────────────────────────

func _draw() -> void:
	var col := base_color.lerp(Color(1, 1, 1), clampf(_flash / 0.18, 0.0, 1.0))
	col.a = _alpha
	draw_circle(Vector2.ZERO, radius, col)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 20, Color(0.16, 0.1, 0.1, _alpha), 2.5)

	match look:
		"soldier":
			# a little facing nub so a launched soldier reads as "a guy"
			draw_circle(Vector2(radius * 0.35, 0.0), radius * 0.28, Color(0.95, 0.9, 0.8, _alpha))
		"shield":
			var a0 := shield_angle - 0.9
			var a1 := shield_angle + 0.9
			draw_arc(Vector2.ZERO, radius + 5.0, a0, a1, 14, Color(0.7, 0.72, 0.8, _alpha), 6.0)
		"heavy":
			draw_arc(Vector2.ZERO, radius * 0.6, 0.0, TAU, 16, Color(0.2, 0.16, 0.16, _alpha), 4.0)

	if _stun > 0.0:
		for i in range(3):
			var a := float(i) / 3.0 * TAU + _t * 7.0
			draw_circle(Vector2(cos(a), sin(a)) * (radius + 7.0), 2.5, Color(1, 0.9, 0.3, _alpha))
	if hit_count > 0 and not _dead:
		draw_string(ThemeDB.fallback_font, Vector2(-6.0, -radius - 8.0), str(hit_count),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 0.95, 0.7, _alpha))
