extends Node2D
## Headless test for the GeneralHealthbar boss-HP overlay (token BOSSBAR).
##
## Stands a single named "general" up ALONE (a TargetDummy with is_general + a finite
## health) — no Battlefield, no other units — and drives the self-tracking overlay through
## its three states:
##   1) full health  → the bar becomes VISIBLE, tracks 1 general, name "LU BU", ratio ~1.0;
##   2) half health   → after a refresh, the tracked ratio is ~0.5;
##   3) general freed → the bar tracks 0 generals and HIDES.
##
## Run: godot --headless --path . res://tests/BossHealthbarTest.tscn — look for BOSSBAR_VERDICT.

const GENERAL_HEALTHBAR := preload("res://scenes/ui/GeneralHealthbar.tscn")
const TARGET_DUMMY := preload("res://scenes/TargetDummy.tscn")

var _bar
var _general
var _phase := 0
var _wait := 12          ## warm-up frames so the overlay's refresh timer runs before phase 0

# Captured per-phase observations.
var _vis_full := false
var _count_full := -1
var _name_full := ""
var _ratio_full := -1.0
var _ratio_half := -1.0
var _vis_gone := true
var _count_gone := -1

func _ready() -> void:
	_bar = GENERAL_HEALTHBAR.instantiate()
	add_child(_bar)

	# Build a general WITHOUT depending on any other unit: a bare TargetDummy whose exports
	# are set BEFORE add_child, so its _ready joins the "generals" group.
	_general = TARGET_DUMMY.instantiate()
	_general.is_general = true
	_general.enemy_name = "LU BU"
	_general.max_health = 300.0
	_general.faction = "wu"
	add_child(_general)
	# Enemy._ready sets health = max_health; pin it explicitly so the test owns the value.
	_general.health = 300.0

func _physics_process(_delta: float) -> void:
	# Let several frames pass between phase transitions so the overlay's light refresh timer
	# (and its _ready seed) certainly run before each assertion.
	if _wait > 0:
		_wait -= 1
		return
	match _phase:
		0:
			_vis_full = _bar.visible
			_count_full = _bar.tracked_count()
			if _count_full > 0:
				_name_full = _bar.name_for(0)
				_ratio_full = _bar.ratio_for(0)
			# Drop the general to half and let it refresh.
			_general.health = 150.0
			_phase = 1
			_wait = 8
		1:
			_ratio_half = _bar.ratio_for(0)
			# Remove the general entirely.
			_general.queue_free()
			_phase = 2
			_wait = 8
		2:
			_vis_gone = _bar.visible
			_count_gone = _bar.tracked_count()
			_phase = 3
		3:
			_report()

func _report() -> void:
	var full_ok: bool = _vis_full and _count_full == 1 and _name_full == "LU BU" \
		and absf(_ratio_full - 1.0) < 0.02
	var half_ok: bool = absf(_ratio_half - 0.5) < 0.02
	var gone_ok: bool = (not _vis_gone) and _count_gone == 0

	print("BOSSBAR_RESULT vis_full=%s count=%d name=%s ratio_full=%.3f ratio_half=%.3f | vis_gone=%s count_gone=%d"
		% [str(_vis_full), _count_full, _name_full, _ratio_full, _ratio_half,
			str(_vis_gone), _count_gone])
	var ok: bool = full_ok and half_ok and gone_ok
	print("BOSSBAR_VERDICT %s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)
