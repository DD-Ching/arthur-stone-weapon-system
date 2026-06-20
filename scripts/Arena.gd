extends Node2D
## The test arena.
##
## Draws the floor + boundary (the walls' collision lives on the Walls node),
## wires the HUD to Arthur, and handles the reset hotkey. Keeping this script
## tiny is intentional — the arena is a stage, not a system.

const HALF := Vector2(800.0, 500.0)  ## half-extent of the play field

@onready var arthur = $Arthur
@onready var hud = $Hud

func _ready() -> void:
	hud.bind(arthur)
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("reset_arena"):
		get_tree().reload_current_scene()

func _draw() -> void:
	var rect := Rect2(-HALF, HALF * 2.0)
	draw_rect(rect, Color(0.16, 0.15, 0.18))            # floor
	# faint reference grid so movement + knockback distance are readable
	for x in range(-700, 800, 100):
		draw_line(Vector2(x, -HALF.y), Vector2(x, HALF.y), Color(1, 1, 1, 0.04), 1.0)
	for y in range(-400, 500, 100):
		draw_line(Vector2(-HALF.x, y), Vector2(HALF.x, y), Color(1, 1, 1, 0.04), 1.0)
	draw_rect(rect, Color(0.45, 0.40, 0.50), false, 6.0)  # boundary line
