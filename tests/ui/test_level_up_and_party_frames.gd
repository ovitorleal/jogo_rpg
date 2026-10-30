extends "res://tests/base_test.gd"
## Subida de nível (aviso "VOCÊ SUBIU DE NÍVEL!" e efeito no personagem) e retratos do grupo na lateral.

const FACTORY_TESTS := preload("res://tests/characters/test_character_factory.gd")
const VILLAGE := "res://scenes/world/village.tscn"

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


func test_level_ups_are_announced_once() -> void:
	var hero := _begin()
	assert_eq(PartyManager.take_level_ups().size(), 0, "Novo jogo: nada a anunciar")
	Progression.award_xp(hero, Progression.XP_FOR_LEVEL[2], registry)
	assert_eq(PartyManager.take_level_ups(), [hero] as Array[CharacterData], "Subiu para o nível 2")
	assert_eq(PartyManager.take_level_ups().size(), 0, "Anunciado uma vez só")
	PartyManager.roster.recruit("companion.doran", PartyManager.members, registry)
	assert_eq(PartyManager.take_level_ups().size(), 0, "Recém-recrutado entra sem aviso")
	_end()


func test_map_shows_banner_and_effect_after_leveling() -> void:
	var hero := _begin()
	Progression.award_xp(hero, Progression.XP_FOR_LEVEL[2], registry)
	var map := await _open(VILLAGE)
	var hud: ExplorationHud = map.get_node("%Hud")
	assert_true(hud.level_up_banner.is_showing(), "Aviso na tela")
	assert_eq(hud.level_up_banner.title_text(), "VOCÊ SUBIU DE NÍVEL!", "Aviso do protagonista")
	assert_true(hud.level_up_banner.subtitle_text().begins_with("Nível 2"), "Novo nível: %s" % hud.level_up_banner.subtitle_text())
	assert_true(map.get_node("%Player").has_node("LevelUpEffect"), "Luz e faíscas no personagem")
	await _close(map)
	_end()


func test_companion_level_up_uses_the_name() -> void:
	_begin()
	PartyManager.roster.recruit("companion.doran", PartyManager.members, registry)
	PartyManager.take_level_ups()
	var map := await _open(VILLAGE)
	var doran := PartyManager.members[1]
	Progression.award_xp(doran, Progression.XP_FOR_LEVEL[2] - doran.experience, registry)
	map.announce_level_ups()
	var hud: ExplorationHud = map.get_node("%Hud")
	assert_eq(hud.level_up_banner.title_text(), "DORAN SUBIU DE NÍVEL!", "Aviso com o nome do companheiro")
	assert_true(map.followers()[0].has_node("LevelUpEffect"), "Efeito no seguidor")
	await _close(map)
	_end()


func test_party_frames_show_each_member_and_open_their_sheet() -> void:
	_begin()
	PartyManager.roster.recruit("companion.bruna", PartyManager.members, registry)
	var map := await _open(VILLAGE)
	var hud: ExplorationHud = map.get_node("%Hud")
	if hud.is_message_open():
		map.handle_interact()
	assert_eq(hud.party_frames.frame_count(), 2, "Um retrato por membro")
	assert_true(hud.party_frames.frame_text(0).contains("Brena") and hud.party_frames.frame_text(0).contains("PV 12/12"),
			"Nome e PV do líder: %s" % hud.party_frames.frame_text(0))
	PartyManager.members[1].current_hp = 3
	map.refresh_party_frames()
	await tree.process_frame
	assert_true(hud.party_frames.frame_text(1).contains("PV 3/"), "PV atualizado")
	map.open_member_sheet(1)
	assert_true(hud.get_sheet_text().contains("Bruna"), "Clique no retrato abre a ficha do membro")
	map.close_overlays()
	await _close(map)
	_end()
