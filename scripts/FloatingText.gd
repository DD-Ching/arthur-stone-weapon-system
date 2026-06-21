class_name FloatingText
extends Node2D
## A short-lived label that rises from an impact point and fades — the "BONK",
## "WALL CRUSH", "BOWLING HIT" pop-ups that make a hit legible.
##
## Drawn ONCE (no font asset, just the engine's fallback font); the rise, fade, and
## pop-in are done with the node's position / modulate / scale, so _draw never
## re-runs. That keeps a chaotic combo's worth of labels cheap on the web build.
## Spawn it via Impact.popup().

var _text := ""
var _color := Color.WHITE
var _size := 22
var _life := 0.0
var _max_life := 0.7
var _vel := Vector2(0.0, -52.0)

func setup(text: String, color: Color = Color.WHITE, scale_factor: float = 1.0) -> void:
	add_to_group("floating_text")   # so Impact can cap concurrent labels
	_text = text
	_color = color
	_size = int(round(22.0 * scale_factor))
	_max_life = 0.55 + 0.3 * scale_factor
	_vel = Vector2(0.0, -52.0 * scale_factor)
	modulate = Color(1, 1, 1, 1)
	queue_redraw()   # the only redraw — the text content never changes

func _process(delta: float) -> void:
	_life += delta
	position += _vel * delta
	# Ease the rise to a stop, frame-rate-independent (web FPS can stutter).
	_vel.y = move_toward(_vel.y, 0.0, 90.0 * delta)
	# Fade + pop-in via node properties — the engine applies these without a redraw.
	modulate.a = clampf(1.0 - _life / _max_life, 0.0, 1.0)
	var pop := 1.0 + 0.25 * clampf(1.0 - _life / 0.12, 0.0, 1.0)
	scale = Vector2(pop, pop)
	if _life >= _max_life:
		queue_free()

func _draw() -> void:
	var font := ThemeDB.fallback_font
	var w: float = font.get_string_size(_text, HORIZONTAL_ALIGNMENT_LEFT, -1, _size).x
	var off := Vector2(-w * 0.5, 0.0)
	# Drop shadow first so it stays readable over any background.
	draw_string(font, off + Vector2(2.0, 2.0), _text, HORIZONTAL_ALIGNMENT_LEFT, -1, _size, Color(0, 0, 0, 0.6))
	draw_string(font, off, _text, HORIZONTAL_ALIGNMENT_LEFT, -1, _size, _color)
