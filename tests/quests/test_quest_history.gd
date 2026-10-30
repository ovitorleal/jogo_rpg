extends "res://tests/base_test.gd"
## Correção: objetivos cumpridos antes de a missão começar. Ex.: matar o goblin da ruína antes de falar com
## Amara deixava "Ameaça na Ruína" presa esperando um goblin que não volta mais.

const FACTORY_TESTS := preload("res://tests/characters/test_character_factory.gd")
const CLEARING := "res://scenes/world/test_map.tscn"

var registry: ContentRegistry


func _begin() -> void:
	registry = Content.registry
	ExplorationManager.reset()
	QuestManager.reset()
	ExplorationManager.scene_changes_enabled = false
	PartyManager.start_new_party(CharacterFactory.create(FACTORY_TESTS.new().fighter_choices(), registry)[0])


func _end() -> void:
	ExplorationManager.scene_changes_enabled = true
	ExplorationManager.reset()
	QuestManager.reset()
	PartyManager.clear()


func test_goblin_killed_before_talking_to_amara_counts() -> void:
	_begin()
	QuestManager.notify("defeat_encounter", "encounter.ruin_goblin")
	var started := QuestManager.log.start("quest.ruin_threat", registry)
	assert_true(str(started["text"]).contains("Objetivo já cumprido"), "Avisa que o goblin já foi derrotado: %s" % started["text"])
	assert_true(str(started["text"]).contains("Volte a Amara"), "E que é só voltar a Amara")
	assert_true(QuestManager.log.is_ready("quest.ruin_threat", registry), "Missão pronta para entregar")
	_end()


func test_every_kind_of_objective_is_remembered() -> void:
	_begin()
	QuestManager.notify("talk", "dialogue.amara")
	QuestManager.notify("defeat_encounter", "encounter.goblin_chief")
	QuestManager.notify("reach_map", "map.forest_brook")
	QuestManager.log.start("quest.goblin_chief", registry)
	QuestManager.log.start("quest.brook_message", registry)
	assert_true(QuestManager.log.is_ready("quest.goblin_chief", registry), "Amara e Garra-Rubra antes de Ione")
	assert_true(QuestManager.log.is_ready("quest.brook_message", registry), "Bosque visitado antes do recado")
	_end()


func test_history_is_saved_and_old_saves_still_load() -> void:
	_begin()
	QuestManager.notify("defeat_encounter", "encounter.ruin_goblin")
	var loaded: QuestLog = QuestLog.from_dict(QuestManager.log.to_dict(), registry)[0]
	assert_true(loaded.has_happened("defeat_encounter", "encounter.ruin_goblin"), "Histórico no salvamento")
	var old: Array = QuestLog.from_dict({"quests": {"quest.ruin_threat": {"status": "active", "done": []}}}, registry)
	assert_true(old[0] != null, "Salvamento antigo, sem histórico, carrega: %s" % str(old[1]))
	_end()


func test_stuck_save_is_repaired_when_entering_the_map() -> void:
	_begin()
	# Situação do salvamento preso: goblin vencido antes da missão e missão ativa sem o objetivo.
	ExplorationManager.resolved_triggers["test_map.ruin_goblin"] = true
	QuestManager.log.start("quest.ruin_threat", registry)
	assert_true(not QuestManager.log.is_ready("quest.ruin_threat", registry), "Presa antes da correção")
	var map: ExplorationMap = (load(CLEARING) as PackedScene).instantiate()
	tree.root.add_child(map)
	await tree.process_frame
	assert_true(QuestManager.log.is_ready("quest.ruin_threat", registry), "Ao entrar na Clareira, a missão destrava")
	var hud: ExplorationHud = map.get_node("%Hud")
	assert_true(hud.get_message_text().contains("Objetivo cumprido"), "Avisa o jogador: %s" % hud.get_message_text())
	map.queue_free()
	await tree.process_frame
	_end()
