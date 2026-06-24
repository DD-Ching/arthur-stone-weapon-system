extends Node2D
## Headless test for the ScoreScreen overlay (unit #8 — KO + time score screen).
##
## Instantiates ScoreScreen ALONE (not the full Battlefield) and drives show_result():
##   - a VICTORY result reveals the panel and its labels show the KO count, a victory word,
##     and the elapsed time formatted m:ss (73.5s -> "1:13");
##   - a DEFEAT result shows a defeat word + the new KO count.
##
## Run: godot --headless --path . res://tests/ScoreScreenTest.tscn — look for SCORE_UI_VERDICT.

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
	# Victory case: KO 42 at 73.5s -> "1:13".
	_screen.show_result(true, 42, 73.5)
	var vis_v: bool = _screen.visible
	var all_v := _all_text(_screen)
	var has_42: bool = all_v.find("42") != -1
	var has_time: bool = all_v.find("1:13") != -1
	var has_victory: bool = all_v.to_upper().find("VICTORY") != -1
	var victory_ok: bool = vis_v and has_42 and has_time and has_victory

	# Defeat case: KO 7 at 12.0s -> "0:12".
	_screen.show_result(false, 7, 12.0)
	var vis_d: bool = _screen.visible
	var all_d := _all_text(_screen)
	var has_7: bool = all_d.find("7") != -1
	var has_defeat: bool = all_d.to_upper().find("DEFEAT") != -1
	# The defeat banner must replace the victory word.
	var victory_gone: bool = all_d.to_upper().find("VICTORY") == -1
	var defeat_ok: bool = vis_d and has_7 and has_defeat and victory_gone

	print("SCORE_UI_RESULT vis_v=%s 42=%s 1:13=%s victory=%s | vis_d=%s 7=%s defeat=%s vic_gone=%s"
		% [str(vis_v), str(has_42), str(has_time), str(has_victory),
			str(vis_d), str(has_7), str(has_defeat), str(victory_gone)])
	var ok: bool = victory_ok and defeat_ok
	print("SCORE_UI_VERDICT %s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)

## Concatenate the text of every Label in the overlay's subtree.
func _all_text(node: Node) -> String:
	var s := ""
	if node is Label:
		s += node.text + "\n"
	for c in node.get_children():
		s += _all_text(c)
	return s
