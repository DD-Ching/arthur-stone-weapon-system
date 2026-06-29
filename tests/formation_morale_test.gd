extends Node2D
## Headless test for FORMATION MORALE (token FORMMORALE) — the core Musou "behead the unit" loop:
## cut down a formation's commander (the officer at the back) and the surviving ranks ROUT.
##
## Spawns an OfficerGuard (2 shields + 2 spears + 1 banner-commander), confirms nobody is panicked,
## fells the commander, then asserts (a) every surviving rank unit gets a panic stun and (b) the
## formation's one-shot rout flag fired.
##
## Run: godot --headless --path . res://tests/FormationMoraleTest.tscn --quit-after 600 — look for FORMMORALE_VERDICT.

const OFFICER_GUARD := preload("res://scenes/formations/OfficerGuard.tscn")

var _guard
var _commander = null
var _survivors := []
var _frame := 0
var _stunned_before := 0

func _ready() -> void:
	Impact.reset()
	_guard = OFFICER_GUARD.instantiate()
	add_child(_guard)   # auto_spawn → the roster spawns on _ready

func _physics_process(_dt: float) -> void:
	_frame += 1
	if _frame == 2:
		# The commander is the back officer (last unit). Gather the survivors + confirm none panicked.
		_commander = _guard.units[-1] if _guard.units.size() > 0 else null
		for u in _guard.units:
			if u != _commander and is_instance_valid(u):
				_survivors.append(u)
				if "_stun" in u and u._stun > 0.0:
					_stunned_before += 1
		# Fell the commander — its fall should rout the line.
		if _commander and _commander.has_method("_defeat"):
			_commander._defeat()
	elif _frame >= 8:
		_report()

func _report() -> void:
	var stunned_after := 0
	for u in _survivors:
		if is_instance_valid(u) and "_stun" in u and u._stun > 0.0:
			stunned_after += 1
	var has_survivors: bool = _survivors.size() >= 3
	var all_routed: bool = _survivors.size() > 0 and stunned_after >= _survivors.size()
	var flag_set: bool = bool(_guard._routed)
	var ok: bool = has_survivors and _stunned_before == 0 and all_routed and flag_set
	print("FORMMORALE_RESULT survivors=%d stunned_before=%d stunned_after=%d routed_flag=%s"
		% [_survivors.size(), _stunned_before, stunned_after, str(flag_set)])
	print("FORMMORALE_VERDICT %s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)
