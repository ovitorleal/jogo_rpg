extends "res://tests/base_test.gd"
## EncounterDirector e TravelSystem: filtros, sorteio, tempo, rações, eventos, descanso,
## combate pendente, serialização e reprodutibilidade.

const FACTORY_TESTS := preload("res://tests/characters/test_character_factory.gd")

var registry: ContentRegistry


func _registry() -> ContentRegistry:
	if registry == null:
		registry = ContentRegistry.new()
		registry.load_all()
	return registry


func _party() -> Array[CharacterData]:
	return [CharacterFactory.create(FACTORY_TESTS.new().fighter_choices(), _registry())[0]] as Array[CharacterData]


func _travel(seed_number: int = 7) -> TravelSystem:
	var travel := TravelSystem.new()
	travel.start(_registry().get_entry("route", "route.east_road"), seed_number)
	return travel


func _inv(rations: int) -> Inventory:
	var inventory := Inventory.new()
	inventory.add(Inventory.RATIONS, rations)
	return inventory


func _ids(rows: Array[Dictionary]) -> Array:
	return rows.map(func(r: Dictionary) -> String: return r["id"])


# --- EncounterDirector --------------------------------------------------------

func test_day_and_night_filters() -> void:
	var region := _registry().get_entry("region", "region.whispering_forest")
	var day := _ids(EncounterDirector.candidates(region, 10, 1, 1, [], {}, _registry()))
	var night := _ids(EncounterDirector.candidates(region, 22, 1, 1, [], {}, _registry()))
	assert_true("encounter.goblin_scout" in day and not "encounter.wolf_pair" in day, "De dia: goblin, sem matilha")
	assert_true("encounter.wolf_pair" in night and not "encounter.goblin_scout" in night, "À noite: matilha, sem goblin")
	assert_true("encounter.lone_wolf" in day and "encounter.lone_wolf" in night, "Lobo solitário a qualquer hora")
	assert_true(EncounterDirector.is_night(5) and EncounterDirector.is_night(19) and not EncounterDirector.is_night(6),
			"Noite das 19h às 6h")


func test_once_history_and_xp_budget_filters() -> void:
	var region := _registry().get_entry("region", "region.whispering_forest")
	var rows := _ids(EncounterDirector.candidates(region, 10, 1, 1, ["event.fallen_tree"], {"event.peddler": true}, _registry()))
	assert_true(not "event.fallen_tree" in rows, "Não repete o último acontecimento")
	assert_true(not "event.peddler" in rows, "Evento único já resolvido não volta")
	assert_eq(EncounterDirector.xp_budget(1, 1), 100, "Orçamento: 100 XP por nível por personagem")
	assert_eq(EncounterDirector.encounter_xp(_registry().get_entry("encounter", "encounter.wolf_pair"), _registry()), 100, "Dois lobos = 100 XP")
	var strong := region.duplicate(true)
	var registry_copy := ContentRegistry.new()
	var data := {}
	for type_name: String in ContentRegistry.TYPES:
		data[type_name] = []
		for id in _registry().ids(type_name):
			data[type_name].append(_registry().get_entry(type_name, id).duplicate(true))
	data["encounter"].append({"id": "encounter.wolf_pack", "name": "Matilha", "description": "Três lobos.", "source": "original",
			"enemies": [{"monster_id": "monster.wolf", "count": 3}], "flee_allowed": true, "arena_width": 12,
			"arena_height": 8, "intro_text": "Uivos!"})
	assert_true(registry_copy.load_from_dictionaries(data), "Registro de teste válido: %s" % str(registry_copy.errors))
	strong["table"] = [{"kind": "combat", "id": "encounter.wolf_pack", "weight": 10, "time": "any", "once": false}]
	assert_true(EncounterDirector.candidates(strong, 22, 1, 1, [], {}, registry_copy).is_empty(),
			"150 XP excede o orçamento de um personagem de nível 1")
	assert_eq(EncounterDirector.candidates(strong, 22, 2, 1, [], {}, registry_copy).size(), 1, "Nível 2 comporta")


func test_weighted_choice() -> void:
	var region := _registry().get_entry("region", "region.whispering_forest")
	var quiet := EncounterDirector.choose(region, 10, 1, 1, [], {}, _registry(), DiceRoller.scripted([30]))
	assert_eq(quiet["kind"], "quiet", "Até o peso do trecho tranquilo (30): nada acontece")
	var first := EncounterDirector.choose(region, 10, 1, 1, [], {}, _registry(), DiceRoller.scripted([31]))
	assert_eq([first["kind"], first["id"]], ["combat", "encounter.lone_wolf"], "31: primeira linha válida")


# --- TravelSystem -------------------------------------------------------------

func test_advance_consumes_rations_and_time() -> void:
	var travel := _travel()
	travel.roller_override = DiceRoller.scripted([1])
	var supplies := _inv(2)
	var result := travel.advance(_party(), _registry(), supplies)
	assert_true(result["ok"] and result["kind"] == "quiet", "Trecho tranquilo (rolagem 1)")
	assert_eq(supplies.count(Inventory.RATIONS), 1, "1 ração por membro por trecho")
	assert_eq([travel.segments_done, travel.hour()], [1, 11], "Partida às 8h + 3h")
	assert_true(travel.time_label().contains("Dia 1, 11:00"), "Rótulo de tempo")


func test_hunger_without_rations() -> void:
	var travel := _travel()
	travel.roller_override = DiceRoller.scripted([1])
	var supplies := _inv(0)
	travel.advance(_party(), _registry(), supplies)
	assert_true(travel.hungry, "Sem rações, o grupo fica com fome")
	assert_true(not travel.long_rest(_party(), _registry(), supplies)["ok"], "Não pode acampar sem rações")


func test_full_quiet_trip_arrives() -> void:
	var travel := _travel()
	travel.roller_override = DiceRoller.scripted([1, 1, 1, 1])
	var supplies := _inv(10)
	var last := {}
	for i in 4:
		last = travel.advance(_party(), _registry(), supplies)
	assert_eq(last["kind"], "arrived", "Último trecho chega ao destino")
	assert_true(travel.is_arrived(_registry()), "Viagem concluída")
	assert_true(not travel.advance(_party(), _registry(), supplies)["ok"], "Não avança depois de chegar")


func test_event_blocks_until_choice_and_applies_success() -> void:
	var travel := _travel()
	var party := _party()
	var supplies := _inv(5)
	travel.pending = {"kind": "event", "id": "event.berry_bushes"}
	assert_true(not travel.advance(party, _registry(), supplies)["ok"], "Evento pendente bloqueia a viagem")
	# Sobrevivência do Guerreiro: SAB 12 (+1), proficiente (+2) = +3; 15 + 3 = 18 >= CD 10.
	travel.roller_override = DiceRoller.scripted([15])
	var result := travel.choose_option("forage", party, _registry(), supplies)
	assert_true(result["ok"] and result["success"], "Teste bem-sucedido")
	assert_eq(supplies.count(Inventory.RATIONS), 6, "+1 ração")
	assert_true(travel.pending.is_empty(), "Evento resolvido")
	assert_eq(travel.history[-1], "event.berry_bushes", "Histórico registra o evento")


func test_event_failure_damage_never_drops_to_zero() -> void:
	var travel := _travel()
	var party := _party()
	party[0].current_hp = 2
	travel.pending = {"kind": "event", "id": "event.fallen_tree"}
	# Atletismo +5; 1 + 5 = 6 < 12: falha; dano 1d6 = 6.
	travel.roller_override = DiceRoller.scripted([1, 6])
	var result := travel.choose_option("climb", party, _registry(), _inv(3))
	assert_true(result["ok"] and not result["success"], "Falha no teste")
	assert_eq(party[0].current_hp, 1, "Perigo de evento deixa com no mínimo 1 PV")


func test_event_resistance_and_xp() -> void:
	var travel := _travel()
	var dwarf: CharacterData = CharacterFactory.create(FACTORY_TESTS.new().rogue_choices(), _registry())[0]
	var party: Array[CharacterData] = [dwarf]
	travel.pending = {"kind": "event", "id": "event.berry_bushes"}
	# Ladino anão sem Sobrevivência: SAB 13 (+1); 2 + 1 = 3 < 10; veneno 1d4 = 4 -> resistência: 2.
	travel.roller_override = DiceRoller.scripted([2, 4])
	travel.choose_option("forage", party, _registry(), _inv(3))
	assert_eq(dwarf.current_hp, 9, "11 - 2 (resistência a veneno do Anão)")
	travel.pending = {"kind": "event", "id": "event.peddler"}
	travel.roller_override = DiceRoller.scripted([18])
	var supplies := _inv(0)
	travel.choose_option("listen", party, _registry(), supplies)
	assert_eq([dwarf.experience, supplies.count(Inventory.RATIONS)], [25, 2], "Mascate: +25 XP e +2 rações")
	assert_true(travel.resolved_once.has("event.peddler"), "Evento único marcado como resolvido")


func test_combat_pending_and_resolution() -> void:
	var travel := _travel()
	travel.roller_override = DiceRoller.scripted([31])
	var result := travel.advance(_party(), _registry(), _inv(3))
	assert_eq([result["kind"], result["id"]], ["combat", "encounter.lone_wolf"], "Combate sorteado")
	assert_eq(travel.pending, {"kind": "combat", "id": "encounter.lone_wolf"}, "Combate pendente")
	assert_true(not travel.short_rest(_party(), _registry())["ok"], "Não descansa com combate pendente")
	travel.resolve_combat(CombatManager.Outcome.VICTORY)
	assert_true(travel.pending.is_empty(), "Combate resolvido libera a viagem")


func test_rests_during_travel() -> void:
	var travel := _travel()
	var party := _party()
	party[0].current_hp = 4
	travel.roller_override = DiceRoller.scripted([5])
	var short := travel.short_rest(party, _registry())
	assert_true(short["ok"] and party[0].current_hp == 11, "Descanso curto: 4 + 5 + 2")
	assert_eq(travel.hour(), 9, "Descanso curto leva 1 hora")
	var supplies := _inv(1)
	assert_true(travel.long_rest(party, _registry(), supplies)["ok"], "Acampar com ração")
	assert_eq([party[0].current_hp, party[0].hit_dice_spent, supplies.count(Inventory.RATIONS), travel.hour()], [12, 0, 0, 17],
			"Descanso longo: PV e dados cheios, -1 ração, +8 horas")


func test_serialization_round_trip_mid_travel() -> void:
	var travel := _travel(99)
	travel.advance(_party(), _registry(), _inv(9))
	travel.pending = {"kind": "event", "id": "event.peddler"}
	travel.resolved_once["event.lost_child"] = true
	var copy := TravelSystem.from_dict(JSON.parse_string(JSON.stringify(travel.to_dict())))
	assert_eq(copy.to_dict(), travel.to_dict(), "Estado idêntico após ida e volta em JSON")


func test_same_seed_same_journey() -> void:
	var kinds_a := []
	var kinds_b := []
	for kinds: Array in [kinds_a, kinds_b]:
		var travel := _travel(1234)
		var party := _party()
		var supplies := _inv(20)
		for i in 4:
			var result := travel.advance(party, _registry(), supplies)
			kinds.append("%s:%s" % [result.get("kind"), result.get("id")])
			if travel.pending.get("kind") == "combat":
				travel.resolve_combat(CombatManager.Outcome.VICTORY)
			elif travel.pending.get("kind") == "event":
				travel.choose_option(_registry().get_entry("event", travel.pending["id"])["choices"][0]["id"], party, _registry(), supplies)
	assert_eq(kinds_a, kinds_b, "Mesma semente, mesma viagem: %s" % str(kinds_a))


func test_many_journeys_always_finish() -> void:
	for seed_number in range(1, 41):
		var travel := _travel(seed_number)
		var party := _party()
		var supplies := _inv(3)
		var steps := 0
		while not travel.is_arrived(_registry()) and steps < 20:
			steps += 1
			if travel.pending.get("kind") == "combat":
				travel.resolve_combat(CombatManager.Outcome.VICTORY)
			elif travel.pending.get("kind") == "event":
				var event := _registry().get_entry("event", travel.pending["id"])
				var result := travel.choose_option(event["choices"][-1]["id"], party, _registry(), supplies)
				assert_true(result["ok"], "Escolha válida (semente %d)" % seed_number)
			else:
				assert_true(travel.advance(party, _registry(), supplies)["ok"], "Avança (semente %d)" % seed_number)
			assert_true(party[0].current_hp >= 1, "Eventos não derrubam (semente %d)" % seed_number)
			assert_true(supplies.count(Inventory.RATIONS) >= 0, "Rações nunca negativas (semente %d)" % seed_number)
		assert_true(travel.is_arrived(_registry()), "Viagem termina (semente %d)" % seed_number)
