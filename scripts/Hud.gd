extends CanvasLayer
## Minimal diagnostic HUD: a stamina bar, a weapon-state read-out, the Stone Flow
## combo meter, and a one-line control hint. Deliberately ugly-but-clear — game
## feel first, polish later.
##
## It binds to Arthur (stamina + weapon state) and to the Impact autoload (Stone
## Flow) via signals — the HUD never polls and never reaches into gameplay nodes.

@onready var stamina_fill: ColorRect = $Root/StaminaBg/StaminaFill
@onready var stamina_label: Label = $Root/StaminaLabel
@onready var state_label: Label = $Root/StateLabel
@onready var flow_fill: ColorRect = $Root/FlowBg/FlowFill
@onready var flow_label: Label = $Root/FlowLabel
@onready var health_fill: ColorRect = $Root/HealthBg/HealthFill
@onready var health_label: Label = $Root/HealthLabel
@onready var objective_label: Label = $Root/ObjectiveLabel
@onready var banner_label: Label = $Root/BannerLabel
@onready var ko_label: Label = $Root/KoLabel
@onready var musou_fill: ColorRect = $Root/MusouBg/MusouFill
@onready var musou_label: Label = $Root/MusouLabel

const FILL_WIDTH := 312.0
var _flash := 0.0       ## white flash on the stamina bar when a swing fizzles
var _ko_flash := 0.0    ## milestone flash on the KO counter
var _milestone := ""
var _flow_ratio := 0.0  ## smoothed flow bar fill
var _flow_target := 0.0
var _stacks := 0
var _mode := false
var _musou_ratio := 0.0   ## musou gauge fill 0..1 (full = ULTIMATE ready)
var _t := 0.0

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

func _on_health_changed(current: float, maximum: float) -> void:
	if not health_fill:
		return
	var ratio := clampf(current / maximum, 0.0, 1.0)
	health_fill.size.x = FILL_WIDTH * ratio
	health_fill.color = Color(0.85, 0.3, 0.3).lerp(Color(0.5, 0.85, 0.4), ratio)
	health_label.text = "HEALTH  %d / %d" % [round(current), round(maximum)]

## The musou rage gauge: a gold bar that fills as Arthur fights; at full it reads
## "ULTIMATE READY!" and pulses (the pulse rides in _process so it animates).
func _on_musou_changed(current: float, maximum: float) -> void:
	if not musou_fill:
		return
	_musou_ratio = clampf(current / maxf(maximum, 0.001), 0.0, 1.0)
	musou_fill.size.x = FILL_WIDTH * _musou_ratio
	if _musou_ratio >= 1.0:
		musou_label.text = "MUSOU  ULTIMATE READY!"
	else:
		musou_label.text = "MUSOU  %d / %d" % [round(current), round(maximum)]
		# Dim gold while charging; the full-gauge pulse is applied in _process.
		musou_fill.color = Color(0.7, 0.55, 0.18).lerp(Color(1.0, 0.84, 0.3), _musou_ratio)

func _process(delta: float) -> void:
	_t += delta
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta * 3.0)
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
	flow_fill.size.x = FILL_WIDTH * _flow_ratio
	flow_fill.color = _flow_color()
	# A full musou gauge pulses bright gold so "ULTIMATE READY!" is unmissable.
	if musou_fill and _musou_ratio >= 1.0:
		var pulse := 0.65 + 0.35 * sin(_t * 12.0)
		musou_fill.color = Color(1.0, 0.78, 0.25).lerp(Color(1.0, 0.95, 0.6), pulse)

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
	var ratio := clampf(current / maximum, 0.0, 1.0)
	stamina_fill.size.x = FILL_WIDTH * ratio
	var col := Color(0.85, 0.25, 0.25).lerp(Color(0.35, 0.85, 0.45), ratio)
	if _flash > 0.0:
		col = col.lerp(Color(1, 1, 1), _flash)
	stamina_fill.color = col
	stamina_label.text = "STAMINA  %d / %d" % [round(current), round(maximum)]

func _on_state_changed(state_name: String, power: float) -> void:
	if power > 0.01:
		state_label.text = "WEAPON: POWER  [%d%%]" % round(power * 100.0)
	else:
		state_label.text = "WEAPON: %s" % state_name

func _on_flow_changed(flow: float, stacks: int, mode: bool) -> void:
	_flow_target = clampf(flow / Impact.FLOW_MAX, 0.0, 1.0)
	_stacks = stacks
	_mode = mode
	if mode:
		flow_label.text = "STONE FLOW  x%d  — FLOW!" % stacks
	else:
		flow_label.text = "STONE FLOW  x%d" % stacks

func _on_exhausted() -> void:
	_flash = 1.0
