extends RigidBody2D
## A training enemy.
##
## It is now a real physics body: it collides with walls, props, and other
## enemies, gets shoved around by the stone even when you are only aiming, and
## launches when a swing or slam connects. It cannot fight back — it exists to
## make the weight, knockback, and stun read clearly.
##
## Friction is handled by linear_damp (set in the scene) so it slides to a stop
## like a heavy object on dirt. Rotation is locked so the hit-counter stays
## readable.

@export var radius := 16.0

var hit_count := 0
var _flash := 0.0   ## white "just hit" flash, seconds remaining
var _stun := 0.0    ## stun (from slams), seconds remaining
var _t := 0.0       ## free-running clock for the stun spin

func _ready() -> void:
	add_to_group("targets")
	add_to_group("hittable")

## Called by the weapon's hitbox, the passive stone push, and slam shockwaves.
## `strength` is an impulse magnitude; `dir` is a unit vector.
func apply_knockback(dir: Vector2, strength: float) -> void:
	apply_central_impulse(dir * strength)
	_flash = 0.18
	hit_count += 1

func stun(duration: float) -> void:
	_stun = maxf(_stun, duration)

func _process(delta: float) -> void:
	_t += delta
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta)
	if _stun > 0.0:
		_stun = maxf(0.0, _stun - delta)
	queue_redraw()

func _draw() -> void:
	var base := Color(0.78, 0.32, 0.33)
	var col := base.lerp(Color(1, 1, 1), clampf(_flash / 0.18, 0.0, 1.0))
	draw_circle(Vector2.ZERO, radius, col)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 18, Color(0.2, 0.1, 0.1), 2.5)
	if _stun > 0.0:
		# Little orbiting sparks while stunned.
		for i in range(3):
			var a := float(i) / 3.0 * TAU + _t * 7.0
			draw_circle(Vector2(cos(a), sin(a)) * (radius + 7.0), 2.5, Color(1, 0.9, 0.3))
	if hit_count > 0:
		draw_string(ThemeDB.fallback_font, Vector2(-6.0, -radius - 8.0), str(hit_count),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 0.95, 0.7))
