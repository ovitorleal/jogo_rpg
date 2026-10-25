extends "res://tests/base_test.gd"
## Fase 6.6 (entrega 4): características de Bardo (Conhecimento), Clérigo (Vida) e Druida (Terra).

const MARTIAL_TESTS := preload("res://tests/combat/test_martial_features.gd")

var _martial: Object


func _m() -> Object:
	if _martial == null:
		_martial = MARTIAL_TESTS.new()
		_martial.tree = tree
	return _martial


func _registry() -> ContentRegistry:
	return _m()._e()._registry()


func _at(class_id: String, level: int, options: Dictionary = {}) -> CharacterData:
	var c: CharacterData = _m()._at(class_id, level)
	for key: String in options:
		c.choices[key] = options[key]
	CharacterChoices.fill_defaults(c, _registry())
	Spellcasting.fill_defaults(c, _registry())
	return c


func _fight(c: CharacterData, dice: Array[int], enemies: int = 2) -> CombatManager:
	return _m()._fight(c, dice, enemies)


## Combate com dois personagens (o primeiro age antes): iniciativa 20 e 15 contra 1 dos goblins.
func _duo(first: CharacterData, second: CharacterData, dice: Array[int]) -> CombatManager:
	second.id = "character.ally"
	var manager := CombatManager.new()
	manager.registry = _registry()
	var party: Array[Combatant] = [Combatant.from_character(first, _registry()), Combatant.from_character(second, _registry())]
	var all_dice: Array[int] = []
	for unit in party:
		all_dice.append(20 if unit == party[0] else 15)
		if CombatFeatures.initiative_advantage(unit):
			all_dice.append(20 if unit == party[0] else 15)
	all_dice.append_array([1, 1] as Array[int])
	all_dice.append_array(dice)
	manager.setup(party, _m()._e()._goblins(2), Vector2i(12, 8), true, DiceRoller.scripted(all_dice))
	manager.start()
	return manager


func _hero(manager: CombatManager) -> Combatant:
	return manager.living(Combatant.Team.PARTY)[0]


func _enemy(manager: CombatManager, index: int = 0) -> Combatant:
	return manager.living(Combatant.Team.ENEMY)[index]


func _feature(manager: CombatManager, unit: Combatant, feature: String, target: Combatant = null) -> Dictionary:
	return manager.submit({"type": "feature", "actor": unit.id, "feature": feature, "target": target.id if target != null else ""})


func _attack(manager: CombatManager, unit: Combatant, target: Combatant, attack_id: String) -> Dictionary:
	return manager.submit({"type": "attack", "actor": unit.id, "target": target.id, "attack_id": attack_id})


func _events(result: Dictionary, type: String) -> Array:
	return result["events"].filter(func(e: Dictionary) -> bool: return e["type"] == type)


func _has_feature_event(events: Array, feature: String) -> bool:
	return events.any(func(e: Dictionary) -> bool: return e["type"] == "feature" and e["feature"] == feature)


func _wis(unit: Combatant) -> int:
	return int(unit.modifiers[Ability.WISDOM])


# --- Bardo ------------------------------------------------------------------------------------------

func test_bardic_inspiration_and_font() -> void:
	var bard := _at("class.bard", 5)
	var manager := _duo(bard, _at("class.fighter", 1), [5])
	var hero := _hero(manager)
	var ally: Combatant = manager.living(Combatant.Team.PARTY)[1]
	assert_true(not _feature(manager, hero, "bardic_inspiration", hero)["ok"], "Não inspira a si mesmo")
	var inspire := _feature(manager, hero, "bardic_inspiration", ally)
	assert_true(inspire["ok"], "Inspiração de Bardo: %s" % inspire["error"])
	assert_eq(str(ally.effects_of("inspired")[0]["value"]), "d8", "Dado d8 no nível 5")
	var events: Array[Dictionary] = []
	var roll := CombatFeatures._inspired_attack(manager, ally, {"natural": 10, "total": 12, "hit": false, "critical": false}, 15, events)
	assert_true(roll["hit"], "O dado (5) transforma o erro em acerto")
	assert_true(ally.effects_of("inspired").is_empty(), "O dado é gasto ao ser rolado")
	bard.resources_spent["bardic_inspiration"] = ClassFeatures.maximum(bard, _registry(), "bardic_inspiration")
	var font := _feature(manager, hero, "font_of_inspiration")
	assert_true(font["ok"], "Fonte de Inspiração: %s" % font["error"])
	assert_eq(ClassFeatures.remaining(bard, _registry(), "bardic_inspiration"), 1, "Espaço vira uma Inspiração")
	assert_eq(Spellcasting.slots_left(bard, _registry())[0], 3, "Gastou um espaço de 1º círculo")
	ClassFeatures.short_rest(bard, _registry())
	assert_eq(bard.resource_spent("bardic_inspiration"), 0, "Descanso curto recupera tudo (Fonte de Inspiração)")


func test_cutting_words_and_peerless_skill() -> void:
	var bard := _at("class.bard", 14)
	var hero_ac := Combatant.from_character(bard, _registry()).effective_ac()
	var manager := _fight(bard, [hero_ac - 4, 1, 5])
	var hero := _hero(manager)
	var goblin := _enemy(manager)
	goblin.position = hero.position + Vector2i(1, 0)
	var events: Array[Dictionary] = []
	var roll := manager._resolve_weapon_attack(goblin, hero, goblin.attacks[0], events, false)
	assert_true(_has_feature_event(events, "cutting_words"), "Palavras Cortantes na reação")
	assert_true(not roll["hit"], "O dado faz o goblin errar")
	assert_true(not hero.reaction_available, "Gastou a reação")
	var spent := bard.resource_spent("bardic_inspiration")
	var miss := CombatFeatures._inspired_attack(manager, hero, {"natural": 9, "total": 12, "hit": false, "critical": false}, 15, events)
	assert_true(miss["hit"], "Perícia Inigualável: +5 vira acerto")
	assert_eq(bard.resource_spent("bardic_inspiration"), spent + 1, "Gasta a Inspiração porque deu certo")


func test_countercharm_and_superior_inspiration() -> void:
	var bard := _at("class.bard", 18)
	bard.resources_spent["bardic_inspiration"] = ClassFeatures.maximum(bard, _registry(), "bardic_inspiration")
	var manager := _duo(bard, _at("class.fighter", 1), [1, 20, 20])
	var hero := _hero(manager)
	var ally: Combatant = manager.living(Combatant.Team.PARTY)[1]
	assert_eq(ClassFeatures.remaining(bard, _registry(), "bardic_inspiration"), 2, "Inspiração Superior: volta a 2 na iniciativa")
	ally.position = hero.position + Vector2i(0, 1)
	var save := manager._roll_save(ally, Ability.WISDOM, 15, "frightened")
	assert_true(save.success, "Contraencanto refaz com vantagem")
	assert_true(not hero.reaction_available, "Usa a reação do bardo")


func test_magical_secrets_and_discoveries() -> void:
	var lore := _at("class.bard", 6)
	var discoveries := CharacterChoices.magical_discoveries(lore)
	assert_eq(discoveries.size(), 2, "Duas Descobertas Mágicas")
	for id in discoveries:
		assert_true(id in Spellcasting.always_prepared_ids(lore, _registry()), "%s sempre preparada" % id)
		assert_true(not "class.bard" in _registry().get_entry("spell", id)["classes"], "%s vem de outra lista" % id)
	var secrets := _at("class.bard", 10)
	assert_true("spell.guiding_bolt" in Spellcasting.preparable_spells(secrets, _registry()), "Segredos Mágicos: lista de clérigo")
	assert_true(Spellcasting.validate(secrets, _registry()).is_empty(), "Magias do bardo 10 válidas")


# --- Clérigo ----------------------------------------------------------------------------------------

func test_divine_order_training_and_thaumaturge() -> void:
	var protector := _at("class.cleric", 1, {"option.feature.divine_order": ["divine_order.protector"]})
	var sheet := CharacterSheet.build(protector, _registry())
	assert_true("martial" in sheet.weapon_training and "heavy" in sheet.armor_training, "Protetor: armas marciais e armadura pesada")
	var thaumaturge := _at("class.cleric", 1, {"option.feature.divine_order": ["divine_order.thaumaturge"]})
	var plain := CharacterSheet.build(protector, _registry())
	var learned := CharacterSheet.build(thaumaturge, _registry())
	assert_eq(learned.skill_bonus(&"religion") - plain.skill_bonus(&"religion"), maxi(1, learned.modifiers[Ability.WISDOM]),
			"Taumaturgo soma a Sabedoria em Religião")
	assert_true(not "martial" in learned.weapon_training, "Taumaturgo não ganha armas marciais")


func test_divine_spark_and_turn_undead() -> void:
	var cleric := _at("class.cleric", 7)
	var manager := _fight(cleric, [4, 4, 1, 4, 4, 1, 1, 1, 1, 1, 1])
	var hero := _hero(manager)
	var goblin := _enemy(manager)
	var wolf := _enemy(manager, 1)
	goblin.position = hero.position + Vector2i(2, 0)
	wolf.position = hero.position + Vector2i(0, 2)
	hero.hp -= 20
	var before := hero.hp
	var heal := _feature(manager, hero, "divine_spark_heal", hero)
	assert_true(heal["ok"], "Centelha Divina (cura): %s" % heal["error"])
	assert_eq(hero.hp - before, 8 + _wis(hero), "2d8 + Sabedoria no nível 7")
	manager.action_available = true
	goblin.hp = 40
	var harm := _feature(manager, hero, "divine_spark_harm", goblin)
	assert_true(harm["ok"], "Centelha Divina (dano): %s" % harm["error"])
	assert_eq(goblin.hp, 40 - (8 + _wis(hero)), "Falhou na Constituição: dano inteiro")
	manager.action_available = true
	wolf.creature_type = "morto-vivo"
	var turn := _feature(manager, hero, "turn_undead")
	assert_true(turn["ok"], "Expulsar Mortos-Vivos: %s" % turn["error"])
	assert_true(_has_feature_event(turn["events"], "sear_undead"), "Queimar Mortos-Vivos")
	assert_true(wolf.has_condition("frightened") and wolf.has_condition("incapacitated"), "Amedrontado e Incapacitado")
	assert_eq(cleric.resource_spent("channel_divinity"), 3, "Três usos de Canalizar Divindade")


func test_life_domain_healing() -> void:
	var cleric := _at("class.cleric", 6)
	var manager := _duo(cleric, _at("class.fighter", 1), [4, 4])
	var hero := _hero(manager)
	var ally: Combatant = manager.living(Combatant.Team.PARTY)[1]
	ally.position = hero.position + Vector2i(0, 1)
	ally.hp = 1
	hero.hp -= 5
	var cast := manager.submit({"type": "cast", "actor": hero.id, "spell_id": "spell.cure_wounds", "target": ally.id})
	assert_true(cast["ok"], "Curar Ferimentos: %s" % cast["error"])
	assert_eq(ally.hp, mini(ally.max_hp, 1 + 8 + _wis(hero) + 3), "Discípulo da Vida: +2 + círculo")
	assert_true(_has_feature_event(cast["events"], "blessed_healer"), "Curandeiro Abençoado cura o clérigo")
	var supreme := _at("class.cleric", 17)
	var second := _fight(supreme, [])
	var unit := _hero(second)
	unit.hp = 1
	second.submit({"type": "cast", "actor": unit.id, "spell_id": "spell.cure_wounds", "target": unit.id})
	assert_eq(unit.hp, mini(unit.max_hp, 1 + 16 + _wis(unit) + 3), "Cura Suprema: dados no máximo")
	var preserve := _at("class.cleric", 3)
	var third := _fight(preserve, [])
	var healer := _hero(third)
	healer.hp = 1
	assert_true(_feature(third, healer, "preserve_life")["ok"], "Preservar a Vida")
	@warning_ignore("integer_division")
	assert_eq(healer.hp, mini(healer.max_hp / 2, 1 + 15), "Até metade dos PV máximos")


func test_blessed_strikes_and_divine_intervention() -> void:
	var cleric := _at("class.cleric", 7, {"option.feature.blessed_strikes": ["blessed_strikes.divine_strike"]})
	var manager := _fight(cleric, [18, 3, 5])
	var hero := _hero(manager)
	var goblin := _enemy(manager)
	goblin.position = hero.position + Vector2i(1, 0)
	goblin.hp = 40
	var event: Dictionary = _events(_attack(manager, hero, goblin, "item.mace"), "attack")[0]
	assert_true("Golpe Divino +5" in str(event["features"]), "Golpe Divino do clérigo: %s" % event["features"])
	var potent := _at("class.cleric", 14, {"option.feature.blessed_strikes": ["blessed_strikes.potent_spellcasting"]})
	var second := _fight(potent, [])
	var unit := _hero(second)
	assert_eq(CombatFeatures.cantrip_bonus(unit, unit.get_spell("spell.sacred_flame")), _wis(unit), "Conjuração Potente: +Sabedoria")
	var events: Array[Dictionary] = []
	CombatFeatures.after_spell_damage(second, unit, unit.get_spell("spell.sacred_flame"), events)
	assert_eq(unit.temp_hp, 2 * _wis(unit), "Aprimorado: PV temporários iguais ao dobro da Sabedoria")
	var intervention := _at("class.cleric", 10)
	for i in 5:
		intervention.spell_slots_spent.append(9)
	var third := _fight(intervention, [])
	var healer := _hero(third)
	healer.hp = 1
	var cast := third.submit({"type": "cast", "actor": healer.id, "spell_id": "intervention:spell.cure_wounds", "target": healer.id})
	assert_true(cast["ok"], "Intervenção Divina sem espaços: %s" % cast["error"])
	assert_eq(intervention.resource_spent("divine_intervention"), 1, "Uma vez por descanso longo")
	assert_true(not third.action_available, "É uma ação de Magia")
	assert_true(not third.spell_error(healer, "intervention:spell.bless").is_empty(), "Não repete")


# --- Druida -----------------------------------------------------------------------------------------

func test_wild_shape_form_and_revert() -> void:
	var druid := _at("class.druid", 2)
	var forms := CharacterChoices.wild_shape_forms(druid)
	assert_eq(forms.size(), 4, "Quatro formas conhecidas no nível 2")
	assert_true("monster.wolf" in forms and not "monster.black_bear" in forms, "Só ND 1/4 no nível 2")
	var manager := _fight(druid, [])
	var hero := _hero(manager)
	var ac := hero.effective_ac()
	var shape := _feature(manager, hero, "wild_shape:monster.wolf")
	assert_true(shape["ok"], "Forma Selvagem: %s" % shape["error"])
	assert_eq(hero.armor_class, 12, "CA do lobo")
	assert_true(not hero.get_attack("attack.wolf_bite").is_empty(), "Ataca com a mordida")
	assert_true(hero.has_trait("trait.pack_tactics"), "Traços da fera")
	assert_eq(hero.temp_hp, 2, "PV temporários iguais ao nível")
	assert_true(not manager.spell_error(hero, "spell.cure_wounds").is_empty(), "Sem conjurar em Forma Selvagem")
	manager.bonus_action_available = true
	assert_true(_feature(manager, hero, "end_wild_shape")["ok"], "Sai da forma")
	assert_eq(hero.effective_ac(), ac, "Volta à CA normal")
	assert_true(hero.get_attack("attack.wolf_bite").is_empty(), "Volta às próprias armas")
	var bear := _at("class.druid", 4)
	bear.choices["wild_shape.feature.wild_shape"] = ["monster.black_bear"]
	var second := _fight(bear, [])
	var unit := _hero(second)
	_feature(second, unit, "wild_shape:monster.black_bear")
	assert_eq(second.attacks_per_action(unit), 2, "Ataques Múltiplos do urso")
	var events: Array[Dictionary] = []
	second.add_condition(unit, "stunned", unit.id, events)
	assert_true(not CombatFeatures.in_wild_shape(unit), "Incapacitado encerra a forma")


func test_primal_strike_resurgence_and_archdruid() -> void:
	var druid := _at("class.druid", 7, {"option.feature.elemental_fury": ["elemental_fury.primal_strike"]})
	var manager := _fight(druid, [18, 3, 5])
	var hero := _hero(manager)
	var goblin := _enemy(manager)
	goblin.position = hero.position + Vector2i(1, 0)
	goblin.hp = 40
	_feature(manager, hero, "wild_shape:monster.wolf")
	var event: Dictionary = _events(_attack(manager, hero, goblin, "attack.wolf_bite"), "attack")[0]
	assert_true("Golpe Primal +5" in str(event["features"]), "Golpe Primal na forma de fera: %s" % event["features"])
	druid.resources_spent["wild_shape"] = ClassFeatures.maximum(druid, _registry(), "wild_shape")
	var gain := _feature(manager, hero, "resurgence_gain")
	assert_true(gain["ok"], "Ressurgimento Selvagem: %s" % gain["error"])
	assert_eq(ClassFeatures.remaining(druid, _registry(), "wild_shape"), 1, "Espaço vira Forma Selvagem")
	var slot := _feature(manager, hero, "resurgence_slot")
	assert_true(slot["ok"], "Forma Selvagem vira espaço: %s" % slot["error"])
	assert_eq(druid.spell_slots_spent[0], 0, "Recupera o espaço de 1º círculo")
	var arch := _at("class.druid", 20)
	arch.resources_spent["wild_shape"] = ClassFeatures.maximum(arch, _registry(), "wild_shape")
	_fight(arch, [])
	assert_eq(ClassFeatures.remaining(arch, _registry(), "wild_shape"), 1, "Arquidruida: recupera um uso na iniciativa")


func test_circle_of_the_land() -> void:
	var druid := _at("class.druid", 10, {"option.feature.land_type": ["land.arid"]})
	var always := Spellcasting.always_prepared_ids(druid, _registry())
	assert_true("spell.burning_hands" in always and "spell.fire_bolt" in always, "Magias da terra árida")
	var manager := _fight(druid, [1, 3, 3, 3])
	var hero := _hero(manager)
	assert_true("poisoned" in hero.condition_immunities and "fire" in hero.resistances, "Proteção da Natureza (árida: fogo)")
	assert_true(manager._free_cast_available(hero, hero.get_spell("spell.burning_hands")), "Recuperação Natural: magia do Círculo sem espaço")
	var goblin := _enemy(manager)
	goblin.position = hero.position + Vector2i(3, 0)
	goblin.hp = 40
	var aid := _feature(manager, hero, "lands_aid", goblin)
	assert_true(aid["ok"], "Auxílio da Terra: %s" % aid["error"])
	assert_eq(goblin.hp, 40 - 9, "3d6 necrótico com falha no nível 10")
	var rested := _at("class.druid", 6)
	rested.spell_slots_spent.assign([2, 1])
	ClassFeatures.short_rest(rested, _registry())
	assert_eq(Array(rested.spell_slots_spent), [1, 0], "Recuperação Natural: 3 círculos (um de 2º e um de 1º)")
	var sanctuary := _at("class.druid", 14)
	var second := _fight(sanctuary, [])
	var unit := _hero(second)
	var ac := unit.effective_ac()
	assert_true(_feature(second, unit, "natures_sanctuary")["ok"], "Santuário da Natureza")
	assert_eq(unit.effective_ac(), ac + 2, "Meia cobertura no cubo")


func test_new_spells_and_beast_traits() -> void:
	var wizard := _at("class.wizard", 1)
	wizard.cantrips.assign(["spell.shocking_grasp"])
	wizard.prepared_spells.assign(["spell.ray_of_sickness"])
	var manager := _fight(wizard, [18, 3, 18, 4, 4])
	var hero := _hero(manager)
	var goblin := _enemy(manager)
	goblin.position = hero.position + Vector2i(1, 0)
	goblin.hp = 40
	manager.submit({"type": "cast", "actor": hero.id, "spell_id": "spell.shocking_grasp", "target": goblin.id})
	assert_true(not manager._can_opportunity_attack(goblin, hero, hero.position + Vector2i(-1, 0)), "Toque Chocante: sem ataque de oportunidade")
	manager.action_available = true
	goblin.position = hero.position + Vector2i(4, 0)
	var ray := manager.submit({"type": "cast", "actor": hero.id, "spell_id": "spell.ray_of_sickness", "target": goblin.id})
	assert_true(ray["ok"], "Raio Nauseante conjurado: %s" % ray["error"])
	assert_true(goblin.has_condition("poisoned"), "Raio Nauseante: Envenenado")
	var druid := _at("class.druid", 2)
	druid.choices["wild_shape.feature.wild_shape"] = ["monster.rat"]
	var second := _fight(druid, [])
	var unit := _hero(second)
	var enemy := _enemy(second)
	enemy.position = unit.position + Vector2i(1, 0)
	_feature(second, unit, "wild_shape:monster.rat")
	assert_true(not second._can_opportunity_attack(enemy, unit, unit.position + Vector2i(-1, 0)), "Rato Ágil: sem ataque de oportunidade")
