extends Node2D
## Headless test for the room → campaign hand-off glue (token ROOMCAMPAIGN).
##
## The challenge rooms used to dead-end on a win (no result screen, no progression). This asserts
## the new RoomFinish glue closes that loop, using the REAL BowlingRoom level + the REAL Campaign
## autoload + the REAL ScoreScreen — no mocks:
##   1. WIN — boot a BowlingRoom, drive its strike to clear the cluster, and assert:
##        - the Campaign now reports this stage CLEARED (is_cleared(scene_file_path)), and
##        - a ScoreScreen appeared, is visible, shows VICTORY, and was handed a NON-EMPTY
##          next_path (the next trial to advance to).
##   2. LOSE — a room can register a loss: RoomFinish.finish(room, false, …) reveals a ScoreScreen
##        that shows DEFEAT (and is NOT a win → no false campaign clear).
##
## Run: godot --headless --path . res://tests/RoomCampaignTest.tscn --quit-after 600
##      — look for ROOMCAMPAIGN_VERDICT.

const ROOM := preload("res://scenes/rooms/BowlingRoom.tscn")
const STRIKE_SPEED := 720.0     ## a hard launch — well above Impact.BOWL_MIN_SPEED
const REPORT_FRAME := 160       ## let the bowled pins fly + settle + the scan fire the win

var _room
var _frame := 0
var _struck := false
var _reported := false

# WIN-case captures
var _won := false
var _cleared := false
var _score_visible := false
var _score_victory := false
var _next_path := ""

# LOSE-case captures
var _lose_score_shown := false
var _lose_is_defeat := false
var _lose_not_cleared := true

func _ready() -> void:
	# Start from a clean campaign so is_cleared() is a real signal of THIS run's win.
	var c = get_node_or_null("/root/Campaign")
	if c:
		c.reset()
	_room = ROOM.instantiate()
	add_child(_room)

func _physics_process(_delta: float) -> void:
	_frame += 1
	# Frame 2: the room's _ready has run. Launch the striker straight into the crowd.
	if _frame == 2:
		var ball = _room._ball
		if is_instance_valid(ball):
			var to: Vector2 = Vector2(_room.pin_lane_x, ball.global_position.y) - ball.global_position
			ball.apply_central_impulse(to.normalized() * STRIKE_SPEED * ball.mass)
			_struck = true
	elif _frame >= REPORT_FRAME:
		_report()

## Find the ScoreScreen the room revealed (the CanvasLayer carrying show_result / _next_path).
func _find_score(room: Node):
	for child in room.get_children():
		if child is CanvasLayer and "_next_path" in child and child.has_method("show_result"):
			return child
	return null

func _report() -> void:
	if _reported:
		return
	_reported = true

	var c = get_node_or_null("/root/Campaign")
	var path := String(_room.scene_file_path)

	# ── WIN case (the real room, driven to a strike-cleared cluster) ──────────────
	_won = _room._resolved and _room._objectives.won
	_cleared = c != null and c.is_cleared(path)
	var score = _find_score(_room)
	if score != null:
		_score_visible = score.visible
		_next_path = String(score._next_path)
		var t := _all_text(score).to_upper()
		_score_victory = t.find("VICTORY") != -1
	var win_ok: bool = _struck and _won and _cleared and _score_visible \
		and _score_victory and _next_path != ""

	# ── LOSE case (a fresh room registers a loss via the same glue) ───────────────
	# Use a DIFFERENT stage that the win case never touched, so its cleared-state is a clean
	# probe: a loss must NEVER mark a stage cleared.
	const LOSE_PROBE := "res://scenes/rooms/WallCrushRoom.tscn"
	var lose_room = ROOM.instantiate()
	lose_room.scene_file_path = LOSE_PROBE   # govern the helper's campaign lookups by this path
	add_child(lose_room)
	# Drive the loss directly through the shared helper (the lose path every room uses).
	var lose_screen = RoomFinish.finish(lose_room, false, 0, 5.0)
	if lose_screen != null:
		_lose_score_shown = lose_screen.visible
		_lose_is_defeat = _all_text(lose_screen).to_upper().find("DEFEAT") != -1
	# A loss must NOT clear the stage.
	_lose_not_cleared = (c == null) or (not c.is_cleared(LOSE_PROBE))
	var lose_ok: bool = _lose_score_shown and _lose_is_defeat and _lose_not_cleared

	print("ROOMCAMPAIGN_RESULT struck=%s won=%s cleared=%s score_vis=%s victory=%s next='%s' | lose_shown=%s defeat=%s no_spurious_clear=%s"
		% [str(_struck), str(_won), str(_cleared), str(_score_visible), str(_score_victory),
			_next_path, str(_lose_score_shown), str(_lose_is_defeat), str(_lose_not_cleared)])
	var ok: bool = win_ok and lose_ok
	print("ROOMCAMPAIGN_VERDICT %s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)

## Concatenate the text of every Label in a subtree (to read the VICTORY/DEFEAT banner).
func _all_text(node: Node) -> String:
	var s := ""
	if node is Label:
		s += node.text + "\n"
	for ch in node.get_children():
		s += _all_text(ch)
	return s
