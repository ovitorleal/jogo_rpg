extends Control
## Criação de personagem (nível 1): formulário à esquerda, ficha ao vivo à direita.
## A validação é sempre a do CharacterFactory; esta tela só coleta escolhas.

const TITLE_SCENE := "res://scenes/menus/title_screen.tscn"
const START_SCENE := "res://scenes/world/village.tscn"
const INTRO_TEXT := "Depois de dias de estrada, você chega à Vila de Ribeira. Os moradores cochicham sobre goblins " \
		+ "na floresta... Dizem que Ione, a chefe da vila, procura alguém corajoso. Ela costuma ficar perto do poço da praça."
const DEFAULT_NAME := "Viajante"
const LABEL_WIDTH := 92.0
const LOOK_LABELS := {
	"body": "Corpo", "build": "Porte", "hair_style": "Cabelo", "beard": "Barba", "ears": "Orelhas",
	"horns": "Chifres", "tail": "Cauda", "marks": "Marcas", "face": "Rosto", "accessory": "Acessório",
	"cloak": "Capa",
}
const SWATCH_LABELS := {
	"skin": "Pele", "hair_color": "Cor do cabelo", "eye_color": "Olhos", "outfit": "Roupa", "cloak_color": "Cor da capa",
}
## Sequência da prévia animada: cada passo dura LOOK_STEP segundos; a direção gira a cada volta.
const LOOK_SEQUENCE: Array[String] = ["idle", "walk", "walk", "attack"]
const LOOK_STEP := 1.4
const NO_GEAR := {"armor": "none", "shield": false, "weapon": "none"}

var _registry: ContentRegistry
var _species_id: String = ""
var _class_id: String = ""
var _background_id: String = ""
var _scores: Dictionary = {}
## 0 = +2 e +1; 1 = +1 em três
var _bonus_mode: int = 0
var _plus_two: StringName = &""
var _plus_one: StringName = &""
var _class_skills: Array[StringName] = []
var _species_skills: Array[StringName] = []
var _expertise: Array[StringName] = []
var _cantrips: Array[String] = []
var _prepared: Array[String] = []
## Escolhas de talentos/características (CharacterChoices), editadas pelo ChoicesPanel.
var _choices: Dictionary = {}
var _character: CharacterData = null
var _refresh_queued := false
## Aparência completa escolhida (todas as categorias e índices de cor).
var _look: Dictionary = {}
var _look_rng := RandomNumberGenerator.new()
var _look_step := 0
var _look_direction := 0
## Chave da aparência mostrada na prévia; a folha é pintada uma direção por quadro.
var _look_key := ""

var _name_edit: LineEdit
var _species_option: OptionButton
var _class_option: OptionButton
var _background_option: OptionButton
var _score_options: Dictionary = {}
var _bonus_mode_option: OptionButton
var _plus_two_row: Control
var _plus_one_row: Control
var _plus_two_option: OptionButton
var _plus_one_option: OptionButton
var _background_skills_label: Label
var _class_skills_box: VBoxContainer
var _species_skills_box: VBoxContainer
var _expertise_box: VBoxContainer
var _spells_section: Control
var _spells_box: VBoxContainer
var _choices_panel: ChoicesPanel
var _look_options: Dictionary = {}
var _look_rows: Dictionary = {}
var _swatch_boxes: Dictionary = {}
var _swatch_rows: Dictionary = {}
var _look_sprite: AnimatedSprite2D
var _look_portrait: TextureRect
var _appearance_section: Control
var _random_look_button: Button
## Legenda da prévia ("Bárbaro · Draconato") quando há ilustrações.
var _figure_caption: Label

@onready var _form: VBoxContainer = %Form
@onready var _preview: CharacterSheetPanel = %Preview
@onready var _start_button: Button = %StartButton
@onready var _back_button: Button = %BackButton


func _ready() -> void:
	_registry = Content.registry
	_build_form()
	_species_id = _first_id("species")
	_class_id = _first_id("class")
	_background_id = _first_id("background")
	_look = CharacterPainter.default_appearance(_profile())
	_build_look_preview()
	_apply_class_defaults()
	_fix_choices(true)
	_start_button.pressed.connect(_on_start_pressed)
	_back_button.pressed.connect(_on_back_pressed)
	_refresh()
	_name_edit.grab_focus()


## Escolhas atuais no formato aceito por CharacterFactory.create().
func build_choices() -> Dictionary:
	var increases := {}
	if _bonus_mode == 0:
		increases[_plus_two] = 2
		increases[_plus_one] = int(increases.get(_plus_one, 0)) + 1
	else:
		for ability: Variant in _background().get("ability_options", []):
			increases[StringName(ability)] = 1
	return {
		"name": _name_edit.text,
		"species_id": _species_id,
		"class_id": _class_id,
		"background_id": _background_id,
		"ability_method": "standard_array",
		"base_scores": _scores.duplicate(),
		"background_increases": increases,
		"class_skills": _class_skills.duplicate(),
		"species_skills": _species_skills.duplicate(),
		"expertise": _expertise.duplicate(),
		"cantrips": _cantrips.duplicate(),
		"prepared_spells": _prepared.duplicate(),
		"choices": _choices.duplicate(true),
		"appearance": _look.duplicate(),
	}


## Personagem válido atual, ou null se as escolhas tiverem erros.
func get_character() -> CharacterData:
	return _character


func set_character_name(text: String) -> void:
	_name_edit.text = text
	_refresh()


func select_species(species_id: String) -> void:
	_select_by_metadata(_species_option, species_id)
	_on_species_selected(_species_option.selected)


func select_class(class_id: String) -> void:
	_select_by_metadata(_class_option, class_id)
	_on_class_selected(_class_option.selected)


## Aparência atual (cópia).
func get_look() -> Dictionary:
	return _look.duplicate()


## Escolhe uma peça (ex.: "horns", "ram") ou índice de cor (ex.: "skin", 2).
func set_look(key: String, value: Variant) -> void:
	_look[key] = value
	_queue_refresh()


func randomize_look(seed_value: int = -1) -> void:
	if seed_value >= 0:
		_look_rng.seed = seed_value
	else:
		_look_rng.randomize()
	_look = Appearance.random_look(_profile(), _look_rng)
	_queue_refresh()


func _profile() -> Dictionary:
	return Appearance.profile_for(_species_id, _registry)


func _class() -> Dictionary:
	return _registry.get_entry("class", _class_id)


func _species() -> Dictionary:
	return _registry.get_entry("species", _species_id)


func _background() -> Dictionary:
	return _registry.get_entry("background", _background_id)


func _first_id(type_name: String) -> String:
	var all := _registry.ids(type_name)
	return all[0] if not all.is_empty() else ""


# --- Construção do formulário -------------------------------------------------

func _build_form() -> void:
	_name_edit = LineEdit.new()
	_name_edit.text = DEFAULT_NAME
	_name_edit.placeholder_text = "Nome do personagem"
	_name_edit.max_length = CharacterData.MAX_NAME_LENGTH
	_name_edit.text_changed.connect(func(_t: String) -> void: _queue_refresh())
	_add_row("Nome", _name_edit)

	_species_option = _make_content_option("species")
	_species_option.item_selected.connect(_on_species_selected)
	_add_row("Espécie", _species_option)
	_class_option = _make_content_option("class")
	_class_option.item_selected.connect(_on_class_selected)
	_add_row("Classe", _class_option)
	_background_option = _make_content_option("background")
	_background_option.item_selected.connect(_on_background_selected)
	_add_row("Antecedente", _background_option)

	_add_section("Aparência")
	# Com a arte de Arghaz o visual vem da classe: o editor de partes fica escondido (a aparência
	# continua salva e serve de reserva quando não há ilustração).
	_appearance_section = _form.get_child(_form.get_child_count() - 1)
	for category: String in CharacterPainter.PARTS:
		var option := OptionButton.new()
		option.item_selected.connect(_on_look_selected.bind(category))
		_look_options[category] = option
		_look_rows[category] = _add_row(LOOK_LABELS[category], option)
	for key: String in SWATCH_LABELS:
		var box := HFlowContainer.new()
		box.add_theme_constant_override("h_separation", 2)
		box.add_theme_constant_override("v_separation", 2)
		_swatch_boxes[key] = box
		_swatch_rows[key] = _add_row(SWATCH_LABELS[key], box)

	_add_section("Atributos (arranjo padrão: cada valor uma vez)")
	for ability: StringName in Ability.ALL:
		var option := OptionButton.new()
		for value in RulesEngine.STANDARD_ARRAY:
			option.add_item(str(value))
			option.set_item_metadata(option.item_count - 1, value)
		option.item_selected.connect(_on_score_selected.bind(ability))
		_score_options[ability] = option
		_add_row(Ability.NAMES[ability], option)

	_add_section("Aumento do antecedente")
	_bonus_mode_option = OptionButton.new()
	_bonus_mode_option.add_item("+2 em um, +1 em outro")
	_bonus_mode_option.add_item("+1 em três")
	_bonus_mode_option.item_selected.connect(_on_bonus_mode_selected)
	_add_row("Modo", _bonus_mode_option)
	_plus_two_option = OptionButton.new()
	_plus_two_option.item_selected.connect(_on_plus_two_selected)
	_plus_two_row = _add_row("+2 em", _plus_two_option)
	_plus_one_option = OptionButton.new()
	_plus_one_option.item_selected.connect(_on_plus_one_selected)
	_plus_one_row = _add_row("+1 em", _plus_one_option)

	_add_section("Perícias")
	_background_skills_label = Label.new()
	_background_skills_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_form.add_child(_background_skills_label)
	_class_skills_box = VBoxContainer.new()
	_form.add_child(_class_skills_box)
	_species_skills_box = VBoxContainer.new()
	_form.add_child(_species_skills_box)
	_expertise_box = VBoxContainer.new()
	_form.add_child(_expertise_box)

	_add_section("Talentos e escolhas")
	_choices_panel = ChoicesPanel.new()
	_choices_panel.changed.connect(_on_choices_changed)
	_form.add_child(_choices_panel)

	_add_section("Magias")
	_spells_section = _form.get_child(_form.get_child_count() - 1)
	_spells_box = VBoxContainer.new()
	_form.add_child(_spells_box)


## Coluna com o personagem animado, o retrato e os botões Aleatório/Girar.
func _build_look_preview() -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 104
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	panel.add_child(column)
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(96, 190)
	holder.clip_contents = true
	_look_sprite = AnimatedSprite2D.new()
	_look_sprite.scale = Vector2(5, 5)
	_look_sprite.position = Vector2(48, 182)
	holder.add_child(_look_sprite)
	column.add_child(holder)
	_look_portrait = TextureRect.new()
	_look_portrait.custom_minimum_size = Vector2(64, 64)
	_look_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_look_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	column.add_child(_look_portrait)
	_figure_caption = Label.new()
	_figure_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_figure_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_figure_caption.visible = false
	column.add_child(_figure_caption)
	var random_button := Button.new()
	_random_look_button = random_button
	random_button.text = "Aleatório"
	random_button.pressed.connect(func() -> void: randomize_look())
	column.add_child(random_button)
	var turn_button := Button.new()
	turn_button.text = "Girar"
	turn_button.pressed.connect(func() -> void:
		_look_direction = (_look_direction + 1) % SpriteLibrary.FOUR_DIRECTIONS.size()
		_look_step = 0
		_play_look())
	column.add_child(turn_button)
	_preview.get_parent().add_child(panel)
	_preview.get_parent().move_child(panel, _preview.get_index())
	var timer := Timer.new()
	timer.wait_time = LOOK_STEP
	timer.timeout.connect(_on_look_tick)
	add_child(timer)
	timer.start()


func _make_content_option(type_name: String) -> OptionButton:
	var option := OptionButton.new()
	for id in _registry.ids(type_name):
		option.add_item(_registry.get_entry(type_name, id)["name"])
		option.set_item_metadata(option.item_count - 1, id)
	return option


func _add_section(title: String) -> void:
	var label := Label.new()
	label.text = title
	label.add_theme_color_override("font_color", Color(0.604, 0.659, 0.698))
	_form.add_child(HSeparator.new())
	_form.add_child(label)


func _add_row(label_text: String, control: Control) -> Control:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size.x = LABEL_WIDTH
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	row.add_child(control)
	_form.add_child(row)
	return row


# --- Regras de preenchimento --------------------------------------------------

func _apply_class_defaults() -> void:
	var suggested: Array = _class().get("suggested_scores", RulesEngine.STANDARD_ARRAY)
	for i in Ability.ALL.size():
		_scores[Ability.ALL[i]] = int(suggested[i])
	_class_skills.clear()
	_expertise.clear()
	_plus_two = &""
	_plus_one = &""


## Remove escolhas que ficaram inválidas e, com fill = true, completa as que faltam.
func _fill_from(chosen: Array[StringName], options: Array[StringName], blocked: Array[StringName],
		count: int, fill: bool) -> void:
	for skill in chosen.duplicate():
		if not skill in options or skill in blocked:
			chosen.erase(skill)
	while chosen.size() > count:
		chosen.pop_back()
	if fill:
		for skill in options:
			if chosen.size() >= count:
				break
			if not skill in chosen and not skill in blocked:
				chosen.append(skill)


func _fix_choices(fill: bool) -> void:
	var background_skills := _names(_background().get("skill_proficiencies", []))
	_fill_from(_class_skills, _names(_class().get("skill_options", [])), background_skills,
			int(_class().get("skill_choice_count", 0)), fill)
	_fill_from(_species_skills, CharacterFactory.species_skill_options(_species()),
			_names(background_skills + _class_skills), int(_species().get("extra_skill_choices", 0)), fill)
	_fix_look()
	_fix_spells(fill)
	var proficient := _names(background_skills + _class_skills + _species_skills)
	_fill_from(_expertise, proficient, [] as Array[StringName], int(_class().get("expertise_choices", 0)), fill)

	var options := _names(_background().get("ability_options", []))
	if not _plus_two in options:
		_plus_two = options[0]
		for ability: Variant in _class().get("primary_abilities", []):
			if StringName(ability) in options:
				_plus_two = StringName(ability)
				break
	if not _plus_one in options or _plus_one == _plus_two:
		for ability in options:
			if ability != _plus_two:
				_plus_one = ability
				break


## Troca peças e cores que a espécie atual não oferece pelo padrão dela.
func _fix_look() -> void:
	var profile := _profile()
	var defaults := CharacterPainter.default_appearance(profile)
	for category: String in CharacterPainter.PARTS:
		if not _look.get(category) in profile.get(category, CharacterPainter.PARTS[category]):
			_look[category] = defaults[category]
	for key: String in SWATCH_LABELS:
		if int(_look.get(key, -1)) < 0 or int(_look.get(key, -1)) >= _swatch_colors(key, profile).size():
			_look[key] = 0


func _swatch_colors(key: String, profile: Dictionary) -> Array:
	match key:
		"skin":
			return profile.get("skin_tones", [])
		"hair_color":
			return profile.get("hair_colors", [])
		"eye_color":
			return CharacterPainter.EYE_COLORS
		"outfit":
			return CharacterPainter.OUTFIT_COLORS
		_:
			return CharacterPainter.CLOAK_COLORS


func _names(values: Array) -> Array[StringName]:
	var result: Array[StringName] = []
	for v: Variant in values:
		result.append(StringName(v))
	return result


# --- Atualização --------------------------------------------------------------

func _queue_refresh() -> void:
	if not _refresh_queued:
		_refresh_queued = true
		_refresh.call_deferred()


func _refresh() -> void:
	_refresh_queued = false
	_sync_widgets()
	var result := CharacterFactory.create(build_choices(), _registry)
	_character = result[0]
	if _character != null:
		_preview.show_sheet(CharacterSheet.build(_character, _registry))
	else:
		_preview.show_errors("Ajuste as escolhas para continuar:", result[1])
	_start_button.disabled = _character == null
	if _character != null:
		_choices = _character.choices.duplicate(true)
		_choices_panel.show_choices(_character, _registry)
	_update_look_preview()


## Prévia com a ilustração do personagem: a espécie (vestida para a classe, quando houver essa arte).
func _update_figure_preview() -> bool:
	var path := Appearance.figure_for(_species_id, _class_id)
	var has_art := ResourceLoader.exists(path)
	_set_appearance_editor_visible(not has_art)
	_figure_caption.visible = has_art
	_look_portrait.visible = not has_art
	if not has_art:
		return false
	var key := "figure:%s" % path
	if key == _look_key:
		return true
	_look_key = key
	SpriteLibrary.attach(_look_sprite, SpriteLibrary.frames_for(path))
	_play_look()
	_figure_caption.text = "%s · %s" % [_class().get("name", ""), _species().get("name", "")]
	return true


func _set_appearance_editor_visible(shown: bool) -> void:
	_appearance_section.visible = shown
	_random_look_button.visible = shown
	for category: String in _look_rows:
		(_look_rows[category] as Control).visible = shown and (_look_rows[category] as Control).visible
	for key: String in _swatch_rows:
		(_swatch_rows[key] as Control).visible = shown and (_swatch_rows[key] as Control).visible


func _update_look_preview() -> void:
	if _update_figure_preview():
		return
	var profile := _profile()
	var gear: Dictionary = CharacterPainter.gear_for(_character, _registry) if _character != null else NO_GEAR
	var key := Appearance.key_of(_look, profile, gear)
	if key == _look_key:
		return
	_look_key = key
	_look_portrait.texture = Appearance.portrait_for(_look, profile, gear)
	var look := _look.duplicate()
	var sheet := CharacterPainter.empty_sheet()
	var texture: ImageTexture = null
	var order: Array[int] = [_look_direction]
	for row in CharacterPainter.DIRECTIONS.size():
		if row != _look_direction:
			order.append(row)
	for row in order:
		CharacterPainter.paint_row(sheet, look, profile, gear, row)
		if texture == null:
			texture = ImageTexture.create_from_image(sheet)
			SpriteLibrary.attach(_look_sprite, SpriteLibrary.frames_for_texture(key, texture, false))
			_play_look()
		else:
			texture.update(sheet)
		await get_tree().process_frame
		if _look_key != key or not is_inside_tree():
			return


func _play_look() -> void:
	if _look_sprite.sprite_frames == null:
		return
	var direction: String = SpriteLibrary.FOUR_DIRECTIONS[_look_direction]
	_look_sprite.play(SpriteLibrary.animation_name(_look_sprite.sprite_frames, LOOK_SEQUENCE[_look_step], direction))


func _sync_look_widgets() -> void:
	var profile := _profile()
	for category: String in CharacterPainter.PARTS:
		var option: OptionButton = _look_options[category]
		var choices: Array = profile.get(category, CharacterPainter.PARTS[category])
		option.clear()
		for value: Variant in choices:
			option.add_item(CharacterPainter.NAMES.get(value, str(value)))
			option.set_item_metadata(option.item_count - 1, value)
		_select_by_metadata(option, _look.get(category))
		_look_rows[category].visible = choices.size() > 1
	(_look_rows["horns"].get_child(0) as Label).text = "Crista" if profile.get("snout", false) else "Chifres"
	(_swatch_rows["skin"].get_child(0) as Label).text = "Escamas" if profile.get("snout", false) else "Pele"
	for key: String in SWATCH_LABELS:
		var box: HFlowContainer = _swatch_boxes[key]
		for child in box.get_children():
			box.remove_child(child)
			child.queue_free()
		var colors := _swatch_colors(key, profile)
		for i in colors.size():
			box.add_child(_make_swatch(Color(colors[i]), i == int(_look.get(key, 0)), key, i))
		_swatch_rows[key].visible = colors.size() > 1
	_swatch_rows["cloak_color"].visible = _look.get("cloak") == "cape"
	_swatch_rows["hair_color"].visible = _look.get("hair_style") != "bald" or _look.get("beard", "none") != "none"


func _make_swatch(color: Color, selected: bool, key: String, index: int) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(14, 14)
	button.tooltip_text = "#%s" % color.to_html(false)
	for state in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = color
		style.set_border_width_all(2 if selected or state == "hover" else 1)
		style.border_color = Color.WHITE if selected else (Color(0.8, 0.8, 0.8) if state == "hover" else Color(0.1, 0.08, 0.14))
		button.add_theme_stylebox_override(state, style)
	button.pressed.connect(set_look.bind(key, index))
	return button


func _sync_widgets() -> void:
	_sync_look_widgets()
	_select_by_metadata(_species_option, _species_id)
	_select_by_metadata(_class_option, _class_id)
	_select_by_metadata(_background_option, _background_id)
	for ability: StringName in Ability.ALL:
		_select_by_metadata(_score_options[ability], _scores.get(ability, 8))

	_bonus_mode_option.select(_bonus_mode)
	_plus_two_row.visible = _bonus_mode == 0
	_plus_one_row.visible = _bonus_mode == 0
	var options := _names(_background().get("ability_options", []))
	for option: OptionButton in [_plus_two_option, _plus_one_option]:
		option.clear()
		for ability in options:
			option.add_item(Ability.NAMES[ability])
			option.set_item_metadata(option.item_count - 1, ability)
	_select_by_metadata(_plus_two_option, _plus_two)
	_select_by_metadata(_plus_one_option, _plus_one)

	var background_skills := _names(_background().get("skill_proficiencies", []))
	_background_skills_label.text = "Do antecedente: %s" % ", ".join(
			background_skills.map(func(s: StringName) -> String: return Skill.NAMES[s]))

	var locked := {}
	for skill in background_skills:
		locked[skill] = "antecedente"
	_fill_checkboxes(_class_skills_box, "Da classe", _names(_class().get("skill_options", [])),
			_class_skills, int(_class().get("skill_choice_count", 0)), locked)

	var species_locked := locked.duplicate()
	for skill in _class_skills:
		species_locked[skill] = "classe"
	_fill_checkboxes(_species_skills_box, "Da espécie", CharacterFactory.species_skill_options(_species()),
			_species_skills, int(_species().get("extra_skill_choices", 0)), species_locked)

	_fill_checkboxes(_expertise_box, "Especialização (dobra a proficiência)",
			_names(background_skills + _class_skills + _species_skills), _expertise,
			int(_class().get("expertise_choices", 0)), {})
	_sync_spell_widgets()


## Truques e magias preparadas: remove o que não é da classe e, com fill, completa até o limite.
func _fix_spells(fill: bool) -> void:
	var limits := _spell_limits()
	for pair: Array in [[_cantrips, _spell_options(0, 0), int(limits["cantrips"])],
			[_prepared, _spell_options(1, 1), int(limits["prepared"])]]:
		var chosen: Array[String] = pair[0]
		var options: Array[String] = pair[1]
		for id in chosen.duplicate():
			if not id in options:
				chosen.erase(id)
		while chosen.size() > int(pair[2]):
			chosen.pop_back()
		if fill:
			for id in options:
				if chosen.size() >= int(pair[2]):
					break
				if not id in chosen:
					chosen.append(id)


func _spell_probe() -> CharacterData:
	var probe := CharacterData.new()
	probe.class_id = _class_id
	probe.level = 1
	return probe


func _spell_limits() -> Dictionary:
	return Spellcasting.limits(_spell_probe(), _registry)


## Opções de magia da classe; as sempre preparadas (ex.: Marca do Caçador) não entram na escolha.
func _spell_options(min_level: int, max_level: int) -> Array[String]:
	var always := Spellcasting.always_prepared_ids(_spell_probe(), _registry)
	var options: Array[String] = []
	for id in Spellcasting.class_spells(_class_id, _registry, min_level, max_level):
		if not id in always:
			options.append(id)
	return options


func _sync_spell_widgets() -> void:
	for child in _spells_box.get_children():
		_spells_box.remove_child(child)
		child.queue_free()
	var limits := _spell_limits()
	var caster := Spellcasting.is_caster(_class())
	_spells_section.visible = caster
	_spells_box.visible = caster
	if not caster:
		return
	_add_spell_group("Truques", _spell_options(0, 0), _cantrips, int(limits["cantrips"]))
	_add_spell_group("Magias preparadas (1º círculo)", _spell_options(1, 1), _prepared, int(limits["prepared"]))


func _add_spell_group(title: String, options: Array[String], chosen: Array[String], count: int) -> void:
	if count <= 0:
		return
	var label := Label.new()
	label.text = "%s: escolha %d (%d/%d)" % [title, count, chosen.size(), count]
	_spells_box.add_child(label)
	var grid := GridContainer.new()
	grid.columns = 2
	_spells_box.add_child(grid)
	for id in options:
		var entry := _registry.get_entry("spell", id)
		var check := CheckBox.new()
		check.text = entry["name"]
		check.tooltip_text = entry["description"]
		check.button_pressed = id in chosen
		check.disabled = not id in chosen and chosen.size() >= count
		check.toggled.connect(_on_spell_toggled.bind(chosen, id))
		grid.add_child(check)


func _on_choices_changed() -> void:
	if _character != null:
		_choices = _character.choices.duplicate(true)
	_queue_refresh()


func _on_spell_toggled(pressed: bool, chosen: Array[String], spell_id: String) -> void:
	if pressed and not spell_id in chosen:
		chosen.append(spell_id)
	elif not pressed:
		chosen.erase(spell_id)
	_queue_refresh()


func _fill_checkboxes(box: VBoxContainer, title: String, options: Array[StringName],
		chosen: Array[StringName], count: int, locked: Dictionary) -> void:
	for child in box.get_children():
		box.remove_child(child)
		child.queue_free()
	box.visible = count > 0
	if count <= 0:
		return
	var label := Label.new()
	label.text = "%s: escolha %d (%d/%d)" % [title, count, chosen.size(), count]
	box.add_child(label)
	var grid := GridContainer.new()
	grid.columns = 2
	box.add_child(grid)
	var sorted := options.duplicate()
	sorted.sort_custom(func(a: StringName, b: StringName) -> bool: return Skill.NAMES[a] < Skill.NAMES[b])
	for skill: StringName in sorted:
		var check := CheckBox.new()
		check.text = Skill.NAMES[skill]
		if locked.has(skill):
			check.text += " (%s)" % locked[skill]
		check.button_pressed = skill in chosen
		check.disabled = locked.has(skill) or (not skill in chosen and chosen.size() >= count)
		check.toggled.connect(_on_skill_toggled.bind(chosen, skill))
		grid.add_child(check)


func _select_by_metadata(option: OptionButton, value: Variant) -> void:
	for i in option.item_count:
		if option.get_item_metadata(i) == value:
			option.select(i)
			return


# --- Sinais -------------------------------------------------------------------

func _on_species_selected(index: int) -> void:
	_species_id = _species_option.get_item_metadata(index)
	_fix_choices(true)
	_queue_refresh()


func _on_look_selected(index: int, category: String) -> void:
	set_look(category, _look_options[category].get_item_metadata(index))


func _on_look_tick() -> void:
	_look_step += 1
	if _look_step >= LOOK_SEQUENCE.size():
		_look_step = 0
		_look_direction = (_look_direction + 1) % SpriteLibrary.FOUR_DIRECTIONS.size()
	_play_look()


func _on_class_selected(index: int) -> void:
	_class_id = _class_option.get_item_metadata(index)
	_cantrips.clear()
	_prepared.clear()
	_apply_class_defaults()
	_fix_choices(true)
	_queue_refresh()


func _on_background_selected(index: int) -> void:
	_background_id = _background_option.get_item_metadata(index)
	_fix_choices(true)
	_queue_refresh()


func _on_score_selected(index: int, ability: StringName) -> void:
	_scores[ability] = int(_score_options[ability].get_item_metadata(index))
	_queue_refresh()


func _on_bonus_mode_selected(index: int) -> void:
	_bonus_mode = index
	_queue_refresh()


func _on_plus_two_selected(index: int) -> void:
	_plus_two = _plus_two_option.get_item_metadata(index)
	_queue_refresh()


func _on_plus_one_selected(index: int) -> void:
	_plus_one = _plus_one_option.get_item_metadata(index)
	_queue_refresh()


func _on_skill_toggled(pressed: bool, chosen: Array[StringName], skill: StringName) -> void:
	if pressed and not skill in chosen:
		chosen.append(skill)
	elif not pressed:
		chosen.erase(skill)
	_fix_choices(false)
	_queue_refresh()


func _on_start_pressed() -> void:
	if _character == null:
		return
	PartyManager.start_new_party(_character)
	QuestManager.reset()
	ExplorationManager.reset()
	ExplorationManager.intro_message = INTRO_TEXT
	var err := get_tree().change_scene_to_file(START_SCENE)
	if err != OK:
		push_error("Falha ao carregar %s: %s" % [START_SCENE, error_string(err)])


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(TITLE_SCENE)
