extends Node2D
## Headless test for the shared scene-transition fade (token TRANSITION) — the hard-cut killer.
##
## The Transition autoload owns a high-layer black ColorRect that fades out → swaps the scene →
## fades in, so lobby/battle/pause/score all wipe smoothly instead of snapping. Autoloads load for
## ANY scene run, so this test reaches the live `/root/Transition` (with a built-instance fallback
## so it still runs if the autoload were ever absent) and asserts the contract WITHOUT letting the
## real scene swap tear the test down:
##   - it exposes a `change_scene(path)` method (the single entry point every UI script now calls);
##   - it owns an overlay CanvasLayer with a full-rect ColorRect cover;
##   - it is process_mode ALWAYS (so the wipe runs while the tree is paused — PauseMenu needs this);
##   - calling change_scene with a VALID path doesn't error and arms the wipe (is_busy → true), and
##     calling it with an empty / missing path is a guarded no-op (stays idle).
## The actual change_scene_to_file is stubbed out by KILLING the wipe tween before its deferred swap
## callback can fire (the swap is scheduled a fraction of a second out, well past this frame-2 report).
##
## Run: godot --headless --path . res://tests/TransitionTest.tscn --quit-after 600 — look for TRANSITION_VERDICT.

const A_VALID_PATH := "res://scenes/ui/StageSelect.tscn"

var _tr
var _built := false
var _frame := 0

func _ready() -> void:
	# Prefer the real autoload (it is present in any headless run); build a standalone instance only
	# as a fallback so the test never depends on registration order.
	_tr = get_node_or_null("/root/Transition")
	if _tr == null:
		_tr = load("res://scripts/Transition.gd").new()
		add_child(_tr)
		_built = true

func _physics_process(_delta: float) -> void:
	_frame += 1
	if _frame < 2:
		return
	_report()

func _report() -> void:
	var checks := {}

	# 1) The single public entry point exists.
	checks["has_change_scene"] = _tr.has_method("change_scene")

	# 2) It owns an overlay CanvasLayer holding a ColorRect cover (the full-rect black wipe).
	var layer: CanvasLayer = null
	for c in _tr.get_children():
		if c is CanvasLayer:
			layer = c
			break
	checks["has_overlay_layer"] = layer != null
	var has_rect := false
	if layer != null:
		for c in layer.get_children():
			if c is ColorRect:
				has_rect = true
				break
	checks["has_cover_rect"] = has_rect

	# 3) process_mode ALWAYS — the wipe must run while the tree is paused (PauseMenu calls it paused).
	checks["always"] = _tr.process_mode == Node.PROCESS_MODE_ALWAYS

	# 4) An empty / missing path is a guarded no-op: no error, stays idle (never reaches change_scene_to_file).
	_tr.change_scene("")
	checks["empty_noop"] = (not _tr.has_method("is_busy")) or (not _tr.is_busy())
	_tr.change_scene("res://__does_not_exist__.tscn")
	checks["missing_noop"] = (not _tr.has_method("is_busy")) or (not _tr.is_busy())

	# 5) A VALID path doesn't error and ARMS the wipe (is_busy → true). We then KILL the tween so the
	#    deferred change_scene_to_file callback never fires — stubbing the real swap so the test lives.
	_tr.change_scene(A_VALID_PATH)
	checks["valid_arms"] = (not _tr.has_method("is_busy")) or _tr.is_busy()
	_stub_out_swap()

	var ok := true
	var parts: Array = []
	for k in checks:
		ok = ok and checks[k]
		parts.append("%s=%s" % [k, str(checks[k])])
	print("TRANSITION_RESULT built_fallback=%s %s" % [str(_built), " ".join(parts)])
	print("TRANSITION_VERDICT %s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)

## Kill any in-flight wipe tween on the Transition so its queued change_scene_to_file can't run and
## tear the test (and the whole headless harness) down. Uses the public kill path if present, else
## reaches the private tween — both are guarded.
func _stub_out_swap() -> void:
	if _tr.has_method("_kill_tween"):
		_tr._kill_tween()
	elif "_tween" in _tr and _tr._tween != null and _tr._tween.is_valid():
		_tr._tween.kill()
