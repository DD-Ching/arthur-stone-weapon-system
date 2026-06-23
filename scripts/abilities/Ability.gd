class_name Ability
extends RefCounted
## ONE move a unit can perform — a data-driven replacement for the old hardcoded
## attack_kind enum + flat windup/strike/recover/damage exports on Enemy.gd.
##
## A move is pure DATA (timings, ranges, damage) plus a single execute() that lands
## its effect. A unit owns a list of these (Enemy.moves); the AI picks one by range
## each time it attacks (see AbilityLibrary.choose). Because every move reuses the
## SAME hit plumbing the legacy code used — foe.take_damage() for Arthur/allies,
## foe.apply_hit() for enemy bodies, Impact for everything shared — adding a move is
## data, never new combat code. Build once, reuse many.
##
## Friendly fire is honoured here the way Enemy._find_foe() already guarantees it:
## execute() only ever acts on the `foe` the brain selected (always opposing team),
## and any AoE filters to bodies NOT in the user's team group. Raiders never hit
## raiders; allies never hit allies.

# Move flavours. The kind drives ONLY the effect + telegraph look; all numbers below
# are per-move data so two units can share a kind with different reach/damage.
#   slash   — arc melee (the default light swing)
#   thrust  — spear lunge (long, narrow; a small forward hop into the poke)
#   bash    — shield shove (short, heavy, extra knockback)
#   lunge   — foot gap-closer: a forward impulse THEN a melee hit at the end of it
#   leap    — jump to the foe + a small landing AoE around where it lands
#   javelin — ranged throw: spawns a Javelin projectile, no melee contact needed
#   pound   — ground slam: radial AoE around the user (no single foe required)
var id := "slash"
var kind := "slash"

# Range band this move is valid in (centre-to-centre distance to the foe). The brain
# prefers the gap-closer / ranged move when far and the cheap melee when close.
var min_range := 0.0
var max_range := 30.0

# Timings (seconds) — read by Enemy's WINDUP/STRIKE/RECOVER states for THIS move.
var windup := 0.45
var strike := 0.12
var recover := 0.5
var cooldown := 0.8

# Effect numbers.
var damage := 8.0
var knockback := 130.0      ## apply_hit strength used against enemy bodies (not Arthur)
var stun := 0.12            ## apply_hit stun used against enemy bodies
var lunge_impulse := 0.0    ## forward impulse on the USER on strike (gap-close / commit)

# AoE moves (leap landing, pound). Ignored by single-target kinds.
var aoe_radius := 0.0
var aoe_damage := 0.0
var aoe_knockback := 320.0

# Ranged moves (javelin).
var projectile_speed := 540.0

# Telegraph hint, so a config can override the drawn look without a new kind.
# Falls back to a sensible per-kind default (see telegraph_shape()).
var telegraph := ""

# Javelin projectile, loaded lazily so non-ranged units never touch the scene.
const JAVELIN_SCENE := "res://scenes/Javelin.tscn"


## Build a move from a plain dictionary (how AbilityLibrary and the legacy-fallback
## both author moves). Only the keys present are applied, so a config stays terse.
static func from_dict(d: Dictionary) -> Ability:
	var a := Ability.new()
	a.id = d.get("id", d.get("kind", "slash"))
	a.kind = d.get("kind", "slash")
	a.min_range = d.get("min_range", 0.0)
	a.max_range = d.get("max_range", 30.0)
	a.windup = d.get("windup", 0.45)
	a.strike = d.get("strike", 0.12)
	a.recover = d.get("recover", 0.5)
	a.cooldown = d.get("cooldown", 0.8)
	a.damage = d.get("damage", 8.0)
	a.knockback = d.get("knockback", 130.0)
	a.stun = d.get("stun", 0.12)
	a.lunge_impulse = d.get("lunge_impulse", 0.0)
	a.aoe_radius = d.get("aoe_radius", 0.0)
	a.aoe_damage = d.get("aoe_damage", 0.0)
	a.aoe_knockback = d.get("aoe_knockback", 320.0)
	a.projectile_speed = d.get("projectile_speed", 540.0)
	a.telegraph = d.get("telegraph", "")
	return a


## Is this move usable against a foe at `dist` right now? (Range band + off cooldown.)
## `cd` is the user's remaining cooldown for THIS move id (0 = ready).
func usable(dist: float, cd: float) -> bool:
	return cd <= 0.0 and dist >= min_range and dist <= max_range


## How the telegraph should read: "line" (narrow, forward — thrust/javelin/lunge) or
## "arc" (a swept melee — slash/bash) or "ring" (radial — pound/leap). Enemy's
## _draw_attack_telegraph reads this so one draw routine serves every move.
func telegraph_shape() -> String:
	if telegraph != "":
		return telegraph
	match kind:
		"thrust", "javelin", "lunge":
			return "line"
		"pound", "leap":
			return "ring"
		_:
			return "arc"


## Land this move's effect. Mirrors the semantics of the old Enemy._strike():
##   - Arthur / allies expose take_damage(dmg, from_pos) → use it (scored, lethal).
##   - enemy bodies expose apply_hit(dir, strength, stun, dmg) → use that (knockback +
##     a small scored hit so allies and raiders can kill each other).
## `user` is the attacking Enemy, `foe` the selected target, `dir` user→foe (normalised).
## All AoE/projectile spawns reuse the user's tree + the opposing-team filter so
## friendly fire can never happen.
func execute(user: Node2D, foe: Node, dir: Vector2) -> void:
	match kind:
		"javelin":
			_throw_javelin(user, dir)
		"pound":
			_radial_aoe(user, user.global_position)
		"leap":
			# The leap's forward impulse is applied as the user commits (lunge_impulse);
			# the landing burst hits whatever it lands among, around the USER.
			_hit_one(user, foe, dir)
			if aoe_radius > 0.0:
				_radial_aoe(user, user.global_position)
		_:
			_hit_one(user, foe, dir)

	# Small strike-time shove for committing MELEE moves (bash / thrust / slash), exactly like
	# the old `if attack_kind == "bash" or "thrust": apply_central_impulse(dir * 70)`. Gap-closers
	# (leap / lunge) already launched their big impulse at the wind-up start (Enemy._begin_attack),
	# so they must NOT double-apply it here.
	if lunge_impulse != 0.0 and kind != "leap" and kind != "lunge" \
			and user.has_method("apply_central_impulse"):
		user.apply_central_impulse(dir * lunge_impulse)


## Single-target hit — the shared path the legacy _strike() used.
func _hit_one(user: Node2D, foe: Node, dir: Vector2) -> void:
	if not is_instance_valid(foe):
		return
	if foe.has_method("take_damage"):
		foe.take_damage(damage, user.global_position)        # Arthur / allies
	elif foe.has_method("apply_hit"):
		foe.apply_hit(dir, knockback, stun, damage)           # enemy body


## Radial AoE around `centre` (pound; leap landing). Hits every HITTABLE body that is
## NOT on the user's team — so raiders' pounds catch Arthur + allies, allies' pounds
## catch raiders, and neither catches its own side. Cheap: one group scan, no physics
## query, distance-falloff impulse like the slam shockwave.
func _radial_aoe(user: Node2D, centre: Vector2) -> void:
	if aoe_radius <= 0.0:
		return
	var tree := user.get_tree()
	if tree == null:
		return
	var my_team: String = user.team if "team" in user else "raiders"
	for body in tree.get_nodes_in_group("hittable"):
		if body == user or not is_instance_valid(body):
			continue
		if body.is_in_group(my_team):
			continue                                          # never hit own side
		var to: Vector2 = body.global_position - centre
		var dist := to.length()
		if dist >= aoe_radius:
			continue
		var falloff := 1.0 - dist / aoe_radius
		var adir := to.normalized() if dist > 0.01 else dir_default(user)
		if body.has_method("take_damage"):
			body.take_damage(aoe_damage * falloff, centre)    # Arthur / allies
		elif body.has_method("apply_hit"):
			body.apply_hit(adir, aoe_knockback * falloff, stun, aoe_damage * falloff)
	# A little burst label so the AoE reads (kept under Impact's label cap).
	Impact.popup("SLAM", centre + Vector2(0.0, -28.0), Color(1.0, 0.7, 0.35))


## Spawn a Javelin flying along `dir`. The projectile carries the user's team so it
## only damages the opposing side, and frees itself on hit or timeout.
func _throw_javelin(user: Node2D, dir: Vector2) -> void:
	var scene: PackedScene = load(JAVELIN_SCENE)
	if scene == null:
		# No projectile scene shipped → degrade to nothing rather than erroring.
		return
	var j: Node = scene.instantiate()
	var root := user.get_tree().current_scene
	if root == null:
		j.queue_free()
		return
	root.add_child(j)
	var my_team: String = user.team if "team" in user else "raiders"
	# launch() positions + aims the projectile; kept out of _ready so the spawner
	# sets transform first (same reason Shockwave.detonate is separate).
	if j.has_method("launch"):
		j.launch(user.global_position + dir * (16.0 + 8.0), dir, projectile_speed, damage, my_team)


## A safe fallback direction when a foe sits exactly on the user (AoE math).
func dir_default(user: Node2D) -> Vector2:
	if "shield_angle" in user:
		return Vector2.RIGHT.rotated(user.shield_angle)
	return Vector2.RIGHT
