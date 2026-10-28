extends "res://tests/base_test.gd"
## Aparência modular: perfis por espécie, pintura determinística, validação, save e tela de criação.

const SCENE := "res://scenes/menus/character_creation.tscn"

var registry: ContentRegistry


func _registry() -> ContentRegistry:
	if registry == null:
		registry = ContentRegistry.new()
		registry.load_all()
	return registry


func _character(species_id: String = "species.human") -> CharacterData:
	var species := _registry().get_entry("species", species_id)
	var extra: Array[StringName] = []
	for skill in CharacterFactory.species_skill_options(species):
		if extra.size() < int(species.get("extra_skill_choices", 0)) and not skill in [&"perception", &"survival", &"athletics", &"intimidation"]:
			extra.append(skill)
	var result := CharacterFactory.create({
		"name": "Lio",
		"species_id": species_id,
		"class_id": "class.fighter",
		"background_id": "background.soldier",
		"ability_method": "standard_array",
		"base_scores": {&"str": 15, &"dex": 13, &"con": 14, &"int": 8, &"wis": 12, &"cha": 10},
		"background_increases": {&"str": 2, &"con": 1},
		"class_skills": [&"perception", &"survival"],
		"species_skills": extra,
		"expertise": [],
	}, _registry())
	return result[0]


func test_every_species_has_a_valid_profile() -> void:
	var reg := _registry()
	assert_eq(reg.errors, [] as Array[String], "Registro sem erros com os perfis de aparência")
	for species_id in reg.ids("species"):
		var profile := Appearance.profile_for(species_id, reg)
		assert_true(not profile.is_empty(), "Perfil para %s" % species_id)
		assert_true(profile.get("body", []).size() == 2, "%s oferece corpo Masculino/Feminino" % species_id)


func test_sheets_and_portraits_have_expected_size_and_are_deterministic() -> void:
	var reg := _registry()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for species_id in reg.ids("species"):
		var profile := Appearance.profile_for(species_id, reg)
		var look := Appearance.random_look(profile, rng)
		var gear := {"armor": "medium", "shield": true, "weapon": "sword"}
		var sheet := CharacterPainter.paint_sheet(look, profile, gear)
		assert_eq(sheet.get_size(), Vector2i(576, 256), "Folha 9x4 quadros 64x64 para %s" % species_id)
		assert_eq(CharacterPainter.paint_portrait(look, profile, gear).get_size(), Vector2i(64, 64), "Retrato 64x64")
		var again := CharacterPainter.paint_sheet(look, profile, gear)
		assert_eq(again.get_data(), sheet.get_data(), "Mesma aparência gera a mesma folha (%s)" % species_id)
		assert_true(not sheet.get_region(Rect2i(0, 0, 64, 64)).is_invisible(), "Quadro parado não está vazio")


func test_options_change_the_drawing() -> void:
	var reg := _registry()
	var profile := Appearance.profile_for("species.tiefling", reg)
	var look := CharacterPainter.default_appearance(profile)
	var base := CharacterPainter.paint_sheet(look, profile, {}).get_data()
	for change: Array in [["horns", "curved"], ["tail", "thin"], ["body", "feminine"], ["hair_style", "short"], ["skin", 3]]:
		var other := look.duplicate()
		other[change[0]] = change[1]
		assert_true(CharacterPainter.paint_sheet(other, profile, {}).get_data() != base, "%s altera o desenho" % change[0])


func test_validation_rejects_options_from_other_species() -> void:
	var c := _character("species.human")
	assert_true(c != null, "Personagem base criado")
	if c == null:
		return
	c.appearance = {"horns": "ram"}
	assert_true(not Appearance.validate(c, _registry()).is_empty(), "Humano não tem chifres")
	c.appearance = {"skin": 99}
	assert_true(not Appearance.validate(c, _registry()).is_empty(), "Índice de cor fora da lista")
	c.appearance = {"wings": "big"}
	assert_true(not Appearance.validate(c, _registry()).is_empty(), "Campo desconhecido")
	c.appearance = {"beard": "full", "body": "feminine", "skin": 2}
	assert_eq(CharacterFactory.validate(c, _registry()), [] as Array[String], "Escolhas válidas passam")


func test_appearance_survives_save_round_trip() -> void:
	var c := _character("species.dwarf")
	assert_true(c != null, "Anão criado")
	if c == null:
		return
	c.appearance = {"beard": "braided", "hair_color": 2, "body": "feminine"}
	var data: Variant = JSON.parse_string(JSON.stringify(c.to_dict()))
	var result := CharacterData.from_dict(data)
	var loaded: CharacterData = result[0]
	assert_true(loaded != null, "Recarrega: %s" % str(result[1]))
	if loaded != null:
		assert_eq(loaded.appearance, c.appearance, "Aparência preservada (índices voltam a int)")
		assert_eq(Appearance.key_for(loaded, _registry()), Appearance.key_for(c, _registry()), "Mesma chave de cache")


func test_migration_from_schema_2_uses_species_defaults() -> void:
	var c := _character("species.elf")
	var data := c.to_dict()
	data.erase("appearance")
	data["schema_version"] = 2
	var result := CharacterData.from_dict(data)
	var loaded: CharacterData = result[0]
	assert_true(loaded != null, "Save v2 carrega: %s" % str(result[1]))
	if loaded != null:
		assert_eq(loaded.appearance, {}, "Sem escolhas salvas")
		assert_eq(Appearance.resolve(loaded, _registry())["ears"], "pointed_long", "Padrão élfico aplicado")


func test_combatant_uses_class_figure() -> void:
	var c := _character("species.orc")
	var unit := Combatant.from_character(c, _registry())
	assert_true(unit.sprite_texture != null, "Combatente usa a ilustração")
	assert_eq(unit.sprite_texture.resource_path, Appearance.class_figure_path(c.class_id), "Ilustração da classe")
	var frames := SpriteLibrary.frames_for_texture(unit.sprite_key, unit.sprite_texture)
	for anim in ["idle_down", "walk_left", "attack_right", "walk_up"]:
		assert_true(frames.has_animation(anim), "Animação %s feita por código" % anim)
	assert_eq(frames.get_frame_count(&"walk_right"), 4, "Caminhada com balanço")
	assert_true(Appearance.portrait_texture(c, _registry()) is AtlasTexture, "Retrato = busto da ilustração")


func test_companion_figure_overrides_class() -> void:
	var c := CompanionRoster.build(_registry().get_entry("companion", "companion.doran"), 1, _registry())
	assert_eq(Appearance.figure_path(c, _registry()), "res://assets/characters/arghaz/species_dwarf.png",
			"Doran usa a ilustração do anão, não a da clériga")
	for id in _registry().ids("companion"):
		var figure := str(_registry().get_entry("companion", id).get("figure", ""))
		assert_true(figure.is_empty() or ResourceLoader.exists("res://assets/characters/arghaz/%s.png" % figure),
				"%s: ilustração existe" % id)


func test_every_class_and_species_has_a_figure() -> void:
	for id in _registry().ids("class"):
		assert_true(ResourceLoader.exists(Appearance.class_figure_path(id)), "%s tem ilustração" % id)
	for id in _registry().ids("species"):
		assert_true(ResourceLoader.exists(Appearance.species_figure_path(id)), "%s tem ilustração" % id)


func test_creation_screen_appearance_controls() -> void:
	var screen: Control = (load(SCENE) as PackedScene).instantiate()
	tree.root.add_child(screen)
	await tree.process_frame
	await tree.process_frame
	screen.select_species("species.tiefling")
	await tree.process_frame
	assert_true(screen.get_look()["horns"] != "none", "Tiefling começa com chifres")
	screen.set_look("tail", "thin")
	await tree.process_frame
	var c: CharacterData = screen.get_character()
	assert_true(c != null and c.appearance.get("tail") == "thin", "Escolha chega ao personagem")
	screen.select_species("species.human")
	await tree.process_frame
	assert_eq([screen.get_look()["horns"], screen.get_look()["tail"]], ["none", "none"], "Trocar espécie remove peças inválidas")
	c = screen.get_character()
	assert_true(c != null, "Continua válido após trocar de espécie")
	for seed_value in 12:
		screen.randomize_look(seed_value)
		await tree.process_frame
		assert_true(screen.get_character() != null, "Aparência aleatória %d é válida" % seed_value)
	screen.queue_free()
	await tree.process_frame
