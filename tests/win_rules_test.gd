extends Node2D
## Headless test for the boss-gated win rules (token WINRULE) — the "you won without beating the
## boss / you won instantly" fixes.
##
## Asserts: DefeatGeneralObjective doesn't complete at 0 generals (before the boss appears), stays
## open while a general lives, and completes once the seen general falls. RepelWavesObjective does
## NOT fire at frame 0 / with no waves (the `started` guard), and only completes after every wave
## has spawned and the field is clear. Composed in an ObjectiveManager, victory is held OPEN while
## a general still stands and is only declared once the boss is down too.
##
## Run: godot --headless --path . res://tests/WinRulesTest.tscn --quit-after 600 — look for WINRULE_VERDICT.

var _frame := 0

func _physics_process(_dt: float) -> void:
	_frame += 1
	if _frame < 2:
		return
	_report()

func _report() -> void:
	# DefeatGeneralObjective: 0 -> not done (unseen); 1 -> not done (alive); 0 -> done (felled).
	var dg := DefeatGeneralObjective.new("Fell the boss")
	dg.evaluate({"generals": 0})
	var dg_start: bool = not dg.is_done()
	dg.evaluate({"generals": 1})
	var dg_alive: bool = not dg.is_done()
	dg.evaluate({"generals": 0})
	var dg_felled: bool = dg.is_done()

	# RepelWavesObjective: the zero-wave frame-0 guard (wave_count 0 must NOT read as "repelled"
	# against an empty field), not-yet-done mid-fight, then proper completion.
	var rw := RepelWavesObjective.new()
	rw.evaluate({"wave": 0, "wave_count": 0, "alive": 0})
	var rw_frame0: bool = not rw.is_done()
	rw.evaluate({"wave": 1, "wave_count": 5, "alive": 0})
	var rw_midfight: bool = not rw.is_done()
	rw.evaluate({"wave": 5, "wave_count": 5, "alive": 1})
	var rw_repelled: bool = rw.is_done()

	# Composed: a manager with both required objectives must NOT win while a general lives, and
	# WINS once the boss is also down — even though the waves are already repelled.
	var mgr := ObjectiveManager.new()
	mgr.add(RepelWavesObjective.new())
	mgr.add(DefeatGeneralObjective.new("Fell the boss"))
	mgr.evaluate({"started": true, "wave": 5, "wave_count": 5, "alive": 0, "generals": 1})
	var held_open: bool = not mgr.won
	mgr.evaluate({"started": true, "wave": 5, "wave_count": 5, "alive": 0, "generals": 0})
	var won_after_boss: bool = mgr.won

	var ok: bool = dg_start and dg_alive and dg_felled and rw_frame0 and rw_midfight \
		and rw_repelled and held_open and won_after_boss
	print("WINRULE_RESULT dg_start=%s dg_alive=%s dg_felled=%s rw_frame0=%s rw_mid=%s rw_repelled=%s held=%s won=%s" % [
		str(dg_start), str(dg_alive), str(dg_felled), str(rw_frame0), str(rw_midfight),
		str(rw_repelled), str(held_open), str(won_after_boss)])
	print("WINRULE_VERDICT %s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)
