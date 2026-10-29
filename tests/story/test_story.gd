extends "res://tests/base_test.gd"
## Fase 9: a história no jogo. Garra Vermelha como recompensa do chefe, cenas de história (chegada e
## descanso) com falas dos companheiros, crônicas desbloqueadas no diário, Ione reconhecendo a Garra e o
## epílogo do Ato I.

const FACTORY_TESTS := preload("res://tests/characters/test_character_factory.gd")
const VILLAGE := "res://scenes/world/village.tscn"
const FOREST := "res://scenes/world/forest_brook.tscn"
const CLAW := "item.red_claw"

var registry: ContentRegistry


func _begin() -> CharacterData:
	registry = Content.registry
	ExplorationManager.reset()
	QuestManager.reset()
	ExplorationManager.scene_changes_enabled = false
	var hero: CharacterData = CharacterFactory.create(FACTORY_TESTS.new().fighter_choices(), registry)[0]
	PartyManager.start_new_party(hero)
	return hero


func _end() -> void:
	ExplorationManager.scene_changes_enabled = true
	ExplorationManager.reset()
	QuestManager.reset()
	PartyManager.clear()


func _conditions() -> DialogueRunner:
	return DialogueRunner.new().prepare(QuestManager.log, PartyManager.members, PartyManager.inventory, registry,
			PartyManager.roster, null, ExplorationManager.resolved_triggers, ExplorationManager.once_events)


func _open(path: String) -> ExplorationMap:
	var map: ExplorationMap = (load(path) as PackedScene).instantiate()
	tree.root.add_child(map)
	await tree.process_frame
	return map


func _close(node: Node) -> void:
	node.queue_free()
	await tree.process_frame


func _lore_ids() -> Array:
	return StoryDirector.unlocked_lore(_conditions(), registry).map(func(e: Dictionary) -> String: return e["id"])


func test_boss_drops_the_red_claw() -> void:
	registry = Content.registry
	var rewards: Array = registry.get_entry("encounter", "encounter.goblin_chief")["reward_items"]
	assert_true(rewards.any(func(r: Dictionary) -> bool: return r["item_id"] == CLAW), "Garra-Rubra deixa a Garra Vermelha")
	assert_eq(registry.get_entry("item", CLAW)["item_type"], "gear", "A Garra é um item comum do inventário")


func test_claw_scene_plays_once_with_party_remarks() -> void:
	_begin()
	PartyManager.roster.recruit("companion.ignis", PartyManager.members, registry)
	var none := StoryDirector.pending_beats("arrive", "map.forest_brook", _conditions(), registry, ExplorationManager.once_events)
	assert_eq(none.size(), 0, "Sem a Garra, nada acontece")
	PartyManager.inventory.add(CLAW, 1)
	var beats := StoryDirector.pending_beats("arrive", "map.forest_brook", _conditions(), registry, ExplorationManager.once_events)
	assert_eq(beats.map(func(b: Dictionary) -> String: return b["id"]), ["story.claw_found"], "Cena da Garra no Bosque")
	assert_eq(StoryDirector.pending_beats("arrive", "map.village", _conditions(), registry, ExplorationManager.once_events).size(),
			0, "Só no Bosque do Riacho")
	var text := StoryDirector.beat_text(beats[0], PartyManager.members)
	assert_true(text.contains("Ignis:"), "Ignis, no grupo, comenta")
	assert_true(not text.contains("Doran:"), "Quem não está no grupo não fala")
	ExplorationManager.once_events["story.claw_found"] = true
	assert_eq(StoryDirector.pending_beats("arrive", "map.forest_brook", _conditions(), registry, ExplorationManager.once_events).size(),
			0, "A cena acontece uma vez só")
	_end()


func test_chronicles_unlock_as_the_story_advances() -> void:
	_begin()
	assert_eq(_lore_ids(), ["lore.arghaz"], "No começo, só Arghaz e a mana")
	QuestManager.log.start("quest.goblin_chief", registry)
	assert_true("lore.arauto" in _lore_ids(), "Com a missão, os kobolds e o Arauto")
	ExplorationManager.once_events["story.claw_found"] = true
	assert_true("lore.dragons" in _lore_ids() and "lore.silence" in _lore_ids(), "A Garra revela as linhagens e o Silêncio")
	ExplorationManager.once_events["story.vermeth_dream"] = true
	assert_true("lore.vermeth" in _lore_ids(), "O sonho revela Vermeth")
	var journal := JournalPanel.format(QuestManager.log, registry, StoryDirector.unlocked_lore(_conditions(), registry))
	assert_true(journal.contains("Crônicas de Arghaz") and journal.contains("Vermeth"), "Crônicas no diário")
	_end()


func test_arriving_at_the_camp_with_the_claw_shows_the_scene() -> void:
	_begin()
	PartyManager.inventory.add(CLAW, 1)
	ExplorationManager.intro_message = "Vitória!"
	var map := await _open(FOREST)
	var hud: ExplorationHud = map.get_node("%Hud")
	assert_true(hud.get_message_text().contains("Vitória!") and hud.get_message_text().contains("oferendas"),
			"Resultado do combate e a cena juntos: %s" % hud.get_message_text().left(80))
	assert_true(ExplorationManager.once_events.has("story.claw_found"), "Cena marcada como vista")
	await _close(map)
	_end()


func test_first_rest_with_the_claw_brings_the_dream() -> void:
	_begin()
	PartyManager.inventory.add(CLAW, 1)
	var map := await _open(VILLAGE)
	var hud: ExplorationHud = map.get_node("%Hud")
	if hud.is_message_open():
		map.handle_interact()
	(map.get_node("Objects/Inn") as Interactable).interact()
	map.handle_interact()
	assert_eq(hud.get_speaker_name(), "Uma voz no sonho", "Sonho com Vermeth no descanso")
	assert_true(hud.get_message_text().contains("Você trouxe minha garra"), "Fala de Vermeth")
	map.handle_interact()
	(map.get_node("Objects/Inn") as Interactable).interact()
	map.handle_interact()
	assert_true(hud.get_message_text().contains("descansa"), "No segundo descanso, só a mensagem comum")
	map.handle_interact()
	await _close(map)
	_end()


func test_ione_recognizes_the_claw_and_points_to_vessa() -> void:
	_begin()
	QuestManager.log.start("quest.goblin_chief", registry)
	QuestManager.notify("talk", "dialogue.amara")
	QuestManager.notify("defeat_encounter", "encounter.goblin_chief")
	var without := DialogueRunner.new()
	without.begin(registry.get_entry("dialogue", "dialogue.ione"), QuestManager.log, PartyManager.members,
			PartyManager.inventory, registry)
	assert_eq(without.choices().size(), 1, "Sem a Garra, só o agradecimento")
	assert_true(not str(without.choices()[0]["text"]).contains("garra"), "Sem mencionar a Garra")
	PartyManager.inventory.add(CLAW, 1)
	var ione := DialogueRunner.new()
	ione.begin(registry.get_entry("dialogue", "dialogue.ione"), QuestManager.log, PartyManager.members,
			PartyManager.inventory, registry)
	assert_true(str(ione.choices()[0]["text"]).contains("garra vermelha"), "Com a Garra, o herói mostra a Ione")
	ione.choose(0)
	assert_eq(ione.node["id"], "symbol", "Ione reconhece o símbolo")
	assert_eq(QuestManager.log.status("quest.goblin_chief"), QuestLog.Status.COMPLETED, "Missão concluída")
	ione.choose(0)
	assert_true(str(ione.node["text"]).contains("Vessa"), "Gancho para o Ato II")
	assert_true(EndingScreen.summary_text().contains("Continua no Ato II"), "Epílogo na tela de conclusão")
	_end()


func test_registry_checks_story_conditions() -> void:
	registry = Content.registry
	var saved := registry.errors.duplicate()
	registry.errors.clear()
	registry._check_rule("story.teste", "has_item:item.nada", ContentRegistry.DIALOGUE_CONDITIONS, "condição")
	registry._check_rule("story.teste", "event_seen:", ContentRegistry.DIALOGUE_CONDITIONS, "condição")
	var found := registry.errors.duplicate()
	registry.errors = saved
	assert_eq(found.size(), 2, "Item inexistente e evento vazio apontados: %s" % str(found))
