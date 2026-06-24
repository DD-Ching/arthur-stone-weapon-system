extends Node2D
## Test for the Changban (長坂坡) escort map — a thin BattleMap subclass that protects ONE
## allied ward against escalating Wei waves. Two paths, each on a FRESH map instance:
##
##   (a) DEFEAT — the map sets a `_ward`; killing that ward (a huge apply_hit) must fail the
##       ProtectBanner constraint and drive the base to `_lost == true`.
##   (b) VICTORY — keep the ward alive and loop-kill every raider in "targets" each frame until
##       all waves clear; the RepelWaves objective must then drive `_won == true` (and `_lost`
##       stays false — the banner never fell).
##
## Run: godot --headless --path . res://tests/ChangbanTest.tscn --quit-after 600
## Look for CHANGBAN_VERDICT.

const CHANGBAN := preload("res://scenes/maps/Changban.tscn")

enum Phase { DEFEAT, VICTORY }

var _phase: int = Phase.DEFEAT
var _map = null
var _frame := 0

# DEFEAT results
var _ward_set := false
var _defeat_lost := false
var _defeat_done := false

# VICTORY results
var _victory_won := false
var _victory_not_lost := false
var _victory_ward_alive := false
var _victory_done := false

func _ready() -> void:
	_start_defeat()

# ── DEFEAT path ──────────────────────────────────────────────────────────────
func _start_defeat() -> void:
	_phase = Phase.DEFEAT
	_frame = 0
	_map = _make_map()
	add_child(_map)

func _make_map():
	var m = CHANGBAN.instantiate()
	# Fast waves + a light density so the headless run resolves quickly.
	m.wave_interval = 0.4
	m.density = 0.2
	return m

func _physics_process(_dt: float) -> void:
	_frame += 1
	match _phase:
		Phase.DEFEAT:
			_tick_defeat()
		Phase.VICTORY:
			_tick_victory()

func _tick_defeat() -> void:
	if _frame == 4:
		# The map must have placed a ward to protect.
		_ward_set = _map._ward != null and is_instance_valid(_map._ward)
		# Kill the ward with an overwhelming hit (it's an Enemy → apply_hit). Fails ProtectBanner.
		if _ward_set:
			_map._ward.apply_hit(Vector2.DOWN, 1.0e9, 0.2, 1.0e12, 0.0)
	if _frame >= 30:
		_defeat_lost = bool(_map._lost)
		_defeat_done = true
		_teardown_and_start_victory()

func _teardown_and_start_victory() -> void:
	_map.queue_free()
	_map = null
	# Begin the victory run on a fresh instance next frame, after the old map is freed and its
	# raiders leave the "targets" group.
	call_deferred("_start_victory")

# ── VICTORY path ─────────────────────────────────────────────────────────────
func _start_victory() -> void:
	_phase = Phase.VICTORY
	_frame = 0
	_map = _make_map()
	add_child(_map)

func _tick_victory() -> void:
	# Never touch the ward — it must survive. Cull every live raider each frame so the field
	# clears, the next wave is forced in (tiny wave_interval), and eventually all waves clear.
	for e in get_tree().get_nodes_in_group("targets"):
		if is_instance_valid(e) and not (e is Enemy and e._dead):
			e.apply_hit(Vector2.DOWN, 6000.0, 0.1, 1.0e9, 0.0)
	if _map._won or _frame >= 420:
		_victory_won = bool(_map._won)
		_victory_not_lost = not bool(_map._lost)
		var w = _map._ward
		_victory_ward_alive = w != null and is_instance_valid(w) and not (w is Enemy and w._dead)
		_victory_done = true
		_report()

# ── verdict ──────────────────────────────────────────────────────────────────
func _report() -> void:
	var defeat_ok: bool = _ward_set and _defeat_lost
	var victory_ok: bool = _victory_won and _victory_not_lost and _victory_ward_alive
	var ok: bool = defeat_ok and victory_ok
	print("CHANGBAN_RESULT ward_set=%s defeat_lost=%s | victory_won=%s victory_not_lost=%s ward_alive=%s" % [
		str(_ward_set), str(_defeat_lost),
		str(_victory_won), str(_victory_not_lost), str(_victory_ward_alive)])
	print("CHANGBAN_VERDICT %s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)
