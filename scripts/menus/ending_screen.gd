class_name EndingScreen
extends Control
## Conclusão da aventura (fim da missão final): resumo do herói e das missões, e opções de continuar
## explorando a vila ou voltar ao título. O jogo já foi salvo com a missão concluída.

const VILLAGE_SCENE := "res://scenes/world/village.tscn"
const TITLE_SCENE := "res://scenes/menus/title_screen.tscn"

var _summary: RichTextLabel


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = Color(0.067, 0.086, 0.110)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(360, 0)
	column.add_theme_constant_override("separation", 6)
	center.add_child(column)
	var title := Label.new()
	title.text = "Ribeira está salva!"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.52))
	column.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "Fim da aventura de demonstração"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 9)
	column.add_child(subtitle)
	_summary = RichTextLabel.new()
	_summary.bbcode_enabled = true
	_summary.fit_content = true
	_summary.scroll_active = false
	_summary.add_theme_font_size_override("normal_font_size", 8)
	_summary.add_theme_font_size_override("bold_font_size", 8)
	_summary.text = summary_text()
	column.add_child(_summary)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 8)
	column.add_child(buttons)
	var keep := Button.new()
	keep.add_theme_font_size_override("font_size", 10)
	keep.name = "ContinueButton"
	keep.text = "Continuar explorando"
	keep.pressed.connect(continue_exploring)
	buttons.add_child(keep)
	var title_button := Button.new()
	title_button.add_theme_font_size_override("font_size", 10)
	title_button.name = "TitleButton"
	title_button.text = "Voltar ao título"
	title_button.pressed.connect(back_to_title)
	buttons.add_child(title_button)
	keep.grab_focus.call_deferred()


## Resumo: história, herói (classe, nível, XP, ouro), recompensas e missões concluídas.
static func summary_text() -> String:
	var lines := PackedStringArray()
	lines.append("Garra-Rubra foi derrotado e as carroças voltam a cruzar a Floresta Sussurrante em paz. "
			+ "Na praça de Ribeira, a festa vai até o amanhecer.")
	lines.append("")
	var leader: CharacterData = PartyManager.get_leader()
	if leader != null:
		var registry := Content.registry
		lines.append("[b]%s[/b] — %s %s, nível %d (%d XP) · %d PO" % [leader.name,
				registry.get_entry("species", leader.species_id).get("name", "?"),
				registry.get_entry("class", leader.class_id).get("name", "?"), leader.level, leader.experience,
				PartyManager.inventory.gold])
	if not ExplorationManager.ending_lines.is_empty():
		lines.append("Recompensa: %s" % " · ".join(ExplorationManager.ending_lines))
	var done := PackedStringArray()
	for quest_id in QuestManager.log.completed_ids():
		done.append(Content.registry.get_entry("quest", quest_id).get("name", quest_id))
	if not done.is_empty():
		lines.append("Missões concluídas: %s" % ", ".join(done))
	lines.append("")
	lines.append("O jogo foi salvo. Você pode continuar explorando a vila e a floresta.")
	return "\n".join(lines)


func continue_exploring() -> void:
	get_tree().change_scene_to_file(VILLAGE_SCENE)


func back_to_title() -> void:
	get_tree().change_scene_to_file(TITLE_SCENE)
