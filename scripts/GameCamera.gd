extends Camera2D
## A camera that follows Arthur and shakes when the stone connects.
##
## Shake is intentionally simple for the prototype: a single decaying magnitude
## that jitters the camera offset every frame. Bigger / more-charged hits push a
## larger magnitude in. It reads as "impact" without needing noise textures.

@export var decay := 9.0       ## how quickly a shake settles (higher = snappier)
@export var max_offset := 22.0 ## clamp so a huge hit never throws the view off

var _shake := 0.0

func _ready() -> void:
	make_current()

func add_shake(strength: float) -> void:
	_shake = minf(max_offset, maxf(_shake, strength))

func _process(delta: float) -> void:
	if _shake > 0.05:
		offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake
		_shake = lerpf(_shake, 0.0, clampf(decay * delta, 0.0, 1.0))
	else:
		_shake = 0.0
		offset = Vector2.ZERO
