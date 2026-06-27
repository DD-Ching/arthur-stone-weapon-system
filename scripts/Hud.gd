extends CanvasLayer
## In-battle HUD: a tidy left-column of code-drawn status bars (HEALTH, STAMINA,
## ULTIMATE, STONE FLOW) plus a one-line WEAPON read-out, the KO counter, the
## objective line, and a control-hint strip that teaches then fades away.
##
## The bars are NOT image assets — a single `Bars` Control renders every bar in its
## `_draw()` (rounded, bordered, consistent palette) from a small block of remembered
## state. The signal handlers only update that state + `queue_redraw()`; the HUD never
## polls and never reaches into gameplay nodes.
##
## It binds to Arthur (health, stamina, weapon charge, musou) and to the Impact autoload
## (Stone Flow + KO count) via signals. Public API consumed by BattleMap is kept stable:
##   bind(arthur) · set_objective(text) · show_banner(text, color)

@onready var bars: Control = $Root/Bars
@onready var stamina_label: Label = $Root/StaminaLabel
@onready var state_label: Label = $Root/StateLabel
@onready var flow_label: Label = $Root/FlowLabel
@onready var health_label: Label = $Root/HealthLabel
@onready var objective_label: Label = $Root/ObjectiveLabel
@onready var banner_label: Label = $Root/BannerLabel
@onready var ko_label: Label = $Root/KoLabel
@onready var musou_label: Label = $Root/MusouLabel
@onready var hints_label: Label = $Root/Hints

# --- bar geometry (code-drawn, no image assets) ------------------------------
# These are VARS, not consts: _apply_scale() sets them on boot and on every resize. On a
# short (phone-landscape) viewport — or any touchscreen — they shrink so the bar column
# stops eating the short screen. On a wide desktop viewport they take the *_DESK values,
# so the desktop layout stays byte-identical to before this change.
const BAR_X := 30.0          ## left edge of every bar (constant across layouts)
const BAR_R := 6.0           ## corner radius (constant)
var BAR_W := 312.0           ## bar width — compacted on a narrow viewport
var BAR_H := 16.0            ## bar height — compacted on a narrow viewport
var ROW_H := 52.0            ## vertical pitch between rows — compacted on a narrow viewport
var BAR_TOP := 42.0          ## top of the first (HEALTH) bar — compacted on a narrow viewport
var CHARGE_H := 8.0          ## the thin WEAPON-charge sub-bar — compacted on a narrow viewport

# Desktop defaults — the un-compacted look shipped before this change.
const BAR_W_DESK := 312.0
const BAR_H_DESK := 16.0
const ROW_H_DESK := 52.0
const BAR_TOP_DESK := 42.0
const CHARGE_H_DESK := 8.0
const LABEL_FS_DESK := 14       ## bar-row label font size on desktop (matches the .tscn)
const LABEL_GAP_DESK := 20.0    ## how far a bar-row label sits above its bar on desktop

# Narrow (phone) layout — a tighter bar column for the short landscape viewport.
const BAR_W_NARROW := 226.0
const BAR_H_NARROW := 12.0
const ROW_H_NARROW := 38.0
const BAR_TOP_NARROW := 28.0
const CHARGE_H_NARROW := 6.0
const LABEL_FS_NARROW := 12      ## smaller bar-row label font on a phone
const LABEL_GAP_NARROW := 16.0   ## tighter label-above-bar gap on a phone

# Row order — drives the bar Y for each meter (label offsets in the .tscn match this).
const ROW_HEALTH := 0
const ROW_STAMINA := 1
const ROW_MUSOU := 2
const ROW_WEAPON := 3        ## the weapon row carries the thin CHARGE bar
const ROW_FLOW := 4

# --- palette ------------------------------------------------------------------
const COL_TRACK := Color(0.08, 0.09, 0.12, 0.82)   ## the recessed bar track
const COL_BORDER := Color(0.0, 0.0, 0.0, 0.55)     ## a thin dark border frames each bar
const COL_RIM := Color(1.0, 1.0, 1.0, 0.10)        ## a faint top highlight for a beveled read

# Reused StyleBoxFlat instances for the code-drawn bars (rounded + bordered). Built once,
# re-tinted per draw — cheaper than allocating a box every frame, and web-export safe.
var _track_box := StyleBoxFlat.new()
var _fill_box := StyleBoxFlat.new()

# --- remembered state the _draw() reads --------------------------------------
var _health_ratio := 1.0
var _health_col := Color(0.5, 0.85, 0.4)
var _stamina_ratio := 1.0
var _stamina_col := Color(0.35, 0.85, 0.45)
var _musou_ratio := 0.0       ## ultimate gauge fill 0..1 (full = beam READY)
var _musou_col := Color(1.0, 0.84, 0.3)
var _musou_live := false      ## true once the gauge is bound — guards the boot ULTIMATE placeholder
var _flow_ratio := 0.0        ## smoothed flow bar fill
var _flow_target := 0.0
var _charge_ratio := 0.0      ## the weapon swing charge 0..1 (the thin CHARGE sub-bar)

var _flash := 0.0       ## white flash on the stamina bar when a swing fizzles
var _ko_flash := 0.0    ## milestone flash on the KO counter
var _milestone := ""
var _stacks := 0
var _mode := false
var _stamina_base_col := Color(0.35, 0.85, 0.45)   ## the bar's resting colour, re-tinted each frame while low
var _t := 0.0

const STAMINA_LOW := 0.25   ## below this, the stamina bar pulses + desaturates as a low-stamina warning

# --- control-hint fade: teach, then get out of the way -----------------------
const HINTS_HOLD := 6.0      ## seconds the hint strip stays fully lit after the battle starts
const HINTS_FADE := 2.5      ## seconds it then takes to fade out
var _hints_alpha := 1.0      ## current hint-strip opacity, mirrored onto hints_label.modulate.a

# Remembered .tscn label geometry, captured once on boot. The desktop branch of _apply_scale
# restores EXACTLY these (so desktop stays byte-identical, FlowLabel's hand-nudged 224 and
# all), while the narrow branch overrides them with the compact phone column.
var _label_defaults := {}    ## label -> {top, bottom, fs}
var _scale_ready := false    ## true once the defaults are captured (guards an early _apply_scale)

func _ready() -> void:
	_track_box.set_border_width_all(1)   # the thin dark frame around each bar
	if bars:
		bars.draw.connect(_draw_bars)
		bars.queue_redraw()
	# Capture the shipped .tscn label geometry so the desktop branch can restore it exactly.
	_capture_label_defaults()
	# Pick the compact-vs-desktop bar layout, and re-pick it whenever the viewport
	# changes (rotate / resize) — a phone landscape can shrink the logical height.
	var vp := get_viewport()
	if vp:
		vp.size_changed.connect(_apply_scale)
	_apply_scale()
	# On a touchscreen the bottom control-hint strip is redundant (the touch buttons teach
	# the controls) and just crowds the short screen — hide it. Desktop keeps the fading hint.
	if hints_label and _on_touch():
		hints_label.visible = false

## True when this device should use the COMPACT phone layout: a touchscreen is present, or
## a touch UI is active (the in-HUD TouchControls, looked up by group). Reused for the bar
## sizing AND the device-aware ULTIMATE / hint text below.
func _on_touch() -> bool:
	if DisplayServer.is_touchscreen_available():
		return true
	var tc = get_tree().get_first_node_in_group("touch_controls")
	return tc != null and tc.active_ui

## The bar-row labels, paired with the bar they title (row order matches _draw_bars / ROW_*).
## Built fresh each call so it survives the @onready resolve; cheap (six entries).
func _bar_label_rows() -> Array:
	return [
		[health_label, ROW_HEALTH],
		[stamina_label, ROW_STAMINA],
		[musou_label, ROW_MUSOU],
		[state_label, ROW_WEAPON],
		[flow_label, ROW_FLOW],
		[get_node_or_null("Root/FlowHint"), ROW_FLOW],   # the "build combo…" hint, under FLOW
	]

## Snapshot the shipped .tscn label geometry (offsets + font size) so the desktop branch can
## restore it verbatim — keeping desktop byte-identical (incl. FlowLabel's hand-nudged 224).
func _capture_label_defaults() -> void:
	for entry in _bar_label_rows():
		var lbl: Label = entry[0]
		if lbl:
			_label_defaults[lbl] = {
				"top": lbl.offset_top,
				"bottom": lbl.offset_bottom,
				"fs": lbl.get_theme_font_size("font_size"),
			}
	_scale_ready = true

## Choose the bar geometry for the current screen, then re-lay the bar-row labels to match.
## NARROW (a short logical viewport OR a touchscreen) → the compact phone column; otherwise
## restore the shipped desktop layout verbatim. Wired to the viewport's size_changed so a
## rotate/resize re-picks the layout live.
func _apply_scale() -> void:
	if not _scale_ready:
		return   # defaults not captured yet (an early size_changed); _ready will call us
	# CanvasLayer has no get_viewport_rect(); read the visible rect off the viewport instead.
	var view := get_viewport()
	var vp := view.get_visible_rect().size if view else Vector2(1280, 720)
	# Share ONE "is this a phone?" predicate with the text/hint compacting (_on_touch covers a
	# touchscreen, a force_on test rig, or a runtime _reveal); add the short-viewport fallback
	# so a narrow desktop window compacts too. Keeps the bars, labels, ULT text + hints in sync.
	var narrow := vp.y < 600.0 or _on_touch()
	if narrow:
		BAR_W = BAR_W_NARROW
		BAR_H = BAR_H_NARROW
		ROW_H = ROW_H_NARROW
		BAR_TOP = BAR_TOP_NARROW
		CHARGE_H = CHARGE_H_NARROW
		_layout_bar_labels_narrow()
	else:
		BAR_W = BAR_W_DESK
		BAR_H = BAR_H_DESK
		ROW_H = ROW_H_DESK
		BAR_TOP = BAR_TOP_DESK
		CHARGE_H = CHARGE_H_DESK
		_restore_label_defaults()
	# A touch-state flip / rotate may change the device → re-pick the ULTIMATE wording too,
	# so a full gauge can't keep a stale "hold Q" cue on a phone (no Q key there). Skip until
	# the gauge is bound so the boot "ULTIMATE" placeholder (the .tscn text) is left alone.
	if _musou_live:
		_refresh_musou_text()
	if bars:
		bars.queue_redraw()

## Re-position each bar-row label for the COMPACT phone column: sit it `gap` px above its bar
## (following the tightened row pitch) with the smaller phone font. Code-driven so the labels
## track the shrunken bars.
func _layout_bar_labels_narrow() -> void:
	var flow_hint := get_node_or_null("Root/FlowHint")
	for entry in _bar_label_rows():
		var lbl: Label = entry[0]
		if not lbl:
			continue
		var row: int = entry[1]
		# The bar-row labels sit ABOVE their bar; the FlowHint (also row FLOW, but it's the
		# trailing entry) tucks just UNDER the FLOW bar instead.
		var top: float
		var fs := LABEL_FS_NARROW
		if lbl == flow_hint:
			top = _bar_y(ROW_FLOW) + BAR_H + 6.0
			fs = maxi(LABEL_FS_NARROW - 2, 10)
		else:
			top = _bar_y(row) - LABEL_GAP_NARROW
		lbl.offset_top = top
		lbl.offset_bottom = top + float(fs) + 6.0
		lbl.add_theme_font_size_override("font_size", fs)

## Restore the captured .tscn label geometry — the desktop layout, exactly as shipped.
func _restore_label_defaults() -> void:
	for entry in _bar_label_rows():
		var lbl: Label = entry[0]
		if lbl and _label_defaults.has(lbl):
			var d: Dictionary = _label_defaults[lbl]
			lbl.offset_top = d["top"]
			lbl.offset_bottom = d["bottom"]
			lbl.add_theme_font_size_override("font_size", d["fs"])

func bind(arthur) -> void:
	arthur.stamina_changed.connect(_on_stamina_changed)
	arthur.weapon_state_changed.connect(_on_state_changed)
	arthur.exhausted.connect(_on_exhausted)
	arthur.health_changed.connect(_on_health_changed)
	arthur.musou_changed.connect(_on_musou_changed)
	Impact.flow_changed.connect(_on_flow_changed)
	Impact.kills_changed.connect(_on_kills_changed)
	_on_stamina_changed(arthur.stamina, arthur.max_stamina)
	_on_health_changed(arthur.health, arthur.max_health)
	_on_musou_changed(arthur.musou, arthur.max_musou)
	_on_flow_changed(Impact.flow, Impact.stacks, Impact.flow_mode)
	_on_kills_changed(Impact.kills, "")

func _on_kills_changed(k: int, milestone: String) -> void:
	if not ko_label:
		return
	if milestone != "":
		_milestone = milestone
		_ko_flash = 1.0
	elif _ko_flash <= 0.0:
		ko_label.text = "KO  %d" % k

## Objective + win/lose banner — only present on the battlefield, so guard the nodes.
func set_objective(text: String) -> void:
	if objective_label:
		objective_label.text = text

func show_banner(text: String, color: Color) -> void:
	if banner_label:
		var tc = get_tree().get_first_node_in_group("touch_controls")
		var how := "(tap the R button to restart)" if tc and tc.active_ui else "(press R to restart)"
		banner_label.text = text + "\n" + how
		banner_label.add_theme_color_override("font_color", color)
		banner_label.visible = true

## Re-show the control hints (e.g. on un-pause). Optional convenience — resets the fade.
func replay_hints() -> void:
	_t = 0.0
	_hints_alpha = 1.0
	if hints_label:
		hints_label.modulate.a = 1.0

func _on_health_changed(current: float, maximum: float) -> void:
	_health_ratio = clampf(current / maxf(maximum, 0.001), 0.0, 1.0)
	_health_col = Color(0.85, 0.3, 0.3).lerp(Color(0.5, 0.85, 0.4), _health_ratio)
	if health_label:
		health_label.text = "HEALTH  %d / %d" % [round(current), round(maximum)]
	if bars:
		bars.queue_redraw()

## The musou gauge is the CHARGE-BEAM ULTIMATE: a gold bar that fills as Arthur fights;
## at full it reads "READY — hold Q to fire beam" and pulses (the pulse rides in _process).
func _on_musou_changed(current: float, maximum: float) -> void:
	_musou_live = true
	_musou_ratio = clampf(current / maxf(maximum, 0.001), 0.0, 1.0)
	if _musou_ratio < 1.0:
		# Dim gold while charging; the full-gauge pulse is applied in _process.
		_musou_col = Color(0.7, 0.55, 0.18).lerp(Color(1.0, 0.84, 0.3), _musou_ratio)
	_refresh_musou_text()
	if bars:
		bars.queue_redraw()

## Set the ULTIMATE read-out for the current gauge + device. Pulled out of _on_musou_changed so
## _apply_scale can re-run it: a touch-state flip (_reveal) or a resize re-evaluates the text, so
## a full gauge never leaves the stale "hold Q" cue on a phone (there's no Q key there).
func _refresh_musou_text() -> void:
	if not musou_label:
		return
	if _musou_ratio >= 1.0:
		# On a phone there's no Q key — the ULT touch button fires it — so drop the
		# keyboard cue and keep the line short for the cramped landscape viewport.
		musou_label.text = "ULTIMATE  ★ READY" if _on_touch() else "ULTIMATE  ★ READY — hold Q to fire beam"
	else:
		musou_label.text = "ULTIMATE  %d%%" % round(_musou_ratio * 100.0)

func _process(delta: float) -> void:
	_t += delta
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta * 3.0)
	# Re-tint the stamina bar each frame while it's low (or the exhausted flash is decaying):
	# _on_stamina_changed only fires on a CHANGE, so a low/empty pool would otherwise freeze.
	var base := _stamina_base_col
	if _flash > 0.0:
		base = base.lerp(Color(1, 1, 1), _flash)
	_stamina_col = _stamina_pulsed(base)
	# KO milestone flash: shout RAMPAGE! etc. in gold, then fall back to the count.
	if _ko_flash > 0.0 and ko_label:
		_ko_flash = maxf(0.0, _ko_flash - delta)
		var pulse := 0.6 + 0.4 * sin(_t * 18.0)
		ko_label.text = _milestone
		ko_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.25, pulse))
		if _ko_flash <= 0.0:
			ko_label.text = "KO  %d" % Impact.kills
			ko_label.add_theme_color_override("font_color", Color(1, 1, 1))
	# Ease the flow bar so chains feel like a meter filling, not snapping.
	_flow_ratio = move_toward(_flow_ratio, _flow_target, delta * 2.5)
	# A full ultimate gauge pulses bright gold so "READY" is unmissable.
	if _musou_ratio >= 1.0:
		var pulse := 0.65 + 0.35 * sin(_t * 12.0)
		_musou_col = Color(1.0, 0.78, 0.25).lerp(Color(1.0, 0.95, 0.6), pulse)
	# Fade the control-hint strip a few seconds in: it teaches, then gets out of the way.
	_update_hints_fade()
	if bars:
		bars.queue_redraw()

## Hold the hint strip lit for HINTS_HOLD, then fade it over HINTS_FADE. Cheap + reusable.
func _update_hints_fade() -> void:
	if not hints_label:
		return
	if _t <= HINTS_HOLD:
		_hints_alpha = 1.0
	else:
		_hints_alpha = clampf(1.0 - (_t - HINTS_HOLD) / HINTS_FADE, 0.0, 1.0)
	hints_label.modulate.a = _hints_alpha

# --- the code-drawn bars (no image assets) -----------------------------------

func _bar_y(row: int) -> float:
	return BAR_TOP + float(row) * ROW_H

## Draw one rounded, bordered bar: a recessed dark track (rounded + bordered) with a coloured
## fill clipped to `ratio` inset inside it, plus a faint top rim so it reads as a beveled gauge,
## not a flat box. Built from StyleBoxFlat (true rounded corners), web-export safe — no images.
func _draw_bar(y: float, ratio: float, fill: Color, h: float = BAR_H) -> void:
	var r := minf(BAR_R, h * 0.5)
	# Recessed track: dark fill + a thin dark border, rounded.
	_track_box.bg_color = COL_TRACK
	_track_box.border_color = COL_BORDER
	_track_box.set_corner_radius_all(int(r))
	bars.draw_style_box(_track_box, Rect2(BAR_X, y, BAR_W, h))
	# Coloured fill, inset 2px so the track frame stays visible, clipped to ratio.
	var fw := (BAR_W - 4.0) * clampf(ratio, 0.0, 1.0)
	if fw > 1.0:
		var fr := maxf(0.0, r - 2.0)
		_fill_box.bg_color = fill
		_fill_box.set_corner_radius_all(int(fr))
		var fill_rect := Rect2(BAR_X + 2.0, y + 2.0, fw, h - 4.0)
		bars.draw_style_box(_fill_box, fill_rect)
		# faint top highlight across the filled span for a glossy, readable bevel
		bars.draw_rect(Rect2(fill_rect.position, Vector2(fill_rect.size.x, maxf(2.0, h * 0.25))), COL_RIM)

func _draw_bars() -> void:
	if not bars:
		return
	_draw_bar(_bar_y(ROW_HEALTH), _health_ratio, _health_col)
	_draw_bar(_bar_y(ROW_STAMINA), _stamina_ratio, _stamina_col)
	_draw_bar(_bar_y(ROW_MUSOU), _musou_ratio, _musou_col)
	# The WEAPON row carries only a thin CHARGE sub-bar (the swing charge), sitting under
	# its label; an empty charge draws just the track so the row still reads as a gauge.
	_draw_bar(_bar_y(ROW_WEAPON), _charge_ratio, Color(1.0, 0.72, 0.25), CHARGE_H)
	_draw_bar(_bar_y(ROW_FLOW), _flow_ratio, _flow_color())

func _flow_color() -> Color:
	var cool := Color(0.45, 0.7, 1.0)
	var warm := Color(1.0, 0.55, 0.2)
	var col := cool.lerp(warm, clampf(float(_stacks) / 5.0, 0.0, 1.0))
	if _mode:
		# Stone Flow mode: pulse gold so it clearly reads as "powered up".
		var pulse := 0.5 + 0.5 * sin(_t * 9.0)
		col = col.lerp(Color(1.0, 0.85, 0.3), 0.5 + 0.5 * pulse)
	return col

func _on_stamina_changed(current: float, maximum: float) -> void:
	var ratio := clampf(current / maxf(maximum, 0.001), 0.0, 1.0)
	_stamina_ratio = ratio
	var col := Color(0.85, 0.25, 0.25).lerp(Color(0.35, 0.85, 0.45), ratio)
	_stamina_base_col = col   # remember the resting tint so the LOW-stamina pulse (in _process) can ride on top
	if _flash > 0.0:
		col = col.lerp(Color(1, 1, 1), _flash)
	_stamina_col = _stamina_pulsed(col)
	if stamina_label:
		stamina_label.text = "STAMINA  %d / %d" % [round(current), round(maximum)]
	if bars:
		bars.queue_redraw()

## Telegraph a LOW stamina pool through the EXISTING bar: below STAMINA_LOW it pulses and
## desaturates (a readable "almost out" warning), reusing _t and the exhausted _flash. A
## no-op above the threshold, so a healthy pool looks exactly as before. Cosmetic only.
func _stamina_pulsed(col: Color) -> Color:
	if _stamina_ratio >= STAMINA_LOW:
		return col
	# Stronger warning the closer to empty: pulse brightness + drain saturation toward grey.
	var sev := 1.0 - clampf(_stamina_ratio / STAMINA_LOW, 0.0, 1.0)
	var pulse := 0.6 + 0.4 * sin(_t * 14.0)
	var dim := col.lerp(Color(0.45, 0.42, 0.4), 0.5 * sev)   # desaturate toward a tired grey
	return dim.lerp(Color(1.0, 0.85, 0.4), sev * 0.35 * pulse)

## The weapon read-out. A live swing reports a `power` (charge 0..1) — show it as a clear
## "WEAPON  CHARGE 42%" line plus a thin charge sub-bar; otherwise just the state word.
func _on_state_changed(state_name: String, power: float) -> void:
	if power > 0.01:
		_charge_ratio = clampf(power, 0.0, 1.0)
		if state_label:
			state_label.text = "WEAPON  CHARGE %d%%" % round(power * 100.0)
	else:
		_charge_ratio = 0.0
		if state_label:
			state_label.text = "WEAPON  %s" % state_name
	if bars:
		bars.queue_redraw()

func _on_flow_changed(flow: float, stacks: int, mode: bool) -> void:
	_flow_target = clampf(flow / Impact.FLOW_MAX, 0.0, 1.0)
	_stacks = stacks
	_mode = mode
	if flow_label:
		if mode:
			flow_label.text = "STONE FLOW  x%d  — FLOW!" % stacks
		else:
			flow_label.text = "STONE FLOW  x%d" % stacks
	if bars:
		bars.queue_redraw()

func _on_exhausted() -> void:
	_flash = 1.0
