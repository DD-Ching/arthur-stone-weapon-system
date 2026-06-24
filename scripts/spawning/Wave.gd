class_name Wave
extends Resource
## One wave of a battle, described as DATA instead of code. A level loads a list of these
## (inside a WaveSpawner .tres) and materializes them in order — the same idea that
## `Battlefield._waves`/`_spawn_wave` hard-code, but now it's an editable Resource so a new
## level can ship its own wave script as a `.tres` without touching any script.
##
## A wave is EITHER a loose mob OR a cohesive formation:
##   - loose : leave `formation` null and fill `scenes` (a roster of unit scenes). `count` > 0
##             repeats a single-entry roster up to that many units (a quick "5 LightSoldiers").
##   - formation : set `formation` to a Formation scene; it marches in as a block.
## The WaveSpawner does the spawning by REUSING the shared Spawner / Formation modules.

## A short name for popups / HUD ("LIGHT RAIDERS").
@export var label: String = ""

## LOOSE path: the unit scenes to spawn along the lane. If this holds exactly one scene and
## `count` > 1, it's repeated `count` times (so a 5-LightSoldier wave is one scene + count 5).
@export var scenes: Array[PackedScene] = []

## FORMATION path: a Formation scene to instance as a block. When set, `scenes`/`count` are
## ignored — the formation owns its own roster.
@export var formation: PackedScene

## LOOSE: how many to spawn when `scenes` has a single entry to repeat. 0 → spawn `scenes` as-is.
@export var count: int = 0

## Where the wave arrives: the lane y and the x band it spreads across, plus jitter.
@export var lane_y: float = -490.0
@export var x_min: float = -380.0
@export var x_max: float = 380.0
@export var scatter: bool = true

## Which side these units fight for ("raiders" = attackers; "allies"/other = reinforcements).
@export var team: String = "raiders"

## Seconds a scheduler may wait before this wave (advisory — the spawner just reads it).
@export var delay: float = 0.0

## True when this wave marches in as a cohesive Formation rather than a loose mob.
func is_formation() -> bool:
	return formation != null
