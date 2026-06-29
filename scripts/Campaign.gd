extends Node
## Campaign — the ordered story progression that ties every battle into ONE connected game.
##
## Registered as an autoload (see project.godot [autoload]), mirroring Impact: a single source
## of truth any screen can read as `Campaign.*`. It owns three things:
##
##   1. The ORDERED stage table (the Arthurian legend as the spine, then the Ford & Trials, then
##      the Three-Kingdoms BONUS) — id, title, scene path, section, and a short STORY BLURB shown
##      between battles so the campaign reads as a told story, not a scattered menu.
##   2. The CLEARED set — which battles the player has won — persisted to user://campaign.cfg via
##      ConfigFile (web-safe, single-threaded), so progress survives a refresh.
##   3. The flow helpers the lobby / pause menu / score screen / BattleMap all reuse:
##      next_path() (advance to the next battle in the campaign), mark_completed(), is_unlocked()
##      (the legend unlocks in order; trials + bonus are always open), is_cleared(), blurb_for().
##
## Build once, reuse many: there is no per-screen progression logic — every screen reads THIS.

const SAVE_PATH := "user://campaign.cfg"

## Section ids (display + lock grouping). Shared with the lobby so the two never drift.
## The legend is the one connected journey (ten regions, unlocks in order); the Training Yard
## (Hold the Ford + the challenge rooms) is always-open practice reached from the Camelot node.
const SEC_ARTHUR := "arthur"
const SEC_TRIALS := "trials"

const SECTION_LABELS := {
	SEC_ARTHUR: "— THE LEGEND OF KING ARTHUR —",
	SEC_TRIALS: "— THE TRAINING YARD —",
}

## The campaign, in ONE connected journey across Britain (Logres). The legend is ten regions that
## unlock IN ORDER (clear a region to open the next); `region`/`map_x`/`map_y` place each on the
## overworld Map of Britain and `links` draw the road between them. `blurb` is the story beat shown
## on deploy + the result screen. The Training Yard (Hold the Ford + the rooms) is always-open
## practice, reached from the Camelot node rather than sitting on the legend road.
const STAGES := [
	# ── THE LEGEND OF KING ARTHUR — the connected road, unlocks in order ──
	{"id": "sword_in_stone", "title": "The Sword in the Stone",
		"path": "res://scenes/maps/SwordInStone.tscn", "section": SEC_ARTHUR,
		"region": "churchyard", "map_x": 300.0, "map_y": 610.0, "links": ["the_marches"],
		"blurb": "No man could draw the blade from the stone. So the boy Arthur lifted the WHOLE STONE — and a kingdom found its king."},
	{"id": "the_marches", "title": "The Marches",
		"path": "res://scenes/maps/HuLaoGate.tscn", "section": SEC_ARTHUR,
		"region": "marches", "map_x": 470.0, "map_y": 520.0, "links": ["the_burning_fords"],
		"blurb": "The Saxon host tests the frontier. Hold the border fort and break their warlord — let them learn what guards this land."},
	{"id": "the_burning_fords", "title": "The Burning Fords",
		"path": "res://scenes/maps/RedCliffs.tscn", "section": SEC_ARTHUR,
		"region": "fords", "map_x": 650.0, "map_y": 470.0, "links": ["the_long_road"],
		"blurb": "Saxon longships crowd the crossing. Put them to the torch and hold the ford while the river burns."},
	{"id": "the_long_road", "title": "The Long Road",
		"path": "res://scenes/maps/Changban.tscn", "section": SEC_ARTHUR,
		"region": "road", "map_x": 500.0, "map_y": 395.0, "links": ["the_beacon_forts"],
		"blurb": "A town lies sacked behind you. Cover its people down the long road to Camelot — let none be taken."},
	{"id": "the_beacon_forts", "title": "The Beacon-Forts",
		"path": "res://scenes/maps/Guandu.tscn", "section": SEC_ARTHUR,
		"region": "beacons", "map_x": 700.0, "map_y": 345.0, "links": ["mount_badon"],
		"blurb": "The invasion lives on its supply. Seize the beacon-forts and burn the stores; starve the war to win it."},
	{"id": "mount_badon", "title": "Mount Badon",
		"path": "res://scenes/maps/MountBadon.tscn", "section": SEC_ARTHUR,
		"region": "badon", "map_x": 360.0, "map_y": 300.0, "links": ["defend_camelot"],
		"blurb": "The Saxon host climbs Mount Badon in an endless tide. Hold the hill, and the dream of Britain holds with it."},
	{"id": "defend_camelot", "title": "Defend Camelot",
		"path": "res://scenes/maps/DefendCamelot.tscn", "section": SEC_ARTHUR,
		"region": "camelot", "map_x": 520.0, "map_y": 235.0, "links": ["the_night_host"],
		"blurb": "Treachery within, a siege without. The Black Knight throws his host at the gate of Camelot. Hold it."},
	{"id": "the_night_host", "title": "The Night-Host",
		"path": "res://scenes/maps/YellowTurban.tscn", "section": SEC_ARTHUR,
		"region": "nighthost", "map_x": 700.0, "map_y": 210.0, "links": ["camlann"],
		"blurb": "Out of the dark moor comes a host that should not be — Morgan's making. Stand against it until the dawn breaks it."},
	{"id": "camlann", "title": "Camlann",
		"path": "res://scenes/maps/Camlann.tscn", "section": SEC_ARTHUR,
		"region": "camlann", "map_x": 430.0, "map_y": 150.0, "links": ["lady_of_lake"],
		"blurb": "The last field. Mordred's banner flies and Morgan's magic stirs. Here the legend ends — or is forged anew."},
	{"id": "lady_of_lake", "title": "The Lady of the Lake",
		"path": "res://scenes/maps/LadyOfLake.tscn", "section": SEC_ARTHUR,
		"region": "avalon", "map_x": 250.0, "map_y": 90.0, "links": [],
		"blurb": "Beyond the water waits Avalon. Carry the stone to the lake, and let the legend rest."},
	# ── THE TRAINING YARD — always-open practice, reached from the Camelot node ──
	{"id": "hold_ford", "title": "Hold the Ford",
		"path": "res://scenes/Battlefield.tscn", "section": SEC_TRIALS,
		"region": "training", "map_x": 0.0, "map_y": 0.0, "links": [],
		"blurb": "A river crossing, five waves of raiders, one stone."},
	{"id": "bowling_room", "title": "Bowling Room",
		"path": "res://scenes/rooms/BowlingRoom.tscn", "section": SEC_TRIALS,
		"region": "training", "map_x": 0.0, "map_y": 0.0, "links": [],
		"blurb": "One launched body, a packed formation. Knock them all down."},
	{"id": "wall_crush_room", "title": "Wall Crush Room",
		"path": "res://scenes/rooms/WallCrushRoom.tscn", "section": SEC_TRIALS,
		"region": "training", "map_x": 0.0, "map_y": 0.0, "links": [],
		"blurb": "Pin them to the stone walls. Crush, don't chase."},
	{"id": "rock_launcher_room", "title": "Rock Launcher Room",
		"path": "res://scenes/rooms/RockLauncherRoom.tscn", "section": SEC_TRIALS,
		"region": "training", "map_x": 0.0, "map_y": 0.0, "links": [],
		"blurb": "Let the rocks do the work. Launch, ricochet, repeat."},
	{"id": "combo_trial_room", "title": "Combo Trial Room",
		"path": "res://scenes/rooms/ComboTrialRoom.tscn", "section": SEC_TRIALS,
		"region": "training", "map_x": 0.0, "map_y": 0.0, "links": [],
		"blurb": "Keep the Stone Flow burning. Build the stack before the clock runs out."},
]

## id -> true for every cleared battle. Loaded from disk on boot, written on each win.
var _cleared := {}

func _ready() -> void:
	_load()

# ── stage lookups ─────────────────────────────────────────────────────────────
## The full ordered stage table (Array of Dictionaries). Screens iterate this.
func stages() -> Array:
	return STAGES

func _index_of_path(path: String) -> int:
	for i in STAGES.size():
		if STAGES[i]["path"] == path:
			return i
	return -1

func stage_for(path: String) -> Dictionary:
	var i := _index_of_path(path)
	return STAGES[i] if i >= 0 else {}

func id_for(path: String) -> String:
	var s := stage_for(path)
	return String(s.get("id", ""))

func title_for(path: String) -> String:
	var s := stage_for(path)
	return String(s.get("title", ""))

func section_for(path: String) -> String:
	var s := stage_for(path)
	return String(s.get("section", ""))

func blurb_for(path: String) -> String:
	var s := stage_for(path)
	return String(s.get("blurb", ""))

# ── overworld geography (for the Map of Britain) ──────────────────────────────
## The Arthurian region id for `path` ("churchyard"/"marches"/…/"avalon"/"training"), or "".
func region_for(path: String) -> String:
	var s := stage_for(path)
	return String(s.get("region", ""))

## The overworld map position for `path` (Vector2(map_x, map_y)); Vector2.ZERO if unplaced.
func map_pos_for(path: String) -> Vector2:
	var s := stage_for(path)
	if s.is_empty():
		return Vector2.ZERO
	return Vector2(float(s.get("map_x", 0.0)), float(s.get("map_y", 0.0)))

## The stage ids this region connects to on the journey road (drawn as the overworld line).
func links_for(path: String) -> Array:
	var s := stage_for(path)
	return s.get("links", [])

## The legend stages (SEC_ARTHUR) in play order — the regions the overworld plots as the road.
func legend_stages() -> Array:
	var out: Array = []
	for s in STAGES:
		if String(s["section"]) == SEC_ARTHUR:
			out.append(s)
	return out

# ── progress (cleared / unlocked) ─────────────────────────────────────────────
func is_cleared(path: String) -> bool:
	var id := id_for(path)
	return id != "" and _cleared.has(id)

## Record a win and persist it. Accepts the scene path (BattleMap passes scene_file_path).
func mark_completed(path: String) -> void:
	var id := id_for(path)
	if id == "":
		return
	if not _cleared.has(id):
		_cleared[id] = true
		_save()

## A stage is unlocked when: it's bonus/trials (always open), it's the FIRST battle of the
## legend, or the PREVIOUS legend battle has been cleared. So the Arthurian campaign reveals
## itself in order while practice + bonus stay open.
func is_unlocked(path: String) -> bool:
	var i := _index_of_path(path)
	if i < 0:
		return true
	var sec := String(STAGES[i]["section"])
	if sec != SEC_ARTHUR:
		return true
	# Find the previous stage in the SAME (arthur) section; unlocked if it's cleared.
	var j := i - 1
	while j >= 0:
		if String(STAGES[j]["section"]) == SEC_ARTHUR:
			return _cleared.has(String(STAGES[j]["id"]))
		j -= 1
	return true   # first arthur battle — always open

## The next battle to play after `path`: the following stage IN THE SAME SECTION whose scene
## exists on disk. "" if `path` is the last of its section (campaign/section complete).
func next_path(path: String) -> String:
	var i := _index_of_path(path)
	if i < 0:
		return ""
	var sec := String(STAGES[i]["section"])
	var j := i + 1
	while j < STAGES.size():
		if String(STAGES[j]["section"]) != sec:
			break
		var p := String(STAGES[j]["path"])
		if ResourceLoader.exists(p):
			return p
		j += 1
	return ""

## True once EVERY stage of `section` has been cleared. The campaign finale + any
## "section complete" banner read this (e.g. the legend is done when all SEC_ARTHUR
## battles are won). Empty/unknown section → false (nothing to complete).
func is_section_complete(section: String) -> bool:
	var any := false
	for s in STAGES:
		if String(s["section"]) != section:
			continue
		any = true
		if not _cleared.has(String(s["id"])):
			return false
	return any

## True when `path` is the LAST stage of the Arthurian legend (SEC_ARTHUR) — the finale.
## Clearing it completes the legend, so the score screen shows the grand finale banner.
func is_finale(path: String) -> bool:
	return path != "" and path == _last_section_path(SEC_ARTHUR)

## The scene path of the last stage in `section` (in play order), or "" if the section is empty.
func _last_section_path(section: String) -> String:
	var last := ""
	for s in STAGES:
		if String(s["section"]) == section:
			last = String(s["path"])
	return last

## How many distinct stages have been cleared (matched to the stage table, so stray ids
## from an older save don't inflate the count). Pairs with total() for "X / N" progress.
func cleared_count() -> int:
	var c := 0
	for s in STAGES:
		if _cleared.has(String(s["id"])):
			c += 1
	return c

## Total number of stages in the campaign (the denominator for cleared_count()).
func total() -> int:
	return STAGES.size()

## Wipe all progress (new game / tests).
func reset() -> void:
	_cleared = {}
	_save()

# ── persistence (ConfigFile — web-safe, single-threaded) ──────────────────────
func _load() -> void:
	_cleared = {}
	var cfg := ConfigFile.new()
	var err := cfg.load(SAVE_PATH)
	if err != OK:
		return
	var arr = cfg.get_value("progress", "cleared", PackedStringArray())
	for id in arr:
		_cleared[String(id)] = true

func _save() -> void:
	var cfg := ConfigFile.new()
	var arr := PackedStringArray()
	for id in _cleared.keys():
		arr.append(String(id))
	cfg.set_value("progress", "cleared", arr)
	cfg.save(SAVE_PATH)
