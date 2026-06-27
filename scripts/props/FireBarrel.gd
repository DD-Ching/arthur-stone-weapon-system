class_name FireBarrel
extends Breakable
## The marquee EXPLOSIVE prop — a barrel of pitch/oil. A config of Breakable that adds a twist on
## break: a radial Impact.explode boom (launch + damage everything hittable in the ring) AND a
## lingering FireZone pool at the break point, so smashing it both blows raiders back and leaves
## the ground burning. Build-once-reuse-many: no bespoke destruction code, just `_on_break`.
##
## Cheap on purpose: ONE explode call + ONE FireZone per break (the shared budgeted Impact path),
## a small debris_count, and a code-drawn barrel (no textures).

## AoE blast (radius / impulse / damage / stun) fed to Impact.explode on break.
@export var blast_radius := 110.0
@export var blast_impulse := 700.0
@export var blast_damage := 24.0
@export var blast_stun := 0.4

## The burning pool dropped where the barrel broke (one per break).
@export var fire_scene: PackedScene = preload("res://scenes/hazards/FireZone.tscn")
@export var fire_size := Vector2(72.0, 56.0)

## Twist on break: blow the ring, then leave a fire pool at the barrel's spot.
func _on_break(_dir: Vector2) -> void:
	Impact.explode(self, global_position, blast_radius, blast_impulse, blast_damage, blast_stun)
	FireSpawn.drop(fire_scene, self, global_position, fire_size)

## A squat barrel: dark staves, two metal hoops, and a red hazard band + flame mark so it reads
## "explosive" at a glance. Flashes white on a hit (lit) like the base Breakable.
func _draw() -> void:
	var lit := clampf(_flash / 0.18, 0.0, 1.0)
	var body := Color(0.34, 0.22, 0.12, _alpha).lerp(Color(1, 1, 1, _alpha), lit)
	var hoop := Color(0.55, 0.55, 0.6, _alpha).lerp(Color(1, 1, 1, _alpha), lit)
	var w := radius * 1.7
	var h := radius * 2.0
	# Barrel body (staves drawn as a filled rect with a dark outline).
	draw_rect(Rect2(-w * 0.5, -h * 0.5, w, h), body)
	draw_rect(Rect2(-w * 0.5, -h * 0.5, w, h), Color(0.2, 0.12, 0.06, _alpha), false, 2.0)
	# Two metal hoops top and bottom.
	draw_rect(Rect2(-w * 0.5, -h * 0.42, w, 3.0), hoop)
	draw_rect(Rect2(-w * 0.5, h * 0.42 - 3.0, w, 3.0), hoop)
	# Red hazard band across the middle.
	draw_rect(Rect2(-w * 0.5, -3.0, w, 6.0), Color(0.85, 0.18, 0.12, _alpha))
	# A small flame mark in the centre: a triangle tongue (yellow core over orange).
	_flame_mark(Vector2(0.0, 1.0), radius * 0.5, Color(0.95, 0.45, 0.12, _alpha))
	_flame_mark(Vector2(0.0, 1.0), radius * 0.3, Color(1.0, 0.85, 0.35, _alpha))

func _flame_mark(base: Vector2, s: float, col: Color) -> void:
	draw_colored_polygon(PackedVector2Array([
		base + Vector2(-s * 0.5, 0.0),
		base + Vector2(s * 0.5, 0.0),
		base + Vector2(0.0, -s * 1.4),
	]), col)
