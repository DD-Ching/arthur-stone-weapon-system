class_name LitBrazier
extends Breakable
## A LIT camp brazier you can smash. A config of Breakable that, when broken, scatters its burning
## coals into a small FireZone pool at its feet — knock one over and you've started a fire. It
## reuses the camp Brazier's code-drawn bowl + flickering flame look (no textures), but unlike the
## decor Brazier it's a real breakable RigidBody2D the stone can topple.
##
## Cheap: ONE small FireZone per break (the shared FireSpawn helper), a low debris_count, and a
## throttled flame redraw so a row of braziers doesn't churn the single-threaded web build.

## The coal pool dropped when the brazier is knocked over (smaller than a barrel's blast pool).
@export var fire_scene: PackedScene = preload("res://scenes/hazards/FireZone.tscn")
@export var fire_size := Vector2(46.0, 38.0)
## Bowl radius for the drawn brazier; the flame scales with it (mirrors Brazier.bowl_radius).
@export var bowl_radius := 12.0

var _seed := 0.0
var _redraw_cd := 0.0   ## throttle so the live flame reshimmers ~15x/sec, not 60x (web-safe, per FireZone)

func _ready() -> void:
	super._ready()
	_seed = randf() * 10.0   # de-sync braziers placed side by side

## Twist on break: scatter the coals into a small burning pool where the brazier stood.
func _on_break(_dir: Vector2) -> void:
	FireSpawn.drop(fire_scene, self, global_position, fire_size)

func _process(delta: float) -> void:
	super._process(delta)
	# A live flame needs to reshimmer; the base only redraws while flashing. THROTTLE it the way
	# FireZone does — ~15x/sec, not every frame — so a row of lit braziers doesn't re-tessellate
	# flame circles at 60fps on the single-threaded web build (the _draw reads the SceneTree clock,
	# so the flame still moves smoothly between redraws).
	_redraw_cd -= delta
	if _redraw_cd <= 0.0:
		_redraw_cd = 1.0 / 15.0
		queue_redraw()

## Reuses the camp Brazier silhouette: a dark stone bowl with a lighter rim, glowing coals, and a
## few stacked flame tongues that breathe with two offset sines. Flashes white when hit (lit).
func _draw() -> void:
	var t := float(Time.get_ticks_msec()) / 1000.0
	var lit := clampf(_flash / 0.18, 0.0, 1.0)
	# The stone bowl.
	draw_circle(Vector2(0.0, 2.0), bowl_radius, Color(0.26, 0.24, 0.23, _alpha).lerp(Color(1, 1, 1, _alpha), lit))
	draw_arc(Vector2(0.0, 2.0), bowl_radius, 0.0, TAU, 18, Color(0.42, 0.39, 0.36, _alpha), 2.0)
	# Glowing coals across the top of the bowl.
	draw_circle(Vector2(0.0, 0.0), bowl_radius * 0.7, Color(0.85, 0.35, 0.12, 0.9 * _alpha))
	# Flame tongues: stacked circles whose height + width breathe with two offset sines.
	var tongues := 3
	for i in range(tongues):
		var k := float(i) / float(tongues)
		var jitter := sin(t * 11.0 + _seed + k * 5.0) * 0.5 + 0.5
		var lift := (bowl_radius * 0.6) + k * bowl_radius * (1.1 + 0.6 * jitter)
		var r := bowl_radius * (0.62 - k * 0.34) * (0.8 + 0.5 * jitter)
		var sway := sin(t * 7.0 + _seed * 1.7 + k * 3.0) * bowl_radius * 0.25
		var col := Color(1.0, 0.75 - k * 0.45, 0.18, (0.85 - k * 0.35) * _alpha)
		draw_circle(Vector2(sway, -lift), r, col)
