extends Button
## StageCard — one battle "card" in the lobby's stage list.
##
## A themed Button (so it inherits the shared lobby Theme + focus/hover styling for free) that
## lays out a battle's title, a small section/era tag, and a state badge (LOCKED / NEW / CLEARED)
## inside itself with child Labels. Build once, reuse many: the lobby spawns one per battle and
## never duplicates this layout. The lobby maps a press / focus back to its entry via the signal
## bind + its own card array, so the card stays a pure view and holds no index of its own.
##
## Pure presentation: the card NEVER launches or mutates campaign state. It emits the standard
## Button `pressed` signal (tap / Enter / Space while focused); the lobby owns the launch flow.

## Badge states. LOCKED rows stay in the list (the contract keeps the row, shows a lock badge).
const BADGE_LOCKED := "locked"
const BADGE_NEW := "new"
const BADGE_CLEARED := "cleared"

## The title label + badge label are kept because their colour is re-tinted in _apply_badge.
var _title_label: Label
var _badge: Label

## Lay out this card's title, era tag, and state badge. Called once by the lobby at build time.
func setup(title: String, tag: String, badge: String, palette: Dictionary) -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	# The button's own text is empty — we lay out our own labels so the title, tag and badge can
	# each carry their own type scale + colour. Toggle off the default text centring.
	text = ""
	clip_contents = true
	custom_minimum_size = Vector2(0, 64)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var pad := MarginContainer.new()
	pad.set_anchors_preset(Control.PRESET_FULL_RECT)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_theme_constant_override("margin_left", 18)
	pad.add_theme_constant_override("margin_right", 18)
	pad.add_theme_constant_override("margin_top", 10)
	pad.add_theme_constant_override("margin_bottom", 10)
	add_child(pad)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 14)
	pad.add_child(row)

	# Left column: the battle title (large) over a dim section/era tag (small).
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 2)
	row.add_child(col)

	_title_label = Label.new()
	_title_label.text = title
	_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_label.add_theme_font_size_override("font_size", 22)
	_title_label.add_theme_color_override("font_color", palette.get("card_title", Color.WHITE))
	col.add_child(_title_label)

	var tag_label := Label.new()
	tag_label.text = tag
	tag_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag_label.add_theme_font_size_override("font_size", 13)
	tag_label.add_theme_color_override("font_color", palette.get("card_tag", Color.GRAY))
	col.add_child(tag_label)

	# Right: the state badge, vertically centred.
	var badge_wrap := CenterContainer.new()
	badge_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(badge_wrap)

	_badge = Label.new()
	_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_badge.add_theme_font_size_override("font_size", 14)
	badge_wrap.add_child(_badge)
	_apply_badge(badge, palette)

## Paint the badge text + colour for its state. LOCKED dims the card's TEXT (not the whole card
## via `modulate`, which would also mute the selected/focus highlight) so the lock reads as "not
## yet available" while the row stays present + crisply selectable per the contract.
func _apply_badge(badge: String, palette: Dictionary) -> void:
	match badge:
		BADGE_LOCKED:
			_badge.text = "🔒 LOCKED"
			_badge.add_theme_color_override("font_color", palette.get("badge_locked", Color.GRAY))
			_title_label.add_theme_color_override("font_color",
				palette.get("card_title", Color.WHITE) * Color(1, 1, 1, 0.62))
		BADGE_CLEARED:
			_badge.text = "✔ CLEARED"
			_badge.add_theme_color_override("font_color", palette.get("badge_cleared", Color.GREEN))
		BADGE_NEW:
			_badge.text = "◆ NEW"
			_badge.add_theme_color_override("font_color", palette.get("badge_new", Color.YELLOW))
		_:
			_badge.text = ""
