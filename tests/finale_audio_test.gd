extends Node2D
## Headless test for the campaign FINALE — victory/defeat audio + legend-complete moment.
##
## Three things, all on the event/data path (headless has NO audio device, so we verify the
## chosen event NAME + the registered voices, never playback):
##   (a) AUDIO PATH — ScoreScreen.show_result picks the victory stinger on a win and the defeat
##       knell on a loss (its `last_event`), and SoundBank has BOTH new voices registered;
##   (b) FINALE — Campaign.is_section_complete(SEC_ARTHUR) flips true once every Arthurian battle
##       is marked cleared, and is_finale(last_arthur_path) is true (and a non-finale path isn't);
##   (c) PROGRESS — Campaign.cleared_count() tracks the marks.
##
## Run: godot --headless --path . res://tests/FinaleAudioTest.tscn --quit-after 600
## Look for FINALE_VERDICT.

const SCORE_SCREEN := preload("res://scenes/ui/ScoreScreen.tscn")

var _screen
var _frame := 0

func _ready() -> void:
	_screen = SCORE_SCREEN.instantiate()
	add_child(_screen)

func _physics_process(_delta: float) -> void:
	_frame += 1
	if _frame >= 4:
		_report()

func _report() -> void:
	var checks := {}

	# ── (a) audio path: the chosen event NAME per outcome ──────────────────────
	_screen.show_result(true, 10, 30.0)
	var win_event: String = String(_screen.last_event)
	checks["win_event"] = win_event == _screen.EVT_VICTORY and win_event == "victory_fanfare"

	_screen.show_result(false, 3, 8.0)
	var loss_event: String = String(_screen.last_event)
	checks["loss_event"] = loss_event == _screen.EVT_DEFEAT and loss_event == "defeat_knell"

	# Both new voices are registered in the SoundBank (real procedural streams).
	var sb = get_node_or_null("/root/SoundBank")
	var voices_ok := false
	if sb != null and "_bank" in sb:
		var bank = sb._bank
		voices_ok = bank.has("victory_fanfare") and bank.has("defeat_knell") \
			and bank["victory_fanfare"] != null and bank["defeat_knell"] != null
	checks["voices_registered"] = voices_ok

	# ── (b) finale: legend-complete + is_finale ────────────────────────────────
	Campaign.reset()
	# Gather every Arthurian battle in order; the last one is the finale.
	var arthur_paths: Array = []
	for s in Campaign.stages():
		if String(s["section"]) == Campaign.SEC_ARTHUR:
			arthur_paths.append(String(s["path"]))
	checks["has_arthur"] = arthur_paths.size() >= 2
	var last_arthur: String = String(arthur_paths[arthur_paths.size() - 1]) if arthur_paths.size() > 0 else ""

	# is_finale picks out the LAST Arthurian stage and nothing else.
	checks["is_finale_last"] = Campaign.is_finale(last_arthur)
	checks["not_finale_first"] = not Campaign.is_finale(String(arthur_paths[0]))
	checks["not_finale_empty"] = not Campaign.is_finale("")

	# The section is NOT complete until every Arthurian battle is cleared.
	checks["incomplete_at_start"] = not Campaign.is_section_complete(Campaign.SEC_ARTHUR)
	var i := 0
	while i < arthur_paths.size():
		Campaign.mark_completed(String(arthur_paths[i]))
		# Still incomplete until the very last mark lands.
		if i < arthur_paths.size() - 1 and Campaign.is_section_complete(Campaign.SEC_ARTHUR):
			checks["incomplete_at_start"] = false   # flipped true too early
		i += 1
	checks["complete_after_all"] = Campaign.is_section_complete(Campaign.SEC_ARTHUR)

	# ── (c) progress: cleared_count reflects the marks ─────────────────────────
	# Exactly the Arthurian stages are cleared right now.
	checks["count_matches"] = Campaign.cleared_count() == arthur_paths.size()
	checks["count_le_total"] = Campaign.cleared_count() <= Campaign.total()

	# A fresh clear of one more (non-Arthur) stage bumps the count by one.
	var extra := ""
	for s in Campaign.stages():
		if String(s["section"]) != Campaign.SEC_ARTHUR:
			extra = String(s["path"])
			break
	if extra != "":
		var before: int = Campaign.cleared_count()
		Campaign.mark_completed(extra)
		checks["count_bumps"] = Campaign.cleared_count() == before + 1
	else:
		checks["count_bumps"] = true

	Campaign.reset()   # leave no persisted progress behind
	checks["reset_zeroes"] = Campaign.cleared_count() == 0

	var ok := true
	var parts: Array = []
	for k in checks:
		ok = ok and checks[k]
		parts.append("%s=%s" % [k, str(checks[k])])
	print("FINALE_RESULT win=%s loss=%s %s" % [win_event, loss_event, " ".join(parts)])
	print("FINALE_VERDICT %s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)
