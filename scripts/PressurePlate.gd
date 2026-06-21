extends Node2D
## A simple physics puzzle: push (or launch) a rock, crate, or enemy onto the
## plate and it stays down, opening the gate wall beside it. It is the smallest
## "weapon as a tool, not just a sword" interaction — exactly the kind of thing
## the puzzle rooms on the roadmap are built from.
##
## Self-contained: the plate (an Area2D) and the gate (a StaticBody2D wall) are
## children; this node watches the plate and drops the gate's collision when it
## is weighted. Drawn in code so it needs no art.

@onready var _plate: Area2D = $Plate
@onready var _gate: StaticBody2D = $Gate
@onready var _gate_shape: CollisionShape2D = $Gate/CollisionShape2D

var _open := false
var _open_amt := 0.0   ## 0 = gate solid, 1 = gate gone (drives fade + collision)

func _ready() -> void:
	queue_redraw()

func _physics_process(delta: float) -> void:
	# Latch: once something heavy weights the plate, the gate stays open.
	if not _open and not _plate.get_overlapping_bodies().is_empty():
		_open = true
		Impact.popup("GATE OPEN!", _gate.global_position, Color(0.5, 0.95, 0.55), 1.1)
		Impact.add_flow(8.0)
	_open_amt = move_toward(_open_amt, 1.0 if _open else 0.0, delta * 2.4)
	_gate_shape.set_deferred("disabled", _open_amt > 0.5)
	queue_redraw()

func _draw() -> void:
	# Plate: a recessed pad that lights up when pressed.
	var lit := _open_amt
	var pad := Color(0.3, 0.32, 0.36).lerp(Color(0.4, 0.9, 0.5), lit)
	draw_rect(Rect2(-32, -32, 64, 64), pad)
	draw_rect(Rect2(-32, -32, 64, 64), Color(0.15, 0.16, 0.2), false, 4.0)
	draw_rect(Rect2(-20, -20, 40, 40), pad.darkened(0.2 * (1.0 - lit)))

	# Gate: a wall bar that fades and sinks as it opens.
	var gp: Vector2 = _gate.position
	var a := 1.0 - _open_amt
	var half := Vector2(20.0, 96.0)
	draw_rect(Rect2(gp - half, half * 2.0), Color(0.5, 0.45, 0.55, a))
	draw_rect(Rect2(gp - half, half * 2.0), Color(0.7, 0.65, 0.78, a), false, 4.0)
