extends CanvasLayer
## StageSelect — the lobby / boot menu. Pick a battle, deploy Arthur into it.
##
## This is the game's `run/main_scene`. It is a RESPONSIVE Control tree (anchors + containers,
## NOT absolute pixel coords), so the list reflows on 1280x720 AND a phone, and a ScrollContainer
## carries any overflow instead of painting battles off the bottom of the viewport.
##
## Layout (all containers — nothing is hard-positioned):
##   MarginContainer (full rect, ~32px)            ← outer frame
##     └ VBoxContainer
##         ├ Label  ......................... the legend TITLE
##         ├ ScrollContainer (EXPAND_FILL)
##         │   └ VBoxContainer  ............. one block per section
##         │        ├ Label (dim header)  .. Campaign.SECTION_LABELS[section]
##         │        └ StageCard × N  ....... a themed Button per battle: title + era tag + badge
##         └ HBoxContainer (footer)
##              ├ DEPLOY  ...... launch the focused card
##              └ QUICK START .. jump into the first unlocked battle
##
## Build once, reuse many: the battle list + progress come from the `Campaign` autoload — the
## single source of truth shared with the pause menu / score screen / battle maps. We iterate
## `Campaign.stages()` (already ordered Arthur → Ford & Trials → Three-Kingdoms bonus), guard
## each with `ResourceLoader.exists` (so pending sibling maps are skipped, never referenced),
## and read `Campaign.is_unlocked` / `is_cleared` for each card's badge. A cohesive Arthurian
## palette + a clear title/section/card/badge type scale come from a single code-built Theme.
##
## Input reuses the project actions: `move_up` / `move_down` move the selection (wrapping),
## `attack` (Space / LMB) or Enter deploys it. Tapping a card selects it; tapping the already-
## selected card deploys (tap-to-select / tap-again-to-launch), on mouse and touch alike.
##
## Public surface (driven by tests/stage_select_test.gd + tests/stage_arthur_test.gd, kept stable):
##   `entries`  — Array of ONLY selectable battles as {title, path, section}, in display order.
##   `selected` — index into `entries` of the highlighted battle.
##   `_move(dir)`, `selected_path()` — wrapping navigation + the chosen scene path.
##   `TITLE_TEXT`, `SEC_ARTHUR` / `SEC_TRIALS` / `SEC_BONUS`, `SECTION_LABELS` — re-exposed.

const StageCard := preload("res://scripts/ui/StageCard.gd")

## Section ids re-exposed for the headless tests (they read `_menu.SEC_*`). Mirror Campaign's.
const SEC_ARTHUR := "arthur"
const SEC_TRIALS := "trials"
const SEC_BONUS := "bonus"

## Human-readable section headers, re-exposed for tests. Resolved from Campaign at build time so
## the lobby and the campaign never drift; this const is the fallback if the autoload is absent.
const SECTION_LABELS := {
	SEC_ARTHUR: "— THE LEGEND OF KING ARTHUR —",
	SEC_TRIALS: "— FORD & TRIALS —",
	SEC_BONUS: "— THREE KINGDOMS (BONUS) —",
}

## A short era / kind tag printed under each card's title, by section.
const SECTION_TAGS := {
	SEC_ARTHUR: "ARTHURIAN LEGEND",
	SEC_TRIALS: "TRIAL · PRACTICE",
	SEC_BONUS: "THREE KINGDOMS · BONUS",
}

## Title MUST contain both "STONE" and "ARTHUR" (and never "三國") — asserted by the Arthur test.
const TITLE_TEXT := "THE STONE KING — ARTHUR'S CAMPAIGN"
const HINT_TEXT := "W/S or Up/Down to choose   ·   Space / Enter to deploy   ·   or TAP a battle"

# --- Arthurian palette (reused for the code-built Theme + the cards) ----------
const BG_COL := Color(0.10, 0.09, 0.14, 1.0)       ## deep night-violet backdrop
const TITLE_COL := Color(0.96, 0.82, 0.42)          ## regal gold
const SUBTITLE_COL := Color(0.62, 0.6, 0.72)
const HEADER_COL := Color(0.58, 0.55, 0.70)         ## dim section header
const CARD_BG := Color(0.15, 0.14, 0.20, 1.0)
const CARD_BG_HOVER := Color(0.20, 0.18, 0.27, 1.0)
const CARD_BG_SEL := Color(0.30, 0.13, 0.13, 1.0)   ## blood-red selected
const CARD_BORDER := Color(0.28, 0.26, 0.36, 1.0)
const CARD_BORDER_SEL := Color(0.86, 0.36, 0.30, 1.0)
const CARD_TITLE_COL := Color(0.92, 0.91, 0.96)
const CARD_TAG_COL := Color(0.56, 0.54, 0.66)
const BADGE_LOCKED_COL := Color(0.55, 0.52, 0.60)
const BADGE_NEW_COL := Color(0.98, 0.84, 0.40)
const BADGE_CLEARED_COL := Color(0.46, 0.78, 0.52)
const DEPLOY_BG := Color(0.62, 0.18, 0.16, 1.0)
const DEPLOY_BG_HOVER := Color(0.74, 0.22, 0.20, 1.0)
const QUICK_BG := Color(0.18, 0.17, 0.24, 1.0)
const QUICK_BG_HOVER := Color(0.24, 0.23, 0.32, 1.0)
const BTN_TEXT_COL := Color(0.96, 0.93, 0.88)

## The resolved battles, in display order: [{title, path, section}, …]. Built in `_ready`.
## Holds ONLY selectable battles (headers are containers, never entries) so nav can't land on one.
var entries: Array = []
## Index into `entries` of the highlighted battle.
var selected := 0

## entry index → its StageCard, so selection changes can restyle the right card.
var _cards: Array = []
var _scroll: ScrollContainer
var _palette := {}
## Set when a card's `focus_entered` just MOVED the selection (a first mouse-click lands focus
## before the Button emits `pressed`). It lets `_on_card_pressed` distinguish "first click =
## select only" from "click an already-selected card = deploy", preserving tap-to-select /
## tap-again-to-launch on mouse. Keyboard (card already focused) never sets it, so Space/Enter
## on the highlighted card deploys as expected.
var _select_consumed_press := false
## The two static card skins (selected vs resting), built once and reused on every restyle.
var _sb_card_sel: StyleBoxFlat
var _sb_card_rest: StyleBoxFlat

func _ready() -> void:
	layer = 0
	_palette = _build_palette()
	_build_entries()
	_build_ui()
	set_process_input(true)
	_refresh_selection()

# --- entries (from Campaign, guarded) ----------------------------------------

## Filter the Campaign stage table down to scenes that exist on this branch, preserving order +
## the section tag. Untyped loop var on purpose — the stages are Dictionaries inside a const
## Array (Variant); `:=` would fail type inference (a known GDScript 4.3 pitfall). Falls back to
## SECTION_LABELS' own keys' battles only if Campaign is somehow unavailable (it's an autoload).
func _build_entries() -> void:
	entries = []
	for s in _stage_table():
		var path: String = String(s.get("path", ""))
		if path != "" and ResourceLoader.exists(path):
			entries.append({
				"title": String(s.get("title", "")),
				"path": path,
				"section": String(s.get("section", "")),
			})
	if selected >= entries.size():
		selected = 0

## The ordered stage table from the Campaign autoload (single source of truth).
func _stage_table() -> Array:
	var camp = _campaign()
	if camp != null:
		return camp.stages()
	return []

# --- UI build (responsive container tree) ------------------------------------

func _build_palette() -> Dictionary:
	return {
		"card_title": CARD_TITLE_COL,
		"card_tag": CARD_TAG_COL,
		"badge_locked": BADGE_LOCKED_COL,
		"badge_new": BADGE_NEW_COL,
		"badge_cleared": BADGE_CLEARED_COL,
	}

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = BG_COL
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var theme := _build_theme()

	var frame := MarginContainer.new()
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.theme = theme
	frame.add_theme_constant_override("margin_left", 32)
	frame.add_theme_constant_override("margin_right", 32)
	frame.add_theme_constant_override("margin_top", 28)
	frame.add_theme_constant_override("margin_bottom", 28)
	add_child(frame)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	frame.add_child(column)

	# (a) Title.
	var title := Label.new()
	title.text = TITLE_TEXT
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 38)
	title.add_theme_color_override("font_color", TITLE_COL)
	column.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Choose your battle"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.add_theme_color_override("font_color", SUBTITLE_COL)
	column.add_child(subtitle)

	# (b) Scrolling list of section blocks — this is what fixes the overflow.
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(_scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 10)
	_scroll.add_child(list)

	_cards = []
	for _i in entries.size():
		_cards.append(null)

	var prev_section := ""
	var i := 0
	while i < entries.size():
		var sec: String = entries[i]["section"]
		if sec != prev_section:
			list.add_child(_make_header(sec))
			prev_section = sec
		var card := _make_card(i)
		list.add_child(card)
		_cards[i] = card
		i += 1

	if entries.is_empty():
		var empty := Label.new()
		empty.text = "(no battles found)"
		empty.add_theme_color_override("font_color", SUBTITLE_COL)
		list.add_child(empty)

	# (c) Footer: campaign progress + a primary DEPLOY + a QUICK START.
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 14)
	column.add_child(footer)

	# Campaign progress — "Battles cleared: X / N" — read from the Campaign autoload (single
	# source of truth), so the lobby always shows how far through the legend the player is.
	var progress := Label.new()
	progress.text = _progress_text()
	progress.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	progress.add_theme_font_size_override("font_size", 14)
	progress.add_theme_color_override("font_color", BADGE_CLEARED_COL)
	footer.add_child(progress)

	var hint := Label.new()
	hint.text = HINT_TEXT
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", SUBTITLE_COL)
	footer.add_child(hint)

	var quick := Button.new()
	quick.text = "QUICK START"
	quick.custom_minimum_size = Vector2(160, 52)
	quick.focus_mode = Control.FOCUS_NONE
	quick.add_theme_stylebox_override("normal", _flat(QUICK_BG, CARD_BORDER))
	quick.add_theme_stylebox_override("hover", _flat(QUICK_BG_HOVER, CARD_BORDER_SEL))
	quick.add_theme_stylebox_override("pressed", _flat(QUICK_BG_HOVER, CARD_BORDER_SEL))
	quick.add_theme_color_override("font_color", BTN_TEXT_COL)
	quick.add_theme_font_size_override("font_size", 17)
	quick.pressed.connect(_on_quick_start)
	footer.add_child(quick)

	var deploy := Button.new()
	deploy.text = "DEPLOY"
	deploy.custom_minimum_size = Vector2(190, 52)
	deploy.focus_mode = Control.FOCUS_NONE
	deploy.add_theme_stylebox_override("normal", _flat(DEPLOY_BG, CARD_BORDER_SEL))
	deploy.add_theme_stylebox_override("hover", _flat(DEPLOY_BG_HOVER, CARD_BORDER_SEL))
	deploy.add_theme_stylebox_override("pressed", _flat(DEPLOY_BG_HOVER, CARD_BORDER_SEL))
	deploy.add_theme_color_override("font_color", BTN_TEXT_COL)
	deploy.add_theme_font_size_override("font_size", 19)
	deploy.pressed.connect(_launch)
	footer.add_child(deploy)

func _make_header(section: String) -> Label:
	var hdr := Label.new()
	hdr.text = _section_label(section)
	hdr.add_theme_font_size_override("font_size", 15)
	hdr.add_theme_color_override("font_color", HEADER_COL)
	# A little breathing room above each section (except the very first).
	hdr.add_theme_constant_override("line_spacing", 4)
	return hdr

func _make_card(idx: int) -> Button:
	var e: Dictionary = entries[idx]
	var path: String = e["path"]
	var card := StageCard.new()
	card.setup(String(e["title"]), _section_tag(e["section"]), _badge_for(path), _palette)
	card.pressed.connect(_on_card_pressed.bind(idx))
	card.focus_entered.connect(_on_card_focused.bind(idx))
	return card

## LOCKED / CLEARED / NEW for a battle path, read from Campaign (the single source of progress).
func _badge_for(path: String) -> String:
	var camp = _campaign()
	if camp == null:
		return ""
	if not camp.is_unlocked(path):
		return StageCard.BADGE_LOCKED
	if camp.is_cleared(path):
		return StageCard.BADGE_CLEARED
	return StageCard.BADGE_NEW

func _section_label(section: String) -> String:
	var camp = _campaign()
	if camp != null and camp.SECTION_LABELS.has(section):
		return String(camp.SECTION_LABELS[section])
	return String(SECTION_LABELS.get(section, ""))

func _section_tag(section: String) -> String:
	return String(SECTION_TAGS.get(section, ""))

func _campaign():
	var tree := get_tree()
	if tree and tree.root and tree.root.has_node("Campaign"):
		return tree.root.get_node("Campaign")
	if typeof(Campaign) != TYPE_NIL:
		return Campaign
	return null

## "Battles cleared: X / N" from the Campaign autoload (single source of progress). Falls back to
## a 0/entry-count line if the autoload is somehow absent, so the footer is never blank.
func _progress_text() -> String:
	var camp = _campaign()
	if camp != null and camp.has_method("cleared_count") and camp.has_method("total"):
		return "Battles cleared: %d / %d" % [camp.cleared_count(), camp.total()]
	return "Battles cleared: 0 / %d" % entries.size()

# --- Theme (shared Arthurian styling for the whole tree) ---------------------

func _build_theme() -> Theme:
	_sb_card_sel = _flat(CARD_BG_SEL, CARD_BORDER_SEL)
	_sb_card_rest = _flat(CARD_BG, CARD_BORDER)
	var theme := Theme.new()
	# StageCards are Buttons; give the Button type its card look so every card matches.
	theme.set_stylebox("normal", "Button", _sb_card_rest)
	theme.set_stylebox("hover", "Button", _flat(CARD_BG_HOVER, CARD_BORDER))
	theme.set_stylebox("pressed", "Button", _sb_card_sel)
	theme.set_stylebox("focus", "Button", _sb_card_sel)
	theme.set_color("font_color", "Button", CARD_TITLE_COL)
	return theme

## A rounded, bordered StyleBoxFlat in `fill` with a `border` edge — the card / button skin.
func _flat(fill: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	return sb

# --- selection / focus sync --------------------------------------------------

## Restyle every card so only `selected` reads as chosen, and keep the GUI focus + scroll on it.
func _refresh_selection() -> void:
	if entries.is_empty():
		return
	selected = clampi(selected, 0, entries.size() - 1)
	var i := 0
	while i < _cards.size():
		var card = _cards[i]
		if card != null:
			_style_card(card, i == selected)
		i += 1
	var sel_card = _cards[selected] if selected < _cards.size() else null
	if sel_card != null:
		if not sel_card.has_focus():
			sel_card.grab_focus()
		_scroll_to(sel_card)

## Paint a card as selected (blood-red, bright border) or resting (dim slate). The two looks are
## static, so reuse the cached StyleBoxFlats instead of allocating fresh ones every nav keypress.
func _style_card(card: Button, is_sel: bool) -> void:
	card.add_theme_stylebox_override("normal", _sb_card_sel if is_sel else _sb_card_rest)

## Keep the selected card visible inside the ScrollContainer (manual ensure-visible; cheap).
## Skipped until the card has been laid out (size.y > 0) — on the first _ready-time call the
## container hasn't sorted yet, so positions are 0; the next nav after layout scrolls correctly.
func _scroll_to(card: Control) -> void:
	if _scroll == null or not is_instance_valid(card) or card.size.y <= 0.0:
		return
	var top := int(card.position.y)
	var bottom := top + int(card.size.y)
	var view_top := _scroll.scroll_vertical
	var view_h := int(_scroll.size.y)
	if top < view_top:
		_scroll.scroll_vertical = top
	elif bottom > view_top + view_h:
		_scroll.scroll_vertical = bottom - view_h

# --- input -------------------------------------------------------------------

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
	elif event is InputEventScreenTouch and event.pressed:
		# Phones (emulate_mouse_from_touch is off): the cards' own `pressed` doesn't fire from raw
		# touch, so map the tap to a card here. Same select / select-again-to-launch as the mouse.
		var hit := _card_at(event.position)
		if hit >= 0:
			if hit == selected:
				_launch()
			else:
				selected = hit
				_refresh_selection()
			_consume()

## Mark the event handled. We're a CanvasLayer (no Control.accept_event), so stop propagation via
## the viewport — guarded for the headless test, which calls `_input` on an instance outside the tree.
func _consume() -> void:
	var vp := get_viewport()
	if vp:
		vp.set_input_as_handled()

func _is_enter(event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed and not event.echo:
		return event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER
	return false

## Move the selection by `dir`, wrapping at the ends. Public so the headless test can drive nav
## without synthesising key events. Only ever lands on a real entry — headers are not entries.
func _move(dir: int) -> void:
	if entries.is_empty():
		return
	# Keyboard/gamepad nav is a deliberate move, not the select-half of a mouse tap — clear any
	# stale select-consume flag so a later Space/Enter on this card can't be wrongly swallowed.
	_select_consumed_press = false
	selected = wrapi(selected + dir, 0, entries.size())
	_refresh_selection()

## The path of the currently-highlighted battle, or "" if there are none.
func selected_path() -> String:
	if selected < 0 or selected >= entries.size():
		return ""
	return entries[selected]["path"]

## Launch the highlighted battle. Guarded again here so a stale/empty selection can never hand
## the scene change an invalid path. Routes through the shared scene-fade (Transition autoload)
## when present, else a plain hard cut so a build / headless run without it still launches.
func _launch() -> void:
	var path := selected_path()
	if path == "" or not ResourceLoader.exists(path):
		return
	var tr := get_node_or_null("/root/Transition")
	if tr:
		tr.change_scene(path)
	else:
		get_tree().change_scene_to_file(path)

## QUICK START: jump into the first UNLOCKED battle (or just the first entry if none report lock
## state). Falls back to the current selection so the button is never a no-op.
func _on_quick_start() -> void:
	var camp = _campaign()
	var i := 0
	while i < entries.size():
		var path: String = entries[i]["path"]
		if camp == null or camp.is_unlocked(path):
			selected = i
			_refresh_selection()
			_launch()
			return
		i += 1
	_launch()

# --- card callbacks ----------------------------------------------------------

## Tap / Space / Enter on a card. A first MOUSE-click on an unselected card grabs focus first
## (`focus_entered` already moved `selected` here and flagged `_select_consumed_press`), so that
## click only SELECTS — we swallow the press. A click / Space on the already-selected card (no
## flag) deploys. This is the tap-to-select / tap-again-to-launch contract on mouse + keyboard.
func _on_card_pressed(idx: int) -> void:
	if _select_consumed_press:
		_select_consumed_press = false
		return
	if idx == selected:
		_launch()
	else:
		selected = idx
		_refresh_selection()

## Mouse hover / keyboard focus landing on a card keeps `selected` in lock-step with the GUI focus
## (so DEPLOY and the launch path always act on what the player sees highlighted). When a click
## moves focus to a NEW card, mark that the imminent `pressed` is just the select half of the tap.
func _on_card_focused(idx: int) -> void:
	if idx != selected:
		selected = idx
		_select_consumed_press = true
		_refresh_selection()

## Which entry index the point `p` falls on, or -1. Used for the raw-touch path.
func _card_at(p: Vector2) -> int:
	var i := 0
	while i < _cards.size():
		var card = _cards[i]
		if card != null and is_instance_valid(card):
			var r := Rect2(card.global_position, card.size)
			if r.has_point(p):
				return i
		i += 1
	return -1
