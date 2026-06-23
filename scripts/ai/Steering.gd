class_name Steering
extends RefCounted
## Reusable, physics-based obstacle avoidance against the WORLD layer (walls + fences).
##
## The problem this fixes: enemies march straight at their goal and JAM on fences/walls.
## The only avoidance today is for water (danger_terrain Areas) and a crude stuck-recovery
## that nudges a FIXED flank — which can keep shoving a unit into the same corner. This
## module flows a unit AROUND solid walls instead, using the same short raycasts the
## wall-crush check already relies on (Impact.cushion), so it costs ~3 casts per call.
##
## It is STATELESS and PURE: static funcs only, no scene/group/node deps, no state, no
## threads. It takes the body's space state (the caller caches it — see the integration
## contract) and returns an ADJUSTED unit direction. Because every level's walls are
## already StaticBody2D on the world layer (bit 1), this works in EVERY level with zero
## per-level wiring.
##
## Why the world layer only: water/bridge are Area2D (not on the world layer) and the
## existing danger-zone logic already routes around them; props/units/Arthur are dynamic
## and would make a unit flinch at its own crowd. So we mask to bit 1 — solid map geometry.

const WORLD_MASK := 1            ## physics layer 1 = "world" (walls / fences / obstacles)
const LOOKAHEAD := 34.0          ## how far past the body radius the feelers probe
const WHISKER_ANGLE := 0.6       ## radians the two side feelers splay from center (~34°)
const TURN_TANGENT := 0.85       ## how hard to slide along a wall when both whiskers hit
const FAN_SPREAD := 1.7          ## radians half-width of the stuck-recovery fan (~97° each side)
const FAN_RAYS := 5              ## rays in the most_open_dir fan (odd → one straight at goal)
const FAN_GOAL_BIAS := 0.35      ## prefer clearance NEAR the goal dir over a marginally longer one

## Cast one ray from `origin` along `dir` for `length` px against the world layer, excluding
## `exclude_rid` (the body itself). Returns the free distance (== length when clear). Pure:
## the caller supplies `space` so we never touch the scene tree.
static func _probe(space: PhysicsDirectSpaceState2D, origin: Vector2, dir: Vector2,
		length: float, exclude_rid: RID) -> float:
	var q := PhysicsRayQueryParameters2D.create(origin, origin + dir * length)
	q.collision_mask = WORLD_MASK
	q.collide_with_areas = false   # ignore water/bridge Areas — those are handled elsewhere
	q.exclude = [exclude_rid]      # never let the body's own shape register as a wall
	# intersect_ray returns an untyped Dictionary; keep `hit` untyped (Variant gotcha) and read
	# "position" into an explicit Vector2 so `:=` never has to infer off a Variant.
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return length
	var p: Vector2 = hit["position"]
	return origin.distance_to(p)

## THE main wrapper. Given the body's position, radius, a DESIRED unit direction, the space
## state, and the body RID to exclude, fire a short CENTER ray plus two angled WHISKERS ahead
## and return an adjusted unit direction that flows AROUND a wall:
##   - center clear            → keep `desired` (zero cost beyond the 3 casts);
##   - center blocked, one side more open → rotate toward the more-open whisker;
##   - both whiskers blocked    → slide along the wall TANGENT toward the more-open side, so
##                                the unit hugs the wall toward open space instead of pushing in.
## `desired` is assumed unit length; the return is unit length. ~3 casts, no allocations beyond
## the query objects. Safe to call every frame for the small body counts here — but the contract
## suggests throttling it so a 67-body battle never pays for 67 fresh redirects each frame.
## `bias` (typically the unit's flank, ±1) breaks a symmetric tie so a unit pinned dead-centre
## on a long wall commits to ONE end instead of jittering in place; 0 = no preference.
static func avoid(space: PhysicsDirectSpaceState2D, pos: Vector2, radius: float,
		desired: Vector2, exclude_rid: RID, bias := 0.0) -> Vector2:
	if space == null or desired == Vector2.ZERO:
		return desired
	var reach := radius + LOOKAHEAD
	var clear := reach - 0.5
	var ang := desired.angle()
	# Feelers start at the body CENTRE (not the rim): a wall the body is already touching sits
	# ~radius away, so it still registers as blocked. (Starting at the rim would put the origin
	# INSIDE the wall, and intersect_ray ignores the surface it begins within → a false "clear".)
	var center := _probe(space, pos, desired, reach, exclude_rid)
	var left_dir := Vector2.RIGHT.rotated(ang - WHISKER_ANGLE)
	var right_dir := Vector2.RIGHT.rotated(ang + WHISKER_ANGLE)
	var left := _probe(space, pos, left_dir, reach, exclude_rid)
	var right := _probe(space, pos, right_dir, reach, exclude_rid)
	# Only commit to the straight line when the WHOLE width is clear — if a side feeler still
	# clips a wall (e.g. rounding a corner where the centre point has already passed the end),
	# keep steering, so the body's radius clears the corner instead of catching on it.
	if center >= clear and left >= clear and right >= clear:
		return desired
	# Steer toward the more-open side; a near-symmetric tie is broken by `bias` so the unit
	# picks an end and slides off it rather than oscillating dead-centre.
	var side := 1.0 if right >= left else -1.0
	if absf(right - left) < 12.0 and bias != 0.0:
		side = signf(bias)
	if center < clear and minf(left, right) < clear:
		# Boxed in ahead → glide along the wall tangent toward the open side, hugging it toward
		# open space instead of pushing straight in.
		var open_dir := right_dir if side > 0.0 else left_dir
		var tangent := Vector2(-desired.y, desired.x) * side
		return (open_dir + tangent * TURN_TANGENT).normalized()
	# A feeler is blocked but there's room → bend partway toward the open side, proportional to
	# how tight the closest feeler is.
	var tightest := minf(center, minf(left, right))
	var bend := clampf(1.0 - tightest / reach, 0.0, 1.0) * WHISKER_ANGLE
	return Vector2.RIGHT.rotated(ang + bend * side)

## STUCK RECOVERY: fan a handful of rays across `±FAN_SPREAD` around `preferred` and return the
## unit direction of the LONGEST-CLEAR one, lightly biased toward `preferred` (the goal/foe dir)
## so a tie or a marginal win still pushes the unit the way it wanted to go. Replaces the
## fixed-flank nudge that could re-shove a unit into the same corner: this turns toward whichever
## side is ACTUALLY clear. `preferred` is assumed unit length; the return is unit length.
static func most_open_dir(space: PhysicsDirectSpaceState2D, pos: Vector2, radius: float,
		preferred: Vector2, exclude_rid: RID) -> Vector2:
	if space == null or preferred == Vector2.ZERO:
		return preferred
	var reach := radius + LOOKAHEAD
	var base := preferred.angle()
	var best_dir := preferred
	var best_score := -INF
	for i in FAN_RAYS:
		# Spread the rays evenly across the fan, symmetric about `preferred`.
		var t := (float(i) / float(FAN_RAYS - 1)) * 2.0 - 1.0   # -1..1
		var dir := Vector2.RIGHT.rotated(base + t * FAN_SPREAD)
		var clear := _probe(space, pos, dir, reach, exclude_rid)
		# Score = clearance, plus a small bonus for pointing near the goal (alignment 0..1).
		var align := (dir.dot(preferred) + 1.0) * 0.5
		var score := clear + align * reach * FAN_GOAL_BIAS
		if score > best_score:
			best_score = score
			best_dir = dir
	return best_dir
