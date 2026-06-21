class_name TerrainZone
extends Area2D
## A reusable battlefield terrain rule you place (or spawn) anywhere. ONE script, many
## rules via exports — drop another instance and it behaves identically, so a second
## river/mud/ford uses the same logic. Each physics frame it applies its rule to the
## bodies overlapping it. This is the module that replaces hard-coded terrain loops.
##
## Rules (compose freely on one zone):
##   drag        < 1.0 : velocity kept per frame (mud / shallow water slow)
##   current     != 0  : a steady downstream push (a river's flow)
##   dangerous         : NPCs that avoid terrain steer AROUND it toward a crossing
##                       (see Enemy.avoid_danger + group "crossing") → natural chokepoints
##   drowns_light      : a light UNIT (raider/ally, mass ≤ drown_mass_max) that ends up
##                       inside is removed ("knocked into deep water"). Props never drown.
##   splash            : a SPLASH popup + water_splash sound when a fast body enters
##
## Detection is the Area's own overlap (set collision_mask to the layers it should act on).
## Arthur (a CharacterBody2D) is pushed via move_and_collide so walls still stop him.
## A zone reads its world rect from its RectangleShape2D child, so contains() is cheap.

@export var drag := 1.0                    ## 1.0 = none; ~0.93 shallow water; ~0.86 mud
@export var current := Vector2.ZERO        ## px/s push applied to bodies inside
@export var dangerous := false             ## NPCs with avoid_danger route around this
@export var drowns_light := false          ## remove a light unit that ends up here
@export var drown_mass_max := 1.1          ## "light" = RigidBody mass at or below this
@export var splash := true                 ## SPLASH + water_splash on fast entry
@export var arthur_push := 0.55            ## how much of the current shoves Arthur (0 = none)

var _rect := Rect2()                        ## cached world-space bounds, for contains()

func _ready() -> void:
	add_to_group("terrain")
	if dangerous:
		add_to_group("danger_terrain")
	monitoring = true
	_cache_rect()
	body_entered.connect(_on_body_entered)

## Build the zone's collision shape from a world-space rect (used when spawned in code).
func setup_rect(world_rect: Rect2) -> void:
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = world_rect.size
	cs.shape = shape
	cs.position = world_rect.position + world_rect.size * 0.5
	add_child(cs)
	_rect = world_rect

func _cache_rect() -> void:
	if _rect.size != Vector2.ZERO:
		return
	# Find the rect shape by TYPE, not by node name, so an editor-placed zone works no
	# matter what its CollisionShape2D is called. Fail loudly if it's mis-authored.
	for c in get_children():
		if c is CollisionShape2D and c.shape is RectangleShape2D:
			_rect = Rect2(c.global_position - c.shape.size * 0.5, c.shape.size)
			return
	push_warning("TerrainZone '%s' has no RectangleShape2D — its rule will be inert." % name)

## Is a world point inside this zone? (Cheap rect test — zones don't move.)
func contains(world_point: Vector2) -> bool:
	return _rect.has_point(world_point)

func _physics_process(delta: float) -> void:
	if not monitoring:
		return                      # a disabled zone (e.g. an intact bridge gap) does nothing
	for b in get_overlapping_bodies():
		if not is_instance_valid(b):
			continue
		if b is RigidBody2D:
			# Apply drag + current as IMPULSES, not direct linear_velocity writes, so they
			# COMPOSE with other physics that frame (a swing's knockback, the water wheel's
			# bat) instead of clobbering it — a body in the river can still be launched.
			if drag != 1.0:
				b.apply_central_impulse(b.linear_velocity * (drag - 1.0) * b.mass)
			if current != Vector2.ZERO:
				b.apply_central_impulse(current * delta * b.mass)
			if drowns_light and _is_drownable_unit(b):
				_drown(b)
		elif b is CharacterBody2D and current != Vector2.ZERO and arthur_push > 0.0:
			b.move_and_collide(current * delta * arthur_push)   # respects walls

func _is_drownable_unit(b: Node) -> bool:
	# Only units sink — props (logs/rocks/crates) float and are meant to drift.
	if not (b.is_in_group("targets") or b.is_in_group("allies")):
		return false
	return ("mass" in b) and b.mass <= drown_mass_max

func _drown(unit: Node) -> void:
	# Debounce so a body straddling the rect edge is only drowned/scored ONCE (the unit
	# stays in get_overlapping_bodies until the deferred free flushes). Same guard the
	# wheel/prop hits use; and drop its layer now so it stops overlapping immediately.
	if not Impact.try_collision_hit(unit.get_instance_id(), 1.0):
		return
	unit.set_deferred("collision_layer", 0)
	if splash:
		Audio.play("water_splash", unit.global_position)
	Impact.popup("DROWNED", unit.global_position + Vector2(0, -26), Color(0.55, 0.82, 1.0), 1.1)
	# A drowned raider counts as defeated (you used the terrain); an ally just sinks.
	if unit.is_in_group("targets"):
		Impact.add_kill()
	unit.queue_free()

func _on_body_entered(body: Node) -> void:
	if not splash or not is_instance_valid(body):
		return
	if body is RigidBody2D and body.linear_velocity.length() > 150.0:
		Audio.play("water_splash", body.global_position)
		Impact.popup("SPLASH", body.global_position + Vector2(0, -24), Color(0.6, 0.85, 1.0), 0.9)
