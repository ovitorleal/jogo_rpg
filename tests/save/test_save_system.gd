extends "res://tests/base_test.gd"
## Fase 6: formato do salvamento, gravação segura, recuperação, recusa de dados inválidos,
## locais seguros, menu do mapa, "Continuar" no título e autosave.

const MAP_SCENE := "res://scenes/world/test_map.tscn"
const TITLE_SCENE := "res://scenes/menus/title_screen.tscn"
const TRAVEL_SCENE := "res://scenes/travel/travel_scene.tscn"
const MAP_LOCATION := {"kind": "map", "scene": MAP_SCENE, "position": [120.0, 96.0]}


func _saves() -> Node:
	return tree.root.get_node("SaveManager")


func _fighter() -> CharacterData:
	var fixtures: Object = load("res://tests/characters/test_character_factory.gd").new()
	return CharacterFactory.create(fixtures.fighter_choices(), Content.registry)[0]


## Jogo de exemplo nos autoloads: herói ferido, ouro, missão ativa e um encontro vencido.
func _start_game() -> CharacterData:
	_saves().delete_save()
	var hero := _fighter()
	hero.current_hp = 5
	hero.appearance = {"hair_style": "long", "skin": 2}
	PartyManager.start_new_party(hero)
	PartyManager.inventory.gold = 37
	QuestManager.reset()
	QuestManager.log.start("quest.ruin_threat", Content.registry)
	ExplorationManager.reset()
	ExplorationManager.resolved_triggers["test_map.lone_wolf"] = true
	return hero


func _end_game() -> void:
	_saves().delete_save()
	PartyManager.clear()
	QuestManager.reset()
	ExplorationManager.reset()


func _file_text(path: String) -> String:
	return FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""


func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func test_round_trip_restores_the_whole_game() -> void:
	_start_game()
	var text := SaveGame.encode(SaveGame.capture(MAP_LOCATION))
	# Muda tudo e depois aplica o salvamento.
	PartyManager.start_new_party(_fighter())
	QuestManager.reset()
	ExplorationManager.reset()
	var decoded := SaveGame.decode(text, Content.registry)
	assert_true(decoded["ok"], "Salvamento válido: %s" % str(decoded["errors"]))
	if decoded["ok"]:
		var scene := SaveGame.apply(decoded["state"])
		var leader: CharacterData = PartyManager.get_leader()
		assert_eq(scene, MAP_SCENE, "Volta ao mapa salvo")
		assert_eq([leader.current_hp, leader.appearance.get("hair_style")], [5, "long"], "PV e aparência restaurados")
		assert_eq(PartyManager.inventory.gold, 37, "Ouro restaurado")
		assert_eq(QuestManager.log.active_ids(), ["quest.ruin_threat"] as Array[String], "Missão ativa restaurada")
		assert_true(ExplorationManager.is_resolved("test_map.lone_wolf"), "Encontro vencido continua vencido")
		assert_eq(ExplorationManager.take_return_position(MAP_SCENE), Vector2(120, 96), "Posição do jogador")
		assert_eq(decoded["state"]["summary"].get("name"), leader.name, "Resumo para o título")
	_end_game()


func test_corrupted_or_unknown_files_are_rejected() -> void:
	_start_game()
	var state := SaveGame.capture(MAP_LOCATION)
	var text := SaveGame.encode(state)
	assert_true(not SaveGame.decode(text.substr(0, text.length() / 2), Content.registry)["ok"], "Arquivo cortado")
	assert_true(not SaveGame.decode(text.replace("37", "99999"), Content.registry)["ok"], "Conteúdo alterado (soma)")
	assert_true(not SaveGame.decode("{}", Content.registry)["ok"], "Formato desconhecido")
	var future := state.duplicate(true)
	future["save_version"] = SaveGame.SAVE_VERSION + 1
	var result := SaveGame.decode(SaveGame.encode(future), Content.registry)
	assert_true(not result["ok"] and str(result["errors"]).contains("mais nova"), "Versão futura recusada")
	var bad_item := state.duplicate(true)
	bad_item["inventory"]["stacks"]["item.nao_existe"] = 1
	assert_true(not SaveGame.decode(SaveGame.encode(bad_item), Content.registry)["ok"], "Item desconhecido")
	var no_party := state.duplicate(true)
	no_party["party"] = []
	assert_true(not SaveGame.decode(SaveGame.encode(no_party), Content.registry)["ok"], "Grupo vazio")
	var bad_map := state.duplicate(true)
	bad_map["location"]["scene"] = "res://nao_existe.tscn"
	assert_true(not SaveGame.decode(SaveGame.encode(bad_map), Content.registry)["ok"], "Mapa desconhecido")
	_end_game()


func test_save_writes_main_and_keeps_backup() -> void:
	_start_game()
	var saves := _saves()
	var first := saves.save_state(SaveGame.capture(MAP_LOCATION)) as Dictionary
	assert_true(first["ok"], "Primeiro salvamento: %s" % first["message"])
	assert_true(FileAccess.file_exists(saves.main_path()), "Arquivo principal criado")
	assert_true(not FileAccess.file_exists(saves.temp_path()), "Temporário removido após confirmar")
	var first_text := _file_text(saves.main_path())
	PartyManager.inventory.gold = 50
	assert_true(saves.save_state(SaveGame.capture(MAP_LOCATION))["ok"], "Segundo salvamento")
	assert_eq(_file_text(saves.backup_path()), first_text, "Salvamento anterior vira cópia de recuperação")
	var found: Dictionary = saves.peek()
	assert_true(found["ok"] and found["source"] == "main", "Lê o principal")
	_end_game()


func test_corrupted_main_falls_back_to_backup() -> void:
	_start_game()
	var saves := _saves()
	saves.save_state(SaveGame.capture(MAP_LOCATION))
	PartyManager.inventory.gold = 80
	saves.save_state(SaveGame.capture(MAP_LOCATION))
	_write(saves.main_path(), _file_text(saves.main_path()).substr(0, 200))
	var found: Dictionary = saves.peek()
	assert_true(found["ok"] and found["source"] == "backup", "Usa a cópia de recuperação")
	assert_true(str(found["message"]).contains("recuperação"), "Avisa que recuperou")
	var loaded: Dictionary = saves.load_game()
	assert_true(loaded["ok"], "Carrega a cópia")
	assert_eq(PartyManager.inventory.gold, 37, "Estado da cópia (antes do último salvamento)")
	# Sem nenhum arquivo válido: mensagem útil, sem carregar nada.
	_write(saves.backup_path(), "lixo")
	var broken: Dictionary = saves.peek()
	assert_true(not broken["ok"] and str(broken["message"]).contains("danificado"), "Salvamento danificado avisado")
	_end_game()


func test_invalid_state_never_overwrites_a_valid_save() -> void:
	_start_game()
	var saves := _saves()
	saves.save_state(SaveGame.capture(MAP_LOCATION))
	var good := _file_text(saves.main_path())
	var broken := SaveGame.capture(MAP_LOCATION)
	broken["party"] = []
	var result := saves.save_state(broken) as Dictionary
	assert_true(not result["ok"] and str(result["message"]).contains("anterior foi mantido"), "Recusa estado inválido")
	assert_eq(_file_text(saves.main_path()), good, "Arquivo válido intacto")
	_end_game()


func test_save_only_in_consistent_places() -> void:
	_end_game()
	var saves := _saves()
	assert_true(not saves.current_location()["ok"], "Sem grupo não salva")
	assert_true(not saves.save_now()["ok"], "save_now recusa sem grupo")
	_start_game()
	# Cena atual do executor de testes não é mapa nem viagem.
	assert_true(not saves.current_location()["ok"], "Fora de mapa/viagem não salva")
	var travel := TravelSystem.new()
	travel.start(Content.registry.get_entry("route", "route.east_road"), 3)
	travel.pending = {"kind": "combat", "id": "encounter.ruin_goblin"}
	ExplorationManager.store_travel(travel)
	var screen: TravelScene = (load(TRAVEL_SCENE) as PackedScene).instantiate()
	screen.animations_enabled = false
	tree.root.add_child(screen)
	await tree.process_frame
	assert_true(not screen.save_blocker().is_empty(), "Combate pendente na viagem bloqueia o salvamento")
	screen.queue_free()
	await tree.process_frame
	_end_game()


func test_map_menu_saves_and_title_continues() -> void:
	_start_game()
	ExplorationManager.scene_changes_enabled = false
	var map: ExplorationMap = (load(MAP_SCENE) as PackedScene).instantiate()
	tree.root.add_child(map)
	var previous_scene := tree.current_scene
	tree.current_scene = map
	await tree.process_frame
	await tree.process_frame
	map.close_overlays()
	map.cancel_message()
	map.open_pause_menu()
	assert_true(map.is_pause_menu_open(), "Esc abre o menu")
	var result: Dictionary = map.save_from_menu()
	assert_true(result["ok"], "Salvar agora: %s" % result["message"])
	var hud: ExplorationHud = map.get_node("%Hud")
	assert_true(hud.pause_menu.get_status().contains("Jogo salvo") or hud.pause_menu.get_status().contains("salvo"),
			"Menu confirma o salvamento: %s" % hud.pause_menu.get_status())
	map.start_dialogue("dialogue.amara")
	assert_true(not _saves().save_now()["ok"], "Não salva no meio de uma conversa")
	map.end_dialogue()
	tree.current_scene = previous_scene
	map.queue_free()
	await tree.process_frame

	var title: Control = (load(TITLE_SCENE) as PackedScene).instantiate()
	tree.root.add_child(title)
	await tree.process_frame
	var continue_button: Button = title.get_node("%ContinueButton")
	assert_true(not continue_button.disabled, "Continuar habilitado com jogo salvo")
	assert_true((title.get_node("%StatusLabel") as Label).text.contains(PartyManager.get_leader().name), "Resumo do salvamento")
	title.queue_free()
	await tree.process_frame
	_saves().delete_save()
	title = (load(TITLE_SCENE) as PackedScene).instantiate()
	tree.root.add_child(title)
	await tree.process_frame
	assert_true((title.get_node("%ContinueButton") as Button).disabled, "Sem salvamento, Continuar desabilitado")
	title.queue_free()
	await tree.process_frame
	ExplorationManager.scene_changes_enabled = true
	_end_game()


func test_autosave_groups_requests_and_waits_for_safe_point() -> void:
	_start_game()
	var saves := _saves()
	ExplorationManager.scene_changes_enabled = false
	var map: ExplorationMap = (load(MAP_SCENE) as PackedScene).instantiate()
	tree.root.add_child(map)
	var previous_scene := tree.current_scene
	tree.current_scene = map
	await tree.process_frame
	map.cancel_message()
	saves.autosave_enabled = true
	var writes := [0]
	var count := func(_ok: bool, _message: String) -> void: writes[0] += 1
	saves.save_finished.connect(count)
	map.start_dialogue("dialogue.amara")
	saves.request_autosave("teste")
	saves.request_autosave("teste 2")
	await tree.create_timer(0.6).timeout
	assert_eq(writes[0], 0, "Durante a conversa o autosave espera")
	assert_true(saves.has_pending_autosave(), "Pedido continua pendente")
	map.end_dialogue()
	await tree.create_timer(1.3).timeout
	assert_eq(writes[0], 1, "Pedidos agrupados numa única gravação")
	assert_true(saves.has_save(), "Autosave gravou um salvamento válido")
	saves.save_finished.disconnect(count)
	saves.autosave_enabled = false
	tree.current_scene = previous_scene
	map.queue_free()
	await tree.process_frame
	ExplorationManager.scene_changes_enabled = true
	_end_game()
