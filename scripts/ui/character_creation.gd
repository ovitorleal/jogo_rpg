extends Control
## Criação de personagem (nível 1): formulário à esquerda, ficha ao vivo à direita.
## A validação é sempre a do CharacterFactory; esta tela só coleta escolhas.

const TITLE_SCENE := "res://scenes/menus/title_screen.tscn"
const START_SCENE := "res://scenes/world/test_map.tscn"
const DEFAULT_NAME := "Viajante"
const LABEL_WIDTH := 92.0

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
var _character: CharacterData = null
var _refresh_queued := false

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
	}


## Personagem válido atual, ou null se as escolhas tiverem erros.
func get_character() -> CharacterData:
	return _character


func set_character_name(text: String) -> void:
	_name_edit.text = text
	_refresh()


func select_class(class_id: String) -> void:
	_select_by_metadata(_class_option, class_id)
	_on_class_selected(_class_option.selected)


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


func _make_content_option(type_name: String) -> OptionButton:
	var option := OptionButton.new()
	for id in _registry.ids(type_name):
		option.add_item(_registry.get_entry(type_name, id)["name"])
		option.set_item_metadata(option.item_count - 1, id)
	return option


func _add_section(title: String) -> void:
	var label := Label.new()
	label.text = title
	label.add_theme_color_override("font_color", Color(0.522, 0.592, 0.722))
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


func _sync_widgets() -> void:
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


func _on_class_selected(index: int) -> void:
	_class_id = _class_option.get_item_metadata(index)
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
	var err := get_tree().change_scene_to_file(START_SCENE)
	if err != OK:
		push_error("Falha ao carregar %s: %s" % [START_SCENE, error_string(err)])


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(TITLE_SCENE)
