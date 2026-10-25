extends "res://tests/base_test.gd"
## Fase 6.6 (entrega 3): características de Paladino (Devoção) e Patrulheiro (Caçador) em combate.

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
	return c


func _fight(c: CharacterData, dice: Array[int], enemies: int = 2) -> CombatManager:
	return _m()._fight(c, dice, enemies)


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


func _cha(unit: Combatant) -> int:
	return maxi(1, int(unit.modifiers[Ability.CHARISMA]))


# --- Paladino ---------------------------------------------------------------------------------------

func test_lay_on_hands_restoring_touch_and_auras() -> void:
	var paladin := _at("class.paladin", 14)
	var manager := _fight(paladin, [])
	var hero := _hero(manager)
	var goblin := _enemy(manager)
	var events: Array[Dictionary] = []
	hero.hp -= 30
	manager.add_condition(hero, "poisoned", goblin.id, events)
	manager.add_condition(hero, "blinded", goblin.id, events)
	var result := _feature(manager, hero, "lay_on_hands")
	assert_true(result["ok"], "Cura pelas Mãos: %s" % result["error"])
	assert_true(not hero.has_condition("poisoned") and not hero.has_condition("blinded"), "Remove Envenenado e Cego (Toque Restaurador)")
	assert_eq(hero.hp, hero.max_hp, "Cura os 30 PV perdidos")
	assert_eq(paladin.resource_spent("lay_on_hands"), 40, "5 + 5 pelas condições e 30 pela cura")
	assert_true(not manager.bonus_action_available, "Gasta a ação bônus")
	assert_eq(CombatFeatures.save_bonus(manager, hero, Ability.WISDOM), _cha(hero), "Aura de Proteção soma o Carisma")
	hero.position = Vector2i(0, 0)
	goblin.position = Vector2i(3, 0)
	assert_eq(CombatFeatures.save_bonus(manager, goblin, Ability.WISDOM), 0, "Inimigos não recebem a aura")
	manager.add_condition(hero, "frightened", goblin.id, events)
	manager.add_condition(hero, "charmed", goblin.id, events)
	assert_true(not hero.has_condition("frightened"), "Aura de Coragem: imune a Amedrontado")
	assert_true(not hero.has_condition("charmed"), "Aura de Devoção: imune a Enfeitiçado")


func test_divine_smite_free_use_and_always_prepared() -> void:
	var paladin := _at("class.paladin", 2)
	assert_true("spell.divine_smite" in Spellcasting.always_prepared_ids(paladin, _registry()), "Golpe Divino sempre preparada")
	assert_true(not "spell.divine_smite" in paladin.prepared_spells, "Não ocupa vaga de magia preparada")
	var manager := _fight(paladin, [15, 5, 4, 4])
	var hero := _hero(manager)
	var goblin := _enemy(manager)
	goblin.position = hero.position + Vector2i(1, 0)
	assert_true(not manager.spell_error(hero, "spell.divine_smite").is_empty(), "Não se conjura pelo menu de magias")
	manager.submit({"type": "option", "actor": hero.id, "key": "smite", "value": "always"})
	var attack := _attack(manager, hero, goblin, "item.longsword")
	var event: Dictionary = _events(attack, "attack")[0]
	assert_true("Golpe Divino +8" in str(event["features"]), "2d8 radiante: %s" % event["features"])
	assert_eq(paladin.resource_spent("paladins_smite"), 1, "Usou o Golpe do Paladino (sem espaço)")
	assert_eq(Spellcasting.slots_left(paladin, _registry())[0], 2, "Nenhum espaço gasto")
	assert_true(not manager.bonus_action_available, "Golpe Divino gasta a ação bônus")
	var critical_only := _at("class.paladin", 2)
	var second := _fight(critical_only, [15, 5])
	var unit := _hero(second)
	var target := _enemy(second)
	target.position = unit.position + Vector2i(1, 0)
	second.submit({"type": "option", "actor": unit.id, "key": "smite", "value": "critical"})
	var plain: Dictionary = _events(_attack(second, unit, target, "item.longsword"), "attack")[0]
	assert_true(not "Golpe Divino" in str(plain["features"]), "Modo crítico: acerto normal não gasta o Golpe Divino")
	assert_eq(critical_only.resource_spent("paladins_smite"), 0, "Uso gratuito preservado")


func test_radiant_strikes_sacred_weapon_and_abjure_foes() -> void:
	var paladin := _at("class.paladin", 11)
	var manager := _fight(paladin, [15, 5, 3, 1, 1])
	var hero := _hero(manager)
	var goblin := _enemy(manager)
	var other := _enemy(manager, 1)
	goblin.position = hero.position + Vector2i(1, 0)
	other.position = hero.position + Vector2i(2, 2)
	var sacred := _feature(manager, hero, "sacred_weapon")
	assert_true(sacred["ok"], "Arma Sagrada: %s" % sacred["error"])
	assert_eq(CombatFeatures.attack_bonus(hero, hero.get_attack("item.longsword")), _cha(hero), "Soma o Carisma ao ataque")
	assert_eq(paladin.resource_spent("channel_divinity"), 1, "Gasta Canalizar Divindade")
	var event: Dictionary = _events(_attack(manager, hero, goblin, "item.longsword"), "attack")[0]
	assert_true("Golpes Radiantes +3" in str(event["features"]), "Golpes Radiantes: +1d8 radiante (%s)" % event["features"])
	manager.attacks_left = 0
	var fresh := _at("class.paladin", 11)
	var second := _fight(fresh, [1, 1])
	var unit := _hero(second)
	var a := _enemy(second)
	var b := _enemy(second, 1)
	a.position = unit.position + Vector2i(2, 0)
	b.position = unit.position + Vector2i(2, 1)
	var abjure := _feature(second, unit, "abjure_foes")
	assert_true(abjure["ok"], "Repudiar Inimigos: %s" % abjure["error"])
	assert_true(a.has_condition("frightened") and b.has_condition("frightened"), "Os dois falharam e ficaram Amedrontados")
	var hit: Array[Dictionary] = []
	second._apply_damage(a, 1, hit, {"type": "attack", "actor": unit.id, "target": a.id})
	assert_true(not a.has_condition("frightened"), "Dano encerra o medo de Repudiar Inimigos")
	assert_true(not second.action_available, "Usa a ação (Magia)")


func test_holy_nimbus_and_smite_of_protection() -> void:
	var paladin := _at("class.paladin", 20)
	var manager := _fight(paladin, [15, 5, 4, 4])
	var hero := _hero(manager)
	var near := _enemy(manager)
	var far := _enemy(manager, 1)
	near.position = hero.position + Vector2i(1, 0)
	far.position = hero.position + Vector2i(8, 0)
	manager.submit({"type": "option", "actor": hero.id, "key": "smite", "value": "always"})
	var ac := hero.effective_ac()
	_attack(manager, hero, near, "item.longsword")
	assert_eq(hero.effective_ac(), ac + 2, "Golpe de Proteção: meia cobertura (+2 CA)")
	manager.bonus_action_available = true
	near.hp = 1
	var nimbus := _feature(manager, hero, "holy_nimbus")
	assert_true(nimbus["ok"], "Nimbo Sagrado: %s" % nimbus["error"])
	var end := manager.submit({"type": "end_turn", "actor": hero.id})
	assert_true(not near.is_up(), "Inimigo que começa o turno na aura sofre dano radiante")
	assert_true(_events(end, "feature").any(func(e: Dictionary) -> bool: return e["feature"] == "holy_nimbus"), "Evento do Nimbo")
	assert_eq(manager.current(), far, "O turno do inimigo caído é pulado")


func test_protection_from_evil_and_good() -> void:
	var paladin := _at("class.paladin", 3)
	assert_true("spell.protection_from_evil_and_good" in Spellcasting.always_prepared_ids(paladin, _registry()),
			"Magia do Juramento de Devoção")
	var manager := _fight(paladin, [])
	var hero := _hero(manager)
	var goblin := _enemy(manager)
	goblin.position = hero.position + Vector2i(1, 0)
	var cast := manager.submit({"type": "cast", "actor": hero.id, "spell_id": "spell.protection_from_evil_and_good", "target": hero.id})
	assert_true(cast["ok"], "Proteção conjurada: %s" % cast["error"])
	assert_true("proteção contra o bem e o mal" in manager.attack_advantage(goblin, hero, goblin.attacks[0])["disadvantage"],
			"Feérico ataca com desvantagem")
	var events: Array[Dictionary] = []
	manager.add_condition(hero, "frightened", goblin.id, events)
	assert_true(not hero.has_condition("frightened"), "Feérico não consegue amedrontar")


# --- Patrulheiro ------------------------------------------------------------------------------------

func test_favored_enemy_free_hunters_mark() -> void:
	var ranger := _at("class.ranger", 1)
	assert_true(not "spell.hunters_mark" in ranger.prepared_spells, "Marca do Caçador não ocupa vaga")
	var manager := _fight(ranger, [])
	var hero := _hero(manager)
	var goblin := _enemy(manager)
	assert_true(manager._free_cast_available(hero, hero.get_spell("spell.hunters_mark")), "Uso gratuito disponível")
	var cast := manager.submit({"type": "cast", "actor": hero.id, "spell_id": "spell.hunters_mark", "target": goblin.id})
	assert_true(cast["ok"], "Marca do Caçador: %s" % cast["error"])
	assert_eq(ranger.resource_spent("favored_enemy"), 1, "Gastou um uso do Inimigo Favorito")
	assert_eq(Spellcasting.slots_left(ranger, _registry())[0], 2, "Nenhum espaço gasto")
	assert_true(not manager.slot_used_this_turn, "Ainda pode gastar um espaço no turno")
	var events: Array[Dictionary] = []
	goblin.hp = 1
	manager._apply_damage(goblin, 1, events, {"type": "attack", "actor": hero.id, "target": goblin.id})
	var other := _enemy(manager)
	manager.bonus_action_available = true
	var moved := _feature(manager, hero, "move_mark", other)
	assert_true(moved["ok"], "Move a marca do alvo caído: %s" % moved["error"])
	assert_eq(other.effects_of("marked").size(), 1, "Nova criatura marcada")


func test_colossus_slayer_and_horde_breaker() -> void:
	var ranger := _at("class.ranger", 3)
	var manager := _fight(ranger, [18, 3, 4])
	var hero := _hero(manager)
	var goblin := _enemy(manager)
	goblin.position = hero.position + Vector2i(1, 0)
	goblin.hp = 9
	var event: Dictionary = _events(_attack(manager, hero, goblin, "item.scimitar"), "attack")[0]
	assert_true("Matador de Colossos +4" in str(event["features"]), "Matador de Colossos: %s" % event["features"])
	var horde := _at("class.ranger", 3, {"option.feature.hunters_prey": ["hunters_prey.horde_breaker"]})
	var second := _fight(horde, [18, 1, 18, 1])
	var unit := _hero(second)
	var first := _enemy(second)
	var next := _enemy(second, 1)
	first.position = unit.position + Vector2i(1, 0)
	next.position = unit.position + Vector2i(1, 1)
	assert_true(not _feature(second, unit, "horde_breaker", next)["ok"], "Só depois de atacar com arma")
	_attack(second, unit, first, "item.scimitar")
	assert_true(not _feature(second, unit, "horde_breaker", first)["ok"], "Não contra a mesma criatura")
	var extra := _feature(second, unit, "horde_breaker", next)
	assert_true(extra["ok"], "Quebrador de Hordas: %s" % extra["error"])
	assert_eq(_events(extra, "attack").size(), 1, "Um ataque extra")
	assert_true(not _feature(second, unit, "horde_breaker", next)["ok"], "Uma vez por turno")


func test_superior_hunters_prey_and_lore() -> void:
	var ranger := _at("class.ranger", 11)
	var manager := _fight(ranger, [18, 3, 2, 5])
	var hero := _hero(manager)
	var goblin := _enemy(manager)
	var other := _enemy(manager, 1)
	goblin.position = hero.position + Vector2i(1, 0)
	other.position = goblin.position + Vector2i(2, 0)
	var cast := manager.submit({"type": "cast", "actor": hero.id, "spell_id": "spell.hunters_mark", "target": goblin.id})
	var effect: Dictionary = _events(cast, "spell_effect")[0]
	assert_true("Saber do Caçador" in str(effect["effect"]), "Saber do Caçador revela resistências")
	var attack := _attack(manager, hero, goblin, "item.scimitar")
	var spread := _events(attack, "feature").filter(func(e: Dictionary) -> bool: return e["feature"] == "superior_hunters_prey")
	assert_eq(spread.size(), 1, "Presa do Caçador Superior")
	assert_eq(other.hp, other.max_hp - 5, "Dano da Marca na segunda criatura")


func test_tireless_veil_and_relentless_hunter() -> void:
	var ranger := _at("class.ranger", 14)
	var manager := _fight(ranger, [4])
	var hero := _hero(manager)
	var goblin := _enemy(manager)
	var tireless := _feature(manager, hero, "tireless")
	assert_true(tireless["ok"], "Incansável: %s" % tireless["error"])
	assert_eq(hero.temp_hp, maxi(1, 4 + int(hero.modifiers[Ability.WISDOM])), "1d8 + Sabedoria de PV temporários")
	var veil := _feature(manager, hero, "natures_veil")
	assert_true(veil["ok"] and hero.has_condition("invisible"), "Véu da Natureza: Invisível")
	manager._expire_effects("turn_end", hero.id)
	assert_true(hero.has_condition("invisible"), "Continua até o fim do próximo turno")
	manager._expire_effects("turn_end", hero.id)
	assert_true(not hero.has_condition("invisible"), "Termina no fim do próximo turno")
	manager.bonus_action_available = true
	manager.submit({"type": "cast", "actor": hero.id, "spell_id": "spell.hunters_mark", "target": goblin.id})
	var events: Array[Dictionary] = []
	manager._apply_damage(hero, 20, events, {"type": "attack", "actor": goblin.id, "target": hero.id})
	assert_eq(hero.concentration.get("spell_id"), "spell.hunters_mark", "Caçador Implacável: dano não quebra a Marca")
	ranger.exhaustion = 2
	ClassFeatures.short_rest(ranger, _registry())
	assert_eq(ranger.exhaustion, 1, "Descanso curto reduz a Exaustão")


func test_precise_hunter_feral_senses_foe_slayer_and_defenses() -> void:
	var ranger := _at("class.ranger", 20, {"option.feature.defensive_tactics": ["defensive_tactics.multiattack_defense"]})
	var manager := _fight(ranger, [])
	var hero := _hero(manager)
	var goblin := _enemy(manager)
	goblin.position = hero.position + Vector2i(1, 0)
	manager.submit({"type": "cast", "actor": hero.id, "spell_id": "spell.hunters_mark", "target": goblin.id})
	assert_eq(str(goblin.effects_of("marked")[0]["value"]), "1d10", "Matador de Inimigos: d10")
	var scimitar := hero.get_attack("item.scimitar")
	assert_true("caçador preciso" in manager.attack_advantage(hero, goblin, scimitar)["advantage"], "Caçador Preciso")
	var events: Array[Dictionary] = []
	manager.add_condition(hero, "blinded", goblin.id, events)
	manager.add_condition(goblin, "invisible", goblin.id, events)
	var senses := manager.attack_advantage(hero, goblin, scimitar)
	assert_true(not "cego" in senses["disadvantage"] and not "alvo invisível" in senses["disadvantage"], "Sentidos Ferais a 9 m")
	CombatFeatures.after_hit(manager, goblin, hero, goblin.attacks[0], events)
	assert_true("defesa contra ataques múltiplos" in manager.attack_advantage(goblin, hero, goblin.attacks[0])["disadvantage"],
			"Defesa contra Ataques Múltiplos")
	var halved := CombatFeatures.incoming_attack_damage(manager, hero, goblin, goblin.attacks[0], 10, events)
	assert_eq(halved, 5, "Defesa do Caçador Superior: metade")
	assert_true(str(goblin.attacks[0]["damage_type"]) in hero.all_resistances(), "Resistência ao tipo até o fim do turno")
	var escape := _at("class.ranger", 7)
	var second := _fight(escape, [])
	var unit := _hero(second)
	var enemy := _enemy(second)
	second.opportunity_attack = true
	assert_true("escapar da horda" in second.attack_advantage(enemy, unit, enemy.attacks[0])["disadvantage"], "Escapar da Horda")
	second.opportunity_attack = false
