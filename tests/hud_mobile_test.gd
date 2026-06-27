extends Node2D
## Headless test for the COMPACT phone HUD (token HUD_MOBILE).
##
## Instances the HUD ALONE (a CanvasLayer with its code-drawn bars + labels) and asserts the
## mobile-compacting added by the HUD-mobile pass, WITHOUT a Battlefield:
##   - the compact NARROW layout is genuinely smaller than the desktop defaults (the
##     BAR_W_NARROW / ROW_H_NARROW / BAR_TOP_NARROW / BAR_H_NARROW / CHARGE_H_NARROW
##     consts are all < their *_DESK counterparts);
##   - forcing a NARROW viewport (a short logical height) and calling _apply_scale() actually
##     shrinks the live geometry VARS (BAR_W / ROW_H / BAR_TOP) below the desktop values, and
##     restoring a TALL viewport puts them back to the desktop defaults;
##   - the bar-row LABELS follow the compacted pitch (e.g. the HEALTH label moves up) and pick
##     up a smaller font, and snap back on the desktop layout;
##   - the bars + labels DRAW without error in BOTH layouts (the _draw_bars path runs).
##
## Run: godot --headless --path . res://tests/HudMobileTest.tscn --quit-after 600 — look for HUD_MOBILE_VERDICT.

const HUD := preload("res://scenes/Hud.tscn")

var _hud
var _frame := 0

func _ready() -> void:
	_hud = HUD.instantiate()
	add_child(_hud)

func _physics_process(_delta: float) -> void:
	_frame += 1
	# Let a few frames pass so _ready (the scale + draw-signal hookup) and a draw run.
	if _frame < 4:
		return
	_report()

## Drive a short (phone-landscape) logical viewport, then a tall (desktop) one, then re-run the
## HUD's scale pass. The web build stretches with content_scale_size=1280x720; forcing the root's
## content_scale_size is the headless way to make get_visible_rect().y the value we want (the
## stretch keeps the base height, so a window resize alone can't shrink the LOGICAL height here).
func _force_height(h: int) -> void:
	var root := get_tree().root
	# A wide-aspect window so expand-stretch locks the base HEIGHT (not the width), plus a
	# matching content_scale_size so get_visible_rect().y lands on `h`. Headless's default
	# 64x64 window is taller-than-wide, which would otherwise expand the height instead.
	var win := get_window()
	if win:
		win.size = Vector2i(1280, h)
	root.content_scale_size = Vector2i(1280, h)
	_hud._apply_scale()

func _report() -> void:
	var checks := {}

	var health: Label = _hud.get_node("Root/HealthLabel")

	# 1) The compact NARROW constants are strictly smaller than the desktop defaults.
	checks["narrow_consts_smaller"] = (
		_hud.BAR_W_NARROW < _hud.BAR_W_DESK
		and _hud.ROW_H_NARROW < _hud.ROW_H_DESK
		and _hud.BAR_TOP_NARROW < _hud.BAR_TOP_DESK
		and _hud.BAR_H_NARROW < _hud.BAR_H_DESK
		and _hud.CHARGE_H_NARROW < _hud.CHARGE_H_DESK
		and _hud.LABEL_FS_NARROW < _hud.LABEL_FS_DESK
	)

	# 2) Force a SHORT viewport → _apply_scale must compact the live geometry vars.
	_force_height(584)   # ~ an 854x390 phone's logical height under expand-stretch
	var n_bar_w: float = _hud.BAR_W
	var n_row_h: float = _hud.ROW_H
	var n_bar_top: float = _hud.BAR_TOP
	var n_label_top: float = health.offset_top
	var n_label_fs: int = health.get_theme_font_size("font_size")
	checks["vars_compact_on_narrow"] = (
		n_bar_w <= _hud.BAR_W_DESK
		and n_row_h < _hud.ROW_H_DESK
		and n_bar_top < _hud.BAR_TOP_DESK
		and absf(n_bar_w - _hud.BAR_W_NARROW) < 0.01
		and absf(n_row_h - _hud.ROW_H_NARROW) < 0.01
	)
	# The HEALTH label followed the compacted pitch up (sits higher) + shrank its font.
	checks["label_followed_narrow"] = n_label_top < 22.0 and n_label_fs <= _hud.LABEL_FS_NARROW

	# The compacted bars must DRAW with no error.
	var bars = _hud.get_node_or_null("Root/Bars")
	bars.queue_redraw()
	checks["bars_draw_narrow"] = bars != null

	# 3) Restore a TALL viewport → _apply_scale must return the desktop defaults verbatim.
	_force_height(720)
	checks["vars_desktop_on_tall"] = (
		absf(_hud.BAR_W - _hud.BAR_W_DESK) < 0.01
		and absf(_hud.ROW_H - _hud.ROW_H_DESK) < 0.01
		and absf(_hud.BAR_TOP - _hud.BAR_TOP_DESK) < 0.01
		and absf(_hud.CHARGE_H - _hud.CHARGE_H_DESK) < 0.01
	)
	# The HEALTH label snapped back to its shipped .tscn offset (22) + font (14).
	checks["label_restored_desktop"] = (
		absf(health.offset_top - 22.0) < 0.01
		and health.get_theme_font_size("font_size") == _hud.LABEL_FS_DESK
	)
	bars.queue_redraw()
	checks["bars_draw_desktop"] = bars != null

	# 4) An active TOUCH UI must compact the bars EVEN on a tall viewport (the bar layout shares
	#    one "is this a phone?" predicate with the text/hint compacting — no half-compact HUD).
	var tc = _hud.get_node_or_null("TouchControls")
	if tc:
		tc.active_ui = true   # simulate a touchscreen / a runtime _reveal without a real device
	_force_height(720)        # tall (desktop) viewport, but touch is active
	checks["touch_forces_narrow"] = absf(_hud.BAR_W - _hud.BAR_W_NARROW) < 0.01

	# 5) The ULTIMATE-READY text re-evaluates on a layout pass: fill the gauge while touch is
	#    active → it must drop the "Q" cue and read the short phone form (no stale keyboard hint).
	var musou: Label = _hud.get_node("Root/MusouLabel")
	_hud._on_musou_changed(200.0, 200.0)
	checks["ult_ready_touch_short"] = musou.text == "ULTIMATE  ★ READY"
	# Flip touch OFF and re-run the layout pass → the desktop wording (with "Q") comes back,
	# proving _apply_scale re-picks the ULT text (not only _on_musou_changed).
	if tc:
		tc.active_ui = false
	_force_height(720)
	checks["ult_text_refreshes_on_scale"] = musou.text.find("Q") != -1

	var ok := true
	var parts: Array = []
	for k in checks:
		ok = ok and checks[k]
		parts.append("%s=%s" % [k, str(checks[k])])
	print("HUD_MOBILE_RESULT ", " ".join(parts))
	print("HUD_MOBILE_VERDICT %s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)
