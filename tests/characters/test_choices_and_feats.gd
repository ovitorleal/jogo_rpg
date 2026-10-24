extends "res://tests/base_test.gd"
## Fase 6.6 (entrega 1): antecedentes do SRD, talentos, escolhas de nível, recursos de classe,
## migração do esquema 5 e as telas de escolha.

const ENGINE_TESTS := preload("res://tests/combat/test_combat_engine.gd")
const SCENE := "res://scenes/menus/character_creation.tscn"

var _engine: Object


func _hero(class_id: String, background_id: String = "background.criminal", picks: Dictionary = {}) -> CharacterData:
	if _engine == null:
		_engine = ENGINE_TESTS.new()
		_engine.tree = tree
	return _engine._hero(class_id, background_id, picks)


func _registry() -> ContentRegistry:
	if _engine == null:
		_engine = ENGINE_TESTS.new()
	return _engine._registry()


func test_all_srd_backgrounds_create_valid_characters() -> void:
	for background_id in ["background.acolyte", "background.criminal", "background.sage", "background.soldier"]:
		var c := _hero("class.fighter", background_id)
		assert_true(c != null, "%s válido" % background_id)
	var acolyte := _hero("class.fighter", "background.acolyte")
	assert_true(CharacterChoices.has_feat(acolyte, _registry(), "feat.magic_initiate"), "Acólito: Iniciado em Magia")
	assert_true("spell.sacred_flame" in acolyte.choice("bg.cantrips"), "Truque de clérigo escolhido")
	var sage := _hero("class.fighter", "background.sage")
	assert_eq(sage.choice("bg.cantrips").size(), 2, "Sábio: dois truques de mago")
	assert_eq(sage.choice("bg.spell").size(), 1, "Sábio: uma magia de 1º círculo")


func test_magic_initiate_free_cast_once_per_long_rest() -> void:
	var fighter := _hero("class.fighter", "background.sage")
	var unit := Combatant.from_character(fighter, _registry())
	var spell_id: String = fighter.choice("bg.spell")[0]
	assert_true(not unit.get_spell(spell_id).is_empty(), "Guerreiro conjura a magia do talento")
	var manager := CombatManager.new()
	manager.registry = _registry()
	var party: Array[Combatant] = [unit]
	var enemy: Array[Combatant] = [_engine._monster("monster.goblin_warrior")]
	manager.setup(party, enemy, Vector2i(12, 8), true, DiceRoller.scripted([20, 1]))
	manager.start()
	assert_true(manager.spell_error(unit, spell_id).is_empty(), "Uso gratuito disponível sem espaços de magia")
	var entry: Dictionary = unit.get_spell(spell_id)["entry"]
	var command := {"type": "cast", "actor": unit.id, "spell_id": spell_id}
	if CombatManager.is_area_spell(entry):
		command["cell"] = unit.position + Vector2i(1, 0)
	else:
		command["target"] = enemy[0].id if entry["target"] == "enemy" else unit.id
	enemy[0].position = unit.position + Vector2i(1, 0)
	var result := manager.submit(command)
	assert_true(result["ok"], "Conjura sem espaço: %s" % result["error"])
	assert_eq(fighter.resource_spent("mi.bg"), 1, "Uso gratuito gasto")
	manager.slot_used_this_turn = false
	manager.action_available = true
	assert_true(not manager.spell_error(unit, spell_id).is_empty(), "Sem espaços, não conjura de novo")
	Rest.long_rest(fighter, _registry())
	assert_eq(fighter.resource_spent("mi.bg"), 0, "Descanso longo devolve o uso")


func test_level_four_feat_and_ability_increase() -> void:
	var fighter := _hero("class.fighter")
	var strength := fighter.ability_score(Ability.STRENGTH)
	for i in 3:
		Progression.level_up(fighter, _registry())
	fighter.experience = 2700
	assert_eq(fighter.choice("feat.L4"), ["feat.ability_score_improvement"] as Array[String], "Nível 4: Aumento no Valor de Atributo")
	assert_eq(fighter.ability_score(Ability.STRENGTH), mini(20, strength + 2), "+2 no atributo principal (Força)")
	fighter.choices["feat.L4"] = ["feat.skilled"]
	CharacterChoices.fill_defaults(fighter, _registry())
	assert_eq(fighter.choice("feat.L4.skills").size(), 3, "Habilidoso: três perícias")
	assert_eq(fighter.ability_score(Ability.STRENGTH), strength, "Sem o aumento de atributo")
	assert_eq(CharacterFactory.validate(fighter, _registry()), [] as Array[String], "Escolhas válidas")
	fighter.choices["feat.L4"] = ["feat.ability_score_improvement"]
	fighter.choices["feat.L4.abilities"] = ["str", "str", "str"]
	assert_true(not CharacterChoices.validate(fighter, _registry()).is_empty(), "Mais pontos que o permitido é erro")


func test_subclass_and_options_at_level_three() -> void:
	var cleric := _hero("class.cleric")
	assert_eq(cleric.choice("option.feature.divine_order").size(), 1, "Ordem Divina escolhida")
	for i in 2:
		Progression.level_up(cleric, _registry())
	assert_eq(cleric.subclass_id, "subclass.life", "Nível 3: Domínio da Vida (única subclasse do SRD)")
	var sheet := CharacterSheet.build(cleric, _registry())
	assert_true(sheet.features.any(func(f: Dictionary) -> bool: return f["id"] == "feature.disciple_of_life"), "Características da subclasse na ficha")


func test_class_resources_and_rests() -> void:
	var barbarian := _hero("class.barbarian")
	assert_eq(ClassFeatures.maximum(barbarian, _registry(), "rage"), 2, "Fúria: 2 usos no nível 1")
	assert_eq(ClassFeatures.raw_value(barbarian, _registry(), "rage_damage"), "+2", "Dano da Fúria +2")
	ClassFeatures.spend(barbarian, "rage", 2)
	assert_eq(ClassFeatures.remaining(barbarian, _registry(), "rage"), 0, "Sem Fúria")
	ClassFeatures.short_rest(barbarian, _registry())
	assert_eq(ClassFeatures.remaining(barbarian, _registry(), "rage"), 1, "Descanso curto recupera um uso")
	Rest.long_rest(barbarian, _registry())
	assert_eq(ClassFeatures.remaining(barbarian, _registry(), "rage"), 2, "Descanso longo recupera tudo")
	var paladin := _hero("class.paladin")
	assert_eq(ClassFeatures.maximum(paladin, _registry(), "lay_on_hands"), 5, "Cura pelas Mãos: 5 x nível")
	var bard := _hero("class.bard")
	assert_eq(ClassFeatures.maximum(bard, _registry(), "bardic_inspiration"), maxi(1, Ability.modifier(bard.ability_score(Ability.CHARISMA))),
			"Inspiração: modificador de Carisma")


func test_weapon_mastery_choices_follow_class_rules() -> void:
	var barbarian := _hero("class.barbarian")
	assert_eq(barbarian.choice("weapon_mastery").size(), 2, "Bárbaro: duas armas")
	for weapon_id in barbarian.choice("weapon_mastery"):
		assert_eq(_registry().get_entry("item", weapon_id)["attack_type"], "melee", "Bárbaro: só armas corpo a corpo")
	var rogue := _hero("class.rogue")
	for weapon_id in rogue.choice("weapon_mastery"):
		var properties: Array = _registry().get_entry("item", weapon_id)["properties"]
		assert_true("finesse" in properties or "light" in properties, "Ladino: armas leves ou de acuidade")
	var fighter := _hero("class.fighter")
	assert_eq(fighter.choice("weapon_mastery").size(), 3, "Guerreiro: três armas")
	assert_true("item.longsword" in fighter.choice("weapon_mastery"), "Arma do kit entre as escolhas padrão")


func test_schema_5_migration_fills_choices() -> void:
	var rogue := _hero("class.rogue")
	var old := rogue.to_dict()
	for key in ["subclass_id", "choices", "resources_spent", "exhaustion"]:
		old.erase(key)
	old["schema_version"] = 4
	var loaded: CharacterData = CharacterData.from_dict(old)[0]
	assert_true(loaded != null and loaded.choices.is_empty(), "Save v4 carrega sem escolhas")
	CharacterChoices.fill_defaults(loaded, _registry())
	assert_eq(loaded.choice("weapon_mastery").size(), 2, "Maestria completada")
	assert_eq(CharacterFactory.validate(loaded, _registry()), [] as Array[String], "Personagem migrado válido")


func test_creation_screen_shows_choices() -> void:
	var screen: Control = (load(SCENE) as PackedScene).instantiate()
	tree.root.add_child(screen)
	await tree.process_frame
	await tree.process_frame
	screen.select_class("class.fighter")
	await tree.process_frame
	await tree.process_frame
	var panel: ChoicesPanel = screen._choices_panel
	assert_true(panel.get_plain_text().contains("Estilo de Luta"), "Estilo de Luta na criação: %s" % panel.get_plain_text())
	assert_true(panel.get_plain_text().contains("Maestria em Armas"), "Maestria em Armas na criação")
	var c: CharacterData = screen.get_character()
	assert_true(c != null and not c.choice("weapon_mastery").is_empty(), "Escolhas chegam ao personagem")
	screen.queue_free()
	await tree.process_frame
