class_name FloatingText
extends Node2D
## A short-lived label that rises from an impact point and fades — the "BONK",
## "WALL CRUSH", "BOWLING HIT" pop-ups that make a hit legible.
##
## Drawn in code (no font asset) using the engine's fallback font, so it works in
## a clean checkout and in the web build. Spawn it via Impact.popup().

var _text := ""
var _color := Color.WHITE
var _size := 22
var _life := 0.0
var _max_life := 0.7
var _vel := Vector2(0.0, -52.0)

func setup(text: String, color: Color = Color.WHITE, scale: float = 1.0) -> void:
	add_to_group("floating_text")   # so Impact can cap concurrent labels
	_text = text
	_color = color
	_size = int(round(22.0 * scale))
	_max_life = 0.55 + 0.3 * scale
	_vel = Vector2(0.0, -52.0 * scale)
	queue_redraw()

func _process(delta: float) -> void:
	_life += delta
	position += _vel * delta
	# Ease the rise to a stop, frame-rate-independent (web FPS can stutter).
	_vel.y = move_toward(_vel.y, 0.0, 90.0 * delta)
	queue_redraw()
	if _life >= _max_life:
		queue_free()

func _draw() -> void:
	var a := clampf(1.0 - _life / _max_life, 0.0, 1.0)
	# A quick pop-in: the label is biggest just after it appears.
	var pop := 1.0 + 0.25 * clampf(1.0 - _life / 0.12, 0.0, 1.0)
	var size := int(round(_size * pop))
	var font := ThemeDB.fallback_font
	var w: float = font.get_string_size(_text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var off := Vector2(-w * 0.5, 0.0)
	# Drop shadow first so it stays readable over any background.
	draw_string(font, off + Vector2(2.0, 2.0), _text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0, 0, 0, a * 0.6))
	draw_string(font, off, _text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(_color.r, _color.g, _color.b, a))
