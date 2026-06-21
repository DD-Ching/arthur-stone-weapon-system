extends Node2D
## The test arena — a stage built around the impact loop.
##
## It draws the floor + boundary, builds a few interior walls (a pillar to pin
## enemies against and a corner pocket / corridor for wall-crush practice),
## resets Stone Flow on (re)load, wires the HUD, and handles the reset hotkey.
##
## Interior walls are data-driven: each Rect2 in WALLS becomes BOTH a collision
## body (layer 1, "world") and a drawn rectangle, so the thing you crush enemies
## against is exactly the thing you see — no chance of the two drifting apart.

const HALF := Vector2(800.0, 500.0)  ## half-extent of the play field
const GRID_STEP := 100               ## reference-grid spacing (px)

## Interior obstacles, as world-space Rect2s (top-left + size). Laid out to leave
## the centre open for big swings while giving the edges things to pin against.
const WALLS := [
	Rect2(-380, -30, 56, 200),    # centre-left pillar — pin / crush target
	Rect2(280, -210, 300, 40),    # corridor lip (top of the right pocket)
	Rect2(536, -210, 44, 260),    # corridor wall (right side of the pocket)
	Rect2(-600, 250, 220, 40),    # bottom-left corner pocket
]

@onready var arthur = $Arthur
@onready var hud = $Hud
@onready var walls: StaticBody2D = $Walls

func _ready() -> void:
	Impact.reset()
	_build_interior_walls()
	hud.bind(arthur)
	queue_redraw()

func _build_interior_walls() -> void:
	for r in WALLS:
		var cs := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = r.size
		cs.shape = shape
		cs.position = r.position + r.size * 0.5   # Rect2 is top-left; shape is centred
		walls.add_child(cs)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("reset_arena"):
		get_tree().reload_current_scene()

func _draw() -> void:
	var rect := Rect2(-HALF, HALF * 2.0)
	draw_rect(rect, Color(0.16, 0.15, 0.18))            # floor
	# faint reference grid so movement + knockback distance are readable
	# (derived from HALF so it always lines up with the boundary)
	for x in range(-int(HALF.x), int(HALF.x) + 1, GRID_STEP):
		draw_line(Vector2(x, -HALF.y), Vector2(x, HALF.y), Color(1, 1, 1, 0.04), 1.0)
	for y in range(-int(HALF.y), int(HALF.y) + 1, GRID_STEP):
		draw_line(Vector2(-HALF.x, y), Vector2(HALF.x, y), Color(1, 1, 1, 0.04), 1.0)
	draw_rect(rect, Color(0.45, 0.40, 0.50), false, 6.0)  # boundary line
	# interior walls (same Rect2s that became collision)
	for r in WALLS:
		draw_rect(r, Color(0.30, 0.28, 0.34))
		draw_rect(r, Color(0.5, 0.46, 0.56), false, 3.0)
