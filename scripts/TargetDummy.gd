extends CharacterBody2D
## A training dummy.
##
## It cannot hurt you; it exists to make the knockback read clearly. Each hit
## flings it across the arena, it slides to a stop with friction, and it bounces
## off walls for a bit of extra comedy. A counter tracks how many times it has
## been clobbered. Press R to reset the arena and stand them all back up.

@export var friction := 720.0  ## how quickly it slides to a stop after a hit
@export var radius := 16.0

var hit_count := 0
var _knockback := Vector2.ZERO
var _flash := 0.0  ## seconds of white "I just got hit" flash remaining

func _ready() -> void:
	add_to_group("targets")

## Called by the StoneWeapon's hitbox when the stone connects.
func apply_knockback(dir: Vector2, strength: float) -> void:
	_knockback = dir * strength
	_flash = 0.18
	hit_count += 1

func _physics_process(delta: float) -> void:
	_knockback = _knockback.move_toward(Vector2.ZERO, friction * delta)
	velocity = _knockback
	move_and_slide()
	if get_slide_collision_count() > 0 and _knockback.length() > 40.0:
		# Rebound off the wall instead of dead-stopping against it.
		var n := get_last_slide_collision().get_normal()
		_knockback = _knockback.bounce(n) * 0.55
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta)
	queue_redraw()

func _draw() -> void:
	var base := Color(0.78, 0.32, 0.33)
	var col := base.lerp(Color(1, 1, 1), clampf(_flash / 0.18, 0.0, 1.0))
	draw_circle(Vector2.ZERO, radius, col)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 18, Color(0.2, 0.1, 0.1), 2.5)
	if hit_count > 0:
		draw_string(ThemeDB.fallback_font, Vector2(-6.0, -radius - 8.0), str(hit_count),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 0.95, 0.7))
