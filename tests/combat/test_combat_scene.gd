extends "res://tests/base_test.gd"
## Cena de combate + transição exploração ↔ combate: um combate completo pode ser iniciado,
## resolvido e encerrado sem quebrar o estado do jogo.

const SCENE := "res://scenes/combat/combat_scene.tscn"
const MAP_SCENE := "res://scenes/world/test_map.tscn"
const FACTORY_TESTS := preload("res://tests/characters/test_character_factory.gd")

var _scene: Control


func _hero() -> CharacterData:
	var fixtures := FACTORY_TESTS.new()
	return CharacterFactory.create(fixtures.fighter_choices(), tree.root.get_node("Content").registry)[0]


func _open(encounter_id: String, party: Array[CharacterData], roller: DiceRoller) -> void:
	_scene = (load(SCENE) as PackedScene).instantiate()
	_scene.ai_delay = 0.0
	_scene.setup(encounter_id, party, roller)
	tree.root.add_child(_scene)
	await tree.process_frame


func _close() -> void:
	_scene.queue_free()
	await tree.process_frame


func _manager() -> CombatManager:
	return _scene.get_manager()


## Joga pelo grupo usando só a API da cena (como cliques): aproxima-se e ataca até acabar.
func _play_until_finished() -> void:
	var guard := 0
	while _manager().state == CombatManager.State.IN_PROGRESS and guard < 200:
		guard += 1
		var hero := _manager().current()
		var enemy: Combatant = _manager().living(Combatant.Team.ENEMY)[0]
		if Attack.grid_distance_feet(hero.position, enemy.position) > 5:
			var best := hero.position
			var reachable := _manager().reachable_cells(hero)
			for cell: Vector2i in reachable:
				if Attack.grid_distance_feet(cell, enemy.position) < Attack.grid_distance_feet(best, enemy.position):
					best = cell
			if best != hero.position:
				_scene.click_cell(best)
		if _manager().state == CombatManager.State.IN_PROGRESS and _manager().is_party_turn() and _manager().action_available:
			_scene.click_cell(enemy.position)
		if _manager().state == CombatManager.State.IN_PROGRESS and _manager().is_party_turn():
			_scene.press_end_turn()


func test_scene_starts_combat_from_encounter() -> void:
	var hero := _hero()
	await _open("encounter.lone_wolf", [hero] as Array[CharacterData], DiceRoller.new(5))
	assert_eq(_manager().state, CombatManager.State.IN_PROGRESS, "Combate em andamento")
	assert_eq(_manager().combatants.size(), 2, "Herói e lobo")
	assert_true(_manager().is_party_turn(), "Turnos dos inimigos já foram executados até a vez do jogador")
	var log_text := (_scene.get_node("%Log") as RichTextLabel).get_parsed_text()
	assert_true(log_text.contains("lobo faminto") and log_text.contains("iniciativa"), "Registro mostra introdução e iniciativa")
	var order := (_scene.get_node("%TurnOrder") as RichTextLabel).get_parsed_text()
	assert_true(order.contains("Brena") and order.contains("Lobo"), "Ordem de iniciativa visível")
	await _close()


func test_invalid_click_shows_error_and_keeps_turn() -> void:
	await _open("encounter.lone_wolf", [_hero()] as Array[CharacterData], DiceRoller.new(5))
	var hero := _manager().current()
	var result: Dictionary = _scene.click_cell(hero.position + Vector2i(9, 0))
	assert_true(not result["ok"], "Casa longe demais é recusada")
	assert_true((_scene.get_node("%Status") as Label).text.contains("alcance"), "Mensagem de erro útil")
	assert_true(_manager().current() == hero, "Continua no turno do herói")
	await _close()


func test_full_combat_through_scene_and_result_panel() -> void:
	var hero := _hero()
	await _open("encounter.lone_wolf", [hero] as Array[CharacterData], DiceRoller.new(11))
	_play_until_finished()
	assert_eq(_manager().state, CombatManager.State.FINISHED, "Combate terminou")
	assert_true((_scene.get_node("%ResultPanel") as Control).visible, "Painel de resultado aparece")
	var label := (_scene.get_node("%ResultLabel") as Label).text
	if _manager().outcome == CombatManager.Outcome.VICTORY:
		assert_true(label.contains("Vitória") and label.contains("50 XP"), "Vitória com XP")
		assert_eq(hero.experience, 50, "XP aplicado ao personagem")
	else:
		assert_true(label.contains("Derrota"), "Derrota")
	assert_eq(hero.current_hp, _manager().combatants[0].hp if _manager().combatants[0].team == Combatant.Team.PARTY
			else _manager().combatants[1].hp, "PV do personagem = PV no fim do combate")
	assert_eq(CharacterFactory.validate(hero, tree.root.get_node("Content").registry), [] as Array[String],
			"Personagem continua válido depois do combate")
	await _close()


func test_flee_button() -> void:
	var hero := _hero()
	await _open("encounter.lone_wolf", [hero] as Array[CharacterData], DiceRoller.new(5))
	_scene.press_flee()
	assert_eq(_manager().outcome, CombatManager.Outcome.FLED, "Fugiu")
	assert_true((_scene.get_node("%ResultLabel") as Label).text.contains("fugiu"), "Resultado de fuga")
	await _close()


func test_unknown_encounter_reports_error() -> void:
	await _open("encounter.nao_existe", [_hero()] as Array[CharacterData], DiceRoller.new(1))
	assert_true((_scene.get_node("%ResultPanel") as Control).visible, "Erro visível")
	assert_true((_scene.get_node("%ResultLabel") as Label).text.contains("Encontro desconhecido"), "Mensagem útil")
	await _close()


func test_exploration_to_combat_and_back() -> void:
	var exploration: Node = tree.root.get_node("ExplorationManager")
	var party: Node = tree.root.get_node("PartyManager")
	exploration.reset()
	exploration.scene_changes_enabled = false
	var hero := _hero()
	party.start_new_party(hero)

	var map: ExplorationMap = (load(MAP_SCENE) as PackedScene).instantiate()
	tree.root.add_child(map)
	await tree.physics_frame
	var player: Player = map.get_node("%Player")
	var trigger: EncounterTrigger = map.get_node("Objects/WolfEncounter")
	var trigger_position := trigger.global_position
	player.global_position = trigger_position
	for i in 3:
		await tree.physics_frame
	assert_eq(exploration.pending_encounter_id, "encounter.lone_wolf", "Entrar na área inicia o encontro")
	assert_true(not player.input_enabled, "Jogador parado ao iniciar o combate")
	assert_eq(exploration.return_scene, MAP_SCENE, "Lembra o mapa de origem")
	map.queue_free()
	await tree.process_frame

	# Vitória: volta ao mapa na mesma posição, gatilho some, mensagem com retrato.
	hero.current_hp = 7
	var destination: String = exploration.finish_encounter(CombatManager.Outcome.VICTORY, 50)
	assert_eq(destination, MAP_SCENE, "Vitória volta ao mapa")
	map = (load(MAP_SCENE) as PackedScene).instantiate()
	tree.root.add_child(map)
	await tree.physics_frame
	player = map.get_node("%Player")
	assert_true(player.global_position.distance_to(trigger_position) < 1.0, "Volta na posição de onde saiu")
	assert_true(not map.has_node("Objects/WolfEncounter") or map.get_node("Objects/WolfEncounter").is_queued_for_deletion(),
			"Encontro vencido não volta")
	var hud: ExplorationHud = map.get_node("%Hud")
	assert_true(hud.is_message_open() and hud.get_message_text().contains("50 XP"), "Mensagem de vitória ao voltar")
	assert_eq(hud.get_speaker_name(), hero.name, "Fala com o nome do personagem")
	assert_true(hud.get_portrait() != null, "Fala com o retrato do personagem")
	assert_eq(hero.current_hp, 7, "PV do combate preservados na exploração")
	map.queue_free()
	await tree.process_frame

	exploration.scene_changes_enabled = true
	exploration.reset()
	party.clear()


func test_fled_trigger_does_not_fire_until_player_leaves() -> void:
	var exploration: Node = tree.root.get_node("ExplorationManager")
	var party: Node = tree.root.get_node("PartyManager")
	exploration.reset()
	exploration.scene_changes_enabled = false
	party.start_new_party(_hero())
	exploration.begin_encounter("encounter.ruin_goblin", "test_map.ruin_goblin", MAP_SCENE, Vector2(232, 408))
	exploration.finish_encounter(CombatManager.Outcome.FLED, 0)

	var map: ExplorationMap = (load(MAP_SCENE) as PackedScene).instantiate()
	tree.root.add_child(map)
	for i in 3:
		await tree.physics_frame
	assert_eq(exploration.pending_encounter_id, "", "Voltar dentro da área após fugir não reinicia o combate")
	var trigger: EncounterTrigger = map.get_node("Objects/GoblinEncounter")
	assert_true(not trigger.armed, "Gatilho desarmado até o jogador sair")
	var player: Player = map.get_node("%Player")
	player.global_position = Vector2(504, 300)
	for i in 3:
		await tree.physics_frame
	assert_true(trigger.armed, "Sair da área rearma o gatilho")
	map.queue_free()
	await tree.process_frame
	exploration.scene_changes_enabled = true
	exploration.reset()
	party.clear()


func test_defeat_returns_to_title_and_clears_party() -> void:
	var exploration: Node = tree.root.get_node("ExplorationManager")
	var party: Node = tree.root.get_node("PartyManager")
	exploration.scene_changes_enabled = false
	party.start_new_party(_hero())
	exploration.begin_encounter("encounter.lone_wolf", "test_map.lone_wolf", MAP_SCENE, Vector2.ZERO)
	var destination: String = exploration.finish_encounter(CombatManager.Outcome.DEFEAT, 0)
	assert_eq(destination, ExplorationManager.TITLE_SCENE, "Derrota leva ao título")
	assert_true(not party.has_party(), "Grupo limpo após a derrota")
	assert_true(not exploration.is_resolved("test_map.lone_wolf"), "Encontro não conta como resolvido")
	exploration.scene_changes_enabled = true
	exploration.reset()
