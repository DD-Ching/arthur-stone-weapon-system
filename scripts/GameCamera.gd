extends Camera2D
## Arthur's camera — it follows him (it's his child) and frames the battle like a musou camera.
##
## Four layers that no longer fight each other:
##   - a BASE ZOOM so the action fills the screen instead of sitting as specks in a wide diorama;
##   - WORLD LIMITS (set by BattleMap) so it never reveals past the wall band / empty floor;
##   - a small LOOK-AHEAD that leads the view toward where Arthur is aiming;
##   - a decaying, optionally DIRECTIONAL shake + a punch-zoom KICK on heavy hits / the ultimate.
## Shake rides ON TOP of the look-ahead offset (the old code hard-zeroed offset every frame, which
## stomped any framing). Reuse: every map + room gets it for free; BattleMap just sets the limits.

@export var base_zoom := 1.5       ## framed-in (1 = no zoom); the swarm + the stone read at a glance
@export var lookahead := 110.0     ## how far the view leads toward the aim heading (toward the fight)
@export var decay := 9.0           ## how quickly a shake settles
@export var max_offset := 24.0     ## clamp so a huge hit never throws the view off

var _shake := 0.0
var _shake_dir := Vector2.ZERO
var _base_offset := Vector2.ZERO   ## the look-ahead offset (shake is added on top of this)
var _zoom_kick := 0.0              ## transient punch-zoom amount, eases back to 0
var _eff_zoom := 1.5               ## base_zoom scaled DOWN on short (phone) screens — see _recompute_zoom

func _ready() -> void:
	make_current()
	_recompute_zoom()
	zoom = Vector2(_eff_zoom, _eff_zoom)
	reset_smoothing()
	get_viewport().size_changed.connect(_recompute_zoom)

## Effective zoom = base zoom scaled down on a SHORT viewport (a phone in landscape, ~390px tall)
## so a tight screen still shows enough battlefield. Desktop (720 tall) → ratio 1.0 → unchanged.
func _recompute_zoom() -> void:
	var vp := get_viewport_rect().size
	_eff_zoom = base_zoom * clampf(vp.y / 720.0, 0.72, 1.0)

## Clamp the camera to the world so it never shows past the bounding wall band. Called once by
## BattleMap with _world_bounds(). Godot centres automatically when the world is smaller than the view.
func set_world_limits(b: Rect2) -> void:
	limit_left = int(b.position.x)
	limit_top = int(b.position.y)
	limit_right = int(b.end.x)
	limit_bottom = int(b.end.y)

## Lead the view a little toward `dir` (the aim heading) so you see more of where you're fighting.
## Called each frame by Arthur with his aim direction; lerped so it glides rather than snaps.
func set_focus(dir: Vector2) -> void:
	var target := dir.normalized() * lookahead if dir.length() > 0.01 else Vector2.ZERO
	_base_offset = _base_offset.lerp(target, 0.08)

## A decaying shake. `dir` (optional) biases the jitter along the hit normal; the default omni jitter
## keeps every existing `add_shake(strength)` call working unchanged.
func add_shake(strength: float, dir: Vector2 = Vector2.ZERO) -> void:
	_shake = minf(max_offset, maxf(_shake, strength))
	_shake_dir = dir

## A punch-zoom on a heavy hit / the ultimate — snaps in a touch, then eases back to base.
func kick(strength: float) -> void:
	_zoom_kick = maxf(_zoom_kick, clampf(strength / 280.0, 0.04, 0.16))

func _process(delta: float) -> void:
	var jitter := Vector2.ZERO
	if _shake > 0.05:
		if _shake_dir.length() > 0.01:
			var n := _shake_dir.normalized()
			var perp := Vector2(-n.y, n.x)
			jitter = n * randf_range(-1.0, 1.0) * _shake + perp * randf_range(-0.35, 0.35) * _shake
		else:
			jitter = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake
		_shake = lerpf(_shake, 0.0, clampf(decay * delta, 0.0, 1.0))
	else:
		_shake = 0.0
	offset = _base_offset + jitter
	# Punch-zoom: ease the kick back to 0, so zoom dips in then recovers.
	if _zoom_kick > 0.001:
		_zoom_kick = lerpf(_zoom_kick, 0.0, clampf(8.0 * delta, 0.0, 1.0))
		var z := _eff_zoom * (1.0 - _zoom_kick)
		zoom = Vector2(z, z)
	elif not zoom.is_equal_approx(Vector2(_eff_zoom, _eff_zoom)):
		zoom = Vector2(_eff_zoom, _eff_zoom)
