class_name RoomFinish
extends RefCounted
## RoomFinish — the win/lose + campaign hand-off glue for the challenge rooms, in ONE place.
##
## A challenge room (BowlingRoom, WallCrushRoom, …) builds its own thin win/lose rule but ends
## the SAME way every BattleMap does: mark the stage cleared in the Campaign on a win, then reveal
## a ScoreScreen wired with the next battle + its story blurb (Next / Retry / Return to Lobby). This
## helper holds that glue so it isn't pasted into all four rooms — it mirrors `BattleMap._show_score`
## (scripts/maps/BattleMap.gd ~232-246) exactly, composing the reusable ScoreScreen + Campaign +
## PauseMenu rather than inventing a new win/lose engine.
##
## Build once, reuse many: rooms call `RoomFinish.finish(...)` on a decided outcome and
## `RoomFinish.add_pause_menu(room)` in `_ready`. No room owns its own copy of this logic.

const SCORE_SCREEN := preload("res://scenes/ui/ScoreScreen.tscn")
const PAUSE_MENU := preload("res://scenes/ui/PauseMenu.tscn")

## Resolve a room: on a WIN record it in the Campaign (so the lobby unlocks the next stage + marks
## this one cleared), then reveal a ScoreScreen handed the campaign context — the next battle to
## advance to (win only) and the story blurb for it (or for this stage on a loss/end). Also locks
## any PauseMenu so the result screen owns the choices now. Returns the ScoreScreen instance (so a
## caller/test can inspect it). `room` is the level Node; `won` the outcome; `kos`/`seconds` the
## tally shown on the panel.
static func finish(room: Node, won: bool, kos: int, seconds: float) -> Node:
	if room == null or not is_instance_valid(room):
		return null
	var path := String(room.scene_file_path)
	var next_path := ""
	var blurb := ""
	# Campaign is an autoload — guard the access (it may be absent in a bare test harness).
	var c = room.get_node_or_null("/root/Campaign")
	if c:
		if won:
			c.mark_completed(path)
		# On a win, advance to the next battle; on a loss the player retries THIS one.
		next_path = c.next_path(path) if won else ""
		blurb = c.blurb_for(next_path) if (won and next_path != "") else c.blurb_for(path)
	# Lock THIS room's pause overlay — the ScoreScreen's Next/Retry/Lobby takes over.
	var pause = _find_pause_menu(room)
	if pause and pause.has_method("lock"):
		pause.lock()
	var screen = SCORE_SCREEN.instantiate()
	room.add_child(screen)
	screen.show_result(won, kos, seconds, next_path, blurb)
	return screen

## Add the reusable PauseMenu overlay to a room (Esc / mobile MENU → Resume / Restart / Return to
## Lobby). Mirrors what BattleMap does in _ready so rooms are no longer dead-ends. Returns the
## instance. PauseMenu self-registers (group "pause_menu") and owns its own toggle — no wiring.
static func add_pause_menu(room: Node) -> Node:
	if room == null or not is_instance_valid(room):
		return null
	var pause = PAUSE_MENU.instantiate()
	room.add_child(pause)
	return pause

## Find THIS room's own PauseMenu — a direct child in the "pause_menu" group (the one
## add_pause_menu parented here). Scoped to the room (not the global group) so that with more
## than one room alive — e.g. a test instancing two — finish() locks the right overlay, never a
## sibling room's.
static func _find_pause_menu(room: Node) -> Node:
	for child in room.get_children():
		if is_instance_valid(child) and child.is_in_group("pause_menu"):
			return child
	return null
