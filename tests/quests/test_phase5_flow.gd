extends "res://tests/base_test.gd"
## Fluxo da Fase 5 no mapa: conversar com a Amara, aceitar a missão, vencer o goblin, ver o
## objetivo cumprido ao voltar, entregar, receber recompensas e usar o inventário e o diário.

const FACTORY_TESTS := preload("res://tests/characters/test_character_factory.gd")
const CLEARING := "res://scenes/world/test_map.tscn"

var exploration: Node
var party: Node
var quests: Node


func _begin() -> CharacterData:
	exploration = tree.root.get_node("ExplorationManager")
	party = tree.root.get_node("PartyManager")
	quests = tree.root.get_node("QuestManager")
	exploration.reset()
	quests.reset()
	exploration.scene_changes_enabled = false
	var hero: CharacterData = CharacterFactory.create(FACTORY_TESTS.new().fighter_choices(), tree.root.get_node("Content").registry)[0]
	party.start_new_party(hero)
	return hero


func _end() -> void:
	exploration.scene_changes_enabled = true
	exploration.reset()
	quests.reset()
	party.clear()


func _open_map() -> ExplorationMap:
	var map: ExplorationMap = (load(CLEARING) as PackedScene).instantiate()
	tree.root.add_child(map)
	await tree.process_frame
	return map


func _close(node: Node) -> void:
	node.queue_free()
	await tree.process_frame


func test_talk_accept_defeat_return_and_turn_in() -> void:
	var hero := _begin()
	var map := await _open_map()
	var hud: ExplorationHud = map.get_node("%Hud")
	var amara: Interactable = map.get_node("Objects/Amara")
	amara.interact()
	assert_true(map.is_in_dialogue(), "Conversa aberta")
	assert_eq(hud.get_speaker_name(), "Amara", "Nome de quem fala")
	assert_true(hud.get_portrait() != null, "Retrato da Amara")
	assert_eq(hud.dialogue_options().size(), 3, "Três respostas como botões")
	map.choose_dialogue_option(0)
	map.choose_dialogue_option(0)
	assert_true(not map.is_in_dialogue(), "Conversa encerrada")
	assert_true(hud.is_message_open() and hud.get_message_text().contains("Nova missão"), "Aviso da missão nova")
	map.handle_interact()
	map.toggle_journal()
	assert_true(hud.journal_panel.visible and hud.journal_panel.get_plain_text().contains("Ameaça na Ruína"), "Diário mostra a missão")
	assert_true(hud.journal_panel.get_plain_text().contains("[ ] Derrotar o goblin"), "Objetivo pendente marcado")
	map.toggle_journal()
	await _close(map)

	exploration.begin_encounter("encounter.ruin_goblin", "test_map.ruin_goblin", CLEARING, Vector2(300, 380))
	exploration.finish_encounter(CombatManager.Outcome.VICTORY, 50)
	map = await _open_map()
	hud = map.get_node("%Hud")
	assert_true(hud.get_message_text().contains("Objetivo cumprido"), "Ao voltar: objetivo cumprido (%s)" % hud.get_message_text())
	map.handle_interact()
	map.toggle_journal()
	assert_true(hud.journal_panel.get_plain_text().contains("pronta para entregar"), "Diário: pronta")
	map.toggle_journal()

	var gold_before: int = party.inventory.gold
	(map.get_node("Objects/Amara") as Interactable).interact()
	map.choose_dialogue_option(0)
	assert_eq(quests.log.status("quest.ruin_threat"), QuestLog.Status.COMPLETED, "Missão concluída pelo diálogo")
	assert_eq(party.inventory.gold, gold_before + 20, "Ouro da recompensa no inventário")
	assert_eq(hero.experience, 150, "XP da recompensa")
	map.choose_dialogue_option(1)
	assert_true(hud.get_message_text().contains("Missão concluída"), "Resumo das recompensas ao fim da conversa")
	await _close(map)
	_end()


func test_inventory_panel_and_exclusive_overlays() -> void:
	var hero := _begin()
	hero.current_hp = 4
	var map := await _open_map()
	var hud: ExplorationHud = map.get_node("%Hud")
	map.toggle_inventory()
	assert_true(hud.inventory_panel.visible, "Inventário abre com I")
	var result: Dictionary = hud.inventory_panel.use_item(Inventory.POTION)
	assert_true(result["ok"] and hero.current_hp > 4, "Poção usada pelo painel")
	assert_eq(party.inventory.count(Inventory.POTION), 1, "Uma poção a menos")
	map.toggle_character_sheet()
	assert_true(hud.is_sheet_open() and not hud.inventory_panel.visible, "Só um painel por vez")
	map.close_overlays()
	assert_true(not hud.is_overlay_open(), "Esc fecha")
	await _close(map)
	_end()


func test_new_game_resets_quests() -> void:
	_begin()
	quests.log.start("quest.ruin_threat", tree.root.get_node("Content").registry)
	var screen: Control = (load("res://scenes/menus/character_creation.tscn") as PackedScene).instantiate()
	tree.root.add_child(screen)
	await tree.process_frame
	await tree.process_frame
	assert_true(screen.get_character() != null, "Personagem padrão válido")
	_end()
	assert_true(quests.log.active_ids().is_empty(), "Reset limpa missões")
	screen.queue_free()
	await tree.process_frame
