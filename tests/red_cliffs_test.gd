extends Node2D
## Red Cliffs (赤壁) + FireZone test (token CHIBI). Three checks, all headless:
##   (a) FIRE DAMAGES — a unit standing INSIDE a FireZone loses health / dies; a unit OUTSIDE
##       it (same scene, placed clear of the rect) takes NO burn. This proves the hazard works.
##   (b) THE MAP BOOTS — RedCliffs instantiates Arthur + the HUD and spawns its first wave of
##       raiders, all stamped 魏 Wei.
##   (c) (optional) LOOPING-KILL → VICTORY — clear every raider each wave and the RepelWaves
##       objective drives the base to `_won`.
##
## Run: godot --headless --path . res://tests/RedCliffsTest.tscn --quit-after 600 → CHIBI_VERDICT.

const FIRE_ZONE := preload("res://scenes/hazards/FireZone.tscn")
const LIGHT := preload("res://scenes/LightSoldier.tscn")

var _frame := 0

# (a) fire damage probe
var _fire = null
var _burned = null          ## the unit inside the flames
var _safe = null            ## the unit outside the flames
var _burned_hp0 := 0.0
var _safe_hp0 := 0.0
var _fire_done := false
var _fire_dmg_ok := false   ## inside unit lost health or died
var _safe_ok := false       ## outside unit untouched

# (b)/(c) the map
var _map = null
var _spawned_seen := false

func _ready() -> void:
	_setup_fire_probe()
	_map = RedCliffs.new()
	add_child(_map)

## A standalone FireZone with two LightSoldiers: one dead-centre inside, one well outside.
## Placed far NORTH-WEST (small y), clear of the map's water/fires AND above its defence line,
## so the map's breach check (which frees any target past defence_line_y) never culls the probe.
func _setup_fire_probe() -> void:
	_fire = FIRE_ZONE.instantiate()
	_fire.burn_dmg = 6.0
	_fire.tick = 0.3
	_fire.setup_rect(Rect2(-3000.0, -3000.0, 200.0, 160.0))
	add_child(_fire)

	_burned = LIGHT.instantiate()
	add_child(_burned)
	_burned.global_position = Vector2(-2900.0, -2920.0)   # centre of the fire rect
	_burned.ai_enabled = false                            # hold still inside the flames

	_safe = LIGHT.instantiate()
	add_child(_safe)
	_safe.global_position = Vector2(-2400.0, -2920.0)     # clear of the fire rect
	_safe.ai_enabled = false

func _physics_process(_dt: float) -> void:
	_frame += 1
	if _frame == 4:
		# Snapshot starting health AFTER _ready ran (Enemy sets health = max_health on ready).
		_burned_hp0 = _burned.health
		_safe_hp0 = _safe.health
	# (a) Step ~90 physics frames (~1.5s) so several burn ticks land, then assert.
	if _frame == 95 and not _fire_done:
		_fire_done = true
		var burned_lost: bool = (not is_instance_valid(_burned)) or _burned._dead or (_burned.health < _burned_hp0 - 0.001)
		var safe_intact: bool = is_instance_valid(_safe) and not _safe._dead and (_safe.health >= _safe_hp0 - 0.001)
		_fire_dmg_ok = burned_lost
		_safe_ok = safe_intact
	# (b) The base should have spawned wave 0 within its first scans.
	if _frame == 20:
		_spawned_seen = get_tree().get_nodes_in_group("targets").size() > 0
	# (c) Loop-kill: every few frames, wipe the live raiders so waves keep coming → victory.
	# Skip the two fire-probe units (off in the far NW) so the burn check at frame 95 still has
	# an intact "safe" unit to compare — only the map's raiders are culled.
	if _frame >= 30 and _frame % 8 == 0 and not _map._won and not _map._lost:
		for e in get_tree().get_nodes_in_group("targets"):
			if is_instance_valid(e) and e != _burned and e != _safe:
				e.apply_hit(Vector2.DOWN, 6000.0, 0.1, 1.0e9, 0.0)
	# Report well after the loop-kill clears all four waves (victory lands ~frame 182). 600
	# idle frames (the suite's --quit-after) reach ~250 physics frames headless, so 220 is safe.
	if _frame >= 220:
		_report()

func _report() -> void:
	var has_arthur: bool = _map.arthur != null and is_instance_valid(_map.arthur)
	var has_hud: bool = _map.hud != null
	var won: bool = _map._won
	# Required: fire damages the inside unit, leaves the outside unit alone, and the map booted
	# (Arthur + HUD + a wave of raiders). Victory is a bonus signal but also required here since
	# the loop-kill should clear all four waves well within 460 frames.
	var ok: bool = _fire_dmg_ok and _safe_ok and has_arthur and has_hud and _spawned_seen and won
	print("CHIBI_RESULT fire_dmg=%s safe_intact=%s arthur=%s hud=%s spawned=%s won=%s kos=%d" % [
		str(_fire_dmg_ok), str(_safe_ok), str(has_arthur), str(has_hud),
		str(_spawned_seen), str(won), Impact.kills])
	print("CHIBI_VERDICT %s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)
