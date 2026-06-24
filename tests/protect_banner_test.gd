extends Node
## Pure-logic test for ProtectBannerObjective (no scene). Asserts the protect-banner
## CONSTRAINT behaves like its sibling HoldLine: it tracks an allied banner's life,
## fails (→ lose) when the banner is gone, never reports "done", and drives the
## ObjectiveManager to emit a loss when the ward dies.
##
## Run: godot --headless --path . res://tests/ProtectBannerTest.tscn — look for
## PROTECT_OBJ_VERDICT.

func _ready() -> void:
	var obj := ProtectBannerObjective.new()

	# 1) Banner alive: not failed, not done, fragment shows it's holding.
	obj.evaluate({"ward_alive": true})
	var frag_alive: String = obj.fragment({"ward_alive": true})
	var a: bool = not obj.is_failed() and not obj.is_done() and frag_alive.contains("BANNER OK")

	# 2) Banner gone: failed, still never done, fragment shows the loss.
	obj.evaluate({"ward_alive": false})
	var frag_dead: String = obj.fragment({"ward_alive": false})
	var b: bool = obj.is_failed() and not obj.is_done() and frag_dead.contains("BANNER LOST")

	# 3) As a required constraint, the manager emits `lost` when the ward dies. Pair it with a
	#    still-incomplete completable objective (RepelWaves: waves not yet cleared) so the win
	#    doesn't fire first — proving the constraint gates the loss without ever being "done".
	var m := ObjectiveManager.new()
	m.add(RepelWavesObjective.new()).add(ProtectBannerObjective.new())
	var mid_ctx := {"wave": 1, "wave_count": 5, "alive": 20, "ward_alive": true}
	m.evaluate(mid_ctx)
	var c1: bool = not m.won and not m.lost
	mid_ctx["ward_alive"] = false
	m.evaluate(mid_ctx)
	var c2: bool = m.lost and not m.won
	var c: bool = c1 and c2

	var ok: bool = a and b and c
	print("PROTECT_OBJ_RESULT a=%s b=%s c=%s" % [str(a), str(b), str(c)])
	print("PROTECT_OBJ_VERDICT %s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)
