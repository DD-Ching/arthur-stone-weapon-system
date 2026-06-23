class_name AbilityLibrary
extends RefCounted
## The registry of named moves. A unit config lists move IDs (Enemy.moves) and this
## hands back fresh Ability instances for them, so authoring a varied moveset is a
## PackedStringArray in a .tscn — no new script. "Build once, reuse many."
##
## Two entry points the brain uses:
##   build_for(ids) → an Array[Ability] for a unit's move list (instances are per-unit
##                    so cooldowns can be tracked per id without shared state).
##   choose(moves, dist, cooldowns) → the best applicable move for the current range,
##                    preferring a gap-closer/ranged option when far and cheap melee
##                    when close; null when nothing is in range / off cooldown.
##
## Timings + damage are tuned in the spirit of the existing configs: light melee ~6,
## thrust ~9, bash ~10. New moves (lunge/leap/javelin/pound) sit around those so a
## mixed warband stays readable and the existing tests' balance is untouched.

# Master table: id → authoring dict (see Ability.from_dict). Kept as plain data so the
# whole catalogue is greppable and a config can copy a row to tweak it.
const TABLE := {
	# ── the three legacy kinds, as data (used when a config opts into `moves`) ──
	"slash": {
		"kind": "slash", "min_range": 0.0, "max_range": 30.0,
		"windup": 0.4, "strike": 0.1, "recover": 0.45, "cooldown": 1.0,
		"damage": 6.0, "knockback": 130.0, "stun": 0.12,
	},
	"thrust": {
		"kind": "thrust", "min_range": 40.0, "max_range": 120.0,
		"windup": 0.55, "strike": 0.14, "recover": 0.5, "cooldown": 1.0,
		"damage": 9.0, "knockback": 150.0, "stun": 0.12, "lunge_impulse": 70.0,
	},
	"bash": {
		"kind": "bash", "min_range": 0.0, "max_range": 34.0,
		"windup": 0.5, "strike": 0.12, "recover": 0.55, "cooldown": 1.0,
		"damage": 10.0, "knockback": 260.0, "stun": 0.2, "lunge_impulse": 70.0,
	},
	# ── new gap-closers / ranged / AoE ──
	"lunge": {
		# A foot gap-closer: commits forward HARD then lands a melee at the lunge's end.
		"kind": "lunge", "min_range": 60.0, "max_range": 150.0,
		"windup": 0.5, "strike": 0.12, "recover": 0.55, "cooldown": 1.6,
		"damage": 8.0, "knockback": 200.0, "stun": 0.15, "lunge_impulse": 320.0,
	},
	"leap": {
		# Jump to the foe + a small landing burst. Slower to recover (it commits).
		"kind": "leap", "min_range": 80.0, "max_range": 220.0,
		"windup": 0.6, "strike": 0.14, "recover": 0.7, "cooldown": 2.4,
		"damage": 9.0, "knockback": 180.0, "stun": 0.18, "lunge_impulse": 460.0,
		"aoe_radius": 70.0, "aoe_damage": 6.0, "aoe_knockback": 300.0,
	},
	"javelin": {
		# Ranged opener: thrown from afar, no melee contact. Long cooldown so a
		# skirmisher still has to close eventually.
		"kind": "javelin", "min_range": 160.0, "max_range": 420.0,
		"windup": 0.55, "strike": 0.1, "recover": 0.45, "cooldown": 2.2,
		"damage": 8.0, "projectile_speed": 540.0,
	},
	"pound": {
		# Ground slam: radial AoE around the user, no single foe needed. The heavy's
		# crowd-control move.
		"kind": "pound", "min_range": 0.0, "max_range": 60.0,
		"windup": 0.7, "strike": 0.16, "recover": 0.7, "cooldown": 2.6,
		"damage": 0.0, "aoe_radius": 110.0, "aoe_damage": 12.0, "aoe_knockback": 420.0,
		"stun": 0.25,
	},
}


## Every move, freshly built — handy for tests / tools. Returns Array[Ability].
static func build_all() -> Array:
	var out: Array = []
	for id in TABLE.keys():
		out.append(get_move(id))
	return out


## A fresh Ability for one id, or null if the id is unknown. (Named get_move, not
## `get`, to avoid shadowing Object.get.)
static func get_move(id: String) -> Ability:
	if not TABLE.has(id):
		return null
	# Stamp the dict's own id in so a row keyed differently still self-identifies.
	var d: Dictionary = TABLE[id].duplicate()
	d["id"] = id
	return Ability.from_dict(d)


## Build the Ability list for a unit's `moves` PackedStringArray. Unknown ids are
## skipped (a typo in a .tscn shouldn't crash the battle). Returns Array[Ability].
static func build_for(ids) -> Array:
	var out: Array = []
	for id in ids:
		var a := get_move(id)
		if a != null:
			out.append(a)
	return out


## Pick the best move for the foe at `dist`, honouring per-id cooldowns. `cooldowns`
## is a Dictionary {id: seconds_remaining}; a missing/<=0 entry means ready.
##
## Selection rule (matches the brief "prefer a gap-closer when far, melee when close"):
##   among all USABLE moves (in range + off cooldown), pick the one whose range band
##   sits FARTHEST out — i.e. the largest max_range. When far that naturally selects a
##   javelin/leap/lunge; once the foe is inside melee only the melee bands qualify, so
##   the cheap swing wins. Returns null if nothing is applicable right now.
static func choose(moves, dist: float, cooldowns: Dictionary) -> Ability:
	var best: Ability = null
	var best_reach := -1.0
	for m in moves:
		var ab: Ability = m
		var cd: float = cooldowns.get(ab.id, 0.0)
		if not ab.usable(dist, cd):
			continue
		if ab.max_range > best_reach:
			best_reach = ab.max_range
			best = ab
	return best
