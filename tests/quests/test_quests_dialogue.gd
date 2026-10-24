extends "res://tests/base_test.gd"
## Missões e diálogo: estados, objetivos, recompensas, condições do diálogo da Amara do
## começo ao fim, serialização e validação de dados.

const FACTORY_TESTS := preload("res://tests/characters/test_character_factory.gd")

var registry: ContentRegistry


func _registry() -> ContentRegistry:
	if registry == null:
		registry = ContentRegistry.new()
		registry.load_all()
	return registry


func _party() -> Array[CharacterData]:
	return [CharacterFactory.create(FACTORY_TESTS.new().fighter_choices(), _registry())[0]] as Array[CharacterData]


func test_quest_lifecycle_and_rewards() -> void:
	var log := QuestLog.new()
	var party := _party()
	var inv := Inventory.new()
	assert_eq(log.status("quest.ruin_threat"), QuestLog.Status.NOT_STARTED, "Começa não iniciada")
	assert_true(not log.complete("quest.ruin_threat", party, inv, _registry())["ok"], "Não conclui sem iniciar")
	assert_true(log.start("quest.ruin_threat", _registry())["ok"], "Inicia")
	assert_true(not log.start("quest.ruin_threat", _registry())["ok"], "Não inicia duas vezes")
	assert_true(log.notify("defeat_encounter", "encounter.lone_wolf", _registry()).is_empty(), "Outro encontro não conta")
	assert_true(not log.is_ready("quest.ruin_threat", _registry()), "Ainda não pronta")
	var messages := log.notify("defeat_encounter", "encounter.ruin_goblin", _registry())
	assert_true(str(messages).contains("Objetivo cumprido") and str(messages).contains("Volte a Amara"), "Avisos: %s" % str(messages))
	assert_true(log.is_ready("quest.ruin_threat", _registry()), "Pronta para entregar")
	var done := log.complete("quest.ruin_threat", party, inv, _registry())
	assert_true(done["ok"], "Entrega")
	assert_eq([party[0].experience, inv.gold, inv.count("item.potion_of_healing")], [150, 20, 2], "150 XP, 20 PO, 2 poções")
	assert_eq(log.status("quest.ruin_threat"), QuestLog.Status.COMPLETED, "Concluída")
	assert_true(not log.complete("quest.ruin_threat", party, inv, _registry())["ok"], "Recompensa não é dada duas vezes")


func test_quest_reward_can_level_up() -> void:
	var log := QuestLog.new()
	var party := _party()
	party[0].experience = 200
	log.start("quest.ruin_threat", _registry())
	log.notify("defeat_encounter", "encounter.ruin_goblin", _registry())
	var done := log.complete("quest.ruin_threat", party, Inventory.new(), _registry())
	assert_eq(party[0].level, 2, "200 + 150 = 350 XP: nível 2")
	assert_true(str(done["lines"]).contains("subiu para o nível 2"), "Aviso de subida de nível na entrega")


func test_amara_dialogue_full_flow() -> void:
	var log := QuestLog.new()
	var party := _party()
	var inv := Inventory.new()
	var amara := _registry().get_entry("dialogue", "dialogue.amara")
	var runner := DialogueRunner.new()
	assert_eq(runner.begin(amara, log, party, inv, _registry())["id"], "greeting", "Primeira conversa: apresentação")
	assert_eq(runner.speaker(), "Amara", "Quem fala")
	assert_eq(runner.choices().size(), 3, "Três respostas")
	var accepted := runner.choose(0)
	assert_true(accepted["ok"] and str(accepted["lines"]).contains("Nova missão: Ameaça na Ruína"), "Aceita a missão")
	assert_eq(runner.node["id"], "accept_ruin", "Nó seguinte")
	assert_true(runner.choose(0)["finished"], "Conversa termina")
	assert_eq(runner.begin(amara, log, party, inv, _registry())["id"], "ruin_reminder", "Missão ativa: lembrete")
	log.notify("defeat_encounter", "encounter.ruin_goblin", _registry())
	assert_eq(runner.begin(amara, log, party, inv, _registry())["id"], "ruin_report", "Missão pronta: relatório")
	var report := runner.choose(0)
	assert_true(str(report["lines"]).contains("Missão concluída"), "Entrega pelo diálogo")
	assert_eq(runner.node["id"], "after_ruin", "Oferece a próxima missão")
	runner.choose(0)
	assert_eq(log.status("quest.brook_message"), QuestLog.Status.ACTIVE, "Segunda missão ativa")
	log.notify("reach_map", "map.forest_brook", _registry())
	assert_eq(runner.begin(amara, log, party, inv, _registry())["id"], "brook_report", "Notícias do Bosque prontas")
	runner.choose(0)
	assert_eq(runner.begin(amara, log, party, inv, _registry())["id"], "idle", "Tudo feito: conversa final")
	assert_eq(log.completed_ids().size(), 2, "Duas missões concluídas")
	assert_eq(party[0].experience, 250, "150 + 100 XP")


func test_lore_branch_and_invalid_choice() -> void:
	var runner := DialogueRunner.new()
	runner.begin(_registry().get_entry("dialogue", "dialogue.amara"), QuestLog.new(), _party(), Inventory.new(), _registry())
	runner.choose(1)
	assert_eq(runner.node["id"], "ruin_lore", "Pergunta sobre a ruína")
	assert_true(not runner.choose(7)["ok"], "Índice inválido é recusado")
	assert_true(runner.choose(1)["finished"], "'Vou pensar' encerra sem iniciar")


func test_quest_log_serialization() -> void:
	var log := QuestLog.new()
	log.start("quest.ruin_threat", _registry())
	log.notify("defeat_encounter", "encounter.ruin_goblin", _registry())
	var copy: QuestLog = QuestLog.from_dict(JSON.parse_string(JSON.stringify(log.to_dict())), _registry())[0]
	assert_true(copy != null and copy.is_ready("quest.ruin_threat", _registry()), "Estado restaurado")
	var bad := QuestLog.from_dict({"quests": {"quest.dragon": {"status": "active", "done": []}}}, _registry())
	assert_true(bad[0] == null and str(bad[1]).contains("desconhecida"), "Missão inexistente rejeitada")


func test_dialogue_and_quest_validation() -> void:
	var data := {}
	for type_name: String in ContentRegistry.TYPES:
		data[type_name] = []
		for id in _registry().ids(type_name):
			data[type_name].append(_registry().get_entry(type_name, id).duplicate(true))
	var amara: Dictionary = data["dialogue"][0]
	amara["nodes"][0]["choices"][0]["next"] = "nao_existe"
	amara["nodes"][0]["choices"][1]["action"] = "summon_dragon:quest.ruin_threat"
	amara["entries"][0]["condition"] = "quest_ready:quest.inexistente"
	for quest: Dictionary in data["quest"]:
		if quest["id"] == "quest.ruin_threat":
			quest["objectives"][0]["target"] = "encounter.inexistente"
	var check := ContentRegistry.new()
	assert_true(not check.load_from_dictionaries(data), "Dados quebrados reprovam")
	var errors := "\n".join(check.errors)
	assert_true(errors.contains("nó inexistente 'nao_existe'"), "Próximo nó inexistente")
	assert_true(errors.contains("ação desconhecida"), "Ação desconhecida")
	assert_true(errors.contains("missão inexistente 'quest.inexistente'"), "Condição com missão inexistente")
	assert_true(errors.contains("encounter inexistente 'encounter.inexistente'"), "Objetivo com alvo inexistente")
