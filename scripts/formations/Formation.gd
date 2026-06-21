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
## independent bodies the moment they exist. The formation node stays as a marker (a
## hook for future break/morale logic). Set `team` to make an allied formation.

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

var units: Array = []                ## the spawned bodies (for future break conditions)

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
	return units

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
