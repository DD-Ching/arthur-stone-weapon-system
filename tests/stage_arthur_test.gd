extends Node2D
## Headless test for the ARTHURIAN re-theme of the StageSelect boot menu.
##
## Instantiates StageSelect ALONE, steps a frame so it builds its list, and asserts the
## re-theme + sectioning held up without breaking the menu:
##   - it resolved a NON-EMPTY selectable entry list — at least the guaranteed-existing
##     scenes (Battlefield + the four challenge rooms + the five 三國 maps already on dev),
##     so >= 10 entries;
##   - every listed entry's `path` passes ResourceLoader.exists (no phantom rows from the
##     still-missing Arthurian maps, which are guarded + skipped on this branch);
##   - the new Arthurian TITLE is set (no longer the old 三國無雙 title);
##   - sections are tagged + ordered: every entry carries a known `section`, the bonus
##     三國 maps sort AFTER the ford/trials block, and `entries` holds ONLY selectable
##     battles (never a header row);
##   - navigation via `_move(1)` advances + WRAPS to 0 at the end, `_move(-1)` from 0 wraps
##     to the last entry, and every landing spot is a real selectable entry (never a header);
##   - the real input path (synthetic `move_down` action through `_input`) advances too;
##   - the currently-selected entry's path is a valid, loadable scene.
##
## It deliberately does NOT call change_scene_to_file (that would tear down the test).
##
## Run: godot --headless --path . res://tests/StageArthurTest.tscn --quit-after 600
## Look for STAGEARTHUR_VERDICT.

const STAGE_SELECT := preload("res://scenes/ui/StageSelect.tscn")

## Scenes that already exist on dev — must all be listed + selectable.
const GUARANTEED := [
	"res://scenes/Battlefield.tscn",
	"res://scenes/rooms/BowlingRoom.tscn",
	"res://scenes/rooms/WallCrushRoom.tscn",
	"res://scenes/rooms/RockLauncherRoom.tscn",
	"res://scenes/rooms/ComboTrialRoom.tscn",
	"res://scenes/maps/HuLaoGate.tscn",
	"res://scenes/maps/RedCliffs.tscn",
	"res://scenes/maps/Guandu.tscn",
	"res://scenes/maps/Changban.tscn",
	"res://scenes/maps/YellowTurban.tscn",
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

	# 1) Non-empty, and at least the ten guaranteed scenes resolved.
	checks["nonempty"] = count >= 10

	# 2) Every listed entry actually exists (no phantom rows from the missing Arthurian maps).
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

	# 4) The Arthurian re-theme: a new title is set, and it is NOT the old 三國無雙 one.
	var title: String = _menu.TITLE_TEXT
	checks["arthur_title"] = title != "" and title.find("三國") < 0 \
		and (title.to_upper().find("STONE") >= 0 or title.to_upper().find("ARTHUR") >= 0)

	# 5) Every selectable entry carries a known section tag (so headers can group them), and
	#    NONE of the entries is itself a header (entries are pure battles).
	var known := [_menu.SEC_ARTHUR, _menu.SEC_TRIALS, _menu.SEC_BONUS]
	var sections_ok := true
	for e in _menu.entries:
		if not e.has("section") or not known.has(e["section"]):
			sections_ok = false
	checks["sections_tagged"] = sections_ok

	# 6) Ordering: the 三國 BONUS maps come AFTER the ford/trials block. The first bonus
	#    entry's index must exceed the last trials entry's index.
	var last_trials := -1
	var first_bonus := count   # sentinel: larger than any index
	var idx := 0
	while idx < count:
		var sec: String = _menu.entries[idx]["section"]
		if sec == _menu.SEC_TRIALS:
			last_trials = idx
		elif sec == _menu.SEC_BONUS and idx < first_bonus:
			first_bonus = idx
		idx += 1
	checks["bonus_after_trials"] = last_trials >= 0 and first_bonus > last_trials

	# 7) Navigation: _move(1) advances the index, and the landing is a real selectable entry.
	_menu.selected = 0
	_menu._move(1)
	checks["advance"] = _menu.selected == 1 and _is_real_entry(_menu.selected)

	# 8) Navigation wraps at the end: from last → 0.
	_menu.selected = count - 1
	_menu._move(1)
	checks["wrap_forward"] = _menu.selected == 0

	# 9) Navigation wraps backward: from 0 → last.
	_menu.selected = 0
	_menu._move(-1)
	checks["wrap_back"] = _menu.selected == count - 1

	# 10) Sweep the whole list with _move(1): every landing is a valid selectable entry whose
	#     path exists — navigation never lands on a header / phantom row.
	_menu.selected = 0
	var sweep_ok := true
	var step := 0
	while step < count + 2:   # a couple past the end to exercise the wrap
		if not _is_real_entry(_menu.selected):
			sweep_ok = false
		var p: String = _menu.selected_path()
		if p == "" or not ResourceLoader.exists(p):
			sweep_ok = false
		_menu._move(1)
		step += 1
	checks["sweep_selectable"] = sweep_ok

	# 11) The real input path: a synthetic move_down action advances via _input (the same
	#     wiring keyboard/gamepad uses in-game). We do NOT synthesise `attack` (would launch).
	_menu.selected = 0
	var ev := InputEventAction.new()
	ev.action = "move_down"
	ev.pressed = true
	_menu._input(ev)
	checks["input_nav"] = _menu.selected == 1

	# 12) The currently-selected entry's path is a valid, loadable scene.
	_menu.selected = 0
	var sel_path: String = _menu.selected_path()
	checks["selected_valid"] = sel_path != "" and ResourceLoader.exists(sel_path)

	var ok := true
	var parts: Array = []
	for k in checks:
		ok = ok and checks[k]
		parts.append("%s=%s" % [k, str(checks[k])])
	print("STAGEARTHUR_RESULT entries=%d title=\"%s\" %s" % [count, str(_menu.TITLE_TEXT), " ".join(parts)])
	print("STAGEARTHUR_VERDICT %s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)

## True when `i` indexes a real selectable battle entry whose path resolves.
func _is_real_entry(i: int) -> bool:
	if i < 0 or i >= _menu.entries.size():
		return false
	var e = _menu.entries[i]
	return e.has("path") and ResourceLoader.exists(e["path"])
