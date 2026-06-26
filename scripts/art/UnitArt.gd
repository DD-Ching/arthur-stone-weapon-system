class_name UnitArt
extends RefCounted
## Per-unit silhouette art, dispatched by `look`. `Enemy._draw_type()` calls `UnitArt.draw_type(self)`.
##
## Each look's drawing lives in its OWN file (SoldierArt / ShieldArt / HeavyArt / SpearArt /
## BannerArt / KnightArt) so a unit type can be BEAUTIFIED IN ISOLATION — one agent, one file —
## without touching Enemy.gd or any sibling unit's art. `e` is the Enemy (a CanvasItem): the art
## functions draw on it (`e.draw_*`) and read its state (`e.radius`, `e._face`, `e._alpha`,
## `e.shield_angle`, `e._shield_broken`, `e.faction`, `e.is_general`, `e.faction_color()`).

static func draw_type(e) -> void:
	match e.look:
		"soldier": SoldierArt.draw(e)
		"shield": ShieldArt.draw(e)
		"heavy": HeavyArt.draw(e)
		"spear": SpearArt.draw(e)
		"banner": BannerArt.draw(e)
		"knight": KnightArt.draw(e)
		"excalibur": ExcaliburArt.draw(e)   # Camelot champions wielding a radiant Excalibur
		"sorceress": SorceressArt.draw(e)   # Morgan le Fay and her dark magic
		"mordred": MordredArt.draw(e)       # the traitor prince
		"black_knight": BlackKnightArt.draw(e)  # the dread mercenary champion
		"warlord": WarlordArt.draw(e)       # the Saxon axe-lord
		# "dummy" and any other look draw no extra silhouette here. Cavalry/WarCart override
		# Enemy._draw_type() entirely with their own mounted draw, so they never reach this.
