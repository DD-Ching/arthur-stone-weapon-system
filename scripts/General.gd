class_name General
extends Enemy
## A named general (武將) — a boss-tier unit. It is, at heart, just a heavily-tuned
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


func _physics_process(delta: float) -> void:
	# Run the ENTIRE base brain first — approach, steering, the data-driven moveset,
	# staggers, defeat. The general is a normal Enemy that simply also shouts.
	super._physics_process(delta)
	if _dead or not ai_enabled:
		return
	# Staggered / launched generals can't shout (they're reeling, same as they can't act).
	if _stun > 0.0:
		return
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
	# A loud cue so the boss beat reads. Reuse an existing Audio event (no new sound asset).
	Impact.popup("WAR CRY!", global_position + Vector2(0.0, -warcry_radius * 0.18 - 30.0),
		Color(1.0, 0.78, 0.32), 1.3)
	Audio.play("banner_down", global_position)
