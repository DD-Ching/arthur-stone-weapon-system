extends CanvasLayer
## StageSelect — the boot menu that lets the player pick a battle and launches it.
##
## A cheap, code-drawn menu (no theme, no .tres) re-themed around the ARTHURIAN legend:
## Arthur failed to draw the sword, so he lifted the WHOLE STONE. The list leads with the
## legend's battles (Sword in the Stone, Mount Badon, Defend Camelot, Camlann, the Lady of
## the Lake), then "Hold the Ford" and the challenge rooms, then a Three-Kingdoms BONUS
## section. It is the game's `run/main_scene`: pick a battle and Arthur is dropped into it.
##
## Reuse / safety: every candidate battle is GUARDED with `ResourceLoader.exists(path)` at
## build time. Scenes that don't exist on this branch yet (the new Arthurian maps are
## produced by parallel work) are simply skipped — the menu never references a missing
## resource, so it can't crash or fail to import. Adding a battle is one line in `CANDIDATES`.
##
## Sections: each candidate carries a `section` tag. `entries` holds ONLY the selectable
## battles (those whose path resolved), so navigation/selection logic is untouched and can
## never land on a header. The drawn list emits a dim, non-selectable section label whenever
## the section changes between consecutive entries — headers are pure paint, not nav targets.
##
## Input reuses the existing actions (project.godot): `move_up` / `move_down` move the
## selection (wrapping), `attack` (Space / LMB) or Enter launches it. Gamepad/keyboard
## friendly; tap (mouse or touch) selects a row, tapping the highlighted row launches it.

## Section ids, in display order. Used to group + label the list.
const SEC_ARTHUR := "arthur"
const SEC_TRIALS := "trials"
const SEC_BONUS := "bonus"

## Human-readable, non-selectable headers drawn above each section's first entry.
const SECTION_LABELS := {
	SEC_ARTHUR: "— THE LEGEND OF KING ARTHUR —",
	SEC_TRIALS: "— FORD & TRIALS —",
	SEC_BONUS: "— THREE KINGDOMS (BONUS) —",
}

## A battle the menu can offer. Only those whose `path` resolves are actually listed; the
## order here is the display order, with Arthurian battles first and the 三國 maps demoted
## to a bonus section. Several Arthurian scenes are produced by sibling work and may not
## exist on this branch yet — they're skip-guarded and simply appear after integration.
const CANDIDATES := [
	# The legend of King Arthur (some still pending sibling work — guarded, may be skipped).
	{"title": "The Sword in the Stone", "path": "res://scenes/maps/SwordInStone.tscn", "section": SEC_ARTHUR},
	{"title": "Mount Badon", "path": "res://scenes/maps/MountBadon.tscn", "section": SEC_ARTHUR},
	{"title": "Defend Camelot", "path": "res://scenes/maps/DefendCamelot.tscn", "section": SEC_ARTHUR},
	{"title": "Camlann", "path": "res://scenes/maps/Camlann.tscn", "section": SEC_ARTHUR},
	{"title": "The Lady of the Lake", "path": "res://scenes/maps/LadyOfLake.tscn", "section": SEC_ARTHUR},
	# Hold the Ford + the challenge rooms.
	{"title": "Hold the Ford", "path": "res://scenes/Battlefield.tscn", "section": SEC_TRIALS},
	{"title": "Bowling Room", "path": "res://scenes/rooms/BowlingRoom.tscn", "section": SEC_TRIALS},
	{"title": "Wall Crush Room", "path": "res://scenes/rooms/WallCrushRoom.tscn", "section": SEC_TRIALS},
	{"title": "Rock Launcher Room", "path": "res://scenes/rooms/RockLauncherRoom.tscn", "section": SEC_TRIALS},
	{"title": "Combo Trial Room", "path": "res://scenes/rooms/ComboTrialRoom.tscn", "section": SEC_TRIALS},
	# Three-Kingdoms BONUS maps.
	{"title": "Hu Lao Gate", "path": "res://scenes/maps/HuLaoGate.tscn", "section": SEC_BONUS},
	{"title": "Red Cliffs", "path": "res://scenes/maps/RedCliffs.tscn", "section": SEC_BONUS},
	{"title": "Guandu", "path": "res://scenes/maps/Guandu.tscn", "section": SEC_BONUS},
	{"title": "Changban", "path": "res://scenes/maps/Changban.tscn", "section": SEC_BONUS},
	{"title": "Yellow Turban Rebellion", "path": "res://scenes/maps/YellowTurban.tscn", "section": SEC_BONUS},
]

const TITLE_TEXT := "THE STONE KING — CHOOSE YOUR BATTLE"
const HINT_TEXT := "W/S or ↑/↓ · Space/Enter to deploy   ·   or TAP a battle"

const BG_COL := Color(0.08, 0.07, 0.10, 1.0)
const TITLE_COL := Color(0.96, 0.82, 0.42)
const ITEM_COL := Color(0.78, 0.78, 0.84)
const SELECT_COL := Color(1.0, 0.95, 0.7)
const HIGHLIGHT_COL := Color(0.62, 0.18, 0.16, 0.85)
const HINT_COL := Color(0.6, 0.6, 0.68)
const HEADER_COL := Color(0.52, 0.5, 0.62)   ## dim, non-selectable section label

const ROW_H := 46.0           ## pixel height of one battle row
const HEADER_H := 30.0        ## pixel height of a section header label
const LIST_TOP := 150.0       ## y of the first drawn line
const TITLE_Y := 84.0

## The resolved battles, in display order: [{title, path, section}, …]. Built in `_ready`.
## Holds ONLY selectable battles — headers are never entries, so nav can't land on one.
var entries: Array = []
## Index into `entries` of the highlighted battle.
var selected := 0

var _root: Control
var _draw_layer: Control
var _vp := Vector2(1280, 720)

func _ready() -> void:
	layer = 0
	_build_entries()
	_build_ui()
	set_process_input(true)

## Filter CANDIDATES down to the scenes that actually exist on this branch, preserving the
## section tag so the drawn list can group them. Untyped loop var on purpose — the entries
## are Dictionaries inside a const Array (Variant); `:=` would fail type inference (a known
## GDScript 4.3 pitfall).
func _build_entries() -> void:
	entries = []
	for c in CANDIDATES:
		var path: String = c["path"]
		if ResourceLoader.exists(path):
			entries.append({"title": c["title"], "path": path, "section": c["section"]})
	if selected >= entries.size():
		selected = 0

func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = BG_COL
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(bg)

	# A dedicated child Control owns the _draw() so it paints over the background rect.
	_draw_layer = _DrawLayer.new()
	_draw_layer.owner_menu = self
	_draw_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_draw_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_draw_layer)

	_vp = get_viewport().get_visible_rect().size
	get_viewport().size_changed.connect(_on_resize)
	_redraw()

func _on_resize() -> void:
	_vp = get_viewport().get_visible_rect().size
	_redraw()

func _redraw() -> void:
	if _draw_layer:
		_draw_layer.queue_redraw()

# --- layout ------------------------------------------------------------------

## The y of entry `i`'s row top, accounting for the section header drawn above each
## section's first entry. Single source of truth shared by drawing and the tap hit-test so
## the two never drift apart. A header precedes entry `i` when its section differs from the
## previous entry's (the first entry always opens its section).
func _row_top(i: int) -> float:
	var y := LIST_TOP
	var prev_section := ""
	var k := 0
	while k < entries.size():
		var sec: String = entries[k]["section"]
		if sec != prev_section:
			y += HEADER_H
			prev_section = sec
		if k == i:
			return y
		y += ROW_H
		k += 1
	return y

# --- input ------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if entries.is_empty():
		return
	if event.is_action_pressed("move_down"):
		_move(1)
		_consume()
	elif event.is_action_pressed("move_up"):
		_move(-1)
		_consume()
	elif event.is_action_pressed("attack") or _is_enter(event):
		_launch()
		_consume()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Tap a row to select it; tap the already-selected row to launch.
		var hit := _row_at(event.position)
		if hit >= 0:
			if hit == selected:
				_launch()
			else:
				selected = hit
				_redraw()
			_consume()
	elif event is InputEventScreenTouch and event.pressed:
		# Phones (emulate_mouse_from_touch is off) — tap a battle row to select it, tap the
		# highlighted row to deploy. Same hit-test the mouse path uses.
		var hit_t := _row_at(event.position)
		if hit_t >= 0:
			if hit_t == selected:
				_launch()
			else:
				selected = hit_t
				_redraw()
			_consume()

## Mark the event handled. We're a CanvasLayer (no Control.accept_event), so we stop
## propagation through the viewport directly — guarded for the headless test, which calls
## `_input` on a bare instance that isn't inside the tree.
func _consume() -> void:
	var vp := get_viewport()
	if vp:
		vp.set_input_as_handled()

func _is_enter(event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed and not event.echo:
		return event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER
	return false

## Move the selection by `dir` rows, wrapping around the ends. Public so the headless
## test can drive navigation without synthesising key events. Only ever lands on a real
## (selectable) entry — headers aren't entries, so they're skipped for free.
func _move(dir: int) -> void:
	if entries.is_empty():
		return
	selected = wrapi(selected + dir, 0, entries.size())
	_redraw()

## The path of the currently-highlighted battle, or "" if there are none.
func selected_path() -> String:
	if selected < 0 or selected >= entries.size():
		return ""
	return entries[selected]["path"]

## Launch the highlighted battle. Guarded again at the point of use so a stale/empty
## selection can never hand `change_scene_to_file` an invalid path.
func _launch() -> void:
	var path := selected_path()
	if path == "" or not ResourceLoader.exists(path):
		return
	get_tree().change_scene_to_file(path)

## Which row (entry index) the point `p` falls on, or -1. Used for tap-to-select. Tapping a
## section header's band falls between rows and returns -1, so headers stay inert to touch.
func _row_at(p: Vector2) -> int:
	var i := 0
	while i < entries.size():
		var top := _row_top(i)
		if p.y >= top and p.y < top + ROW_H:
			return i
		i += 1
	return -1

# --- drawing (a child Control so it paints above the background) -------------

## Inner Control whose sole job is the code-drawn list. Kept as a nested class so the
## whole menu is a single file; it reads its state back from the owning StageSelect.
class _DrawLayer extends Control:
	var owner_menu

	func _draw() -> void:
		if owner_menu == null:
			return
		var vp: Vector2 = size
		if vp.x <= 0.0:
			vp = owner_menu._vp
		var font := get_theme_default_font()
		if font == null:
			return

		# Title banner.
		_centered(font, owner_menu.TITLE_TEXT, vp.x, owner_menu.TITLE_Y, 40, owner_menu.TITLE_COL)

		# Battle rows, grouped under dim section headers.
		var entries: Array = owner_menu.entries
		if entries.is_empty():
			_centered(font, "(no battles found)", vp.x, owner_menu.LIST_TOP, 26,
				owner_menu.ITEM_COL)
		else:
			var prev_section := ""
			var i := 0
			while i < entries.size():
				var top: float = owner_menu._row_top(i)
				var sec: String = entries[i]["section"]
				# Emit the (non-selectable) section header just above this section's first row.
				if sec != prev_section:
					var hdr: String = owner_menu.SECTION_LABELS.get(sec, "")
					if hdr != "":
						_centered(font, hdr, vp.x, top - 8.0, 20, owner_menu.HEADER_COL)
					prev_section = sec
				var is_sel: bool = i == owner_menu.selected
				if is_sel:
					var pad := 28.0
					draw_rect(Rect2(pad, top + 5.0, vp.x - pad * 2.0,
						owner_menu.ROW_H - 10.0), owner_menu.HIGHLIGHT_COL, true)
				var prefix := "▶  " if is_sel else "    "
				var col: Color = owner_menu.SELECT_COL if is_sel else owner_menu.ITEM_COL
				var fs := 28 if is_sel else 25
				var label: String = prefix + str(entries[i]["title"])
				_centered(font, label, vp.x, top + owner_menu.ROW_H * 0.5 + float(fs) * 0.35,
					fs, col)
				i += 1

		# Hint line at the bottom.
		_centered(font, owner_menu.HINT_TEXT, vp.x, vp.y - 48.0, 18, owner_menu.HINT_COL)

	## Draw `text` horizontally centred across width `w`, baseline at `y`.
	func _centered(font, text: String, w: float, y: float, fs: int, col: Color) -> void:
		var sz: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		draw_string(font, Vector2((w - sz.x) * 0.5, y), text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
