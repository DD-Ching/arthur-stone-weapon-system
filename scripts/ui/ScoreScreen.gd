extends CanvasLayer
## ScoreScreen — the end-of-battle result overlay AND the campaign hand-off.
##
## Hidden by default; the level reveals it on a win or a loss via show_result(). It shows a
## VICTORY/DEFEAT banner, the KO count, the elapsed time (m:ss), a short Arthurian STORY BLURB,
## and a row of action buttons that tie the battles into one campaign:
##   - VICTORY → "Next Battle" (advance the campaign) + "Return to Lobby"
##   - DEFEAT  → "Retry" (this battle) + "Return to Lobby"
## Navigation reuses the shared MenuList (keyboard move_up/down + attack/Enter, or tap). The
## level passes the next battle's path + blurb (from the Campaign autoload) into show_result; this
## node owns no game state and never reaches into gameplay nodes.

const STAGE_SELECT := "res://scenes/ui/StageSelect.tscn"
const PANEL_SIZE := Vector2(620.0, 480.0)
const VICTORY_COL := Color(0.5, 0.95, 0.55)
const DEFEAT_COL := Color(0.95, 0.45, 0.4)

var _root: Control
var _dim: ColorRect
var _panel: ColorRect
var _banner: Label
var _kos: Label
var _time: Label
var _blurb: Label
var _list: MenuList
var _next_path := ""

func _ready() -> void:
	layer = 64          # draw above the HUD (default layer 1) and the world
	visible = false
	_build()

## Reveal the result panel. `victory` picks the banner + accent colour; `kos` the KO count;
## `seconds` the elapsed battle time (m:ss). `next_path` is the next campaign battle to advance to
## on a win ("" = none / campaign complete); `blurb` is the story beat shown under the score. The
## extra params are OPTIONAL so older callers (and the headless test) using the 3-arg form work.
func show_result(victory: bool, kos: int, seconds: float, next_path := "", blurb := "") -> void:
	if _root == null:
		_build()
	_next_path = next_path
	var accent := VICTORY_COL if victory else DEFEAT_COL
	_banner.text = "VICTORY" if victory else "DEFEAT"
	_banner.add_theme_color_override("font_color", accent)
	_kos.text = "KO  %d" % kos
	_time.text = "TIME  %s" % _format_time(seconds)
	_blurb.text = blurb
	_blurb.visible = blurb != ""
	# Build the action buttons for this outcome and arm the menu.
	var items: Array = []
	if victory:
		if next_path != "":
			items.append({"id": "next", "label": "Next Battle  ▶"})
		items.append({"id": "lobby", "label": "Return to Lobby"})
	else:
		items.append({"id": "retry", "label": "Retry Battle"})
		items.append({"id": "lobby", "label": "Return to Lobby"})
	_list.accent = accent
	_list.set_items(items)
	_list.set_enabled(true)
	visible = true

## Seconds → "m:ss" (e.g. 73.5 → "1:13"). Floors to whole seconds.
func _format_time(seconds: float) -> String:
	var total := int(maxf(0.0, seconds))
	var minutes := total / 60
	var secs := total % 60
	return "%d:%02d" % [minutes, secs]

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	# A dim wash over the battlefield so the panel reads as a modal result.
	_dim = ColorRect.new()
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.color = Color(0.0, 0.0, 0.0, 0.6)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_dim)

	# Centred panel.
	_panel = ColorRect.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.size = PANEL_SIZE
	_panel.position = -PANEL_SIZE * 0.5
	_panel.color = Color(0.09, 0.09, 0.12, 0.94)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_panel)

	_banner = _make_label(46, 24.0)
	_banner.text = "VICTORY"
	_kos = _make_label(30, 104.0)
	_kos.text = "KO  0"
	_time = _make_label(30, 150.0)
	_time.text = "TIME  0:00"
	# The story beat — wrapped, dimmer, smaller. Sits between the score and the buttons.
	_blurb = _make_label(18, 204.0)
	_blurb.offset_left = 36.0
	_blurb.offset_right = -36.0
	_blurb.offset_bottom = 296.0
	_blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_blurb.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_blurb.add_theme_color_override("font_color", Color(0.82, 0.82, 0.9))
	_blurb.text = ""

	# The action buttons, in the lower band of the panel (panel-local coords).
	_list = MenuList.new()
	_list.position = Vector2(0.0, 300.0)
	_list.size = Vector2(PANEL_SIZE.x, PANEL_SIZE.y - 300.0)
	_panel.add_child(_list)
	_list.chosen.connect(_on_chosen)
	_list.set_enabled(false)

## A horizontally-centred label inside the panel at a given top offset + font size.
func _make_label(font_size: int, top: float) -> Label:
	var l := Label.new()
	l.set_anchors_preset(Control.PRESET_TOP_WIDE)
	l.offset_top = top
	l.offset_bottom = top + float(font_size) + 12.0
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_size)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(l)
	return l

func _on_chosen(id: String) -> void:
	match id:
		"next":
			if _next_path != "" and ResourceLoader.exists(_next_path):
				get_tree().change_scene_to_file(_next_path)
			else:
				get_tree().change_scene_to_file(STAGE_SELECT)
		"retry":
			get_tree().reload_current_scene()
		"lobby":
			get_tree().change_scene_to_file(STAGE_SELECT)
