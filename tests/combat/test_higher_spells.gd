extends "res://tests/base_test.gd"
## Fase 6.6 (entrega 6): magias de círculo alto, áreas novas e características que dependem delas.

const FULL_TESTS := preload("res://tests/combat/test_full_caster_features.gd")

var _full: Object


func _f() -> Object:
	if _full == null:
		_full = FULL_TESTS.new()
		_full.tree = tree
	return _full


func _registry() -> ContentRegistry:
	return _f()._registry()


func _caster(class_id: String, level: int, spells: Array[String] = []) -> CharacterData:
	var c: CharacterData = _f()._at(class_id, level)
	if not spells.is_empty():
		c.prepared_spells.assign(spells)
	return c


func _fight(c: CharacterData, dice: Array[int]) -> CombatManager:
	return _f()._fight(c, dice)


func _hero(manager: CombatManager) -> Combatant:
	return manager.living(Combatant.Team.PARTY)[0]


func _enemy(manager: CombatManager, index: int = 0) -> Combatant:
	return manager.living(Combatant.Team.ENEMY)[index]


func _cast(manager: CombatManager, unit: Combatant, spell_id: String, target: Combatant) -> Dictionary:
	return manager.submit({"type": "cast", "actor": unit.id, "spell_id": spell_id, "target": target.id})


func _cast_at(manager: CombatManager, unit: Combatant, spell_id: String, cell: Vector2i) -> Dictionary:
	return manager.submit({"type": "cast", "actor": unit.id, "spell_id": spell_id, "cell": cell})


func _effects(result: Dictionary) -> Array:
	return result["events"].filter(func(e: Dictionary) -> bool: return e["type"] == "spell_effect")


func _ones(count: int, value: int = 1) -> Array[int]:
	var result: Array[int] = []
	for i in count:
		result.append(value)
	return result


# --- Áreas ------------------------------------------------------------------------------------------

func test_fireball_sphere_and_lightning_line() -> void:
	var dice: Array[int] = [1]
	dice.append_array(_ones(8, 3))
	dice.append(20)
	dice.append_array(_ones(8, 3))
	var manager := _fight(_caster("class.wizard", 5, ["spell.fireball", "spell.lightning_bolt"]), dice)
	var hero := _hero(manager)
	var a := _enemy(manager)
	var b := _enemy(manager, 1)
	hero.position = Vector2i(1, 3)
	a.position = Vector2i(8, 3)
	b.position = Vector2i(9, 3)
	a.hp = 60
	b.hp = 60
	var fire := _cast_at(manager, hero, "spell.fireball", a.position)
	assert_true(fire["ok"], "Bola de Fogo: %s" % fire["error"])
	assert_eq(_effects(fire).size(), 2, "Os dois goblins estão na esfera de 6 m (o mago não)")
	assert_eq([a.hp, b.hp], [36, 48], "Falha: 24; sucesso: metade (12)")
	var second := _fight(_caster("class.wizard", 5, ["spell.lightning_bolt"]), [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1])
	var unit := _hero(second)
	var c := _enemy(second)
	var d := _enemy(second, 1)
	unit.position = Vector2i(1, 3)
	c.position = Vector2i(4, 3)
	d.position = Vector2i(4, 5)
	c.hp = 60
	d.hp = 60
	var bolt := _cast_at(second, unit, "spell.lightning_bolt", unit.position + Vector2i(1, 0))
	assert_true(bolt["ok"], "Relâmpago: %s" % bolt["error"])
	assert_eq(_effects(bolt).size(), 1, "Só quem está na linha")
	assert_true(c.hp < 60 and d.hp == 60, "Atinge o goblin da linha")


func test_scorching_ray_misty_step_and_blur() -> void:
	var manager := _fight(_caster("class.sorcerer", 5, ["spell.scorching_ray", "spell.misty_step", "spell.blur"]),
			[18, 1, 1, 18, 1, 1, 18, 1, 1])
	var hero := _hero(manager)
	var goblin := _enemy(manager)
	goblin.position = hero.position + Vector2i(4, 0)
	goblin.hp = 60
	var rays := _cast(manager, hero, "spell.scorching_ray", goblin)
	assert_true(rays["ok"], "Raio Ardente: %s" % rays["error"])
	assert_eq(_effects(rays).size(), 3, "Três raios, cada um com sua jogada")
	manager.slot_used_this_turn = false
	var destination := hero.position + Vector2i(0, 2)
	var step := _cast_at(manager, hero, "spell.misty_step", destination)
	assert_true(step["ok"] and hero.position == destination, "Passo Nebuloso: %s" % step["error"])
	assert_true(not manager.bonus_action_available, "Ação bônus")
	var second := _fight(_caster("class.sorcerer", 5, ["spell.blur"]), [])
	var unit := _hero(second)
	var enemy := _enemy(second)
	assert_true(_cast_at(second, unit, "spell.blur", unit.position)["ok"], "Borrão")
	assert_true("borrão" in second.attack_advantage(enemy, unit, enemy.attacks[0])["disadvantage"], "Ataques contra com desvantagem")


# --- Condições ---------------------------------------------------------------------------------------

func test_hold_person_sleep_fear_and_charm() -> void:
	var manager := _fight(_caster("class.wizard", 5, ["spell.hold_person", "spell.sleep", "spell.fear"]), [1, 20, 1, 1])
	var hero := _hero(manager)
	var goblin := _enemy(manager)
	var other := _enemy(manager, 1)
	goblin.position = hero.position + Vector2i(3, 0)
	other.position = hero.position + Vector2i(6, 4)
	assert_true(not manager.spell_target_error(hero, "spell.hold_person", goblin).is_empty(), "Goblin é feérico, não humanoide")
	goblin.creature_type = "humanoide"
	var hold := _cast(manager, hero, "spell.hold_person", goblin)
	assert_true(hold["ok"] and goblin.has_condition("paralyzed"), "Imobilizar Pessoa: Paralisado (%s)" % hold["error"])
	var events: Array[Dictionary] = []
	manager._repeat_end_of_turn_saves(goblin, events)
	assert_true(not goblin.has_condition("paralyzed"), "Passou no teste do fim do turno")
	manager.action_available = true
	manager.slot_used_this_turn = false
	var sleep := _cast_at(manager, hero, "spell.sleep", other.position)
	assert_true(sleep["ok"] and other.has_condition("incapacitated"), "Sono: Incapacitado (%s)" % sleep["error"])
	manager._repeat_end_of_turn_saves(other, events)
	assert_true(other.has_condition("unconscious"), "Falhou de novo: Inconsciente")
	var charm := _fight(_caster("class.warlock", 7, ["spell.charm_monster"]), [1, 1])
	var warlock := _hero(charm)
	var wolf := _enemy(charm)
	wolf.position = warlock.position + Vector2i(2, 0)
	var charmed := _cast(charm, warlock, "spell.charm_monster", wolf)
	assert_true(charmed["ok"] and wolf.has_condition("charmed"), "Enfeitiçar Monstro (vantagem: 1 e 1): %s" % charmed["error"])
	assert_true(charm._choose_target(wolf) == null, "Enfeitiçado não ataca quem o enfeitiçou")


# --- Cura e proteção --------------------------------------------------------------------------------

func test_aid_mass_cure_revivify_and_death_ward() -> void:
	var cleric := _caster("class.cleric", 9, ["spell.aid", "spell.mass_cure_wounds", "spell.revivify", "spell.death_ward"])
	var manager: CombatManager = _f()._duo(cleric, _f()._at("class.fighter", 1), [4, 4, 4, 4, 4, 4, 4, 4, 4, 4] as Array[int])
	var hero := _hero(manager)
	var ally: Combatant = manager.living(Combatant.Team.PARTY)[1]
	ally.position = hero.position + Vector2i(0, 1)
	var max_hp := ally.max_hp
	var aid := manager.submit({"type": "cast", "actor": hero.id, "spell_id": "spell.aid", "target": hero.id, "targets": [ally.id]})
	assert_true(aid["ok"], "Auxílio: %s" % aid["error"])
	assert_eq(ally.max_hp, max_hp + 5, "+5 PV máximos")
	manager.action_available = true
	manager.slot_used_this_turn = false
	hero.hp -= 40
	ally.hp = 1
	var before := hero.hp
	var mass := _cast_at(manager, hero, "spell.mass_cure_wounds", hero.position)
	assert_true(mass["ok"], "Curar Ferimentos em Massa: %s" % mass["error"])
	assert_eq(hero.hp - before, 20 + int(hero.modifiers[Ability.WISDOM]) + 7 + 7,
			"5d8 + Sabedoria + Discípulo da Vida (2 + 5) + Curandeiro Abençoado (curou o aliado: 2 + 5)")
	manager.action_available = true
	manager.slot_used_this_turn = false
	ally.hp = 0
	var revive := _cast(manager, hero, "spell.revivify", ally)
	assert_true(revive["ok"] and ally.hp == 1, "Revivificar: volta com 1 PV (%s)" % revive["error"])
	manager.action_available = true
	manager.slot_used_this_turn = false
	assert_true(_cast(manager, hero, "spell.death_ward", ally)["ok"], "Proteção contra a Morte")
	var events: Array[Dictionary] = []
	manager._apply_damage(ally, 50, events, {"type": "attack", "actor": "x", "target": ally.id})
	assert_eq(ally.hp, 1, "Cairia a 0 PV: fica com 1")


func test_restoration_freedom_fire_shield_hope_and_dispel() -> void:
	var druid := _caster("class.druid", 9, ["spell.lesser_restoration", "spell.greater_restoration", "spell.freedom_of_movement",
			"spell.fire_shield"])
	druid.exhaustion = 2
	var manager := _fight(druid, [3, 3])
	var hero := _hero(manager)
	var goblin := _enemy(manager)
	var events: Array[Dictionary] = []
	manager.add_condition(hero, "poisoned", goblin.id, events)
	assert_true(_cast(manager, hero, "spell.lesser_restoration", hero)["ok"] and not hero.has_condition("poisoned"), "Restauração Menor")
	manager.slot_used_this_turn = false
	assert_true(_cast(manager, hero, "spell.greater_restoration", hero)["ok"], "Restauração Maior")
	assert_eq(druid.exhaustion, 1, "Remove um nível de Exaustão")
	manager.action_available = true
	manager.slot_used_this_turn = false
	assert_true(_cast(manager, hero, "spell.freedom_of_movement", hero)["ok"], "Liberdade de Movimento")
	manager.add_condition(hero, "paralyzed", goblin.id, events)
	assert_true(not hero.has_condition("paralyzed"), "Não fica Paralisado")
	manager.action_available = true
	manager.slot_used_this_turn = false
	assert_true(_cast_at(manager, hero, "spell.fire_shield", hero.position)["ok"], "Escudo de Fogo")
	assert_true("cold" in hero.all_resistances(), "Resistência a frio")
	goblin.position = hero.position + Vector2i(1, 0)
	goblin.hp = 40
	CombatFeatures.on_damaged_by_attack(manager, hero, goblin, events)
	assert_eq(goblin.hp, 34, "Quem acerta sofre 2d8 de fogo (3 + 3)")
	var cleric := _fight(_caster("class.cleric", 5, ["spell.beacon_of_hope", "spell.dispel_magic"]), [])
	var priest := _hero(cleric)
	assert_true(_cast_at(cleric, priest, "spell.beacon_of_hope", priest.position)["ok"], "Sinal de Esperança")
	assert_true(not priest.effects_of("hope").is_empty(), "Esperança no próprio clérigo")
	priest.effects.append({"kind": "blessed", "source": "x", "spell": "Bênção", "value": "1d4", "on": "concentration"})
	cleric.action_available = true
	cleric.slot_used_this_turn = false
	assert_true(_cast(cleric, priest, "spell.dispel_magic", priest)["ok"], "Dissipar Magia")
	assert_true(priest.effects_of("blessed").is_empty() and priest.effects_of("hope").is_empty(), "Encerra as magias em andamento")


func test_flame_strike_and_power_words() -> void:
	var dice: Array[int] = [1]
	dice.append_array(_ones(10, 2))
	var manager := _fight(_caster("class.cleric", 9, ["spell.flame_strike"]), dice)
	var hero := _hero(manager)
	var goblin := _enemy(manager)
	goblin.position = hero.position + Vector2i(4, 0)
	goblin.hp = 60
	var strike := _cast_at(manager, hero, "spell.flame_strike", goblin.position)
	assert_true(strike["ok"], "Coluna de Chamas: %s" % strike["error"])
	assert_eq(goblin.hp, 40, "5d6 de fogo + 5d6 radiante (10 + 10)")
	var bard := _caster("class.bard", 20)
	assert_true("spell.power_word_kill" in Spellcasting.always_prepared_ids(bard, _registry()), "Palavras da Criação")
	var second := _fight(bard, [])
	var unit := _hero(second)
	var a := _enemy(second)
	var b := _enemy(second, 1)
	a.position = unit.position + Vector2i(4, 0)
	b.position = a.position + Vector2i(1, 1)
	var kill := second.submit({"type": "cast", "actor": unit.id, "spell_id": "spell.power_word_kill", "target": a.id, "targets": [b.id]})
	assert_true(kill["ok"], "Palavra de Poder Matar em dois alvos: %s" % kill["error"])
	assert_true(not a.is_up() and second.state == CombatManager.State.FINISHED, "Até 100 PV: morrem")
	var heal := _fight(_caster("class.bard", 20), [])
	var singer := _hero(heal)
	singer.hp = 3
	heal.add_condition(singer, "poisoned", "x", [] as Array[Dictionary])
	assert_true(_cast(heal, singer, "spell.power_word_heal", singer)["ok"], "Palavra de Poder Curar")
	assert_true(singer.hp == singer.max_hp and not singer.has_condition("poisoned"), "Todos os PV e sem Envenenado")


# --- Características ----------------------------------------------------------------------------------

func test_mystic_arcanum_spell_mastery_and_signature_spells() -> void:
	var warlock := _caster("class.warlock", 17)
	assert_eq(warlock.choice("arcanum.7"), ["spell.finger_of_death"] as Array[String], "Arcano Místico de 7º círculo")
	var manager := _fight(warlock, [1, 4, 4, 4, 4, 4, 4, 4])
	var hero := _hero(manager)
	var goblin := _enemy(manager)
	goblin.position = hero.position + Vector2i(4, 0)
	goblin.hp = 200
	var finger := _cast(manager, hero, "spell.finger_of_death", goblin)
	assert_true(finger["ok"], "Dedo da Morte sem espaço de 7º: %s" % finger["error"])
	assert_eq(goblin.hp, 200 - 58, "7d8 + 30 (28 + 30)")
	assert_eq(warlock.resource_spent("arcanum_7"), 1, "Uso do Arcano Místico gasto")
	manager.action_available = true
	assert_true(not manager.spell_error(hero, "spell.finger_of_death").is_empty(), "Uma vez por descanso longo")
	var wizard := _caster("class.wizard", 20)
	var mastery := wizard.choice("spell_mastery.1")
	assert_eq(mastery.size(), 1, "Maestria em Magia: uma magia de 1º círculo")
	var second := _fight(wizard, [])
	var mage := _hero(second)
	assert_true(second._free_cast_available(mage, mage.get_spell(mastery[0])), "À vontade, sem espaço")
	var signature := wizard.choice("signature")
	assert_eq(signature.size(), 2, "Duas Magias Assinatura")
	assert_true(second._free_cast_available(mage, mage.get_spell(signature[0])), "Assinatura sem espaço")
	assert_eq(str(mage.get_spell(signature[1])["free"]), "res.signature_2", "Cada uma com seu uso por descanso curto")
