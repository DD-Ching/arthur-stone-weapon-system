extends Node
## Transition — the ONE shared scene-change fade that kills the hard cuts.
##
## Registered as an autoload (see project.godot [autoload], after Campaign), mirroring Impact /
## Campaign: a single source of truth any screen can reach as `Transition.change_scene(path)`.
## Today every screen change (lobby → battle → pause → score) is an instant hard cut; this owns a
## high-layer black ColorRect and fades it to opaque, swaps the scene, then fades it back to clear,
## so EVERY navigation gets a smooth wipe for free. Build once, reuse many — no per-screen fade.
##
## It is `process_mode = ALWAYS` so it keeps running (and can drive its own fade) while the tree is
## PAUSED — the PauseMenu calls `change_scene` while `get_tree().paused == true`. Single-threaded:
## the fade is a plain Tween on the CanvasLayer's ColorRect, no threads, web-export safe.
##
## Callers guard the autoload (so a build/headless run without it still navigates):
##   var tr := get_node_or_null("/root/Transition")
##   if tr: tr.change_scene(path) else: get_tree().change_scene_to_file(path)

## How long each half of the wipe takes (fade-out before the swap, fade-in after). Short on
## purpose: the screen change still feels immediate, and a headless test that waits a few frames
## still observes the swap (the actual change_scene_to_file is called on the fade-out's completion).
const FADE_OUT := 0.22
const FADE_IN := 0.28

## This CanvasLayer sits above everything (HUD = 1, ScoreScreen = 64, PauseMenu = 80) so the wipe
## covers the whole screen, including the pause overlay.
const COVER_LAYER := 128

var _layer: CanvasLayer
var _rect: ColorRect
var _tween: Tween
## Guards against re-entrancy: a second change_scene while one is mid-fade is ignored (the first
## wins) so we never queue two scene swaps or fight two tweens over the same rect.
var _busy := false

func _ready() -> void:
	# Run while the tree is paused (PauseMenu → change_scene happens under pause).
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	# Start the cover OPAQUE on boot so fade_in() actually wipes it away — the very first screen
	# fades up from black instead of snapping on. (fade_in() only animates toward 0; with a fresh
	# already-transparent rect it would be a no-op, so we prime it to black here.)
	_rect.color = Color(0.0, 0.0, 0.0, 1.0)
	fade_in()

## Build the cover: a high-layer CanvasLayer + a full-rect black ColorRect that starts transparent
## and ignores the mouse (so it never eats input when clear). Safe to call once.
func _build() -> void:
	if _layer != null:
		return
	_layer = CanvasLayer.new()
	_layer.layer = COVER_LAYER
	_layer.name = "TransitionCover"
	# The cover must also survive/ignore pause so it can fade while the tree is paused.
	_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_layer)

	_rect = ColorRect.new()
	_rect.color = Color(0.0, 0.0, 0.0, 0.0)   # start fully transparent
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Ignore the mouse while clear; we flip this to STOP during a wipe so a stray click can't slip
	# through to the dying scene, then back to IGNORE when transparent again.
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_rect)

## Change to `path` with a fade: black-out, swap the scene, fade back in. Guarded — an invalid /
## missing path is a no-op (we never hand change_scene_to_file a bad path). Re-entrant calls while a
## wipe is in flight are ignored. Single-threaded; the swap runs on the fade-out's completion.
func change_scene(path: String) -> void:
	if path == "" or not ResourceLoader.exists(path):
		return
	if _busy:
		return
	if _rect == null:
		_build()
	_busy = true
	_rect.mouse_filter = Control.MOUSE_FILTER_STOP   # block input during the wipe
	_kill_tween()
	_tween = create_tween()
	_tween.tween_property(_rect, "color:a", 1.0, FADE_OUT)
	# Swap on the SAME completion step: change the scene, then fade back up. Using tween_callback
	# keeps it on the main thread; a headless test waiting a few frames still sees the swap.
	_tween.tween_callback(_do_swap.bind(path))
	_tween.tween_property(_rect, "color:a", 0.0, FADE_IN)
	_tween.tween_callback(_finish)

## Fade the cover UP from black to clear (used on boot, and as the tail of change_scene). Idempotent
## enough to call on a fresh, already-transparent rect — it just animates to 0 alpha.
func fade_in() -> void:
	if _rect == null:
		_build()
	_kill_tween()
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tween = create_tween()
	_tween.tween_property(_rect, "color:a", 0.0, FADE_IN)

func _do_swap(path: String) -> void:
	var tree := get_tree()
	if tree == null:
		return
	tree.change_scene_to_file(path)

func _finish() -> void:
	if _rect != null:
		_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false

func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null

## True while a wipe is in flight (the cover is fading / mid-swap). Exposed for tests / callers.
func is_busy() -> bool:
	return _busy
