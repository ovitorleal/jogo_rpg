class_name CombatFeatures
extends RefCounted
## Características de classe/subclasse em combate (SRD 5.2.1), ligadas ao CombatManager por ganchos:
## iniciativa, início/fim de turno, vantagem do ataque, faixa de crítico, ajuste da jogada, dano extra
## ao acertar, dano recebido (reações), efeitos após o acerto, testes de resistência, cair a 0 PV,
## resistências e ações do menu "Ações". Funções estáticas recebem o CombatManager (m) para usar
## o rolador e os auxiliares; nada aqui é chamado pela interface diretamente.
##
## Estado por combatente fica em Combatant.state (ex.: "raging_extended", "relentless_dc").
## Preferências do jogador (ligar Golpe Atordoante, efeitos do Golpe Astuto...) ficam em
## Combatant.options e são alteradas pelo comando {"type": "option", "key", "value"}.

const BPS := ["bludgeoning", "piercing", "slashing"]
const ALL_DAMAGE := ["acid", "bludgeoning", "cold", "fire", "force", "lightning", "necrotic", "piercing", "poison",
		"psychic", "radiant", "slashing", "thunder"]
const CUNNING_COSTS := {"poison": 1, "trip": 1, "withdraw": 1, "daze": 2, "obscure": 3, "knock_out": 6}
const CUNNING_NAMES := {"poison": "Veneno", "trip": "Rasteira", "withdraw": "Retirada", "daze": "Atordoar",
		"obscure": "Ofuscar", "knock_out": "Nocaute"}
const BRUTAL_NAMES := {"forceful": "Golpe Forte", "hamstring": "Golpe Jarrete", "staggering": "Golpe Atordoante",
		"sundering": "Golpe Despedaçador"}
const OPEN_HAND_NAMES := {"addle": "Atordoar", "push": "Empurrar", "topple": "Derrubar"}
## Tipos de criatura contidos por Proteção contra o Bem e o Mal (nomes dos dados de monstros).
const WARD_TYPES := ["aberração", "celestial", "elemental", "feérico", "corruptor", "morto-vivo"]
## Golpe Divino causa +1d8 contra estes tipos.
const SMITE_BONUS_TYPES := ["corruptor", "morto-vivo"]
const DIVINE_SENSE_TYPES := ["celestial", "corruptor", "morto-vivo"]
const RESTORING_TOUCH := ["blinded", "charmed", "deafened", "frightened", "paralyzed", "stunned"]
## Proteção da Natureza (Círculo da Terra 10): resistência pelo tipo de terra.
const LAND_RESISTANCE := {"land.arid": "fire", "land.polar": "cold", "land.temperate": "lightning", "land.tropical": "poison"}
## Golpe Primal: escolhe o primeiro tipo a que o alvo não resiste.
const PRIMAL_TYPES := ["thunder", "fire", "cold", "lightning"]
const SANCTUARY := "Santuário da Natureza"


# --- Auxiliares --------------------------------------------------------------------------

static func resource_left(unit: Combatant, m: CombatManager, resource_id: String) -> int:
	if unit.character == null or m.registry == null:
		return 0
	return ClassFeatures.remaining(unit.character, m.registry, resource_id)


static func spend(unit: Combatant, resource_id: String, amount: int = 1) -> void:
	if unit.character != null:
		ClassFeatures.spend(unit.character, resource_id, amount)


static func table(unit: Combatant, m: CombatManager, resource_id: String) -> String:
	if unit.character == null or m.registry == null:
		return ""
	return ClassFeatures.raw_value(unit.character, m.registry, resource_id)


static func is_raging(unit: Combatant) -> bool:
	return not unit.effects_of("raging").is_empty()


static func uses_strength(attack: Dictionary) -> bool:
	return attack.get("ability") == Ability.STRENGTH and str(attack.get("unarmed", "")) in ["", "damage"]


static func is_weapon_or_unarmed(attack: Dictionary) -> bool:
	return not str(attack.get("weapon_id", "")).is_empty() or attack.get("unarmed", "") == "damage"


## Arma de monge: corpo a corpo simples, ou marcial com Leve (SRD 5.2.1).
static func is_monk_weapon(attack: Dictionary, registry: ContentRegistry) -> bool:
	if attack.get("unarmed", "") == "damage":
		return true
	if registry == null or str(attack.get("weapon_id", "")).is_empty() or attack["attack_type"] != "melee":
		return false
	var item := registry.get_entry("item", str(attack["weapon_id"]))
	return item.get("weapon_category") == "simple" or "light" in item.get("properties", [])


static func martial_arts_active(unit: Combatant) -> bool:
	return unit.has_feature("feature.martial_arts") and bool(unit.state.get("unarmored", false))


static func focus_dc(unit: Combatant) -> int:
	return 8 + int(unit.modifiers.get(Ability.WISDOM, 0)) + unit.proficiency_bonus


static func roll(m: CombatManager, expression: String, critical: bool = false) -> int:
	var dice := DiceExpression.parse(expression)
	var total := dice.bonus
	for value in m._roller.roll_dice(dice.count * (2 if critical else 1), dice.sides):
		total += value
	return maxi(0, total)


static func save_event(save: D20Test, ability: String) -> Dictionary:
	return {"natural": save.natural, "modifier": save.modifier, "total": save.total, "dc": save.dc,
			"success": save.success, "ability": ability}


static func feature_event(unit: Combatant, feature: String, text: String, extra: Dictionary = {}) -> Dictionary:
	var event := {"type": "feature", "actor": unit.id, "feature": feature, "text": text}
	event.merge(extra, true)
	return event


# --- Iniciativa e turnos ------------------------------------------------------------------

static func initiative_advantage(unit: Combatant) -> bool:
	return unit.has_feature("feature.feral_instinct") or unit.has_feature("feature.remarkable_athlete")


static func on_initiative(m: CombatManager, unit: Combatant, events: Array[Dictionary]) -> void:
	if unit.character == null:
		return
	var c := unit.character
	# Fúria Persistente: recupera todas as Fúrias (uma vez por descanso longo).
	if unit.has_feature("feature.persistent_rage") and c.resource_spent("rage") > 0 and c.resource_spent("persistent_rage") == 0:
		c.resources_spent["rage"] = 0
		c.resources_spent["persistent_rage"] = 1
		events.append(feature_event(unit, "persistent_rage", "recupera todas as Fúrias"))
	# Metabolismo Sobrenatural: recupera o Foco e cura nível + dado de Artes Marciais.
	var metabolized := false
	if unit.has_feature("feature.uncanny_metabolism") and c.resource_spent("focus") > 0 \
			and resource_left(unit, m, "uncanny_metabolism") > 0:
		c.resources_spent["focus"] = 0
		spend(unit, "uncanny_metabolism")
		var healed := mini(unit.max_hp - unit.hp, c.level + roll(m, table(unit, m, "martial_arts_die")))
		unit.hp += healed
		metabolized = true
		events.append(feature_event(unit, "uncanny_metabolism", "recupera o Foco e %d PV" % healed, {"healed": healed}))
	# Inspiração Superior (Bardo 18): recupera Inspiração de Bardo até ter dois usos.
	if unit.has_feature("feature.superior_inspiration") and resource_left(unit, m, "bardic_inspiration") < 2:
		ClassFeatures.restore(c, "bardic_inspiration", 2 - resource_left(unit, m, "bardic_inspiration"))
		events.append(feature_event(unit, "superior_inspiration", "recupera Inspiração de Bardo até 2"))
	# Arquidruida (Druida 20): sem usos de Forma Selvagem, recupera um.
	if unit.has_feature("feature.archdruid") and resource_left(unit, m, "wild_shape") <= 0 \
			and ClassFeatures.maximum(c, m.registry, "wild_shape") > 0:
		ClassFeatures.restore(c, "wild_shape", 1)
		events.append(feature_event(unit, "archdruid", "Forma Selvagem Perene: recupera um uso"))
	# Foco Perfeito: sem Metabolismo, volta a ter ao menos 4 pontos de Foco.
	if unit.has_feature("feature.perfect_focus") and not metabolized and resource_left(unit, m, "focus") < 4:
		var maximum := ClassFeatures.maximum(c, m.registry, "focus")
		c.resources_spent["focus"] = maxi(0, maximum - 4)
		events.append(feature_event(unit, "perfect_focus", "recupera Foco até 4"))


static func on_turn_start(m: CombatManager, unit: Combatant, events: Array[Dictionary]) -> void:
	unit.state["raging_extended"] = false
	if unit.state.has("sanctuary"):
		unit.state["sanctuary"]["rounds"] = int(unit.state["sanctuary"]["rounds"]) - 1
		refresh_sanctuary(m, unit)
	# Nimbo Sagrado (Devoção 20): inimigo que começa o turno na aura sofre Carisma + proficiência radiante.
	for paladin in m.combatants:
		if not bool(paladin.state.get("holy_nimbus", false)) or not unit.is_hostile_to(paladin) or not unit.is_up():
			continue
		var radius := aura_radius(paladin)
		if radius >= 0 and Attack.grid_distance_feet(paladin.position, unit.position) <= radius:
			var raw := maxi(1, int(paladin.modifiers.get(Ability.CHARISMA, 0)) + paladin.proficiency_bonus)
			var damage := Attack.apply_damage_modifiers(raw, "radiant", unit.all_resistances())
			m._apply_damage(unit, damage, events, feature_event(paladin, "holy_nimbus", "Nimbo Sagrado queima %s" % unit.name,
					{"target": unit.id, "damage": damage, "damage_type": "radiant"}))
	if unit.has_feature("feature.heroic_warrior"):
		unit.state["heroic_inspiration"] = true
	# Sobrevivente (Campeão 18): Sangrando com 1+ PV recupera 5 + Constituição.
	if unit.has_feature("feature.survivor") and unit.hp >= 1 and unit.hp * 2 <= unit.max_hp:
		var healed := mini(unit.max_hp - unit.hp, 5 + int(unit.modifiers.get(Ability.CONSTITUTION, 0)))
		if healed > 0:
			unit.hp += healed
			events.append(feature_event(unit, "survivor", "recupera %d PV (Reunião Heroica)" % healed, {"healed": healed}))


static func on_turn_end(m: CombatManager, unit: Combatant, events: Array[Dictionary]) -> void:
	# A Fúria acaba se não foi prolongada no turno (exceto com Fúria Persistente).
	if is_raging(unit) and not unit.has_feature("feature.persistent_rage") and not bool(unit.state.get("raging_extended", false)):
		end_rage(m, unit, events, "não foi prolongada")
	# Autorrestauração (Monge 10): remove Enfeitiçado, Amedrontado ou Envenenado.
	if unit.has_feature("feature.self_restoration"):
		for condition in ["charmed", "frightened", "poisoned"]:
			if unit.has_condition(condition):
				m.remove_condition(unit, condition, events)
				break


# --- Ataque -------------------------------------------------------------------------------

## Acrescenta fontes de vantagem/desvantagem das características.
static func attack_mods(m: CombatManager, actor: Combatant, target: Combatant, attack: Dictionary,
		advantage: Array[String], disadvantage: Array[String]) -> void:
	if not actor.effects_of("reckless").is_empty() and uses_strength(attack):
		# Golpe Brutal: abre mão da vantagem do Ataque Imprudente num ataque de Força por turno.
		if actor.has_feature("feature.brutal_strike") and not str(actor.options.get("brutal", "")).is_empty() \
				and not m.once_per_turn.has("brutal") and not m.once_per_turn.has("brutal_pending"):
			m.once_per_turn["brutal_pending"] = true
		else:
			advantage.append("ataque imprudente")
	if not target.effects_of("reckless").is_empty():
		advantage.append("alvo imprudente")
	if not actor.effects_of("steady_aim").is_empty():
		advantage.append("mira firme")
	for effect in target.effects_of("studied"):
		if effect["source"] == actor.id:
			advantage.append("ataques estudados")
			break
	if not target.effects_of("stun_advantage").is_empty():
		advantage.append("golpe atordoante")
	# Caçador Preciso (Patrulheiro 17): vantagem contra a criatura da sua Marca do Caçador.
	if actor.has_feature("feature.precise_hunter"):
		for effect in target.effects_of("marked"):
			if effect["source"] == actor.id and effect.get("spell_id") == "spell.hunters_mark":
				advantage.append("caçador preciso")
				break
	# Táticas Defensivas (Caçador 7).
	if m.opportunity_attack and target.has_feature("defensive_tactics.escape_the_horde"):
		disadvantage.append("escapar da horda")
	for effect in target.effects_of("multiattack_defense"):
		if effect["source"] == actor.id:
			disadvantage.append("defesa contra ataques múltiplos")
			break


## Elusivo (Ladino 18): nenhum ataque tem vantagem contra você, salvo Incapacitado.
static func blocks_advantage(target: Combatant) -> bool:
	return target.has_feature("feature.elusive") and not target.is_incapacitated()


## Menor d20 que é crítico (Crítico Aprimorado 19, Superior 18), para armas e desarmado.
static func crit_min(actor: Combatant, attack: Dictionary) -> int:
	if not is_weapon_or_unarmed(attack):
		return 20
	if actor.has_feature("feature.superior_critical"):
		return 18
	if actor.has_feature("feature.improved_critical"):
		return 19
	return 20


## Depois da jogada: Inspiração Heroica (refaz) e Golpe de Sorte (vira 20) em ataques que erraram.
static func adjust_attack_roll(m: CombatManager, actor: Combatant, roll: Dictionary, bonus: int, target_ac: int,
		advantage_state: D20Test.Advantage, critical_from: int, events: Array[Dictionary]) -> Dictionary:
	if roll["hit"]:
		return roll
	if bool(actor.state.get("heroic_inspiration", false)):
		actor.state["heroic_inspiration"] = false
		events.append(feature_event(actor, "heroic_inspiration", "usa Inspiração Heroica e rola de novo"))
		roll = Attack.roll_attack(m._roller, bonus, target_ac, advantage_state, critical_from)
		if roll["hit"]:
			return roll
	if roll["natural"] != 1:
		roll = _inspired_attack(m, actor, roll, target_ac, events)
		if roll["hit"]:
			return roll
	if actor.has_feature("feature.stroke_of_luck") and resource_left(actor, m, "stroke_of_luck") > 0:
		spend(actor, "stroke_of_luck")
		events.append(feature_event(actor, "stroke_of_luck", "Golpe de Sorte: o d20 vira 20"))
		roll["natural"] = 20
		roll["total"] = 20 + bonus
		roll["hit"] = true
		roll["critical"] = true
	return roll


## Ataque que errou: Perícia Inigualável (Conhecimento 14: gasta Inspiração só se passar a acertar) e
## dado de Inspiração de Bardo recebido (gasto ao ser rolado). Só quando o dado pode virar o resultado.
static func _inspired_attack(m: CombatManager, actor: Combatant, roll: Dictionary, target_ac: int,
		events: Array[Dictionary]) -> Dictionary:
	var missing := target_ac - int(roll["total"])
	if actor.has_feature("feature.peerless_skill") and resource_left(actor, m, "bardic_inspiration") > 0:
		var die := table(actor, m, "bardic_die")
		if missing <= int(die.trim_prefix("d")):
			var bonus := roll_die_text(m, die)
			if int(roll["total"]) + bonus >= target_ac:
				spend(actor, "bardic_inspiration")
				roll["total"] = int(roll["total"]) + bonus
				roll["hit"] = true
				events.append(feature_event(actor, "peerless_skill", "Perícia Inigualável: +%d no ataque" % bonus))
				return roll
	var inspiration := actor.effects_of("inspired")
	if not inspiration.is_empty() and missing <= int(str(inspiration[0]["value"]).trim_prefix("d")):
		actor.effects.erase(inspiration[0])
		var bonus := roll_die_text(m, str(inspiration[0]["value"]))
		roll["total"] = int(roll["total"]) + bonus
		roll["hit"] = int(roll["total"]) >= target_ac
		events.append(feature_event(actor, "bardic_inspiration", "usa a Inspiração de Bardo: +%d no ataque" % bonus))
	return roll


static func roll_die_text(m: CombatManager, die: String) -> int:
	return roll(m, "1%s" % die if die.begins_with("d") else die)


## Palavras Cortantes (Conhecimento 3): reação de um bardo a até 18 m de quem acertou; subtrai o dado de
## Inspiração da jogada, só quando isso pode transformar o acerto em erro (críticos não).
static func defend_attack_roll(m: CombatManager, attacker: Combatant, target: Combatant, roll: Dictionary,
		target_ac: int, events: Array[Dictionary]) -> Dictionary:
	if not roll["hit"] or roll["critical"]:
		return roll
	for bard in m.combatants:
		if not bard.is_hostile_to(attacker) or not bard.has_feature("feature.cutting_words") or not bard.is_up() \
				or bard.is_incapacitated() or not bard.reaction_available or resource_left(bard, m, "bardic_inspiration") <= 0:
			continue
		if Attack.grid_distance_feet(bard.position, attacker.position) > 60:
			continue
		var die := table(bard, m, "bardic_die")
		if int(roll["total"]) - target_ac >= int(die.trim_prefix("d")):
			continue
		bard.reaction_available = false
		spend(bard, "bardic_inspiration")
		var penalty := roll_die_text(m, die)
		roll["total"] = int(roll["total"]) - penalty
		roll["hit"] = int(roll["total"]) >= target_ac
		events.append(feature_event(bard, "cutting_words", "Palavras Cortantes: -%d no ataque de %s%s" % [penalty, attacker.name,
				"" if roll["hit"] else " (erra)"], {"target": attacker.id}))
		return roll
	return roll


## Dano extra ao acertar: [{amount, type, label}]. Chamado depois do dano da arma.
static func extra_damage(m: CombatManager, actor: Combatant, target: Combatant, attack: Dictionary, roll: Dictionary,
		advantage_state: D20Test.Advantage, events: Array[Dictionary]) -> Array[Dictionary]:
	var extras: Array[Dictionary] = []
	var damage_type := str(attack["damage_type"])
	if is_raging(actor) and uses_strength(attack):
		extras.append({"amount": int(table(actor, m, "rage_damage")), "type": damage_type, "label": "Fúria"})
	if actor.has_feature("feature.frenzy") and is_raging(actor) and not actor.effects_of("reckless").is_empty() \
			and uses_strength(attack) and not m.once_per_turn.has("frenzy"):
		m.once_per_turn["frenzy"] = true
		var dice := int(table(actor, m, "rage_damage"))
		extras.append({"amount": roll(m, "%dd6" % dice, roll["critical"]), "type": damage_type, "label": "Frenesi"})
	if m.once_per_turn.has("brutal_pending") and not m.once_per_turn.has("brutal"):
		m.once_per_turn["brutal"] = true
		m.once_per_turn.erase("brutal_pending")
		var brutal_dice := "2d10" if actor.has_feature("feature.improved_brutal_strike_17") else "1d10"
		extras.append({"amount": roll(m, brutal_dice, roll["critical"]), "type": damage_type, "label": "Golpe Brutal"})
		m.pending_after_hit.append({"kind": "brutal", "effects": brutal_effects(actor)})
	var sneak := sneak_attack(m, actor, target, attack, roll, advantage_state)
	if not sneak.is_empty():
		extras.append(sneak)
	var melee_strike: bool = attack["attack_type"] == "melee" and is_weapon_or_unarmed(attack)
	# Golpes Radiantes (Paladino 11): +1d8 radiante com arma corpo a corpo ou desarmado.
	if melee_strike and actor.has_feature("feature.radiant_strikes"):
		extras.append({"amount": roll(m, "1d8", roll["critical"]), "type": "radiant", "label": "Golpes Radiantes"})
	# Matador de Colossos (Caçador 3): uma vez por turno, +1d8 contra quem não está com PV máximos.
	if actor.has_feature("hunters_prey.colossus_slayer") and not str(attack.get("weapon_id", "")).is_empty() \
			and target.hp < target.max_hp and not m.once_per_turn.has("colossus_slayer"):
		m.once_per_turn["colossus_slayer"] = true
		extras.append({"amount": roll(m, "1d8", roll["critical"]), "type": damage_type, "label": "Matador de Colossos"})
	if melee_strike:
		var smite := divine_smite(m, actor, target, roll, events)
		if not smite.is_empty():
			extras.append(smite)
	# Dano adicional do ataque de fera (veneno da aranha...).
	if not str(attack.get("extra_damage", "")).is_empty():
		var extra_type := str(attack.get("extra_damage_type", damage_type))
		extras.append({"amount": roll(m, str(attack["extra_damage"]), roll["critical"]), "type": extra_type,
				"label": CombatLog.DAMAGE_TYPE_NAMES.get(extra_type, extra_type).capitalize()})
	var weapon := not str(attack.get("weapon_id", "")).is_empty()
	# Golpe Divino do Clérigo (Golpes Abençoados 7): uma vez por turno, +1d8 radiante (2d8 no 14) com arma.
	if weapon and actor.has_feature("blessed_strikes.divine_strike") and not m.once_per_turn.has("divine_strike"):
		m.once_per_turn["divine_strike"] = true
		var kind := "necrotic" if "radiant" in target.all_resistances() and not "necrotic" in target.all_resistances() else "radiant"
		var dice := "2d8" if actor.has_feature("feature.improved_blessed_strikes") else "1d8"
		extras.append({"amount": roll(m, dice, roll["critical"]), "type": kind, "label": "Golpe Divino"})
	# Golpe Primal (Fúria Elemental 7): uma vez por turno, com arma ou ataque de fera, +1d8 (2d8 no 15).
	if (weapon or in_wild_shape(actor)) and actor.has_feature("elemental_fury.primal_strike") \
			and not m.once_per_turn.has("primal_strike"):
		m.once_per_turn["primal_strike"] = true
		var kind := PRIMAL_TYPES[0]
		for candidate: String in PRIMAL_TYPES:
			if not candidate in target.all_resistances():
				kind = candidate
				break
		var dice := "2d8" if actor.has_feature("feature.improved_elemental_fury") else "1d8"
		extras.append({"amount": roll(m, dice, roll["critical"]), "type": kind, "label": "Golpe Primal"})
	return extras


## Golpe Divino (opção do menu): logo após acertar corpo a corpo, gasta a ação bônus e o uso gratuito
## do Golpe do Paladino ou o menor espaço livre. 2d8 radiante +1d8 por círculo acima do 1º e +1d8
## contra corruptor ou morto-vivo; críticos dobram os dados.
static func divine_smite(m: CombatManager, actor: Combatant, target: Combatant, attack_roll: Dictionary,
		events: Array[Dictionary]) -> Dictionary:
	var mode := str(actor.options.get("smite", ""))
	if mode.is_empty() or (mode == "critical" and not attack_roll["critical"]) or actor != m.current():
		return {}
	var spell := actor.get_spell("spell.divine_smite")
	if spell.is_empty() or not m.bonus_action_available or actor.is_incapacitated() or is_raging(actor):
		return {}
	var free := m._free_cast_available(actor, spell)
	var slot := 1 if free else 0
	if not free and not m.slot_used_this_turn and actor.character != null and m.registry != null:
		slot = Spellcasting.lowest_slot(actor.character, m.registry, 1)
	if slot == 0:
		return {}
	if free:
		m._spend_free_cast(actor, spell)
	else:
		Spellcasting.spend_slot(actor.character, slot)
		m.slot_used_this_turn = true
	m.bonus_action_available = false
	var dice := 1 + slot + (1 if target.creature_type in SMITE_BONUS_TYPES else 0)
	events.append(feature_event(actor, "divine_smite", "Golpe Divino (%s)" % ("uso gratuito" if free else "espaço de %dº círculo" % slot),
			{"target": target.id, "vfx": "smite"}))
	# Golpe de Proteção (Devoção 15): meia cobertura para você e aliados na aura até o seu próximo turno.
	if actor.has_feature("feature.smite_of_protection"):
		var radius := aura_radius(actor)
		for ally in m.combatants:
			if ally.is_up() and not ally.is_hostile_to(actor) and radius >= 0 \
					and Attack.grid_distance_feet(actor.position, ally.position) <= radius:
				ally.effects.append({"kind": "half_cover", "source": actor.id, "spell": "Golpe de Proteção", "on": "turn_start",
						"actor": actor.id, "count": 1})
		events.append(feature_event(actor, "smite_of_protection", "Golpe de Proteção: meia cobertura na aura"))
	return {"amount": roll(m, "%dd8" % dice, attack_roll["critical"]), "type": "radiant", "label": "Golpe Divino"}


static func brutal_effects(actor: Combatant) -> Array:
	var chosen := str(actor.options.get("brutal", ""))
	var result := [chosen] if not chosen.is_empty() else []
	var second := str(actor.options.get("brutal_2", ""))
	if actor.has_feature("feature.improved_brutal_strike_17") and not second.is_empty() and second != chosen:
		result.append(second)
	return result


## Ataque Furtivo: uma vez por turno, arma de Acuidade ou à distância, com vantagem (ou aliado
## adjacente ao alvo e sem desvantagem). Golpe Astuto troca dados por efeitos.
static func sneak_attack(m: CombatManager, actor: Combatant, target: Combatant, attack: Dictionary, roll: Dictionary,
		advantage_state: D20Test.Advantage) -> Dictionary:
	if not actor.has_feature("feature.sneak_attack") or m.once_per_turn.has("sneak_attack"):
		return {}
	if str(attack.get("weapon_id", "")).is_empty():
		return {}
	var properties: Array = attack.get("properties", [])
	if not ("finesse" in properties or attack["attack_type"] == "ranged"):
		return {}
	var allowed := advantage_state == D20Test.Advantage.ADVANTAGE
	if not allowed and advantage_state != D20Test.Advantage.DISADVANTAGE:
		for ally in m.combatants:
			if ally != actor and ally.is_up() and not ally.is_hostile_to(actor) and not ally.is_incapacitated() \
					and m._adjacent(ally, target):
				allowed = true
				break
	if not allowed:
		return {}
	m.once_per_turn["sneak_attack"] = true
	var dice := DiceExpression.parse(table(actor, m, "sneak_attack"))
	var effects := cunning_effects(actor, dice.count)
	var cost := 0
	for effect: String in effects:
		cost += int(CUNNING_COSTS[effect])
	var count := maxi(0, dice.count - cost)
	if not effects.is_empty():
		m.pending_after_hit.append({"kind": "cunning", "effects": effects})
	return {"amount": roll(m, "%dd6" % count, roll["critical"]) if count > 0 else 0, "type": str(attack["damage_type"]),
			"label": "Ataque Furtivo"}


## Efeitos do Golpe Astuto escolhidos que cabem nos dados (1 efeito; 2 com Golpe Astuto Aprimorado).
static func cunning_effects(actor: Combatant, dice: int) -> Array:
	if not actor.has_feature("feature.cunning_strike"):
		return []
	var limit := 2 if actor.has_feature("feature.improved_cunning_strike") else 1
	var result := []
	var budget := dice
	for effect: Variant in actor.options.get("cunning", []):
		if result.size() >= limit or not CUNNING_COSTS.has(effect):
			continue
		if effect in ["daze", "obscure", "knock_out"] and not actor.has_feature("feature.devious_strikes"):
			continue
		if int(CUNNING_COSTS[effect]) <= budget:
			result.append(effect)
			budget -= int(CUNNING_COSTS[effect])
	return result


## Tipo de dano: desarmado com Golpes Fortalecidos vira energia se o alvo resistir ao contundente;
## Arma Sagrada pode causar radiante (escolhido quando o alvo resiste ao tipo normal).
static func damage_type_for(actor: Combatant, target: Combatant, attack: Dictionary) -> String:
	if attack.get("unarmed", "") == "damage" and actor.has_feature("feature.empowered_strikes") \
			and "bludgeoning" in target.all_resistances():
		return "force"
	var resistances := target.all_resistances()
	if sacred_weapon_applies(actor, attack) and str(attack["damage_type"]) in resistances and not "radiant" in resistances:
		return "radiant"
	return str(attack["damage_type"])


static func sacred_weapon_applies(actor: Combatant, attack: Dictionary) -> bool:
	return bool(actor.state.get("sacred_weapon", false)) and attack["attack_type"] == "melee" \
			and not str(attack.get("weapon_id", "")).is_empty()


## Bônus de ataque de características: Arma Sagrada (+Carisma, mínimo +1, com arma corpo a corpo).
static func attack_bonus(actor: Combatant, attack: Dictionary) -> int:
	if sacred_weapon_applies(actor, attack):
		return maxi(1, int(actor.modifiers.get(Ability.CHARISMA, 0)))
	return 0


## Efeitos depois de um acerto com dano (Golpe Atordoante, Golpe Astuto, Golpe Brutal, Mão Aberta, Palma Trêmula).
static func after_hit(m: CombatManager, actor: Combatant, target: Combatant, attack: Dictionary, events: Array[Dictionary]) -> void:
	# Condição do ataque de fera (Caído, Agarrado) em alvos até o tamanho dado.
	var on_hit := str(attack.get("on_hit_condition", ""))
	var max_size := str(attack.get("on_hit_max_size", ""))
	if not on_hit.is_empty() and target.is_up() and (max_size.is_empty() \
			or Combatant.size_rank(target.size) <= Combatant.size_rank(max_size)):
		m.add_condition(target, on_hit, actor.id, events, {"escape_dc": int(attack.get("escape_dc", 10))} if on_hit == "grappled" else {})
	# Defesa contra Ataques Múltiplos (Caçador 7): quem acertou tem desvantagem no resto do turno.
	if target.has_feature("defensive_tactics.multiattack_defense") and target.is_up() and m.current() != null:
		target.effects.append({"kind": "multiattack_defense", "source": actor.id, "spell": "Defesa contra Ataques Múltiplos",
				"on": "turn_end", "actor": m.current().id, "count": 1})
	var pending := m.pending_after_hit.duplicate()
	m.pending_after_hit.clear()
	for item: Dictionary in pending:
		match str(item["kind"]):
			"cunning":
				for effect: String in item["effects"]:
					apply_cunning(m, actor, target, effect, events)
			"brutal":
				for effect: String in item["effects"]:
					apply_brutal(m, actor, target, effect, events)
	if not target.is_up() or m.state != CombatManager.State.IN_PROGRESS:
		return
	if actor.has_feature("feature.stunning_strike") and bool(actor.options.get("stunning", true)) \
			and not m.once_per_turn.has("stunning") and is_monk_weapon(attack, m.registry) and resource_left(actor, m, "focus") > 0:
		m.once_per_turn["stunning"] = true
		spend(actor, "focus")
		var save := m._roll_save(target, Ability.CONSTITUTION, focus_dc(actor))
		events.append(feature_event(actor, "stunning_strike", "Golpe Atordoante", {"target": target.id,
				"save": save_event(save, "con")}))
		if not save.success:
			m.add_condition(target, "stunned", actor.id, events, {"on": "turn_start", "actor": actor.id, "count": 1})
		else:
			target.effects.append({"kind": "slowed", "source": actor.id, "spell": "Golpe Atordoante",
					"value": int(target.speed_feet / 2), "on": "turn_start", "actor": actor.id, "count": 1})
			target.effects.append({"kind": "stun_advantage", "source": actor.id, "spell": "Golpe Atordoante",
					"on": "turn_start", "actor": actor.id, "count": 1})
	if bool(m.once_per_turn.get("flurry_active", false)) and actor.has_feature("feature.open_hand_technique"):
		apply_open_hand(m, actor, target, str(actor.options.get("open_hand", "topple")), events)
	if actor.has_feature("feature.quivering_palm") and bool(actor.options.get("quivering", false)) \
			and attack.get("unarmed", "") == "damage" and resource_left(actor, m, "focus") >= 4 \
			and str(actor.state.get("quivering_target", "")).is_empty():
		spend(actor, "focus", 4)
		actor.state["quivering_target"] = target.id
		actor.options["quivering"] = false
		events.append(feature_event(actor, "quivering_palm", "Palma Trêmula: vibrações em %s" % target.name, {"target": target.id}))


static func apply_cunning(m: CombatManager, actor: Combatant, target: Combatant, effect: String, events: Array[Dictionary]) -> void:
	var dc := 8 + int(actor.modifiers.get(Ability.DEXTERITY, 0)) + actor.proficiency_bonus
	match effect:
		"withdraw":
			m.movement_left_feet += int(m.effective_speed(actor) / 2)
			m.disengaged = true
			events.append(feature_event(actor, "cunning_strike", "Golpe Astuto (Retirada): move sem provocar ataques"))
			return
	if not target.is_up():
		return
	var ability := Ability.CONSTITUTION if effect in ["poison", "daze", "knock_out"] else Ability.DEXTERITY
	if effect == "trip" and Combatant.size_rank(target.size) > Combatant.size_rank("large"):
		return
	var save := m._roll_save(target, ability, dc)
	events.append(feature_event(actor, "cunning_strike", "Golpe Astuto (%s)" % CUNNING_NAMES[effect],
			{"target": target.id, "save": save_event(save, String(ability))}))
	if save.success:
		return
	match effect:
		"poison":
			m.add_condition(target, "poisoned", actor.id, events, {"save_ends": {"ability": "con", "dc": dc}})
		"trip":
			m.add_condition(target, "prone", actor.id, events)
		"daze":
			target.effects.append({"kind": "dazed", "source": actor.id, "spell": "Atordoar", "on": "turn_end",
					"actor": target.id, "count": 1})
		"knock_out":
			m.add_condition(target, "unconscious", actor.id, events, {"save_ends": {"ability": "con", "dc": dc},
					"ends_on_damage": true})
		"obscure":
			m.add_condition(target, "blinded", actor.id, events, {"on": "turn_end", "actor": target.id, "count": 1})


static func apply_brutal(m: CombatManager, actor: Combatant, target: Combatant, effect: String, events: Array[Dictionary]) -> void:
	if not target.is_up():
		return
	events.append(feature_event(actor, "brutal_strike", "Golpe Brutal (%s)" % BRUTAL_NAMES.get(effect, effect), {"target": target.id}))
	match effect:
		"forceful":
			m._push(actor, target, 3, events)
		"hamstring":
			var kept: Array[Dictionary] = []
			for existing in target.effects:
				if existing.get("spell") != "Golpe Jarrete":
					kept.append(existing)
			target.effects = kept
			target.effects.append({"kind": "slowed", "source": actor.id, "spell": "Golpe Jarrete", "value": 15,
					"on": "turn_start", "actor": actor.id, "count": 1})
		"staggering":
			target.effects.append({"kind": "staggered", "source": actor.id, "spell": "Golpe Atordoante", "on": "turn_start",
					"actor": actor.id, "count": 1})
		"sundering":
			target.effects.append({"kind": "sundered", "source": actor.id, "spell": "Golpe Despedaçador", "on": "turn_start",
					"actor": actor.id, "count": 1})


static func apply_open_hand(m: CombatManager, actor: Combatant, target: Combatant, effect: String, events: Array[Dictionary]) -> void:
	if not target.is_up():
		return
	match effect:
		"addle":
			target.effects.append({"kind": "addled", "source": actor.id, "spell": "Mão Aberta", "on": "turn_start",
					"actor": target.id, "count": 1})
			events.append(feature_event(actor, "open_hand", "Mão Aberta: %s não faz ataques de oportunidade" % target.name))
		"push":
			var save := m._roll_save(target, Ability.STRENGTH, focus_dc(actor))
			events.append(feature_event(actor, "open_hand", "Mão Aberta (Empurrar)", {"target": target.id, "save": save_event(save, "str")}))
			if not save.success:
				m._push(actor, target, 3, events)
		"topple":
			var save := m._roll_save(target, Ability.DEXTERITY, focus_dc(actor))
			events.append(feature_event(actor, "open_hand", "Mão Aberta (Derrubar)", {"target": target.id, "save": save_event(save, "dex")}))
			if not save.success:
				m.add_condition(target, "prone", actor.id, events)


## Bônus de ataque de efeitos no alvo (Golpe Despedaçador: +5 para outra criatura, uma vez).
static func attack_bonus_from_target(actor: Combatant, target: Combatant) -> int:
	for effect in target.effects_of("sundered"):
		if effect["source"] != actor.id:
			target.effects.erase(effect)
			return 5
	return 0


## Ataque perdido: Ataques Estudados dão vantagem no próximo contra a mesma criatura.
static func on_miss(m: CombatManager, actor: Combatant, target: Combatant) -> void:
	if actor.has_feature("feature.studied_attacks"):
		target.effects.append({"kind": "studied", "source": actor.id, "spell": "Ataques Estudados", "on": "turn_end",
				"actor": actor.id, "count": 2 if actor == m.current() else 1})


## Consumo de efeitos de uso único no ataque (Mira Firme, vantagem do Golpe Atordoante).
static func consume_attack(actor: Combatant, target: Combatant) -> void:
	actor.effects = actor.effects.filter(func(e: Dictionary) -> bool: return e["kind"] != "steady_aim")
	target.effects = target.effects.filter(func(e: Dictionary) -> bool: return e["kind"] != "stun_advantage")


# --- Dano recebido -----------------------------------------------------------------------

## Reações que reduzem o dano de um ataque que acertou: Desviar Ataques e Esquiva Sobrenatural.
static func incoming_attack_damage(m: CombatManager, target: Combatant, attacker: Combatant, attack: Dictionary,
		damage: int, events: Array[Dictionary]) -> int:
	if damage <= 0 or not target.reaction_available or target.is_incapacitated():
		return damage
	var any_type := target.has_feature("feature.deflect_energy")
	if target.has_feature("feature.deflect_attacks") and (any_type or str(attack["damage_type"]) in BPS):
		target.reaction_available = false
		var reduction := roll(m, "1d10") + int(target.modifiers.get(Ability.DEXTERITY, 0)) + target.character_level
		var left := maxi(0, damage - reduction)
		events.append(feature_event(target, "deflect_attacks", "Desviar Ataques reduz %d de dano" % (damage - left)))
		if left == 0 and resource_left(target, m, "focus") > 0 and attacker.is_up():
			var melee: bool = attack["attack_type"] == "melee"
			if (melee and m._adjacent(target, attacker)) or (not melee and Attack.grid_distance_feet(target.position, attacker.position) <= 60):
				spend(target, "focus")
				var save := m._roll_save(attacker, Ability.DEXTERITY, focus_dc(target))
				var die := table(target, m, "martial_arts_die")
				var redirected := 0 if save.success else roll(m, die) + roll(m, die) + int(target.modifiers.get(Ability.DEXTERITY, 0))
				var event := feature_event(target, "deflect_attacks", "devolve o golpe", {"target": attacker.id,
						"save": save_event(save, "dex"), "damage": redirected, "damage_type": attack["damage_type"]})
				if redirected > 0:
					m._apply_damage(attacker, redirected, events, event)
				else:
					events.append(event)
		return left
	if target.has_feature("feature.uncanny_dodge"):
		target.reaction_available = false
		@warning_ignore("integer_division")
		var halved := damage / 2
		events.append(feature_event(target, "uncanny_dodge", "Esquiva Sobrenatural reduz o dano à metade"))
		return halved
	# Defesa do Caçador Superior (Caçador 15): resistência ao tipo de dano até o fim do turno.
	if target.has_feature("feature.superior_hunters_defense") and m.current() != null:
		target.reaction_available = false
		target.effects.append({"kind": "resist_type", "source": target.id, "spell": "Defesa do Caçador Superior",
				"value": str(attack["damage_type"]), "on": "turn_end", "actor": m.current().id, "count": 1})
		@warning_ignore("integer_division")
		var resisted := damage / 2
		events.append(feature_event(target, "superior_hunters_defense", "Defesa do Caçador Superior: resistência a %s" %
				CombatLog.DAMAGE_TYPE_NAMES.get(str(attack["damage_type"]), str(attack["damage_type"]))))
		return resisted
	return damage


## Depois de sofrer dano de um ataque: Retaliação (Berserker 10).
static func on_damaged_by_attack(m: CombatManager, target: Combatant, attacker: Combatant, events: Array[Dictionary]) -> void:
	if not target.is_up() or not attacker.is_up() or m.state != CombatManager.State.IN_PROGRESS:
		return
	if target.has_feature("feature.retaliation") and target.reaction_available and not target.is_incapacitated() \
			and m._adjacent(target, attacker):
		var melee := m._first_attack(target, "melee")
		if not melee.is_empty():
			target.reaction_available = false
			events.append(feature_event(target, "retaliation", "Retaliação contra %s" % attacker.name, {"target": attacker.id}))
			m._resolve_weapon_attack(target, attacker, melee, events, false)


## Ao cair a 0 PV: Fúria Implacável (teste de Constituição CD 10, +5 a cada uso). true = continua de pé.
static func on_zero_hp(m: CombatManager, unit: Combatant, events: Array[Dictionary]) -> bool:
	if unit.has_feature("feature.relentless_rage") and is_raging(unit):
		var dc := int(unit.state.get("relentless_dc", 10))
		unit.state["relentless_dc"] = dc + 5
		var save := m._roll_save(unit, Ability.CONSTITUTION, dc)
		events.append(feature_event(unit, "relentless_rage", "Fúria Implacável", {"save": save_event(save, "con")}))
		if save.success:
			unit.hp = 2 * unit.character_level
			return true
	return false


## Resistências vindas de características (Fúria, Defesa Superior).
static func resistances(unit: Combatant) -> Array:
	var result := []
	if is_raging(unit):
		result.append_array(BPS)
	if not unit.effects_of("superior_defense").is_empty():
		for damage_type in ALL_DAMAGE:
			if damage_type != "force":
				result.append(damage_type)
	for effect in unit.effects_of("resist_type"):
		result.append(str(effect["value"]))
	return result


# --- Testes de resistência ----------------------------------------------------------------

## Vantagens em testes de resistência: Sentido de Perigo (Destreza), Fúria (Força).
static func save_advantage(unit: Combatant, ability: StringName) -> int:
	var count := 0
	if ability == Ability.DEXTERITY and unit.has_feature("feature.danger_sense") and not unit.is_incapacitated():
		count += 1
	if ability == Ability.STRENGTH and is_raging(unit):
		count += 1
	return count


# --- Auras do Paladino -------------------------------------------------------------------

## Raio da Aura de Proteção em pés (-1 sem aura ou Incapacitado); 9 m com Expansão da Aura.
static func aura_radius(unit: Combatant) -> int:
	if not unit.has_feature("feature.aura_of_protection") or not unit.is_up() or unit.is_incapacitated():
		return -1
	return 30 if unit.has_feature("feature.aura_expansion") else 10


## Paladinos aliados (ou o próprio) cuja Aura de Proteção alcança a unidade.
static func auras_on(m: CombatManager, unit: Combatant) -> Array[Combatant]:
	var result: Array[Combatant] = []
	for other in m.combatants:
		if other.is_hostile_to(unit):
			continue
		var radius := aura_radius(other)
		if radius >= 0 and Attack.grid_distance_feet(other.position, unit.position) <= radius:
			result.append(other)
	return result


## Bônus em testes de resistência: Aura de Proteção (Carisma do paladino, mínimo +1; só a maior
## aura vale) e meia cobertura (+2 em Destreza).
static func save_bonus(m: CombatManager, unit: Combatant, ability: StringName) -> int:
	var bonus := 0
	for paladin in auras_on(m, unit):
		bonus = maxi(bonus, maxi(1, int(paladin.modifiers.get(Ability.CHARISMA, 0))))
	if ability == Ability.DEXTERITY and not unit.effects_of("half_cover").is_empty():
		bonus += 2
	return bonus


## Condição impedida: Aura de Coragem (Amedrontado) e Aura de Devoção (Enfeitiçado) na aura;
## Proteção contra o Bem e o Mal contra os tipos de criatura que ela contém.
static func condition_blocked(m: CombatManager, target: Combatant, condition: String, source_id: String) -> bool:
	if not condition in ["frightened", "charmed"]:
		return false
	var source := m.get_combatant(source_id)
	if source != null and source.creature_type in WARD_TYPES and not target.effects_of("warded").is_empty():
		return true
	for paladin in auras_on(m, target):
		if condition == "frightened" and paladin.has_feature("feature.aura_of_courage"):
			return true
		if condition == "charmed" and paladin.has_feature("feature.aura_of_devotion"):
			return true
	return false


# --- Marca do Caçador ---------------------------------------------------------------------

## Saber do Caçador (Caçador 3): ao marcar, revela resistências e imunidades do alvo.
static func hunters_lore(actor: Combatant, target: Combatant, entry: Dictionary) -> String:
	if entry["id"] != "spell.hunters_mark" or not actor.has_feature("feature.hunters_lore"):
		return ""
	var resist := PackedStringArray()
	for damage_type: Variant in target.resistances:
		resist.append(CombatLog.DAMAGE_TYPE_NAMES.get(str(damage_type), str(damage_type)))
	var immune := PackedStringArray()
	for condition: Variant in target.condition_immunities:
		immune.append(CombatManager.CONDITION_NAMES.get(str(condition), str(condition)))
	return " — Saber do Caçador: resistências %s; imunidades %s" % [", ".join(resist) if not resist.is_empty() else "nenhuma",
			", ".join(immune) if not immune.is_empty() else "nenhuma"]


## Quando a criatura marcada cai, quem a marcou pode mover a marca com uma ação bônus.
## Quem cai em Forma Selvagem volta à forma normal.
static func on_unit_down(m: CombatManager, unit: Combatant) -> void:
	revert_form(m, unit, [] as Array[Dictionary], "")
	for effect in unit.effects_of("marked"):
		var source := m.get_combatant(str(effect["source"]))
		if source != null and source.concentration.get("spell_id") == effect.get("spell_id"):
			source.state["mark_to_move"] = effect.duplicate()


## Caçador Implacável (Patrulheiro 13): dano não quebra a concentração na Marca do Caçador.
static func keeps_concentration(unit: Combatant) -> bool:
	return unit.has_feature("feature.relentless_hunter") and unit.concentration.get("spell_id") == "spell.hunters_mark"


## Presa do Caçador Superior (Caçador 11): uma vez por turno, o dano extra da Marca também atinge
## outra criatura a até 9 m do alvo (a mais próxima).
static func after_mark_damage(m: CombatManager, actor: Combatant, target: Combatant, extra: Dictionary,
		events: Array[Dictionary]) -> void:
	if int(extra.get("damage", 0)) <= 0 or not actor.has_feature("feature.superior_hunters_prey") \
			or m.once_per_turn.has("superior_hunters_prey") or m.state != CombatManager.State.IN_PROGRESS:
		return
	var value := ""
	for effect in target.effects_of("marked"):
		if effect["source"] == actor.id and effect.get("spell_id") == "spell.hunters_mark":
			value = str(effect["value"])
	if value.is_empty():
		return
	var best: Combatant = null
	var best_distance := 0
	for other in m.combatants:
		if other == target or not other.is_up() or not other.is_hostile_to(actor):
			continue
		var distance := Attack.grid_distance_feet(target.position, other.position)
		if distance <= 30 and (best == null or distance < best_distance):
			best = other
			best_distance = distance
	if best == null:
		return
	m.once_per_turn["superior_hunters_prey"] = true
	var damage := Attack.apply_damage_modifiers(roll(m, value), str(extra["damage_type"]), best.all_resistances())
	m._apply_damage(best, damage, events, feature_event(actor, "superior_hunters_prey", "Presa do Caçador Superior atinge %s" % best.name,
			{"target": best.id, "damage": damage, "damage_type": extra["damage_type"]}))


# --- Conjuração de Clérigo e Druida ---------------------------------------------------------

## Truque da própria classe (não de talento) com Conjuração Potente: Clérigo (Golpes Abençoados) e
## Druida (Fúria Elemental) somam a Sabedoria ao dano.
static func _potent_cantrip(actor: Combatant, spell: Dictionary) -> bool:
	if actor.character == null or int(spell["entry"]["level"]) != 0 or not str(spell["id"]) in actor.character.cantrips:
		return false
	return (actor.has_feature("blessed_strikes.potent_spellcasting") and actor.character.class_id == "class.cleric") \
			or (actor.has_feature("elemental_fury.potent_spellcasting") and actor.character.class_id == "class.druid")


static func cantrip_bonus(actor: Combatant, spell: Dictionary) -> int:
	return int(actor.modifiers.get(Ability.WISDOM, 0)) if _potent_cantrip(actor, spell) else 0


## Fúria Elemental Aprimorada (Druida 15): truques de druida com alcance de 3 m ou mais ganham +90 m.
static func spell_range_bonus(actor: Combatant, spell: Dictionary) -> int:
	if actor.has_feature("feature.improved_elemental_fury") and _potent_cantrip(actor, spell) \
			and int(spell["entry"]["range_feet"]) >= 10:
		return 300
	return 0


## Golpes Abençoados Aprimorados (Clérigo 14): truque com Conjuração Potente que causa dano concede
## PV temporários iguais ao dobro da Sabedoria (ao próprio clérigo).
static func after_spell_damage(m: CombatManager, actor: Combatant, spell: Dictionary, events: Array[Dictionary]) -> void:
	if actor.has_feature("feature.improved_blessed_strikes") and actor.has_feature("blessed_strikes.potent_spellcasting") \
			and _potent_cantrip(actor, spell):
		var temp := 2 * maxi(0, int(actor.modifiers.get(Ability.WISDOM, 0)))
		if temp > actor.temp_hp:
			actor.temp_hp = temp
			events.append(feature_event(actor, "improved_blessed_strikes", "Conjuração Potente: %d PV temporários" % temp))


## Curandeiro Abençoado (Vida 6): ao curar outra criatura com espaço de magia, recupera 2 + o círculo.
static func after_cast(m: CombatManager, actor: Combatant, slot_level: int, with_slot: bool, healed_others: bool,
		events: Array[Dictionary]) -> void:
	if with_slot and healed_others and actor.has_feature("feature.blessed_healer") and actor.is_up():
		var healed := mini(actor.max_hp - actor.hp, 2 + slot_level)
		if healed > 0:
			actor.hp += healed
			events.append(feature_event(actor, "blessed_healer", "Curandeiro Abençoado: +%d PV" % healed, {"healed": healed}))


# --- Forma Selvagem --------------------------------------------------------------------------

static func in_wild_shape(unit: Combatant) -> bool:
	return unit.state.has("wild_shape")


## Assume a forma de uma fera: CA, deslocamento, Força/Destreza/Constituição, ataques (com Ataques
## Múltiplos), tamanho e traços da fera; mantém PV, atributos mentais, proficiências e características.
## Ganha PV temporários iguais ao nível de druida.
static func assume_form(m: CombatManager, unit: Combatant, form_id: String, events: Array[Dictionary]) -> void:
	revert_form(m, unit, events, "")
	var beast := m.registry.get_entry("monster", form_id)
	var shape := Combatant.from_monster(beast, 1, 1)
	unit.state["wild_shape"] = {"form": form_id, "name": beast["name"], "original": {
		"armor_class": unit.armor_class, "speed_feet": unit.speed_feet, "attacks": unit.attacks, "size": unit.size,
		"scores": unit.scores.duplicate(), "modifiers": unit.modifiers.duplicate(), "save_bonuses": unit.save_bonuses.duplicate(),
		"trait_ids": unit.trait_ids.duplicate(), "sprite_path": unit.sprite_path, "sprite_texture": unit.sprite_texture,
		"sprite_key": unit.sprite_key}}
	for ability: StringName in [Ability.STRENGTH, Ability.DEXTERITY, Ability.CONSTITUTION]:
		var proficient := int(unit.save_bonuses.get(ability, 0)) > int(unit.modifiers.get(ability, 0))
		unit.scores[ability] = shape.scores[ability]
		unit.modifiers[ability] = shape.modifiers[ability]
		unit.save_bonuses[ability] = int(shape.modifiers[ability]) + (unit.proficiency_bonus if proficient else 0)
	if unit == m.current():
		m.movement_left_feet = maxi(0, m.movement_left_feet + shape.speed_feet - unit.speed_feet)
	unit.armor_class = shape.armor_class
	unit.speed_feet = shape.speed_feet
	unit.attacks = shape.attacks
	unit.size = shape.size
	unit.trait_ids = shape.trait_ids
	unit.state["multiattack"] = int(beast.get("multiattack", 1))
	if not str(beast.get("sprite", "")).is_empty():
		unit.sprite_texture = null
		unit.sprite_path = str(beast["sprite"])
		unit.sprite_key = ""
	unit.temp_hp = maxi(unit.temp_hp, unit.character_level)
	events.append(feature_event(unit, "wild_shape", "assume a forma de %s (+%d PV temporários)" % [beast["name"],
			unit.character_level], {"vfx": "aura", "reshape": true}))


## Volta à forma normal (sem evento quando reason == "").
static func revert_form(m: CombatManager, unit: Combatant, events: Array[Dictionary], reason: String) -> void:
	if not in_wild_shape(unit):
		return
	var data: Dictionary = unit.state["wild_shape"]
	var original: Dictionary = data["original"]
	if unit == m.current():
		m.movement_left_feet = maxi(0, m.movement_left_feet + int(original["speed_feet"]) - unit.speed_feet)
	unit.armor_class = int(original["armor_class"])
	unit.speed_feet = int(original["speed_feet"])
	unit.attacks = original["attacks"]
	unit.size = str(original["size"])
	unit.scores = original["scores"]
	unit.modifiers = original["modifiers"]
	unit.save_bonuses = original["save_bonuses"]
	unit.trait_ids = original["trait_ids"]
	unit.sprite_path = str(original["sprite_path"])
	unit.sprite_texture = original["sprite_texture"]
	unit.sprite_key = str(original["sprite_key"])
	unit.state.erase("wild_shape")
	unit.state.erase("multiattack")
	if not reason.is_empty():
		events.append(feature_event(unit, "wild_shape_end", "volta à forma normal (%s)" % reason, {"reshape": true}))


# --- Santuário da Natureza -----------------------------------------------------------------

## Reaplica a meia cobertura e a resistência a quem está no cubo (3x3 casas em volta do druida).
static func refresh_sanctuary(m: CombatManager, druid: Combatant) -> void:
	for unit in m.combatants:
		unit.effects = unit.effects.filter(func(e: Dictionary) -> bool:
			return not (e.get("spell") == SANCTUARY and e["source"] == druid.id))
	var data: Dictionary = druid.state.get("sanctuary", {})
	if data.is_empty() or int(data["rounds"]) <= 0 or not druid.is_up() or druid.is_incapacitated():
		druid.state.erase("sanctuary")
		return
	var resist: String = LAND_RESISTANCE.get(ClassFeatures.option(druid.character, "feature.land_type"), "") \
			if druid.character != null else ""
	for unit in m.combatants:
		if unit.is_up() and not unit.is_hostile_to(druid) and unit.position in data["cells"]:
			unit.effects.append({"kind": "half_cover", "source": druid.id, "spell": SANCTUARY, "on": "none", "actor": "", "count": 0})
			if unit != druid and not resist.is_empty():
				unit.effects.append({"kind": "resist_type", "value": resist, "source": druid.id, "spell": SANCTUARY,
						"on": "none", "actor": "", "count": 0})


## Percepção às Cegas em pés (Sentidos Ferais do Patrulheiro 18: 9 m); 0 sem.
static func blindsight(unit: Combatant) -> int:
	return 30 if unit.has_feature("feature.feral_senses") else 0


static func save_disadvantage(unit: Combatant) -> int:
	if not unit.effects_of("staggered").is_empty():
		unit.effects = unit.effects.filter(func(e: Dictionary) -> bool: return e["kind"] != "staggered")
		return 1
	return 0


## Depois do teste: Poder Indomável (Força mínima), Indomável, Sobrevivente Disciplinado e Golpe de Sorte.
static func after_save(m: CombatManager, unit: Combatant, ability: StringName, test: D20Test, events: Array[Dictionary],
		condition: String = "") -> D20Test:
	if ability == Ability.STRENGTH and unit.has_feature("feature.indomitable_might") and test.total < int(unit.scores.get(Ability.STRENGTH, 0)):
		test.total = int(unit.scores.get(Ability.STRENGTH, 0))
		test.success = test.total >= test.dc
	if test.success or unit.character == null:
		return test
	# Contraencanto (Bardo 7): reação de um bardo a até 9 m; refaz com vantagem o teste contra Enfeitiçado/Amedrontado.
	if condition in ["charmed", "frightened"]:
		for bard in m.combatants:
			if bard.has_feature("feature.countercharm") and not bard.is_hostile_to(unit) and bard.is_up() \
					and not bard.is_incapacitated() and bard.reaction_available \
					and Attack.grid_distance_feet(bard.position, unit.position) <= 30:
				bard.reaction_available = false
				events.append(feature_event(bard, "countercharm", "Contraencanto: %s refaz o teste com vantagem" % unit.name))
				test = D20Test.roll(m._roller, test.modifier, test.dc, D20Test.Advantage.ADVANTAGE)
				if test.success:
					return test
				break
	var inspiration := unit.effects_of("inspired")
	if not inspiration.is_empty() and test.dc - test.total <= int(str(inspiration[0]["value"]).trim_prefix("d")):
		unit.effects.erase(inspiration[0])
		var bonus := roll_die_text(m, str(inspiration[0]["value"]))
		test.total += bonus
		test.success = test.total >= test.dc
		events.append(feature_event(unit, "bardic_inspiration", "usa a Inspiração de Bardo: +%d no teste" % bonus))
		if test.success:
			return test
	if unit.has_feature("feature.indomitable") and resource_left(unit, m, "indomitable") > 0:
		spend(unit, "indomitable")
		var retry := D20Test.roll(m._roller, test.modifier + unit.character_level, test.dc)
		events.append(feature_event(unit, "indomitable", "Indomável: refaz o teste com +%d" % unit.character_level))
		return retry
	if unit.has_feature("feature.disciplined_survivor") and resource_left(unit, m, "focus") > 0:
		spend(unit, "focus")
		events.append(feature_event(unit, "disciplined_survivor", "Sobrevivente Disciplinado: refaz o teste"))
		return D20Test.roll(m._roller, test.modifier, test.dc)
	if unit.has_feature("feature.stroke_of_luck") and resource_left(unit, m, "stroke_of_luck") > 0:
		spend(unit, "stroke_of_luck")
		events.append(feature_event(unit, "stroke_of_luck", "Golpe de Sorte: o d20 vira 20"))
		test.natural = 20
		test.total = 20 + test.modifier
		test.success = test.total >= test.dc
	return test


# --- Fúria ----------------------------------------------------------------------------------

static func start_rage(m: CombatManager, unit: Combatant, events: Array[Dictionary]) -> void:
	spend(unit, "rage")
	unit.effects.append({"kind": "raging", "source": unit.id, "spell": "Fúria", "on": "none", "actor": "", "count": 0})
	unit.state["raging_extended"] = true
	m._end_concentration(unit, events, "entrou em Fúria")
	if unit.has_feature("feature.mindless_rage"):
		for condition in ["charmed", "frightened"]:
			m.remove_condition(unit, condition, events)
	events.append(feature_event(unit, "rage", "entra em Fúria", {"vfx": "rage"}))
	# Bote Instintivo: pode mover metade do deslocamento.
	if unit.has_feature("feature.instinctive_pounce"):
		m.movement_left_feet += int(m.effective_speed(unit) / 2)


static func end_rage(m: CombatManager, unit: Combatant, events: Array[Dictionary], reason: String) -> void:
	unit.effects = unit.effects.filter(func(e: Dictionary) -> bool: return e["kind"] != "raging")
	events.append(feature_event(unit, "rage_end", "a Fúria termina (%s)" % reason))


## Atacar um inimigo ou forçar um teste de resistência prolonga a Fúria.
static func extend_rage(unit: Combatant) -> void:
	if is_raging(unit):
		unit.state["raging_extended"] = true


# --- Ações do menu ------------------------------------------------------------------------

## Ações de característica disponíveis: [{id, name, target ("none"/"enemy"), error}].
static func actions(m: CombatManager, unit: Combatant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var heavy: bool = unit.character != null and m.registry != null \
			and m.registry.get_entry("item", unit.character.armor_id).get("armor_category") == "heavy"
	if unit.has_feature("feature.rage"):
		if is_raging(unit):
			result.append(_action("extend_rage", "Prolongar Fúria (ação bônus)", "none",
					_bonus_error(m) if not bool(unit.state.get("raging_extended", false)) else "Já prolongada neste turno"))
		else:
			var error := _bonus_error(m)
			if error.is_empty() and resource_left(unit, m, "rage") <= 0:
				error = "Sem usos de Fúria"
			if error.is_empty() and heavy:
				error = "Não entra em Fúria com armadura pesada"
			result.append(_action("rage", "Fúria (ação bônus, %d/%d)" % [resource_left(unit, m, "rage"),
					ClassFeatures.maximum(unit.character, m.registry, "rage")], "none", error))
	if unit.has_feature("feature.reckless_attack") and unit.effects_of("reckless").is_empty():
		result.append(_action("reckless", "Ataque Imprudente (antes do 1º ataque)", "none",
				"" if not m.attack_action_used else "Só antes do primeiro ataque do turno"))
	if unit.has_feature("feature.intimidating_presence"):
		var error := _bonus_error(m)
		if error.is_empty() and resource_left(unit, m, "intimidating_presence") <= 0 and resource_left(unit, m, "rage") <= 0:
			error = "Sem usos (nem Fúria para restaurar)"
		result.append(_action("intimidating_presence", "Presença Intimidadora (ação bônus)", "none", error))
	if unit.has_feature("feature.second_wind"):
		var error := _bonus_error(m)
		if error.is_empty() and resource_left(unit, m, "second_wind") <= 0:
			error = "Sem usos"
		result.append(_action("second_wind", "Retomar o Fôlego (ação bônus, %d)" % resource_left(unit, m, "second_wind"), "none", error))
	if unit.has_feature("feature.action_surge"):
		var error := "" if resource_left(unit, m, "action_surge") > 0 else "Sem usos"
		if error.is_empty() and m.once_per_turn.has("action_surge"):
			error = "Uma vez por turno"
		if error.is_empty() and m.action_available:
			error = "Use a ação do turno primeiro"
		result.append(_action("action_surge", "Surto de Ação (%d)" % resource_left(unit, m, "action_surge"), "none", error))
	if unit.has_feature("feature.steady_aim"):
		var error := _bonus_error(m)
		if error.is_empty() and m.movement_left_feet < m.effective_speed(unit):
			error = "Só sem ter se movido no turno"
		result.append(_action("steady_aim", "Mira Firme (ação bônus)", "none", error))
	if martial_arts_active(unit):
		result.append(_action("bonus_unarmed", "Golpe Desarmado (ação bônus)", "enemy", _bonus_error(m)))
	if unit.has_feature("feature.monks_focus"):
		var focus := resource_left(unit, m, "focus")
		result.append(_action("flurry", "Rajada de Golpes (1 Foco, %d)" % focus, "enemy",
				_bonus_error(m) if focus > 0 else "Sem Foco"))
		result.append(_action("patient_defense", "Defesa Paciente: Desengajar (ação bônus)", "none", _bonus_error(m)))
		result.append(_action("patient_defense_focus", "Defesa Paciente: Desengajar + Esquivar (1 Foco)", "none",
				_bonus_error(m) if focus > 0 else "Sem Foco"))
		var step_error := _bonus_error(m)
		if not step_error.is_empty() and unit.has_feature("feature.fleet_step") and not m.once_per_turn.has("fleet_step"):
			step_error = ""
		result.append(_action("step_of_the_wind", "Passo do Vento: Disparada (ação bônus)", "none", step_error))
		result.append(_action("step_of_the_wind_focus", "Passo do Vento: Disparada + Desengajar (1 Foco)", "none",
				step_error if focus > 0 else "Sem Foco"))
	if unit.has_feature("feature.superior_defense") and unit.effects_of("superior_defense").is_empty():
		result.append(_action("superior_defense", "Defesa Superior (3 Foco)", "none",
				"" if resource_left(unit, m, "focus") >= 3 else "Foco insuficiente"))
	if unit.has_feature("feature.wholeness_of_body"):
		var error := _bonus_error(m)
		if error.is_empty() and resource_left(unit, m, "wholeness_of_body") <= 0:
			error = "Sem usos"
		result.append(_action("wholeness_of_body", "Plenitude do Corpo (ação bônus)", "none", error))
	if not str(unit.state.get("quivering_target", "")).is_empty():
		result.append(_action("end_quivering_palm", "Encerrar Palma Trêmula (gasta um ataque)", "none",
				"" if m.can_attack(unit) else "Sem ataques"))
	_paladin_actions(m, unit, result)
	_ranger_actions(m, unit, result)
	_bard_actions(m, unit, result)
	_cleric_actions(m, unit, result)
	_druid_actions(m, unit, result)
	return result


## Erro da ação de Magia (ação livre e que não venha do Surto de Ação).
static func _magic_error(m: CombatManager) -> String:
	if not m.action_available:
		return "A ação deste turno já foi usada"
	if m.surge_action:
		return "A ação do Surto de Ação não pode ser a ação de Magia"
	return ""


static func _bard_actions(m: CombatManager, unit: Combatant, result: Array[Dictionary]) -> void:
	if unit.has_feature("feature.bardic_inspiration"):
		var left := resource_left(unit, m, "bardic_inspiration")
		var error := _bonus_error(m)
		if error.is_empty() and left <= 0:
			error = "Sem usos"
		result.append(_action("bardic_inspiration", "Inspiração de Bardo (ação bônus, %s, %d)" % [table(unit, m, "bardic_die"), left],
				"other_ally", error, 60))
	if unit.has_feature("feature.font_of_inspiration") and unit.character != null \
			and resource_left(unit, m, "bardic_inspiration") < ClassFeatures.maximum(unit.character, m.registry, "bardic_inspiration"):
		var error := "" if Spellcasting.lowest_slot(unit.character, m.registry, 1) > 0 else "Sem espaços de magia"
		result.append(_action("font_of_inspiration", "Fonte de Inspiração: gasta espaço por 1 Inspiração", "none", error))


static func spark_dice(unit: Combatant) -> int:
	var level := unit.character_level
	return 1 + (1 if level >= 7 else 0) + (1 if level >= 13 else 0) + (1 if level >= 18 else 0)


static func _cleric_actions(m: CombatManager, unit: Combatant, result: Array[Dictionary]) -> void:
	if not unit.has_feature("feature.channel_divinity"):
		return
	var uses := resource_left(unit, m, "channel_divinity")
	var error := _magic_error(m)
	if error.is_empty() and uses <= 0:
		error = "Sem usos de Canalizar Divindade"
	var spark := "%dd8%s" % [spark_dice(unit), Ability.format_modifier(int(unit.modifiers.get(Ability.WISDOM, 0)))]
	result.append(_action("divine_spark_heal", "Centelha Divina: curar %s (ação, Canalizar Divindade %d)" % [spark, uses], "ally", error, 30))
	result.append(_action("divine_spark_harm", "Centelha Divina: ferir %s (ação, Canalizar Divindade %d)" % [spark, uses], "enemy", error, 30))
	result.append(_action("turn_undead", "Expulsar Mortos-Vivos (ação, Canalizar Divindade %d)" % uses, "none", error))
	if unit.has_feature("feature.preserve_life"):
		var preserve_error := error
		if preserve_error.is_empty() and _bloodied_allies(m, unit).is_empty():
			preserve_error = "Nenhum aliado Sangrando a até 9 m"
		result.append(_action("preserve_life", "Preservar a Vida (ação, Canalizar Divindade %d)" % uses, "none", preserve_error))


static func _bloodied_allies(m: CombatManager, unit: Combatant) -> Array[Combatant]:
	var result: Array[Combatant] = []
	for ally in m.combatants:
		if ally.is_up() and not ally.is_hostile_to(unit) and ally.hp * 2 <= ally.max_hp \
				and Attack.grid_distance_feet(unit.position, ally.position) <= 30:
			result.append(ally)
	return result


static func _druid_actions(m: CombatManager, unit: Combatant, result: Array[Dictionary]) -> void:
	if unit.character == null or m.registry == null:
		return
	var uses := resource_left(unit, m, "wild_shape")
	if unit.has_feature("feature.wild_shape"):
		for form_id in CharacterChoices.wild_shape_forms(unit.character):
			var beast := m.registry.get_entry("monster", form_id)
			if beast.is_empty():
				continue
			var error := _bonus_error(m)
			if error.is_empty() and uses <= 0:
				error = "Sem usos de Forma Selvagem"
			if error.is_empty() and unit.state.get("wild_shape", {}).get("form") == form_id:
				error = "Já está nesta forma"
			result.append(_action("wild_shape:%s" % form_id, "Forma Selvagem: %s (ação bônus, %d)" % [beast["name"], uses], "none", error))
		if in_wild_shape(unit):
			result.append(_action("end_wild_shape", "Sair da Forma Selvagem (ação bônus)", "none", _bonus_error(m)))
	if unit.has_feature("feature.wild_resurgence"):
		var gain_error := "" if uses <= 0 else "Ainda há usos de Forma Selvagem"
		if gain_error.is_empty() and m.once_per_turn.has("wild_resurgence"):
			gain_error = "Uma vez por turno"
		if gain_error.is_empty() and Spellcasting.lowest_slot(unit.character, m.registry, 1) == 0:
			gain_error = "Sem espaços de magia"
		result.append(_action("resurgence_gain", "Ressurgimento Selvagem: espaço por 1 Forma Selvagem", "none", gain_error))
		var slot_error := "" if uses > 0 else "Sem usos de Forma Selvagem"
		if slot_error.is_empty() and resource_left(unit, m, "wild_resurgence") <= 0:
			slot_error = "Já usado neste descanso longo"
		if slot_error.is_empty() and (unit.character.spell_slots_spent.is_empty() or unit.character.spell_slots_spent[0] <= 0):
			slot_error = "Nenhum espaço de 1º círculo gasto"
		result.append(_action("resurgence_slot", "Ressurgimento Selvagem: Forma Selvagem por espaço de 1º", "none", slot_error))
	if unit.has_feature("feature.archdruid"):
		var error := "" if resource_left(unit, m, "nature_magician") > 0 else "Já usado neste descanso longo"
		if error.is_empty() and _nature_magician_slot(unit, m) == 0:
			error = "Nenhum espaço gasto que os usos de Forma Selvagem cubram"
		result.append(_action("nature_magician", "Mago da Natureza: Forma Selvagem por espaço", "none", error))
	for spec: Array in [["feature.lands_aid", "lands_aid", "Auxílio da Terra", "enemy", 60],
			["feature.natures_sanctuary", "natures_sanctuary", "Santuário da Natureza", "none", 5]]:
		if unit.has_feature(spec[0]):
			var error := _magic_error(m)
			if error.is_empty() and uses <= 0:
				error = "Sem usos de Forma Selvagem"
			result.append(_action(spec[1], "%s (ação, Forma Selvagem %d)" % [spec[2], uses], spec[3], error, spec[4]))


## Mago da Natureza: maior círculo gasto que os usos de Forma Selvagem pagam (2 círculos por uso).
static func _nature_magician_slot(unit: Combatant, m: CombatManager) -> int:
	var uses := resource_left(unit, m, "wild_shape")
	var spent := unit.character.spell_slots_spent
	for slot_level in range(mini(9, spent.size()), 0, -1):
		if spent[slot_level - 1] > 0 and slot_level <= 2 * uses:
			return slot_level
	return 0


static func _paladin_actions(m: CombatManager, unit: Combatant, result: Array[Dictionary]) -> void:
	if unit.has_feature("feature.lay_on_hands"):
		var pool := resource_left(unit, m, "lay_on_hands")
		var error := _bonus_error(m)
		if error.is_empty() and pool <= 0:
			error = "Sem pontos de cura"
		if error.is_empty() and unit.hp >= unit.max_hp and _curable(unit).is_empty():
			error = "PV cheios e nada a curar"
		result.append(_action("lay_on_hands", "Cura pelas Mãos (ação bônus, %d PV)" % pool, "none", error))
	var divinity := resource_left(unit, m, "channel_divinity")
	if unit.has_feature("feature.channel_divinity_paladin"):
		var error := _bonus_error(m)
		if error.is_empty() and divinity <= 0:
			error = "Sem usos de Canalizar Divindade"
		result.append(_action("divine_sense", "Sentido Divino (ação bônus, Canalizar Divindade %d)" % divinity, "none", error))
	if unit.has_feature("feature.sacred_weapon") and not bool(unit.state.get("sacred_weapon", false)):
		var error := "" if m.can_attack(unit) else "Só ao usar a ação de Ataque"
		if error.is_empty() and divinity <= 0:
			error = "Sem usos de Canalizar Divindade"
		result.append(_action("sacred_weapon", "Arma Sagrada (Canalizar Divindade %d)" % divinity, "none", error))
	if unit.has_feature("feature.abjure_foes"):
		var error := "" if m.action_available else "A ação deste turno já foi usada"
		if error.is_empty() and m.surge_action:
			error = "A ação do Surto de Ação não pode ser a ação de Magia"
		if error.is_empty() and divinity <= 0:
			error = "Sem usos de Canalizar Divindade"
		result.append(_action("abjure_foes", "Repudiar Inimigos (ação, Canalizar Divindade %d)" % divinity, "none", error))
	if unit.has_feature("feature.holy_nimbus") and not bool(unit.state.get("holy_nimbus", false)):
		var error := _bonus_error(m)
		if error.is_empty() and resource_left(unit, m, "holy_nimbus") <= 0 and _slot_5_left(m, unit) <= 0:
			error = "Sem usos (nem espaço de 5º círculo)"
		result.append(_action("holy_nimbus", "Nimbo Sagrado (ação bônus)", "none", error))


static func _ranger_actions(m: CombatManager, unit: Combatant, result: Array[Dictionary]) -> void:
	if unit.state.has("mark_to_move") and unit.concentration.get("spell_id") == unit.state["mark_to_move"].get("spell_id"):
		result.append(_action("move_mark", "Mover %s (ação bônus)" % unit.state["mark_to_move"]["spell"], "enemy",
				_bonus_error(m), 90))
	if unit.has_feature("feature.tireless"):
		var error := "" if m.action_available else "A ação deste turno já foi usada"
		if error.is_empty() and resource_left(unit, m, "tireless") <= 0:
			error = "Sem usos"
		result.append(_action("tireless", "Incansável: PV temporários (ação, %d)" % resource_left(unit, m, "tireless"), "none", error))
	if unit.has_feature("feature.natures_veil"):
		var error := _bonus_error(m)
		if error.is_empty() and resource_left(unit, m, "natures_veil") <= 0:
			error = "Sem usos"
		result.append(_action("natures_veil", "Véu da Natureza: Invisível (ação bônus, %d)" % resource_left(unit, m, "natures_veil"),
				"none", error))
	if unit.has_feature("hunters_prey.horde_breaker"):
		var attack := unit.get_attack(str(m.once_per_turn.get("last_weapon_attack", "")))
		var error := ""
		if attack.is_empty():
			error = "Ataque com uma arma primeiro"
		elif m.once_per_turn.has("horde_breaker"):
			error = "Uma vez por turno"
		var reach := int(attack.get("reach", 5)) if attack.get("attack_type", "melee") == "melee" else int(attack.get("range_long", 0))
		result.append(_action("horde_breaker", "Quebrador de Hordas (ataque extra)", "enemy", error, maxi(5, reach)))


static func _action(id: String, name: String, target: String, error: String, range_feet: int = 5) -> Dictionary:
	return {"id": id, "name": name, "target": target, "error": error, "range": range_feet}


## Condições que a Cura pelas Mãos pode remover (Envenenado; mais as do Toque Restaurador).
static func _curable(unit: Combatant) -> Array[String]:
	var conditions: Array = ["poisoned"]
	if unit.has_feature("feature.restoring_touch"):
		conditions.append_array(RESTORING_TOUCH)
	var result: Array[String] = []
	for condition: String in conditions:
		if unit.has_condition(condition):
			result.append(condition)
	return result


static func _slot_5_left(m: CombatManager, unit: Combatant) -> int:
	if unit.character == null or m.registry == null:
		return 0
	var left := Spellcasting.slots_left(unit.character, m.registry)
	return left[4] if left.size() >= 5 else 0


static func _bonus_error(m: CombatManager) -> String:
	return "" if m.bonus_action_available else "A ação bônus deste turno já foi usada"


## Opções (preferências) mostradas no menu: [{key, value, name, checked}].
static func toggles(unit: Combatant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if unit.has_feature("feature.brutal_strike"):
		for effect: String in BRUTAL_NAMES:
			if effect in ["staggering", "sundering"] and not unit.has_feature("feature.improved_brutal_strike_13"):
				continue
			result.append({"key": "brutal", "value": effect, "name": "Golpe Brutal: %s" % BRUTAL_NAMES[effect],
					"checked": unit.options.get("brutal", "") == effect})
	if unit.has_feature("feature.cunning_strike"):
		for effect: String in CUNNING_NAMES:
			if effect in ["daze", "obscure", "knock_out"] and not unit.has_feature("feature.devious_strikes"):
				continue
			result.append({"key": "cunning", "value": effect, "name": "Golpe Astuto: %s (%dd6)" % [CUNNING_NAMES[effect],
					CUNNING_COSTS[effect]], "checked": effect in unit.options.get("cunning", [])})
	if unit.has_feature("feature.stunning_strike"):
		result.append({"key": "stunning", "value": true, "name": "Golpe Atordoante (1 Foco ao acertar)",
				"checked": bool(unit.options.get("stunning", true))})
	if unit.has_feature("feature.open_hand_technique"):
		for effect: String in OPEN_HAND_NAMES:
			result.append({"key": "open_hand", "value": effect, "name": "Mão Aberta: %s" % OPEN_HAND_NAMES[effect],
					"checked": unit.options.get("open_hand", "topple") == effect})
	if unit.has_feature("feature.tactical_master"):
		for effect: Array in [["push", "Empurrar"], ["sap", "Enfraquecer"], ["slow", "Lentidão"]]:
			result.append({"key": "tactical_master", "value": effect[0], "name": "Mestre Tático: %s" % effect[1],
					"checked": unit.options.get("tactical_master", "") == effect[0]})
	if unit.has_feature("feature.quivering_palm") and str(unit.state.get("quivering_target", "")).is_empty():
		result.append({"key": "quivering", "value": true, "name": "Palma Trêmula no próximo acerto (4 Foco)",
				"checked": bool(unit.options.get("quivering", false))})
	if not unit.get_spell("spell.divine_smite").is_empty():
		for mode: Array in [["always", "em todo acerto corpo a corpo"], ["critical", "só em acertos críticos"]]:
			result.append({"key": "smite", "value": mode[0], "name": "Golpe Divino: %s" % mode[1],
					"checked": unit.options.get("smite", "") == mode[0]})
	return result


## Alterna uma opção do menu.
static func set_option(unit: Combatant, key: String, value: Variant) -> void:
	match key:
		"cunning":
			var list: Array = unit.options.get("cunning", []).duplicate()
			if value in list:
				list.erase(value)
			else:
				list.append(value)
			unit.options["cunning"] = list
		"brutal", "open_hand", "tactical_master", "smite":
			unit.options[key] = "" if unit.options.get(key, "") == value and key != "open_hand" else value
		_:
			unit.options[key] = not bool(unit.options.get(key, key == "stunning"))


## Executa uma ação de característica. Retorna "" ou a mensagem de erro.
static func do_action(m: CombatManager, unit: Combatant, action_id: String, target: Combatant,
		events: Array[Dictionary]) -> String:
	var spec := {}
	for action in actions(m, unit):
		if action["id"] == action_id:
			spec = action
	if spec.is_empty():
		return "Ação indisponível"
	if not str(spec["error"]).is_empty():
		return spec["error"]
	if spec["target"] == "enemy" and (target == null or not target.is_up() or not target.is_hostile_to(unit)):
		return "Escolha um inimigo"
	if spec["target"] in ["ally", "other_ally"] and (target == null or target.is_hostile_to(unit)):
		return "Escolha um aliado"
	if spec["target"] == "other_ally" and target == unit:
		return "Escolha outra criatura"
	if spec["target"] != "none" and Attack.grid_distance_feet(unit.position, target.position) > int(spec["range"]):
		return "Alvo fora do alcance (%d pés)" % int(spec["range"])
	if action_id.begins_with("wild_shape:"):
		m.bonus_action_available = false
		spend(unit, "wild_shape")
		assume_form(m, unit, action_id.trim_prefix("wild_shape:"), events)
		return ""
	if action_id == "horde_breaker":
		var error := _horde_breaker_error(m, target)
		if not error.is_empty():
			return error
	match action_id:
		"rage":
			m.bonus_action_available = false
			start_rage(m, unit, events)
		"extend_rage":
			m.bonus_action_available = false
			unit.state["raging_extended"] = true
			events.append(feature_event(unit, "rage", "prolonga a Fúria"))
		"reckless":
			unit.effects.append({"kind": "reckless", "source": unit.id, "spell": "Ataque Imprudente", "on": "turn_start",
					"actor": unit.id, "count": 1})
			events.append(feature_event(unit, "reckless", "ataca imprudentemente"))
		"intimidating_presence":
			m.bonus_action_available = false
			if resource_left(unit, m, "intimidating_presence") > 0:
				spend(unit, "intimidating_presence")
			else:
				spend(unit, "rage")
			var dc := 8 + int(unit.modifiers.get(Ability.STRENGTH, 0)) + unit.proficiency_bonus
			events.append(feature_event(unit, "intimidating_presence", "Presença Intimidadora", {"vfx": "fear"}))
			extend_rage(unit)
			for enemy in m.combatants:
				if enemy.is_up() and enemy.is_hostile_to(unit) and Attack.grid_distance_feet(unit.position, enemy.position) <= 30:
					var save := m._roll_save(enemy, Ability.WISDOM, dc, "frightened")
					events.append(feature_event(unit, "intimidating_presence", "%s testa Sabedoria" % enemy.name,
							{"target": enemy.id, "save": save_event(save, "wis")}))
					if not save.success:
						m.add_condition(enemy, "frightened", unit.id, events, {"save_ends": {"ability": "wis", "dc": dc}})
		"second_wind":
			m.bonus_action_available = false
			spend(unit, "second_wind")
			var healed := mini(unit.max_hp - unit.hp, roll(m, "1d10") + unit.character_level)
			unit.hp += healed
			events.append(feature_event(unit, "second_wind", "Retomar o Fôlego: +%d PV" % healed, {"healed": healed, "vfx": "heal"}))
			if unit.has_feature("feature.tactical_shift"):
				m.movement_left_feet += int(m.effective_speed(unit) / 2)
				m.disengaged = true
		"action_surge":
			spend(unit, "action_surge")
			m.once_per_turn["action_surge"] = true
			m.action_available = true
			m.attack_action_used = false
			m.attacks_left = 0
			m.surge_action = true
			events.append(feature_event(unit, "action_surge", "Surto de Ação: uma ação a mais"))
		"steady_aim":
			m.bonus_action_available = false
			m.movement_left_feet = 0
			unit.effects.append({"kind": "steady_aim", "source": unit.id, "spell": "Mira Firme", "on": "turn_end",
					"actor": unit.id, "count": 1})
			events.append(feature_event(unit, "steady_aim", "Mira Firme: vantagem no próximo ataque"))
		"bonus_unarmed":
			m.bonus_action_available = false
			_mark_bonus_used(m, "bonus_unarmed")
			m._resolve_weapon_attack(unit, target, unit.get_attack("attack.unarmed_strike"), events, false)
		"flurry":
			m.bonus_action_available = false
			_mark_bonus_used(m, "flurry")
			spend(unit, "focus")
			var strikes := 3 if unit.has_feature("feature.heightened_focus") else 2
			events.append(feature_event(unit, "flurry", "Rajada de Golpes (%d golpes)" % strikes))
			m.once_per_turn["flurry_active"] = true
			var current_target := target
			for i in strikes:
				if current_target == null or not current_target.is_up():
					current_target = _adjacent_enemy(m, unit)
				if current_target == null or m.state != CombatManager.State.IN_PROGRESS:
					break
				m._resolve_weapon_attack(unit, current_target, unit.get_attack("attack.unarmed_strike"), events, false)
			m.once_per_turn.erase("flurry_active")
		"patient_defense", "patient_defense_focus":
			m.bonus_action_available = false
			_mark_bonus_used(m, "patient_defense")
			m.disengaged = true
			var text := "Defesa Paciente: Desengajar"
			if action_id == "patient_defense_focus":
				spend(unit, "focus")
				unit.effects.append({"kind": "dodging", "source": unit.id, "spell": "Esquivar", "on": "turn_start",
						"actor": unit.id, "count": 1})
				text += " e Esquivar"
				if unit.has_feature("feature.heightened_focus"):
					var die := table(unit, m, "martial_arts_die")
					unit.temp_hp = maxi(unit.temp_hp, roll(m, die) + roll(m, die))
					text += " (+%d PV temporários)" % unit.temp_hp
			events.append(feature_event(unit, "patient_defense", text))
		"step_of_the_wind", "step_of_the_wind_focus":
			if not m.bonus_action_available and unit.has_feature("feature.fleet_step"):
				m.once_per_turn["fleet_step"] = true
			m.bonus_action_available = false
			m.movement_left_feet += m.effective_speed(unit)
			var text := "Passo do Vento: Disparada"
			if action_id == "step_of_the_wind_focus":
				spend(unit, "focus")
				m.disengaged = true
				text += " e Desengajar"
			events.append(feature_event(unit, "step_of_the_wind", text))
		"superior_defense":
			spend(unit, "focus", 3)
			unit.effects.append({"kind": "superior_defense", "source": unit.id, "spell": "Defesa Superior", "on": "turn_start",
					"actor": unit.id, "count": 10})
			events.append(feature_event(unit, "superior_defense", "Defesa Superior: resistência a quase todo dano", {"vfx": "aura"}))
		"wholeness_of_body":
			m.bonus_action_available = false
			_mark_bonus_used(m, "wholeness_of_body")
			spend(unit, "wholeness_of_body")
			var healed := mini(unit.max_hp - unit.hp, maxi(1, roll(m, table(unit, m, "martial_arts_die")) + int(unit.modifiers.get(Ability.WISDOM, 0))))
			unit.hp += healed
			events.append(feature_event(unit, "wholeness_of_body", "Plenitude do Corpo: +%d PV" % healed, {"healed": healed, "vfx": "heal"}))
		"end_quivering_palm":
			var victim := m.get_combatant(str(unit.state["quivering_target"]))
			unit.state["quivering_target"] = ""
			m._use_attack(unit)
			if victim != null and victim.is_up():
				var save := m._roll_save(victim, Ability.CONSTITUTION, focus_dc(unit))
				var damage := roll(m, "10d12")
				if save.success:
					@warning_ignore("integer_division")
					damage = damage / 2
				var event := feature_event(unit, "quivering_palm", "Palma Trêmula", {"target": victim.id,
						"save": save_event(save, "con"), "damage": damage, "damage_type": "force"})
				m._apply_damage(victim, Attack.apply_damage_modifiers(damage, "force", victim.all_resistances()), events, event)
		"lay_on_hands":
			m.bonus_action_available = false
			lay_on_hands(m, unit, unit, events)
		"divine_sense":
			m.bonus_action_available = false
			spend(unit, "channel_divinity")
			var found := PackedStringArray()
			for other in m.combatants:
				if other.is_up() and other.creature_type in DIVINE_SENSE_TYPES and Attack.grid_distance_feet(unit.position, other.position) <= 60:
					found.append("%s (%s)" % [other.name, other.creature_type])
			events.append(feature_event(unit, "divine_sense", "Sentido Divino: %s" % (", ".join(found) if not found.is_empty()
					else "nenhum celestial, corruptor ou morto-vivo a até 18 m"), {"vfx": "aura"}))
		"sacred_weapon":
			spend(unit, "channel_divinity")
			unit.state["sacred_weapon"] = true
			events.append(feature_event(unit, "sacred_weapon", "Arma Sagrada: +%d nos ataques corpo a corpo com arma" %
					maxi(1, int(unit.modifiers.get(Ability.CHARISMA, 0))), {"vfx": "smite"}))
		"abjure_foes":
			m.action_available = false
			spend(unit, "channel_divinity")
			events.append(feature_event(unit, "abjure_foes", "Repudiar Inimigos", {"vfx": "fear"}))
			var foes: Array[Combatant] = []
			for enemy in m.combatants:
				if enemy.is_up() and enemy.is_hostile_to(unit) and Attack.grid_distance_feet(unit.position, enemy.position) <= 60:
					foes.append(enemy)
			foes.sort_custom(func(a: Combatant, b: Combatant) -> bool:
				return Attack.grid_distance_feet(unit.position, a.position) < Attack.grid_distance_feet(unit.position, b.position))
			for enemy in foes.slice(0, maxi(1, int(unit.modifiers.get(Ability.CHARISMA, 0)))):
				var save := m._roll_save(enemy, Ability.WISDOM, unit.spell_dc, "frightened")
				events.append(feature_event(unit, "abjure_foes", "%s testa Sabedoria" % enemy.name,
						{"target": enemy.id, "save": save_event(save, "wis")}))
				if not save.success:
					m.add_condition(enemy, "frightened", unit.id, events, {"ends_on_damage": true, "on": "turn_end",
							"actor": enemy.id, "count": 10})
		"holy_nimbus":
			m.bonus_action_available = false
			if resource_left(unit, m, "holy_nimbus") > 0:
				spend(unit, "holy_nimbus")
			else:
				Spellcasting.spend_slot(unit.character, 5)
			unit.state["holy_nimbus"] = true
			events.append(feature_event(unit, "holy_nimbus", "Nimbo Sagrado: a aura arde com luz solar", {"vfx": "smite"}))
		"move_mark":
			m.bonus_action_available = false
			var mark: Dictionary = unit.state["mark_to_move"]
			unit.state.erase("mark_to_move")
			target.effects.append(mark)
			events.append(feature_event(unit, "move_mark", "move %s para %s" % [mark["spell"], target.name],
					{"target": target.id, "vfx": "mark"}))
		"tireless":
			m.action_available = false
			spend(unit, "tireless")
			var temp := maxi(1, roll(m, "1d8") + int(unit.modifiers.get(Ability.WISDOM, 0)))
			unit.temp_hp = maxi(unit.temp_hp, temp)
			events.append(feature_event(unit, "tireless", "Incansável: %d PV temporários" % temp, {"vfx": "heal"}))
		"natures_veil":
			m.bonus_action_available = false
			spend(unit, "natures_veil")
			events.append(feature_event(unit, "natures_veil", "Véu da Natureza: fica Invisível", {"vfx": "aura"}))
			m.add_condition(unit, "invisible", unit.id, events, {"on": "turn_end", "actor": unit.id, "count": 2})
		"bardic_inspiration":
			m.bonus_action_available = false
			spend(unit, "bardic_inspiration")
			for old in target.effects_of("inspired"):
				target.effects.erase(old)
			var die := table(unit, m, "bardic_die")
			target.effects.append({"kind": "inspired", "source": unit.id, "spell": "Inspiração de Bardo", "value": die,
					"on": "none", "actor": "", "count": 0})
			events.append(feature_event(unit, "bardic_inspiration", "inspira %s (%s)" % [target.name, die],
					{"target": target.id, "vfx": "aura"}))
		"font_of_inspiration":
			var slot := Spellcasting.lowest_slot(unit.character, m.registry, 1)
			Spellcasting.spend_slot(unit.character, slot)
			ClassFeatures.restore(unit.character, "bardic_inspiration", 1)
			events.append(feature_event(unit, "font_of_inspiration", "Fonte de Inspiração: espaço de %dº círculo vira 1 Inspiração" % slot))
		"divine_spark_heal", "divine_spark_harm":
			m.action_available = false
			spend(unit, "channel_divinity")
			var dice := "%dd8" % spark_dice(unit)
			var wis := int(unit.modifiers.get(Ability.WISDOM, 0))
			if action_id == "divine_spark_heal":
				var rolled := DiceExpression.parse(dice).maximum() if unit.has_feature("feature.supreme_healing") else roll(m, dice)
				var healed := mini(target.max_hp - target.hp, maxi(0, rolled + wis))
				target.hp += healed
				events.append(feature_event(unit, "divine_spark", "Centelha Divina cura %d PV de %s" % [healed, target.name],
						{"target": target.id, "healed": healed, "vfx": "heal"}))
			else:
				var save := m._roll_save(target, Ability.CONSTITUTION, unit.spell_dc)
				var amount := maxi(0, roll(m, dice) + wis)
				if save.success:
					@warning_ignore("integer_division")
					amount = amount / 2
				var kind := "necrotic" if "radiant" in target.all_resistances() and not "necrotic" in target.all_resistances() else "radiant"
				var damage := Attack.apply_damage_modifiers(amount, kind, target.all_resistances())
				m._apply_damage(target, damage, events, feature_event(unit, "divine_spark", "Centelha Divina",
						{"target": target.id, "save": save_event(save, "con"), "damage": damage, "damage_type": kind, "vfx": "smite"}))
		"turn_undead":
			m.action_available = false
			spend(unit, "channel_divinity")
			var undead: Array[Combatant] = []
			for other in m.combatants:
				if other.is_up() and other.is_hostile_to(unit) and other.creature_type == "morto-vivo" \
						and Attack.grid_distance_feet(unit.position, other.position) <= 30:
					undead.append(other)
			events.append(feature_event(unit, "turn_undead", "Expulsar Mortos-Vivos%s" % ("" if not undead.is_empty()
					else ": nenhum morto-vivo a até 9 m"), {"vfx": "smite"}))
			for foe in undead:
				var save := m._roll_save(foe, Ability.WISDOM, unit.spell_dc, "frightened")
				events.append(feature_event(unit, "turn_undead", "%s testa Sabedoria" % foe.name, {"target": foe.id,
						"save": save_event(save, "wis")}))
				if save.success:
					continue
				# Queimar Mortos-Vivos (Clérigo 5): o dano vem antes, para não encerrar a expulsão.
				if unit.has_feature("feature.sear_undead"):
					var sear := roll(m, "%dd8" % maxi(1, int(unit.modifiers.get(Ability.WISDOM, 0))))
					var seared := Attack.apply_damage_modifiers(sear, "radiant", foe.all_resistances())
					m._apply_damage(foe, seared, events, feature_event(unit, "sear_undead", "Queimar Mortos-Vivos",
							{"target": foe.id, "damage": seared, "damage_type": "radiant"}))
				if foe.is_up():
					for condition in ["frightened", "incapacitated"]:
						m.add_condition(foe, condition, unit.id, events, {"ends_on_damage": true, "on": "turn_end",
								"actor": foe.id, "count": 10})
		"preserve_life":
			m.action_available = false
			spend(unit, "channel_divinity")
			var pool := 5 * unit.character_level
			var allies := _bloodied_allies(m, unit)
			allies.sort_custom(func(a: Combatant, b: Combatant) -> bool: return a.hp * b.max_hp < b.hp * a.max_hp)
			var total := 0
			for ally in allies:
				@warning_ignore("integer_division")
				var healed := mini(pool, maxi(0, ally.max_hp / 2 - ally.hp))
				ally.hp += healed
				pool -= healed
				total += healed
			events.append(feature_event(unit, "preserve_life", "Preservar a Vida: %d PV" % total,
					{"healed": total, "vfx": "heal"}))
		"end_wild_shape":
			m.bonus_action_available = false
			revert_form(m, unit, events, "ação bônus")
		"resurgence_gain":
			m.once_per_turn["wild_resurgence"] = true
			var slot := Spellcasting.lowest_slot(unit.character, m.registry, 1)
			Spellcasting.spend_slot(unit.character, slot)
			ClassFeatures.restore(unit.character, "wild_shape", 1)
			events.append(feature_event(unit, "wild_resurgence", "Ressurgimento Selvagem: espaço de %dº círculo vira 1 Forma Selvagem" % slot))
		"resurgence_slot":
			spend(unit, "wild_shape")
			spend(unit, "wild_resurgence")
			unit.character.spell_slots_spent[0] -= 1
			events.append(feature_event(unit, "wild_resurgence", "Ressurgimento Selvagem: 1 Forma Selvagem vira espaço de 1º círculo"))
		"nature_magician":
			var slot := _nature_magician_slot(unit, m)
			@warning_ignore("integer_division")
			var cost := (slot + 1) / 2
			spend(unit, "wild_shape", cost)
			spend(unit, "nature_magician")
			unit.character.spell_slots_spent[slot - 1] -= 1
			events.append(feature_event(unit, "archdruid", "Mago da Natureza: %d Forma(s) Selvagem(ns) viram espaço de %dº círculo" % [cost, slot]))
		"lands_aid":
			m.action_available = false
			spend(unit, "wild_shape")
			var level := unit.character_level
			var dice := "%dd6" % (4 if level >= 14 else (3 if level >= 10 else 2))
			events.append(feature_event(unit, "lands_aid", "Auxílio da Terra", {"target": target.id, "vfx": "spray"}))
			var center := target.position
			var wounded: Combatant = null
			for other in m.combatants:
				if not other.is_up() or Attack.grid_distance_feet(center, other.position) > 10:
					continue
				if other.is_hostile_to(unit):
					var save := m._roll_save(other, Ability.CONSTITUTION, unit.spell_dc)
					var amount := roll(m, dice)
					if save.success:
						@warning_ignore("integer_division")
						amount = amount / 2
					var damage := Attack.apply_damage_modifiers(amount, "necrotic", other.all_resistances())
					m._apply_damage(other, damage, events, feature_event(unit, "lands_aid", "espinhos em %s" % other.name,
							{"target": other.id, "save": save_event(save, "con"), "damage": damage, "damage_type": "necrotic"}))
				elif other.hp < other.max_hp and (wounded == null or other.hp * wounded.max_hp < wounded.hp * other.max_hp):
					wounded = other
			if wounded != null:
				var healed := mini(wounded.max_hp - wounded.hp, roll(m, dice))
				wounded.hp += healed
				events.append(feature_event(unit, "lands_aid", "flores curam %d PV de %s" % [healed, wounded.name],
						{"target": wounded.id, "healed": healed, "vfx": "heal"}))
		"natures_sanctuary":
			m.action_available = false
			spend(unit, "wild_shape")
			var cells: Array[Vector2i] = []
			for dx in range(-1, 2):
				for dy in range(-1, 2):
					cells.append(unit.position + Vector2i(dx, dy))
			unit.state["sanctuary"] = {"cells": cells, "rounds": 10}
			refresh_sanctuary(m, unit)
			events.append(feature_event(unit, "natures_sanctuary", "Santuário da Natureza: árvores espectrais em volta", {"vfx": "aura"}))
		"horde_breaker":
			m.once_per_turn["horde_breaker"] = true
			events.append(feature_event(unit, "horde_breaker", "Quebrador de Hordas contra %s" % target.name))
			m._resolve_weapon_attack(unit, target, unit.get_attack(str(m.once_per_turn["last_weapon_attack"])), events, false)
	return ""


## Quebrador de Hordas: outra criatura, ainda não atacada no turno, a até 1,5 m de uma já atacada.
static func _horde_breaker_error(m: CombatManager, target: Combatant) -> String:
	var attacked: Array = m.once_per_turn.get("attacked_ids", [])
	if target.id in attacked:
		return "Escolha uma criatura que você ainda não atacou neste turno"
	for id: Variant in attacked:
		var original := m.get_combatant(str(id))
		if original != null and Attack.grid_distance_feet(original.position, target.position) <= 5:
			return ""
	return "O alvo precisa estar a até 1,5 m de uma criatura que você atacou"


static func lay_on_hands(m: CombatManager, paladin: Combatant, target: Combatant, events: Array[Dictionary]) -> void:
	var pool := resource_left(paladin, m, "lay_on_hands")
	var cured := PackedStringArray()
	for condition in _curable(target):
		if pool < 5:
			break
		m.remove_condition(target, condition, events)
		spend(paladin, "lay_on_hands", 5)
		pool -= 5
		cured.append(CombatManager.CONDITION_NAMES[condition])
	var healed := mini(target.max_hp - target.hp, pool)
	target.hp += healed
	spend(paladin, "lay_on_hands", healed)
	var text := "Cura pelas Mãos: +%d PV" % healed
	if not cured.is_empty():
		text += " e remove %s" % ", ".join(cured)
	events.append(feature_event(paladin, "lay_on_hands", text, {"target": target.id, "healed": healed, "vfx": "heal"}))


## Passo Veloz: depois de outra ação bônus, Passo do Vento sem gastar ação bônus.
static func _mark_bonus_used(m: CombatManager, _action_id: String) -> void:
	m.once_per_turn.erase("fleet_step")


static func _adjacent_enemy(m: CombatManager, unit: Combatant) -> Combatant:
	for other in m.combatants:
		if other.is_up() and other.is_hostile_to(unit) and m._adjacent(other, unit):
			return other
	return null
