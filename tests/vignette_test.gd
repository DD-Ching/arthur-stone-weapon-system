extends Node2D
## Headless test for the screen-space Vignette overlay.
##
## Instantiates the Vignette scene ALONE (no full map) and asserts the reusable contract:
##   - it is a CanvasLayer (a screen-space overlay, not a world node);
##   - it sits at a layer BELOW the HUD (layer 1) so it never dims the HUD bars / pause / score;
##   - it builds a drawing child Control with mouse_filter IGNORE (clicks pass through);
##   - it survives a few frames with no error (the _draw path runs clean).
##
## Run: godot --headless --path . res://tests/VignetteTest.tscn — look for VIGNETTE_VERDICT.

const VIGNETTE := preload("res://scenes/ui/Vignette.tscn")

var _vig
var _frame := 0

func _ready() -> void:
	_vig = VIGNETTE.instantiate()
	add_child(_vig)

func _physics_process(_delta: float) -> void:
	_frame += 1
	if _frame >= 4:
		_report()

func _report() -> void:
	var is_layer: bool = _vig is CanvasLayer
	# Below the HUD (layer 1) so the dark edges never dim HUD text / pause / score overlays.
	var under_hud: bool = is_layer and _vig.layer < 1
	# A drawing child Control that ignores the mouse (clicks pass through to the game).
	var child := _find_control(_vig)
	var has_child: bool = child != null
	var ignores_mouse: bool = has_child and child.mouse_filter == Control.MOUSE_FILTER_IGNORE
	var still_valid: bool = is_instance_valid(_vig)

	print("VIGNETTE_RESULT canvaslayer=%s under_hud(layer=%s)=%s child=%s ignore_mouse=%s alive=%s"
		% [str(is_layer), str(_vig.layer if is_layer else -1), str(under_hud),
			str(has_child), str(ignores_mouse), str(still_valid)])
	var ok: bool = is_layer and under_hud and has_child and ignores_mouse and still_valid
	print("VIGNETTE_VERDICT %s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)

## Find the first Control anywhere under `node` (the vignette's drawing frame).
func _find_control(node: Node) -> Control:
	for c in node.get_children():
		if c is Control:
			return c
		var deeper := _find_control(c)
		if deeper != null:
			return deeper
	return null
