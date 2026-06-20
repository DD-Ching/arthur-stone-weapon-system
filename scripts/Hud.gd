extends CanvasLayer
## Minimal diagnostic HUD: a stamina bar, a weapon-state read-out, and a one-line
## control hint. Deliberately ugly-but-clear — game feel first, polish later.
##
## It binds to Arthur via signals (see bind()), so the HUD never polls and never
## needs a hard reference path into the gameplay nodes.

@onready var stamina_fill: ColorRect = $Root/StaminaBg/StaminaFill
@onready var stamina_label: Label = $Root/StaminaLabel
@onready var state_label: Label = $Root/StateLabel

const FILL_WIDTH := 312.0
var _flash := 0.0  ## white flash on the bar when a swing fizzles from exhaustion

func bind(arthur) -> void:
	arthur.stamina_changed.connect(_on_stamina_changed)
	arthur.weapon_state_changed.connect(_on_state_changed)
	arthur.exhausted.connect(_on_exhausted)
	_on_stamina_changed(arthur.stamina, arthur.max_stamina)

func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta * 3.0)

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

func _on_exhausted() -> void:
	_flash = 1.0
