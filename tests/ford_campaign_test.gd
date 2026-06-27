extends Node2D
## Headless test for the Hold-the-Ford CAMPAIGN wiring (token FORDCAMPAIGN).
##
## Hold the Ford is the ORIGINAL standalone level (scripts/Battlefield.gd, not a BattleMap
## subclass), so it had to be wired into the campaign spine by hand. This asserts that wiring,
## mirroring BattleMap's pattern:
##   - a reusable PauseMenu overlay is present (Esc / mobile MENU → return-to-lobby),
##   - on VICTORY the guarded Campaign.mark_completed(scene_file_path) fires (the Ford reads as
##     CLEARED afterwards), and
##   - the ScoreScreen receives a NON-EMPTY next_path + blurb (the next trial + its story beat),
##     i.e. the 5-arg show_result form that ties the battles into one campaign.
##
## We force a deterministic win: freeze the garrison, advance the wave counter past the last
## wave, make the DefeatOfficer objective "see" an officer (spawn one in the officers group, then
## free it), and clear the field — satisfying RepelWaves + DefeatOfficer with HoldLine intact.
##
## Run: godot --headless --path . res://tests/FordCampaignTest.tscn --quit-after 600 — look for FORDCAMPAIGN_VERDICT.

const BANNER := preload("res://scenes/BannerBearer.tscn")
const FORD_PATH := "res://scenes/Battlefield.tscn"

var bf
var _frame := 0
var _officer = null
var _had_pause := false
var _next_path := ""
var _blurb := ""
var _was_cleared_before := false
var _cleared_after := false

func _ready() -> void:
	# Deterministic campaign start: ignore any saved progress so the Ford begins UN-cleared.
	var c = get_node_or_null("/root/Campaign")
	if c:
		c.reset()
		_was_cleared_before = c.is_cleared(FORD_PATH)
	bf = load(FORD_PATH).instantiate()
	add_child(bf)
	# A reusable PauseMenu overlay must have been instanced (Esc / mobile MENU → lobby).
	_had_pause = get_tree().get_nodes_in_group("pause_menu").size() >= 1
	# Freeze the garrison so ONLY our scripted state drives the win (no stray breaches/officers).
	for e in get_tree().get_nodes_in_group("targets"):
		e.ai_enabled = false
	print("FORDCAMPAIGN_READY pause=%s cleared_before=%s" % [str(_had_pause), str(_was_cleared_before)])

func _physics_process(_delta: float) -> void:
	_frame += 1
	if _frame == 6:
		# Clear the pre-placed field, advance the wave counter to the end, and drop an OFFICER
		# (a support raider in the "officers" group) so DefeatOfficer registers that one appeared.
		for t in get_tree().get_nodes_in_group("targets"):
			if is_instance_valid(t):
				t.queue_free()
		bf._wave = bf._waves.size()
		_officer = BANNER.instantiate()
		bf.add_child(_officer)
		_officer.ai_enabled = false
		_officer.global_position = Vector2(0.0, -120.0)   # well north of the defence line
	elif _frame == 24:
		# The officer has been "seen" by a scan tick; remove it (officer down) and clear the field
		# so RepelWaves + DefeatOfficer both complete on the next evaluation → VICTORY.
		if is_instance_valid(_officer):
			_officer.queue_free()
		for t in get_tree().get_nodes_in_group("targets"):
			if is_instance_valid(t):
				t.queue_free()
	elif _frame >= 70:
		_report()

func _report() -> void:
	var c = get_node_or_null("/root/Campaign")
	if c:
		_cleared_after = c.is_cleared(FORD_PATH)
	# The ScoreScreen stores the campaign hand-off the level passed it (5-arg show_result).
	if bf._score_screen:
		_next_path = String(bf._score_screen._next_path)
		_blurb = String(bf._score_screen._blurb.text) if bf._score_screen._blurb else ""

	var won: bool = bf._won
	var has_pause: bool = _had_pause
	var marked: bool = (c == null) or _cleared_after   # if no autoload, the guard simply no-ops
	var has_next: bool = _next_path != ""
	var has_blurb: bool = _blurb != ""

	# The win must actually have advanced the campaign, not just toggled a flag.
	var ok: bool = won and has_pause and marked and has_next and has_blurb
	print("FORDCAMPAIGN_RESULT won=%s pause=%s cleared=%s next='%s' blurb_len=%d" % [
		str(won), str(has_pause), str(_cleared_after), _next_path, _blurb.length()])
	print("FORDCAMPAIGN_VERDICT %s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)
