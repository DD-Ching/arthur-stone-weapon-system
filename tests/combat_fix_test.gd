extends Node2D
## Headless test (token COMBATFIX) for two combat fixes:
##   - EVERY minion can attack: the formerly attackless support units (banner bearers, drummer,
##     Morgan le Fay) now carry an attack (a non-empty moveset), so no raider just walks.
##   - WEAPON CLASH: an enemy caught mid-strike can be PARRIED (is_striking()/parry_strike()) — the
##     strike is cancelled and it's staggered, the hook the stone uses to bat aside enemy weapons.
##
## Run: godot --headless --path . res://tests/CombatFixTest.tscn --quit-after 600 — look for COMBATFIX_VERDICT.

const ARMED := [
	"res://scenes/BannerBearer.tscn",
	"res://scenes/troops/StandardBearer.tscn",
	"res://scenes/troops/Drummer.tscn",
	"res://scenes/villains/MorganLeFay.tscn",
]

var _frame := 0

func _physics_process(_dt: float) -> void:
	_frame += 1
	if _frame < 2:
		return
	_report()

func _report() -> void:
	# (1) every formerly-attackless unit now has an attack (a non-empty moveset).
	var all_armed := true
	for path in ARMED:
		var e = load(path).instantiate()
		add_child(e)
		var armed: bool = e.moves.size() > 0 or e.attack_kind != "none"
		if not armed:
			all_armed = false
		e.queue_free()

	# (2) the clash parry: an enemy mid-strike is interrupted + staggered by parry_strike.
	var foe = load("res://scenes/LightSoldier.tscn").instantiate()
	add_child(foe)
	foe._ai = Enemy.AI.WINDUP                      # force it into a strike
	var was_striking: bool = foe.is_striking()
	foe.parry_strike(Vector2.RIGHT)
	var parried: bool = (not foe.is_striking()) and foe._stun > 0.0

	var ok: bool = all_armed and was_striking and parried
	print("COMBATFIX_RESULT all_armed=%s was_striking=%s parried=%s" % [
		str(all_armed), str(was_striking), str(parried)])
	print("COMBATFIX_VERDICT %s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)
