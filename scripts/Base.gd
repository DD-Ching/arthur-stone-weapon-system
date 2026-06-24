class_name Base
extends Node2D
## A capturable supply base — the Guandu (官渡) granary depot mechanic, built once so any
## map can place it. A Base sits in group "bases" with a capture `radius`. It is captured
## once it has been ENGAGED (a live raider was ever inside the radius) AND no live raider
## (group "targets", not `_dead`) remains inside it. So you take a depot by clearing the
## garrison Arthur fights around it — the same "defeat the targets" contract every map uses,
## scoped to a circle on the field.
##
## Pure-code art (`_draw`): a granary mound + a banner pole, drawn in the holder's colour;
## the colour flips from the foe's (魏 Wei) to the captor's (蜀 Shu) once taken, with a
## "CAPTURED" popup. Cheap and web-safe — it only re-scans a few times a second and only
## redraws when its state changes.

## How far from the centre a raider counts as "garrisoning" this base.
@export var radius := 150.0
## Banner colour BEFORE capture (the enemy holder — 魏 Wei blue by default).
@export var enemy_color := Color(0.30, 0.52, 0.95)
## Banner colour AFTER capture (the captor — 蜀 Shu green by default).
@export var captured_color := Color(0.36, 0.78, 0.42)
## A short label drawn under the granary, pure flavour.
@export var label := "GRANARY"

var captured := false
var _engaged := false          ## a raider was EVER inside — guards the empty-first-frame case
var _scan_cd := 0.0
var _pulse := 0.0

func _ready() -> void:
	add_to_group("bases")
	queue_redraw()

func _physics_process(delta: float) -> void:
	_pulse += delta
	if captured:
		queue_redraw()
		return
	_scan_cd -= delta
	if _scan_cd > 0.0:
		return
	_scan_cd = 0.2
	var inside := _live_raiders_inside()
	if inside > 0:
		_engaged = true
	elif _engaged:
		_capture()
	queue_redraw()

## How many live raiders (group "targets", not defeated) sit within `radius`.
func _live_raiders_inside() -> int:
	var n := 0
	for e in get_tree().get_nodes_in_group("targets"):
		if not is_instance_valid(e):
			continue
		if "_dead" in e and e._dead:
			continue
		if e.global_position.distance_to(global_position) <= radius:
			n += 1
	return n

func _capture() -> void:
	if captured:
		return
	captured = true
	Impact.popup("%s CAPTURED" % label, global_position + Vector2(0.0, -radius - 18.0),
		captured_color, 1.4)
	Audio.play("stone_flow_gain", global_position)   # a positive chime; unknown events no-op
	queue_redraw()

func is_captured() -> bool:
	return captured

# ── drawing (pure code art) ──────────────────────────────────────────────────
func _draw() -> void:
	var col := captured_color if captured else enemy_color
	# Capture-radius ring — faint, so the contested area reads on the field.
	var ring := col
	ring.a = 0.16 + 0.05 * sin(_pulse * 2.0)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, ring, 2.0)
	# Granary mound: a filled dome with a darker rim + a small stack of sacks.
	draw_circle(Vector2(0.0, 6.0), 30.0, Color(0.40, 0.34, 0.24))
	draw_arc(Vector2(0.0, 6.0), 30.0, PI, TAU, 24, Color(0.22, 0.18, 0.12), 3.0)
	draw_circle(Vector2(-16.0, -2.0), 8.0, Color(0.62, 0.52, 0.34))
	draw_circle(Vector2(16.0, -2.0), 8.0, Color(0.62, 0.52, 0.34))
	draw_circle(Vector2(0.0, -10.0), 8.0, Color(0.7, 0.6, 0.4))
	# Banner pole + pennant, in the holder's colour — the flag flips on capture.
	draw_line(Vector2(0.0, -10.0), Vector2(0.0, -58.0), Color(0.45, 0.38, 0.3), 3.0)
	var flag := PackedVector2Array([
		Vector2(0.0, -58.0), Vector2(26.0, -50.0), Vector2(0.0, -42.0)])
	draw_colored_polygon(flag, col)
	draw_circle(Vector2(0.0, -58.0), 3.0, Color(0.85, 0.8, 0.7))
	# Label under the mound.
	draw_string(ThemeDB.fallback_font, Vector2(-30.0, 30.0), label,
		HORIZONTAL_ALIGNMENT_CENTER, 60.0, 12, Color(0.92, 0.88, 0.78, 0.9))
	if captured:
		draw_string(ThemeDB.fallback_font, Vector2(-30.0, 44.0), "HELD",
			HORIZONTAL_ALIGNMENT_CENTER, 60.0, 11, captured_color)
