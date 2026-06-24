extends Node2D
## Headless test for the ChargeGroup formation (a reusable Formation config):
##   - it spawns its full roster (a wide front rank of fast light chargers + a Cavalry
##     commander for punch), every unit on the raider team;
##   - the front rank is genuinely WIDE — the chargers spread far across the facing so it
##     reads as a loose flanking charge block, not a tight column;
##   - the whole block faces DOWN (toward the defenders), so the commander sits BEHIND
##     (north of) the front rank along the facing.
##
## Run: godot --headless --path . res://tests/ChargeGroupTest.tscn — look for CHARGE_GRP_VERDICT.

const CHARGE_GROUP := preload("res://scenes/formations/ChargeGroup.tscn")
const MIN_FRONT_WIDTH := 300.0   # the front rank must spread at least this wide (loose charge)

var _group
var _frame := 0

func _ready() -> void:
	_group = CHARGE_GROUP.instantiate()
	_group.position = Vector2(0, -200)   # faces DOWN; the commander sits to the north
	add_child(_group)

func _physics_process(_delta: float) -> void:
	_frame += 1
	if _frame >= 4:
		_report()

func _report() -> void:
	# Expected roster: front_count chargers + 1 commander.
	var expected: int = _group.front_count + (1 if _group.commander != null else 0)
	var roster_ok: bool = _group.units.size() == expected

	# Every unit is on the raider team (group "raiders" and the "targets" Arthur acts on).
	var team_ok := true
	# Split into front chargers vs. the rear commander by look, to measure the rank separately.
	var fronts: Array = []
	var rears: Array = []
	for u in _group.units:
		if not (u.is_in_group("raiders") and u.is_in_group("targets")):
			team_ok = false
		if u.look == "cavalry":
			rears.append(u)
		else:
			fronts.append(u)

	# The front rank is WIDE: the x-spread across the chargers clears the threshold.
	var min_x := 1.0e9
	var max_x := -1.0e9
	for u in fronts:
		min_x = minf(min_x, u.global_position.x)
		max_x = maxf(max_x, u.global_position.x)
	var width: float = (max_x - min_x) if fronts.size() > 0 else 0.0
	var wide_ok: bool = fronts.size() == _group.front_count and width >= MIN_FRONT_WIDTH

	# Facing is DOWN: the commander (rear rank) sits NORTH of the front rank along the facing.
	var faces_down: bool = _group.face.y > 0.0
	var rear_behind: bool = rears.size() > 0 and _avg_y(rears) < _avg_y(fronts) - 20.0
	var facing_ok: bool = faces_down and rear_behind

	print("CHARGE_GRP_RESULT units=%d expected=%d team=%s front=%d width=%.0f wide=%s face_down=%s rear_behind=%s"
		% [_group.units.size(), expected, str(team_ok), fronts.size(), width,
			str(wide_ok), str(faces_down), str(rear_behind)])
	var ok: bool = roster_ok and team_ok and wide_ok and facing_ok
	print("CHARGE_GRP_VERDICT %s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)

func _avg_y(arr: Array) -> float:
	if arr.is_empty():
		return 0.0
	var s := 0.0
	for n in arr:
		s += n.global_position.y
	return s / arr.size()
