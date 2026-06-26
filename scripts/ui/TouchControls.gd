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
##   - RESTART button      → reloads the scene (the mobile stand-in for the `R` key).
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
var _menu_c := Vector2.ZERO      ## MENU button — back to the stage select (the mobile way to leave a battle)
const SLAM_R := 56.0
const SPIN_R := 48.0
const RESET_R := 28.0
const MUSOU_R := 50.0
const MENU_R := 30.0
const STAGE_SELECT := "res://scenes/ui/StageSelect.tscn"

func _ready() -> void:
	add_to_group("touch_controls")
	mouse_filter = Control.MOUSE_FILTER_IGNORE   # never eat GUI mouse; we read raw touch in _input
	set_anchors_preset(Control.PRESET_FULL_RECT)
	active_ui = force_on or DisplayServer.is_touchscreen_available()
	visible = active_ui
	resized.connect(_layout)
	_layout()

## Lay the buttons out against the current screen corners (logical canvas coords).
func _layout() -> void:
	_vp = get_viewport_rect().size
	_slam_c = Vector2(_vp.x - 96.0, _vp.y - 100.0)    # bottom-right thumb
	_spin_c = Vector2(_vp.x - 222.0, _vp.y - 78.0)    # just left of SLAM
	_reset_c = Vector2(_vp.x - 52.0, 52.0)            # top-right (mostly for after win/lose)
	_musou_c = Vector2(_vp.x - 110.0, _vp.y - 212.0)  # above the SLAM/SPIN cluster
	_menu_c = Vector2(56.0, 52.0)                      # top-left: back to the battle menu
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
	queue_redraw()

## A finger went down at p: claim a button if it's on one, else start a floating stick
## (left half = move, right half = aim/swing). Buttons win the hit-test (they sit in the
## right-stick zone), and we keep at most one stick per side.
func _press(index: int, p: Vector2) -> void:
	if p.distance_to(_reset_c) <= RESET_R:
		_fingers[index] = {"role": "reset"}
		get_tree().reload_current_scene()
		return
	if p.distance_to(_slam_c) <= SLAM_R:
		_fingers[index] = {"role": "slam"}
		Input.action_press("slam")
		queue_redraw()
		return
	if p.distance_to(_spin_c) <= SPIN_R:
		_fingers[index] = {"role": "spin"}
		Input.action_press("spin")
		queue_redraw()
		return
	if p.distance_to(_musou_c) <= MUSOU_R:
		_fingers[index] = {"role": "musou"}
		Input.action_press("musou")   # Arthur only fires when the gauge is full; a premature tap is safely ignored
		queue_redraw()
		return
	if p.distance_to(_menu_c) <= MENU_R:
		# Back to the stage select — the mobile way to leave a battle and pick another.
		# Open the in-battle pause overlay (Resume / Restart / Return to Lobby) — the mobile
		# equivalent of pressing Escape. Falls back to the stage select on any screen with no
		# pause menu, so the MENU button always does something.
		var pm := get_tree().get_first_node_in_group("pause_menu")
		if pm and pm.has_method("open"):
			pm.open()
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
	if _fingers.is_empty():
		# Faint discoverability hints when nothing is held.
		_draw_hint(Vector2(_vp.x * 0.16, _vp.y - 56.0), "MOVE")
		_draw_hint(Vector2(_vp.x * 0.56, _vp.y - 56.0), "AIM · circle to SWING")
	_draw_button(_slam_c, SLAM_R, "SLAM", _has_role("slam"), Color(0.92, 0.42, 0.3))
	_draw_button(_spin_c, SPIN_R, "SPIN", _has_role("spin"), Color(0.42, 0.62, 0.95))
	_draw_button(_musou_c, MUSOU_R, "ULT", _has_role("musou"), Color(1.0, 0.84, 0.3))
	_draw_button(_reset_c, RESET_R, "R", false, Color(0.72, 0.72, 0.78))
	_draw_button(_menu_c, MENU_R, "MENU", false, Color(0.66, 0.74, 0.7))
	for index in _fingers:
		var f: Dictionary = _fingers[index]
		if f.role == "move":
			_draw_stick(f.base, f.cur, Color(0.55, 0.85, 0.5))
		elif f.role == "aim":
			_draw_stick(f.base, f.cur, Color(1.0, 0.6, 0.3))

func _draw_stick(base: Vector2, cur: Vector2, col: Color) -> void:
	draw_circle(base, STICK_RADIUS, Color(0.1, 0.1, 0.12, 0.28))
	draw_arc(base, STICK_RADIUS, 0.0, TAU, 40, Color(col, 0.5), 3.0)
	draw_circle(cur, KNOB_R, Color(col, 0.55))
	draw_arc(cur, KNOB_R, 0.0, TAU, 28, Color(col, 0.95), 3.0)

func _draw_button(c: Vector2, r: float, label: String, pressed: bool, col: Color) -> void:
	draw_circle(c, r, Color(col, 0.55 if pressed else 0.28))
	draw_arc(c, r, 0.0, TAU, 32, Color(col, 0.9), 3.0)
	var font := get_theme_default_font()
	if font:
		var fs := 20
		var sz := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		draw_string(font, c + Vector2(-sz.x * 0.5, fs * 0.35), label,
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 0.92))

func _draw_hint(pos: Vector2, text: String) -> void:
	var font := get_theme_default_font()
	if font:
		draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1, 1, 1, 0.22))
