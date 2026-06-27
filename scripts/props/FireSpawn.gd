class_name FireSpawn
extends RefCounted
## The ONE place a prop drops a burning pool. FireBarrel / LitBrazier / Haystack all leave a
## FireZone on break/ignite — this static helper instances the shared FireZone hazard and places
## it via its real `setup_rect` API, so the "leave a fire" path lives in a single function instead
## of being copy-pasted into each material. Build-once-reuse-many.

## Drop ONE FireZone (scene `fire_scene`) centred on world `pos`, sized `s`, into the current scene.
## `host` only supplies the SceneTree. Returns the spawned FireZone, or null if it couldn't spawn.
static func drop(fire_scene: PackedScene, host: Node, pos: Vector2, s: Vector2) -> Node:
	if fire_scene == null or not is_instance_valid(host):
		return null
	var tree := host.get_tree()
	if tree == null:
		return null
	var parent := tree.current_scene
	if parent == null:
		return null
	var fire := fire_scene.instantiate()
	parent.add_child(fire)
	# setup_rect takes a TOP-LEFT-anchored world rect and centres the Area's shape on it.
	fire.setup_rect(Rect2(pos - s * 0.5, s))
	return fire
