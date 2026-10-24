class_name CombatLog
extends RefCounted
## Converte eventos do CombatManager em frases para o registro do combate (apresentação).

const DAMAGE_TYPE_NAMES := {
	"bludgeoning": "contundente", "piercing": "perfurante", "slashing": "cortante", "poison": "veneno",
	"fire": "fogo", "cold": "frio", "acid": "ácido", "lightning": "elétrico", "thunder": "trovejante",
	"force": "energia", "necrotic": "necrótico", "psychic": "psíquico", "radiant": "radiante",
}


static func describe(event: Dictionary, manager: CombatManager) -> String:
	var actor := _name(manager, str(event.get("actor", "")))
	match str(event.get("type", "")):
		"initiative":
			return "%s rola iniciativa: %d %s = %d" % [actor, event["natural"],
					Ability.format_modifier(event["bonus"]), event["total"]]
		"round_start":
			return "[b]— Rodada %d —[/b]" % event["round"]
		"turn_start":
			return "Turno de [b]%s[/b]." % actor
		"move":
			return "%s se move (%d pés restantes)." % [actor, event["movement_left"]]
		"attack":
			return _describe_attack(event, manager, actor)
		"down":
			return "[color=#d6463c]%s %s![/color]" % [actor, "morre" if event["dead"] else "cai inconsciente"]
		"combat_end":
			match int(event["outcome"]):
				CombatManager.Outcome.VICTORY:
					return "[b]Vitória![/b] +%d XP" % event["xp"]
				CombatManager.Outcome.DEFEAT:
					return "[b]Derrota.[/b]"
				CombatManager.Outcome.FLED:
					return "[b]O grupo fugiu.[/b]"
	return ""


static func _describe_attack(event: Dictionary, manager: CombatManager, actor: String) -> String:
	var roll: Dictionary = event["roll"]
	var target := _name(manager, str(event["target"]))
	var dice := str(roll["natural"])
	if roll["rolls"].size() > 1:
		var mode := "vantagem" if int(roll["advantage"]) == D20Test.Advantage.ADVANTAGE else "desvantagem"
		var reasons: Array = event["advantage_reasons"] + event["disadvantage_reasons"]
		dice = "%s (%s: %s; %s)" % [roll["natural"], mode, ", ".join(roll["rolls"].map(func(r: int) -> String: return str(r))),
				", ".join(reasons)]
	var text := "%s ataca %s com %s: %s %s = %d contra CA %d — " % [actor, target, event["attack"], dice,
			Ability.format_modifier(roll["bonus"]), roll["total"], roll["target_ac"]]
	if not roll["hit"]:
		return text + ("erro automático (1 natural)." if roll["natural"] == 1 else "erra.")
	var hit := "[color=#e6d65a]acerto crítico![/color]" if roll["critical"] else "acerta"
	var resisted := " (resistido)" if event.get("resisted", false) else ""
	return text + "%s %d de dano %s%s. PV de %s: %d." % [hit, event["damage"],
			DAMAGE_TYPE_NAMES.get(event["damage_type"], event["damage_type"]), resisted, target, event["target_hp"]]


static func _name(manager: CombatManager, unit_id: String) -> String:
	var unit := manager.get_combatant(unit_id)
	return unit.name if unit != null else unit_id
