extends Node2D
## Headless test for the Beacon-Forts map + the reusable Base-capture mechanic.
##
## Three things to prove:
##   (a) THE MECHANIC — a Base with live raiders inside its radius is NOT captured; once those
##       raiders are defeated (and it was engaged), it flips to is_captured() == true.
##   (b) THE WIN RULE — CaptureBasesObjective completes when every base is held (ctx
##       bases_total == bases_captured), and not before.
##   (c) THE MAP — the Beacon-Forts scene boots (Arthur + HUD), and after its base garrisons
##       are all defeated, every fort captures and the map reaches VICTORY (_won).
##
## Run: godot --headless --path . res://tests/GuanduTest.tscn --quit-after 600
## Look for GUANDU_VERDICT.

const BASE := preload("res://scenes/Base.tscn")
const LIGHT := preload("res://scenes/LightSoldier.tscn")
const GUANDU := preload("res://scenes/maps/Guandu.tscn")

var _base
var _g1
var _g2
var _map
var _frame := 0

# (a) Base capture stages.
var _base_busy_uncaptured := false   ## raiders inside → not captured
var _base_captured := false          ## after defeating them → captured

# (b) Objective rule (deterministic).
var _obj_no_win_partial := false     ## 1/2 captured → not won
var _obj_win_all := false            ## 2/2 captured → won

# (c) Map outcome.
var _map_has_arthur := false
var _map_has_hud := false
var _map_uses_objective := false
var _map_won := false

func _ready() -> void:
	# ── (a) place a Base and garrison it with two live raiders inside its radius ──
	_base = BASE.instantiate()
	add_child(_base)
	_base.global_position = Vector2(-2000.0, 0.0)   # off to the side, away from the map
	_base.radius = 120.0
	_g1 = LIGHT.instantiate()
	_g2 = LIGHT.instantiate()
	add_child(_g1)
	add_child(_g2)
	_g1.ai_enabled = false
	_g2.ai_enabled = false
	_g1.global_position = _base.global_position + Vector2(40.0, 0.0)
	_g2.global_position = _base.global_position + Vector2(-40.0, 30.0)

	# ── (b) drive the objective directly, so the rule check is deterministic ──
	var obj := CaptureBasesObjective.new()
	var mgr := ObjectiveManager.new()
	mgr.add(obj)
	mgr.evaluate({"bases_total": 2, "bases_captured": 1})
	_obj_no_win_partial = not mgr.won
	mgr.evaluate({"bases_total": 2, "bases_captured": 2})
	_obj_win_all = mgr.won

	# ── (c) boot the real Guandu map ──
	_map = GUANDU.instantiate()
	add_child(_map)
	_map_has_arthur = _map.arthur != null and is_instance_valid(_map.arthur)
	_map_has_hud = _map.hud != null
	_map_uses_objective = _map._objectives != null \
		and _map._objectives.objectives.size() >= 1 \
		and _map._objectives.objectives[0] is CaptureBasesObjective

	print("GUANDU_READY arthur=%s hud=%s bases=%d" % [
		str(_map_has_arthur), str(_map_has_hud),
		get_tree().get_nodes_in_group("bases").size()])

func _physics_process(_dt: float) -> void:
	_frame += 1

	# (a) After a couple scans the Base has registered its two live raiders inside → engaged
	# but NOT captured. Snapshot that, then defeat them so it can flip.
	if _frame == 15:
		_base_busy_uncaptured = is_instance_valid(_base) and not _base.is_captured()
		if is_instance_valid(_g1):
			_g1.apply_hit(Vector2.DOWN, 9000.0, 0.1, 1.0e9, 0.0)
		if is_instance_valid(_g2):
			_g2.apply_hit(Vector2.DOWN, 9000.0, 0.1, 1.0e9, 0.0)

	# (c) Keep defeating every raider on the MAP (the fort garrisons + any relief wave) so
	# each fort empties and captures, driving the map to victory.
	if _frame >= 20 and not _map._won:
		for e in get_tree().get_nodes_in_group("targets"):
			if not is_instance_valid(e):
				continue
			# Leave the isolated Base's own garrison out of the map sweep — it's far away and
			# already defeated; this just hammers the map's raiders.
			e.apply_hit(Vector2.DOWN, 9000.0, 0.1, 1.0e9, 0.0)

	if _frame >= 180:
		_report()

func _report() -> void:
	_base_captured = is_instance_valid(_base) and _base.is_captured()
	_map_won = _map._won

	var ok: bool = _base_busy_uncaptured and _base_captured \
		and _obj_no_win_partial and _obj_win_all \
		and _map_has_arthur and _map_has_hud and _map_uses_objective and _map_won

	print("GUANDU_RESULT base_busy=%s base_cap=%s obj_partial=%s obj_all=%s arthur=%s hud=%s obj=%s map_won=%s kos=%d" % [
		str(_base_busy_uncaptured), str(_base_captured),
		str(_obj_no_win_partial), str(_obj_win_all),
		str(_map_has_arthur), str(_map_has_hud), str(_map_uses_objective),
		str(_map_won), Impact.kills])
	print("GUANDU_VERDICT %s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)
