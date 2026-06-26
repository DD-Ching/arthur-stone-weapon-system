class_name CamelotBanner
extends Node2D
## A Camelot / Pendragon standard — a tall pole flying a gold pennant blazoned with a simple
## red dragon (a Pendragon chevron + wings, code-drawn). The faction is exported so the same
## prop dresses Camelot (gold, default), Saxon (moss-green) or Mordred's rebels (black-purple)
## camps, matching Enemy.faction_color so a banner reads the same kingdom as its troops.
##
## The pennant ripples with two cheap sin offsets in _process (no physics, no image assets),
## modelled on FactionBanner but blazoned, so the Arthurian field has its own royal standard.

@export_enum("camelot", "saxon", "rebel") var faction := "camelot"
## Pole height in pixels (the pennant flies from the top); tune per placement.
@export var pole_height := 72.0
## How vigorously the pennant ripples (purely cosmetic).
@export var wave_amount := 5.0

var _t := 0.0

## The standard's field colour, matching Enemy.faction_color (Camelot gold / Saxon moss-green /
## Mordred's rebel black-purple). Kept here so decor has no dependency on Enemy.
func banner_color() -> Color:
	match faction:
		"saxon": return Color(0.40, 0.46, 0.27)
		"rebel": return Color(0.52, 0.33, 0.60)
		_: return Color(0.92, 0.78, 0.30)   # camelot gold (default)

## The blazon (charge) colour painted on the field — Pendragon red on Camelot's gold; a
## darkened field tone on the others so the dragon stays legible against any banner.
func charge_color() -> Color:
	if faction == "camelot":
		return Color(0.74, 0.16, 0.16)   # Pendragon red dragon
	return banner_color().darkened(0.45)

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

	# The pennant: a tall banner hanging from the top, rippled by two sin offsets so the fly
	# edge waves. Built as a small polygon — a handful of points, rebuilt each frame.
	var col := banner_color()
	var flag_w := pole_height * 0.52
	var flag_h := pole_height * 0.66
	var segs := 4
	var pts := PackedVector2Array()
	# Top edge sweeping out from the pole, rising wave amplitude toward the fly.
	for i in range(segs + 1):
		var f := float(i) / float(segs)
		var x := f * flag_w
		var y := top.y + sin(_t * 3.0 + f * 3.2) * wave_amount * f
		pts.append(Vector2(x, y))
	# Bottom edge: a swallow-tail notch at the fly, then back to the pole.
	for i in range(segs, -1, -1):
		var f := float(i) / float(segs)
		var x := f * flag_w
		var notch := 0.0
		if i == segs:
			notch = -flag_h * 0.22   # tail notch at the outer edge
		var y := top.y + flag_h + notch + sin(_t * 3.0 + f * 3.2) * wave_amount * f
		pts.append(Vector2(x, y))
	draw_colored_polygon(pts, col)
	# A darker trim along the fly so the cloth reads as fabric.
	draw_line(pts[segs], pts[segs + 1], col.darkened(0.35), 2.0)

	# The blazon: a simple Pendragon dragon — a chevron body with two swept wings and a head —
	# centred on the field. Drawn small so it reads as a charge, not clutter.
	var cx := flag_w * 0.46
	var cy := top.y + flag_h * 0.46
	var sway := sin(_t * 3.0 + 0.5 * 3.2) * wave_amount * 0.5
	var c := Vector2(cx, cy + sway)
	var charge := charge_color()
	var u := flag_h * 0.18   # blazon unit
	# Body: a downward chevron (the dragon's serpentine spine).
	draw_line(c + Vector2(-u, -u * 0.5), c + Vector2(0.0, u * 0.4), charge, 3.0)
	draw_line(c + Vector2(0.0, u * 0.4), c + Vector2(u, -u * 0.5), charge, 3.0)
	# Wings: two short bars swept up from the spine's apex.
	draw_line(c + Vector2(0.0, u * 0.4), c + Vector2(-u * 0.9, u * 0.0), charge, 2.0)
	draw_line(c + Vector2(0.0, u * 0.4), c + Vector2(u * 0.9, u * 0.0), charge, 2.0)
	# Head: a small dot at the right wing-tip, and a tail flick at the left.
	draw_circle(c + Vector2(u * 1.0, -u * 0.5), u * 0.22, charge)
	draw_line(c + Vector2(-u, -u * 0.5), c + Vector2(-u * 1.3, -u * 0.9), charge, 2.0)
