class_name General
extends Enemy
## A named general (a boss warlord) — a boss-tier unit. It is, at heart, just a heavily-tuned
## Enemy: it keeps the full base brain (approach, steer, telegraphed moves, defeat,
## the KO count) and adds ONE signature flourish on top — a periodic WAR-CRY.
##
## The war-cry is deliberately tiny: when the general is composed (not staggered) and
## a foe has come within reach, it lets out a shout that briefly STUNS the lesser units
## fighting on the SAME side as that foe — the boss seizing the initiative and rattling
## the line. It reuses the pieces already on the field: `stun()` on the affected units,
## an `Impact.popup` for the cue, and an existing Audio event. No new force system, no
## new projectile, no change to the base AI — `super._physics_process` still runs the
## whole show; this only watches a cooldown and shouts.
##
## Set `is_general = true` on the .tscn (so it joins the "generals" group the boss
## health-bar UI tracks). The strongest generals use this script for the war-cry; the
## simpler ones can stay a plain Enemy config — both are equally valid bosses.

## Seconds between war-cries. Long, so the shout reads as a rare boss beat, not spam.
@export var warcry_cooldown := 6.0
## How far the war-cry's stun reaches. Lesser units of the foe's side inside this go rigid.
@export var warcry_radius := 200.0
## How long the shout stuns those caught in it.
@export var warcry_stun := 0.9
## Don't stun other generals — bosses shrug off a rival's shout (keeps duels fair).
@export var warcry_spares_generals := true

var _warcry_cd := 2.0     ## a short initial delay so a freshly-spawned boss doesn't open with it
var _announced := false   ## one-shot: the entrance name-card fires once, when a foe first closes in

## Below this HP fraction the boss ENRAGES — faster + more aggressive, so the back half of every
## fight changes rhythm (the player feels it "wake up" right when they think it's won).
@export var enrage_at := 0.4
## A war-cry now also rattles the PLAYER: a small hit that breaks Arthur's combo + shoves him (it
## respects his i-frames), so a boss seizes the initiative instead of being a passive HP sponge.
@export var warcry_damage := 6.0
var _enraged := false


func _physics_process(delta: float) -> void:
	# Run the ENTIRE base brain first — approach, steering, the data-driven moveset,
	# staggers, defeat. The general is a normal Enemy that simply also shouts.
	super._physics_process(delta)
	if _dead or not ai_enabled:
		return
	_check_enrage()
	# Staggered / launched generals can't shout (they're reeling, same as they can't act).
	if _stun > 0.0:
		return
	# ENTRANCE: the first time a foe closes to engagement range, the warlord ANNOUNCES himself with a
	# gold name-card — a named general arrives as an EVENT, not just a mob with a big bar. Once only.
	if not _announced and is_instance_valid(_player) \
			and global_position.distance_to(_player.global_position) <= warcry_radius * 1.6:
		_announce_entrance()
	_warcry_cd = maxf(0.0, _warcry_cd - delta)
	if _warcry_cd > 0.0:
		return
	# Only shout when a foe has actually closed in — a boss roars at the press of battle,
	# not at an empty field. `_player` is the foe the base brain already picked.
	if not is_instance_valid(_player):
		return
	if global_position.distance_to(_player.global_position) > warcry_radius:
		return
	_war_cry()


## The entrance flourish — a gold name-card when the player first meets this warlord, so a named
## general reads as an event. Reuses an existing Audio event (no new sound asset) + Impact.popup.
func _announce_entrance() -> void:
	_announced = true
	var nm := "A WARLORD"
	if "enemy_name" in self and String(enemy_name) != "":
		nm = String(enemy_name)
	Impact.popup(nm.to_upper(), global_position + Vector2(0.0, -64.0), Color(0.98, 0.84, 0.42), 2.0)
	Audio.play("cavalry_charge", global_position)


## The ENRAGE flip: once the boss drops below enrage_at HP it speeds up + shouts more often, so the
## back half of the fight escalates (the player feels it "wake up"). One-shot; reuses move_speed +
## warcry pacing — no new systems.
func _check_enrage() -> void:
	if _enraged or max_health <= 0.0 or health > max_health * enrage_at:
		return
	_enraged = true
	move_speed *= 1.3
	warcry_cooldown *= 0.6
	_warcry_cd = minf(_warcry_cd, 1.0)
	Impact.popup("ENRAGED!", global_position + Vector2(0.0, -52.0), Color(1.0, 0.35, 0.3), 2.0)
	Audio.play("shield_break", global_position)


## The signature move: rattle the lesser units on the FOE's side within reach.
## Reuses each unit's own `stun()` (the same one Arthur's heavy hits use), so nothing
## new is introduced — it just borrows the stagger that already exists.
func _war_cry() -> void:
	_warcry_cd = warcry_cooldown
	# Whose line are we rattling? The side `_player` belongs to: raiders' generals shout
	# at Arthur's allies group; an allied general shouts at the raiders.
	var foe_group := "raiders" if team != "raiders" else "allies"
	for u in get_tree().get_nodes_in_group(foe_group):
		if u == self or not is_instance_valid(u):
			continue
		if not u.has_method("stun"):
			continue
		# Rival bosses are unshaken (optional), and a downed unit needs no further stun.
		if warcry_spares_generals and u.is_in_group("generals"):
			continue
		if u is Enemy and u._dead:
			continue
		if global_position.distance_to(u.global_position) <= warcry_radius:
			u.stun(warcry_stun)
	# The war-cry ALSO rattles the PLAYER (Arthur) if in range: a small hit that breaks his combo +
	# shoves him (it respects his i-frames), so the boss seizes the initiative, not a free punching bag.
	for p in get_tree().get_nodes_in_group("player"):
		if is_instance_valid(p) and p.has_method("take_damage") \
				and global_position.distance_to(p.global_position) <= warcry_radius:
			p.take_damage(warcry_damage, global_position)
	# A loud cue so the boss beat reads. Reuse an existing Audio event (no new sound asset).
	Impact.popup("WAR CRY!", global_position + Vector2(0.0, -warcry_radius * 0.18 - 30.0),
		Color(1.0, 0.78, 0.32), 1.3)
	Audio.play("banner_down", global_position)
