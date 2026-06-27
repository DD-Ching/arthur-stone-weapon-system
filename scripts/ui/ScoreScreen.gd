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
## The grand finale tint + words, shown when the LAST Arthurian battle is won.
const FINALE_COL := Color(0.98, 0.84, 0.42)        ## regal gold (matches the lobby title)
const FINALE_BANNER := "THE LEGEND IS COMPLETE"
const FINALE_BLURB := "The whole stone is set down at last. Arthur's legend is sealed, and the boy who lifted a mountain is remembered as the once and future king."
## The big-moment audio events, fired on a result. Named so the test can verify the PATH
## (which event was chosen) without needing an audio device.
const EVT_VICTORY := "victory_fanfare"
const EVT_DEFEAT := "defeat_knell"

var _root: Control
var _dim: ColorRect
var _panel: ColorRect
var _banner: Label
var _kos: Label
var _time: Label
var _blurb: Label
var _list: MenuList
var _next_path := ""
## The audio event chosen on the most recent show_result (victory_fanfare / defeat_knell).
## Exposed so the headless test can assert the right stinger without a sound device.
var last_event := ""
## True when the most recent result was the campaign finale (last Arthurian battle won).
var last_was_finale := false

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
	# Play the big-moment stinger: a bright fanfare on a win, a low knell on a loss. This is
	# one place, so EVERY map + room + Ford gets win/loss audio for free. `last_event` records
	# the chosen event so the headless test can verify the path without an audio device.
	last_event = EVT_VICTORY if victory else EVT_DEFEAT
	if typeof(Audio) != TYPE_NIL:
		Audio.play(last_event)
	# Did this win complete the Arthurian legend? mark_completed has already run by now (the map
	# records the clear before revealing the score), so the finale is "we won AND the running
	# stage is the last Arthurian battle". Reuse the Campaign helper — no per-screen rule here.
	last_was_finale = victory and _is_finale_now()
	var accent := FINALE_COL if last_was_finale else (VICTORY_COL if victory else DEFEAT_COL)
	if last_was_finale:
		_banner.text = FINALE_BANNER
	else:
		_banner.text = "VICTORY" if victory else "DEFEAT"
	_banner.add_theme_color_override("font_color", accent)
	_kos.text = "KO  %d" % kos
	_time.text = "TIME  %s" % _format_time(seconds)
	# On the finale, override the per-battle blurb with the closing words of the legend.
	var shown_blurb := FINALE_BLURB if last_was_finale else blurb
	_blurb.text = shown_blurb
	_blurb.visible = shown_blurb != ""
	# Build the action buttons for this outcome and arm the menu. The finale has no "Next
	# Battle" (the legend is over) — it offers only the road home, Return to Lobby.
	var items: Array = []
	if victory:
		if next_path != "" and not last_was_finale:
			items.append({"id": "next", "label": "Next Battle"})
		items.append({"id": "lobby", "label": "Return to Lobby"})
	else:
		items.append({"id": "retry", "label": "Retry Battle"})
		items.append({"id": "lobby", "label": "Return to Lobby"})
	_list.accent = accent
	_list.set_items(items)
	_list.set_enabled(true)
	visible = true

## True when the currently-running stage is the LAST Arthurian battle — the campaign finale.
## Reads the live scene path and asks the Campaign autoload (the single source of truth). Guarded
## for headless / standalone use (no Campaign autoload, or the screen built outside a real scene).
func _is_finale_now() -> bool:
	var camp = _campaign()
	if camp == null or not camp.has_method("is_finale"):
		return false
	var tree := get_tree()
	if tree == null or tree.current_scene == null:
		return false
	return camp.is_finale(tree.current_scene.scene_file_path)

## The Campaign autoload, or null if it isn't registered (headless test harness / older host).
func _campaign():
	var tree := get_tree()
	if tree and tree.root and tree.root.has_node("Campaign"):
		return tree.root.get_node("Campaign")
	return null

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
				_goto(_next_path)
			else:
				_goto(STAGE_SELECT)
		"retry":
			get_tree().reload_current_scene()
		"lobby":
			_goto(STAGE_SELECT)

## Navigate through the shared scene-fade when the Transition autoload is present, else hard-cut so
## a build / headless run WITHOUT the autoload still reaches the next scene.
func _goto(path: String) -> void:
	var tr := get_node_or_null("/root/Transition")
	if tr:
		tr.change_scene(path)
	else:
		get_tree().change_scene_to_file(path)
