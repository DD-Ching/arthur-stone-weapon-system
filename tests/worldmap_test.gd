extends Node2D
## Headless test for the Worldmap overworld (token WORLDMAP) — the connected Map of Britain that
## replaces the flat stage list. Instantiates Worldmap ALONE, steps a frame so it builds its node
## graph from Campaign, and asserts:
##   - it resolved the ten legend regions, in Campaign road order, every path loadable;
##   - the title is Arthurian (contains STONE/ARTHUR, never 三國);
##   - navigation (_move ±1) advances + WRAPS along the road;
##   - selected_path() is a valid loadable scene;
##   - the JOURNEY gates: at a fresh campaign the first region is open (rideable) and a later one
##     is sealed (locked) — i.e. there is a real progression, not a flat pick-anything list;
##   - the first region carries road links (so the overworld can draw the road).
##
## Run: godot --headless --path . res://tests/WorldmapTest.tscn --quit-after 600 — look for WORLDMAP_VERDICT.

const WORLDMAP := preload("res://scenes/ui/Worldmap.tscn")

var _map
var _frame := 0

func _ready() -> void:
	Campaign.reset()   # deterministic lock state: only the first legend region open
	_map = WORLDMAP.instantiate()
	add_child(_map)

func _physics_process(_dt: float) -> void:
	_frame += 1
	if _frame >= 2:
		_report()

func _report() -> void:
	var checks := {}
	var n: int = _map.nodes.size()
	checks["ten_regions"] = n >= 10

	var all_exist := true
	for nd in _map.nodes:
		if not ResourceLoader.exists(String(nd["path"])):
			all_exist = false
	checks["all_exist"] = all_exist

	# Nodes match Campaign's legend (same scenes, same road order).
	var legend: Array = Campaign.legend_stages()
	var order_ok := (n == legend.size())
	if order_ok:
		for i in n:
			if String(_map.nodes[i]["path"]) != String(legend[i]["path"]):
				order_ok = false
	checks["matches_legend"] = order_ok

	var title: String = _map.TITLE_TEXT
	checks["arthur_title"] = title.find("三國") < 0 \
		and (title.to_upper().find("ARTHUR") >= 0 or title.to_upper().find("STONE") >= 0)

	# Navigation advances + wraps both ways.
	_map.selected = 0
	_map._move(1)
	checks["advance"] = _map.selected == 1
	_map.selected = n - 1
	_map._move(1)
	checks["wrap_fwd"] = _map.selected == 0
	_map.selected = 0
	_map._move(-1)
	checks["wrap_back"] = _map.selected == n - 1

	# The selected region resolves to a loadable scene.
	_map.selected = 0
	checks["sel_path"] = _map.selected_path() != "" and ResourceLoader.exists(_map.selected_path())

	# The JOURNEY gates: first region open, a later region sealed (real progression).
	_map.selected = 0
	checks["first_open"] = _map.selected_unlocked()
	var later_locked := false
	for i in range(1, n):
		if not bool(_map.nodes[i]["unlocked"]):
			later_locked = true
	checks["later_sealed"] = later_locked

	# The road: the first region links onward (so the overworld can draw the journey line).
	checks["has_road"] = n > 0 and Campaign.links_for(String(_map.nodes[0]["path"])).size() >= 1

	var ok := true
	var parts: Array = []
	for k in checks:
		ok = ok and checks[k]
		parts.append("%s=%s" % [k, str(checks[k])])
	print("WORLDMAP_RESULT regions=%d %s" % [n, " ".join(parts)])
	print("WORLDMAP_VERDICT %s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)
