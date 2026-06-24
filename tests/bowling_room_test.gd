extends Node2D
## Headless test for the Bowling Room challenge (token BOWL_ROOM).
##
## Instantiates the real BowlingRoom level, then simulates a STRIKE: the room's heavy striker
## is given a high velocity toward the packed crowd of pins. Over ~140 physics frames the first
## impact must BOWL into the crowd and chain (Impact owns enemy-to-enemy collisions), so MULTIPLE
## pins are knocked out of the crowd or defeated. We assert:
##   - BEFORE the strike the room's win-detection has NOT fired (no false win on frame 0),
##   - the strike displaces/defeats >= 3 pins (a real chain, not a single bonk),
##   - the room's ClearClusterObjective then fires the win.
##
## Run: godot --headless --path . res://tests/BowlingRoomTest.tscn --quit-after 600
##      — look for BOWL_ROOM_VERDICT.

const ROOM := preload("res://scenes/rooms/BowlingRoom.tscn")
const STRIKE_SPEED := 720.0     ## a hard launch — well above Impact.BOWL_MIN_SPEED (230)
const DISPLACE_MIN := 3         ## a real chain must move/defeat at least this many pins
const REPORT_FRAME := 140       ## let the bowled pins fly + settle before scoring

var _room
var _frame := 0
var _won_before_strike := true  ## must STAY false-ish: win must not fire before the strike
var _struck := false
var _displaced := 0
var _reported := false

func _ready() -> void:
	_room = ROOM.instantiate()
	add_child(_room)

func _physics_process(_delta: float) -> void:
	_frame += 1
	# Frame 2: the room's _ready has run (crowd + striker spawned). Confirm the win has NOT
	# fired yet, then launch the striker straight at the crowd.
	if _frame == 2:
		_won_before_strike = _room._objectives.won
		var ball = _room._ball
		if is_instance_valid(ball):
			# Launch the striker straight down the lane into the crowd (impulse = speed × mass).
			var to: Vector2 = Vector2(_room.pin_lane_x, ball.global_position.y) - ball.global_position
			ball.apply_central_impulse(to.normalized() * STRIKE_SPEED * ball.mass)
			_struck = true
	elif _frame >= REPORT_FRAME:
		_report()

func _report() -> void:
	if _reported:
		return
	_reported = true
	# How many pins ended up bowled out of the crowd (displaced past the room's threshold, or defeated)?
	_displaced = _room.cluster_total() - _room.cluster_remaining()
	var chained: bool = _displaced >= DISPLACE_MIN
	# The win must NOT have fired before the strike, and MUST have fired after the chain.
	var no_early_win: bool = not _won_before_strike
	var won_after: bool = _room._objectives.won
	var ok: bool = _struck and chained and no_early_win and won_after

	print("BOWL_ROOM_RESULT struck=%s total=%d remaining=%d displaced=%d (>=%d) early_win=%s won=%s"
		% [str(_struck), _room.cluster_total(), _room.cluster_remaining(), _displaced,
			DISPLACE_MIN, str(_won_before_strike), str(won_after)])
	print("BOWL_ROOM_VERDICT %s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)
