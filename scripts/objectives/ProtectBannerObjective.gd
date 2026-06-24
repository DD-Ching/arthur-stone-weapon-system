class_name ProtectBannerObjective
extends Objective
## Protect an allied banner/ward: you LOSE the moment the banner falls. A required
## CONSTRAINT (completable = false) — it can only fail (→ lose), it's never "done", so it
## never gates the win. The inverse of DefeatOfficer: there you fell the enemy banner;
## here you keep your OWN banner standing. Reusable for any "keep unit X alive" level.
##
## ctx key it reads: `ward_alive` (bool) — true while the protected banner lives, false
## once it has fallen. (Consistent with the level supplying live-state booleans like the
## Hold-the-Ford `alive`/`officers` counts.)

func _init(title_text := "Protect the banner") -> void:
	title = title_text
	required = true
	completable = false   # a constraint: it can only fail (→ lose), it's never "done"

func evaluate(ctx: Dictionary) -> void:
	# Latch on failure: once the banner is gone the battle is lost and stays lost.
	if not bool(ctx.get("ward_alive", true)):
		_failed = true

func fragment(_ctx: Dictionary) -> String:
	return "BANNER LOST" if _failed else "BANNER OK"
