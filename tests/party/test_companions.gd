extends "res://tests/base_test.gd"
## Companheiros recrutáveis: montagem válida dos seis, recrutamento com grupo cheio (estalagem),
## entrada no nível do líder, salvamento, condições e testes de perícia nos diálogos, NPCs no mapa,
## seguidores, painel do grupo e volta com 1 PV depois de uma vitória.

const FACTORY_TESTS := preload("res://tests/characters/test_character_factory.gd")
const VILLAGE := "res://scenes/world/village.tscn"
const CLEARING := "res://scenes/world/test_map.tscn"
const FOREST := "res://scenes/world/forest_brook.tscn"
const ALL := ["companion.doran", "companion.bruna", "companion.lyra", "companion.kael", "companion.tarka",
		"companion.ignis"]

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


func _open(path: String) -> ExplorationMap:
	var map: ExplorationMap = (load(path) as PackedScene).instantiate()
	tree.root.add_child(map)
	await tree.process_frame
	return map


func _close(node: Node) -> void:
	node.queue_free()
	await tree.process_frame


func _runner(dialogue_id: String, roller: DiceRoller = null, resolved: Dictionary = {}) -> DialogueRunner:
	var runner := DialogueRunner.new()
	runner.begin(registry.get_entry("dialogue", dialogue_id), QuestManager.log, PartyManager.members,
			PartyManager.inventory, registry, PartyManager.roster, roller, resolved)
	return runner


func _choice_index(runner: DialogueRunner, text_part: String) -> int:
	var visible := runner.choices()
	for i in visible.size():
		if str(visible[i]["text"]).contains(text_part):
			return i
	return -1


func test_six_companions_with_distinct_class_and_species() -> void:
	registry = Content.registry
	var ids := registry.ids("companion")
	assert_true(ids.size() >= 6, "Pelo menos 6 companheiros (%d)" % ids.size())
	var classes := {}
	var species := {}
	for id in ids:
		var entry := registry.get_entry("companion", id)
		classes[entry["class_id"]] = true
		species[entry["species_id"]] = true
		assert_true(registry.has("dialogue", entry["dialogue_id"]), "%s tem diálogo" % id)
	assert_eq(classes.size(), ids.size(), "Classes diferentes")
	assert_eq(species.size(), ids.size(), "Espécies diferentes")


func test_every_companion_builds_valid_at_levels_1_and_5() -> void:
	registry = Content.registry
	for id in registry.ids("companion"):
		for level in [1, 5]:
			var c := CompanionRoster.build(registry.get_entry("companion", id), level, registry)
			assert_true(c != null, "%s monta no nível %d" % [id, level])
			if c == null:
				continue
			assert_eq(c.level, level, "%s no nível %d" % [id, level])
			assert_eq(CharacterFactory.validate(c, registry), [] as Array[String], "%s válido (nível %d)" % [id, level])
			assert_eq(Appearance.validate(c, registry), [] as Array[String], "%s com aparência válida" % id)
			assert_eq(c.current_hp, CharacterSheet.build(c, registry).max_hp, "%s com PV cheios" % id)
			assert_eq(CompanionRoster.companion_id_of(c), id, "Id do companheiro recuperável")


func test_party_holds_leader_plus_two_and_extra_recruits_wait_at_the_inn() -> void:
	_begin()
	var roster: CompanionRoster = PartyManager.roster
	for id in ["companion.doran", "companion.bruna", "companion.lyra"]:
		var result := roster.recruit(id, PartyManager.members, registry)
		assert_true(result["ok"], "Recruta %s" % id)
	assert_eq(PartyManager.members.size(), CompanionRoster.MAX_PARTY, "Líder + 2 companheiros")
	assert_eq(roster.bench.size(), 1, "O terceiro espera na estalagem")
	assert_eq(roster.bench[0].name, "Lyra Vento-Leste", "Lyra na estalagem")
	assert_true(not roster.recruit("companion.doran", PartyManager.members, registry)["ok"], "Não recruta duas vezes")
	assert_true(not roster.join(roster.bench[0], PartyManager.members, registry)["ok"], "Grupo cheio não aceita mais")
	assert_true(not roster.leave(PartyManager.members[0], PartyManager.members)["ok"], "O líder não sai")
	var doran := PartyManager.members[1]
	assert_true(roster.leave(doran, PartyManager.members)["ok"], "Doran fica na estalagem")
	var lyra := roster.bench[0]
	assert_true(roster.join(lyra, PartyManager.members, registry)["ok"], "Lyra entra no lugar dele")
	assert_eq(PartyManager.members.map(func(c: CharacterData) -> String: return c.name.get_slice(" ", 0)),
			["Brena", "Bruna", "Lyra"], "Grupo trocado")
	_end()


func test_recruits_join_at_the_leader_level_and_catch_up_from_the_bench() -> void:
	var hero := _begin()
	Progression.award_xp(hero, Progression.XP_FOR_LEVEL[3], registry)
	assert_eq(hero.level, 3, "Líder no nível 3")
	var roster: CompanionRoster = PartyManager.roster
	roster.recruit("companion.kael", PartyManager.members, registry)
	assert_eq([PartyManager.members[1].level, PartyManager.members[1].experience], [3, hero.experience],
			"Kael entra no nível e na experiência do líder")
	roster.leave(PartyManager.members[1], PartyManager.members)
	Progression.award_xp(hero, Progression.XP_FOR_LEVEL[4] - hero.experience, registry)
	var kael := roster.bench[0]
	assert_eq(kael.level, 3, "Na estalagem não ganha experiência")
	var joined := roster.join(kael, PartyManager.members, registry)
	assert_eq(kael.level, 4, "Ao voltar alcança o líder (%s)" % str(joined["lines"]))
	assert_eq(CharacterFactory.validate(kael, registry), [] as Array[String], "Continua válido depois de subir")
	_end()


func test_save_round_trip_keeps_party_bench_and_recruited() -> void:
	_begin()
	var roster: CompanionRoster = PartyManager.roster
	for id in ["companion.tarka", "companion.ignis", "companion.bruna"]:
		roster.recruit(id, PartyManager.members, registry)
	var text := SaveGame.encode(SaveGame.capture({"kind": "map", "scene": VILLAGE, "position": [300.0, 236.0]}))
	PartyManager.start_new_party(CharacterFactory.create(FACTORY_TESTS.new().fighter_choices(), registry)[0])
	assert_eq(PartyManager.roster.recruited, [] as Array[String], "Novo jogo sem companheiros")
	var decoded := SaveGame.decode(text, registry)
	assert_true(decoded["ok"], "Salvamento válido: %s" % str(decoded.get("errors")))
	if decoded["ok"]:
		SaveGame.apply(decoded["state"])
		assert_eq(PartyManager.members.size(), 3, "Grupo de três restaurado")
		assert_eq(PartyManager.roster.recruited, ["companion.tarka", "companion.ignis", "companion.bruna"] as Array[String],
				"Recrutados restaurados")
		assert_eq(PartyManager.roster.bench.map(func(c: CharacterData) -> String: return c.name),
				["Bruna Pé-Ligeiro"], "Estalagem restaurada")
	var bad := CompanionRoster.from_dict({"recruited": ["companion.nobody"], "bench": [{"name": 3}]}, registry)
	assert_eq((bad[1] as Array).size(), 2, "Companheiro desconhecido e ficha inválida apontados: %s" % str(bad[1]))
	_end()


func test_dialogue_conditions_gate_recruitment() -> void:
	_begin()
	var doran := _runner("dialogue.companion_doran")
	assert_eq(doran.node["id"], "wait", "Doran espera a missão de Ione")
	QuestManager.log.start("quest.goblin_chief", registry)
	doran = _runner("dialogue.companion_doran")
	assert_eq(doran.node["id"], "offer", "Com a missão aceita, ele oferece ajuda")
	var result := doran.choose(0)
	assert_true(result["lines"][0].contains("entrou para o grupo"), "Doran recrutado: %s" % str(result["lines"]))
	assert_true(PartyManager.roster.is_recruited("companion.doran"), "Doran no roster")

	var lyra := _runner("dialogue.companion_lyra")
	assert_eq(lyra.node["id"], "hello", "Lyra pede o lobo")
	lyra.choose(0)
	assert_eq(QuestManager.log.status("quest.lyra_wolf"), QuestLog.Status.ACTIVE, "Missão da Lyra aceita")
	assert_eq(_runner("dialogue.companion_lyra").node["id"], "reminder", "Lembrete enquanto o lobo vive")
	QuestManager.log.notify("defeat_encounter", "encounter.lone_wolf", registry)
	lyra = _runner("dialogue.companion_lyra", null, {"test_map.lone_wolf": true})
	assert_eq(lyra.node["id"], "proven", "Lobo vencido")
	var lines: Array[String] = lyra.choose(0)["lines"]
	assert_eq(QuestManager.log.status("quest.lyra_wolf"), QuestLog.Status.COMPLETED, "Missão concluída: %s" % str(lines))
	assert_eq(PartyManager.members.size(), 3, "Lyra entrou no grupo")
	_end()


func test_kael_requires_and_takes_fifteen_gold() -> void:
	_begin()
	PartyManager.inventory.gold = 10
	var kael := _runner("dialogue.companion_kael")
	assert_eq(_choice_index(kael, "Toma as 15 PO"), -1, "Sem ouro, não dá para pagar")
	assert_true(_choice_index(kael, "Não tenho") >= 0, "Opção de quem não tem ouro")
	PartyManager.inventory.gold = 20
	kael = _runner("dialogue.companion_kael")
	assert_eq(_choice_index(kael, "Não tenho"), -1, "Com ouro, some a desculpa")
	kael.choose(_choice_index(kael, "Toma as 15 PO"))
	assert_eq(PartyManager.inventory.gold, 5, "Pagou 15 PO")
	assert_true(PartyManager.roster.is_recruited("companion.kael"), "Kael recrutado")
	_end()


func test_tarka_arm_wrestling_uses_the_best_athlete_and_allows_retry() -> void:
	_begin()
	PartyManager.roster.recruit("companion.bruna", PartyManager.members, registry)
	var hero_bonus := CharacterSheet.build(PartyManager.members[0], registry).skill_bonus(&"athletics")
	var tarka := _runner("dialogue.companion_tarka", DiceRoller.scripted([2, 19] as Array[int]))
	var result := tarka.choose(0)
	assert_eq(tarka.node["id"], "lost", "d20 = 2 perde a queda de braço")
	assert_true(result["lines"][0].contains("Brena"), "Quem tenta é o mais forte (%s)" % result["lines"][0])
	assert_true(result["lines"][0].contains("%d" % (2 + hero_bonus)), "Mostra o total")
	assert_true(not PartyManager.roster.is_recruited("companion.tarka"), "Falhou: não recruta")
	tarka.choose(0)
	assert_eq(tarka.node["id"], "won", "Tentou de novo e venceu")
	tarka.choose(0)
	assert_true(PartyManager.roster.is_recruited("companion.tarka"), "Tarka recrutada")
	_end()


func test_registry_rejects_bad_companion_rules() -> void:
	registry = Content.registry
	var base: Dictionary = registry.get_entry("dialogue", "dialogue.companion_kael").duplicate(true)
	base["nodes"][0]["choices"][0]["action"] = "pay_gold:15;recruit:companion.nobody"
	base["nodes"][0]["choices"][1]["condition"] = "gold_below:muito"
	var saved := registry.errors.duplicate()
	registry.errors.clear()
	registry._check_dialogue("dialogue.companion_kael", base)
	var found := registry.errors.duplicate()
	registry.errors = saved
	assert_true(found.any(func(e: String) -> bool: return e.contains("companheiro inexistente")),
			"Companheiro inexistente apontado: %s" % str(found))
	assert_true(found.any(func(e: String) -> bool: return e.contains("valor inválido")), "Ouro inválido apontado")
	assert_eq(found.size(), 2, "Só os dois problemas (pay_gold:15 é válido)")


func test_companion_npcs_appear_until_recruited() -> void:
	_begin()
	var map := await _open(FOREST)
	var tarka := map.get_node("Objects/Tarka") as CompanionNpc
	var ignis := map.get_node("Objects/Ignis") as CompanionNpc
	assert_true(tarka.visible and tarka.enabled, "Tarka no Bosque do Riacho")
	assert_eq(tarka.prompt_text, "Conversar com Tarka", "Aviso com o nome")
	assert_true(not ignis.visible and not ignis.enabled, "Ignis só aparece depois de Garra-Rubra")
	await _close(map)
	ExplorationManager.resolved_triggers["forest_brook.goblin_chief"] = true
	map = await _open(FOREST)
	ignis = map.get_node("Objects/Ignis") as CompanionNpc
	assert_true(ignis.visible, "Ignis amarrado no acampamento")
	ignis.interact()
	var hud: ExplorationHud = map.get_node("%Hud")
	assert_eq(hud.get_speaker_name(), "Ignis", "Ignis conversa")
	assert_true(hud.get_portrait() != null, "Retrato pintado do companheiro")
	map.choose_dialogue_option(0)
	map.choose_dialogue_option(0)
	map.handle_interact()
	assert_true(PartyManager.roster.is_recruited("companion.ignis"), "Ignis recrutado")
	assert_true(not ignis.visible, "Some do mapa depois de recrutado")
	assert_eq(map.followers().size(), 1, "Segue o líder")
	assert_eq(map.followers()[0].character.name, "Ignis Escama-Rubra", "Seguidor é o Ignis")
	await _close(map)
	_end()


func test_inn_panel_swaps_members_and_tab_cycles_sheets() -> void:
	_begin()
	for id in ["companion.doran", "companion.bruna", "companion.lyra"]:
		PartyManager.roster.recruit(id, PartyManager.members, registry)
	var map := await _open(VILLAGE)
	var hud: ExplorationHud = map.get_node("%Hud")
	if hud.is_message_open():
		map.handle_interact()
	assert_true(not (map.get_node("Objects/Doran") as CompanionNpc).visible, "Doran recrutado não fica na praça")
	assert_eq(map.followers().size(), 2, "Dois seguidores")
	(map.get_node("Objects/InnRegister") as Interactable).interact()
	map.handle_interact()
	assert_true(hud.party_panel.visible, "Livro de hóspedes abre o painel do grupo")
	assert_true(hud.party_panel.get_plain_text().contains("Lyra Vento-Leste"), "Lyra esperando na estalagem")
	assert_true(hud.party_panel.get_plain_text().contains("Kael"), "Mostra quem falta conhecer")
	var buttons := hud.party_panel.buttons()
	# Botões: [Doran sai, Bruna sai, Lyra entra (desabilitado: grupo cheio)].
	assert_eq(buttons.size(), 3, "Três botões")
	assert_true(buttons[2].disabled, "Grupo cheio: Lyra não entra")
	buttons[0].pressed.emit()
	await tree.process_frame
	assert_eq(PartyManager.members.size(), 2, "Doran deixado na estalagem")
	assert_eq(map.followers().size(), 1, "Um seguidor")
	buttons = hud.party_panel.buttons()
	var lyra_button := buttons.filter(func(b: Button) -> bool: return not b.disabled and b.text == "Trazer para o grupo")
	assert_eq(lyra_button.size(), 2, "Doran e Lyra podem entrar")
	map.close_overlays()
	map.toggle_character_sheet()
	assert_true(hud.get_sheet_text().contains("Brena"), "Ficha do líder primeiro")
	map.cycle_member()
	assert_true(hud.get_sheet_text().contains("Bruna"), "Tab mostra a ficha da Bruna")
	map.cycle_member()
	assert_true(hud.get_sheet_text().contains("Brena"), "Volta ao líder")
	map.close_overlays()
	await _close(map)
	_end()


func test_fallen_allies_get_up_with_one_hp_after_victory() -> void:
	var hero := _begin()
	PartyManager.roster.recruit("companion.bruna", PartyManager.members, registry)
	var bruna := PartyManager.members[1]
	var manager := CombatManager.new()
	var party: Array[Combatant] = []
	for c in PartyManager.members:
		party.append(Combatant.from_character(c, registry))
	var enemies: Array[Combatant] = [Combatant.from_monster(registry.get_entry("monster", "monster.wolf"), 1, 1)]
	manager.setup(party, enemies, Vector2i(12, 8), true, DiceRoller.new(3))
	manager.start()
	party[1].hp = 0
	enemies[0].hp = 0
	manager._check_end()
	assert_eq(manager.outcome, CombatManager.Outcome.VICTORY, "Vitória")
	manager.apply_results_to_party(registry)
	assert_eq(bruna.current_hp, 1, "Bruna se levanta com 1 PV")
	assert_true(hero.current_hp > 0, "Líder de pé")
	_end()
