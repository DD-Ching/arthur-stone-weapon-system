extends Node
## Impact — the single place that decides how every hit feels.
##
## Registered as an autoload (see project.godot [autoload]), so any node can call
## it: `Impact.resolve_hit(...)`, `Impact.collide(...)`, `Impact.add_flow(...)`,
## `Impact.popup(...)`. It owns three things:
##
##   1. ALL the impact tuning numbers (mass, charge, angle, wall-crush, combo) —
##      the brief's "keep the numbers tunable in one place".
##   2. The scoring formula that turns a hit's context into knockback / damage /
##      stun / shake / a feedback label / combo gain.
##   3. The "Stone Flow" combo meter — stacks that build on good hits, decay over
##      time, and break on a whiff or exhaustion. Stacks lightly buff Arthur, but
##      never make him feel weightless.
##
## The formula is deliberately not real physics. It is:
##   score = speed × mass × charge × angle × collision_bonus × combo
## tuned until "slow touch pushes, fast swing launches, wall crush smashes".

# ── Scoring tunables ────────────────────────────────────────────────────────
@export_group("Scoring")
const REF_SPEED := 720.0      ## a solid swing's head speed; relative_speed is divided by this
const MIN_SPEED_F := 0.25     ## a slow touch still counts a little
const MAX_SPEED_F := 2.4      ## but blistering speed saturates
const REF_MASS := 4.0         ## the stone (MASS_STONE) sits above this; props below
const CHARGE_GAIN := 1.15     ## a full charge roughly doubles the score
const ANGLE_MIN := 0.55       ## a glancing, badly-aligned hit keeps just over half
const CRUSH_GAIN := 1.9       ## extra collision_bonus when fully pinned (no cushion)

# Effective mass of each "attacker" (the thing delivering the hit).
const MASS_STONE := 6.2       ## the whole liftable stone — devastating
const MASS_ROCK := 1.5        ## a launched rock
const MASS_CRATE := 1.1       ## a shoved crate
const MASS_ENEMY := 0.9       ## an enemy used as a bowling ball (low — see note below)

# score → output. NOTE on knockback: it is applied as an *impulse*, so a light
# RigidBody2D (a flung soldier) moves far on a small number while a heavy guard
# barely budges. That is the design — mass lives on the receiver, not here.
const BASE_KNOCK := 540.0
const KNOCK_MIN := 300.0
const KNOCK_MAX := 1800.0     ## headroom so a full charge still out-launches a maxed combo
const CLASH_FLOW := 6.0       ## Stone-Flow reward for parrying an enemy's strike with the stone
const DMG_BASE := 9.0
const SLAM_DAMAGE_MULT := 1.6 ## the slam's bonus damage on top of DMG_BASE (read by Shockwave)
const STUN_BASE := 0.18
const STUN_MAX := 1.6
const SHAKE_BASE := 5.5
const SHAKE_MIN := 4.0
const SHAKE_MAX := 26.0
const CRIT_SCORE := 4.2       ## above this a plain hit reads as a CRITICAL BONK

# ── Wall-crush detection ────────────────────────────────────────────────────
const CRUSH_RANGE := 50.0     ## how close a wall behind the target counts as "no cushion"
const CRUSH_MASK := 1         ## physics layer 1 = "world" (walls / obstacles)

# ── Stone Flow combo ────────────────────────────────────────────────────────
@export_group("Stone Flow")
const FLOW_MAX := 100.0
const STACK_STEP := 18.0      ## flow per stack; 5 stacks at 90, headroom to 100
const MAX_STACKS := 5
const FLOW_GRACE := 2.2       ## seconds after a hit before flow starts to decay
const FLOW_DECAY := 16.0      ## flow lost per second once decaying
const MISS_PENALTY := 24.0    ## flow lost when a swing hits nothing
const BOWL_MIN_SPEED := 230.0 ## min speed for an enemy/rock collision to "count"
const SLAM_FLOW_BASE := 9.5   ## flow per enemy a slam shockwave catches (read by Shockwave)

signal flow_changed(flow: float, stacks: int, flow_mode: bool)
signal impact_fx(strength: float)   ## camera shake / hit-stop request from non-weapon hits
signal kills_changed(kills: int, milestone: String)   ## musou KO counter

const MAX_LABELS := 16        ## cap concurrent floating labels (web: bounds node + redraw churn)
## Cap on concurrent shatter chunks (web: bounds node + redraw churn). A VAR, not a const, so a
## weaker device (a phone) can LOWER it — fewer chunks alive at once means less per-frame redraw +
## physics on a single-threaded mobile GPU/CPU. Desktop keeps DEBRIS_BUDGET_DESKTOP (90) untouched;
## only a touchscreen drops it (see `apply_mobile_profile`). Still read everywhere as
## `Impact.DEBRIS_BUDGET`, so existing readers (the shatter path, the physics-foundation test) are
## byte-identical on desktop.
const DEBRIS_BUDGET_DESKTOP := 90  ## the full desktop chunk budget — never lowered
const DEBRIS_BUDGET_MOBILE := 50   ## the lowered phone budget — fewer concurrent chunks on a weak GPU
var DEBRIS_BUDGET := DEBRIS_BUDGET_DESKTOP   ## the LIVE budget honored by shatter() (mobile lowers it)
var _mobile_profile := false  ## true once the touchscreen debris cap has been applied (idempotent)

var flow := 0.0
var stacks := 0
var flow_mode := false        ## stack 5: "Stone Flow" mode, stronger reactions
var kills := 0                ## total enemies defeated this battle (the KO count)
var _since_gain := 0.0
var _collision_cd := {}       ## shared collision debounce: instance_id -> expiry (ms)

const FLOATING_TEXT := preload("res://scenes/FloatingText.tscn")

func _process(delta: float) -> void:
	_since_gain += delta
	if flow > 0.0 and _since_gain > FLOW_GRACE:
		flow = maxf(0.0, flow - FLOW_DECAY * delta)
		_recompute()
	# Prune expired collision-debounce entries so the dict can't grow unbounded
	# (instance IDs are reused, so stale entries must not linger).
	if not _collision_cd.is_empty():
		var now := Time.get_ticks_msec()
		for id in _collision_cd.keys():
			if _collision_cd[id] <= now:
				_collision_cd.erase(id)

# ── Stone Flow API ──────────────────────────────────────────────────────────

func add_flow(amount: float) -> void:
	var before := stacks
	flow = clampf(flow + amount, 0.0, FLOW_MAX)
	_since_gain = 0.0
	_recompute()
	if stacks > before:
		Audio.play("stone_flow_gain")

## A KO — the musou counter. Fires a milestone string on the big round numbers so
## the HUD can shout RAMPAGE! etc.
func add_kill() -> void:
	kills += 1
	var milestone := ""
	match kills:
		10: milestone = "RAMPAGE!"
		25: milestone = "MASSACRE!"
		50: milestone = "WARLORD!"
		100: milestone = "LEGENDARY!"
		200: milestone = "UNSTOPPABLE!"
		400: milestone = "ONE-MAN ARMY!"
	kills_changed.emit(kills, milestone)

## A swing that connected with nothing — bleed the combo.
func note_miss() -> void:
	if flow <= 0.0:
		return
	flow = maxf(0.0, flow - MISS_PENALTY)
	_recompute()

## Stamina ran dry mid-flow — drop hard, but not always to zero.
func note_exhausted() -> void:
	flow = minf(flow, STACK_STEP)   # back down to ~1 stack
	_recompute()

## Arthur took a hit — the rhythm is broken, so the combo breaks.
func note_damage() -> void:
	flow = 0.0
	_recompute()

func reset() -> void:
	flow = 0.0
	kills = 0
	_since_gain = 0.0
	_collision_cd.clear()
	kills_changed.emit(0, "")
	_recompute()

## Lower the destruction budget for a weak device (a phone). Called ONCE by a map's _ready when a
## touchscreen is detected, so on mobile a crowd-wipe / mass shatter floats fewer concurrent chunks
## (DEBRIS_BUDGET_MOBILE 50 vs the desktop 90) — less redraw + physics on a single-threaded mobile
## GPU. Only ever REDUCES the budget (never raises a value a caller already lowered) and is
## idempotent. Desktop never calls this, so DEBRIS_BUDGET stays the full 90 = byte-identical there.
## `force` lets a headless test exercise the cap (the device reports no touchscreen).
func apply_mobile_profile(force: bool = false) -> void:
	if not (force or DisplayServer.is_touchscreen_available()):
		return
	_mobile_profile = true
	DEBRIS_BUDGET = mini(DEBRIS_BUDGET, DEBRIS_BUDGET_MOBILE)   # only ever lower it

## One shared debounce for "a flung body hit a target" — used by enemy bowling and
## prop launches so one touch scores once. Replaces per-body dictionaries that
## never pruned. Returns true if this target may be hit now.
func try_collision_hit(target_id: int, cooldown: float = 0.3) -> bool:
	var now := Time.get_ticks_msec()
	if _collision_cd.get(target_id, 0) > now:
		return false
	_collision_cd[target_id] = now + int(cooldown * 1000.0)
	return true

func _recompute() -> void:
	stacks = clampi(int(flow / STACK_STEP), 0, MAX_STACKS)
	flow_mode = stacks >= MAX_STACKS
	flow_changed.emit(flow, stacks, flow_mode)

# Stack effects. All small on purpose — buffed Arthur is still hauling a rock.
func charge_speed_mult() -> float:    # stack 1+: wind up a touch faster
	return 1.0 + 0.07 * stacks
func move_mult() -> float:            # stack 2+: a little more mobile
	return 1.0 + 0.04 * maxi(0, stacks - 1)
func force_mult() -> float:           # the combo factor; a FELT but not game-breaking crescendo —
	var m := 1.0 + 0.11 * stacks      # a maxed rampage hits ~1.9x vs a cold start, so building a
	if stacks >= 4:                   # streak amplifies your power (Musou flow-state) without
		m += 0.12                     # one-shotting the whole roster; a single cold hit stays 1.0.
	if flow_mode:
		m += 0.3
	return m

# ── The scoring formula ─────────────────────────────────────────────────────

## ctx keys: kind ("swing"/"slam"/"rock"/"crate"/"bowling"), attacker_mass,
## relative_speed, charge (0..1), angle_quality (0..1), pin (0..1), chain (int).
## Returns a Dictionary the caller applies and displays.
func resolve_hit(ctx: Dictionary) -> Dictionary:
	var kind: String = ctx.get("kind", "swing")
	var speed_f := clampf(float(ctx.get("relative_speed", REF_SPEED)) / REF_SPEED, MIN_SPEED_F, MAX_SPEED_F)
	var mass_f := float(ctx.get("attacker_mass", MASS_STONE)) / REF_MASS
	var charge: float = clampf(ctx.get("charge", 0.0), 0.0, 1.0)
	var charge_mult := 1.0 + CHARGE_GAIN * charge
	var angle_q := lerpf(ANGLE_MIN, 1.0, clampf(ctx.get("angle_quality", 1.0), 0.0, 1.0))
	var pin: float = clampf(ctx.get("pin", 0.0), 0.0, 1.0)
	var chain: int = ctx.get("chain", 0)
	var collision_bonus := _collision_bonus(kind, pin, chain)
	var combo_mult := force_mult()

	var score := speed_f * mass_f * charge_mult * angle_q * collision_bonus * combo_mult
	var info := _label_for(kind, score, pin, charge, chain)
	return {
		"score": score,
		"knockback": clampf(BASE_KNOCK * score, KNOCK_MIN, KNOCK_MAX),
		"damage": DMG_BASE * score,
		"stun": clampf(STUN_BASE * score * (0.6 + 0.8 * pin), 0.0, STUN_MAX),
		"shake": clampf(SHAKE_BASE * score, SHAKE_MIN, SHAKE_MAX),
		"label": info["text"],
		"color": info["color"],
		"flow_gain": _flow_for(kind, score, pin),
		"pin": pin,
	}

func _collision_bonus(kind: String, pin: float, chain: int) -> float:
	var b := 1.0
	match kind:
		"bowling":
			b = 1.6 + 0.3 * float(chain)
		"rock":
			b = 1.3
		"crate":
			b = 1.2
		"slam":
			b = 1.2
	return b + CRUSH_GAIN * pin   # wall crush stacks on top of any hit type

func _label_for(kind: String, score: float, pin: float, charge: float, chain: int) -> Dictionary:
	var crush_col := Color(1.0, 0.42, 0.2)
	if pin >= 0.5:
		if charge >= 0.6 or score >= 6.0:
			return {"text": "WALL CRUSH", "color": crush_col}
		if score >= 3.2:
			return {"text": "STONE PRESS", "color": crush_col}
		return {"text": "NO CUSHION", "color": Color(1.0, 0.6, 0.35)}
	match kind:
		"bowling":
			if chain >= 3:
				return {"text": "DOUBLE BONK!", "color": Color(0.6, 0.9, 1.0)}
			if chain >= 2:
				return {"text": "CHAIN IMPACT", "color": Color(0.55, 0.88, 1.0)}
			return {"text": "BOWLING HIT", "color": Color(0.5, 0.85, 1.0)}
		"rock":
			return {"text": "ROCK HIT", "color": Color(0.82, 0.74, 0.55)}
		"crate":
			return {"text": "CRATE HIT", "color": Color(0.78, 0.62, 0.4)}
		"slam":
			return {"text": "SLAM!", "color": Color(1.0, 0.8, 0.3)}
	if score >= CRIT_SCORE:
		return {"text": "CRITICAL BONK", "color": Color(1.0, 0.85, 0.3)}
	if score >= 2.0:
		return {"text": "BONK!", "color": Color(1.0, 0.97, 0.85)}
	return {"text": "", "color": Color.WHITE}   # weak taps stay quiet

func _flow_for(kind: String, score: float, pin: float) -> float:
	var base := 9.0
	match kind:
		"bowling":
			base = 14.0
		"rock", "crate":
			base = 11.0
		"slam":
			base = SLAM_FLOW_BASE
	base += 9.0 * pin
	if score >= CRIT_SCORE:
		base += 6.0
	return base

# ── Wall-crush raycast ──────────────────────────────────────────────────────

## How "pinned" the target is along `dir` (the way it is about to be knocked):
## 1.0 = a wall is right behind it (no room to fly = crush), 0.0 = open space.
## `from_node` only supplies the 2D physics world.
func cushion(from_node: Node2D, pos: Vector2, dir: Vector2) -> float:
	if not is_instance_valid(from_node):
		return 0.0
	var world := from_node.get_world_2d()
	if world == null:
		return 0.0
	var space := world.direct_space_state
	var q := PhysicsRayQueryParameters2D.create(pos, pos + dir.normalized() * CRUSH_RANGE)
	q.collision_mask = CRUSH_MASK
	q.collide_with_areas = false
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return 0.0
	var dist: float = pos.distance_to(hit["position"])
	return clampf(1.0 - dist / CRUSH_RANGE, 0.0, 1.0)

# ── One-call collision (rocks, crates, bowling) ─────────────────────────────

## Resolve and APPLY a non-weapon collision (a flung prop or enemy hitting a
## target), then pop the label, feed Stone Flow, and request shake. The weapon
## does its own richer version inline (it owns charge + the swing trail speed).
func collide(target: Object, dir: Vector2, relative_speed: float, attacker_mass: float,
		kind: String, from_node: Node2D, chain: int = 0) -> void:
	if not is_instance_valid(target) or not target.has_method("apply_hit"):
		return
	var pin := cushion(from_node, target.global_position, dir)
	var r := resolve_hit({
		"kind": kind, "attacker_mass": attacker_mass, "relative_speed": relative_speed,
		"charge": 0.0, "angle_quality": 1.0, "pin": pin, "chain": chain,
	})
	# The enemy applies its own shield block / break and tells us if it blocked.
	var res: Dictionary = target.apply_hit(dir, r["knockback"], r["stun"], r["damage"], pin)
	if not res["blocked"]:
		popup(r["label"], target.global_position + Vector2(0.0, -26.0), r["color"])
	add_flow(r["flow_gain"] * (0.4 if res["blocked"] else 1.0))
	impact_fx.emit(r["shake"])
	if kind == "bowling":
		Audio.play("chain_impact" if chain >= 2 else "enemy_launch", target.global_position)

# ── Feedback pop-up ─────────────────────────────────────────────────────────

func popup(text: String, world_pos: Vector2, color: Color = Color.WHITE, scale: float = 1.0) -> void:
	if text == "":
		return
	var scene := get_tree().current_scene
	if scene == null:
		return
	# Bound how many labels can live at once — in a chaotic combo this keeps node
	# count and per-frame redraws fixed (matters most on the single-threaded web build).
	var active := get_tree().get_nodes_in_group("floating_text")
	if active.size() >= MAX_LABELS:
		active[0].queue_free()   # retire the oldest
	var label := FLOATING_TEXT.instantiate()
	scene.add_child(label)
	label.global_position = world_pos
	label.setup(text, color, scale)

# ── Destruction (one code path for "it breaks and pieces fly out") ───────────

## Burst `count` debris chunks of `scene` out of `pos`, each flung at a random heading + a speed
## in `speed_range`. The single reusable "shatter" any breakable prop / cart / pot calls, so the
## look + the spawn cost live in ONE place. Honors DEBRIS_BUDGET so a mass shatter (a haystack
## cluster, a row of barrels) can't flood the single-threaded web build with chunks.
func shatter(scene: PackedScene, pos: Vector2, count: int,
		speed_range: Vector2 = Vector2(160.0, 340.0), tint: Color = Color(0.5, 0.36, 0.22)) -> void:
	if scene == null:
		return
	var tree := get_tree()
	if tree == null:
		return
	var parent := tree.current_scene
	if parent == null:
		return
	var live := tree.get_nodes_in_group("debris").size()
	var budget := maxi(0, DEBRIS_BUDGET - live)
	var n := mini(count, budget)
	for _i in n:
		var d = scene.instantiate()
		parent.add_child(d)
		d.global_position = pos + Vector2(randf_range(-9.0, 9.0), randf_range(-9.0, 9.0))
		if "chunk_color" in d:
			d.chunk_color = tint
		if d.has_method("apply_knockback"):
			var ang := randf() * TAU
			d.apply_knockback(Vector2(cos(ang), sin(ang)), randf_range(speed_range.x, speed_range.y))

## A radial burst from `pos`: launch + damage everything hittable within `radius`, with falloff
## to the edge. The reusable AoE for an explosive barrel or any boom (the slam keeps its own richer
## Shockwave for the wall-crush pin). `from_node` is spared (the source prop). Returns the count hit.
func explode(from_node: Node, pos: Vector2, radius: float, impulse: float, dmg: float, stun: float) -> int:
	var tree := get_tree()
	if tree == null:
		return 0
	var hit := 0
	for group in ["targets", "props"]:
		for body in tree.get_nodes_in_group(group):
			if not is_instance_valid(body) or body == from_node:
				continue
			var to: Vector2 = body.global_position - pos
			var dist := to.length()
			if dist >= radius:
				continue
			var falloff := 1.0 - dist / radius
			var dir := to.normalized() if dist > 0.01 else Vector2.RIGHT
			var strength := impulse * falloff
			if body.has_method("apply_hit"):
				body.apply_hit(dir, strength, stun * falloff, dmg * falloff, 0.0)
				add_flow(2.0 * falloff)
				hit += 1
			elif body.has_method("apply_knockback"):
				body.apply_knockback(dir, strength)
	impact_fx.emit(clampf(impulse / 800.0, 0.25, 1.0))
	popup("BOOM!", pos + Vector2(0.0, -28.0), Color(1.0, 0.62, 0.22), 1.4)
	return hit
