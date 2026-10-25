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
			if bool(event.get("free", false)):
				slot = " (uso sem espaço)"
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
		"feature":
			var text := "[color=#ffcf8a]%s: %s[/color]" % [actor, event["text"]]
			if event.has("save"):
				var save: Dictionary = event["save"]
				text += " — %s testa %s: %d %s = %d contra CD %d — %s" % [_name(manager, str(event.get("target", ""))),
						Ability.NAMES.get(StringName(save["ability"]), save["ability"]), save["natural"],
						Ability.format_modifier(save["modifier"]), save["total"], save["dc"], "sucesso" if save["success"] else "falha"]
			if int(event.get("damage", 0)) > 0:
				text += "; %d de dano" % event["damage"]
			return text + "."
		"opportunity":
			return "[color=#ffb070]%s faz um ataque de oportunidade contra %s.[/color]" % [actor, _name(manager, str(event["target"]))]
		"standard_action":
			var names := {"dash": "Disparada", "disengage": "Desengajar", "dodge": "Esquivar"}
			return "%s usa %s%s." % [actor, names.get(event["action"], event["action"]), " (ação bônus)" if event["bonus"] else ""]
		"mastery":
			var target_name := _name(manager, str(event["target"]))
			var text := "Maestria %s: " % Attack.MASTERY_NAMES.get(event["mastery"], event["mastery"])
			match str(event["mastery"]):
				"graze":
					return text + "%s sofre %d de dano mesmo com o erro. PV: %d." % [target_name, event["damage"], event["target_hp"]]
				"cleave":
					return text + "o golpe continua até %s." % target_name
				"sap":
					return text + "%s terá desvantagem no próximo ataque." % target_name
				"slow":
					return text + "deslocamento de %s -3 m." % target_name
				"vex":
					return text + "%s terá vantagem no próximo ataque contra %s." % [actor, target_name]
				"topple":
					var save: Dictionary = event["save"]
					return text + "%s testa Constituição: %d %s = %d contra CD %d — %s." % [target_name, save["natural"],
							Ability.format_modifier(save["modifier"]), save["total"], save["dc"], "resiste" if save["success"] else "cai"]
			return text
		"unarmed":
			var save: Dictionary = event["save"]
			var option := "agarrar" if event["option"] == "grapple" else "derrubar"
			return "%s tenta %s %s: teste de %s %d %s = %d contra CD %d — %s." % [actor, option, _name(manager, str(event["target"])),
					Ability.NAMES.get(StringName(save["ability"]), save["ability"]), save["natural"],
					Ability.format_modifier(save["modifier"]), save["total"], save["dc"], "escapa" if save["success"] else "consegue"]
		"condition":
			return "%s fica %s." % [actor, CombatManager.CONDITION_NAMES[event["condition"]].to_lower()]
		"condition_end":
			return "%s não está mais %s." % [actor, CombatManager.CONDITION_NAMES[event["condition"]].to_lower()]
		"condition_save":
			return "%s testa para encerrar %s: %d %s = %d contra CD %d — %s." % [actor,
					CombatManager.CONDITION_NAMES[event["condition"]].to_lower(), event["natural"],
					Ability.format_modifier(event["modifier"]), event["total"], event["dc"], "sucesso" if event["success"] else "falha"]
		"escape":
			return "%s tenta escapar: %d %s = %d contra CD %d — %s." % [actor, event["natural"],
					Ability.format_modifier(event["modifier"]), event["total"], event["dc"], "escapa" if event["success"] else "continua preso"]
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
	var prefix := "Ataque extra: " if event.get("offhand", false) else ""
	var text := prefix + "%s ataca %s com %s: %s %s = %d contra CA %d — " % [actor, target, event["attack"], dice,
			Ability.format_modifier(roll["bonus"]), roll["total"], roll["target_ac"]]
	if not roll["hit"]:
		return text + ("erro automático (1 natural)." if roll["natural"] == 1 else "erra.")
	var hit := "[color=#e6d65a]acerto crítico![/color]" if roll["critical"] else "acerta"
	var resisted := " (resistido)" if event.get("resisted", false) else ""
	var extra: Dictionary = event.get("extra", {})
	if int(extra.get("damage", 0)) > 0:
		resisted += " (inclui %d de %s)" % [extra["damage"], extra["spell"]]
	if not str(event.get("features", "")).is_empty():
		resisted += " [%s]" % event["features"]
	return text + "%s %d de dano %s%s. PV de %s: %d." % [hit, event["damage"],
			DAMAGE_TYPE_NAMES.get(event["damage_type"], event["damage_type"]), resisted, target, event["target_hp"]]


## Texto curto para flutuar sobre a ficha (maestria, condição, ação).
static func short_label(event: Dictionary) -> String:
	match str(event.get("type", "")):
		"mastery":
			return Attack.MASTERY_NAMES.get(event["mastery"], "")
		"condition":
			return CombatManager.CONDITION_NAMES.get(event["condition"], "")
		"unarmed":
			return "Escapou" if event["save"]["success"] else ("Agarrado!" if event["option"] == "grapple" else "Derrubado!")
		"standard_action":
			return {"dash": "Disparada", "disengage": "Desengajar", "dodge": "Esquivar"}.get(event["action"], "")
	return ""


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
