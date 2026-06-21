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

const FILL_WIDTH := 312.0
var _flash := 0.0       ## white flash on the stamina bar when a swing fizzles
var _flow_ratio := 0.0  ## smoothed flow bar fill
var _flow_target := 0.0
var _stacks := 0
var _mode := false
var _t := 0.0

func bind(arthur) -> void:
	arthur.stamina_changed.connect(_on_stamina_changed)
	arthur.weapon_state_changed.connect(_on_state_changed)
	arthur.exhausted.connect(_on_exhausted)
	Impact.flow_changed.connect(_on_flow_changed)
	_on_stamina_changed(arthur.stamina, arthur.max_stamina)
	_on_flow_changed(Impact.flow, Impact.stacks, Impact.flow_mode)

func _process(delta: float) -> void:
	_t += delta
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta * 3.0)
	# Ease the flow bar so chains feel like a meter filling, not snapping.
	_flow_ratio = move_toward(_flow_ratio, _flow_target, delta * 2.5)
	flow_fill.size.x = FILL_WIDTH * _flow_ratio
	flow_fill.color = _flow_color()

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

func _on_state_changed(state_name: String, charge: float) -> void:
	if charge > 0.01:
		state_label.text = "WEAPON: WINDING  [%d%%]" % round(charge * 100.0)
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
