extends "res://tests/base_test.gd"
## Fluxo completo da Fase 4: placa no mapa -> viagem -> evento/combate -> retomada -> chegada
## no outro mapa, mais a fogueira de descanso. Sem trocar de cena de verdade.

const FACTORY_TESTS := preload("res://tests/characters/test_character_factory.gd")
const TRAVEL_SCENE := "res://scenes/travel/travel_scene.tscn"
const CLEARING := "res://scenes/world/test_map.tscn"
const FOREST := "res://scenes/world/forest_brook.tscn"

var exploration: Node
var party: Node


func _begin() -> CharacterData:
	exploration = tree.root.get_node("ExplorationManager")
	party = tree.root.get_node("PartyManager")
	exploration.reset()
	exploration.scene_changes_enabled = false
	var hero: CharacterData = CharacterFactory.create(FACTORY_TESTS.new().fighter_choices(), tree.root.get_node("Content").registry)[0]
	party.start_new_party(hero)
	return hero


func _end() -> void:
	exploration.scene_changes_enabled = true
	exploration.reset()
	party.clear()


func _open(path: String) -> Node:
	var scene: Node = (load(path) as PackedScene).instantiate()
	if scene.get("animations_enabled") != null:
		scene.set("animations_enabled", false)
	tree.root.add_child(scene)
	await tree.process_frame
	return scene


func _close(scene: Node) -> void:
	scene.queue_free()
	await tree.process_frame


func test_signpost_requires_confirmation_and_starts_travel() -> void:
	_begin()
	var map: ExplorationMap = await _open(CLEARING)
	var sign: Interactable = map.get_node("Objects/EastRoadSign")
	assert_eq(sign.action, "travel:route.east_road", "Placa leva à Estrada do Leste")
	sign.interact()
	var hud: ExplorationHud = map.get_node("%Hud")
	assert_true(hud.is_message_open() and hud.get_message_text().contains("Partir agora"), "Pergunta antes de partir")
	map.cancel_message()
	assert_true(not exploration.is_traveling(), "Esc cancela sem viajar")
	sign.interact()
	map.handle_interact()
	await tree.process_frame
	assert_true(exploration.is_traveling(), "Confirmar inicia a viagem")
	assert_eq(exploration.current_travel().route_id, "route.east_road", "Rota certa")
	await _close(map)
	_end()


func test_travel_scene_full_journey_with_combat_and_return() -> void:
	var hero := _begin()
	exploration.begin_travel("route.east_road", 5)
	var guard := 0
	var saw_combat := false
	var saw_event := false
	while exploration.is_traveling() and guard < 30:
		guard += 1
		var scene: Node = await _open(TRAVEL_SCENE)
		var travel: TravelSystem = scene.travel
		if travel.is_arrived(tree.root.get_node("Content").registry):
			var destination: String = exploration.finish_travel()
			assert_eq(destination, FOREST, "Chegada leva ao Bosque do Riacho")
			await _close(scene)
			break
		if travel.pending.get("kind") == "event":
			saw_event = true
			var event: Dictionary = tree.root.get_node("Content").registry.get_entry("event", travel.pending["id"])
			assert_true((scene.get_node("%EventPanel") as Control).visible, "Painel do evento aberto")
			var result: Dictionary = scene.choose(event["choices"][-1]["id"])
			assert_true(result["ok"], "Escolha aceita")
			scene.close_event()
			await _close(scene)
			continue
		scene.advance()
		await tree.process_frame
		if not exploration.pending_encounter_id.is_empty():
			saw_combat = true
			assert_eq(exploration.return_scene, ExplorationManager.TRAVEL_SCENE, "Combate volta para a viagem")
			var back: String = exploration.finish_encounter(CombatManager.Outcome.VICTORY, 50)
			assert_eq(back, ExplorationManager.TRAVEL_SCENE, "Vitória retoma a viagem")
		await _close(scene)
	assert_true(not exploration.is_traveling(), "Viagem concluída em até 30 passos")
	assert_true(saw_combat or saw_event, "A viagem teve ao menos um acontecimento (semente 5)")

	var forest: ExplorationMap = await _open(FOREST)
	var player: Player = forest.get_node("%Player")
	var entrance: Node2D = forest.get_node("Entrances/Entrance_west")
	assert_true(player.global_position.distance_to(entrance.global_position) < 1.0, "Jogador aparece na entrada oeste")
	assert_true(CharacterFactory.validate(hero, tree.root.get_node("Content").registry).is_empty(), "Personagem válido após a viagem")
	await _close(forest)
	_end()


func test_combat_outcome_is_applied_when_returning_to_travel() -> void:
	_begin()
	exploration.begin_travel("route.east_road", 1)
	var travel: TravelSystem = exploration.current_travel()
	travel.pending = {"kind": "combat", "id": "encounter.lone_wolf"}
	travel.segments_done = 1
	exploration.store_travel(travel)
	exploration.begin_travel_encounter("encounter.lone_wolf")
	exploration.finish_encounter(CombatManager.Outcome.FLED, 0)
	var scene: Node = await _open(TRAVEL_SCENE)
	assert_true(scene.travel.pending.is_empty(), "Fuga resolve o combate pendente")
	assert_true((scene.get_node("%Message") as Label).text.contains("escapou"), "Mensagem da fuga")
	assert_true(not (scene.get_node("%AdvanceButton") as Button).disabled, "Pode seguir viagem")
	assert_true(exploration.current_travel().pending.is_empty(), "Estado salvo no ExplorationManager")
	await _close(scene)
	_end()


func test_travel_scene_buttons_and_status() -> void:
	var hero := _begin()
	hero.current_hp = 5
	exploration.begin_travel("route.east_road", 3)
	var scene: Node = await _open(TRAVEL_SCENE)
	var status := (scene.get_node("%Status") as Label).text
	assert_true(status.contains("PV 5/12") and status.contains("Rações 6") and status.contains("Dados de Vida 1/1"), "Status: %s" % status)
	assert_true(not (scene.get_node("%ShortRestButton") as Button).disabled, "Descanso curto disponível")
	scene.long_rest()
	assert_eq([hero.current_hp, int(party.supplies["rations"])], [12, 5], "Acampar: PV cheios, -1 ração")
	assert_true((scene.get_node("%ShortRestButton") as Button).disabled, "Com PV cheios, sem descanso curto")
	await _close(scene)
	_end()


func test_campfire_long_rest_on_map() -> void:
	var hero := _begin()
	hero.current_hp = 3
	hero.hit_dice_spent = 1
	var forest: ExplorationMap = await _open(FOREST)
	var fire: Interactable = forest.get_node("Objects/Campfire")
	assert_eq(fire.action, "rest_long", "Fogueira oferece descanso longo")
	fire.interact()
	forest.handle_interact()
	assert_eq([hero.current_hp, hero.hit_dice_spent], [12, 0], "Descanso longo na fogueira")
	var hud: ExplorationHud = forest.get_node("%Hud")
	assert_true(hud.get_message_text().contains("restaurados"), "Mensagem do descanso")
	await _close(forest)
	_end()


func test_forest_signpost_returns_to_clearing() -> void:
	_begin()
	var forest: ExplorationMap = await _open(FOREST)
	assert_eq((forest.get_node("Objects/RoadSign") as Interactable).action, "travel:route.east_road_back", "Placa de volta")
	await _close(forest)
	exploration.begin_travel("route.east_road_back", 2)
	var travel: TravelSystem = exploration.current_travel()
	travel.segments_done = 4
	exploration.store_travel(travel)
	assert_eq(exploration.finish_travel(), CLEARING, "Volta para a clareira")
	var clearing: ExplorationMap = await _open(CLEARING)
	var player: Player = clearing.get_node("%Player")
	assert_true(player.global_position.distance_to((clearing.get_node("Entrances/Entrance_east") as Node2D).global_position) < 1.0,
			"Chega pela entrada leste")
	await _close(clearing)
	_end()
