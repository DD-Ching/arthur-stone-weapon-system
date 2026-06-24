extends CanvasLayer
## ScoreScreen — the end-of-battle result overlay.
##
## A cheap CanvasLayer overlay, hidden by default, that the level reveals on a win or a
## loss. It shows a VICTORY/DEFEAT banner, the KO count (Arthur's musou kills this battle),
## and the elapsed battle time formatted m:ss. Built in code from Labels + ColorRects in the
## same ugly-but-clear HUD style — no theme, no per-frame work once shown.
##
## Reuse: the level passes in Impact.kills and its own elapsed accumulator via show_result();
## this node owns no game state and never reaches into gameplay nodes.

const PANEL_SIZE := Vector2(560.0, 320.0)
const VICTORY_COL := Color(0.5, 0.95, 0.55)
const DEFEAT_COL := Color(0.95, 0.45, 0.4)

var _root: Control
var _dim: ColorRect
var _panel: ColorRect
var _banner: Label
var _kos: Label
var _time: Label
var _hint: Label

func _ready() -> void:
	layer = 64          # draw above the HUD (default layer 1) and the world
	visible = false
	_build()

## Reveal the result panel. `victory` picks the banner + accent colour; `kos` is the KO
## count; `seconds` is the elapsed battle time, shown as m:ss.
func show_result(victory: bool, kos: int, seconds: float) -> void:
	if _root == null:
		_build()
	var accent := VICTORY_COL if victory else DEFEAT_COL
	_banner.text = "VICTORY" if victory else "DEFEAT"
	_banner.add_theme_color_override("font_color", accent)
	_kos.text = "KO  %d" % kos
	_time.text = "TIME  %s" % _format_time(seconds)
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
	_dim.color = Color(0.0, 0.0, 0.0, 0.55)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_dim)

	# Centred panel.
	_panel = ColorRect.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.size = PANEL_SIZE
	_panel.position = -PANEL_SIZE * 0.5
	_panel.color = Color(0.09, 0.09, 0.12, 0.92)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_panel)

	_banner = _make_label(44, 28.0)
	_banner.text = "VICTORY"
	_kos = _make_label(30, 132.0)
	_kos.text = "KO  0"
	_time = _make_label(30, 184.0)
	_time.text = "TIME  0:00"
	_hint = _make_label(16, 256.0)
	_hint.text = "(press R to restart)"
	_hint.add_theme_color_override("font_color", Color(0.8, 0.8, 0.85))

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
