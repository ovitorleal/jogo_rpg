extends "res://tests/base_test.gd"
## Fase 6.6 (entrega 2): características de Bárbaro, Guerreiro, Ladino e Monge (e subclasses) em combate.

const ENGINE_TESTS := preload("res://tests/combat/test_combat_engine.gd")

var _engine: Object


func _e() -> Object:
	if _engine == null:
		_engine = ENGINE_TESTS.new()
		_engine.tree = tree
	return _engine


## Personagem no nível pedido (escolhas padrão em cada nível).
func _at(class_id: String, level: int, background_id: String = "background.criminal", picks: Dictionary = {}) -> CharacterData:
	var c: CharacterData = _e()._hero(class_id, background_id, picks)
	for i in level - 1:
		Progression.level_up(c, _e()._registry())
	c.experience = Progression.XP_FOR_LEVEL[level]
	c.current_hp = CharacterSheet.build(c, _e()._registry()).max_hp
	return c


func _fight(c: CharacterData, dice: Array[int], enemies: int = 2) -> CombatManager:
	return _e()._combat(c, _e()._goblins(enemies), dice)


func _hero(manager: CombatManager) -> Combatant:
	return manager.living(Combatant.Team.PARTY)[0]


func _enemy(manager: CombatManager, index: int = 0) -> Combatant:
	return manager.living(Combatant.Team.ENEMY)[index]


func _feature(manager: CombatManager, unit: Combatant, feature: String, target: Combatant = null) -> Dictionary:
	return manager.submit({"type": "feature", "actor": unit.id, "feature": feature, "target": target.id if target != null else ""})


func _events(result: Dictionary, type: String) -> Array:
	return result["events"].filter(func(e: Dictionary) -> bool: return e["type"] == type)


# --- Bárbaro --------------------------------------------------------------------------------------

func test_rage_resistance_damage_and_duration() -> void:
	var barbarian := _at("class.barbarian", 2)
	var manager := _fight(barbarian, [15, 6, 1, 1, 1, 1, 1, 1])
	var hero := _hero(manager)
	var goblin := _enemy(manager)
	goblin.position = hero.position + Vector2i(1, 0)
	var rage := _feature(manager, hero, "rage")
	assert_true(rage["ok"], "Fúria: %s" % rage["error"])
	assert_true(CombatFeatures.is_raging(hero), "Em Fúria")
	assert_true("slashing" in hero.all_resistances(), "Resistência a cortante")
	assert_eq(barbarian.resource_spent("rage"), 1, "Gastou um uso")
	var attack := manager.submit({"type": "attack", "actor": hero.id, "target": goblin.id, "attack_id": "item.greataxe"})
	var event: Dictionary = _events(attack, "attack")[0]
	assert_eq(event["damage"], 6 + hero.modifiers[Ability.STRENGTH] + 2, "Dano da Fúria +2 no ataque de Força")
	assert_true(not manager.spell_error(hero, "x").is_empty(), "Sem magias em Fúria")
	manager.submit({"type": "end_turn", "actor": hero.id})
	while not manager.is_party_turn() and manager.state == CombatManager.State.IN_PROGRESS:
		manager.run_enemy_turn()
	assert_true(CombatFeatures.is_raging(hero), "Atacou no turno: a Fúria continua")
	manager.submit({"type": "end_turn", "actor": hero.id})
	assert_true(not CombatFeatures.is_raging(hero), "Sem atacar nem prolongar, a Fúria termina")


func test_reckless_attack_danger_sense_and_relentless_rage() -> void:
	var barbarian := _at("class.barbarian", 11)
	var manager := _fight(barbarian, [20])
	var hero := _hero(manager)
	var goblin := _enemy(manager)
	goblin.position = hero.position + Vector2i(1, 0)
	assert_true(_feature(manager, hero, "reckless")["ok"], "Ataque Imprudente")
	var greataxe := hero.get_attack("item.greataxe")
	assert_true("ataque imprudente" in manager.attack_advantage(hero, goblin, greataxe)["advantage"], "Vantagem com Força")
	assert_true("alvo imprudente" in manager.attack_advantage(goblin, hero, goblin.attacks[0])["advantage"], "Inimigos com vantagem")
	assert_eq(CombatFeatures.save_advantage(hero, Ability.DEXTERITY), 1, "Sentido de Perigo")
	_feature(manager, hero, "rage")
	var events: Array[Dictionary] = []
	manager._apply_damage(hero, hero.hp, events, {"type": "test"})
	assert_true(hero.is_up() and hero.hp == 22, "Fúria Implacável: volta com o dobro do nível (22)")
	assert_eq(CharacterSheet.build(barbarian, _e()._registry()).speed, 40, "Movimento Rápido: +3 m")


func test_brutal_strike_frenzy_retaliation_and_presence() -> void:
	var barbarian := _at("class.barbarian", 14)
	var manager := _fight(barbarian, [15, 6, 5, 3, 3, 3, 1, 1])
	var hero := _hero(manager)
	var goblin := _enemy(manager)
	goblin.position = hero.position + Vector2i(1, 0)
	manager.submit({"type": "option", "actor": hero.id, "key": "brutal", "value": "forceful"})
	_feature(manager, hero, "rage")
	_feature(manager, hero, "reckless")
	var start := goblin.position
	var result := manager.submit({"type": "attack", "actor": hero.id, "target": goblin.id, "attack_id": "item.greataxe"})
	var event: Dictionary = _events(result, "attack")[0]
	assert_true(str(event["features"]).contains("Golpe Brutal") and str(event["features"]).contains("Frenesi"),
			"Golpe Brutal e Frenesi: %s" % event["features"])
	if goblin.is_up():
		assert_eq(goblin.position, start + Vector2i(3, 0), "Golpe Forte empurra 4,5 m")
	var other := _enemy(manager, manager.living(Combatant.Team.ENEMY).size() - 1)
	other.position = hero.position + Vector2i(0, 1)
	var events: Array[Dictionary] = []
	hero.reaction_available = true
	CombatFeatures.on_damaged_by_attack(manager, hero, other, events)
	assert_true(events.any(func(e: Dictionary) -> bool: return e.get("feature") == "retaliation"), "Retaliação")
	var presence := _feature(manager, hero, "intimidating_presence")
	assert_true(presence["ok"] or str(presence["error"]).contains("bônus"), "Presença Intimidadora disponível no nível 14")


func test_primal_champion() -> void:
	var barbarian := _at("class.barbarian", 20)
	var sheet := CharacterSheet.build(barbarian, _e()._registry())
	assert_eq(sheet.scores[Ability.STRENGTH], mini(25, barbarian.ability_score(Ability.STRENGTH) + 4), "Campeão Primal: Força +4")


# --- Guerreiro -------------------------------------------------------------------------------------

func test_second_wind_action_surge_and_indomitable() -> void:
	var fighter := _at("class.fighter", 9, "background.sage")
	var manager := _fight(fighter, [7, 1, 18])
	var hero := _hero(manager)
	hero.hp = 10
	var wind := _feature(manager, hero, "second_wind")
	assert_true(wind["ok"], "Retomar o Fôlego")
	assert_eq(hero.hp, 10 + 7 + 9, "1d10 + nível de guerreiro")
	manager.submit({"type": "dodge", "actor": hero.id})
	var surge := _feature(manager, hero, "action_surge")
	assert_true(surge["ok"] and manager.action_available, "Surto de Ação devolve a ação")
	var spell_id: String = fighter.choice("bg.cantrips")[0]
	assert_true(manager.spell_error(hero, spell_id).contains("Surto"), "A ação do Surto não pode ser Magia")
	var save := manager._roll_save(hero, Ability.INTELLIGENCE, 20)
	assert_true(save.success, "Indomável refaz o teste com +9 (1 -> 18)")


func test_champion_critical_studied_attacks_and_heroic_warrior() -> void:
	var fighter := _at("class.fighter", 13)
	var manager := _fight(fighter, [19, 4, 4])
	var hero := _hero(manager)
	var goblin := _enemy(manager)
	goblin.position = hero.position + Vector2i(1, 0)
	var result := manager.submit({"type": "attack", "actor": hero.id, "target": goblin.id, "attack_id": "item.longsword"})
	assert_true(_events(result, "attack")[0]["roll"]["critical"], "Crítico Aprimorado: 19 é crítico")
	var miss := _fight(_at("class.fighter", 13), [1, 1, 1, 1])
	hero = _hero(miss)
	goblin = _enemy(miss)
	goblin.position = hero.position + Vector2i(1, 0)
	var missed := miss.submit({"type": "attack", "actor": hero.id, "target": goblin.id, "attack_id": "item.longsword"})
	assert_true(_events(missed, "feature").any(func(e: Dictionary) -> bool: return e["feature"] == "heroic_inspiration"),
			"Guerreiro Heroico rola de novo o ataque que errou")
	assert_true("ataques estudados" in miss.attack_advantage(hero, goblin, hero.get_attack("item.longsword"))["advantage"],
			"Ataques Estudados: vantagem depois de errar")


func test_survivor_heroic_rally() -> void:
	var fighter := _at("class.fighter", 18)
	var manager := _fight(fighter, [])
	var hero := _hero(manager)
	hero.hp = 10
	var events: Array[Dictionary] = []
	CombatFeatures.on_turn_start(manager, hero, events)
	assert_eq(hero.hp, 10 + 5 + hero.modifiers[Ability.CONSTITUTION], "Reunião Heroica: 5 + Constituição")


# --- Ladino ---------------------------------------------------------------------------------------

func test_sneak_attack_steady_aim_and_cunning_strike() -> void:
	var rogue := _at("class.rogue", 5)
	var manager := _fight(rogue, [15, 15, 3, 2, 2, 1])
	var hero := _hero(manager)
	var goblin := _enemy(manager)
	goblin.position = hero.position + Vector2i(1, 0)
	manager.submit({"type": "option", "actor": hero.id, "key": "cunning", "value": "trip"})
	assert_true(_feature(manager, hero, "steady_aim")["ok"], "Mira Firme")
	var result := manager.submit({"type": "attack", "actor": hero.id, "target": goblin.id, "attack_id": "item.shortsword"})
	var event: Dictionary = _events(result, "attack")[0]
	assert_true(str(event["features"]).contains("Ataque Furtivo"), "Ataque Furtivo com vantagem")
	assert_eq(event["damage"], 3 + hero.modifiers[Ability.DEXTERITY] + 2 + 2, "3d6 do Ataque Furtivo menos 1d6 da Rasteira")
	assert_true(goblin.has_condition("prone") or not goblin.is_up(), "Rasteira derruba (Destreza 1)")


func test_uncanny_dodge_evasion_elusive_and_reflexes() -> void:
	var rogue := _at("class.rogue", 18)
	var manager := _fight(rogue, [])
	var hero := _hero(manager)
	var goblin := _enemy(manager)
	var damage := CombatFeatures.incoming_attack_damage(manager, hero, goblin, goblin.attacks[0], 10, [] as Array[Dictionary])
	assert_eq(damage, 5, "Esquiva Sobrenatural: metade")
	hero.effects.append({"kind": "reckless", "source": hero.id, "spell": "x", "on": "none", "actor": "", "count": 0})
	assert_eq(manager.attack_advantage(goblin, hero, goblin.attacks[0])["state"], D20Test.Advantage.NONE, "Elusivo: sem vantagem contra")
	var thief := _at("class.rogue", 17)
	var other := _fight(thief, [])
	assert_eq(other.turn_order.count(_hero(other)), 2, "Reflexos de Ladrão: dois turnos na primeira rodada")
	assert_eq(CharacterSheet.build(rogue, _e()._registry()).saving_throws[Ability.WISDOM]["proficient"], true,
			"Mente Escorregadia: proficiência em Sabedoria")


# --- Monge ----------------------------------------------------------------------------------------

func test_martial_arts_flurry_and_patient_defense() -> void:
	var monk := _at("class.monk", 2)
	var manager := _fight(monk, [15, 4, 15, 4, 15, 4])
	var hero := _hero(manager)
	var goblin := _enemy(manager)
	goblin.position = hero.position + Vector2i(1, 0)
	var unarmed := hero.get_attack("attack.unarmed_strike")
	assert_eq(unarmed["ability"], Ability.DEXTERITY, "Artes Marciais: Destreza no desarmado")
	assert_true(str(unarmed["damage"]).begins_with("1d6"), "Dado de Artes Marciais d6")
	var flurry := _feature(manager, hero, "flurry", goblin)
	assert_true(flurry["ok"], "Rajada de Golpes: %s" % flurry["error"])
	assert_eq(_events(flurry, "attack").size(), 2, "Dois ataques desarmados")
	assert_eq(monk.resource_spent("focus"), 1, "Um ponto de Foco")
	assert_eq(CharacterSheet.build(monk, _e()._registry()).speed, 40, "Movimento sem Armadura: +3 m")
	var other := _fight(_at("class.monk", 2), [])
	hero = _hero(other)
	assert_true(_feature(other, hero, "patient_defense_focus")["ok"], "Defesa Paciente com Foco")
	assert_true(other.disengaged and not hero.effects_of("dodging").is_empty(), "Desengajar e Esquivar")


func test_stunning_strike_deflect_and_metabolism() -> void:
	var monk := _at("class.monk", 5)
	var manager := _fight(monk, [15, 4, 1])
	var hero := _hero(manager)
	var goblin := _enemy(manager)
	goblin.position = hero.position + Vector2i(1, 0)
	var result := manager.submit({"type": "attack", "actor": hero.id, "target": goblin.id, "attack_id": "attack.unarmed_strike"})
	assert_true(goblin.has_condition("stunned") or not goblin.is_up(), "Golpe Atordoante: falhou e ficou Atordoado")
	assert_true(_events(result, "feature").any(func(e: Dictionary) -> bool: return e["feature"] == "stunning_strike"), "Evento")
	hero.reaction_available = true
	var reduced := CombatFeatures.incoming_attack_damage(manager, hero, goblin, goblin.attacks[0], 50, [] as Array[Dictionary])
	assert_true(reduced < 50 and not hero.reaction_available, "Desviar Ataques reduz o dano")
	var tired := _at("class.monk", 5)
	ClassFeatures.spend(tired, "focus", 3)
	_fight(tired, [3])
	assert_eq(tired.resource_spent("focus"), 0, "Metabolismo Sobrenatural recupera o Foco na iniciativa")


func test_evasion_against_dex_save_spells() -> void:
	var rogue := _at("class.rogue", 7)
	var manager := _fight(rogue, [20, 6, 6, 6])
	var hero := _hero(manager)
	var caster := _enemy(manager)
	var entry: Dictionary = _e()._registry().get_entry("spell", "spell.burning_hands")
	caster.spells.append({"id": entry["id"], "name": entry["name"], "level": 1, "entry": entry, "dc": 10, "attack": 2, "modifier": 0, "free": ""})
	var events: Array[Dictionary] = []
	var hp := hero.hp
	manager._resolve_spell_on(caster, caster.spells[0], hero, 1, events)
	assert_eq(hero.hp, hp, "Evasão: sucesso em Destreza = nenhum dano")
