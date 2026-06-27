class_name Haystack
extends Breakable
## A bale of hay — a config of Breakable that barely launches (high linear_damp in the .tscn) and
## bursts into yellow straw when smashed. Its twist is being FLAMMABLE: a cheap, THROTTLED proximity
## check ignites it if it's sitting in/near a FireZone, so a torched barrel's pool can spread the
## fire — break the bale and leave a fresh FireZone where it stood.
##
## Cheap: the flammability check runs a few times a second (not every frame) and only walks the
## small "hazard" group; ignition is ONE break + ONE FireZone via the shared FireSpawn helper.

## The fire pool left behind when the bale burns up (ignited by a nearby FireZone).
@export var fire_scene: PackedScene = preload("res://scenes/hazards/FireZone.tscn")
@export var fire_size := Vector2(54.0, 44.0)
## How close a FireZone's edge must be (in px, beyond its own half-extent) to ignite the bale.
@export var ignite_margin := 14.0
## Seconds between flammability checks (throttle — a bale doesn't need a 60fps fire sensor).
@export var ignite_interval := 0.25

var _ignite_cd := 0.0

## Twist on break: leave a small burning pool where the bale stood (straw catches).
func _on_break(_dir: Vector2) -> void:
	FireSpawn.drop(fire_scene, self, global_position, fire_size)

func _process(delta: float) -> void:
	super._process(delta)
	if _dead:
		return
	_ignite_cd -= delta
	if _ignite_cd > 0.0:
		return
	_ignite_cd = ignite_interval
	if _near_fire():
		# Catch fire: break (which scatters straw AND drops a fresh FireZone via _on_break).
		_break(Vector2.UP)

## True if any FireZone overlaps/abuts the bale. Cheap AABB-vs-circle test against the small
## "hazard" group — no physics query, no per-frame work (gated by the throttle above).
func _near_fire() -> bool:
	var tree := get_tree()
	if tree == null:
		return false
	for z in tree.get_nodes_in_group("hazard"):
		if not (z is FireZone) or not is_instance_valid(z):
			continue
		var half: Vector2 = z.size * 0.5 + Vector2(radius + ignite_margin, radius + ignite_margin)
		var d: Vector2 = (global_position - z.global_position).abs()
		if d.x <= half.x and d.y <= half.y:
			return true
	return false

## A rounded mound of hay: a gold dome with a few straw streaks. Flashes white when hit (lit).
func _draw() -> void:
	var lit := clampf(_flash / 0.18, 0.0, 1.0)
	var hay := Color(0.82, 0.68, 0.22, _alpha).lerp(Color(1, 1, 1, _alpha), lit)
	var dark := Color(0.62, 0.48, 0.14, _alpha)
	# The mound: a filled circle squashed a touch (drawn as a wide low ellipse via a polygon ring).
	var pts := PackedVector2Array()
	var n := 16
	for i in range(n):
		var a := TAU * float(i) / float(n)
		pts.append(Vector2(cos(a) * radius * 1.15, sin(a) * radius * 0.85))
	draw_colored_polygon(pts, hay)
	# A few straw streaks for texture.
	for i in range(4):
		var y := -radius * 0.5 + float(i) * radius * 0.4
		draw_line(Vector2(-radius * 0.9, y), Vector2(radius * 0.9, y), dark, 1.5)
