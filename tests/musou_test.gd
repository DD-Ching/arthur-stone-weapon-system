extends Node2D
## Headless test for the MUSOU gauge + screen-clearing ULTIMATE.
##
## Fills Arthur's musou gauge, fires the ultimate (the public trigger), and asserts:
##   - a ring of nearby enemies is LAUNCHED outward and/or DAMAGED (health dropped),
##   - the musou gauge resets back toward 0 after firing,
##   - add_musou() emits `musou_changed` (the HUD's hook).
##
## Drives Arthur's weapon/state directly (his _physics_process is off) so nothing
## fights the test. Run:
##   godot --headless --path . res://tests/MusouTest.tscn --quit-after 600
## Look for the MUSOU_VERDICT line.

var arthur
var enemies := []
var _start_pos := []      ## each enemy's pre-ultimate position
var _start_health := []   ## each enemy's pre-ultimate health
var _frame := 0
var _signal_fired := false
var _musou_after_fill := 0.0
var _musou_after_ult := 0.0
var _fired := false

const RING := 150.0       ## well within the ultimate's ~360 radius and the brief's 200px

func _ready() -> void:
	Impact.reset()
	arthur = load("res://scenes/Arthur.tscn").instantiate()
	add_child(arthur)
	arthur.global_position = Vector2.ZERO
	arthur.set_physics_process(false)   # we drive the ultimate directly

	# `musou_changed` must fire when the gauge changes — connect BEFORE filling it.
	arthur.musou_changed.connect(func(_c, _m): _signal_fired = true)

	# A ring of light soldiers around Arthur, all in the "targets" group.
	for i in 6:
		var e = load("res://scenes/LightSoldier.tscn").instantiate()
		add_child(e)
		var a := float(i) / 6.0 * TAU
		e.global_position = Vector2(cos(a), sin(a)) * RING
		enemies.append(e)
	print("MUSOU_READY ok")

func _physics_process(_delta: float) -> void:
	_frame += 1
	if _frame == 2:
		# Record the baseline, fill the gauge, then fire the ultimate.
		for e in enemies:
			_start_pos.append(e.global_position)
			_start_health.append(e.health)
		arthur.add_musou(arthur.max_musou)        # fill → should emit musou_changed
		_musou_after_fill = arthur.musou
		arthur.trigger_musou_ultimate()           # screen-clearing radial launch
		_musou_after_ult = arthur.musou
		_fired = true
	elif _frame >= 34:
		_report()

func _report() -> void:
	var launched := 0
	var damaged := 0
	for i in range(enemies.size()):
		var e = enemies[i]
		if not is_instance_valid(e):
			# Defeated + faded out entirely → unambiguously affected.
			launched += 1
			damaged += 1
			continue
		if e.global_position.distance_to(_start_pos[i]) > 12.0:
			launched += 1
		if e.health < _start_health[i] - 0.01:
			damaged += 1
	var affected := maxi(launched, damaged)
	print("MUSOU_RESULT launched=%d/6 damaged=%d/6 musou_full=%.1f musou_after=%.1f signal=%s fired=%s"
		% [launched, damaged, _musou_after_fill, _musou_after_ult, str(_signal_fired), str(_fired)])
	var ok: bool = _fired \
		and _signal_fired \
		and _musou_after_fill >= arthur.max_musou - 0.01 \
		and _musou_after_ult <= arthur.max_musou * 0.5 \
		and affected >= 4
	print("MUSOU_VERDICT %s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)
