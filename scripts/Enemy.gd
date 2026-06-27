class_name Enemy
extends RigidBody2D
## A battlefield enemy. One script, several flavours — each enemy *type* is just
## this scene with different exported values, so adding a type costs a .tscn.
##
## Two layers live here, and the seam between them is the whole point:
##   - a PHYSICS body: it collides with walls, props, and other enemies, is shoved
##     by the stone, launches when hit, and BOWLS into other enemies for chain hits;
##   - an AI brain (optional): it approaches Arthur, keeps its shield toward him,
##     and lands a telegraphed attack.
## When the enemy is calm it steers; when it is launched or staggered it goes limp
## and the physics carries it. So Arthur's strength always wins the physical
## contest — a hard enough hit interrupts any attack and throws the soldier.

@export_group("Identity")
@export var enemy_name := "Dummy"
@export_enum("dummy", "soldier", "shield", "heavy", "spear", "banner", "knight", "excalibur", "sorceress", "mordred", "black_knight", "warlord") var look := "dummy"
@export var radius := 16.0
@export var base_color := Color(0.78, 0.32, 0.33)
## "raiders" = the warband attacking across the ford (Arthur's foe). "ally" = a footman
## fighting FOR Arthur. The team decides who this unit hunts and who may hit it.
@export var team := "raiders"
## Three-Kingdoms allegiance, used only for COLOUR theming (魏 Wei blue / 蜀 Shu green /
## 吳 Wu red / neutral grey). It does NOT change targeting — `team` ("raiders"/"ally") still
## decides who hunts whom; faction is pure readability flavour.
@export_enum("neutral", "camelot", "saxon", "rebel", "wei", "shu", "wu") var faction := "neutral"
## A named general (武將), a boss-tier unit: joins the "generals" group so the boss-healthbar
## UI can track it. Otherwise it is an ordinary configurable Enemy.
@export var is_general := false

@export_group("Defense")
@export var max_health := 1.0e9         ## dummies: effectively a punching bag
@export var shielded := false
@export var shield_block := 0.22        ## fraction of a frontal hit that gets through
@export var shield_break_threshold := 900.0  ## hit strength that overwhelms the shield briefly
@export var stagger_threshold := 620.0  ## hit strength that interrupts the AI (stagger)

@export_group("AI")
@export var ai_enabled := false         ## off by default → passive dummy / sandbox
@export var move_speed := 88.0
@export var move_accel := 620.0
@export var control_regain := 160.0     ## above this speed it's "flying" → physics, not AI
@export var keep_distance := 0.0        ## >0: spacing enemy (spearman) holds this range
@export var sight_range := 240.0        ## within this it engages a foe; beyond it marches to the goal
@export var avoid_danger := true        ## route around "danger_terrain" zones toward a "crossing"
@export_enum("none", "melee", "thrust", "bash") var attack_kind := "none"
@export var attack_range := 30.0
@export var attack_damage := 8.0
@export var attack_windup := 0.45       ## telegraph time before the strike
@export var attack_strike := 0.12
@export var attack_recover := 0.5
@export var attack_cooldown := 0.8
## Optional data-driven moveset (ability ids from AbilityLibrary.TABLE: slash / thrust / bash /
## lunge / leap / javelin / pound). EMPTY → use the legacy attack_kind exports above, so every
## existing .tscn is byte-for-byte unchanged. A config that lists moves picks among them by range.
@export var moves: PackedStringArray = PackedStringArray()
@export var guard_range := 64.0         ## shielded: slow + raise shield inside this

@export_group("Support")
@export var is_support := false         ## banner: on death, nearby enemies panic
@export var morale_radius := 190.0

enum AI { APPROACH, GUARD, WINDUP, STRIKE, RECOVER }

var shield_angle := PI    ## which way the shield/facing points (radians)
var health := 0.0
var hit_count := 0
var _flash := 0.0
var _stun := 0.0          ## stun / stagger seconds remaining (vulnerable, can't act)
var _t := 0.0
var _dead := false
var _alpha := 1.0
var _spawn_in := 0.0      ## >0 = fading IN on spawn (units march on, they don't pop into being)
var _chain := 0
var _shield_broken := 0.0 ## seconds the shield is overwhelmed
var _player = null        ## current FOE to attack (Arthur/ally for raiders; a raider for allies)
var _ai := AI.APPROACH
var _ai_time := 0.0
var _atk_cd := 0.0
var _did_strike := false
var _abilities: Array = []          ## built Ability list (from `moves`, or the legacy synth)
var _ability_cd := {}               ## per-move-id cooldown seconds remaining
var _cur_ability: Ability = null    ## the move chosen for the current windup/strike/recover
var _face := PI           ## facing toward the foe (for weapons / telegraphs)
var _flank := 0.0         ## side bias so non-shield units surround instead of clumping
var _steer_bias := 1.0    ## stable ±1 so wall-avoidance commits to one end (even for shields)
var _retarget_cd := 0.0   ## throttle for re-scanning for the nearest foe + separation + terrain
var _separation := Vector2.ZERO  ## steering away from nearby same-team units (no stacking)
var _last_pos := Vector2.ZERO    ## last frame's position, for stuck detection
var _stuck_t := 0.0       ## seconds spent trying-but-failing to move (wall/jam)
var _danger_zones: Array = []    ## cached "danger_terrain" (deep water) to route around
var _crossings: Array = []       ## cached "crossing" markers (bridges/fords) to aim at
var _goal_node = null            ## cached march goal (the ford banner), refreshed on retarget
var _ally_goal = null            ## cached ally muster marker (the front), refreshed on retarget
var _last_face := 0.0            ## last-drawn facing, for the dirty-redraw gate (swarm perf)
var _last_ai := -1               ## last-drawn AI state, for the dirty-redraw gate
var _steer_tick := 0            ## counts down to the next wall-avoidance recompute (throttle)
var _cached_avoid := Vector2.RIGHT  ## last computed avoidance direction (reused between recomputes)
var _cached_avoid_in := Vector2.RIGHT  ## the desired heading the cached avoid was computed for
var _rerouting := false          ## currently steering around danger, not pursuing the foe
var _space: PhysicsDirectSpaceState2D = null  ## world physics space, refreshed on the retarget tick
## TOUCH OFF-SCREEN REDRAW SKIP (mobile swarm perf, see _process). On a touchscreen ONLY, a unit far
## from Arthur (the camera target) is off the phone's view, so re-tessellating its silhouette is wasted
## work. `_touch` is the device check, cached once so it costs nothing per frame; on DESKTOP it is
## false and the whole skip path is dead, so the dirty-redraw stays byte-identical there. `_offscreen`
## remembers last frame so the unit forces ONE redraw the moment it scrolls back on-screen.
static var _touch := DisplayServer.is_touchscreen_available()
var _offscreen := false           ## was off the phone's view last frame (touch only)

## The faction's banner colour, used by the drawing pass to tint a unit so allegiance reads at a
## glance (no gameplay effect). Arthurian: Camelot gold / Saxon moss-green / Mordred's rebels
## black-purple. Three Kingdoms (the bonus maps): Wei blue / Shu green / Wu red. Else neutral grey.
func faction_color() -> Color:
	match faction:
		"camelot": return Color(0.92, 0.78, 0.30)
		"saxon": return Color(0.40, 0.46, 0.27)
		"rebel": return Color(0.52, 0.33, 0.60)
		"wei": return Color(0.30, 0.52, 0.95)
		"shu": return Color(0.36, 0.78, 0.42)
		"wu": return Color(0.86, 0.36, 0.34)
		_: return Color(0.70, 0.70, 0.72)

func _ready() -> void:
	add_to_group("hittable")
	add_to_group(team)
	# Raiders are the "targets" Arthur's weapon/objective/terrain act on; allies are not.
	add_to_group("targets" if team == "raiders" else "allies")
	if is_support and team == "raiders":
		add_to_group("officers")     # the DefeatOfficer objective counts this group
	if is_general:
		add_to_group("generals")     # the boss-healthbar UI tracks named generals (武將)
	# Non-shield units pick a side to flank from, so a crowd surrounds rather than stacks.
	if not shielded:
		_flank = -1.0 if (randf() < 0.5) else 1.0
	# A stable side for wall-rounding: reuse the flank if it has one, else pick once at random so
	# a unit dead-centre on a wall still commits to an end instead of jittering.
	_steer_bias = _flank if _flank != 0.0 else (1.0 if randf() < 0.5 else -1.0)
	health = max_health
	# Build the moveset: data-driven if the config opted in, else synthesise ONE move from the
	# legacy attack_kind/timing/damage exports so every existing .tscn behaves exactly as before.
	if moves.size() > 0:
		_abilities = AbilityLibrary.build_for(moves)
	elif attack_kind != "none":
		_abilities = [Ability.from_dict({
			"id": attack_kind, "kind": attack_kind,
			"min_range": 0.0, "max_range": attack_range,
			"windup": attack_windup, "strike": attack_strike,
			"recover": attack_recover, "cooldown": attack_cooldown,
			"damage": attack_damage, "knockback": 130.0, "stun": 0.12,
			"lunge_impulse": (70.0 if attack_kind == "bash" or attack_kind == "thrust" else 0.0),
		})]
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	# Fade in on spawn (the inverse of the death fade) so reinforcements + the opening host arrive
	# as a quick "materialise" rather than popping into being at full opacity. Cosmetic only — it
	# touches _alpha, never physics, groups, or hit maths, so every .tscn behaves the same.
	_spawn_in = 0.3
	_alpha = 0.0

# ── taking a hit ────────────────────────────────────────────────────────────

## Hard cap on a body's speed (px/s) — clamped every physics step in _integrate_forces so a single
## max hit can NEVER tunnel a light unit clean through the (now 64px) world wall in one step. Still
## a big, satisfying fling (~43px/step); residual escapes are caught by BattleMap's win-safety net.
const MAX_LAUNCH_SPEED := 2600.0

## Cap the rigid body's speed every physics step (anti-tunnelling). Cheap: one length check.
func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if state.linear_velocity.length() > MAX_LAUNCH_SPEED:
		state.linear_velocity = state.linear_velocity.limit_length(MAX_LAUNCH_SPEED)

## Low-level: an impulse + a flash. Used by the slam shockwave and by anything
## that only wants to shove (kept for back-compat with the swing/tests).
func apply_knockback(dir: Vector2, strength: float) -> void:
	apply_central_impulse(dir * strength)
	_flash = 0.18
	hit_count += 1

## Full hit. `raw_strength`/`raw_dmg` are the hit BEFORE the shield reduces them;
## the enemy owns its own shield maths so the decision is always made on the real
## blow: a strong enough hit STAGGERS and BREAKS the shield even though the shield
## softens the knockback that lands. That's Arthur's strength overruling a
## soldier's defense — the brief's core power rule. `pin` (wall-crush) bypasses the
## shield entirely. Returns {blocked, broke} so the caller can pick the feedback.
func apply_hit(dir: Vector2, raw_strength: float, stun_time: float, raw_dmg: float, pin: float = 0.0) -> Dictionary:
	var block := 1.0
	if pin < 0.5:
		block = block_factor(dir)
	apply_knockback(dir, raw_strength * block)
	if stun_time > 0.0:
		stun(stun_time)
	if raw_strength >= stagger_threshold:
		stun(maxf(stun_time, 0.5))
		_interrupt()
		Audio.play("enemy_launch", global_position)
	var broke := false
	if shielded and raw_strength >= shield_break_threshold and _shield_broken <= 0.0:
		_shield_broken = 3.0
		broke = true
		Impact.popup("SHIELD BREAK", global_position + Vector2(0, -30), Color(1.0, 0.8, 0.4), 1.1)
		Audio.play("shield_break", global_position)
	health -= raw_dmg * block
	if health <= 0.0 and not _dead:
		_defeat()
	var blocked := block < 0.9 and not broke
	if blocked:
		Impact.popup("BLOCKED", global_position + Vector2(0, -26), Color(0.7, 0.75, 0.8))
		Audio.play("shield_block", global_position)
	return {"blocked": blocked, "broke": broke}

## How much of a frontal hit a shield lets through (1.0 = no shield / flanked /
## broken). A hit pushes the target along `dir`; the shield blocks if it faces in.
func block_factor(dir: Vector2) -> float:
	if not shielded or _dead or _shield_broken > 0.0:
		return 1.0
	var facing := Vector2.RIGHT.rotated(shield_angle)
	if facing.dot(dir) < -0.35:   # force comes from the shielded side
		return shield_block
	return 1.0

func stun(duration: float) -> void:
	_stun = maxf(_stun, duration)

func _interrupt() -> void:
	_ai = AI.APPROACH
	_ai_time = 0.0
	_did_strike = false

## True while this unit is winding up or landing an attack — the stone reads this to PARRY a clash.
func is_striking() -> bool:
	return _ai == AI.WINDUP or _ai == AI.STRIKE

## The stone CLASHED with this unit's raised weapon mid-strike — cancel the strike, knock it back a
## little, and stagger it briefly. A real weapon-on-weapon parry, not just a visual. `dir` is the
## push direction (away from the stone).
func parry_strike(dir: Vector2) -> void:
	if _dead:
		return
	_did_strike = true   # cancel the pending hit of this strike
	_interrupt()
	stun(0.4)
	apply_central_impulse(dir * 220.0)
	_flash = 0.2

func _defeat() -> void:
	_dead = true
	_chain = 0
	set_deferred("collision_layer", 0)   # stop colliding, keep sliding out
	# Objectives count the defeat IMMEDIATELY, not after the ~0.6s fade-out.
	remove_from_group("shieldwall")
	remove_from_group("officers")        # so DefeatOfficer sees the kill the instant it lands
	remove_from_group("generals")        # so DefeatGeneral (boss-gated win) registers immediately
	Impact.popup("DOWN!", global_position + Vector2(0, -28), Color(1.0, 0.9, 0.4), 1.1)
	# A fallen ALLY costs you nothing (no KO/flow); only raiders feed the counter.
	if team == "raiders":
		Impact.add_flow(10.0)
		Impact.add_kill()                # the musou KO counter
		# A little death-pop: a few body-coloured chunks fly out so clearing the swarm reads as
		# impact (budgeted by Impact.shatter so a crowd-wipe can't flood the single-thread web build).
		Impact.shatter(preload("res://scenes/props/ChunkDebris.tscn"), global_position, 3,
			Vector2(110.0, 230.0), base_color)
	if is_support:
		# A banner bearer falling rattles the line.
		Impact.popup("MORALE BROKEN", global_position + Vector2(0, -48), Color(1.0, 0.5, 0.3), 1.2)
		Audio.play("banner_down", global_position)
		for e in get_tree().get_nodes_in_group("targets"):
			if e != self and is_instance_valid(e) and e.has_method("stun") \
					and e.global_position.distance_to(global_position) < morale_radius:
				e.stun(1.3)

# ── bowling: flung into another enemy ───────────────────────────────────────

func _on_body_entered(body: Node) -> void:
	if _dead or not is_instance_valid(body):
		return
	if not body.is_in_group("targets"):
		return
	var speed := linear_velocity.length()
	if speed < Impact.BOWL_MIN_SPEED:
		return
	if body is RigidBody2D and body.linear_velocity.length() > speed:
		return
	if not Impact.try_collision_hit(body.get_instance_id()):
		return
	_chain += 1
	var dir: Vector2 = (body.global_position - global_position).normalized()
	Impact.collide(body, dir, speed, Impact.MASS_ENEMY, "bowling", self, _chain)

# ── AI + steering ───────────────────────────────────────────────────────────

func _physics_process(delta: float) -> void:
	if _dead or not ai_enabled:
		return
	var speed := linear_velocity.length()
	# Launched or staggered → go limp, let the physics throw us. Arthur's hit wins.
	if _stun > 0.0 or speed > control_regain:
		return
	# Re-scan for the nearest foe + recompute crowd separation a few times a second.
	# Throttle on the timer ALONE — a unit with no foe (e.g. an ally between waves) must
	# not re-scan groups every frame; just drop a foe that was freed since the last scan.
	_retarget_cd -= delta
	if _retarget_cd <= 0.0:
		_retarget_cd = 0.25
		_player = _find_foe()
		_separation = _separation_vector()
		# Cache the world physics space for the wall-avoidance raycasts (cheap, 4x/sec).
		_space = get_world_2d().direct_space_state
		# Cache the (static) terrain + march goal so per-frame steering doesn't re-scan groups.
		if avoid_danger:
			_danger_zones = get_tree().get_nodes_in_group("danger_terrain")
			_crossings = get_tree().get_nodes_in_group("crossing")
		if team == "raiders":
			_goal_node = get_tree().get_first_node_in_group("ford_goal")
		else:
			# Allies aim at the muster marker by the enemy lane, so a pre-placed line ADVANCES
			# toward the front from frame 0 instead of standing idle until a raider strays near.
			_ally_goal = get_tree().get_first_node_in_group("ally_goal")
	elif _player != null and not is_instance_valid(_player):
		_player = null

	# Where to MARCH (the ford goal for raiders / the nearest raider for allies) and the
	# FOE to fight if one blocks the way. Distance/angle are measured to the foe.
	var foe_dist := INF
	var dir := Vector2.RIGHT
	if is_instance_valid(_player):
		var to_foe: Vector2 = _player.global_position - global_position
		foe_dist = to_foe.length()
		dir = to_foe / maxf(foe_dist, 0.001)
		_face = dir.angle()
		if shielded:
			shield_angle = _face            # keep the shield toward whatever it's fighting
	if _atk_cd > 0.0:
		_atk_cd -= delta
	# Tick down each move's own cooldown so a multi-move unit paces each move independently.
	for id in _ability_cd.keys():
		if _ability_cd[id] > 0.0:
			_ability_cd[id] = maxf(0.0, _ability_cd[id] - delta)
	_ai_time += delta

	match _ai:
		AI.APPROACH:
			_rerouting = false
			if foe_dist <= sight_range:
				# A foe is in sight — but if deep water blocks the straight line to it,
				# route around to the crossing first (don't just wade in toward Arthur).
				var sdir := _avoid_redirect(dir)
				if sdir.dot(dir) < 0.9:
					_rerouting = true
					_face = sdir.angle()
					if shielded:
						shield_angle = _face
					linear_velocity = linear_velocity.move_toward(sdir * move_speed + _separation * 40.0, move_accel * delta)
				else:
					linear_velocity = linear_velocity.move_toward(_approach_velocity(dir, foe_dist), move_accel * delta)
					if _atk_cd <= 0.0 and _attack_ready(foe_dist):
						_begin_attack(foe_dist)
					elif shielded and foe_dist <= guard_range:
						_ai = AI.GUARD
						_ai_time = 0.0
			else:
				linear_velocity = linear_velocity.move_toward(_march_velocity(), move_accel * delta)
		AI.GUARD:
			linear_velocity = linear_velocity.move_toward(dir * move_speed * 0.3 + _separation * 36.0, move_accel * delta)
			if foe_dist > guard_range * 1.5:
				_ai = AI.APPROACH
			elif _atk_cd <= 0.0 and _ai_time > 0.45 and _guard_attack_ready(foe_dist):
				_begin_attack(foe_dist)
		AI.WINDUP:
			linear_velocity = linear_velocity.move_toward(Vector2.ZERO, move_accel * delta)
			if _ai_time >= _cur_windup():
				_ai = AI.STRIKE
				_ai_time = 0.0
				_did_strike = false
		AI.STRIKE:
			if not _did_strike:
				_did_strike = true
				# AoE / ranged moves (pound / javelin) don't need the foe in melee reach.
				var reach: float = _cur_ability.max_range if _cur_ability != null else attack_range
				if _cur_is_ranged_or_aoe() or foe_dist <= reach + radius + 6.0:
					_strike(_player, dir)
			if _ai_time >= _cur_strike():
				_ai = AI.RECOVER
				_ai_time = 0.0
		AI.RECOVER:
			linear_velocity = linear_velocity.move_toward(Vector2.ZERO, move_accel * delta)
			if _ai_time >= _cur_recover():
				_ai = AI.APPROACH
				_ai_time = 0.0
				if moves.is_empty():
					_atk_cd = attack_cooldown          # legacy single-attack pacing, verbatim
				else:
					_atk_cd = 0.0                      # multi-move: per-move cooldowns pace it
					if _cur_ability != null:
						_ability_cd[_cur_ability.id] = _cur_ability.cooldown

	# Stuck recovery: if it's actually TRYING to advance but barely moved (jammed on a wall
	# or a pile of bodies), slip sideways. Skip it for a spacing unit holding its band (it's
	# waiting, not stuck) and never nudge a unit into the danger it's avoiding.
	if _ai == AI.APPROACH and _wants_to_advance():
		if global_position.distance_to(_last_pos) < 0.6:
			_stuck_t += delta
			if _stuck_t > 0.4:
				# Turn toward whichever side is ACTUALLY clear (biased to the goal heading),
				# instead of a fixed flank that could re-shove us into the same corner.
				var goal_dir := Vector2.RIGHT.rotated(_face)
				var open := Steering.most_open_dir(_space, global_position, radius, goal_dir, get_rid())
				if not _danger_ahead(global_position + open * (radius + 20.0)):
					linear_velocity = (linear_velocity + open * move_speed * 0.9).limit_length(move_speed)
				_stuck_t = 0.0
		else:
			_stuck_t = 0.0
	else:
		_stuck_t = 0.0
	_last_pos = global_position

## Is the unit actually trying to move this frame (vs. a spearman deliberately holding its
## spacing band, which must not be mistaken for "stuck")?
func _wants_to_advance() -> bool:
	if keep_distance <= 0.0:
		return true
	if not is_instance_valid(_player):
		return true
	var d := global_position.distance_to(_player.global_position)
	return d < keep_distance - 12.0 or d > keep_distance + 40.0

## Steering when a foe is in reach: spacing for spearmen, flank + separation for the rest.
func _approach_velocity(dir: Vector2, dist: float) -> Vector2:
	if keep_distance > 0.0:                    # spacing enemy (spearman)
		if dist < keep_distance - 12.0:
			return -dir * move_speed + _separation * 36.0    # too close — back off
		if dist > keep_distance + 40.0:
			return dir * move_speed + _separation * 36.0     # too far — close in
		return _separation * 30.0                            # hold the line, but don't stack
	# Flank: non-shield units curve toward the foe's side so a crowd surrounds it.
	var d := dir
	if _flank != 0.0 and dist > attack_range + 18.0:
		d = (dir + Vector2(-dir.y, dir.x) * _flank * 0.55).normalized()
	d = _avoid(d)   # round fences while closing in (throttled wall-avoidance — swarm perf)
	return d * move_speed + _separation * 40.0

## Steering while marching toward the goal (no foe in reach), still anti-stacking.
## If dangerous terrain (deep water) is right ahead, steer toward the nearest crossing
## (a bridge/ford) instead of wading in — this is what funnels a warband into a chokepoint.
func _march_velocity() -> Vector2:
	var to_goal: Vector2 = _goal_position() - global_position
	var gdir := to_goal / maxf(to_goal.length(), 0.001)
	gdir = _avoid_redirect(gdir)                                           # route around deep water first
	gdir = _avoid(gdir)  # then bend around walls (throttled wall-avoidance — swarm perf)
	_face = gdir.angle()
	if shielded:
		shield_angle = _face
	return gdir * move_speed + _separation * 40.0

## Wall-avoidance (Steering.avoid casts 3 rays) THROTTLED to ~every 3rd physics frame and reused
## between recomputes — walls are static, so the deflection is stable frame-to-frame; recomputing
## it per soldier every frame is pure cost at swarm scale. Recomputes early if the desired heading
## swings hard (a new foe / a turn) so responsiveness is preserved where it matters.
func _avoid(desired: Vector2) -> Vector2:
	# In OPEN ground the wall deflection is stable, so recompute it only every 3rd frame. BUT the
	# moment the last probe actually DEFLECTED us (we're in wall contact — output != input) recompute
	# EVERY frame, so a unit sliding along / pressed into a wall re-probes immediately and slips off
	# instead of grinding/sticking for 2 stale frames. That kills the "stuck on an invisible wall" feel.
	var in_contact := not _cached_avoid.is_equal_approx(_cached_avoid_in)
	_steer_tick -= 1
	if in_contact or _steer_tick <= 0 or desired.dot(_cached_avoid_in) < 0.6:
		_steer_tick = 3
		_cached_avoid = Steering.avoid(_space, global_position, radius, desired, get_rid(), _steer_bias)
		_cached_avoid_in = desired
	return _cached_avoid

## If deep water is right ahead along `desired`, return a direction toward the nearest
## crossing instead; otherwise return `desired` unchanged. Used by both the march and the
## engage path, so a unit never wades into a danger zone it could go around.
func _avoid_redirect(desired: Vector2) -> Vector2:
	if not avoid_danger or _danger_zones.is_empty():
		return desired
	var ahead := global_position + desired * (radius + 30.0)
	if _danger_ahead(ahead) and not _danger_ahead(global_position):
		var cross := _nearest_crossing()
		if cross.x < INF:
			return (cross - global_position).normalized()
	return desired

func _danger_ahead(p: Vector2) -> bool:
	for z in _danger_zones:
		if is_instance_valid(z) and z.contains(p):
			return true
	return false

func _nearest_crossing() -> Vector2:
	var best := Vector2(INF, INF)
	var bd := INF
	for c in _crossings:
		if not is_instance_valid(c):
			continue
		var d: float = global_position.distance_squared_to(c.global_position)
		if d < bd:
			bd = d
			best = c.global_position
	return best

func _begin_attack(foe_dist: float = INF) -> void:
	_cur_ability = _pick_ability(foe_dist)
	_ai = AI.WINDUP
	_ai_time = 0.0
	_did_strike = false
	# Gap-closers (leap / lunge) commit their travel at the START of the wind-up, so the body
	# crosses the gap DURING the wind-up and arrives as the strike lands — a real pounce, not a
	# hit from afar. (bash / thrust keep their small strike-time lunge inside Ability.execute.)
	if _cur_ability != null and (_cur_ability.kind == "leap" or _cur_ability.kind == "lunge") \
			and is_instance_valid(_player):
		var to: Vector2 = _player.global_position - global_position
		if to.length() > 0.001:
			apply_central_impulse(to.normalized() * _cur_ability.lunge_impulse)

## Best in-range, off-cooldown move for the foe at `dist`; null if none / no moveset.
func _pick_ability(dist: float) -> Ability:
	if _abilities.is_empty():
		return null
	return AbilityLibrary.choose(_abilities, dist, _ability_cd)

## APPROACH may start an attack when a move is in range (moves config), or — legacy — when the
## single attack_kind is within attack_range. Keeps every existing config identical.
func _attack_ready(dist: float) -> bool:
	if not moves.is_empty():
		return _pick_ability(dist) != null
	return attack_kind != "none" and dist <= attack_range

## GUARD (shielded) starts an attack without a range gate, exactly like the legacy code; a moves
## config still requires a usable move.
func _guard_attack_ready(dist: float) -> bool:
	if not moves.is_empty():
		return _pick_ability(dist) != null
	return attack_kind != "none"

# Per-move timing accessors — fall back to the flat legacy exports when no move is selected (e.g. a
# shielded unit that wound up out of range), so those legacy paths still behave as before.
func _cur_windup() -> float:
	return _cur_ability.windup if _cur_ability != null else attack_windup
func _cur_strike() -> float:
	return _cur_ability.strike if _cur_ability != null else attack_strike
func _cur_recover() -> float:
	return _cur_ability.recover if _cur_ability != null else attack_recover
func _cur_is_ranged_or_aoe() -> bool:
	return _cur_ability != null and (_cur_ability.kind == "javelin" or _cur_ability.kind == "pound")

## Land a hit on the current foe — Arthur takes scaled damage; a unit takes a small
## scored hit (so allies and raiders can actually kill each other).
func _strike(foe, dir: Vector2) -> void:
	# Delegate to the chosen move (take_damage/apply_hit for single target, an AoE for pound/leap,
	# a projectile for javelin — all mirroring the old semantics). Fall back to the legacy single
	# hit only if no move was selected (e.g. a shielded whiff with no usable ability).
	if _cur_ability != null:
		_cur_ability.execute(self, foe, dir)
		return
	if not is_instance_valid(foe):
		return
	if foe.has_method("take_damage"):
		foe.take_damage(attack_damage, global_position)
	elif foe.has_method("apply_hit"):
		foe.apply_hit(dir, 130.0, 0.12, attack_damage)
	if attack_kind == "bash" or attack_kind == "thrust":
		apply_central_impulse(dir * 70.0)   # lunge into the strike

## The nearest enemy of the opposing team — Arthur or an ally for a raider; a raider
## for an ally.
func _find_foe() -> Node2D:
	if team == "raiders":
		var best = get_tree().get_first_node_in_group("player")
		var bd := INF
		if best != null and is_instance_valid(best):
			bd = global_position.distance_squared_to(best.global_position)
		for a in get_tree().get_nodes_in_group("allies"):
			if not is_instance_valid(a) or (a is Enemy and a._dead):
				continue
			var d: float = global_position.distance_squared_to(a.global_position)
			if d < bd:
				bd = d
				best = a
		return best
	return _nearest_raider()

func _nearest_raider() -> Node2D:
	var best: Node2D = null
	var bd := INF
	for n in get_tree().get_nodes_in_group("targets"):
		if not is_instance_valid(n) or (n is Enemy and n._dead):
			continue
		var d: float = global_position.distance_squared_to(n.global_position)
		if d < bd:
			bd = d
			best = n
	return best

## Where this unit is trying to GO. Raiders march to the ford goal (the allied banner /
## south bank), so they fight through the line to cross; allies hunt the nearest raider.
func _goal_position() -> Vector2:
	if team == "raiders":
		if is_instance_valid(_goal_node):           # cached on the retarget tick, not per frame
			return _goal_node.global_position
		var p = get_tree().get_first_node_in_group("player")
		return p.global_position if p != null else global_position
	# Ally: chase the nearest raider if one is in reach, else MARCH to the muster marker at the
	# front (cached on the retarget tick) so a standing line advances instead of freezing in place.
	if is_instance_valid(_player):
		return _player.global_position
	if is_instance_valid(_ally_goal):
		return _ally_goal.global_position
	return global_position

## A small push away from nearby same-team units so a crowd spreads instead of stacking
## into one pile (recomputed a few times a second, not every frame).
func _separation_vector() -> Vector2:
	var push := Vector2.ZERO
	var near := radius * 2.4
	for o in get_tree().get_nodes_in_group(team):
		if o == self or not is_instance_valid(o):
			continue
		var away: Vector2 = global_position - o.global_position
		var d := away.length()
		if d > 0.1 and d < near:
			push += away / d * (1.0 - d / near)
	return push.limit_length(1.0)

# ── per-frame visuals ───────────────────────────────────────────────────────

func _process(delta: float) -> void:
	_t += delta
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta)
	if _stun > 0.0:
		_stun = maxf(0.0, _stun - delta)
	if _shield_broken > 0.0:
		_shield_broken = maxf(0.0, _shield_broken - delta)
	if linear_velocity.length() < 60.0:
		_chain = 0
	if _dead:
		_alpha = maxf(0.0, _alpha - delta * 1.6)
		if _alpha <= 0.0:
			queue_free()
	elif _spawn_in > 0.0:
		_spawn_in = maxf(0.0, _spawn_in - delta)
		_alpha = clampf(1.0 - _spawn_in / 0.3, 0.0, 1.0)
	# DIRTY-REDRAW (the single biggest swarm-scale win): re-tessellating each soldier's multi-arc
	# silhouette every frame is the dominant cost with many troops. Redraw only when something
	# VISIBLE actually changed — transient effects (flash/stun/fade/shield-break) and telegraph
	# states always redraw so wind-up/strike read smoothly; an idle/marching unit redraws only when
	# its facing turns past a small threshold or its AI state flips.
	var redraw := _flash > 0.0 or _stun > 0.0 or _alpha < 1.0 or _shield_broken > 0.0
	if not redraw and is_support:
		redraw = true                          # support aura pulses (few of them, cheap)
	elif not redraw and ai_enabled:
		if _ai == AI.WINDUP or _ai == AI.STRIKE or _ai == AI.RECOVER:
			redraw = true                      # telegraph animates
		elif absf(angle_difference(_face, _last_face)) > 0.04 or _ai != _last_ai:
			redraw = true
	# TOUCH-ONLY off-screen skip: on a phone, a unit far from Arthur (the camera target) is off the
	# view, so its silhouette change isn't seen this frame — suppress the redraw to save the swarm cost.
	# Force ONE redraw the moment it scrolls back on-screen so it isn't drawn stale. Dead on DESKTOP
	# (_touch == false), so the gate above is byte-identical there. A cheap squared-distance check.
	if _touch:
		var off := _is_offscreen()
		if off:
			redraw = false                         # off the phone's view → don't re-tessellate
		elif _offscreen:
			redraw = true                          # just re-entered the view → catch up once
		_offscreen = off
	if redraw:
		_last_face = _face
		_last_ai = _ai
		queue_redraw()

## Is this unit far enough from Arthur (the camera target) to be off the phone's view? A cheap
## squared-distance check against Arthur — no viewport/camera maths. The CAMERA isn't always centred
## on Arthur (BattleMap clamps it to the world bounds, so it pins at an edge when Arthur defends a
## wall); OFF_SCREEN_R (1600px) is set well beyond the worst-case Arthur-to-visible-edge distance at
## that pinned state + the mobile zoom (~1180px), so a genuinely VISIBLE unit is never skipped — only
## the safely-distant ones are (which is where the swarm saving lives anyway; a map is ~1280x900).
## Arthur (the one "player") is cached in a SHARED static ref, validated cheaply, so this never does a
## per-frame group scan at swarm scale. With no player (a sandbox / a test) nothing is off-screen.
const OFF_SCREEN_R := 1600.0
static var _cam_target: Node2D = null   ## shared camera target (Arthur); cached, refreshed if freed
func _is_offscreen() -> bool:
	if _cam_target == null or not is_instance_valid(_cam_target):
		_cam_target = get_tree().get_first_node_in_group("player")
	if _cam_target == null or not is_instance_valid(_cam_target):
		return false
	return global_position.distance_squared_to(_cam_target.global_position) > OFF_SCREEN_R * OFF_SCREEN_R

# ── drawing ─────────────────────────────────────────────────────────────────

func _draw() -> void:
	# A support unit (banner/officer) gets a faint morale-aura ring drawn UNDER the body,
	# so allies/raiders nearby read as "rallied around this one". Cheap: a single arc,
	# only while alive, and it pulses with `_t` (already advanced for the telegraphs).
	if is_support and not _dead:
		_draw_morale_aura()
	# Body colour = hit-flash applied first (so a hit still flashes white), THEN a modest tint
	# toward the unit's faction_color so allegiance reads at a glance. Computed by the pure
	# `body_color()` helper so a test can assert the faction shift without a viewport.
	var col := body_color()
	draw_circle(Vector2.ZERO, radius, col)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 20, Color(0.16, 0.1, 0.1, _alpha), 2.5)
	# A faction-coloured emblem ring just inside the rim — Wei blue / Shu green / Wu red — so the
	# kingdom reads even past the body tint. Neutral units skip it (stay plain). Cheap: one arc.
	_draw_faction_emblem()
	_draw_type()
	_draw_attack_telegraph()

	if _stun > 0.0 and not _dead:
		for i in range(3):
			var a := float(i) / 3.0 * TAU + _t * 7.0
			draw_circle(Vector2(cos(a), sin(a)) * (radius + 7.0), 2.5, Color(1, 0.9, 0.3, _alpha))
	if hit_count > 0 and not _dead:
		draw_string(ThemeDB.fallback_font, Vector2(-6.0, -radius - 8.0), str(hit_count),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 0.95, 0.7, _alpha))

# Per-look SILHOUETTE so each unit reads at a glance. Each branch layers a couple of cheap
# primitives keyed to `_face` / `shield_angle`; the markers it draws are summarised (purely)
# by `silhouette_points()` so a test can assert each look produces sane geometry.
func _draw_type() -> void:
	# Per-look silhouette lives in scripts/art/<Look>Art.gd, dispatched by UnitArt, so each unit
	# type can be beautified in isolation without touching Enemy.gd. (Cavalry/WarCart override
	# this entirely with their own mounted draw.)
	UnitArt.draw_type(self)

## A faction emblem ring + a small rear cloak/pennant trim in the faction colour, so Wei/Shu/Wu
## read at a glance beyond the body tint. Neutral units draw nothing (stay plain grey). Cheap:
## one inner rim arc + a couple of short trim lines, all allocation-free.
func _draw_faction_emblem() -> void:
	if faction == "neutral":
		return
	var fc := faction_color()
	# Bright inner emblem ring just inside the body rim (full where unfaded).
	draw_arc(Vector2.ZERO, radius * 0.82, 0.0, TAU, 22, Color(fc.r, fc.g, fc.b, _alpha * 0.9), 2.5)
	# A short faction-coloured cloak/pennant trim trailing BEHIND the facing, so even side-on the
	# allegiance shows. Drawn opposite `_face` as two splayed strokes (a little banner-tail).
	var fwd := Vector2(cos(_face), sin(_face))
	var side := Vector2(-fwd.y, fwd.x)
	var back := -fwd * (radius + 4.0)
	var trim := Color(fc.r, fc.g, fc.b, _alpha)
	draw_line(back + side * 3.0, -fwd * (radius + 12.0) + side * 6.0, trim, 3.0)
	draw_line(back - side * 3.0, -fwd * (radius + 12.0) - side * 6.0, trim, 3.0)

## Faint morale-aura ring + a tiny officer pip for an `is_support` unit — drawn under the body
## in `_draw`. Radius comes from `morale_aura_radius()` (pure, testable).
func _draw_morale_aura() -> void:
	var r := morale_aura_radius()
	var pulse := 0.10 + 0.05 * sin(_t * 2.0)
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 40, Color(0.95, 0.8, 0.4, _alpha * pulse), 2.0)
	draw_arc(Vector2.ZERO, r * 0.62, 0.0, TAU, 32, Color(0.95, 0.8, 0.4, _alpha * pulse * 0.7), 1.5)
	# A small star pip just above the body marks the officer/standard-bearer.
	draw_circle(Vector2(0, -radius - 6.0), 2.5, Color(1.0, 0.85, 0.45, _alpha))

# ── pure geometry helpers (unit-testable; no drawing, no allocations per frame) ───────────────

## The drawn radius of the morale aura — the unit's morale_radius, clamped to a sane band so a
## misconfigured value never draws a pinpoint or a screen-filling ring.
func morale_aura_radius() -> float:
	return clampf(morale_radius, 40.0, 320.0)

## The unit's drawn body colour: the base tint with the hit-flash applied FIRST (so a fresh hit
## still flashes white regardless of faction), THEN a modest blend toward faction_color so
## allegiance reads at a glance. Neutral units get no faction shift (~unchanged). Pure + cheap so
## the readability test can assert the colour shifts toward the faction colour for Wei/Shu/Wu and
## stays put for neutral, all without a viewport.
func body_color() -> Color:
	var col := base_color.lerp(Color(1, 1, 1), clampf(_flash / 0.18, 0.0, 1.0))
	if faction != "neutral":
		col = col.lerp(faction_color(), 0.25)   # 25% tint — visible, but team/flash still read
	col.a = _alpha
	return col

## A small set of marker points (local space) summarising a look's silhouette, used by the
## readability test to assert each look produces sane, non-empty geometry. Mirrors the shapes
## `_draw_type` lays down; kept pure so it can be checked without a viewport.
func silhouette_points(look_name: String) -> PackedVector2Array:
	var fwd := Vector2(cos(_face), sin(_face))
	var side := Vector2(-fwd.y, fwd.x)
	match look_name:
		"soldier":
			return PackedVector2Array([fwd * radius * 0.45, fwd * (radius + 16.0)])
		"shield":
			var s := Vector2(cos(shield_angle), sin(shield_angle))
			return PackedVector2Array([s * (radius + 5.0), s * (radius + 1.5)])
		"heavy":
			return PackedVector2Array([side * radius * 0.72, -side * radius * 0.72, Vector2(0, radius * 0.62)])
		"spear":
			return PackedVector2Array([fwd * radius * 0.2, fwd * (radius + 34.0)])
		"banner":
			return PackedVector2Array([Vector2(0, -radius), Vector2(0, -radius - 34.0), Vector2(22, -radius - 18.0)])
		"knight":
			return PackedVector2Array([fwd * radius * 0.3, fwd * (radius + 22.0), -fwd * (radius + 9.0)])
		_:
			# Any other look (dummy/cavalry/cart) still has a body — return its outline extent.
			return PackedVector2Array([Vector2(radius, 0), Vector2(-radius, 0), Vector2(0, radius)])

## Endpoints [start, end] of a forward thrust/charge warning line for a given reach. Pure so the
## test can assert the line points along `_face` and spans the expected length.
func thrust_line_endpoints(reach: float) -> PackedVector2Array:
	var fwd := Vector2(cos(_face), sin(_face))
	return PackedVector2Array([fwd * radius, fwd * (radius + reach + 10.0)])

func _draw_attack_telegraph() -> void:
	if _dead:
		return
	var fwd := Vector2(cos(_face), sin(_face))
	# Resolve the telegraph look + reach from the chosen move, or the legacy exports if none.
	# "line" = thrust/javelin/lunge, "arc" = slash/bash/melee, "ring" = pound/leap.
	var shape := "arc"
	var reach := attack_range
	if _cur_ability != null:
		shape = _cur_ability.telegraph_shape()
		reach = _cur_ability.max_range
	elif attack_kind == "thrust":
		shape = "line"
	# A gap-closing lunge gets a CHARGE LANE: a long, fading danger lane down the facing during
	# windup (the cavalry charge proper lives in Cavalry.gd, unreachable from here — this covers
	# the foot lunge/leap commit). For thrusts it doubles as the THRUST WARNING LINE.
	var is_lunge := _cur_ability != null and (_cur_ability.kind == "lunge" or _cur_ability.kind == "leap")
	if _ai == AI.WINDUP:
		var t := clampf(_ai_time / maxf(_cur_windup(), 0.01), 0.0, 1.0)
		var warn := Color(1.0, 0.55, 0.2, _alpha * (0.3 + 0.5 * t))
		match shape:
			"line":
				if is_lunge:
					_draw_charge_lane(fwd, reach, t)
				else:
					_draw_thrust_warning(fwd, reach, t, false)
			"ring":
				var rr: float = _cur_ability.aoe_radius if _cur_ability != null and _cur_ability.aoe_radius > 0.0 else reach
				draw_arc(Vector2.ZERO, rr, 0.0, TAU, 28, warn, 4.0)
			_:
				draw_arc(Vector2.ZERO, radius + 10.0, _face - 0.8, _face + 0.8, 12, warn, 5.0)
	elif _ai == AI.STRIKE:
		var hot := Color(1.0, 0.85, 0.4, _alpha)
		match shape:
			"line":
				if is_lunge:
					_draw_charge_lane(fwd, reach, 1.0)
				else:
					_draw_thrust_warning(fwd, reach, 1.0, true)
			"ring":
				var rr2: float = _cur_ability.aoe_radius if _cur_ability != null and _cur_ability.aoe_radius > 0.0 else reach
				draw_arc(Vector2.ZERO, rr2, 0.0, TAU, 32, hot, 6.0)
			_:
				draw_arc(Vector2.ZERO, radius + 12.0, _face - 1.0, _face + 1.0, 14, hot, 7.0)

## A spear THRUST danger line: a forward line that thickens/brightens as the windup fills, with
## a small barbed tip so it reads as an incoming poke. `hot` = the strike frame (brightest).
func _draw_thrust_warning(fwd: Vector2, reach: float, t: float, hot: bool) -> void:
	var ends := thrust_line_endpoints(reach)
	var col := Color(1.0, 0.85, 0.4, _alpha) if hot else Color(1.0, 0.5, 0.2, _alpha * (0.35 + 0.5 * t))
	var w := 6.0 if hot else 3.0 + 2.0 * t
	draw_line(ends[0], ends[1], col, w)
	# A little arrowhead at the tip so the danger reads directional, not just a streak.
	var side := Vector2(-fwd.y, fwd.x)
	var tip: Vector2 = ends[1]
	draw_line(tip, tip - fwd * 7.0 + side * 5.0, col, w * 0.6)
	draw_line(tip, tip - fwd * 7.0 - side * 5.0, col, w * 0.6)

## A CHARGE LANE for a lunge/leap commit: a long, narrow danger corridor down the facing that
## fills toward the strike — a "get out of the way" cue distinct from a short thrust line.
func _draw_charge_lane(fwd: Vector2, reach: float, t: float) -> void:
	var side := Vector2(-fwd.y, fwd.x)
	var lane: float = reach + 20.0
	var col := Color(1.0, 0.45, 0.2, _alpha * (0.18 + 0.45 * t))
	var near := fwd * radius
	var far := fwd * (radius + lane)
	# Two rails + a brightening centre line so the lane reads as a corridor, not a single beam.
	draw_line(near + side * 6.0, far + side * 6.0, col, 2.0)
	draw_line(near - side * 6.0, far - side * 6.0, col, 2.0)
	draw_line(near, fwd * (radius + lane * (0.3 + 0.7 * t)), Color(1.0, 0.6, 0.25, _alpha * (0.4 + 0.5 * t)), 3.0)
