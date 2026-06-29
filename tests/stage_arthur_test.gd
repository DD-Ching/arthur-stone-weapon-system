extends Node2D
## Headless test for the ARTHURIAN world structure of the StageSelect boot menu.
##
## Instantiates StageSelect ALONE, steps a frame so it builds its list, and asserts the
## connected-legend re-theme held up without breaking the menu:
##   - it resolved a NON-EMPTY selectable entry list — at least the guaranteed-existing scenes
##     (Battlefield + the four challenge rooms + the five reskinned war regions), so >= 10 entries;
##   - every listed entry's `path` passes ResourceLoader.exists (no phantom rows);
##   - the Arthurian TITLE is set (contains STONE/ARTHUR, never "三國");
##   - sections are the two Arthurian groups only (legend + training yard); the legend sorts
##     BEFORE the training yard, and `entries` holds ONLY selectable battles (never a header row);
##   - navigation via `_move(±1)` advances + WRAPS, and the real `move_down` input path advances;
##   - the currently-selected entry's path is a valid, loadable scene.
##
## It deliberately does NOT call change_scene_to_file (that would tear down the test).
##
## Run: godot --headless --path . res://tests/StageArthurTest.tscn --quit-after 600
## Look for STAGEARTHUR_VERDICT.

const STAGE_SELECT := preload("res://scenes/ui/StageSelect.tscn")

## Scenes that exist on dev — must all be listed + selectable (the 5 reskinned war regions keep
## their original file paths per the reskin-in-place strategy; their THEME is now Arthurian).
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

	# 2) Every listed entry actually exists.
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

	# 4) The Arthurian title: a new title is set, and it is NOT a Three-Kingdoms one.
	var title: String = _menu.TITLE_TEXT
	checks["arthur_title"] = title != "" and title.find("三國") < 0 \
		and (title.to_upper().find("STONE") >= 0 or title.to_upper().find("ARTHUR") >= 0)

	# 5) Every selectable entry carries a known section tag (legend or training yard) — no bonus
	#    section exists any more — and NONE of the entries is itself a header.
	var known := [_menu.SEC_ARTHUR, _menu.SEC_TRIALS]
	var sections_ok := true
	for e in _menu.entries:
		if not e.has("section") or not known.has(e["section"]):
			sections_ok = false
	checks["sections_tagged"] = sections_ok

	# 6) Ordering: the legend regions come BEFORE the training-yard block. The last legend entry's
	#    index must be below the first training-yard entry's index.
	var last_legend := -1
	var first_trials := count   # sentinel: larger than any index
	var idx := 0
	while idx < count:
		var sec: String = _menu.entries[idx]["section"]
		if sec == _menu.SEC_ARTHUR:
			last_legend = idx
		elif sec == _menu.SEC_TRIALS and idx < first_trials:
			first_trials = idx
		idx += 1
	checks["legend_before_trials"] = last_legend >= 0 and first_trials > last_legend

	# 7) Navigation: _move(1) advances the index, landing on a real selectable entry.
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

	# 10) Sweep the whole list with _move(1): every landing is a valid selectable entry.
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

	# 11) The real input path: a synthetic move_down action advances via _input.
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
