extends Node
## Audio — named placeholder sound events for the battlefield.
##
## There are no final sound assets yet, so this is a tiny event BUS. Every place that
## makes a "heavy, funny, satisfying" moment calls `Audio.play("event", pos)`, and
## this hub re-emits it as the single `sfx(event, world_pos)` signal. A future
## AudioStreamPlayer (or just a debug listener) connects to that one signal and maps
## each event name to a real sound — so adding audio later is a one-file change and
## the call sites are already in place.
##
## Registered as an autoload (see project.godot [autoload]). The known events — the
## brief's list — fired around the codebase:
##   stone_scrape       the heavy stone grinding/pushing something slowly
##   heavy_swing        a fast swing connects
##   shield_block       a frontal hit was caught on a shield
##   shield_break       a strong hit overwhelmed a shield
##   wall_crush         a target was pinned against a wall (no cushion)
##   enemy_launch       a soldier was thrown (by a swing, the wheel, or a bowl)
##   chain_impact       a flung body bowled into another (chain)
##   cavalry_charge     a mounted charger committed to a lane
##   banner_down        an officer/banner bearer fell (morale broken)
##   water_splash       a body crossed into the ford
##   water_wheel_creak  the mill wheel turning
##   stone_flow_gain    a new Stone Flow stack was earned

signal sfx(event: StringName, world_pos: Vector2)

## Fire a named event. `world_pos` lets a future positional player pan/attenuate it;
## global/UI events (like stone_flow_gain) can omit it.
func play(event: StringName, world_pos: Vector2 = Vector2.ZERO) -> void:
	sfx.emit(event, world_pos)
