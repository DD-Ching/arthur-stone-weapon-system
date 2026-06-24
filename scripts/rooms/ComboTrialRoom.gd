extends Node2D
## Combo Trial Room — a self-contained challenge LEVEL.
##
## A bare arena with Arthur and a never-ending trickle of raiders to hit. The rule is a
## race against a TIMER: build the Stone Flow combo up to a target STACK count before the
## clock runs out. Reach it in time and you WIN; let the timer expire below it and you LOSE.
##
## Like every level here it only assembles + rules over reusable modules: force/scoring +
## the Stone Flow combo are `Impact`, enemies are configs of `Enemy`, and refills go through
## the `Spawner`. What lives here is level-specific: the timer, the target, the win/lose, and
## a tiny HUD label of its own (it does NOT touch the shared Hud). Drop these modules in a new
## scene with a different target/timer to make a harder trial.

const HALF := Vector2(640.0, 360.0)   ## half-extent of the play field (1280×720)
const GRID_STEP := 100

const LIGHT := preload("res://scenes/LightSoldier.tscn")
const SHIELD := preload("res://scenes/ShieldSoldier.tscn")

## Target Stone Flow stack count to clear the trial, and how long you get to reach it.
@export var target_stacks := 4
@export var time_limit := 30.0
## Keep this many raiders alive so there is always something to hit; refilled when thinned.
@export var enemy_target_count := 6
@export var refill_interval := 1.5

signal won
signal lost

var _time_left := 0.0
var _finished := false
var _refill_cd := 0.0

@onready var _arthur: Node2D = $Arthur
@onready var _time_label: Label = $RoomHud/Root/TimeLabel
@onready var _stack_label: Label = $RoomHud/Root/StackLabel
@onready var _banner: Label = $RoomHud/Root/BannerLabel

func _ready() -> void:
	target_stacks = clampi(target_stacks, 1, Impact.MAX_STACKS)
	_time_left = time_limit
	# Connect BEFORE the reset so the room never misses a flow change, then prime off the
	# current meter state (the way the Hud binds). Priming also settles the start label and
	# would win immediately if the room were entered already at/above the target.
	Impact.flow_changed.connect(_on_flow_changed)
	Impact.reset()
	_refill_enemies()
	_on_flow_changed(Impact.flow, Impact.stacks, Impact.flow_mode)
	queue_redraw()

## The room leases one connection to the autoload combo meter; drop it when the room leaves
## the tree (a reset/reload re-instances the level) so a stale handler can't outlive its nodes.
func _exit_tree() -> void:
	if Impact.flow_changed.is_connected(_on_flow_changed):
		Impact.flow_changed.disconnect(_on_flow_changed)

func _physics_process(delta: float) -> void:
	if _finished:
		return
	_time_left = maxf(0.0, _time_left - delta)
	_refill_cd -= delta
	if _refill_cd <= 0.0:
		_refill_cd = refill_interval
		_refill_enemies()
	_update_labels()
	if _time_left <= 0.0:
		_lose()

## Stone Flow moved — the moment stacks reach the target (within time), the trial is won.
func _on_flow_changed(_flow: float, stacks: int, _flow_mode: bool) -> void:
	if _finished:
		return
	_update_labels()
	if stacks >= target_stacks:
		_win()

## Top the field back up to `enemy_target_count` LIVE raiders so the combo never starves.
## A defeated enemy lingers in the "targets" group while it fades out (Enemy keeps `_dead`
## bodies for ~0.6s), so count only the still-fightable ones — otherwise dying enemies mask
## an empty field and the refill never fires.
func _refill_enemies() -> void:
	if _finished:
		return
	var alive := 0
	for e in get_tree().get_nodes_in_group("targets"):
		if is_instance_valid(e) and not e._dead:
			alive += 1
	var need := enemy_target_count - alive
	if need <= 0:
		return
	var roster: Array = []
	for i in need:
		roster.append(SHIELD if i % 3 == 2 else LIGHT)
	Spawner.spawn(self, roster, -HALF.y + 70.0, -HALF.x + 120.0, HALF.x - 120.0, true)

func _win() -> void:
	if _finished:
		return
	_finished = true
	_banner.text = "TRIAL CLEARED"
	_banner.modulate = Color(0.5, 0.95, 0.55)
	_banner.visible = true
	Impact.popup("STONE FLOW MASTERED", _arthur.global_position + Vector2(0, -80),
		Color(1.0, 0.85, 0.3), 1.6)
	won.emit()

func _lose() -> void:
	if _finished:
		return
	_finished = true
	_banner.text = "OUT OF TIME"
	_banner.modulate = Color(0.95, 0.45, 0.4)
	_banner.visible = true
	lost.emit()

func _update_labels() -> void:
	_time_label.text = "TIME  %4.1f" % _time_left
	_stack_label.text = "STACKS  %d / %d" % [Impact.stacks, target_stacks]

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("reset_arena"):
		get_tree().reload_current_scene()

func _draw() -> void:
	var rect := Rect2(-HALF, HALF * 2.0)
	draw_rect(rect, Color(0.15, 0.14, 0.17))
	for x in range(-int(HALF.x), int(HALF.x) + 1, GRID_STEP):
		draw_line(Vector2(x, -HALF.y), Vector2(x, HALF.y), Color(1, 1, 1, 0.04), 1.0)
	for y in range(-int(HALF.y), int(HALF.y) + 1, GRID_STEP):
		draw_line(Vector2(-HALF.x, y), Vector2(HALF.x, y), Color(1, 1, 1, 0.04), 1.0)
	draw_rect(rect, Color(0.45, 0.40, 0.50), false, 6.0)
