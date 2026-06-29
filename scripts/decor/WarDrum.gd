class_name WarDrum
extends Node2D
## A great war drum on a frame — the camp standard that beats troops into a charge. Pure
## code-drawn decor for the Arthurian field; no physics, no image assets.
##
## The drumhead breathes with a slow sin pulse (a struck-skin shimmer) and the faction studs
## ring its rim, so a camp reads its house even from the drum. Allocation-light.

@export_enum("neutral", "camelot", "briton", "saxon", "rebel", "pict", "fae") var faction := "neutral"
## Drum radius in pixels; the stand scales with it.
@export var drum_radius := 22.0

var _t := 0.0

## The house accent colour (Camelot gold / Briton blue / Saxon moss-green / rebel purple / Pict
## slate / Fae cyan / neutral grey), mirroring Enemy.faction_color so a drum matches the banners
## and troops of its camp.
func accent_color() -> Color:
	match faction:
		"camelot": return Color(0.92, 0.78, 0.30)
		"briton": return Color(0.34, 0.56, 0.92)
		"saxon": return Color(0.40, 0.46, 0.27)
		"rebel": return Color(0.52, 0.33, 0.60)
		"pict": return Color(0.46, 0.52, 0.58)
		"fae": return Color(0.55, 0.80, 0.80)
		_: return Color(0.70, 0.70, 0.72)

func _ready() -> void:
	add_to_group("decor")

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _draw() -> void:
	var r := drum_radius
	# The A-frame stand legs splaying under the drum.
	var col_wood := Color(0.40, 0.31, 0.21)
	draw_line(Vector2(-r * 0.7, 0.0), Vector2(-r * 1.1, r * 1.6), col_wood, 4.0)
	draw_line(Vector2(r * 0.7, 0.0), Vector2(r * 1.1, r * 1.6), col_wood, 4.0)
	# The drum body: a dark barrel.
	draw_circle(Vector2.ZERO, r, Color(0.34, 0.22, 0.16))
	# The drumhead: a taut skin that shimmers slightly when "struck" (slow pulse).
	var pulse := 1.0 + 0.04 * sin(_t * 6.0)
	draw_circle(Vector2.ZERO, r * 0.84 * pulse, Color(0.90, 0.82, 0.66))
	draw_arc(Vector2.ZERO, r * 0.84, 0.0, TAU, 24, Color(0.55, 0.42, 0.28), 3.0)
	# Faction studs ringing the rim — the house accent.
	var accent := accent_color()
	var studs := 8
	for i in range(studs):
		var a := float(i) / float(studs) * TAU
		draw_circle(Vector2(cos(a), sin(a)) * r * 0.9, 2.2, accent)
	# A small painted glyph dot at the centre of the head in the accent colour.
	draw_circle(Vector2.ZERO, r * 0.18, accent.darkened(0.1))
