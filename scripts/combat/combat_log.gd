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
		"heal":
			return "%s bebe %s e recupera %d PV (agora %d)." % [actor, event["item"], event["amount"], event["hp"]]
		"cast":
			var slot := "" if int(event["slot_level"]) == 0 else " (espaço de %dº círculo)" % event["slot_level"]
			return "[color=#c8a8ff]%s conjura %s%s.[/color]" % [actor, event["spell"], slot]
		"spell_effect":
			return _describe_spell(event, manager, actor)
		"concentration_check":
			return "%s testa a concentração em %s: %d %s = %d contra CD %d — %s." % [actor, event["spell"],
					event["natural"], Ability.format_modifier(event["modifier"]), event["total"], event["dc"],
					"mantém" if event["success"] else "falha"]
		"concentration_end":
			return "%s encerra %s (%s)." % [actor, event["spell"], event["reason"]]
		"pushed":
			return "%s é empurrado para longe." % actor
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
	var extra: Dictionary = event.get("extra", {})
	if int(extra.get("damage", 0)) > 0:
		resisted += " (inclui %d de %s)" % [extra["damage"], extra["spell"]]
	return text + "%s %d de dano %s%s. PV de %s: %d." % [hit, event["damage"],
			DAMAGE_TYPE_NAMES.get(event["damage_type"], event["damage_type"]), resisted, target, event["target_hp"]]


static func _describe_spell(event: Dictionary, manager: CombatManager, actor: String) -> String:
	var target := _name(manager, str(event["target"]))
	var damage_name: String = DAMAGE_TYPE_NAMES.get(event["damage_type"], event["damage_type"])
	var effect := " (%s)" % event["effect"] if not str(event["effect"]).is_empty() else ""
	match str(event["resolution"]):
		"spell_attack":
			var roll: Dictionary = event["roll"]
			var text := "%s: ataque mágico contra %s, %d %s = %d contra CA %d — " % [event["spell"], target, roll["natural"],
					Ability.format_modifier(roll["bonus"]), roll["total"], roll["target_ac"]]
			if not roll["hit"]:
				return text + "erra."
			return text + "%s %d de dano %s%s. PV de %s: %d." % ["[color=#e6d65a]crítico![/color]" if roll["critical"] else "acerta",
					event["damage"], damage_name, effect, target, event["target_hp"]]
		"save":
			var save: Dictionary = event["save"]
			var ability: String = Ability.NAMES.get(StringName(save["ability"]), save["ability"])
			return "%s faz um teste de %s contra %s: %d %s = %d contra CD %d — %s; %d de dano %s%s. PV de %s: %d." % [target,
					ability, event["spell"], save["natural"], Ability.format_modifier(save["modifier"]), save["total"], save["dc"],
					"sucesso" if save["success"] else "falha", event["damage"], damage_name, effect, target, event["target_hp"]]
		"auto":
			return "%d dardos atingem %s: %d de dano %s. PV de %s: %d." % [event["darts"], target, event["damage"], damage_name,
					target, event["target_hp"]]
		"heal":
			return "%s recupera %d PV (agora %d)." % [target, event["healed"], event["target_hp"]]
		"buff":
			return "%s recebe %s: %s." % [target, event["spell"], event["effect"]]
	return ""


static func _name(manager: CombatManager, unit_id: String) -> String:
	var unit := manager.get_combatant(unit_id)
	return unit.name if unit != null else unit_id
