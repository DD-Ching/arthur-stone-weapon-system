class_name MenuList
extends Control
## A reusable, code-drawn vertical button column for overlays (PauseMenu, ScoreScreen, and any
## future menu). One place for menu navigation so overlays don't each reinvent keyboard + tap
## handling. Set the buttons with `set_items([{id, label}])`; drive it with the existing actions
## (`move_up` / `move_down` to change focus, `attack` / Enter to activate) or a tap; it emits
## `chosen(id)`. Buttons are centred within this Control's own rect, so the owner positions it
## (full-rect for a modal pause; a lower band for a result panel).
##
## Honours a paused tree: works while `get_tree().paused` is true as long as the owning overlay
## is `process_mode = ALWAYS` (this node inherits that). Stays inert while hidden or disabled.

signal chosen(id: String)

const BTN_W := 360.0
const BTN_H := 56.0
const GAP := 16.0

var items: Array = []                      ## [{id, label}]
var focused := 0
var accent := Color(0.96, 0.82, 0.42)      ## Camelot gold by default

var _enabled := true

func _ready() -> void:
	# Run input even while the tree is paused (the pause overlay relies on this).
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE   # we read raw input in _input, never eat GUI mouse

## Replace the button set; focus resets to the first item.
func set_items(list: Array) -> void:
	items = list
	focused = 0
	queue_redraw()

## Enable/disable input + repaint focus (hidden menus disable themselves).
func set_enabled(on: bool) -> void:
	_enabled = on

## Move focus by `dir`, wrapping. Public so a test can drive it without synthetic events.
func focus_move(dir: int) -> void:
	if items.is_empty():
		return
	focused = wrapi(focused + dir, 0, items.size())
	queue_redraw()

## Fire `chosen` for the focused item. Public so a test can activate without synthetic events.
func activate() -> void:
	if focused >= 0 and focused < items.size():
		chosen.emit(String(items[focused]["id"]))

## The id of the focused item ("" if none) — handy for tests/inspection.
func focused_id() -> String:
	if focused < 0 or focused >= items.size():
		return ""
	return String(items[focused]["id"])

func _input(event: InputEvent) -> void:
	if not (_enabled and is_visible_in_tree()) or items.is_empty():
		return
	if event.is_action_pressed("move_down"):
		focus_move(1); _consume()
	elif event.is_action_pressed("move_up"):
		focus_move(-1); _consume()
	elif event.is_action_pressed("attack") or _is_enter(event):
		activate(); _consume()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var hit := _at(event.position)
		if hit >= 0:
			focused = hit
			queue_redraw()
			activate()
			_consume()
	elif event is InputEventScreenTouch and event.pressed:
		var ht := _at(event.position)
		if ht >= 0:
			focused = ht
			queue_redraw()
			activate()
			_consume()

func _consume() -> void:
	var vp := get_viewport()
	if vp:
		vp.set_input_as_handled()

func _is_enter(event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed and not event.echo:
		return event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER
	return false

## Total height of the button stack — lets an owner size/centre the band that holds it.
func stack_height() -> float:
	if items.is_empty():
		return 0.0
	return float(items.size()) * BTN_H + float(items.size() - 1) * GAP

## The rect of button `i`, centred within this Control's own size.
func _button_rect(i: int) -> Rect2:
	var top := (size.y - stack_height()) * 0.5
	var x := (size.x - BTN_W) * 0.5
	var y := top + float(i) * (BTN_H + GAP)
	return Rect2(x, y, BTN_W, BTN_H)

## Which button the viewport-space point `p` falls on, or -1. Button rects are local, so we add
## this Control's global position — that way the hit-test is correct whether this MenuList fills
## the screen (PauseMenu) or sits nested in a panel (ScoreScreen).
func _at(p: Vector2) -> int:
	var origin := global_position
	for i in items.size():
		var r := _button_rect(i)
		r.position += origin
		if r.has_point(p):
			return i
	return -1

func _draw() -> void:
	var font := get_theme_default_font()
	if font == null or items.is_empty():
		return
	for i in items.size():
		var r := _button_rect(i)
		var is_f := i == focused
		draw_rect(r, Color(accent, 0.30 if is_f else 0.12), true)
		draw_rect(r, Color(accent, 0.95 if is_f else 0.40), false, 2.0)
		var label := String(items[i]["label"])
		var fs := 26
		var sz := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		var col := Color(1, 1, 1, 0.97) if is_f else Color(0.82, 0.82, 0.88, 0.9)
		draw_string(font, r.position + Vector2((r.size.x - sz.x) * 0.5, r.size.y * 0.5 + float(fs) * 0.35),
			label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
