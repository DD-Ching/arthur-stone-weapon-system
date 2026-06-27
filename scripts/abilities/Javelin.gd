class_name Javelin
extends Area2D
## A cheap thrown spear — the projectile behind the "javelin" Ability.
##
## It is an Area2D (no rigid-body cost): it slides along a fixed heading, hits the
## FIRST opposing-team body it overlaps, pops a label, and frees itself. It also frees
## on a short lifetime cap so a thrown miss can never linger. Single-threaded web build
## friendly: no per-frame group scans, monitoring only, no physics solving.
##
## Friendly fire: it carries the THROWER's team and ignores any body in that group, so
## a raider's javelin can't hit raiders and an ally's can't hit allies.

var _vel := Vector2.ZERO
var _damage := 8.0
var _team := "raiders"        ## thrower's team — bodies in this group are immune
var _life := 0.0
var _max_life := 1.6          ## hard cap so a miss self-frees
var _spent := false           ## hit once, now fading out

func _ready() -> void:
	# Detect overlaps without being a solid body. We set the mask/layer in code so the
	# scene file needs no shape wiring beyond its CollisionShape2D.
	monitoring = true
	monitorable = false
	collision_layer = 0
	# arthur(bit2=2) + enemies(bit3=4): the two teams that can be foes; + weapon(bit5=16) so the
	# swung STONE can intercept the shaft. Walls/props are still ignored — a javelin flies over
	# scenery in this top-down toy.
	collision_mask = 2 | 4 | 16
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

## Aim + arm the projectile. Called by Ability after add_child so the transform is set
## before anything reads position (same pattern as Shockwave.detonate).
func launch(from: Vector2, dir: Vector2, speed: float, dmg: float, team: String) -> void:
	global_position = from
	rotation = dir.angle()
	_vel = dir.normalized() * speed
	_damage = dmg
	_team = team

func _physics_process(delta: float) -> void:
	if _spent:
		return
	global_position += _vel * delta
	_life += delta
	if _life >= _max_life:
		_expire()

func _on_body_entered(body: Node) -> void:
	if _spent or not is_instance_valid(body):
		return
	# The swung stone (its solid body, only enabled when parked/slow) DEFLECTS the shaft — the
	# stone is a shield as well as a club. Checked before the combatant branch so a raised stone
	# stops the arrow no matter whose side threw it.
	if body.is_in_group("stone_weapon"):
		_deflect()
		return
	if body.is_in_group(_team):
		return                                  # never hit the thrower's own side
	var dir := _vel.normalized()
	if body.has_method("take_damage"):
		body.take_damage(_damage, global_position)        # Arthur / allies
	elif body.has_method("apply_hit"):
		body.apply_hit(dir, 150.0, 0.12, _damage)          # enemy body
	else:
		return                                  # not a combatant (shouldn't happen via mask)
	Impact.popup("JAVELIN", global_position + Vector2(0.0, -22.0), Color(0.85, 0.8, 0.6))
	_expire()

## Blocked by the stone: a spark + a small Stone-Flow reward for a clean block, then gone.
func _deflect() -> void:
	Impact.popup("DEFLECT", global_position + Vector2(0.0, -22.0), Color(0.82, 0.9, 1.0), 1.1)
	Impact.add_flow(4.0)
	Impact.impact_fx.emit(0.3)
	Audio.play("shield_block", global_position)
	_expire()

## Stop, hide, and free next frame. We don't free inside the signal so a body_entered
## mid-iteration can't invalidate us under the physics server.
func _expire() -> void:
	_spent = true
	_vel = Vector2.ZERO
	set_deferred("monitoring", false)
	visible = false
	queue_free()

func _draw() -> void:
	# A short shaft with a tip — drawn once along local +X (rotation aims it).
	draw_line(Vector2(-10.0, 0.0), Vector2(10.0, 0.0), Color(0.7, 0.62, 0.45), 2.5)
	draw_colored_polygon(PackedVector2Array([
		Vector2(10.0, 0.0), Vector2(4.0, -3.0), Vector2(4.0, 3.0),
	]), Color(0.86, 0.86, 0.9))
