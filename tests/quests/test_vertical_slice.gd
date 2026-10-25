extends "res://tests/base_test.gd"
## Fase 7: a aventura de demonstração de ponta a ponta — vila, NPC, missão, viagem com encontro não
## combativo, conversa na Clareira, combate com o chefe, volta, recompensa, salvamento e conclusão.

const FACTORY_TESTS := preload("res://tests/characters/test_character_factory.gd")
const VILLAGE := "res://scenes/world/village.tscn"
const CLEARING := "res://scenes/world/test_map.tscn"
const FOREST := "res://scenes/world/forest_brook.tscn"
const ENDING := "res://scenes/menus/ending_screen.tscn"

var exploration: Node
var party: Node
var quests: Node
var registry: ContentRegistry


func _begin() -> CharacterData:
	exploration = tree.root.get_node("ExplorationManager")
	party = tree.root.get_node("PartyManager")
	quests = tree.root.get_node("QuestManager")
	registry = tree.root.get_node("Content").registry
	exploration.reset()
	quests.reset()
	exploration.scene_changes_enabled = false
	var hero: CharacterData = CharacterFactory.create(FACTORY_TESTS.new().fighter_choices(), registry)[0]
	party.start_new_party(hero)
	return hero


func _end() -> void:
	exploration.scene_changes_enabled = true
	exploration.reset()
	quests.reset()
	party.clear()


func _open(path: String) -> ExplorationMap:
	var map: ExplorationMap = (load(path) as PackedScene).instantiate()
	tree.root.add_child(map)
	await tree.process_frame
	return map


func _close(node: Node) -> void:
	node.queue_free()
	await tree.process_frame


func _objective(map: ExplorationMap) -> String:
	return (map.get_node("%Hud") as ExplorationHud).objective_text()


func test_full_adventure_from_village_to_ending() -> void:
	var hero := _begin()
	exploration.intro_message = "Você chega à Vila de Ribeira."
	var map := await _open(VILLAGE)
	var hud: ExplorationHud = map.get_node("%Hud")
	assert_true(hud.get_message_text().contains("Ribeira"), "Abertura da aventura ao chegar")
	map.handle_interact()
	assert_true(_objective(map).contains("Fale com Ione"), "Objetivo inicial claro: %s" % _objective(map))
	(map.get_node("Objects/Ione") as Interactable).interact()
	assert_eq(hud.get_speaker_name(), "Ione", "Ione conversa")
	var potions: int = party.inventory.count(Inventory.POTION)
	map.choose_dialogue_option(0)
	map.choose_dialogue_option(0)
	assert_eq(party.inventory.count(Inventory.POTION), potions + 2, "Ione entrega duas poções")
	assert_eq(quests.log.status("quest.goblin_chief"), QuestLog.Status.ACTIVE, "Missão principal aceita")
	map.handle_interact()
	assert_true(_objective(map).contains("Amara"), "Próximo passo: falar com Amara (%s)" % _objective(map))
	await _close(map)

	# Estrada da Vila: o primeiro trecho traz sempre a criança perdida (encontro não combativo).
	assert_eq(exploration.begin_travel("route.village_road", 7), OK, "Viagem pela Estrada da Vila")
	var travel: TravelSystem = exploration.current_travel()
	var first := travel.advance(party.members, registry, party.inventory)
	assert_eq([first["kind"], first["id"]], ["event", "event.lost_child"], "Encontro roteirizado no primeiro trecho")
	exploration.store_travel(travel)
	assert_true(exploration.once_events.has("event.lost_child"), "Não se repete nas próximas viagens")

	map = await _open(CLEARING)
	(map.get_node("Objects/Amara") as Interactable).interact()
	var amara_text := (map.get_node("%Hud") as ExplorationHud).get_message_text()
	assert_true(amara_text.contains("Garra-Rubra"), "Amara indica o acampamento do chefe: %s" % amara_text)
	assert_true(quests.log.is_objective_done("quest.goblin_chief", "talk_amara"), "Objetivo de conversa cumprido")
	map.end_dialogue()
	map.handle_interact()
	assert_true(_objective(map).contains("Garra-Rubra"), "Próximo passo: derrotar o chefe (%s)" % _objective(map))
	await _close(map)

	var forest := await _open(FOREST)
	assert_true(forest.has_node("Objects/ChiefEncounter"), "Garra-Rubra espera no acampamento")
	await _close(forest)
	exploration.begin_encounter("encounter.goblin_chief", "forest_brook.goblin_chief", FOREST, Vector2(400, 210))
	exploration.finish_encounter(CombatManager.Outcome.VICTORY, 250)
	assert_true(exploration.is_resolved("forest_brook.goblin_chief"), "Chefe derrotado não volta")

	map = await _open(VILLAGE)
	map.handle_interact()
	assert_true(_objective(map).contains("fale com Ione"), "Objetivo: voltar a Ione (%s)" % _objective(map))
	var gold: int = party.inventory.gold
	(map.get_node("Objects/Ione") as Interactable).interact()
	map.choose_dialogue_option(0)
	assert_eq(quests.log.status("quest.goblin_chief"), QuestLog.Status.COMPLETED, "Missão principal concluída")
	assert_eq(party.inventory.gold, gold + 50, "Recompensa em ouro")
	map.choose_dialogue_option(0)
	assert_true(not map.is_in_dialogue(), "Conversa encerrada")
	assert_true(not exploration.ending_lines.is_empty(), "Recompensas guardadas para a conclusão")
	await _close(map)

	var ending: EndingScreen = (load(ENDING) as PackedScene).instantiate()
	tree.root.add_child(ending)
	await tree.process_frame
	var summary := EndingScreen.summary_text()
	assert_true(summary.contains(hero.name) and summary.contains("A Garra-Rubra"), "Resumo do herói e das missões")
	assert_true(ending.has_node("CenterContainer") or ending.get_child_count() > 0, "Tela de conclusão montada")
	await _close(ending)
	_end()


func test_slice_world_is_connected() -> void:
	_begin()
	registry = tree.root.get_node("Content").registry
	for route_id in registry.ids("route"):
		var route := registry.get_entry("route", route_id)
		var scene: PackedScene = load(registry.get_entry("map", route["to_map"])["scene"])
		var map: Node = scene.instantiate()
		assert_true(map.has_node("Entrances/%s" % route["to_entrance"]), "%s chega em %s" % [route_id, route["to_entrance"]])
		map.free()
	var travel_actions := []
	for path in [VILLAGE, CLEARING, FOREST]:
		var map: Node = (load(path) as PackedScene).instantiate()
		for node in map.get_node("Objects").get_children():
			if node is Interactable and (node as Interactable).action.begins_with("travel:"):
				travel_actions.append((node as Interactable).action.trim_prefix("travel:"))
		map.free()
	for route_id in ["route.village_road", "route.village_road_back", "route.east_road", "route.east_road_back"]:
		assert_true(route_id in travel_actions, "Há uma placa para %s" % route_id)
	assert_true(registry.get_entry("quest", "quest.goblin_chief").get("final", false), "Missão principal marcada como final")
	_end()


func test_goblin_chief_attacks_twice() -> void:
	var hero := _begin()
	var engine: Object = load("res://tests/combat/test_combat_engine.gd").new()
	engine.tree = tree
	var boss := Combatant.from_monster(registry.get_entry("monster", "monster.goblin_boss"), 1, 1)
	var manager: CombatManager = engine._combat(hero, [boss] as Array[Combatant], [2, 2] as Array[int])
	manager.submit({"type": "end_turn", "actor": manager.current().id})
	boss.position = manager.living(Combatant.Team.PARTY)[0].position + Vector2i(1, 0)
	var events := manager.run_enemy_turn()
	var attacks := events.filter(func(e: Dictionary) -> bool: return e["type"] == "attack")
	assert_eq(attacks.size(), 2, "Garra-Rubra usa os Ataques Múltiplos (2 golpes)")
	_end()


func test_new_game_starts_in_the_village_with_intro() -> void:
	_begin()
	var screen: Control = (load("res://scenes/menus/character_creation.tscn") as PackedScene).instantiate()
	tree.root.add_child(screen)
	await tree.process_frame
	assert_eq(screen.START_SCENE, VILLAGE, "Novo jogo começa na Vila de Ribeira")
	assert_true(str(screen.INTRO_TEXT).contains("Ione"), "Abertura diz com quem falar")
	screen.queue_free()
	await tree.process_frame
	_end()
