class_name TouchControls
extends Control
## On-screen touch controls so the heavy-stone game is playable on a phone.
##
## This is a REUSABLE module: it lives inside the HUD, so every level that uses the
## HUD (and every future one) gets mobile controls for free. It deliberately reuses
## the EXISTING input model instead of adding a parallel one:
##
##   - LEFT virtual stick  → an analog movement vector (`move_vec`), read by Arthur.
##   - RIGHT virtual stick → it BOTH aims the stone (its angle is the aim target,
##     read by Arthur) AND presses the existing `attack` action. Because the swing is
##     "drag the cursor AROUND Arthur", *circling the right thumb whips the stone* —
##     the exact same mechanic, no weapon code changed. Holding it still just follows.
##   - SLAM / SPIN buttons → press the existing `slam` / `spin` actions.
##   - ULT button          → HOLD to charge the musou beam, RELEASE to fire (the `musou`
##     action). A gold sweep around the button shows the live charge; the button PULSES
##     once the gauge is full (= beam ready).
##   - RESTART button      → reloads the scene (the mobile stand-in for the `R` key).
##   - MENU button         → opens the pause overlay / returns to the lobby.
##
## Desktop is untouched: the UI stays hidden unless a touchscreen is present (or a real
## screen touch arrives — a belt-and-braces reveal in case detection misfires), and it
## only ever reads `InputEventScreen*`, never the mouse or keyboard.

## Show even without a touchscreen — for trying the layout in the editor / headless tests.
@export var force_on := false

## True while the touch UI owns input (a touchscreen device). Read by Arthur + the HUD
## so they prefer touch over the (stale-on-mobile) mouse, and stay identical on desktop.
var active_ui := false
## Left-stick movement, deadzoned + remapped, length 0..1. Arthur folds it into his steer.
var move_vec := Vector2.ZERO
## Right stick deflected past the deadzone → it's aiming (and the swing is engaged).
var aim_active := false
## Right-stick direction in radians — Arthur feeds it to the weapon as the aim target.
var aim_angle := 0.0

const STICK_RADIUS := 92.0   ## max knob travel from the (floating) base, in pixels
const DEADZONE := 0.18       ## fraction of the radius before a stick registers
const KNOB_R := 38.0

var _vp := Vector2(1280, 720)    ## logical viewport size (drives screen-corner layout)
var _fingers := {}               ## finger index -> {role:String, base:Vector2, cur:Vector2}
var _slam_c := Vector2.ZERO      ## button centres + radii, recomputed on resize
var _spin_c := Vector2.ZERO
var _reset_c := Vector2.ZERO
var _musou_c := Vector2.ZERO     ## MUSOU ultimate (ULT) button — phone access to the Q ultimate
var _menu_c := Vector2.ZERO      ## MENU button — open the pause overlay / leave a battle
## Live button radii — the base constants (below) scaled by `_ui_scale` so thumb targets stay
## ~44px on small phones. Derived in `_layout()` (which runs in `_ready`); the hit-test + draw
## both read these, so the touch zone always matches the art. Init 0 like the centres above.
var _slam_r := 0.0
var _spin_r := 0.0
var _reset_r := 0.0
var _musou_r := 0.0
var _menu_r := 0.0
var _ui_scale := 1.0             ## 1.0 on a tall canvas, up to ~1.35 on a short one (bigger targets)

## Discoverability hint fade: holds full then fades over a few seconds so the "circle to SWING"
## teach shows up front but never lingers. Draw-only — gameplay is unaffected.
var _hint_alpha := 1.0
const HINT_HOLD := 4.0           ## seconds the hints stay solid before they begin to fade
const HINT_FADE := 3.0           ## seconds to fade from solid to gone
var _hint_t := 0.0               ## elapsed seconds since the UI armed
var _arrow_t := 0.0              ## free-running phase for the rotating "circle me" arrow on the AIM knob

## Arthur, cached from the "player" group so _draw can read the live musou charge for the ULT ring.
var _player: Node = null

const SLAM_R := 56.0
const SPIN_R := 48.0
const RESET_R := 42.0            ## bumped up for thumbs (was 28) — top-right, clear of the HUD
const MUSOU_R := 50.0
const MENU_R := 42.0             ## bumped up for thumbs (was 30) — top-right beside RESET, off the HUD
const STAGE_SELECT := "res://scenes/ui/Worldmap.tscn"   # the Map of Britain (lobby + journey hub)
## The top-left HUD column (HEALTH/STAMINA/… bars + labels) lives here; the MENU/RESET buttons
## are kept OUT of this box so they never sit on the readouts. Matches Hud.gd's BAR_X/BAR_W/BAR_TOP.
const HUD_BAR_RIGHT := 342.0     ## BAR_X(30) + BAR_W(312)
const HUD_BAR_BOTTOM := 82.0     ## a little below the first (HEALTH) bar + its label

func _ready() -> void:
	add_to_group("touch_controls")
	mouse_filter = Control.MOUSE_FILTER_IGNORE   # never eat GUI mouse; we read raw touch in _input
	set_anchors_preset(Control.PRESET_FULL_RECT)
	active_ui = force_on or DisplayServer.is_touchscreen_available()
	visible = active_ui
	set_process(active_ui)   # only spend a frame on hint/charge animation when the touch UI is live
	resized.connect(_layout)
	_layout()

func _process(delta: float) -> void:
	# Drive the teach-hint fade and the rotating-arrow phase. Cheap, draw-only, phone-only
	# (process is disabled unless the touch UI is active). A redraw is requested only while
	# something is still animating so an idle screen costs nothing.
	_arrow_t += delta
	var redraw := false
	if _hint_alpha > 0.0:
		_hint_t += delta
		var a := 1.0
		if _hint_t > HINT_HOLD:
			a = clampf(1.0 - (_hint_t - HINT_HOLD) / HINT_FADE, 0.0, 1.0)
		if not is_equal_approx(a, _hint_alpha):
			_hint_alpha = a
			redraw = true
	# While the ULT finger is held, the gauge is full (pulse), or the AIM teach-arrow is up,
	# keep animating; an otherwise-idle screen requests no redraw and costs nothing.
	if _has_role("musou") or _player_musou_ready() or _has_role("aim"):
		redraw = true
	if redraw:
		queue_redraw()

## Lay the buttons out against the current screen corners (logical canvas coords). A short
## screen scales the button radii up (toward ~1.35x) so thumb targets clear ~44px even on a
## phone where 720px-tall art would otherwise shrink the touch zones.
func _layout() -> void:
	_vp = get_viewport_rect().size
	# Short-screen scale: tall canvases stay 1.0; a 720px (or shorter) canvas grows targets.
	_ui_scale = clampf(_vp.y / 720.0, 1.0, 1.35)
	_slam_r = SLAM_R * _ui_scale
	_spin_r = SPIN_R * _ui_scale
	_reset_r = RESET_R * _ui_scale
	_musou_r = MUSOU_R * _ui_scale
	_menu_r = MENU_R * _ui_scale
	# Bottom corners stay reachable for the thumbs: SLAM bottom-right, SPIN just left, ULT above.
	_slam_c = Vector2(_vp.x - 96.0, _vp.y - 100.0)    # bottom-right thumb
	_spin_c = Vector2(_vp.x - 222.0, _vp.y - 78.0)    # just left of SLAM
	_musou_c = Vector2(_vp.x - 110.0, _vp.y - 212.0)  # above the SLAM/SPIN cluster
	# Top-right utility cluster, OFF the top-left HUD bars: RESET in the corner, MENU just left of it.
	_reset_c = Vector2(_vp.x - 52.0, 52.0)
	_menu_c = Vector2(_vp.x - 52.0 - _reset_r - _menu_r - 16.0, 52.0)
	queue_redraw()

# --- input ------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and not active_ui:
			_reveal()   # a real touch on a device we misdetected — turn the UI on
		if not active_ui:
			return
		var p: Vector2 = make_input_local(event).position
		if event.pressed:
			_press(event.index, p)
		else:
			_release(event.index)
		accept_event()
	elif event is InputEventScreenDrag:
		if not active_ui:
			return
		_drag(event.index, make_input_local(event).position)
		accept_event()

func _reveal() -> void:
	active_ui = true
	visible = true
	set_process(true)
	queue_redraw()

## Cached Arthur from the "player" group, refreshed lazily if the level reloaded under us.
func _arthur() -> Node:
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
	return _player

## True when Arthur's musou gauge is full — the beam is READY, so the ULT button pulses.
func _player_musou_ready() -> bool:
	var a := _arthur()
	if not is_instance_valid(a):
		return false
	return a.musou >= a.max_musou

## A short haptic pulse, PHONE-ONLY and web/single-thread-safe (a clean no-op on desktop).
## Public-ish so other scripts may buzz through the "touch_controls" group. Guarded so it
## never touches the vibrate API unless we're actually the active touch UI on a mobile build.
func _haptic(ms: int) -> void:
	if active_ui and OS.has_feature("mobile"):
		Input.vibrate_handheld(ms)

## A finger went down at p: claim a button if it's on one, else start a floating stick
## (left half = move, right half = aim/swing). Buttons win the hit-test (they sit in the
## right-stick zone), and we keep at most one stick per side.
func _press(index: int, p: Vector2) -> void:
	if p.distance_to(_reset_c) <= _reset_r:
		_fingers[index] = {"role": "reset"}
		get_tree().reload_current_scene()
		return
	if p.distance_to(_slam_c) <= _slam_r:
		_fingers[index] = {"role": "slam"}
		Input.action_press("slam")
		_haptic(12)
		queue_redraw()
		return
	if p.distance_to(_spin_c) <= _spin_r:
		_fingers[index] = {"role": "spin"}
		Input.action_press("spin")
		_haptic(12)
		queue_redraw()
		return
	if p.distance_to(_musou_c) <= _musou_r:
		_fingers[index] = {"role": "musou"}
		Input.action_press("musou")   # Arthur only fires when the gauge is full; a premature tap is safely ignored
		_haptic(16)
		queue_redraw()
		return
	if p.distance_to(_menu_c) <= _menu_r:
		# Open the in-battle pause overlay (Resume / Restart / Return to Lobby) — the mobile
		# equivalent of pressing Escape. Falls back to the stage select on any screen with no
		# pause menu, so the MENU button always does something.
		var pm := get_tree().get_first_node_in_group("pause_menu")
		if pm and pm.has_method("open"):
			pm.open()
		else:
			# No pause overlay here — fall back to the lobby, through the shared scene-fade when
			# the Transition autoload is present, else a hard cut so this still always navigates.
			var tr := get_node_or_null("/root/Transition")
			if tr:
				tr.change_scene(STAGE_SELECT)
			else:
				get_tree().change_scene_to_file(STAGE_SELECT)
		return
	if p.x < _vp.x * 0.5:
		if not _has_role("move"):
			_fingers[index] = {"role": "move", "base": p, "cur": p}
	else:
		if not _has_role("aim"):
			_fingers[index] = {"role": "aim", "base": p, "cur": p}
	queue_redraw()

func _drag(index: int, p: Vector2) -> void:
	if not _fingers.has(index):
		return
	var f: Dictionary = _fingers[index]
	if f.role == "move" or f.role == "aim":
		f.cur = p
		_recompute()
		queue_redraw()

func _release(index: int) -> void:
	if not _fingers.has(index):
		return
	var role: String = _fingers[index].role
	_fingers.erase(index)
	match role:
		"slam":
			Input.action_release("slam")
		"spin":
			Input.action_release("spin")
		"musou":
			Input.action_release("musou")
		"move", "aim":
			_recompute()
	queue_redraw()

## Re-derive the analog outputs from whatever sticks are currently held. The right stick
## presses/releases the `attack` action on its deadzone edge, so engaging it puts the
## weapon into swing mode (and circling it then whips the head — exactly like the mouse).
func _recompute() -> void:
	move_vec = Vector2.ZERO
	var had_aim := aim_active
	aim_active = false
	for index in _fingers:
		var f: Dictionary = _fingers[index]
		if f.role != "move" and f.role != "aim":
			continue
		var off: Vector2 = (f.cur - f.base).limit_length(STICK_RADIUS)
		f.cur = f.base + off   # pin the drawn knob to the ring
		var mag := off.length() / STICK_RADIUS
		if f.role == "move":
			if mag >= DEADZONE:
				# Remap [deadzone,1] → [0,1] so there's no jump as you cross the deadzone.
				move_vec = off.normalized() * clampf((mag - DEADZONE) / (1.0 - DEADZONE), 0.0, 1.0)
		else:
			if mag >= DEADZONE:
				aim_active = true
				aim_angle = off.angle()
	if aim_active and not had_aim:
		Input.action_press("attack")
	elif had_aim and not aim_active:
		Input.action_release("attack")

func _has_role(role: String) -> bool:
	for index in _fingers:
		if _fingers[index].role == role:
			return true
	return false

# --- drawing (all in code, like the rest of the prototype) ------------------

func _draw() -> void:
	if not active_ui:
		return
	if _fingers.is_empty() and _hint_alpha > 0.0:
		# Faint, fading discoverability hints when nothing is held (teach-then-hide).
		_draw_hint(Vector2(_vp.x * 0.16, _vp.y - 56.0), "MOVE")
		_draw_hint(Vector2(_vp.x * 0.56, _vp.y - 56.0), "AIM · circle to SWING")
	_draw_button(_slam_c, _slam_r, "SLAM", _has_role("slam"), Color(0.92, 0.42, 0.3))
	_draw_button(_spin_c, _spin_r, "SPIN", _has_role("spin"), Color(0.42, 0.62, 0.95))
	_draw_musou_button()
	_draw_button(_reset_c, _reset_r, "R", false, Color(0.72, 0.72, 0.78))
	_draw_button(_menu_c, _menu_r, "MENU", false, Color(0.66, 0.74, 0.7))
	for index in _fingers:
		var f: Dictionary = _fingers[index]
		if f.role == "move":
			_draw_stick(f.base, f.cur, Color(0.55, 0.85, 0.5), false)
		elif f.role == "aim":
			_draw_stick(f.base, f.cur, Color(1.0, 0.6, 0.3), true)

## The ULT (musou) button, with a GOLD charge sweep showing how much beam HOLDING has banked,
## and a soft outer PULSE while the gauge is full (= beam ready to fire).
func _draw_musou_button() -> void:
	var held := _has_role("musou")
	var gold := Color(1.0, 0.84, 0.3)
	# Ready-pulse: a breathing ring outside the button so a full gauge reads as "fire me".
	if _player_musou_ready():
		var pulse := 0.5 + 0.5 * sin(_arrow_t * 4.0)
		draw_arc(_musou_c, _musou_r + 6.0 + pulse * 6.0, 0.0, TAU, 40,
			Color(gold, 0.25 + 0.45 * pulse), 3.0)
	_draw_button(_musou_c, _musou_r, "ULT", held, gold)
	# Live charge sweep: while the finger holds the ULT, fill a gold arc for the charged fraction.
	if held:
		var a := _arthur()
		if is_instance_valid(a):
			var frac := clampf(a._musou_charge / maxf(a.MUSOU_CHARGE_MAX, 0.001), 0.0, 1.0)
			if frac > 0.0:
				var start := -PI * 0.5
				draw_arc(_musou_c, _musou_r + 4.0, start, start + TAU * frac, 48,
					Color(gold, 0.95), 5.0)

func _draw_stick(base: Vector2, cur: Vector2, col: Color, is_aim: bool) -> void:
	draw_circle(base, STICK_RADIUS, Color(0.1, 0.1, 0.12, 0.28))
	draw_arc(base, STICK_RADIUS, 0.0, TAU, 40, Color(col, 0.5), 3.0)
	draw_circle(cur, KNOB_R, Color(col, 0.55))
	draw_arc(cur, KNOB_R, 0.0, TAU, 28, Color(col, 0.95), 3.0)
	# When the AIM stick is held but barely deflected, draw a faint rotating curved-arrow on the
	# knob teaching the "circle your thumb to SWING" verb — fades out as soon as you start circling.
	if is_aim:
		var defl := base.distance_to(cur) / STICK_RADIUS
		var teach := clampf(1.0 - defl / DEADZONE, 0.0, 1.0)   # full when still, gone once you circle
		if teach > 0.01:
			_draw_circle_arrow(cur, KNOB_R * 0.62, Color(col, 0.5 * teach))

## A small curved arrow that sweeps around `c`, hinting "circle the thumb". Pure decoration.
func _draw_circle_arrow(c: Vector2, r: float, col: Color) -> void:
	var a0 := _arrow_t * 2.2
	var span := TAU * 0.62
	draw_arc(c, r, a0, a0 + span, 24, col, 3.0)
	# Arrowhead at the leading (CCW) end of the sweep.
	var tip := c + Vector2(cos(a0 + span), sin(a0 + span)) * r
	var tang := a0 + span + PI * 0.5   # tangent direction at the tip
	var head := 6.0
	var p1 := tip + Vector2(cos(tang + 2.4), sin(tang + 2.4)) * head
	var p2 := tip + Vector2(cos(tang - 2.4), sin(tang - 2.4)) * head
	draw_line(tip, p1, col, 3.0)
	draw_line(tip, p2, col, 3.0)

func _draw_button(c: Vector2, r: float, label: String, pressed: bool, col: Color) -> void:
	draw_circle(c, r, Color(col, 0.55 if pressed else 0.28))
	draw_arc(c, r, 0.0, TAU, 32, Color(col, 0.9), 3.0)
	var font := get_theme_default_font()
	if font:
		var fs := int(round(20.0 * _ui_scale))
		var sz := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		draw_string(font, c + Vector2(-sz.x * 0.5, fs * 0.35), label,
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 0.92))

func _draw_hint(pos: Vector2, text: String) -> void:
	var font := get_theme_default_font()
	if font:
		draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1, 1, 1, 0.22 * _hint_alpha))
