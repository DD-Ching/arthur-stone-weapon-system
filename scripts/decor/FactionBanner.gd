class_name FactionBanner
extends Node2D
## A tall faction standard — a pole topped with a waving pennant whose colour reads the
## kingdom (魏 Wei blue / 蜀 Shu green / 吳 Wu red / neutral grey). Pure code-drawn decor:
## maps drop one near a gate, a camp, or a spawn to give the field Three-Kingdoms flavour.
##
## The wave is two cheap sin offsets in _process so the pennant ripples; no physics, no
## image assets, allocation-light. The colour table MIRRORS Enemy.faction_color so a banner
## and the troops fighting under it read as the same kingdom at a glance.

@export_enum("neutral", "wei", "shu", "wu") var faction := "neutral"
## Pole height in pixels (the pennant flies from the top); tune per placement.
@export var pole_height := 64.0
## How vigorously the pennant ripples (purely cosmetic).
@export var wave_amount := 5.0

var _t := 0.0

## The standard's colour, matching Enemy.faction_color (魏 Wei blue / 蜀 Shu green /
## 吳 Wu red / neutral grey). Kept here too so decor has no dependency on Enemy.
func banner_color() -> Color:
	match faction:
		"wei": return Color(0.30, 0.52, 0.95)
		"shu": return Color(0.36, 0.78, 0.42)
		"wu": return Color(0.86, 0.36, 0.34)
		_: return Color(0.70, 0.70, 0.72)

func _ready() -> void:
	add_to_group("decor")

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _draw() -> void:
	var top := Vector2(0.0, -pole_height)
	# The pole: a stout shaft with a small finial knob at the top.
	draw_line(Vector2.ZERO, top, Color(0.40, 0.31, 0.21), 4.0)
	draw_circle(top, 3.5, Color(0.86, 0.74, 0.45))
	# The pennant: a flag streaming to the right of the pole, rippled by two sin offsets so
	# the trailing edge waves. Built once per frame as a small polygon — a handful of points.
	var col := banner_color()
	var flag_len := pole_height * 0.55
	var flag_h := pole_height * 0.30
	var pts := PackedVector2Array()
	var segs := 5
	# Top edge (anchored at the pole) sweeping out to the fly, with a rising wave amplitude.
	for i in range(segs + 1):
		var f := float(i) / float(segs)
		var x := f * flag_len
		var y := top.y + sin(_t * 4.0 + f * 3.2) * wave_amount * f
		pts.append(Vector2(x, y))
	# Bottom edge back to the pole, the same wave so the cloth stays a ribbon.
	for i in range(segs, -1, -1):
		var f := float(i) / float(segs)
		var x := f * flag_len
		var y := top.y + flag_h + sin(_t * 4.0 + f * 3.2) * wave_amount * f
		pts.append(Vector2(x, y))
	draw_colored_polygon(pts, col)
	# A darker trim along the fly edge so the cloth reads as fabric, not a flat block.
	draw_line(pts[segs], pts[segs + 1], col.darkened(0.35), 2.0)
