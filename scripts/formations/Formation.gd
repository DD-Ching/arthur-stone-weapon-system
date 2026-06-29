class_name Formation
extends Node2D
## A reusable, placeable enemy formation: a group of units arranged in ranks, spawned
## together facing a direction. PLACE one in a level (auto-spawns at its position) or
## spawn one from a wave — tune its roster + spacing instead of hand-placing every soldier.
##
## Three optional ranks, front to back along the facing:
##   front     — the front rank (e.g. shields), `front_count` wide
##   support   — a rank behind (e.g. spears), `support_count` wide, `rank_gap` back
##   commander — one unit at the very back (e.g. a banner bearer), 2×`rank_gap` back
##
## Units are added to the level (this node's parent), not to the formation, so they're
## independent bodies the moment they exist. The formation node stays alive to run MORALE: cut
## down its commander (the officer at the back) and the surviving ranks ROUT. Set `team` to make
## an allied formation.

@export var front: PackedScene
@export var front_count := 5
@export var support: PackedScene
@export var support_count := 0
@export var commander: PackedScene
@export var spacing := 80.0          ## gap between units within a rank
@export var rank_gap := 70.0         ## distance each rank sits behind the front
@export var team := "raiders"
@export var face := Vector2.DOWN     ## the way the formation faces (toward its objective)
@export var auto_spawn := true       ## spawn on _ready (placed in a level) vs. on demand
@export var morale_break := true     ## when the commander (officer) falls, the surviving ranks ROUT

var units: Array = []                ## the spawned bodies (for break/morale logic)
var _commander = null                ## the officer at the back rank — its fall breaks the formation
var _routed := false                 ## one-shot guard so the rout fires exactly once

func _ready() -> void:
	if auto_spawn:
		spawn()

## Instantiate the roster arranged in ranks. Returns the spawned units.
func spawn() -> Array:
	var fwd := face.normalized()
	var side := Vector2(-fwd.y, fwd.x)   # perpendicular: the rank spreads along this
	units = []
	units += _rank(front, front_count, side, Vector2.ZERO)
	if support != null and support_count > 0:
		units += _rank(support, support_count, side, -fwd * rank_gap)
	if commander != null:
		units += _rank(commander, 1, side, -fwd * rank_gap * 2.0)
		if not units.is_empty():
			_commander = units[-1]   # the officer at the back rank — its fall routs the line
	return units

## Formation MORALE: once the commander (officer) falls, the surviving ranks ROUT — they panic,
## reel, and scatter back from where the banner dropped, so "cut down the officer to shatter the
## unit" is a real Musou loop. Reuses each unit's own stun() + a RigidBody scatter impulse — no AI
## surgery. Fires ONCE. A formation with no commander never routs (there's nothing to behead).
func _physics_process(_delta: float) -> void:
	if not morale_break or _routed or _commander == null:
		return
	var down: bool = (not is_instance_valid(_commander)) or ("_dead" in _commander and _commander._dead)
	if down:
		_routed = true
		_rout()

func _rout() -> void:
	var origin := global_position
	if is_instance_valid(_commander):
		origin = _commander.global_position
	var broke := 0
	for u in units:
		if u == _commander or not is_instance_valid(u):
			continue
		if "_dead" in u and u._dead:
			continue
		if u.has_method("stun"):
			u.stun(2.6)             # panic — reeling, helpless to fight back for a beat
		if u.has_method("apply_central_impulse"):
			var away: Vector2 = u.global_position - origin
			away = away.normalized() if away.length() > 1.0 else Vector2.DOWN
			u.apply_central_impulse(away * 420.0)   # scatter back from where the banner fell
		broke += 1
	if broke > 0:
		Impact.popup("THE LINE BREAKS!", origin + Vector2(0.0, -52.0), Color(1.0, 0.55, 0.3), 1.5)

func _rank(scene: PackedScene, count: int, side: Vector2, offset: Vector2) -> Array:
	var out: Array = []
	if scene == null or count <= 0:
		return out
	var parent := get_parent()
	for i in count:
		var u = scene.instantiate()
		if "team" in u:
			u.team = team                # set BEFORE _ready so it joins the right groups
		parent.add_child(u)
		var t := 0.0 if count <= 1 else float(i) - float(count - 1) * 0.5
		u.global_position = global_position + offset + side * t * spacing
		if "ai_enabled" in u:
			u.ai_enabled = true
		out.append(u)
	return out
