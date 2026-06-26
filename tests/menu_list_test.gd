extends Node2D
## Headless test for the reusable MenuList overlay component (token MENULIST).
##
## Asserts: set_items seeds the buttons with focus on the first; focus_move wraps both ways;
## activate() emits chosen() with the focused item's id; focused_id() tracks the focus. This is
## the shared navigation the PauseMenu + ScoreScreen both lean on, so it's verified in isolation.
##
## Run: godot --headless --path . res://tests/MenuListTest.tscn --quit-after 600 — look for MENULIST_VERDICT.

var _list: MenuList
var _last_chosen := ""
var _frame := 0

func _ready() -> void:
	_list = MenuList.new()
	add_child(_list)
	_list.chosen.connect(func(id): _last_chosen = id)
	_list.set_items([
		{"id": "resume", "label": "Resume"},
		{"id": "restart", "label": "Restart"},
		{"id": "lobby", "label": "Lobby"},
	])

func _physics_process(_dt: float) -> void:
	_frame += 1
	if _frame < 2:
		return
	_report()

func _report() -> void:
	var start_focus: bool = _list.focused == 0 and _list.focused_id() == "resume"
	_list.focus_move(1)
	var moved: bool = _list.focused == 1 and _list.focused_id() == "restart"
	# Wrap backwards past the start: 1 -> 0 -> 2 (last).
	_list.focus_move(-1)
	_list.focus_move(-1)
	var wrapped: bool = _list.focused == 2 and _list.focused_id() == "lobby"
	# Activating the focused item emits chosen(id).
	_list.activate()
	var emitted: bool = _last_chosen == "lobby"

	var ok: bool = start_focus and moved and wrapped and emitted
	print("MENULIST_RESULT start=%s moved=%s wrapped=%s emitted=%s last=%s" % [
		str(start_focus), str(moved), str(wrapped), str(emitted), _last_chosen])
	print("MENULIST_VERDICT %s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)
