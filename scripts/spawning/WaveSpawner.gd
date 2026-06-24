class_name WaveSpawner
extends Resource
## A battle's wave script, as DATA. Holds an ordered list of `Wave` resources; a level loads
## one (`load("res://scenes/data/SampleWaves.tres")`) and calls `spawn_wave(parent, i)` to put
## wave `i` on the field. This is the data-driven version of `Battlefield._waves` — the SAME
## idea (loose mobs and cohesive formations, in order), but editable in a `.tres` instead of
## hard-coded in a script, so future levels reuse the level code and just swap the resource.
##
## It does NOT reimplement spawning: loose waves go through the shared `Spawner`, formation
## waves through the shared `Formation`. It only adds the data layer + team wiring on top.

@export var waves: Array[Wave] = []

## How many waves this script holds.
func wave_count() -> int:
	return waves.size()

## Materialize wave `index` into `parent`, reusing the shared modules. Returns the spawned
## units (a formation's `.units`, or the loose nodes from Spawner). Out-of-range → empty.
func spawn_wave(parent: Node, index: int) -> Array:
	if index < 0 or index >= waves.size():
		push_warning("WaveSpawner.spawn_wave: index %d out of range (have %d)" % [index, waves.size()])
		return []
	var wave: Wave = waves[index]
	if wave == null:
		return []
	if wave.is_formation():
		return _spawn_formation(wave, parent)
	return _spawn_loose(wave, parent)

## FORMATION path — instance the Formation block. It owns its roster + ranks; we only place it
## and stamp the team (Formation applies team to each unit before _ready, so groups are right).
func _spawn_formation(wave: Wave, parent: Node) -> Array:
	var f := wave.formation.instantiate()
	if "team" in f:
		f.team = wave.team
	f.position = Vector2((wave.x_min + wave.x_max) * 0.5, wave.lane_y)
	parent.add_child(f)   # auto_spawn formations spawn their ranks on _ready
	# Formation._rank stamps `team` onto each unit BEFORE _ready, so its units already joined
	# the right groups — no _apply_team fixup needed on this path.
	return f.units if "units" in f else []

## LOOSE path — a mob along the lane via the shared Spawner. `count`>0 with a single-scene
## roster repeats that scene (the "5 LightSoldiers" shorthand); otherwise spawn `scenes` as-is.
func _spawn_loose(wave: Wave, parent: Node) -> Array:
	var spawned: Array
	if wave.count > 0 and wave.scenes.size() == 1:
		spawned = Spawner.spawn_count(parent, wave.scenes[0], wave.count,
			wave.lane_y, wave.x_min, wave.x_max, wave.scatter)
	else:
		spawned = Spawner.spawn(parent, wave.scenes,
			wave.lane_y, wave.x_min, wave.x_max, wave.scatter)
	_apply_team(spawned, wave.team)
	return spawned

## Stamp a team onto already-spawned units and fix their team groups. Spawner instances units
## with the scene's default team (all enemy scenes ship "raiders"), so a wave that wants a
## different side re-tags here, mirroring Enemy's team groups (`<team>`, targets/allies, and
## `officers` for a support unit — which the DefeatOfficer objective counts).
func _apply_team(units: Array, team: String) -> void:
	for u in units:
		if not is_instance_valid(u) or not ("team" in u):
			continue
		if u.team == team:
			continue
		# Drop the old team's groups, set the new team, join the new groups.
		u.remove_from_group(u.team)
		u.remove_from_group("targets" if u.team == "raiders" else "allies")
		# `officers` is raiders-only (Enemy._ready): a support unit leaving the raiders is no
		# longer an enemy officer; one joining the raiders becomes one.
		if "is_support" in u and u.is_support:
			if u.team == "raiders":
				u.remove_from_group("officers")
			if team == "raiders":
				u.add_to_group("officers")
		u.team = team
		u.add_to_group(team)
		u.add_to_group("targets" if team == "raiders" else "allies")
