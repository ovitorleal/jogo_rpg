class_name JournalPanel
extends PanelContainer
## Diário de missões (apresentação): ativas com objetivos ([x] cumprido, [ ] pendente) e concluídas.

var _text: RichTextLabel


func _ready() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.067, 0.086, 0.110, 0.97)
	style.border_color = Color(0.851, 0.659, 0.302)
	style.set_border_width_all(1)
	style.set_corner_radius_all(2)
	add_theme_stylebox_override("panel", style)
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 10)
	add_child(margin)
	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.add_theme_font_size_override("normal_font_size", 10)
	_text.add_theme_font_size_override("bold_font_size", 10)
	_text.add_theme_color_override("default_color", Color(0.902, 0.882, 0.827))
	margin.add_child(_text)


func show_journal(quests: QuestLog, registry: ContentRegistry) -> void:
	_text.text = format(quests, registry)


func get_plain_text() -> String:
	return _text.get_parsed_text()


static func format(quests: QuestLog, registry: ContentRegistry) -> String:
	var lines := PackedStringArray(["[b]Diário de missões[/b]", ""])
	var active := quests.active_ids()
	if active.is_empty():
		lines.append("[color=#8597b8]Nenhuma missão ativa. Converse com as pessoas da região.[/color]")
	for quest_id in active:
		var quest := registry.get_entry("quest", quest_id)
		var ready := quests.is_ready(quest_id, registry)
		lines.append("[b]%s[/b]%s" % [quest["name"], "  [color=#e0b48a](pronta para entregar)[/color]" if ready else ""])
		lines.append("[color=#8597b8]%s[/color]" % quest["description"])
		for objective: Dictionary in quest["objectives"]:
			var done := quests.is_objective_done(quest_id, objective["id"])
			lines.append("  %s %s" % ["[lb]x]" if done else "[lb] ]", objective["text"]])
		if ready:
			lines.append("  [lb] ] Voltar a %s" % quest["giver"])
		lines.append("")
	var completed := quests.completed_ids()
	if not completed.is_empty():
		lines.append("[b]Concluídas[/b]")
		for quest_id in completed:
			lines.append("  [lb]x] %s" % registry.get_entry("quest", quest_id)["name"])
	return "\n".join(lines)
