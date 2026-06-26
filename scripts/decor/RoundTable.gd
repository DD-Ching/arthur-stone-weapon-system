class_name RoundTable
extends Node2D
## The Round Table — Camelot's symbol of equal fellowship: a circular table top with a gold
## rim and radial seat marks where the knights sit. Pure code-drawn decor a map drops in the
## great hall; no physics, no image assets. Static geometry, so no per-frame work at all.
##
## The seat count is exported so a hall can dress a fuller or sparser table; the gold trim
## matches Camelot's faction gold so the table reads as Arthur's court at a glance.

## Table-top radius in pixels.
@export var radius := 40.0
## How many knights' seats ring the table (radial marks + place spokes).
@export var seats := 12
## Trim brightness (purely cosmetic; multiplies the gold rim's alpha).
@export var trim := 1.0

## Camelot's gold, matching Enemy.faction_color("camelot"). The rim + spokes use this so the
## Round Table reads as Arthur's court. Kept local so decor has no dependency on Enemy.
func gold_color() -> Color:
	return Color(0.92, 0.78, 0.30)

func _ready() -> void:
	add_to_group("decor")

func _draw() -> void:
	var r := radius
	var g := gold_color()
	var a := clampf(trim, 0.0, 1.5)
	# The table top: a warm wood disc with a darker inner ring so it reads as a turned surface.
	draw_circle(Vector2.ZERO, r, Color(0.46, 0.32, 0.20))
	draw_circle(Vector2.ZERO, r * 0.82, Color(0.54, 0.38, 0.24))
	# A small central boss (the table's hub).
	draw_circle(Vector2.ZERO, r * 0.16, Color(0.40, 0.28, 0.18))
	draw_arc(Vector2.ZERO, r * 0.16, 0.0, TAU, 16, Color(g.r, g.g, g.b, a), 2.0)
	# The gold rim — the trim that marks it as the Round Table.
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, Color(g.r, g.g, g.b, a), 3.0)
	draw_arc(Vector2.ZERO, r * 0.82, 0.0, TAU, 48, Color(g.r, g.g, g.b, a * 0.55), 1.5)
	# Radial seat marks: each knight's place — a short gold spoke to the rim and a seat pip
	# just outside it. Equal places, equal fellowship.
	var n := maxi(seats, 1)
	for i in range(n):
		var ang := float(i) / float(n) * TAU
		var dir := Vector2(cos(ang), sin(ang))
		draw_line(dir * (r * 0.6), dir * (r * 0.95), Color(g.r, g.g, g.b, a * 0.7), 1.5)
		draw_circle(dir * (r + 5.0), 3.0, Color(0.40, 0.28, 0.18))
		draw_arc(dir * (r + 5.0), 3.0, 0.0, TAU, 10, Color(g.r, g.g, g.b, a * 0.8), 1.0)
