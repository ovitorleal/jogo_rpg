extends "res://tests/base_test.gd"
## Fase 6.6 (entrega 5): características de Feiticeiro (Dracônica), Bruxo (Corruptor) e Mago (Evocador).

const FULL_TESTS := preload("res://tests/combat/test_full_caster_features.gd")

var _full: Object


func _f() -> Object:
	if _full == null:
		_full = FULL_TESTS.new()
		_full.tree = tree
	return _full


func _registry() -> ContentRegistry:
	return _f()._registry()


func _at(class_id: String, level: int, options: Dictionary = {}) -> CharacterData:
	return _f()._at(class_id, level, options)


func _fight(c: CharacterData, dice: Array[int], enemies: int = 2) -> CombatManager:
	return _f()._fight(c, dice, enemies)


func _hero(manager: CombatManager) -> Combatant:
	return manager.living(Combatant.Team.PARTY)[0]


func _enemy(manager: CombatManager, index: int = 0) -> Combatant:
	return manager.living(Combatant.Team.ENEMY)[index]


func _feature(manager: CombatManager, unit: Combatant, feature: String, target: Combatant = null) -> Dictionary:
	return manager.submit({"type": "feature", "actor": unit.id, "feature": feature, "target": target.id if target != null else ""})


func _option(manager: CombatManager, unit: Combatant, key: String, value: Variant) -> void:
	manager.submit({"type": "option", "actor": unit.id, "key": key, "value": value})


func _cast(manager: CombatManager, unit: Combatant, spell_id: String, target: Combatant) -> Dictionary:
	return manager.submit({"type": "cast", "actor": unit.id, "spell_id": spell_id, "target": target.id})


func _effect(result: Dictionary) -> Dictionary:
	return result["events"].filter(func(e: Dictionary) -> bool: return e["type"] == "spell_effect")[0]


func _mod(unit: Combatant, ability: StringName) -> int:
	return int(unit.modifiers[ability])


# --- Feiticeiro -------------------------------------------------------------------------------------

func test_innate_sorcery_font_of_magic_and_restoration() -> void:
	var sorcerer := _at("class.sorcerer", 5)
	var manager := _fight(sorcerer, [])
	var hero := _hero(manager)
	var bolt := hero.get_spell("spell.fire_bolt")
	var innate := _feature(manager, hero, "innate_sorcery")
	assert_true(innate["ok"], "Feitiçaria Inata: %s" % innate["error"])
	assert_eq(CombatFeatures.spell_dc_bonus(manager, hero, bolt), 1, "CD +1 nas magias de feiticeiro")
	var adv := {"advantage": [] as Array[String], "disadvantage": [] as Array[String], "state": D20Test.Advantage.NONE}
	CombatFeatures.spell_attack_mods(manager, hero, bolt, adv)
	assert_eq(adv["state"], D20Test.Advantage.ADVANTAGE, "Vantagem nos ataques de magia de feiticeiro")
	assert_true(not _feature(manager, hero, "font_slot_to_points")["ok"], "Pontos cheios: não converte espaço")
	sorcerer.resources_spent["sorcery_points"] = 3
	assert_true(_feature(manager, hero, "font_slot_to_points")["ok"], "Espaço de 1º vira 1 ponto")
	assert_eq(sorcerer.resource_spent("sorcery_points"), 2, "Recebeu 1 ponto")
	assert_eq(Spellcasting.slots_left(sorcerer, _registry())[0], 3, "Gastou o espaço de 1º")
	manager.bonus_action_available = true
	assert_true(_feature(manager, hero, "font_points_to_slot")["ok"], "2 pontos recriam o espaço de 1º")
	assert_eq(Spellcasting.slots_left(sorcerer, _registry())[0], 4, "Espaço de volta")
	sorcerer.resources_spent["sorcery_points"] = 5
	ClassFeatures.short_rest(sorcerer, _registry())
	assert_eq(sorcerer.resource_spent("sorcery_points"), 3, "Restauração Feiticeira: metade do nível (2)")


func test_metamagic_quickened_empowered_and_seeking() -> void:
	var quick := _at("class.sorcerer", 5, {"metamagic.feature.metamagic": ["metamagic.quickened", "metamagic.empowered"]})
	var manager := _fight(quick, [18, 1, 1, 9, 9])
	var hero := _hero(manager)
	var goblin := _enemy(manager)
	goblin.hp = 60
	_option(manager, hero, "metamagic", "metamagic.quickened")
	_option(manager, hero, "metamagic", "metamagic.empowered")
	var cast := _cast(manager, hero, "spell.fire_bolt", goblin)
	assert_true(cast["ok"], "Raio de Fogo acelerado: %s" % cast["error"])
	assert_true(manager.action_available and not manager.bonus_action_available, "Magia Acelerada: gastou a ação bônus")
	assert_eq(int(_effect(cast)["damage"]), 18, "Magia Potencializada: rola de novo os dados baixos (1, 1 → 9, 9)")
	assert_eq(quick.resource_spent("sorcery_points"), 3, "2 (Acelerada) + 1 (Potencializada)")
	assert_true(not manager.spell_error(hero, "spell.burning_hands").is_empty(), "Depois de Acelerada, só truques")
	var seeker := _at("class.sorcerer", 5, {"metamagic.feature.metamagic": ["metamagic.seeking", "metamagic.distant"]})
	var second := _fight(seeker, [2, 18, 5, 5])
	var unit := _hero(second)
	var target := _enemy(second)
	target.hp = 60
	_option(second, unit, "metamagic", "metamagic.seeking")
	var seek := _cast(second, unit, "spell.fire_bolt", target)
	assert_true(_effect(seek)["roll"]["hit"], "Magia Buscadora: errou e acertou ao rolar de novo")
	assert_eq(seeker.resource_spent("sorcery_points"), 1, "Gastou 1 ponto só porque errou")
	_option(second, unit, "metamagic", "metamagic.distant")
	assert_eq(CombatFeatures.spell_range_bonus(second, unit, unit.get_spell("spell.fire_bolt")), 120, "Magia Distante dobra o alcance")


func test_metamagic_heightened_and_command() -> void:
	var sorcerer := _at("class.sorcerer", 5, {"metamagic.feature.metamagic": ["metamagic.heightened", "metamagic.careful"]})
	var manager := _fight(sorcerer, [15, 2, 1, 1, 1])
	var hero := _hero(manager)
	var goblin := _enemy(manager)
	goblin.position = hero.position + Vector2i(1, 0)
	goblin.hp = 60
	_option(manager, hero, "metamagic", "metamagic.heightened")
	var cast := manager.submit({"type": "cast", "actor": hero.id, "spell_id": "spell.burning_hands", "cell": goblin.position})
	assert_true(cast["ok"], "Mãos Flamejantes: %s" % cast["error"])
	assert_eq(int(_effect(cast)["save"]["natural"]), 2, "Magia Elevada: desvantagem (15 e 2 → 2)")
	var fiend := _at("class.warlock", 3)
	var second := _fight(fiend, [1])
	var unit := _hero(second)
	var target := _enemy(second)
	var command := _cast(second, unit, "spell.command", target)
	assert_true(command["ok"], "Comando (Magias do Corruptor): %s" % command["error"])
	assert_true(target.has_condition("prone"), "Falhou em Sabedoria: Caído")


func test_draconic_resilience_affinity_orb_and_wings() -> void:
	var draconic := _at("class.sorcerer", 14, {"option.feature.elemental_affinity": ["elemental_affinity.cold"]})
	var sheet := CharacterSheet.build(draconic, _registry())
	var plain := CharacterData.from_dict(draconic.to_dict())[0] as CharacterData
	plain.subclass_id = ""
	assert_eq(sheet.max_hp - CharacterSheet.build(plain, _registry()).max_hp, 14, "+1 PV por nível de feiticeiro")
	assert_eq(sheet.armor_class, 10 + sheet.modifiers[Ability.DEXTERITY] + sheet.modifiers[Ability.CHARISMA], "CA 10 + Des + Car")
	var manager := _fight(draconic, [18, 1, 1, 1])
	var hero := _hero(manager)
	var goblin := _enemy(manager)
	goblin.position = hero.position + Vector2i(3, 0)
	goblin.hp = 80
	goblin.resistances = ["fire"]
	assert_true("cold" in hero.resistances, "Afinidade Elemental: resistência a frio")
	var orb := _cast(manager, hero, "spell.chromatic_orb", goblin)
	assert_true(orb["ok"], "Orbe Cromático: %s" % orb["error"])
	var effect := _effect(orb)
	assert_eq(str(effect["damage_type"]), "cold", "Orbe escolhe frio contra quem resiste a fogo")
	assert_true(int(effect["damage"]) >= 3 + _mod(hero, Ability.CHARISMA), "Afinidade Elemental soma o Carisma ao frio")
	var wings := _feature(manager, hero, "dragon_wings")
	assert_true(wings["ok"] and hero.speed_feet >= 60, "Asas de Dragão: 18 m")


# --- Bruxo ------------------------------------------------------------------------------------------

func test_eldritch_blast_invocations() -> void:
	var warlock := _at("class.warlock", 5, {"invocation.feature.eldritch_invocations": ["invocation.agonizing_blast@2",
			"invocation.repelling_blast@2", "invocation.eldritch_spear@2", "invocation.eldritch_mind", "invocation.armor_of_shadows"]})
	var sheet := CharacterSheet.build(warlock, _registry())
	warlock.armor_id = ""
	assert_eq(CharacterSheet.build(warlock, _registry()).armor_class, 13 + sheet.modifiers[Ability.DEXTERITY], "13 + Des sem armadura")
	var manager := _fight(warlock, [18, 3, 3])
	var hero := _hero(manager)
	var goblin := _enemy(manager)
	goblin.position = hero.position + Vector2i(3, 0)
	goblin.hp = 60
	var start := goblin.position
	var blast := _cast(manager, hero, "spell.eldritch_blast", goblin)
	assert_eq(int(_effect(blast)["damage"]), 6 + _mod(hero, Ability.CHARISMA), "Explosão Agonizante soma o Carisma")
	assert_eq(goblin.position, start + Vector2i(2, 0), "Explosão Repulsiva empurra 3 m")
	assert_eq(CombatFeatures.spell_range_bonus(manager, hero, hero.get_spell("spell.eldritch_blast")), 150, "Lança Mística: +9 m por nível")
	hero.concentration = {"spell_id": "x", "name": "x"}
	assert_eq(CombatFeatures.concentration_advantage(hero), 1, "Mente Mística")


func test_pact_of_the_blade_smite_and_cunning() -> void:
	var warlock := _at("class.warlock", 5, {"invocation.feature.eldritch_invocations": ["invocation.pact_of_the_blade",
			"invocation.thirsting_blade@5", "invocation.eldritch_smite@5", "invocation.eldritch_mind", "invocation.armor_of_shadows"]})
	var manager := _fight(warlock, [18, 2, 4, 4, 4, 4])
	var hero := _hero(manager)
	var goblin := _enemy(manager)
	goblin.position = hero.position + Vector2i(1, 0)
	goblin.hp = 60
	assert_eq(manager.attacks_per_action(hero), 2, "Lâmina Sedenta: dois ataques")
	var weapon: Dictionary = hero.attacks.filter(func(a: Dictionary) -> bool: return a.get("pact", false))[0]
	assert_eq(int(weapon["attack_bonus"]), maxi(_mod(hero, Ability.CHARISMA), _mod(hero, Ability.STRENGTH)) + 3,
			"Arma de pacto usa o Carisma")
	_option(manager, hero, "eldritch_smite", true)
	var attack := manager.submit({"type": "attack", "actor": hero.id, "target": goblin.id, "attack_id": weapon["id"]})
	var event: Dictionary = attack["events"].filter(func(e: Dictionary) -> bool: return e["type"] == "attack")[0]
	assert_true("Golpe Místico +16" in str(event["features"]), "Golpe Místico: 4d8 com espaço de 3º (%s)" % event["features"])
	assert_true(goblin.has_condition("prone"), "Golpe Místico derruba")
	warlock.spell_slots_spent.assign([0, 0, 2])
	manager.state = CombatManager.State.FINISHED
	manager.outcome = CombatManager.Outcome.VICTORY
	manager.apply_results_to_party(_registry())
	assert_eq(Array(warlock.spell_slots_spent), [0, 0, 1], "Astúcia Mágica: recupera metade dos espaços de pacto")


func test_fiend_blessing_luck_resilience_and_hurl() -> void:
	var fiend := _at("class.warlock", 14)
	var manager := _fight(fiend, [10, 10, 18, 3, 1, 5, 5, 5, 5, 5, 5, 5, 5])
	var hero := _hero(manager)
	var goblin := _enemy(manager)
	var other := _enemy(manager, 1)
	assert_true("acid" in hero.resistances, "Resiliência Corruptora: tipo escolhido (padrão ácido)")
	var dc := 10 + hero.save_bonus(Ability.WISDOM) + 3
	var save := manager._roll_save(hero, Ability.WISDOM, dc)
	assert_true(save.success, "Sorte do Obscuro: +1d10 transforma a falha")
	goblin.position = hero.position + Vector2i(1, 0)
	goblin.hp = 80
	_option(manager, hero, "hurl", true)
	var weapon := hero.get_attack("item.dagger") if not hero.get_attack("item.dagger").is_empty() else hero.attacks[0]
	var attack := manager.submit({"type": "attack", "actor": hero.id, "target": goblin.id, "attack_id": weapon["id"]})
	assert_true(attack["events"].any(func(e: Dictionary) -> bool: return e.get("feature") == "hurl_through_hell"), "Arremessar pelo Inferno")
	assert_true(goblin.has_condition("incapacitated"), "Incapacitado até o fim do próximo turno")
	other.hp = 1
	var events: Array[Dictionary] = []
	manager._apply_damage(other, 1, events, {"type": "attack", "actor": hero.id, "target": other.id})
	assert_eq(hero.temp_hp, maxi(1, _mod(hero, Ability.CHARISMA) + 14), "Bênção do Obscuro: Carisma + nível")


# --- Mago -------------------------------------------------------------------------------------------

func test_arcane_recovery_potent_cantrip_and_sculpt() -> void:
	var wizard := _at("class.wizard", 6)
	wizard.spell_slots_spent.assign([2, 1, 1])
	ClassFeatures.short_rest(wizard, _registry())
	assert_eq(Array(wizard.spell_slots_spent), [2, 1, 0], "Recuperação Arcana: 3 círculos (um de 3º)")
	var manager := _fight(wizard, [2, 3, 3])
	var hero := _hero(manager)
	var goblin := _enemy(manager)
	goblin.position = hero.position + Vector2i(3, 0)
	goblin.hp = 60
	var miss := _cast(manager, hero, "spell.fire_bolt", goblin)
	assert_eq(int(_effect(miss)["damage"]), 3, "Truque Potente: metade do dano ao errar")
	var duo: CombatManager = _f()._duo(_at("class.wizard", 6), _at("class.fighter", 1), [15, 3, 3, 3] as Array[int])
	var caster := _hero(duo)
	var ally: Combatant = duo.living(Combatant.Team.PARTY)[1]
	var foe := _enemy(duo)
	ally.position = caster.position + Vector2i(1, 0)
	foe.position = caster.position + Vector2i(2, 0)
	foe.hp = 60
	var hp := ally.hp
	var burn := duo.submit({"type": "cast", "actor": caster.id, "spell_id": "spell.burning_hands", "cell": ally.position})
	assert_true(burn["ok"], "Mãos Flamejantes: %s" % burn["error"])
	assert_eq(ally.hp, hp, "Esculpir Magias: o aliado não sofre dano")
	assert_true(foe.hp < 60, "O inimigo sofre o dano")


func test_empowered_evocation_and_overchannel() -> void:
	var wizard := _at("class.wizard", 14)
	wizard.prepared_spells.assign(["spell.magic_missile"])
	var manager := _fight(wizard, [5, 5])
	var hero := _hero(manager)
	var goblin := _enemy(manager)
	goblin.hp = 200
	_option(manager, hero, "overchannel", true)
	var first := _cast(manager, hero, "spell.magic_missile", goblin)
	assert_true(first["ok"], "Mísseis Mágicos: %s" % first["error"])
	assert_eq(int(_effect(first)["damage"]), 15 + _mod(hero, Ability.INTELLIGENCE), "Sobrecarga: dardos no máximo + Inteligência (Evocação Fortalecida)")
	manager.action_available = true
	manager.slot_used_this_turn = false
	var before := hero.hp
	var second := _cast(manager, hero, "spell.magic_missile", goblin)
	assert_true(second["ok"], "Segunda Sobrecarga: %s" % second["error"])
	assert_eq(before - hero.hp, 10, "Segunda vez no descanso: 2d12 necrótico por círculo (5 + 5)")
