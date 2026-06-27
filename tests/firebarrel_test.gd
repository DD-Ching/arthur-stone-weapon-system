extends Node2D
## Headless test for the explosive/fire materials (FireBarrel + the shared FireZone drop).
##
## Two acceptance checks, both through the SHARED paths (Impact.explode + FireZone), no per-material
## hacks:
##   (a) BLAST — a FireBarrel placed near a raider, then broken (apply_knockback past hard_hit),
##       launches AND/OR damages that raider via the Impact.explode ring,
##   (b) BURN  — the break leaves a FireZone, and a unit standing in it loses health over a few
##       ticks (the fire can actually kill).
##
## Run: godot --headless --path . res://tests/FireBarrelTest.tscn — look for FIREBARREL_VERDICT.

var barrel
var blast_raider          ## near the barrel; should be launched/damaged by the explode ring
var burn_raider           ## parked on the barrel's spot; should burn in the leftover FireZone
var _frame := 0
var _blast_start := Vector2.ZERO
var _blast_hp_before := 0.0
var _burn_hp_before := 0.0

func _ready() -> void:
	Impact.reset()
	var soldier: PackedScene = load("res://scenes/LightSoldier.tscn")
	var barrel_scene: PackedScene = load("res://scenes/props/FireBarrel.tscn")

	barrel = barrel_scene.instantiate()
	add_child(barrel)
	barrel.global_position = Vector2(0, 0)

	# The blast raider sits ~70px away — inside the explode radius (~110) so the ring catches it.
	blast_raider = soldier.instantiate()
	add_child(blast_raider)
	blast_raider.global_position = Vector2(70, 0)

	# The burn raider stands right where the barrel breaks, so the dropped FireZone overlaps it and
	# burns it tick after tick. Kept clear of the blast launch direction maths — fire ignores facing.
	burn_raider = soldier.instantiate()
	add_child(burn_raider)
	burn_raider.global_position = Vector2(0, 0)

func _physics_process(_delta: float) -> void:
	_frame += 1
	if _frame == 3:
		# Let _ready() run on the spawned bodies (health = max_health), then snapshot + detonate.
		_blast_start = blast_raider.global_position
		_blast_hp_before = blast_raider.health
		_burn_hp_before = burn_raider.health
		# Hard shove past hard_hit (600) so Breakable.apply_knockback breaks the barrel → _on_break.
		barrel.apply_knockback(Vector2.LEFT, 1200.0)
	# Give the FireZone several ticks (tick=0.4s) to burn the parked raider before reporting.
	if _frame >= 120:
		_report()

func _report() -> void:
	# (a) Blast: the explode ring should have moved OR damaged the near raider.
	var moved := 0.0
	var blast_hp_drop := 0.0
	if is_instance_valid(blast_raider):
		moved = blast_raider.global_position.distance_to(_blast_start)
		blast_hp_drop = _blast_hp_before - blast_raider.health
	else:
		blast_hp_drop = _blast_hp_before   # it died = took damage
	var blast_ok: bool = moved > 5.0 or blast_hp_drop > 0.0

	# (b) Burn: a FireZone must have been added, and the parked raider must have lost health to it.
	var fire := get_tree().get_nodes_in_group("hazard")
	var has_fire := false
	for z in fire:
		if z is FireZone:
			has_fire = true
			break
	var burn_hp_drop := 0.0
	if is_instance_valid(burn_raider):
		burn_hp_drop = _burn_hp_before - burn_raider.health
	else:
		burn_hp_drop = _burn_hp_before   # burned to death = lost all its health
	var burn_ok: bool = has_fire and burn_hp_drop > 0.0

	print("FIREBARREL_BLAST moved=%.1f hp_drop=%.1f" % [moved, blast_hp_drop])
	print("FIREBARREL_BURN has_fire=%s hp_drop=%.1f" % [str(has_fire), burn_hp_drop])
	var ok: bool = blast_ok and burn_ok
	print("FIREBARREL_VERDICT %s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)
