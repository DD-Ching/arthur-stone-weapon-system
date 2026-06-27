extends Node2D
## Bowling Room — a tight one-room teaching challenge for CHAIN impacts.
##
## A tight crowd of LightSoldiers stands packed at the far end of a walled room. The lesson is
## a strike: launch ONE thing (the heavy striker on the near edge, or the placed Rock) into the
## pack so the first impact BOWLS into the next, and the next — Arthur's force carrying through a
## crowd. Clear the crowd with chained knockdowns to win.
##
## This is a LEVEL: it only PLACES reusable modules and runs the room's thin win rule. The
## force/scoring is `Impact` (it owns enemy-to-enemy bowling), every pin is a config of
## `Enemy` (LightSoldier.tscn), the crowd is laid with `Spawner.spawn_count`, and the
## win/lose is an `ObjectiveManager` running one small `Objective`. Nothing here duplicates
## a shared system — change the exports and you get a different bowling lane.

const HALF := Vector2(560.0, 320.0)        ## half-extent of the room (1120 × 640, inside 1280×720)
const WALL := 40.0                         ## wall thickness
const GRID_STEP := 80

const LIGHT := preload("res://scenes/LightSoldier.tscn")

## How many pins stand in the packed crowd, and how tightly. Tight packing = one hit reaches
## the next. Tune these instead of hand-placing soldiers.
@export var pin_count := 8
@export var pin_lane_x := 150.0            ## the crowd's near (leading) edge sits at this x
@export var pin_cols := 2                  ## the crowd is this many columns wide ACROSS the lane (y)
@export var pin_pitch := 34.0              ## gap between neighbouring pins (both axes) — > one body, so no overlap
@export var pin_scatter := 5.0             ## tiny jitter so it reads as a crowd, not a rigid grid
## Pins glide on the smooth flagstones: a low damp means a shoved pin KEEPS moving and bowls the
## next one (its retained speed is what fires the enemy-to-enemy chain in Impact), instead of the
## high default damp arresting it on the spot. This is the heart of why the strike chains.
@export var pin_damp := 0.6
@export var striker_gap := 90.0            ## the striker waits this far in FRONT of the crowd's leading edge
@export var clear_threshold := 110.0       ## a pin moved this far from its spawn counts as bowled
## The striker is a HEAVY body (a big bruiser shoved into the crowd): heavier than a single pin
## so Arthur's force carries it THROUGH the crowd instead of stopping on the first man — that
## retained speed is what keeps each bowling impact above Impact.BOWL_MIN_SPEED so the chain
## propagates. Tuned with the lighter damp so it doesn't arrest mid-crowd.
@export var striker_mass := 3.0
@export var striker_damp := 1.6
## A lenient time budget to land the strike. Let it run out without clearing the crowd and the
## room ends in a DEFEAT (ScoreScreen → Retry) instead of dead-ending forever.
@export var time_limit := 60.0

@onready var arthur = $Arthur
@onready var walls: StaticBody2D = $Walls

var _pins: Array = []                       ## the cluster bodies (Enemy)
var _spawn_pos := {}                        ## instance_id -> spawn position (for displacement)
var _ball = null                            ## the launchable striker (an extra LightSoldier)
var _objectives: ObjectiveManager = null
var _status: Label = null
var _scan_cd := 0.0
var _struck := false
var _resolved := false
var _time_left := 0.0
var _elapsed := 0.0

func _ready() -> void:
	Impact.reset()
	_build_walls()
	_spawn_cluster()
	_spawn_ball()
	# One thin win rule: the crowd is cleared once enough pins are bowled (displaced/defeated).
	_objectives = ObjectiveManager.new()
	_objectives.add(ClearClusterObjective.new())
	_build_status()
	# Esc / mobile MENU → Resume / Restart / Return to Lobby, so the room is no longer a dead-end.
	RoomFinish.add_pause_menu(self)
	_time_left = time_limit
	Impact.popup("STRIKE THE CLUSTER", arthur.global_position + Vector2(0, -90),
		Color(0.6, 0.9, 1.0), 1.3)
	_evaluate()
	queue_redraw()

# ── room build ────────────────────────────────────────────────────────────────

## Four bounding walls (StaticBody2D, layer 1 "world") so a bowled pin can't leave the lane
## and so the back wall can wall-crush a pin pinned against it.
func _build_walls() -> void:
	var w := HALF.x
	var h := HALF.y
	_wall_rect(Vector2(0.0, -h - WALL * 0.5), Vector2(w * 2.0 + WALL * 2.0, WALL))  # top
	_wall_rect(Vector2(0.0, h + WALL * 0.5), Vector2(w * 2.0 + WALL * 2.0, WALL))   # bottom
	_wall_rect(Vector2(-w - WALL * 0.5, 0.0), Vector2(WALL, h * 2.0))               # left
	_wall_rect(Vector2(w + WALL * 0.5, 0.0), Vector2(WALL, h * 2.0))                # right

func _wall_rect(center: Vector2, size: Vector2) -> void:
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	cs.shape = shape
	cs.position = center
	walls.add_child(cs)

## The packed crowd of pins — a tight grid of passive LightSoldiers, pin_cols wide ACROSS the lane
## (y) and as many ranks DEEP along it (x) as pin_count needs. AI is OFF so they stand as pins and
## go limp when bowled (the physics carries them). Pins are pin_pitch apart on both axes — just
## over a body width, so they pack shoulder-to-shoulder without overlapping at spawn.
##
## Each column down the lane is laid with the reusable Spawner (it spreads a column's pins along
## x, the strike direction); the columns are stepped across the lane in y. The heavy striker plows
## into the front of the crowd and its momentum carries it THROUGH: front pins are bowled back into
## the ranks behind, and the pile scatters sideways into the flanking columns — one launch clears
## the crowd. That cascade IS the lesson.
func _spawn_cluster() -> void:
	_pins = []
	var cols: int = clampi(pin_cols, 1, maxi(pin_count, 1))
	for c in cols:
		# Spread the remainder across the first columns so the total count is exact.
		var n: int = pin_count / cols + (1 if c < pin_count % cols else 0)
		if n <= 0:
			continue
		var col_y: float = (float(c) - float(cols - 1) * 0.5) * pin_pitch   # column centred on y = 0
		var x_max: float = pin_lane_x + float(maxi(n - 1, 0)) * pin_pitch
		var col: Array = Spawner.spawn_count(self, LIGHT, n, col_y, pin_lane_x, x_max, false, false)
		for p in col:
			# A little jitter so it reads as a crowd; record the spawn for displacement scoring.
			p.global_position += Vector2(randf_range(-pin_scatter, pin_scatter),
				randf_range(-pin_scatter, pin_scatter))
			p.linear_damp = pin_damp   # glide, so a shoved pin bowls the next (keeps the chain alive)
			_spawn_pos[p.get_instance_id()] = p.global_position
			_pins.append(p)

## The striker: one extra, HEAVY LightSoldier just in FRONT of the crowd's leading edge, lined up
## on the lane. Arthur launches it (a swing) into the pack; the test launches it directly. It is
## passive so it stays limp — Arthur's force, not its own AI, carries it through the crowd.
func _spawn_ball() -> void:
	var ball = LIGHT.instantiate()
	add_child(ball)
	ball.ai_enabled = false
	ball.mass = striker_mass        # heavy enough to plow through and keep the chain alive
	ball.linear_damp = striker_damp
	ball.base_color = Color(0.95, 0.78, 0.35)   # marked apart from the white pins
	ball.global_position = Vector2(striker_x(), 0.0)
	_ball = ball

## Where the striker waits: striker_gap in front of the line's leading (near) edge, on the lane.
func striker_x() -> float:
	return pin_lane_x - striker_gap

# ── status label (our own — Hud.gd is off-limits) ──────────────────────────────

func _build_status() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_status = Label.new()
	_status.position = Vector2(24.0, 20.0)
	_status.add_theme_font_size_override("font_size", 22)
	_status.add_theme_color_override("font_color", Color(0.85, 0.92, 1.0))
	_status.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_status.add_theme_constant_override("outline_size", 6)
	layer.add_child(_status)

# ── per-frame ───────────────────────────────────────────────────────────────

func _physics_process(delta: float) -> void:
	if not _resolved:
		_elapsed += delta
		_time_left = maxf(0.0, _time_left - delta)
	_scan_cd -= delta
	if _scan_cd <= 0.0:
		_scan_cd = 0.15
		_evaluate()
		# Lenient lose: the strike never cleared the crowd in time. End in a DEFEAT screen
		# (Retry / Lobby) rather than leaving the player stuck in a half-bowled lane.
		if not _resolved and _time_left <= 0.0:
			_lose()

## Count the pins still standing (alive AND within clear_threshold of their spawn). A pin that
## was defeated or shoved out of the crowd no longer counts — that's a "bowled" pin.
func cluster_remaining() -> int:
	var n := 0
	for p in _pins:
		if not is_instance_valid(p):
			continue
		if p._dead:
			continue
		var origin: Vector2 = _spawn_pos.get(p.get_instance_id(), p.global_position)
		if p.global_position.distance_to(origin) < clear_threshold:
			n += 1
	return n

func cluster_total() -> int:
	return _pins.size()

## True once the striker has actually been launched (so the win can't fire before the strike).
func has_struck() -> bool:
	if _struck:
		return true
	if is_instance_valid(_ball) and _ball.linear_velocity.length() > Impact.BOWL_MIN_SPEED:
		_struck = true
	return _struck

func _evaluate() -> void:
	if _resolved:
		return
	var remaining := cluster_remaining()
	var ctx := {
		"cluster_remaining": remaining,
		"cluster_total": cluster_total(),
		"struck": has_struck(),
	}
	_objectives.evaluate(ctx)
	if _status != null:
		_status.text = "BOWLING ROOM   ·   STANDING %d / %d   ·   %s" % [
			remaining, cluster_total(), _objectives.hud_line(ctx)]
	if _objectives.won:
		_win()

func _win() -> void:
	_resolved = true
	if _status != null:
		_status.text = "BOWLING ROOM   ·   STRIKE!  CLUSTER CLEARED"
	Impact.popup("STRIKE! CLUSTER CLEARED", arthur.global_position + Vector2(0, -90),
		Color(0.6, 0.95, 1.0), 1.6)
	Audio.play("chain_impact", arthur.global_position)
	# Mark the stage cleared + reveal the result overlay (Next / Lobby) via the shared glue.
	RoomFinish.finish(self, true, Impact.kills, _elapsed)

func _lose() -> void:
	if _resolved:
		return
	_resolved = true
	if _status != null:
		_status.text = "BOWLING ROOM   ·   OUT OF TIME"
	Impact.popup("OUT OF TIME", arthur.global_position + Vector2(0, -90),
		Color(0.95, 0.45, 0.4), 1.4)
	RoomFinish.finish(self, false, Impact.kills, _elapsed)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("reset_arena"):
		get_tree().reload_current_scene()

# ── drawing ───────────────────────────────────────────────────────────────────

func _draw() -> void:
	var rect := Rect2(-HALF, HALF * 2.0)
	draw_rect(rect, Color(0.15, 0.16, 0.19))
	for x in range(-int(HALF.x), int(HALF.x) + 1, GRID_STEP):
		draw_line(Vector2(x, -HALF.y), Vector2(x, HALF.y), Color(1, 1, 1, 0.04), 1.0)
	for y in range(-int(HALF.y), int(HALF.y) + 1, GRID_STEP):
		draw_line(Vector2(-HALF.x, y), Vector2(HALF.x, y), Color(1, 1, 1, 0.04), 1.0)
	# the lane: from the striker spot through the crowd, a hint at the line of the strike
	var ranks: int = int(ceil(float(pin_count) / float(maxi(pin_cols, 1))))
	var lane_end: float = pin_lane_x + float(maxi(ranks - 1, 0)) * pin_pitch
	draw_line(Vector2(striker_x(), 0.0), Vector2(lane_end, 0.0), Color(0.4, 0.7, 0.95, 0.18), 3.0)
	draw_rect(rect, Color(0.45, 0.40, 0.50), false, 6.0)


## The room's one win rule, kept in the level file so the lesson stays self-contained: the
## crowd is "cleared" once the strike has landed AND enough pins are bowled out of it. It is a
## subclass of the reusable Objective (not a reimplementation) so the ObjectiveManager runs it
## exactly like any other. It will NOT complete before the strike (struck gate), so the win
## can't fire on the opening frame.
class ClearClusterObjective extends Objective:
	## Cleared once at most this many pins remain standing in the crowd.
	var clear_to := 2

	func _init() -> void:
		title = "Clear the cluster"
		required = true

	func evaluate(ctx: Dictionary) -> void:
		if not bool(ctx.get("struck", false)):
			return   # the strike hasn't landed yet — never "done" on the opening frame
		var remaining := int(ctx.get("cluster_remaining", 999))
		var total := int(ctx.get("cluster_total", 0))
		# Need a real cluster AND enough of it bowled away (guard the trivial empty case).
		if total > 0 and remaining <= clear_to:
			_done = true

	func fragment(ctx: Dictionary) -> String:
		if not bool(ctx.get("struck", false)):
			return "STRIKE TO START"
		var remaining := int(ctx.get("cluster_remaining", 0))
		if remaining <= clear_to:
			return "CLEARED!"
		return "BOWL THEM DOWN"
