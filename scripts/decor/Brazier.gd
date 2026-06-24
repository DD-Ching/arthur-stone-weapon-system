class_name Brazier
extends Node2D
## A small camp brazier — a stone bowl holding a flickering fire. Pure code-drawn decor for
## camps, gates, and night-time staging; no physics, no image assets.
##
## The flicker is a couple of cheap sin/noise offsets in _process scaling a few stacked flame
## circles, so the fire breathes without allocating. Tiny and self-contained.

## Bowl radius in pixels; the flame scales with it.
@export var bowl_radius := 12.0
## Flame liveliness (how much the tongues jump). Purely cosmetic.
@export var flicker := 1.0

var _t := 0.0
var _seed := 0.0

func _ready() -> void:
	add_to_group("decor")
	_seed = randf() * 10.0   # de-sync braziers placed side by side

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _draw() -> void:
	# The stone bowl: a dark filled half-disc with a lighter rim, sitting at the origin.
	draw_circle(Vector2(0.0, 2.0), bowl_radius, Color(0.26, 0.24, 0.23))
	draw_arc(Vector2(0.0, 2.0), bowl_radius, 0.0, TAU, 18, Color(0.42, 0.39, 0.36), 2.0)
	# Glowing coals across the top of the bowl.
	draw_circle(Vector2(0.0, 0.0), bowl_radius * 0.7, Color(0.85, 0.35, 0.12, 0.9))
	# Flame tongues: a few stacked circles whose height + width breathe with two offset sines,
	# so the fire flickers rather than pulsing uniformly.
	var f := flicker
	var tongues := 3
	for i in range(tongues):
		var k := float(i) / float(tongues)
		var jitter := sin(_t * 11.0 + _seed + k * 5.0) * 0.5 + 0.5
		var lift := (bowl_radius * 0.6) + k * bowl_radius * (1.1 + 0.6 * jitter * f)
		var r := bowl_radius * (0.62 - k * 0.34) * (0.8 + 0.5 * jitter * f)
		var sway := sin(_t * 7.0 + _seed * 1.7 + k * 3.0) * bowl_radius * 0.25 * f
		# Hotter (yellow-white) at the base, redder at the tip.
		var col := Color(1.0, 0.75 - k * 0.45, 0.18, 0.85 - k * 0.35)
		draw_circle(Vector2(sway, -lift), r, col)
