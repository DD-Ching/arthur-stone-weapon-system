class_name Breakable
extends RigidBody2D
## A smashable battlefield prop — the reuse-first destruction base.
##
## Configure it as a `.tscn` (mass, damping, a `_draw()` look) and set the exports below; it then:
##   - shoves / launches like any prop (the shared apply_knockback contract Rock/Shockwave use),
##   - takes a full hit from the swung stone / a bowled body / a slam (apply_hit, returning the
##     same {blocked, broke} shape Enemy does so the weapon's feedback branch is happy),
##   - SHATTERS into flying debris (Impact.shatter) when a hit is hard enough or its health runs
##     out — pieces fly out with a pop + shake + sound, and it can drop a hurlable piece.
##
## Build once, reuse many: every material (Barrel, ClayPot, Haystack, FireBarrel, BreakableFence…)
## is a CONFIG of this — tune the exports + override `_draw()`, and override `_on_break()` for a
## twist (an explosion, a fire pool, a scatter). No per-material destruction code.

@export var max_health := 30.0
@export var hard_hit := 600.0                ## hit strength that shatters it outright (vs Impact.KNOCK_*)
@export var radius := 16.0
@export var debris_scene: PackedScene = preload("res://scenes/props/ChunkDebris.tscn")
@export var debris_count := 5
@export var chunk_color := Color(0.5, 0.36, 0.22)
@export var debris_speed := Vector2(160.0, 340.0)
@export var drops_piece: PackedScene = null  ## e.g. Rock.tscn — spawned where it broke (ammo)
@export var smash_label := "SMASH"
@export var break_sound := "shield_break"

var health := 0.0
var _dead := false
var _flash := 0.0
var _alpha := 1.0

func _ready() -> void:
	add_to_group("props")
	add_to_group("hittable")
	collision_layer = 8       # "props" physics layer (the stone Hitbox/mask hits this)
	gravity_scale = 0.0       # top-down: no falling
	health = max_health
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

## Launch contract (a swing/slam/shatter calls this): shove, and shatter on a hard enough shove.
func apply_knockback(dir: Vector2, strength: float) -> void:
	apply_central_impulse(dir * strength)
	_flash = 0.15
	queue_redraw()
	if strength >= hard_hit and not _dead:
		_break(dir)

## Full hit (the stone swing + slam shockwave route props through has_method("apply_hit")).
## Returns {blocked, broke} like Enemy.apply_hit so the weapon's feedback picks the right label.
func apply_hit(dir: Vector2, raw_strength: float, _stun_time: float, raw_dmg: float, _pin: float = 0.0) -> Dictionary:
	apply_central_impulse(dir * raw_strength)
	_flash = 0.18
	queue_redraw()
	health -= raw_dmg
	var broke := false
	if (health <= 0.0 or raw_strength >= hard_hit) and not _dead:
		broke = true
		_break(dir)
	return {"blocked": false, "broke": broke}

## A bowled body slamming into the prop also breaks it (closes the "throw stuff to smash stuff" loop).
func _on_body_entered(body: Node) -> void:
	if _dead or not is_instance_valid(body):
		return
	if body is RigidBody2D and body.linear_velocity.length() > 220.0:
		_break((global_position - body.global_position).normalized())

func _break(dir: Vector2) -> void:
	if _dead:
		return
	_dead = true
	set_deferred("collision_layer", 0)
	Impact.shatter(debris_scene, global_position, debris_count, debris_speed, chunk_color)
	Impact.popup(smash_label, global_position + Vector2(0.0, -radius - 8.0), Color(0.92, 0.86, 0.7), 1.1)
	Impact.impact_fx.emit(0.4)
	Audio.play(break_sound, global_position)
	if drops_piece != null:
		var scene := get_tree().current_scene
		if scene != null:
			var p = drops_piece.instantiate()
			scene.add_child(p)
			p.global_position = global_position
	_on_break(dir)
	queue_free()

## Override for a twist on break (explosion, fire, scatter). Default: nothing extra.
func _on_break(_dir: Vector2) -> void:
	pass

func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta)
		queue_redraw()

## Default crate-ish look; material configs override this with their own silhouette.
func _draw() -> void:
	var lit := clampf(_flash / 0.18, 0.0, 1.0)
	var col := Color(0.5, 0.36, 0.22, _alpha).lerp(Color(1, 1, 1, _alpha), lit)
	draw_rect(Rect2(-radius, -radius, radius * 2.0, radius * 2.0), col)
	draw_rect(Rect2(-radius, -radius, radius * 2.0, radius * 2.0), Color(0.3, 0.2, 0.12, _alpha), false, 2.0)
