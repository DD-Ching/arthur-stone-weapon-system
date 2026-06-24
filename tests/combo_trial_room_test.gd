extends Node2D
## Headless test for the Combo Trial Room (challenge level #4).
##
## Two runs, one Impact (the shared autoload combo meter):
##   1. VICTORY — drive Stone Flow up via Impact's public `add_flow()` (the same path a
##      landed hit feeds) until stacks reach the room's target; assert the room fires `won`.
##   2. DEFEAT — a fresh room with flow left below target; force its timer to expire and
##      assert the room fires `lost` (and did NOT win).
##
## Run: godot --headless --path . res://tests/ComboTrialRoomTest.tscn --quit-after 600
## — look for COMBO_ROOM_VERDICT.

const ROOM := preload("res://scenes/rooms/ComboTrialRoom.tscn")

var _won_fired := false
var _lost_fired := false
var _frame := 0
var _phase := 0
var _room: Node2D = null
# results
var _win_ok := false
var _win_stacks := 0
var _lose_ok := false
var _lose_stacks := 0

func _ready() -> void:
	_start_win_room()

# ── phase 1: VICTORY ─────────────────────────────────────────────────────────
func _start_win_room() -> void:
	_room = ROOM.instantiate()
	_room.target_stacks = 4
	_room.won.connect(func(): _won_fired = true)
	_room.lost.connect(func(): _lost_fired = true)
	add_child(_room)   # _ready resets Impact + connects flow_changed

func _physics_process(_delta: float) -> void:
	_frame += 1
	# Let the room's _ready settle one frame before we drive flow.
	if _phase == 0:
		if _frame < 2:
			return
		_drive_win()
		_phase = 1
		_frame = 0
		return
	if _phase == 1:
		# Give the win a frame to propagate, capture, then swap to the lose room.
		_win_ok = _won_fired and not _lost_fired
		_win_stacks = Impact.stacks
		_room.queue_free()
		_won_fired = false
		_lost_fired = false
		_start_lose_room()
		_phase = 2
		_frame = 0
		return
	if _phase == 2:
		# Wait for the lose room's _ready (it resets Impact again), then below-target flow.
		if _frame < 2:
			return
		_drive_lose_setup()
		_phase = 3
		_frame = 0
		return
	if _phase == 3:
		# Force the timer to expire with stacks below target; the room loses on next tick.
		_room._time_left = 0.0001
		_phase = 4
		_frame = 0
		return
	if _phase == 4:
		if _frame < 3:
			return
		_lose_stacks = Impact.stacks
		_lose_ok = _lost_fired and not _won_fired and _lose_stacks < _room.target_stacks
		_report()

## Drive Stone Flow up to the target using the public flow API a hit would use.
func _drive_win() -> void:
	var target: int = _room.target_stacks
	# STACK_STEP flow per stack; add a hair over N×step to land cleanly on N stacks.
	Impact.add_flow(float(target) * Impact.STACK_STEP + 1.0)

func _drive_lose_setup() -> void:
	# Build SOME flow but stay below target (1 stack worth), so the loss is "below target",
	# not "empty meter".
	Impact.add_flow(Impact.STACK_STEP + 1.0)

func _report() -> void:
	print("COMBO_ROOM_RESULT win_ok=%s win_stacks=%d/%d  lose_ok=%s lose_stacks=%d/%d"
		% [str(_win_ok), _win_stacks, 4, str(_lose_ok), _lose_stacks, _room.target_stacks])
	var ok: bool = _win_ok and _lose_ok
	print("COMBO_ROOM_VERDICT %s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)

func _start_lose_room() -> void:
	_room = ROOM.instantiate()
	_room.target_stacks = 4
	_room.time_limit = 30.0
	_room.won.connect(func(): _won_fired = true)
	_room.lost.connect(func(): _lost_fired = true)
	add_child(_room)
