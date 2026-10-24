extends "res://tests/base_test.gd"
## Fase 6.5: tabelas de conjuração, escolhas de magia, conjuração em combate (ataque mágico,
## resistência, dano automático, área, cura, efeitos e concentração), descansos e cena.

const SCENE := "res://scenes/combat/combat_scene.tscn"

var registry: ContentRegistry


func _registry() -> ContentRegistry:
	if registry == null:
		registry = ContentRegistry.new()
		registry.load_all()
	return registry


## Conjurador humano de nível 1 com o arranjo sugerido da classe e o antecedente Criminoso.
func _caster(class_id: String, extra: Dictionary = {}) -> CharacterData:
	var reg := _registry()
	var class_entry := reg.get_entry("class", class_id)
	var background := reg.get_entry("background", "background.criminal")
	var blocked: Array = background["skill_proficiencies"].duplicate()
	var class_skills: Array[StringName] = []
	for skill: Variant in class_entry["skill_options"]:
		if class_skills.size() < int(class_entry["skill_choice_count"]) and not skill in blocked:
			class_skills.append(StringName(skill))
	var species_skills: Array[StringName] = []
	for skill in CharacterFactory.species_skill_options(reg.get_entry("species", "species.human")):
		if species_skills.is_empty() and not skill in class_skills and not String(skill) in blocked:
			species_skills.append(skill)
	var suggested: Array = class_entry["suggested_scores"]
	var scores := {}
	for i in Ability.ALL.size():
		scores[Ability.ALL[i]] = int(suggested[i])
	var choices := {
		"name": "Lia", "species_id": "species.human", "class_id": class_id, "background_id": "background.criminal",
		"ability_method": "standard_array", "base_scores": scores, "background_increases": {&"dex": 2, &"con": 1},
		"class_skills": class_skills, "species_skills": species_skills, "expertise": [],
	}
	choices.merge(extra, true)
	var result := CharacterFactory.create(choices, reg)
	assert_true(result[0] != null, "Conjurador %s válido: %s" % [class_id, str(result[1])])
	return result[0]


func _monster(monster_id: String, index: int = 1, total: int = 1) -> Combatant:
	return Combatant.from_monster(_registry().get_entry("monster", monster_id), index, total)


## Combate com o conjurador agindo primeiro (iniciativa roteirizada 20 contra 1 para cada inimigo).
func _combat(c: CharacterData, enemies: Array[Combatant], dice: Array[int]) -> CombatManager:
	var manager := CombatManager.new()
	manager.registry = _registry()
	var party: Array[Combatant] = [Combatant.from_character(c, _registry())]
	var all_dice: Array[int] = [20]
	for e in enemies:
		all_dice.append(1)
	all_dice.append_array(dice)
	manager.setup(party, enemies, Vector2i(12, 8), true, DiceRoller.scripted(all_dice))
	manager.start()
	return manager


func _hero(manager: CombatManager) -> Combatant:
	return manager.living(Combatant.Team.PARTY)[0]


func _events_of(result: Dictionary, type: String) -> Array:
	return result["events"].filter(func(e: Dictionary) -> bool: return e["type"] == type)


func test_slot_tables_and_dice_scaling() -> void:
	var reg := _registry()
	var wizard := reg.get_entry("class", "class.wizard")
	assert_eq(Spellcasting.slots_for(wizard, 1), [2] as Array[int], "Mago nível 1: dois espaços de 1º círculo")
	assert_eq(Spellcasting.slots_for(wizard, 3), [4, 2] as Array[int], "Mago nível 3: 4 de 1º e 2 de 2º")
	assert_eq(Spellcasting.slots_for(reg.get_entry("class", "class.paladin"), 1), [2] as Array[int], "Paladino conjura desde o nível 1 (2024)")
	assert_eq(Spellcasting.slots_for(reg.get_entry("class", "class.warlock"), 1), [1] as Array[int], "Bruxo: um espaço de pacto")
	assert_eq(Spellcasting.slots_for(reg.get_entry("class", "class.warlock"), 3), [0, 2] as Array[int], "Pacto: espaços no mesmo círculo")
	assert_eq(Spellcasting.slots_for(reg.get_entry("class", "class.fighter"), 5), [] as Array[int], "Guerreiro não conjura")
	assert_eq([Spellcasting.cantrip_multiplier(1), Spellcasting.cantrip_multiplier(5), Spellcasting.cantrip_multiplier(17)],
			[1, 2, 4], "Truques escalam nos níveis 5, 11 e 17")
	var missile := reg.get_entry("spell", "spell.burning_hands")
	assert_eq(str(Spellcasting.scaled_dice(missile, "3d6", 1, 2)), "4d6", "Mãos Flamejantes em 2º círculo: +1d6")
	assert_true(reg.errors.is_empty(), "Magias e tabelas de conjuração válidas: %s" % str(reg.errors))


func test_defaults_and_validation() -> void:
	var wizard := _caster("class.wizard")
	assert_eq(wizard.cantrips.size(), 3, "Mago começa com 3 truques")
	assert_true("spell.fire_bolt" in wizard.cantrips, "Raio de Fogo entre os truques")
	assert_eq(wizard.prepared_spells.size(), 3, "Preparadas limitadas às 3 magias de mago existentes")
	var combatant := Combatant.from_character(wizard, _registry())
	var sheet := CharacterSheet.build(wizard, _registry())
	assert_eq(combatant.spell_dc, 8 + sheet.modifiers[Ability.INTELLIGENCE] + sheet.proficiency_bonus, "CD = 8 + INT + proficiência")
	assert_eq(combatant.spell_attack, sheet.modifiers[Ability.INTELLIGENCE] + sheet.proficiency_bonus, "Ataque mágico = INT + proficiência")
	var wrong := _caster("class.wizard")
	wrong.prepared_spells.append("spell.cure_wounds")
	assert_true(not Spellcasting.validate(wrong, _registry()).is_empty(), "Curar Ferimentos não é magia de mago")
	var chosen := CharacterFactory.create({"name": "X"}, _registry())
	assert_true(chosen[0] == null, "Escolhas incompletas continuam inválidas")
	var fighter_fixture: Object = load("res://tests/characters/test_character_factory.gd").new()
	var fighter: CharacterData = CharacterFactory.create(fighter_fixture.fighter_choices(), _registry())[0]
	assert_eq([fighter.cantrips.size(), fighter.prepared_spells.size()], [0, 0], "Guerreiro sem magias")
	var data := wizard.to_dict()
	var loaded: CharacterData = CharacterData.from_dict(JSON.parse_string(JSON.stringify(data)))[0]
	assert_eq([loaded.cantrips, loaded.prepared_spells], [wizard.cantrips, wizard.prepared_spells], "Magias salvas e carregadas")


func test_fire_bolt_spell_attack() -> void:
	var manager := _combat(_caster("class.wizard"), [_monster("monster.goblin_warrior")], [15, 7])
	var hero := _hero(manager)
	var goblin: Combatant = manager.living(Combatant.Team.ENEMY)[0]
	var result := manager.submit({"type": "cast", "actor": hero.id, "spell_id": "spell.fire_bolt", "target": goblin.id})
	assert_true(result["ok"], "Raio de Fogo conjurado: %s" % result["error"])
	var effect: Dictionary = _events_of(result, "spell_effect")[0]
	assert_true(effect["roll"]["hit"], "15 + ataque mágico acerta CA 15")
	assert_eq([effect["damage"], goblin.hp], [7, 3], "1d10 de fogo")
	assert_eq(hero.character.spell_slots_spent, [] as Array[int], "Truque não gasta espaço")
	assert_true(not manager.action_available, "Conjurar usa a ação")


func test_magic_missile_spends_slot_and_one_slot_per_turn() -> void:
	var cleric := _caster("class.cleric", {"cantrips": ["spell.sacred_flame"],
			"prepared_spells": ["spell.guiding_bolt", "spell.healing_word", "spell.cure_wounds", "spell.bless"]})
	var manager := _combat(cleric, [_monster("monster.goblin_warrior")], [15, 1, 1, 1, 1])
	var hero := _hero(manager)
	var goblin: Combatant = manager.living(Combatant.Team.ENEMY)[0]
	var bolt := manager.submit({"type": "cast", "actor": hero.id, "spell_id": "spell.guiding_bolt", "target": goblin.id})
	assert_true(bolt["ok"], "Raio Guiador: %s" % bolt["error"])
	assert_eq(cleric.spell_slots_spent, [1] as Array[int], "Gastou um espaço de 1º círculo")
	assert_true(not goblin.effects_of("guided").is_empty(), "Alvo marcado pelo Raio Guiador")
	var adv := manager.attack_advantage(hero, goblin, hero.attacks[0])
	assert_true("raio guiador" in adv["advantage"], "Próximo ataque contra o alvo com vantagem")
	var word := manager.submit({"type": "cast", "actor": hero.id, "spell_id": "spell.healing_word", "target": hero.id})
	assert_true(not word["ok"] and str(word["error"]).contains("um espaço"), "Só um espaço de magia por turno (2024)")

	var wizard := _caster("class.wizard")
	var second := _combat(wizard, [_monster("monster.wolf"), _monster("monster.goblin_warrior")], [4, 4, 4])
	var mage := _hero(second)
	var wolf: Combatant = second.living(Combatant.Team.ENEMY)[0]
	var missile := second.submit({"type": "cast", "actor": mage.id, "spell_id": "spell.magic_missile", "target": wolf.id})
	assert_true(missile["ok"], "Mísseis Mágicos: %s" % missile["error"])
	assert_eq([_events_of(missile, "spell_effect")[0]["damage"], wolf.is_up()], [15, false], "Três dardos de 1d4+1 acertam sempre")
	assert_eq(wizard.spell_slots_spent, [1] as Array[int], "Espaço gasto")


func test_burning_hands_area_and_half_on_save() -> void:
	var manager := _combat(_caster("class.wizard"), [_monster("monster.goblin_warrior"), _monster("monster.wolf")],
			[20, 6, 6, 6])
	var hero := _hero(manager)
	var goblin: Combatant = manager.living(Combatant.Team.ENEMY)[0]
	var wolf: Combatant = manager.living(Combatant.Team.ENEMY)[1]
	goblin.position = hero.position + Vector2i(1, 0)
	wolf.position = hero.position + Vector2i(0, 3)
	var cells := manager.area_cells(hero, _registry().get_entry("spell", "spell.burning_hands"), goblin.position)
	assert_eq(cells.size(), 7, "Cone de 4,5 m em linha reta: 7 casas")
	var result := manager.submit({"type": "cast", "actor": hero.id, "spell_id": "spell.burning_hands", "cell": goblin.position})
	assert_true(result["ok"], "Mãos Flamejantes: %s" % result["error"])
	var effects := _events_of(result, "spell_effect")
	assert_eq(effects.size(), 1, "Só o goblin estava no cone")
	assert_true(effects[0]["save"]["success"], "Goblin passa no teste de Destreza")
	assert_eq([effects[0]["damage"], goblin.hp], [9, 1], "Metade de 18")
	assert_eq(wolf.hp, wolf.max_hp, "Lobo fora da área")


func test_thunderwave_pushes_on_failed_save() -> void:
	var manager := _combat(_caster("class.druid"), [_monster("monster.goblin_warrior")], [1, 1, 1])
	var hero := _hero(manager)
	var goblin: Combatant = manager.living(Combatant.Team.ENEMY)[0]
	goblin.position = hero.position + Vector2i(1, 0)
	var start := goblin.position
	var result := manager.submit({"type": "cast", "actor": hero.id, "spell_id": "spell.thunderwave", "cell": goblin.position})
	assert_true(result["ok"], "Onda Trovejante: %s" % result["error"])
	assert_eq(goblin.hp, 8, "2d8 de trovão (1 + 1)")
	assert_eq(goblin.position, start + Vector2i(2, 0), "Empurrado 3 m (2 casas)")
	assert_eq(_events_of(result, "pushed").size(), 1, "Evento de empurrão")


func test_vicious_mockery_gives_disadvantage() -> void:
	var manager := _combat(_caster("class.bard"), [_monster("monster.goblin_warrior")], [1, 3])
	var hero := _hero(manager)
	var goblin: Combatant = manager.living(Combatant.Team.ENEMY)[0]
	var result := manager.submit({"type": "cast", "actor": hero.id, "spell_id": "spell.vicious_mockery", "target": goblin.id})
	assert_true(result["ok"], "Zombaria Viciosa: %s" % result["error"])
	assert_eq(goblin.hp, 7, "1d6 psíquico")
	var adv := manager.attack_advantage(goblin, hero, goblin.attacks[0])
	assert_true("zombaria" in adv["disadvantage"], "Goblin ataca com desvantagem")


func test_concentration_buffs_and_breaks() -> void:
	var cleric := _caster("class.cleric")
	var manager := _combat(cleric, [_monster("monster.goblin_warrior")], [2, 1])
	var hero := _hero(manager)
	var base_ac := hero.armor_class
	var shield := manager.submit({"type": "cast", "actor": hero.id, "spell_id": "spell.shield_of_faith", "target": hero.id})
	assert_true(shield["ok"], "Escudo da Fé: %s" % shield["error"])
	assert_eq(hero.effective_ac(), base_ac + 2, "+2 na CA")
	assert_eq(hero.concentration.get("name"), "Escudo da Fé", "Concentrando")
	# Simula o turno seguinte para poder gastar outro espaço.
	manager.slot_used_this_turn = false
	var bless := manager.submit({"type": "cast", "actor": hero.id, "spell_id": "spell.bless", "target": hero.id})
	assert_true(bless["ok"], "Bênção: %s" % bless["error"])
	assert_eq(hero.effective_ac(), base_ac, "Nova concentração encerra o Escudo da Fé")
	assert_eq(_events_of(bless, "concentration_end").size(), 1, "Fim da concentração anterior registrado")
	assert_true(not hero.effects_of("blessed").is_empty(), "Abençoado")
	# Dano: teste de Constituição com CD 10 (d20 = 1 + Bênção 1d4 = 2 falha).
	var events: Array[Dictionary] = []
	manager._apply_damage(hero, 4, events, {"type": "test"})
	var check: Array = events.filter(func(e: Dictionary) -> bool: return e["type"] == "concentration_check")
	assert_true(not check.is_empty() and not check[0]["success"], "Falhou no teste de concentração")
	assert_true(hero.effects_of("blessed").is_empty() and hero.concentration.is_empty(), "Bênção perdida")


func test_hex_adds_damage_to_attacks() -> void:
	var manager := _combat(_caster("class.warlock"), [_monster("monster.goblin_warrior")], [15, 3, 6])
	var hero := _hero(manager)
	var goblin: Combatant = manager.living(Combatant.Team.ENEMY)[0]
	var hex := manager.submit({"type": "cast", "actor": hero.id, "spell_id": "spell.hex", "target": goblin.id})
	assert_true(hex["ok"], "Maldição (ação bônus): %s" % hex["error"])
	assert_true(manager.action_available, "Ação ainda disponível")
	var blast := manager.submit({"type": "cast", "actor": hero.id, "spell_id": "spell.eldritch_blast", "target": goblin.id})
	assert_true(blast["ok"], "Rajada Mística: %s" % blast["error"])
	var effect: Dictionary = _events_of(blast, "spell_effect")[0]
	assert_eq([effect["extra"]["damage"], effect["damage"]], [6, 9], "1d10 de energia + 1d6 necrótico da Maldição")


func test_healing_and_rests_restore_slots() -> void:
	var cleric := _caster("class.cleric")
	cleric.current_hp = 1
	var manager := _combat(cleric, [_monster("monster.goblin_warrior")], [8, 8])
	var hero := _hero(manager)
	var result := manager.submit({"type": "cast", "actor": hero.id, "spell_id": "spell.cure_wounds", "target": hero.id})
	assert_true(result["ok"], "Curar Ferimentos: %s" % result["error"])
	assert_eq(hero.hp, hero.max_hp, "Cura até o máximo")
	assert_eq(Spellcasting.slots_left(cleric, _registry()), [1] as Array[int], "Um espaço restante")
	Rest.long_rest(cleric, _registry())
	assert_eq(Spellcasting.slots_left(cleric, _registry()), [2] as Array[int], "Descanso longo recupera os espaços")
	var warlock := _caster("class.warlock")
	Spellcasting.spend_slot(warlock, 1)
	assert_true(Spellcasting.short_rest_would_restore(warlock, _registry()), "Pacto gasto pode ser recuperado")
	assert_eq(Spellcasting.short_rest(warlock, _registry()), 1, "Descanso curto recupera o espaço de pacto")
	Spellcasting.spend_slot(cleric, 1)
	assert_eq(Spellcasting.short_rest(cleric, _registry()), 0, "Clérigo não recupera no descanso curto")


func test_level_up_prepares_new_spells_and_migration() -> void:
	var cleric := _caster("class.cleric")
	assert_eq(cleric.prepared_spells.size(), 4, "Clérigo nível 1 prepara 4")
	var up := Progression.level_up(cleric, _registry())
	assert_eq(cleric.prepared_spells.size(), 5, "Nível 2 prepara 5")
	assert_eq((up["spells"] as Array).size(), 1, "Uma magia nova na subida de nível")
	var old := cleric.to_dict()
	old.erase("cantrips")
	old.erase("prepared_spells")
	old.erase("spell_slots_spent")
	old["schema_version"] = 3
	var loaded: CharacterData = CharacterData.from_dict(old)[0]
	assert_true(loaded != null and loaded.cantrips.is_empty(), "Save v3 carrega sem magias")
	assert_eq(Spellcasting.fill_defaults(loaded, _registry()).size(), 6, "Magias padrão completadas (1 truque + 5)")


func test_combat_scene_casts_with_menu_and_click() -> void:
	var wizard := _caster("class.wizard")
	var scene: Control = (load(SCENE) as PackedScene).instantiate()
	scene.ai_delay = 0.0
	scene.animations_enabled = false
	scene.setup("encounter.ruin_goblin", [wizard] as Array[CharacterData], DiceRoller.scripted([20, 1, 15, 7]))
	tree.root.add_child(scene)
	await tree.process_frame
	await tree.process_frame
	var manager: CombatManager = scene.get_manager()
	assert_true(manager.is_party_turn(), "Mago age primeiro")
	scene.select_spell("spell.fire_bolt")
	assert_eq(scene.selected_spell_id(), "spell.fire_bolt", "Raio de Fogo selecionado")
	var goblin: Combatant = manager.living(Combatant.Team.ENEMY)[0]
	var result: Dictionary = scene.click_cell(goblin.position)
	assert_true(result["ok"], "Clique no goblin conjura: %s" % result.get("error", ""))
	await tree.process_frame
	assert_eq(goblin.hp, 3, "Dano aplicado")
	var log_text: String = (scene.get_node("%Log") as RichTextLabel).get_parsed_text()
	assert_true(log_text.contains("conjura Raio de Fogo"), "Registro mostra a conjuração")
	scene.select_spell("spell.burning_hands")
	scene._refresh()
	scene.queue_free()
	await tree.process_frame
