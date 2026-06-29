extends Node2D
## Directive guard (token NOTKLEAK): the Three-Kingdoms theme must NOT survive as visible content.
##
## Asserts, over every Campaign stage + the section labels:
##   (a) NO CJK / Han glyphs in any player-facing string (title, blurb, section label) — these also
##       tofu in the gl_compatibility web font, so this doubly guards the web build;
##   (b) NO Three-Kingdoms proper nouns (Lu Bu / Cao Cao / Guan Yu / Zhang Fei / Xiahou / the old
##       map names / "Three Kingdoms" / "Dynasty") in titles or blurbs;
##   (c) section ids are exactly {arthur, trials} — the "bonus" Three-Kingdoms section is gone;
##   (d) section labels contain no "BONUS" / "KINGDOM" / "DYNASTY".
##
## Run: godot --headless --path . res://tests/NoTkLeakTest.tscn --quit-after 600 — look for NOTKLEAK_VERDICT.

const FORBIDDEN := [
	"three kingdoms", "dynasty", "lu bu", "lü bu", "cao cao", "guan yu", "zhang fei",
	"xiahou", "yuan shao", "hu lao", "red cliffs", "guandu", "changban", "yellow turban",
]

var _frame := 0

func _physics_process(_dt: float) -> void:
	_frame += 1
	if _frame < 2:
		return
	_report()

## True if `s` contains any CJK/Han codepoint (>= 0x2E80 covers Han + CJK radicals/punctuation,
## while leaving our em-dash U+2014 and middle-dot U+00B7 safely below the threshold).
func _has_cjk(s: String) -> bool:
	for i in range(s.length()):
		if s.unicode_at(i) >= 0x2E80:
			return true
	return false

func _has_forbidden(s: String) -> bool:
	var low := s.to_lower()
	for w in FORBIDDEN:
		if low.find(w) >= 0:
			return true
	return false

func _report() -> void:
	var checks := {}
	var bad_strings: Array = []

	# (a)+(b) every stage's title + blurb is clean.
	var stages_clean := true
	for s in Campaign.stages():
		for key in ["title", "blurb"]:
			var v := String(s.get(key, ""))
			if _has_cjk(v) or _has_forbidden(v):
				stages_clean = false
				bad_strings.append("%s.%s=%s" % [String(s.get("id", "?")), key, v])
	checks["stages_clean"] = stages_clean

	# (c) section ids are exactly the two Arthurian groups; no "bonus".
	var secs := {}
	for s in Campaign.stages():
		secs[String(s.get("section", ""))] = true
	checks["only_arthur_trials"] = secs.size() == 2 \
		and secs.has(Campaign.SEC_ARTHUR) and secs.has(Campaign.SEC_TRIALS)
	checks["no_bonus_section"] = not secs.has("bonus")

	# (d) section labels are clean of Three-Kingdoms / bonus vocabulary + CJK.
	var labels_clean := true
	for k in Campaign.SECTION_LABELS:
		var lab := String(Campaign.SECTION_LABELS[k])
		var low := lab.to_lower()
		if _has_cjk(lab) or low.find("bonus") >= 0 or low.find("kingdom") >= 0 or low.find("dynasty") >= 0:
			labels_clean = false
			bad_strings.append("label=%s" % lab)
	checks["labels_clean"] = labels_clean

	var ok := true
	var parts: Array = []
	for k in checks:
		ok = ok and checks[k]
		parts.append("%s=%s" % [k, str(checks[k])])
	if not bad_strings.is_empty():
		print("NOTKLEAK_OFFENDERS %s" % " | ".join(bad_strings))
	print("NOTKLEAK_RESULT %s" % " ".join(parts))
	print("NOTKLEAK_VERDICT %s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)
