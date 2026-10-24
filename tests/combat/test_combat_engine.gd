extends "res://tests/base_test.gd"
## Fase 6.6 (entrega 1): ação de Ataque com Ataque Extra, ações padrão, ataque de oportunidade,
## condições, Maestria em Armas, ataque extra Leve, Agarrar/Empurrar, PV temporários e talentos de combate.

var registry: ContentRegistry


func _registry() -> ContentRegistry:
	if registry == null:
		registry = ContentRegistry.new()
		registry.load_all()
	return registry


## Personagem humano de nível 1 com o arranjo sugerido; antecedente e escolhas opcionais.
func _hero(class_id: String, background_id: String = "background.criminal", picks: Dictionary = {}) -> CharacterData:
	var reg := _registry()
	var class_entry := reg.get_entry("class", class_id)
	var background := reg.get_entry("background", background_id)
	var blocked: Array = background["skill_proficiencies"].duplicate()
	var class_skills: Array[StringName] = []
	for skill: Variant in class_entry["skill_options"]:
		if class_skills.size() < int(class_entry["skill_choice_count"]) and not skill in blocked:
			class_skills.append(StringName(skill))
	var species_skills: Array[StringName] = []
	for skill in CharacterFactory.species_skill_options(reg.get_entry("species", "species.human")):
		if species_skills.is_empty() and not skill in class_skills and not String(skill) in blocked:
			species_skills.append(skill)
	var expertise: Array[StringName] = []
	for skill in class_skills:
		if expertise.size() < int(class_entry["expertise_choices"]):
			expertise.append(skill)
	var scores := {}
	for i in Ability.ALL.size():
		scores[Ability.ALL[i]] = int(class_entry["suggested_scores"][i])
	var options: Array = background["ability_options"]
	var result := CharacterFactory.create({
		"name": "Teo", "species_id": "species.human", "class_id": class_id, "background_id": background_id,
		"ability_method": "standard_array", "base_scores": scores,
		"background_increases": {StringName(options[0]): 2, StringName(options[1]): 1},
		"class_skills": class_skills, "species_skills": species_skills, "expertise": expertise, "choices": picks,
	}, reg)
	assert_true(result[0] != null, "Personagem %s válido: %s" % [class_id, str(result[1])])
	return result[0]


func _monster(monster_id: String, index: int = 1, total: int = 1) -> Combatant:
	return Combatant.from_monster(_registry().get_entry("monster", monster_id), index, total)


func _combat(c: CharacterData, enemies: Array[Combatant], dice: Array[int]) -> CombatManager:
	var manager := CombatManager.new()
	manager.registry = _registry()
	var party: Array[Combatant] = [Combatant.from_character(c, _registry())]
	# Vantagem na iniciativa (Instinto Feral, Atleta Notável) rola dois d20.
	var all_dice: Array[int] = [20]
	if CombatFeatures.initiative_advantage(party[0]):
		all_dice.append(20)
	for e in enemies:
		all_dice.append(1)
	all_dice.append_array(dice)
	manager.setup(party, enemies, Vector2i(12, 8), true, DiceRoller.scripted(all_dice))
	manager.start()
	return manager


func _hero_unit(manager: CombatManager) -> Combatant:
	return manager.living(Combatant.Team.PARTY)[0]


func _events(result: Dictionary, type: String) -> Array:
	return result["events"].filter(func(e: Dictionary) -> bool: return e["type"] == type)


func _goblins(count: int) -> Array[Combatant]:
	var result: Array[Combatant] = []
	for i in count:
		result.append(_monster("monster.goblin_warrior", i + 1, count))
	return result


func test_extra_attack_gives_two_attacks_per_action() -> void:
	var fighter := _hero("class.fighter")
	for i in 4:
		Progression.level_up(fighter, _registry())
	var manager := _combat(fighter, _goblins(2), [15, 2, 15, 2])
	var hero := _hero_unit(manager)
	assert_eq(manager.attacks_per_action(hero), 2, "Nível 5: Ataque Extra")
	var goblin: Combatant = manager.living(Combatant.Team.ENEMY)[0]
	goblin.position = hero.position + Vector2i(1, 0)
	var first := manager.submit({"type": "attack", "actor": hero.id, "target": goblin.id, "attack_id": "item.longsword"})
	assert_true(first["ok"], "Primeiro ataque: %s" % first["error"])
	assert_eq([manager.action_available, manager.attacks_left], [false, 1], "Ação usada, um ataque restante")
	var second := manager.submit({"type": "attack", "actor": hero.id, "target": goblin.id, "attack_id": "item.longsword"})
	assert_true(second["ok"], "Segundo ataque: %s" % second["error"])
	var third := manager.submit({"type": "attack", "actor": hero.id, "target": goblin.id, "attack_id": "item.longsword"})
	assert_true(not third["ok"], "Sem terceiro ataque")


func test_opportunity_attack_and_disengage() -> void:
	var manager := _combat(_hero("class.fighter"), _goblins(1), [2, 2])
	var hero := _hero_unit(manager)
	var goblin: Combatant = manager.living(Combatant.Team.ENEMY)[0]
	goblin.position = hero.position + Vector2i(1, 0)
	var away := hero.position + Vector2i(-1, 0)
	var result := manager.submit({"type": "move", "actor": hero.id, "to": away})
	assert_true(result["ok"], "Movimento: %s" % result["error"])
	assert_eq(_events(result, "opportunity").size(), 1, "Sair do alcance provoca ataque de oportunidade")
	assert_true(not goblin.reaction_available, "Goblin gastou a reação")
	assert_eq(hero.position, away, "Herói chega ao destino (o ataque errou)")

	var second := _combat(_hero("class.fighter"), _goblins(1), [])
	hero = _hero_unit(second)
	goblin = second.living(Combatant.Team.ENEMY)[0]
	goblin.position = hero.position + Vector2i(1, 0)
	assert_true(second.submit({"type": "disengage", "actor": hero.id})["ok"], "Desengajar")
	result = second.submit({"type": "move", "actor": hero.id, "to": hero.position + Vector2i(-1, 0)})
	assert_eq(_events(result, "opportunity").size(), 0, "Depois de Desengajar, sem ataque de oportunidade")


func test_dash_and_dodge() -> void:
	var manager := _combat(_hero("class.fighter"), _goblins(1), [])
	var hero := _hero_unit(manager)
	var speed := manager.movement_left_feet
	assert_true(manager.submit({"type": "dash", "actor": hero.id})["ok"], "Disparada")
	assert_eq(manager.movement_left_feet, speed * 2, "Disparada dobra o movimento")
	assert_true(not manager.submit({"type": "dodge", "actor": hero.id})["ok"], "Ação já usada")
	var other := _combat(_hero("class.fighter"), _goblins(1), [])
	hero = _hero_unit(other)
	assert_true(other.submit({"type": "dodge", "actor": hero.id})["ok"], "Esquivar")
	var goblin: Combatant = other.living(Combatant.Team.ENEMY)[0]
	assert_true("alvo se esquivando" in other.attack_advantage(goblin, hero, goblin.attacks[0])["disadvantage"],
			"Ataques contra quem se esquiva têm desvantagem")
	assert_true(not other.submit({"type": "dash", "actor": hero.id, "bonus": true})["ok"], "Guerreiro não tem Ação Astuta")


func test_conditions_prone_and_grapple() -> void:
	var manager := _combat(_hero("class.fighter"), _goblins(1), [1, 1])
	var hero := _hero_unit(manager)
	var goblin: Combatant = manager.living(Combatant.Team.ENEMY)[0]
	var events: Array[Dictionary] = []
	manager.add_condition(goblin, "prone", hero.id, events)
	goblin.position = hero.position + Vector2i(1, 0)
	var melee := hero.get_attack("item.longsword")
	assert_true("alvo caído" in manager.attack_advantage(hero, goblin, melee)["advantage"], "Caído: vantagem corpo a corpo")
	goblin.position = hero.position + Vector2i(5, 0)
	var ranged := {"attack_type": "ranged", "range_normal": 80, "properties": []}
	assert_true("alvo caído à distância" in manager.attack_advantage(hero, goblin, ranged)["disadvantage"], "Caído: desvantagem à distância")
	goblin.position = hero.position + Vector2i(1, 0)
	var grab := manager.submit({"type": "attack", "actor": hero.id, "target": goblin.id, "attack_id": "attack.unarmed_grapple"})
	assert_true(grab["ok"], "Agarrar: %s" % grab["error"])
	assert_true(goblin.has_condition("grappled"), "Goblin falhou e está agarrado")
	assert_eq(manager.effective_speed(goblin), 0, "Agarrado: deslocamento 0")
	manager.submit({"type": "end_turn", "actor": hero.id})
	assert_true(goblin.has_condition("prone"), "Agarrado (deslocamento 0) não consegue se levantar")
	var free := _combat(_hero("class.fighter"), _goblins(1), [])
	var standing: Combatant = free.living(Combatant.Team.ENEMY)[0]
	free.add_condition(standing, "prone", _hero_unit(free).id, events)
	free.submit({"type": "end_turn", "actor": _hero_unit(free).id})
	assert_true(not standing.has_condition("prone"), "No próprio turno o goblin se levanta (gasta metade do movimento)")


func test_weapon_masteries() -> void:
	var manager := _combat(_hero("class.fighter"), _goblins(2), [1])
	var hero := _hero_unit(manager)
	var goblin: Combatant = manager.living(Combatant.Team.ENEMY)[0]
	var other: Combatant = manager.living(Combatant.Team.ENEMY)[1]
	goblin.position = hero.position + Vector2i(1, 0)
	other.position = hero.position + Vector2i(3, 3)
	var attack := hero.get_attack("item.longsword").duplicate()
	hero.masteries = ["item.longsword"]
	var events: Array[Dictionary] = []
	attack["mastery"] = "sap"
	manager._apply_mastery_on_hit(hero, goblin, attack, 5, events)
	assert_true("enfraquecido" in manager.attack_advantage(goblin, hero, goblin.attacks[0])["disadvantage"], "Enfraquecer")
	attack["mastery"] = "slow"
	var speed := manager.effective_speed(goblin)
	manager._apply_mastery_on_hit(hero, goblin, attack, 5, events)
	assert_eq(manager.effective_speed(goblin), speed - 10, "Lentidão: -3 m")
	attack["mastery"] = "vex"
	manager._apply_mastery_on_hit(hero, goblin, attack, 5, events)
	assert_true("atormentar" in manager.attack_advantage(hero, goblin, attack)["advantage"], "Atormentar")
	attack["mastery"] = "topple"
	manager._apply_mastery_on_hit(hero, goblin, attack, 5, events)
	assert_true(goblin.has_condition("prone"), "Derrubar: falhou na Constituição (1) e caiu")
	attack["mastery"] = "push"
	var before := goblin.position
	manager._apply_mastery_on_hit(hero, goblin, attack, 5, events)
	assert_eq(goblin.position, before + Vector2i(2, 0), "Empurrar: 3 m")
	hero.masteries = []
	var unmastered := goblin.position
	manager._apply_mastery_on_hit(hero, goblin, attack, 5, events)
	assert_eq(goblin.position, unmastered, "Sem a maestria escolhida, nada acontece")


func test_graze_and_cleave() -> void:
	var fighter := _hero("class.fighter")
	fighter.weapon_ids.assign(["item.greataxe"])
	fighter.shield_id = ""
	fighter.choices["weapon_mastery"] = ["item.greataxe", "item.longsword", "item.handaxe"]
	var manager := _combat(fighter, _goblins(2), [15, 6, 15, 4])
	var hero := _hero_unit(manager)
	var goblin: Combatant = manager.living(Combatant.Team.ENEMY)[0]
	var other: Combatant = manager.living(Combatant.Team.ENEMY)[1]
	goblin.position = hero.position + Vector2i(1, 0)
	other.position = hero.position + Vector2i(1, 1)
	var result := manager.submit({"type": "attack", "actor": hero.id, "target": goblin.id, "attack_id": "item.greataxe"})
	assert_true(result["ok"], "Machado Grande: %s" % result["error"])
	var cleave: Array = _events(result, "mastery").filter(func(e: Dictionary) -> bool: return e["mastery"] == "cleave")
	assert_eq(cleave.size(), 1, "Trespassar atinge o segundo goblin")
	assert_eq(other.hp, other.max_hp - 4, "Segundo golpe sem o modificador de Força")


func test_light_weapon_extra_attack_and_nick() -> void:
	var rogue := _hero("class.rogue", "background.criminal", {"weapon_mastery": ["item.dagger", "item.shortsword"]})
	# Atormentar (espada curta) dá vantagem ao ataque seguinte: dois d20.
	var manager := _combat(rogue, _goblins(2), [15, 3, 15, 15, 3, 4])
	var hero := _hero_unit(manager)
	var goblin: Combatant = manager.living(Combatant.Team.ENEMY)[0]
	goblin.position = hero.position + Vector2i(1, 0)
	assert_true(not manager.offhand_error(hero).is_empty(), "Sem ataque Leve ainda, sem ataque extra")
	manager.submit({"type": "attack", "actor": hero.id, "target": goblin.id, "attack_id": "item.shortsword"})
	assert_true(manager.offhand_error(hero).is_empty(), "Depois da espada curta, ataque extra com a adaga")
	var extra := manager.submit({"type": "offhand", "actor": hero.id, "target": goblin.id})
	assert_true(extra["ok"], "Ataque extra: %s" % extra["error"])
	assert_true(manager.bonus_action_available, "Talhar (adaga): o ataque extra não gasta a ação bônus")
	var event: Dictionary = _events(extra, "attack")[0]
	assert_eq(event["damage"], 3 + 4, "Ataque extra sem o modificador (3) + Ataque Furtivo com vantagem (4)")
	assert_true(str(event["features"]).contains("Ataque Furtivo"), "Ataque Furtivo registrado")


func test_temp_hp_and_combat_feats() -> void:
	var soldier := _hero("class.fighter", "background.soldier")
	var manager := _combat(soldier, _goblins(2), [15, 1, 8])
	var hero := _hero_unit(manager)
	var goblin: Combatant = manager.living(Combatant.Team.ENEMY)[0]
	goblin.position = hero.position + Vector2i(1, 0)
	var result := manager.submit({"type": "attack", "actor": hero.id, "target": goblin.id, "attack_id": "item.longsword"})
	var damage: int = _events(result, "attack")[0]["damage"]
	assert_eq(damage, 8 + hero.modifiers[Ability.STRENGTH], "Atacante Selvagem: rola duas vezes e fica com 8")
	hero.temp_hp = 5
	var events: Array[Dictionary] = []
	var hp := hero.hp
	manager._apply_damage(hero, 7, events, {"type": "test"})
	assert_eq([hero.temp_hp, hero.hp], [0, hp - 2], "PV temporários absorvem primeiro")
	var alert := Combatant.from_character(_hero("class.fighter", "background.criminal"), _registry())
	var sheet := CharacterSheet.build(_hero("class.fighter", "background.criminal"), _registry())
	assert_eq(alert.initiative_bonus, sheet.modifiers[Ability.DEXTERITY] + sheet.proficiency_bonus, "Alerta: proficiência na iniciativa")
	var archer := _hero("class.fighter", "background.criminal", {"fighting_style.feature.fighting_style": ["feat.archery"]})
	archer.weapon_ids.assign(["item.longbow"])
	var bow := Combatant.from_character(archer, _registry()).get_attack("item.longbow")
	var plain := Attack.weapon_attacks(CharacterSheet.build(archer, _registry()), _registry().get_entry("item", "item.longbow"))[0]
	assert_eq(int(bow["attack_bonus"]), int(plain["attack_bonus"]) + 2, "Arquearia: +2 à distância")
	var defender := _hero("class.fighter", "background.criminal", {"fighting_style.feature.fighting_style": ["feat.defense"]})
	var other := _hero("class.fighter", "background.criminal", {"fighting_style.feature.fighting_style": ["feat.archery"]})
	assert_eq(CharacterSheet.build(defender, _registry()).armor_class, CharacterSheet.build(other, _registry()).armor_class + 1,
			"Defesa: +1 na CA com armadura")
