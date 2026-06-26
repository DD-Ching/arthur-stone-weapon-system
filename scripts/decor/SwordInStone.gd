class_name SwordInStone
extends Node2D
## The Sword in the Stone — the game's emblem. A grey stone anvil-block with a cross-hilt
## sword half-sunk into it, catching a faint gleam. Arthur could not pull the sword, so he
## lifted the whole STONE; this prop is the legend a map drops at a shrine, a courtyard, or
## the title field. Pure code-drawn decor: no physics, no image assets, allocation-light.
##
## The only per-frame work is a slow gleam that travels the blade (a single sin), so the
## steel glints rather than sitting flat. Everything else is static geometry in _draw.

## Overall scale of the prop in pixels (the stone block's half-width).
@export var stone_size := 26.0
## How brightly the blade gleams (purely cosmetic; multiplies the highlight alpha).
@export var gleam := 1.0

var _t := 0.0

## The stone's grey, exposed so a map could tint it (mossy, sunlit) without touching _draw.
func stone_color() -> Color:
	return Color(0.46, 0.45, 0.48)

func _ready() -> void:
	add_to_group("decor")
	_t = randf() * 6.28   # de-sync the gleam if several emblems share a scene

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _draw() -> void:
	var s := stone_size
	# The stone anvil-block: a chunky trapezoid, darker base, lighter chiselled top edge.
	var base := Color(0.34, 0.33, 0.36)
	var top := stone_color()
	var block := PackedVector2Array([
		Vector2(-s, s * 0.9),
		Vector2(s, s * 0.9),
		Vector2(s * 0.82, -s * 0.3),
		Vector2(-s * 0.82, -s * 0.3),
	])
	draw_colored_polygon(block, base)
	# A lighter cap across the top so the block reads as a sunlit anvil, not a flat slab.
	var cap := PackedVector2Array([
		Vector2(-s * 0.82, -s * 0.3),
		Vector2(s * 0.82, -s * 0.3),
		Vector2(s * 0.7, -s * 0.5),
		Vector2(-s * 0.7, -s * 0.5),
	])
	draw_colored_polygon(cap, top)
	# A couple of mortar courses so the stone reads as carved rock.
	draw_line(Vector2(-s, s * 0.35), Vector2(s, s * 0.35), base.darkened(0.3), 2.0)
	draw_line(Vector2(-s, s * 0.62), Vector2(s, s * 0.62), base.darkened(0.3), 2.0)

	# The sword, half-sunk into the stone: a blade rising from the cap, a cross-guard, a grip
	# and a round pommel. The lower third of the blade is "buried", drawn behind the cap above.
	var blade_top := Vector2(0.0, -s * 2.2)
	var blade_base := Vector2(0.0, -s * 0.42)
	var steel := Color(0.78, 0.80, 0.86)
	# Blade — a tapering quadrilateral so it reads as a sword, not a line.
	var bw := s * 0.16
	var blade := PackedVector2Array([
		Vector2(-bw, blade_base.y),
		Vector2(bw, blade_base.y),
		Vector2(bw * 0.25, blade_top.y + s * 0.18),
		Vector2(0.0, blade_top.y),                    # the point
		Vector2(-bw * 0.25, blade_top.y + s * 0.18),
	])
	draw_colored_polygon(blade, steel)
	# A central fuller line down the blade for depth.
	draw_line(Vector2(0.0, blade_base.y), blade_top, steel.darkened(0.35), 1.5)

	# The cross-guard — a stout horizontal bar where blade meets grip.
	var guard_y := blade_base.y
	var guard := Color(0.62, 0.50, 0.24)   # tarnished gold
	draw_line(Vector2(-s * 0.42, guard_y), Vector2(s * 0.42, guard_y), guard, 5.0)
	draw_circle(Vector2(-s * 0.42, guard_y), 2.5, guard)
	draw_circle(Vector2(s * 0.42, guard_y), 2.5, guard)
	# The grip rising to a round pommel above the guard.
	var grip_top := Vector2(0.0, guard_y - s * 0.34)
	draw_line(Vector2(0.0, guard_y), grip_top, Color(0.30, 0.22, 0.16), 4.0)
	draw_circle(grip_top, s * 0.12, guard)

	# The gleam: a bright highlight travelling up the blade so the steel glints.
	var g := clampf(gleam, 0.0, 2.0)
	var f := 0.5 + 0.5 * sin(_t * 1.6)
	var glint_y: float = lerpf(blade_base.y, blade_top.y, f)
	var glint := Vector2(-bw * 0.3, glint_y)
	draw_circle(glint, s * 0.09, Color(1.0, 1.0, 1.0, 0.55 * g))
