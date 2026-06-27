extends Node2D
## The musou CHARGE-BEAM — a sustained light beam Arthur sprays after charging Q.
##
## It anchors to Arthur and tracks his aim, so you can SWEEP it across the field like a water gun.
## Every tick it shoves + heavily damages every enemy caught along its length, for a duration set
## by how long you charged (the gauge you spent). Reuse-first: damage goes through the shared
## Enemy.apply_hit; it's a cheap group scan per tick (no per-frame raycasts), code-drawn glow.

const LEN := 780.0          ## beam reach
const WIDTH := 74.0         ## beam half-width is WIDTH*0.5
const TICK := 0.07          ## damage cadence (s)

var _arthur = null
var _life := 0.0
var _t := 0.0
var _tick_cd := 0.0
var _alpha := 1.0

## Anchor to Arthur and set the spray duration (the charge held). Call right after add_child.
func fire(arthur, duration: float) -> void:
	_arthur = arthur
	_life = maxf(0.25, duration)
	if is_instance_valid(arthur):
		Audio.play("shield_break", arthur.global_position)   # a bright zap on fire

func _process(delta: float) -> void:
	_t += delta
	if not is_instance_valid(_arthur):
		queue_free()
		return
	# Follow Arthur + track his aim so the beam sweeps with the cursor.
	global_position = _arthur.global_position
	if "weapon" in _arthur and _arthur.weapon:
		rotation = _arthur.weapon.aim_angle
	_life -= delta
	_tick_cd -= delta
	if _tick_cd <= 0.0:
		_tick_cd = TICK
		_zap()
	_alpha = clampf(_life / 0.18, 0.0, 1.0)   # quick fade-out at the end
	queue_redraw()
	if _life <= 0.0:
		queue_free()

## Damage + shove every enemy caught in the beam this tick (a cheap group scan, no raycasts).
func _zap() -> void:
	var origin := global_position
	var dir := Vector2.RIGHT.rotated(rotation)
	var perp := Vector2(-dir.y, dir.x)
	for e in get_tree().get_nodes_in_group("targets"):
		if not is_instance_valid(e) or ("_dead" in e and e._dead):
			continue
		var rel: Vector2 = e.global_position - origin
		var along := rel.dot(dir)
		if along < 0.0 or along > LEN:
			continue
		var r: float = e.radius if "radius" in e else 14.0
		if absf(rel.dot(perp)) > WIDTH * 0.5 + r:
			continue
		if e.has_method("apply_hit"):
			e.apply_hit(dir, 540.0, 0.2, 17.0, 0.0)   # shove down-beam + heavy damage
		Impact.add_flow(1.0)
	if _arthur and _arthur.camera and _arthur.camera.has_method("add_shake"):
		_arthur.camera.call("add_shake", 7.0, dir)

func _draw() -> void:
	# A bright light beam in LOCAL space (rotation aims it): a wide soft glow, a brighter mid, a
	# hot white core, and a pulsing muzzle flare at the origin.
	var a := _alpha
	var pulse := 0.82 + 0.18 * sin(_t * 42.0)
	var tip := Vector2(LEN, 0.0)
	draw_line(Vector2.ZERO, tip, Color(0.55, 0.82, 1.0, 0.18 * a), WIDTH)
	draw_line(Vector2.ZERO, tip, Color(0.72, 0.92, 1.0, 0.42 * a), WIDTH * 0.55)
	draw_line(Vector2.ZERO, tip, Color(1.0, 1.0, 1.0, 0.95 * a * pulse), WIDTH * 0.22)
	draw_circle(Vector2.ZERO, WIDTH * 0.62 * pulse, Color(1.0, 1.0, 0.95, 0.65 * a))
	draw_circle(Vector2.ZERO, WIDTH * 0.34, Color(0.85, 0.96, 1.0, 0.9 * a))
