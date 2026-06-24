extends Node2D
## Headless test for the StageSelect menu (the Musou battle picker / boot scene).
##
## Instantiates StageSelect ALONE, steps a frame so it builds its list, and asserts:
##   - it resolved a NON-EMPTY entry list — at least the guaranteed-existing scenes
##     (Battlefield + the four challenge rooms), so >= 5 entries;
##   - every listed entry's `path` passes ResourceLoader.exists (no phantom rows);
##   - the new map scenes are guarded — any that don't exist on this branch are skipped;
##   - navigation via the public `_move(1)` advances the selected index and WRAPS around
##     the end back to 0, and `_move(-1)` from 0 wraps to the last entry;
##   - the currently-selected entry's path is a valid, loadable scene.
##
## It deliberately does NOT call change_scene_to_file (that would tear down the test) —
## it only confirms the chosen path is valid.
##
## Run: godot --headless --path . res://tests/StageSelectTest.tscn — look for STAGESELECT_VERDICT.

const STAGE_SELECT := preload("res://scenes/ui/StageSelect.tscn")

const GUARANTEED := [
	"res://scenes/Battlefield.tscn",
	"res://scenes/rooms/BowlingRoom.tscn",
	"res://scenes/rooms/WallCrushRoom.tscn",
	"res://scenes/rooms/RockLauncherRoom.tscn",
	"res://scenes/rooms/ComboTrialRoom.tscn",
]

var _menu
var _frame := 0

func _ready() -> void:
	_menu = STAGE_SELECT.instantiate()
	add_child(_menu)

func _physics_process(_delta: float) -> void:
	_frame += 1
	if _frame >= 2:
		_report()

func _report() -> void:
	var checks := {}
	var count: int = _menu.entries.size()

	# 1) Non-empty, and at least the five guaranteed scenes resolved.
	checks["nonempty"] = count >= 5

	# 2) Every listed entry actually exists (no phantom rows from missing maps).
	var all_exist := true
	for e in _menu.entries:
		if not ResourceLoader.exists(e["path"]):
			all_exist = false
	checks["all_exist"] = all_exist

	# 3) The guaranteed scenes are all present in the list.
	var paths: Array = []
	for e in _menu.entries:
		paths.append(e["path"])
	var guaranteed_listed := true
	for g in GUARANTEED:
		if not paths.has(g):
			guaranteed_listed = false
	checks["guaranteed_listed"] = guaranteed_listed

	# 4) Navigation: _move(1) advances the index.
	_menu.selected = 0
	_menu._move(1)
	checks["advance"] = _menu.selected == 1

	# 5) Navigation wraps at the end: from last → 0.
	_menu.selected = count - 1
	_menu._move(1)
	checks["wrap_forward"] = _menu.selected == 0

	# 6) Navigation wraps backward: from 0 → last.
	_menu.selected = 0
	_menu._move(-1)
	checks["wrap_back"] = _menu.selected == count - 1

	# 7) The currently-selected entry's path is a valid, loadable scene.
	_menu.selected = 0
	var sel_path: String = _menu.selected_path()
	checks["selected_valid"] = sel_path != "" and ResourceLoader.exists(sel_path)

	# 8) The real input path works: a synthetic move_down action event advances the
	#    selection through _input (the same wiring keyboard/gamepad uses in-game). We do
	#    NOT synthesise `attack` — that would launch and tear down the test.
	_menu.selected = 0
	var ev := InputEventAction.new()
	ev.action = "move_down"
	ev.pressed = true
	_menu._input(ev)
	checks["input_nav"] = _menu.selected == 1

	var ok := true
	var parts: Array = []
	for k in checks:
		ok = ok and checks[k]
		parts.append("%s=%s" % [k, str(checks[k])])
	print("STAGESELECT_RESULT entries=%d %s" % [count, " ".join(parts)])
	print("STAGESELECT_VERDICT %s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)
