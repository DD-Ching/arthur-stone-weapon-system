extends Node2D
## Headless test for the Formation module:
##   - a SpearPhalanx spawns its roster (3 shields front + 3 spears behind), on the raider
##     team, with the support rank actually BEHIND the front along the facing;
##   - an OfficerGuard spawned at the real Battlefield wave-y has EVERY unit (including the
##     rear banner) inside the arena (regression for the rear-ranks-clip-the-top-wall bug).
##
## Run: godot --headless --path . res://tests/FormationsTest.tscn — look for FORM_VERDICT.

const SPEAR_PHALANX := preload("res://scenes/formations/SpearPhalanx.tscn")
const OFFICER_GUARD := preload("res://scenes/formations/OfficerGuard.tscn")
const ALLIED_HOST := preload("res://scenes/formations/AlliedHost.tscn")
const HALF_Y := 560.0          # Battlefield.HALF.y
const WALL_INNER := -540.0     # top wall inner edge (raider formations must spawn south of it)
const SWALL_INNER := 540.0     # bottom wall inner edge (the allied host must spawn north of it)

var _phalanx
var _guard
var _host
var _frame := 0

func _ready() -> void:
	_phalanx = SPEAR_PHALANX.instantiate()
	_phalanx.position = Vector2(-400, -200)   # faces DOWN; the rank behind is to the north
	add_child(_phalanx)
	# Spawn the OfficerGuard exactly as Battlefield._spawn_wave does (rear-rank headroom).
	_guard = OFFICER_GUARD.instantiate()
	_guard.position = Vector2(400, -HALF_Y + 100.0 + _guard.rank_gap * 2.0)
	add_child(_guard)
	# The allied host faces UP; placed at the bank, its rear knight must clear the bottom wall.
	_host = ALLIED_HOST.instantiate()
	_host.position = Vector2(0, 350)
	add_child(_host)

func _physics_process(_delta: float) -> void:
	_frame += 1
	if _frame >= 4:
		_report()

func _report() -> void:
	# 1) SpearPhalanx roster + team + rank order.
	var fronts: Array = []
	var supports: Array = []
	var team_ok := true
	for u in _phalanx.units:
		if not u.is_in_group("raiders"):
			team_ok = false
		if u.look == "shield":
			fronts.append(u)
		elif u.look == "spear":
			supports.append(u)
	var ranked_ok: bool = supports.size() > 0 and fronts.size() > 0 and _avg_y(supports) < _avg_y(fronts) - 20.0
	var roster_ok: bool = _phalanx.units.size() == 6 and fronts.size() == 3 and supports.size() == 3 and team_ok and ranked_ok

	# 2) OfficerGuard (2 shields + 2 spears + 1 banner) all clear the TOP wall.
	var north := 1.0e9
	for u in _guard.units:
		north = minf(north, u.global_position.y)
	var clear_ok: bool = _guard.units.size() == 5 and north > WALL_INNER

	# 3) AlliedHost (faces up) — its rear knight clears the BOTTOM wall, and it's on the ally team.
	var south := -1.0e9
	var ally_ok := true
	for u in _host.units:
		south = maxf(south, u.global_position.y)
		if not u.is_in_group("allies"):
			ally_ok = false
	var host_ok: bool = _host.units.size() == 8 and ally_ok and south < SWALL_INNER

	print("FORM_RESULT roster_ok=%s ranked=%s guard=%d north_y=%.0f clear=%s host=%d south_y=%.0f host_ok=%s"
		% [str(roster_ok), str(ranked_ok), _guard.units.size(), north, str(clear_ok),
			_host.units.size(), south, str(host_ok)])
	var ok: bool = roster_ok and clear_ok and host_ok
	print("FORM_VERDICT %s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)

func _avg_y(arr: Array) -> float:
	if arr.is_empty():
		return 0.0
	var s := 0.0
	for n in arr:
		s += n.global_position.y
	return s / arr.size()
