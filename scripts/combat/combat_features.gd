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
	# Foco Perfeito: sem Metabolismo, volta a ter ao menos 4 pontos de Foco.
	if unit.has_feature("feature.perfect_focus") and not metabolized and resource_left(unit, m, "focus") < 4:
		var maximum := ClassFeatures.maximum(c, m.registry, "focus")
		c.resources_spent["focus"] = maxi(0, maximum - 4)
		events.append(feature_event(unit, "perfect_focus", "recupera Foco até 4"))


static func on_turn_start(m: CombatManager, unit: Combatant, events: Array[Dictionary]) -> void:
	unit.state["raging_extended"] = false
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
	if actor.has_feature("feature.stroke_of_luck") and resource_left(actor, m, "stroke_of_luck") > 0:
		spend(actor, "stroke_of_luck")
		events.append(feature_event(actor, "stroke_of_luck", "Golpe de Sorte: o d20 vira 20"))
		roll["natural"] = 20
		roll["total"] = 20 + bonus
		roll["hit"] = true
		roll["critical"] = true
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
	return extras


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


## Tipo de dano do desarmado com Golpes Fortalecidos: energia se o alvo resistir ao contundente.
static func damage_type_for(actor: Combatant, target: Combatant, attack: Dictionary) -> String:
	if attack.get("unarmed", "") == "damage" and actor.has_feature("feature.empowered_strikes") \
			and "bludgeoning" in target.all_resistances():
		return "force"
	return str(attack["damage_type"])


## Efeitos depois de um acerto com dano (Golpe Atordoante, Golpe Astuto, Golpe Brutal, Mão Aberta, Palma Trêmula).
static func after_hit(m: CombatManager, actor: Combatant, target: Combatant, attack: Dictionary, events: Array[Dictionary]) -> void:
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


static func save_disadvantage(unit: Combatant) -> int:
	if not unit.effects_of("staggered").is_empty():
		unit.effects = unit.effects.filter(func(e: Dictionary) -> bool: return e["kind"] != "staggered")
		return 1
	return 0


## Depois do teste: Poder Indomável (Força mínima), Indomável, Sobrevivente Disciplinado e Golpe de Sorte.
static func after_save(m: CombatManager, unit: Combatant, ability: StringName, test: D20Test, events: Array[Dictionary]) -> D20Test:
	if ability == Ability.STRENGTH and unit.has_feature("feature.indomitable_might") and test.total < int(unit.scores.get(Ability.STRENGTH, 0)):
		test.total = int(unit.scores.get(Ability.STRENGTH, 0))
		test.success = test.total >= test.dc
	if test.success or unit.character == null:
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
	return result


static func _action(id: String, name: String, target: String, error: String) -> Dictionary:
	return {"id": id, "name": name, "target": target, "error": error}


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
		"brutal", "open_hand", "tactical_master":
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
					var save := m._roll_save(enemy, Ability.WISDOM, dc)
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
	return ""


## Passo Veloz: depois de outra ação bônus, Passo do Vento sem gastar ação bônus.
static func _mark_bonus_used(m: CombatManager, _action_id: String) -> void:
	m.once_per_turn.erase("fleet_step")


static func _adjacent_enemy(m: CombatManager, unit: Combatant) -> Combatant:
	for other in m.combatants:
		if other.is_up() and other.is_hostile_to(unit) and m._adjacent(other, unit):
			return other
	return null
