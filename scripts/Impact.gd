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

const MAX_LABELS := 16        ## cap concurrent floating labels (web: bounds node + redraw churn)

var flow := 0.0
var stacks := 0
var flow_mode := false        ## stack 5: "Stone Flow" mode, stronger reactions
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
	flow = clampf(flow + amount, 0.0, FLOW_MAX)
	_since_gain = 0.0
	_recompute()

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

func reset() -> void:
	flow = 0.0
	_since_gain = 0.0
	_collision_cd.clear()
	_recompute()

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
func recovery_mult() -> float:        # stack 3+: shorter recovery (multiplies the time)
	return 1.0 - 0.06 * maxi(0, stacks - 2)
func force_mult() -> float:           # the combo factor in the formula; stack 4 + mode add punch
	var m := 1.0 + 0.08 * stacks
	if stacks >= 4:
		m += 0.12
	if flow_mode:
		m += 0.25
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
	var block := 1.0
	if target.has_method("block_factor") and pin < 0.5:
		block = target.block_factor(dir)
	var r := resolve_hit({
		"kind": kind, "attacker_mass": attacker_mass, "relative_speed": relative_speed,
		"charge": 0.0, "angle_quality": 1.0, "pin": pin, "chain": chain,
	})
	target.apply_hit(dir, r["knockback"] * block, r["stun"], r["damage"] * block)
	var label: String = r["label"]
	var color: Color = r["color"]
	if block < 0.9 and pin < 0.5:
		label = "BLOCKED"
		color = Color(0.7, 0.75, 0.8)
	if label != "":
		popup(label, target.global_position + Vector2(0.0, -26.0), color)
	add_flow(r["flow_gain"] * (0.4 if block < 0.9 else 1.0))
	impact_fx.emit(r["shake"])

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
