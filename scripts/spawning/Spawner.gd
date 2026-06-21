class_name Spawner
extends RefCounted
## Reusable spawn helper — instance a group of scenes into a parent across a lane (a line
## of x positions at a given y). Used for the reinforcement waves AND the allied line, so
## the spawn pattern lives in one place instead of being copy-pasted per spawn site.
##
## Stateless: call the static functions. `scenes` is an Array of PackedScene.

## Spawn `scenes` along the line y=lane_y from x_min..x_max. `scatter` jitters x randomly
## (waves arriving ragged); otherwise the units are spaced evenly (a tidy line). Returns
## the spawned nodes. Each gets ai_enabled set if it exposes that property.
static func spawn(parent: Node, scenes: Array, lane_y: float, x_min: float, x_max: float,
		scatter := false, ai_on := true) -> Array:
	var out: Array = []
	var n := scenes.size()
	for i in n:
		var e = scenes[i].instantiate()
		parent.add_child(e)
		if "ai_enabled" in e:
			e.ai_enabled = ai_on
		var x: float
		if scatter:
			x = randf_range(x_min, x_max)
		elif n <= 1:
			x = (x_min + x_max) * 0.5
		else:
			x = lerpf(x_min, x_max, float(i) / float(n - 1))
		e.global_position = Vector2(x, lane_y)
		out.append(e)
	return out

## Convenience: a lane of `count` copies of one scene (e.g. the allied footmen).
static func spawn_count(parent: Node, scene: PackedScene, count: int, lane_y: float,
		x_min: float, x_max: float, scatter := false, ai_on := true) -> Array:
	var scenes: Array = []
	for _i in count:
		scenes.append(scene)
	return spawn(parent, scenes, lane_y, x_min, x_max, scatter, ai_on)
