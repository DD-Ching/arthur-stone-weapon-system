extends Node2D
## Headless test for the TOUCHSCREEN PERFORMANCE PROFILE (token MOBILE_PERF) — the dials that keep a
## phone smooth at peak swarm without touching desktop. Headless reports NO touchscreen, so this
## exercises the LOGIC directly via the `force` hooks the production code exposes:
##
##   1. Impact.DEBRIS_BUDGET is a positive number readable as before, defaults to the desktop 90, and
##      Impact.apply_mobile_profile(force) LOWERS it to the mobile cap (50) — and only ever lowers.
##   2. A BattleMap's _apply_mobile_profile(force) LOWERS density (≤ 1.6) + active_cap (≤ 80) and never
##      RAISES a value that already sits below the cap.
##   3. The DESKTOP path is unchanged: with no force + no touchscreen, the map keeps its authored dials
##      and Impact keeps the full 90 budget (so every other test, run desktop, sees identical numbers).
##
## Run: godot --headless --path . res://tests/MobilePerfTest.tscn --quit-after 600 — look for MOBILE_PERF_VERDICT.

var _frame := 0
var _debris_default_ok := false
var _debris_lowered_ok := false
var _debris_only_lowers_ok := false
var _map_lowered_ok := false
var _map_never_raises_ok := false
var _desktop_unchanged_ok := false

func _ready() -> void:
	# ── (1) Impact debris budget ─────────────────────────────────────────────
	Impact.reset()
	# Default is the full desktop budget — a positive, readable number (the shatter path + the
	# physics-foundation test both read it as Impact.DEBRIS_BUDGET).
	_debris_default_ok = Impact.DEBRIS_BUDGET == Impact.DEBRIS_BUDGET_DESKTOP \
		and Impact.DEBRIS_BUDGET == 90 and Impact.DEBRIS_BUDGET > 0
	# Forcing the mobile profile lowers it to the mobile cap (fewer concurrent chunks on a phone).
	Impact.apply_mobile_profile(true)
	_debris_lowered_ok = Impact.DEBRIS_BUDGET == Impact.DEBRIS_BUDGET_MOBILE \
		and Impact.DEBRIS_BUDGET < 90 and Impact.DEBRIS_BUDGET > 0
	# Idempotent + only-ever-lowers: re-applying never RAISES the budget back up.
	Impact.apply_mobile_profile(true)
	_debris_only_lowers_ok = Impact.DEBRIS_BUDGET == Impact.DEBRIS_BUDGET_MOBILE
	# Restore the autoload so later tests / the rest of this run see the desktop default again.
	Impact.DEBRIS_BUDGET = Impact.DEBRIS_BUDGET_DESKTOP

	# ── (2) BattleMap dials lowered on the (forced) mobile profile ───────────
	var m := _ProbeMap.new()
	var d0: float = m.density
	var c0: int = m.active_cap
	m._apply_mobile_profile(true)        # force the touchscreen path (headless has no touchscreen)
	_map_lowered_ok = m.density <= 1.6 and m.density < d0 and m.active_cap <= 80 and m.active_cap < c0
	m.free()

	# A map already BELOW the caps must keep its lower values (only-ever-reduce, never raise).
	var lean := _ProbeMap.new()
	lean.density = 1.0
	lean.active_cap = 60
	lean._apply_mobile_profile(true)
	_map_never_raises_ok = lean.density == 1.0 and lean.active_cap == 60
	lean.free()

	# ── (3) DESKTOP path: no force + no touchscreen → byte-identical dials ────
	var desk := _ProbeMap.new()
	var dd: float = desk.density
	var dc: int = desk.active_cap
	desk._apply_mobile_profile(false)    # headless = no touchscreen → must be a no-op
	var map_unchanged: bool = desk.density == dd and desk.active_cap == dc
	desk.free()
	# Impact's gate is the same: a non-forced call with no touchscreen leaves the budget alone.
	Impact.DEBRIS_BUDGET = Impact.DEBRIS_BUDGET_DESKTOP
	Impact.apply_mobile_profile(false)
	_desktop_unchanged_ok = map_unchanged and Impact.DEBRIS_BUDGET == 90

func _physics_process(_dt: float) -> void:
	_frame += 1
	if _frame >= 4:
		_report()

func _report() -> void:
	var ok: bool = _debris_default_ok and _debris_lowered_ok and _debris_only_lowers_ok \
		and _map_lowered_ok and _map_never_raises_ok and _desktop_unchanged_ok
	print("MOBILE_PERF_RESULT debris_default=%s debris_lowered=%s debris_only_lowers=%s map_lowered=%s map_never_raises=%s desktop_unchanged=%s budget=%d" % [
		str(_debris_default_ok), str(_debris_lowered_ok), str(_debris_only_lowers_ok),
		str(_map_lowered_ok), str(_map_never_raises_ok), str(_desktop_unchanged_ok), Impact.DEBRIS_BUDGET])
	print("MOBILE_PERF_VERDICT %s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)

## A bare BattleMap subclass used only to read/lower the exported dials — never added to the tree, so
## no Arthur/HUD boots. It just needs the base's exports + _apply_mobile_profile.
class _ProbeMap extends BattleMap:
	func _map_title() -> String:
		return "MOBILE PERF PROBE"
