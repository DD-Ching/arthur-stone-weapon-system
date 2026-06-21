extends Node
## Pure-logic test for the reusable objectives module (no scene). Asserts the
## ObjectiveManager composes win/lose correctly:
##   - waves cleared but the officer still alive → NOT won (a completable objective gates),
##   - officer then defeated → won,
##   - a constraint objective (HoldLine) failing → lost, and never blocks the win,
##   - an objective that never had its trigger appear stays incomplete.
##
## Run: godot --headless --path . res://tests/ObjectivesTest.tscn — look for OBJ_VERDICT.

func _ready() -> void:
	var m := ObjectiveManager.new()
	m.add(RepelWavesObjective.new()).add(DefeatOfficerObjective.new()).add(HoldLineObjective.new())

	# 1) every wave repelled + field clear, but the officer is still alive → no win yet.
	m.evaluate({"wave": 5, "wave_count": 5, "alive": 1, "breaches": 0, "max_breaches": 12, "officers": 1})
	var a: bool = not m.won and not m.lost

	# 2) officer now defeated, field clear → win (the constraint HoldLine never blocked it).
	m.evaluate({"wave": 5, "wave_count": 5, "alive": 0, "breaches": 0, "max_breaches": 12, "officers": 0})
	var b: bool = m.won and not m.lost

	# 3) a constraint failing (too many breaches) → loss.
	var m2 := ObjectiveManager.new()
	m2.add(HoldLineObjective.new())
	m2.evaluate({"breaches": 12, "max_breaches": 12})
	var c: bool = m2.lost

	# 4) an officer that never appeared leaves DefeatOfficer incomplete → no win.
	var m3 := ObjectiveManager.new()
	m3.add(DefeatOfficerObjective.new())
	m3.evaluate({"officers": 0})
	var d: bool = not m3.won

	# 5) soft-lock regression: field cleared + officer defeated with breaches in the old
	#    dead band [max/2, max-1] must now resolve to a WIN (not limbo, not loss).
	var m4 := ObjectiveManager.new()
	m4.add(RepelWavesObjective.new()).add(DefeatOfficerObjective.new()).add(HoldLineObjective.new())
	m4.evaluate({"wave": 5, "wave_count": 5, "alive": 0, "breaches": 8, "max_breaches": 12, "officers": 1})
	m4.evaluate({"wave": 5, "wave_count": 5, "alive": 0, "breaches": 8, "max_breaches": 12, "officers": 0})
	var e: bool = m4.won and not m4.lost

	var ok: bool = a and b and c and d and e
	print("OBJ_RESULT a=%s b=%s c=%s d=%s e=%s" % [str(a), str(b), str(c), str(d), str(e)])
	print("OBJ_VERDICT %s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)
