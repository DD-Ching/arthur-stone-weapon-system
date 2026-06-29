class_name AmbientDrift
extends Node2D
## Drifting ambient particles that make a region feel ALIVE — embers over a battlefield, mist over
## Avalon, dust on a dry hill, leaves on a road, snow on a moor. ONE reusable Node2D; a map drops
## one from `_build_decor` and sets `kind` + `area` + colour.
##
## Web-safe + cheap: a fixed, capped pool of points integrated in _process (no spawning churn, no
## allocation), each wrapping inside `area`; drawn as small code shapes. `randf()` is fine in game
## runtime (only Workflow scripts restrict it). Behind units via a low z_index.

@export_enum("embers", "mist", "dust", "leaves", "snow") var kind := "embers"
@export var count := 36
@export var area := Rect2(-640.0, -440.0, 1280.0, 900.0)   ## the world rect the drift fills
@export var tint := Color(1.0, 0.6, 0.25, 0.5)
@export var drift := Vector2(14.0, -22.0)                  ## base velocity (px/s)
@export var size_px := 2.6
@export var speed_jitter := 0.6

const MAX_COUNT := 64

var _p: PackedVector2Array = PackedVector2Array()   ## positions
var _v: PackedVector2Array = PackedVector2Array()   ## per-particle velocity
var _ph: PackedFloat32Array = PackedFloat32Array()  ## phase (sway / twinkle)
var _t := 0.0

func _ready() -> void:
	add_to_group("decor")
	z_index = -20
	var n := clampi(count, 0, MAX_COUNT)
	for _i in n:
		_p.append(Vector2(area.position.x + randf() * area.size.x, area.position.y + randf() * area.size.y))
		var j := 1.0 + (randf() - 0.5) * 2.0 * speed_jitter
		_v.append(drift * j + Vector2((randf() - 0.5) * 8.0, (randf() - 0.5) * 8.0))
		_ph.append(randf() * TAU)

func _process(delta: float) -> void:
	_t += delta
	for i in _p.size():
		var pos := _p[i] + _v[i] * delta
		# A gentle horizontal sway so motion isn't a straight line.
		pos.x += sin(_t * 1.4 + _ph[i]) * 6.0 * delta
		# Wrap inside the area so the pool is eternal without re-spawning.
		if pos.x < area.position.x: pos.x = area.end.x
		elif pos.x > area.end.x: pos.x = area.position.x
		if pos.y < area.position.y: pos.y = area.end.y
		elif pos.y > area.end.y: pos.y = area.position.y
		_p[i] = pos
	queue_redraw()

func _draw() -> void:
	for i in _p.size():
		var tw := 0.6 + 0.4 * sin(_t * 3.0 + _ph[i])      # twinkle / fade
		var col := Color(tint.r, tint.g, tint.b, tint.a * tw)
		match kind:
			"mist":
				draw_circle(_p[i], size_px * 6.0, Color(tint.r, tint.g, tint.b, tint.a * 0.10 * tw))
			"leaves":
				var a := _t * 2.0 + _ph[i]
				draw_line(_p[i], _p[i] + Vector2(cos(a), sin(a)) * size_px * 2.0, col, 2.0)
			"snow":
				draw_circle(_p[i], size_px, Color(tint.r, tint.g, tint.b, tint.a))
			"dust":
				draw_circle(_p[i], size_px * 1.4, Color(tint.r, tint.g, tint.b, tint.a * 0.4 * tw))
			_:  # embers
				draw_circle(_p[i], size_px, col)
