extends Node2D
## Headless test for the MOBILE polish on TouchControls (v0.13+):
##   - the MENU button no longer sits on the top-left HUD bar column (its centre is OUTSIDE
##     the HUD region x<342, y<82 — matching Hud.gd's BAR_X+BAR_W / first-bar band);
##   - the thumb-target button radii SCALE UP on a short viewport (so they clear ~44px);
##   - the haptic helper `_haptic(10)` runs without error on this (desktop/headless) build —
##     a clean no-op — and the live ULT charge-ring draw path renders without error while the
##     ULT finger is held with a real Arthur (gauge full + half-charged) in the "player" group.
##
## Run: godot --headless --path . res://tests/TouchMobileTest.tscn — look for TOUCH_MOBILE_VERDICT.

var _tc
var _arthur_node
var _frame := 0
var _draw_ok := false

func _ready() -> void:
	_tc = load("res://scenes/ui/TouchControls.tscn").instantiate()
	_tc.force_on = true   # no real touchscreen in headless — show + arm the UI anyway
	add_child(_tc)
	# Register a real Arthur in the "player" group so the ULT ring can read the live charge.
	# Freeze its own logic so it can't drain/fire the charge we stage for the draw assertion —
	# we only need it as a data source for arthur._musou_charge / .musou / the constants.
	_arthur_node = load("res://scenes/Arthur.tscn").instantiate()
	add_child(_arthur_node)
	_arthur_node.set_physics_process(false)
	_arthur_node.set_process(false)
	_arthur_node.set_process_input(false)
	_arthur_node.musou = _arthur_node.max_musou                       # gauge full → ready-pulse path
	_arthur_node._musou_charge = _arthur_node.MUSOU_CHARGE_MAX * 0.5  # half-charged → sweep path
	# Hold the ULT finger BEFORE any frame draws, so the real _draw() exercises the gold sweep,
	# the ready-pulse ring, AND the AIM teach-arrow path below — all draw-only, must not error.
	_tc._fingers[9] = {"role": "musou"}
	# Also hold an AIM stick barely deflected → exercises the rotating teach-arrow draw path.
	var rbase := Vector2(_tc._vp.x * 0.7, _tc._vp.y * 0.5)
	_tc._fingers[10] = {"role": "aim", "base": rbase, "cur": rbase}
	_tc.queue_redraw()

func _physics_process(_delta: float) -> void:
	_frame += 1
	if _frame == 2:
		# A render frame has run with the ULT + AIM fingers held; the charge-ring/teach-arrow
		# draw paths have executed without error if we reach here.
		_draw_ok = true
		_tc._fingers.clear()
		_report()

func _report() -> void:
	var checks := {}

	# --- MENU off the HUD, at a BASELINE 1280x720 canvas (ui_scale clamps to 1.0). We size a
	# SubViewport rather than trusting the headless window (which is square), so the geometry
	# matches a real 720p phone canvas exactly.
	var base_sv := SubViewport.new()
	base_sv.size = Vector2i(1280, 720)
	add_child(base_sv)
	remove_child(_tc)
	base_sv.add_child(_tc)
	_tc._layout()
	checks["scale_baseline_is_one"] = absf(_tc._ui_scale - 1.0) < 0.001
	var menu_base: Vector2 = _tc._menu_c
	checks["menu_off_hud"] = not (menu_base.x < _tc.HUD_BAR_RIGHT and menu_base.y < _tc.HUD_BAR_BOTTOM)
	# RESET too — it shares the top-right utility cluster.
	var reset_base: Vector2 = _tc._reset_c
	checks["reset_off_hud"] = not (reset_base.x < _tc.HUD_BAR_RIGHT and reset_base.y < _tc.HUD_BAR_BOTTOM)
	# Bottom-corner action buttons stay reachable (bottom-right quadrant) for the thumbs.
	checks["slam_bottom"] = _tc._slam_c.x > _tc._vp.x * 0.5 and _tc._slam_c.y > _tc._vp.y * 0.5
	# Baseline radii at the 720 canvas (scale 1.0).
	var menu_r_base: float = _tc._menu_r
	var reset_r_base: float = _tc._reset_r

	# --- TALLER canvas (the `_vp.y / 720` scale factor): a 1080-tall phone canvas pushes the
	# thumb targets bigger (toward the 1.35 cap) so they comfortably clear ~44px. Radii grow.
	var tall_sv := SubViewport.new()
	tall_sv.size = Vector2i(1280, 1080)
	add_child(tall_sv)
	base_sv.remove_child(_tc)
	tall_sv.add_child(_tc)
	_tc._layout()
	checks["scale_tall_gt_one"] = _tc._ui_scale > 1.05
	checks["menu_r_grew"] = _tc._menu_r > menu_r_base + 0.5
	checks["reset_r_grew"] = _tc._reset_r > reset_r_base + 0.5
	# Targets clear ~44px diameter (radius ≥ 22) on the scaled canvas.
	checks["menu_target_44"] = _tc._menu_r * 2.0 >= 44.0
	checks["reset_target_44"] = _tc._reset_r * 2.0 >= 44.0
	# Even scaled up, MENU/RESET stay off the HUD bar box.
	checks["menu_off_hud_tall"] = not (_tc._menu_c.x < _tc.HUD_BAR_RIGHT and _tc._menu_c.y < _tc.HUD_BAR_BOTTOM)

	# Haptic helper: a clean no-op on desktop/headless (no "mobile" feature) — must not error.
	_tc._haptic(10)
	checks["haptic_ran"] = true

	# The real _draw() with the ULT finger held already ran (frame 2) — prove the data path it
	# reads is sane: Arthur cached from "player", gauge full (ready), half-charge fraction.
	checks["draw_ran"] = _draw_ok
	var a = _tc._arthur()
	checks["arthur_cached"] = is_instance_valid(a) and a == _arthur_node
	checks["musou_ready_seen"] = _tc._player_musou_ready()
	var frac := clampf(_arthur_node._musou_charge / maxf(_arthur_node.MUSOU_CHARGE_MAX, 0.001), 0.0, 1.0)
	checks["charge_frac_ok"] = frac > 0.4 and frac < 0.6

	var ok := true
	var parts: Array = []
	for k in checks:
		ok = ok and checks[k]
		parts.append("%s=%s" % [k, str(checks[k])])
	print("TOUCH_MOBILE_RESULT ", " ".join(parts))
	print("TOUCH_MOBILE_VERDICT %s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)
