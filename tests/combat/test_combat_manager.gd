extends "res://tests/base_test.gd"
## CombatManager: iniciativa, turnos, validação de comandos, movimento, ataques,
## IA dos inimigos, fim do combate e aplicação de resultados.

const FACTORY_TESTS := preload("res://tests/characters/test_character_factory.gd")

var registry: ContentRegistry


func _registry() -> ContentRegistry:
	if registry == null:
		registry = ContentRegistry.new()
		registry.load_all()
	return registry


func _hero(rogue: bool = false) -> CharacterData:
	var fixtures := FACTORY_TESTS.new()
	return CharacterFactory.create(fixtures.rogue_choices() if rogue else fixtures.fighter_choices(), _registry())[0]


func _monster(monster_id: String, index: int = 1, total: int = 1) -> Combatant:
	return Combatant.from_monster(_registry().get_entry("monster", monster_id), index, total)


## Combate pronto: herói (Guerreiro) contra os inimigos dados, com dados roteirizados.
func _combat(enemies: Array[Combatant], dice: Array[int], hero: CharacterData = null,
		allow_flee: bool = true) -> CombatManager:
	var manager := CombatManager.new()
	var party: Array[Combatant] = [Combatant.from_character(hero if hero != null else _hero(), _registry())]
	manager.setup(party, enemies, Vector2i(12, 8), allow_flee, DiceRoller.scripted(dice))
	return manager


func _hero_unit(manager: CombatManager) -> Combatant:
	return manager.living(Combatant.Team.PARTY)[0]


func test_combatant_from_character_and_monster() -> void:
	var hero := Combatant.from_character(_hero(), _registry())
	assert_eq([hero.max_hp, hero.hp, hero.armor_class, hero.speed_feet], [12, 12, 18, 30], "Guerreiro: PV, CA e deslocamento")
	assert_true(not hero.get_attack("item.longsword").is_empty(), "Ataque com a espada longa")
	assert_true(not hero.get_attack("attack.unarmed_strike").is_empty(), "Ataque desarmado sempre disponível")
	var wolf := _monster("monster.wolf")
	assert_eq([wolf.max_hp, wolf.armor_class, wolf.speed_feet, wolf.initiative_bonus, wolf.xp], [11, 12, 40, 2, 50], "Lobo do SRD")
	assert_true(wolf.has_trait("trait.pack_tactics"), "Táticas de Matilha implementadas")
	var rogue := Combatant.from_character(_hero(true), _registry())
	var dagger_count := rogue.attacks.filter(func(a: Dictionary) -> bool: return a["id"] == "item.dagger").size()
	assert_eq(dagger_count, 1, "Duas adagas no inventário geram um único ataque")


func test_initiative_order_and_tie_break() -> void:
	# Herói rola 10 (+1 = 11); lobo rola 9 (+2 = 11): empate, vence o maior bônus (lobo).
	var manager := _combat([_monster("monster.wolf")] as Array[Combatant], [10, 9])
	var events := manager.start()
	assert_eq(manager.turn_order[0].name, "Lobo", "Empate de iniciativa: maior bônus age primeiro")
	assert_eq(events.filter(func(e: Dictionary) -> bool: return e["type"] == "initiative").size(), 2, "Uma rolagem por participante")
	assert_eq(manager.state, CombatManager.State.IN_PROGRESS, "Combate em andamento")
	assert_true(not manager.is_party_turn(), "Lobo começa")


func test_positions_on_opposite_sides() -> void:
	var manager := _combat([_monster("monster.wolf", 1, 2), _monster("monster.wolf", 2, 2)] as Array[Combatant], [20, 1, 1])
	assert_eq(_hero_unit(manager).position.x, 1, "Grupo à esquerda")
	for unit in manager.living(Combatant.Team.ENEMY):
		assert_eq(unit.position.x, 10, "Inimigos à direita")
	assert_true(manager.combatants[1].position != manager.combatants[2].position, "Cada um numa casa")


func test_commands_are_validated() -> void:
	var manager := _combat([_monster("monster.wolf")] as Array[Combatant], [20, 1])
	var before := manager.submit({"type": "end_turn", "actor": "x"})
	assert_true(not before["ok"], "Antes de começar, nada é aceito")
	manager.start()
	var hero := _hero_unit(manager)
	var wolf := manager.living(Combatant.Team.ENEMY)[0]
	assert_true(manager.is_party_turn(), "Herói começa (20 natural)")
	assert_true(not manager.submit({"type": "end_turn", "actor": wolf.id})["ok"], "Fora do turno é rejeitado")
	assert_true(not manager.submit({"type": "dance", "actor": hero.id})["ok"], "Comando desconhecido")
	var far := manager.submit({"type": "attack", "actor": hero.id, "target": wolf.id, "attack_id": "item.longsword"})
	assert_true(not far["ok"] and far["error"].contains("alcance"), "Ataque corpo a corpo fora de alcance")
	var ally := manager.submit({"type": "attack", "actor": hero.id, "target": hero.id, "attack_id": "item.longsword"})
	assert_true(not ally["ok"], "Não pode atacar a si mesmo")


func test_movement_rules() -> void:
	var manager := _combat([_monster("monster.wolf")] as Array[Combatant], [20, 1])
	manager.start()
	var hero := _hero_unit(manager)
	var start := hero.position
	var too_far := manager.submit({"type": "move", "actor": hero.id, "to": start + Vector2i(7, 0)})
	assert_true(not too_far["ok"], "30 pés = 6 casas; 7 casas é longe demais")
	var ok := manager.submit({"type": "move", "actor": hero.id, "to": start + Vector2i(4, 2)})
	assert_true(ok["ok"], "Diagonal custa 5 pés por casa: 4 casas")
	assert_eq(manager.movement_left_feet, 10, "Restam 10 pés")
	assert_true(not manager.submit({"type": "move", "actor": hero.id, "to": hero.position + Vector2i(3, 0)})["ok"],
			"Sem movimento suficiente")
	var wolf := manager.living(Combatant.Team.ENEMY)[0]
	assert_true(not manager.submit({"type": "move", "actor": hero.id, "to": wolf.position})["ok"], "Casa ocupada")
	assert_true(not manager.submit({"type": "move", "actor": hero.id, "to": Vector2i(-1, 0)})["ok"], "Fora da arena")


func test_cannot_pass_through_enemies() -> void:
	var manager := _combat([_monster("monster.wolf")] as Array[Combatant], [20, 1])
	manager.start()
	var hero := _hero_unit(manager)
	var wolf := manager.living(Combatant.Team.ENEMY)[0]
	# Corredor de 1 casa: herói em (0,0), lobo em (1,0), arena 3x1.
	manager.arena_size = Vector2i(3, 1)
	hero.position = Vector2i(0, 0)
	wolf.position = Vector2i(1, 0)
	assert_true(not manager.reachable_cells(hero).has(Vector2i(2, 0)), "Não atravessa o inimigo")


func test_attack_hits_kills_and_wins() -> void:
	# Herói 20 na iniciativa; lobo 1. Herói ataca: 15 + 5 = 20 acerta CA 12; dano 8 + 3 = 11 mata (11 PV).
	var manager := _combat([_monster("monster.wolf")] as Array[Combatant], [20, 1, 15, 8])
	manager.start()
	var hero := _hero_unit(manager)
	var wolf := manager.living(Combatant.Team.ENEMY)[0]
	hero.position = wolf.position + Vector2i(-1, 0)
	var result := manager.submit({"type": "attack", "actor": hero.id, "target": wolf.id, "attack_id": "item.longsword"})
	assert_true(result["ok"], "Ataque aceito: %s" % result["error"])
	var attack: Dictionary = result["events"][0]
	assert_true(attack["roll"]["hit"] and attack["damage"] == 11, "Acerta e causa 11")
	assert_eq(wolf.hp, 0, "Lobo com 0 PV")
	assert_eq(manager.state, CombatManager.State.FINISHED, "Combate termina")
	assert_eq(manager.outcome, CombatManager.Outcome.VICTORY, "Vitória")
	assert_true(not manager.submit({"type": "end_turn", "actor": hero.id})["ok"], "Nada é aceito depois do fim")
	var character := hero.character
	var xp_before := character.experience
	manager.apply_results_to_party()
	manager.apply_results_to_party()
	assert_eq(character.experience, xp_before + 50, "XP do lobo aplicado uma única vez")
	assert_eq(character.current_hp, 12, "PV do personagem atualizados")


func test_one_action_per_turn() -> void:
	# Herói erra (2 + 5 = 7 < 12) e tenta atacar de novo.
	var manager := _combat([_monster("monster.wolf")] as Array[Combatant], [20, 1, 2])
	manager.start()
	var hero := _hero_unit(manager)
	var wolf := manager.living(Combatant.Team.ENEMY)[0]
	hero.position = wolf.position + Vector2i(-1, 0)
	var first := manager.submit({"type": "attack", "actor": hero.id, "target": wolf.id, "attack_id": "item.longsword"})
	assert_true(first["ok"] and not first["events"][0]["roll"]["hit"], "Primeiro ataque erra")
	var second := manager.submit({"type": "attack", "actor": hero.id, "target": wolf.id, "attack_id": "item.longsword"})
	assert_true(not second["ok"] and second["error"].contains("ação"), "Segunda ação no mesmo turno é rejeitada")
	assert_true(manager.submit({"type": "move", "actor": hero.id, "to": hero.position + Vector2i(0, 1)})["ok"],
			"Ainda pode se mover depois de atacar")


func test_enemy_ai_approaches_and_attacks() -> void:
	# Lobo age primeiro (20); herói 1. Lobo anda até o herói e morde: 10 + 4 = 14 < CA 18 erra.
	var manager := _combat([_monster("monster.wolf")] as Array[Combatant], [1, 20, 10])
	manager.start()
	var hero := _hero_unit(manager)
	var wolf := manager.living(Combatant.Team.ENEMY)[0]
	var events := manager.run_enemy_turn()
	var types := events.map(func(e: Dictionary) -> String: return e["type"])
	assert_true("move" in types and "attack" in types, "Lobo se move e ataca: %s" % str(types))
	assert_eq(Attack.grid_distance_feet(wolf.position, hero.position), 5, "Termina adjacente ao herói")
	assert_true(manager.is_party_turn(), "Turno passa para o herói")


func test_pack_tactics_gives_advantage() -> void:
	var wolves: Array[Combatant] = [_monster("monster.wolf", 1, 2), _monster("monster.wolf", 2, 2)]
	var manager := _combat(wolves, [1, 20, 19, 3, 15])
	manager.start()
	var hero := _hero_unit(manager)
	var attacker := manager.current()
	var other := wolves[1] if attacker == wolves[0] else wolves[0]
	hero.position = Vector2i(5, 4)
	attacker.position = Vector2i(6, 4)
	other.position = Vector2i(5, 5)
	var adv := manager.attack_advantage(attacker, hero, attacker.get_attack("attack.wolf_bite"))
	assert_eq(adv["state"], D20Test.Advantage.ADVANTAGE, "Aliado adjacente ao alvo dá vantagem")
	other.position = Vector2i(9, 0)
	adv = manager.attack_advantage(attacker, hero, attacker.get_attack("attack.wolf_bite"))
	assert_eq(adv["state"], D20Test.Advantage.NONE, "Sem aliado perto do alvo, sem vantagem")


func test_ranged_disadvantage_rules() -> void:
	var manager := _combat([_monster("monster.goblin_warrior")] as Array[Combatant], [20, 1], _hero(true))
	manager.start()
	var hero := _hero_unit(manager)
	var goblin := manager.living(Combatant.Team.ENEMY)[0]
	var bow := hero.get_attack("item.shortbow")
	hero.position = Vector2i(0, 0)
	goblin.position = Vector2i(5, 0)
	assert_eq(manager.attack_advantage(hero, goblin, bow)["state"], D20Test.Advantage.NONE, "25 pés: sem penalidade")
	goblin.position = Vector2i(1, 1)
	var close := manager.attack_advantage(hero, goblin, bow)
	assert_eq(close["state"], D20Test.Advantage.DISADVANTAGE, "Inimigo adjacente: desvantagem à distância")
	var thrown := hero.get_attack("item.dagger.thrown")
	goblin.position = Vector2i(6, 0)
	assert_eq(manager.attack_advantage(hero, goblin, thrown)["state"], D20Test.Advantage.DISADVANTAGE,
			"Adaga arremessada a 30 pés: além dos 20 pés normais")
	goblin.position = Vector2i(12, 0)
	assert_true(manager.attack_error(hero, goblin, thrown).is_empty(), "60 pés: no limite do alcance máximo")
	goblin.position = Vector2i(13, 0)
	assert_true(manager.attack_error(hero, goblin, thrown).contains("alcance máximo"), "65 pés: além dos 60, inválido")


func test_flee_rules() -> void:
	var manager := _combat([_monster("monster.wolf")] as Array[Combatant], [20, 1])
	manager.start()
	var hero := _hero_unit(manager)
	assert_true(manager.submit({"type": "flee", "actor": hero.id})["ok"], "Fuga permitida")
	assert_eq(manager.outcome, CombatManager.Outcome.FLED, "Resultado: fuga")
	manager.apply_results_to_party()
	assert_eq(hero.character.experience, 0, "Fuga não dá XP")

	var locked := _combat([_monster("monster.wolf")] as Array[Combatant], [20, 1], null, false)
	locked.start()
	assert_true(not locked.submit({"type": "flee", "actor": _hero_unit(locked).id})["ok"], "Fuga proibida neste encontro")


func test_defeat_when_party_falls() -> void:
	# Lobo primeiro (20); herói 1. Mordida crítica (20): dano 2d6+2 = 6 + 6 + 2 = 14 >= 12 PV.
	var manager := _combat([_monster("monster.wolf")] as Array[Combatant], [1, 20, 20, 6, 6])
	manager.start()
	var hero := _hero_unit(manager)
	var events := manager.run_enemy_turn()
	assert_true(events.any(func(e: Dictionary) -> bool: return e["type"] == "attack" and e["roll"]["critical"]), "Crítico")
	assert_eq(hero.hp, 0, "Herói cai")
	assert_eq(manager.outcome, CombatManager.Outcome.DEFEAT, "Derrota")
	manager.apply_results_to_party()
	assert_eq(hero.character.current_hp, 0, "PV 0 aplicados ao personagem")


func test_resistance_applies_in_combat() -> void:
	var dwarf := _hero(true)  # Anão: resistência a veneno.
	var unit := Combatant.from_character(dwarf, _registry())
	assert_true("poison" in unit.resistances, "Resistência da espécie chega ao combate")


func test_full_combats_always_finish() -> void:
	for seed_value in range(1, 31):
		for rogue in [false, true]:
			var manager := CombatManager.new()
			var party: Array[Combatant] = [Combatant.from_character(_hero(rogue), _registry())]
			var enemies: Array[Combatant] = [_monster("monster.wolf"), _monster("monster.goblin_warrior")]
			manager.setup(party, enemies, Vector2i(12, 8), true, DiceRoller.new(seed_value))
			manager.start()
			var steps := 0
			while manager.state == CombatManager.State.IN_PROGRESS and steps < 500:
				steps += 1
				if manager.is_party_turn():
					_auto_party_turn(manager)
				else:
					manager.run_enemy_turn()
				for unit in manager.combatants:
					assert_true(unit.hp >= 0 and unit.hp <= unit.max_hp, "PV dentro dos limites (semente %d)" % seed_value)
			assert_eq(manager.state, CombatManager.State.FINISHED, "Combate terminou (semente %d)" % seed_value)
			assert_true(manager.outcome in [CombatManager.Outcome.VICTORY, CombatManager.Outcome.DEFEAT],
					"Termina em vitória ou derrota (semente %d)" % seed_value)
			assert_true(manager.round_number < 30, "Dura menos de 30 rodadas (semente %d)" % seed_value)


## Política simples do jogador para a simulação: aproximar-se do inimigo mais próximo e atacar.
func _auto_party_turn(manager: CombatManager) -> void:
	var hero := manager.current()
	var enemies := manager.living(Combatant.Team.ENEMY)
	enemies.sort_custom(func(a: Combatant, b: Combatant) -> bool:
		return Attack.grid_distance_feet(hero.position, a.position) < Attack.grid_distance_feet(hero.position, b.position))
	var target: Combatant = enemies[0]
	var melee := hero.attacks[0]
	if not manager.attack_error(hero, target, melee).is_empty():
		var best := hero.position
		var reachable := manager.reachable_cells(hero)
		for cell: Vector2i in reachable:
			if Attack.grid_distance_feet(cell, target.position) < Attack.grid_distance_feet(best, target.position):
				best = cell
		if best != hero.position:
			manager.submit({"type": "move", "actor": hero.id, "to": best})
	if manager.attack_error(hero, target, melee).is_empty():
		manager.submit({"type": "attack", "actor": hero.id, "target": target.id, "attack_id": melee["id"]})
	if manager.state == CombatManager.State.IN_PROGRESS:
		manager.submit({"type": "end_turn", "actor": hero.id})
