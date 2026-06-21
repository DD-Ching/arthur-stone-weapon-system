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
@export_enum("dummy", "soldier", "shield", "heavy", "spear", "banner") var look := "dummy"
@export var radius := 16.0
@export var base_color := Color(0.78, 0.32, 0.33)
## "raiders" = the warband attacking across the ford (Arthur's foe). "ally" = a footman
## fighting FOR Arthur. The team decides who this unit hunts and who may hit it.
@export var team := "raiders"

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
var _chain := 0
var _shield_broken := 0.0 ## seconds the shield is overwhelmed
var _player = null        ## current FOE to attack (Arthur/ally for raiders; a raider for allies)
var _ai := AI.APPROACH
var _ai_time := 0.0
var _atk_cd := 0.0
var _did_strike := false
var _face := PI           ## facing toward the foe (for weapons / telegraphs)
var _flank := 0.0         ## side bias so non-shield units surround instead of clumping
var _retarget_cd := 0.0   ## throttle for re-scanning for the nearest foe + separation + terrain
var _separation := Vector2.ZERO  ## steering away from nearby same-team units (no stacking)
var _last_pos := Vector2.ZERO    ## last frame's position, for stuck detection
var _stuck_t := 0.0       ## seconds spent trying-but-failing to move (wall/jam)
var _danger_zones: Array = []    ## cached "danger_terrain" (deep water) to route around
var _crossings: Array = []       ## cached "crossing" markers (bridges/fords) to aim at
var _goal_node = null            ## cached march goal (the ford banner), refreshed on retarget
var _rerouting := false          ## currently steering around danger, not pursuing the foe

func _ready() -> void:
	add_to_group("hittable")
	add_to_group(team)
	# Raiders are the "targets" Arthur's weapon/objective/terrain act on; allies are not.
	add_to_group("targets" if team == "raiders" else "allies")
	# Non-shield units pick a side to flank from, so a crowd surrounds rather than stacks.
	if not shielded:
		_flank = -1.0 if (randf() < 0.5) else 1.0
	health = max_health
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

# ── taking a hit ────────────────────────────────────────────────────────────

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

func _defeat() -> void:
	_dead = true
	_chain = 0
	set_deferred("collision_layer", 0)   # stop colliding, keep sliding out
	remove_from_group("shieldwall")      # objective counts this immediately, not after the fade
	Impact.popup("DOWN!", global_position + Vector2(0, -28), Color(1.0, 0.9, 0.4), 1.1)
	# A fallen ALLY costs you nothing (no KO/flow); only raiders feed the counter.
	if team == "raiders":
		Impact.add_flow(10.0)
		Impact.add_kill()                # the musou KO counter
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
		# Cache the (static) terrain + march goal so per-frame steering doesn't re-scan groups.
		if avoid_danger:
			_danger_zones = get_tree().get_nodes_in_group("danger_terrain")
			_crossings = get_tree().get_nodes_in_group("crossing")
		if team == "raiders":
			_goal_node = get_tree().get_first_node_in_group("ford_goal")
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
					if foe_dist <= attack_range and _atk_cd <= 0.0 and attack_kind != "none":
						_begin_attack()
					elif shielded and foe_dist <= guard_range:
						_ai = AI.GUARD
						_ai_time = 0.0
			else:
				linear_velocity = linear_velocity.move_toward(_march_velocity(), move_accel * delta)
		AI.GUARD:
			linear_velocity = linear_velocity.move_toward(dir * move_speed * 0.3 + _separation * 36.0, move_accel * delta)
			if foe_dist > guard_range * 1.5:
				_ai = AI.APPROACH
			elif _atk_cd <= 0.0 and attack_kind != "none" and _ai_time > 0.45:
				_begin_attack()
		AI.WINDUP:
			linear_velocity = linear_velocity.move_toward(Vector2.ZERO, move_accel * delta)
			if _ai_time >= attack_windup:
				_ai = AI.STRIKE
				_ai_time = 0.0
				_did_strike = false
		AI.STRIKE:
			if not _did_strike:
				_did_strike = true
				if foe_dist <= attack_range + radius + 6.0:
					_strike(_player, dir)
			if _ai_time >= attack_strike:
				_ai = AI.RECOVER
				_ai_time = 0.0
		AI.RECOVER:
			linear_velocity = linear_velocity.move_toward(Vector2.ZERO, move_accel * delta)
			if _ai_time >= attack_recover:
				_ai = AI.APPROACH
				_ai_time = 0.0
				_atk_cd = attack_cooldown

	# Stuck recovery: if it's actually TRYING to advance but barely moved (jammed on a wall
	# or a pile of bodies), slip sideways. Skip it for a spacing unit holding its band (it's
	# waiting, not stuck) and never nudge a unit into the danger it's avoiding.
	if _ai == AI.APPROACH and _wants_to_advance():
		if global_position.distance_to(_last_pos) < 0.6:
			_stuck_t += delta
			if _stuck_t > 0.4:
				var side := _flank if _flank != 0.0 else 1.0
				var nudge := Vector2(-sin(_face), cos(_face)) * side
				if not _danger_ahead(global_position + nudge * (radius + 20.0)):
					linear_velocity = (linear_velocity + nudge * move_speed * 0.9).limit_length(move_speed)
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
	return d * move_speed + _separation * 40.0

## Steering while marching toward the goal (no foe in reach), still anti-stacking.
## If dangerous terrain (deep water) is right ahead, steer toward the nearest crossing
## (a bridge/ford) instead of wading in — this is what funnels a warband into a chokepoint.
func _march_velocity() -> Vector2:
	var to_goal: Vector2 = _goal_position() - global_position
	var gdir := to_goal / maxf(to_goal.length(), 0.001)
	gdir = _avoid_redirect(gdir)
	_face = gdir.angle()
	if shielded:
		shield_angle = _face
	return gdir * move_speed + _separation * 40.0

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

func _begin_attack() -> void:
	_ai = AI.WINDUP
	_ai_time = 0.0
	_did_strike = false

## Land a hit on the current foe — Arthur takes scaled damage; a unit takes a small
## scored hit (so allies and raiders can actually kill each other).
func _strike(foe, dir: Vector2) -> void:
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
	return _player.global_position if is_instance_valid(_player) else global_position

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
	# AI enemies animate (facing, telegraphs) so they redraw each frame; passive
	# dummies only redraw when something visible changes (keeps the web build light).
	if ai_enabled or _flash > 0.0 or _stun > 0.0 or _alpha < 1.0:
		queue_redraw()

# ── drawing ─────────────────────────────────────────────────────────────────

func _draw() -> void:
	var col := base_color.lerp(Color(1, 1, 1), clampf(_flash / 0.18, 0.0, 1.0))
	col.a = _alpha
	draw_circle(Vector2.ZERO, radius, col)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 20, Color(0.16, 0.1, 0.1, _alpha), 2.5)
	_draw_type()
	_draw_attack_telegraph()

	if _stun > 0.0 and not _dead:
		for i in range(3):
			var a := float(i) / 3.0 * TAU + _t * 7.0
			draw_circle(Vector2(cos(a), sin(a)) * (radius + 7.0), 2.5, Color(1, 0.9, 0.3, _alpha))
	if hit_count > 0 and not _dead:
		draw_string(ThemeDB.fallback_font, Vector2(-6.0, -radius - 8.0), str(hit_count),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 0.95, 0.7, _alpha))

func _draw_type() -> void:
	match look:
		"soldier":
			draw_circle(Vector2(cos(_face), sin(_face)) * radius * 0.45, radius * 0.28, Color(0.95, 0.9, 0.8, _alpha))
		"shield":
			var col := Color(0.4, 0.45, 0.55, _alpha) if _shield_broken > 0.0 else Color(0.72, 0.74, 0.82, _alpha)
			draw_arc(Vector2.ZERO, radius + 5.0, shield_angle - 0.95, shield_angle + 0.95, 16, col, 6.0)
		"heavy":
			draw_arc(Vector2.ZERO, radius * 0.6, 0.0, TAU, 16, Color(0.2, 0.16, 0.16, _alpha), 4.0)
		"spear":
			var tip := Vector2(cos(_face), sin(_face)) * (radius + 34.0)
			draw_line(Vector2.ZERO, tip, Color(0.7, 0.6, 0.45, _alpha), 3.0)
			draw_circle(tip, 3.0, Color(0.85, 0.85, 0.9, _alpha))
		"banner":
			draw_line(Vector2(0, -radius), Vector2(0, -radius - 34.0), Color(0.5, 0.4, 0.3, _alpha), 3.0)
			draw_rect(Rect2(0, -radius - 34.0, 22, 16), Color(0.8, 0.3, 0.25, _alpha))

func _draw_attack_telegraph() -> void:
	if _dead:
		return
	var fwd := Vector2(cos(_face), sin(_face))
	if _ai == AI.WINDUP:
		var t := clampf(_ai_time / maxf(attack_windup, 0.01), 0.0, 1.0)
		var warn := Color(1.0, 0.55, 0.2, _alpha * (0.3 + 0.5 * t))
		if attack_kind == "thrust":
			draw_line(fwd * radius, fwd * (radius + attack_range + 10.0), warn, 4.0)
		else:
			draw_arc(Vector2.ZERO, radius + 10.0, _face - 0.8, _face + 0.8, 12, warn, 5.0)
	elif _ai == AI.STRIKE:
		var hot := Color(1.0, 0.85, 0.4, _alpha)
		if attack_kind == "thrust":
			draw_line(fwd * radius, fwd * (radius + attack_range + 14.0), hot, 6.0)
		else:
			draw_arc(Vector2.ZERO, radius + 12.0, _face - 1.0, _face + 1.0, 14, hot, 7.0)
