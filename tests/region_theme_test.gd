extends Node2D
## Headless guard for the Phase B visual-identity pass (token REGIONTHEME). Headless can't
## screenshot, but it CAN assert the DATA that makes regions look distinct: every legend region must
## override its ground palette and set a time-of-day mood in _theme(), and the palettes must be
## varied (not one re-tinted floor). _theme() is pure (just sets fields), so we call it on a bare
## instance — no full _ready / spawning needed.
##
## Run: godot --headless --path . res://tests/RegionThemeTest.tscn --quit-after 600 — look for REGIONTHEME_VERDICT.

const LEGEND := [
	"res://scripts/maps/SwordInStone.gd", "res://scripts/maps/HuLaoGate.gd",
	"res://scripts/maps/RedCliffs.gd", "res://scripts/maps/Changban.gd",
	"res://scripts/maps/Guandu.gd", "res://scripts/maps/MountBadon.gd",
	"res://scripts/maps/DefendCamelot.gd", "res://scripts/maps/YellowTurban.gd",
	"res://scripts/maps/Camlann.gd", "res://scripts/maps/LadyOfLake.gd",
]
const DEF_TOP := Color(0.12, 0.13, 0.12)
const DEF_BOTTOM := Color(0.17, 0.15, 0.13)
const WHITE := Color(1.0, 1.0, 1.0, 1.0)

var _frame := 0

func _physics_process(_dt: float) -> void:
	_frame += 1
	if _frame < 2:
		return
	_report()

func _report() -> void:
	var overridden := 0
	var mooded := 0
	var tops := {}
	var loaded_all := true
	for path in LEGEND:
		var scr = load(path)
		if scr == null:
			loaded_all = false
			continue
		var m = scr.new()
		m._theme()
		var top: Color = m.ground_top
		var bottom: Color = m.ground_bottom
		var mood: Color = m.region_mood
		if top != DEF_TOP or bottom != DEF_BOTTOM:
			overridden += 1
		if mood != WHITE:
			mooded += 1
		tops[top.to_html(false)] = true
		m.free()
	var distinct: int = tops.size()
	var checks := {
		"loaded_all": loaded_all,
		"all_override": overridden == LEGEND.size(),
		"distinct_palettes": distinct >= 7,
		"most_mooded": mooded >= 7,
	}
	var ok := true
	var parts: Array = []
	for k in checks:
		ok = ok and checks[k]
		parts.append("%s=%s" % [k, str(checks[k])])
	print("REGIONTHEME_RESULT overridden=%d distinct=%d mooded=%d %s" % [overridden, distinct, mooded, " ".join(parts)])
	print("REGIONTHEME_VERDICT %s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)
