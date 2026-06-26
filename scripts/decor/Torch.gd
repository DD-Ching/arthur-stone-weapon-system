class_name Torch
extends Node2D
## A wall-mounted torch — an iron sconce holding a flickering flame, the light that lines a
## castle hall or a ford-side palisade at dusk. Pure code-drawn decor (no physics, no image
## assets), a vertical counterpart to the floor Brazier so a wall can be lit without a bowl.
##
## The flame flickers with a couple of cheap offset sines in _process scaling stacked tongues,
## plus a soft halo whose alpha breathes — allocation-light, web-safe (alpha multiplied).

## Sconce/flame scale in pixels.
@export var torch_size := 10.0
## Flame liveliness (how much the tongues jump). Purely cosmetic.
@export var flicker := 1.0

var _t := 0.0
var _seed := 0.0

func _ready() -> void:
	add_to_group("decor")
	_seed = randf() * 10.0   # de-sync torches lining a wall

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _draw() -> void:
	var s := torch_size
	var f := clampf(flicker, 0.0, 2.0)
	# The iron bracket: a short arm off the wall and a cup that holds the brand.
	var iron := Color(0.22, 0.21, 0.23)
	draw_line(Vector2(-s * 0.9, s * 1.4), Vector2(0.0, s * 0.9), iron, 3.0)
	draw_line(Vector2(0.0, s * 0.9), Vector2(0.0, s * 0.2), Color(0.30, 0.22, 0.14), 4.0)  # the brand
	# The cup ring around the flame's base.
	draw_arc(Vector2(0.0, s * 0.2), s * 0.55, PI, TAU, 12, iron, 2.5)
	# Glowing coals at the brand's head.
	draw_circle(Vector2(0.0, s * 0.05), s * 0.5, Color(0.9, 0.4, 0.12, 0.9))

	# A soft halo whose alpha breathes — the torchlight pooling around the flame.
	var breathe := 0.5 + 0.5 * sin(_t * 5.0 + _seed)
	draw_circle(Vector2(0.0, -s * 0.4), s * 2.4, Color(1.0, 0.7, 0.3, (0.07 + 0.05 * breathe) * f))

	# Flame tongues: stacked circles whose height + width breathe with offset sines so the
	# fire flickers rather than pulsing uniformly. Hotter (yellow-white) at the base, redder up.
	var tongues := 3
	for i in range(tongues):
		var k := float(i) / float(tongues)
		var jitter := sin(_t * 12.0 + _seed + k * 5.0) * 0.5 + 0.5
		var lift := (s * 0.2) + k * s * (1.0 + 0.6 * jitter * f)
		var r := s * (0.55 - k * 0.3) * (0.8 + 0.5 * jitter * f)
		var sway := sin(_t * 8.0 + _seed * 1.7 + k * 3.0) * s * 0.22 * f
		var col := Color(1.0, 0.74 - k * 0.45, 0.16, 0.85 - k * 0.35)
		draw_circle(Vector2(sway, -lift), r, col)
