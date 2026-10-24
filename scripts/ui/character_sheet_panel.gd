class_name CharacterSheetPanel
extends PanelContainer
## Exibe uma CharacterSheet (ou uma lista de erros). Só apresentação: os valores
## já vêm calculados pelo motor de regras.

const PROFICIENT_MARK := "(P)"
const EXPERTISE_MARK := "(E)"
const DISTANCE_UNIT := "pés"

@onready var _text: RichTextLabel = %SheetText


func show_sheet(sheet: CharacterSheet) -> void:
	_text.text = format_sheet(sheet)
	_text.scroll_to_line(0)


func show_errors(title: String, errors: Array[String]) -> void:
	var lines := PackedStringArray(["[b]%s[/b]" % _escape(title), ""])
	for problem in errors:
		lines.append("- %s" % _escape(problem))
	_text.text = "\n".join(lines)


func get_plain_text() -> String:
	return _text.get_parsed_text()


static func format_sheet(sheet: CharacterSheet) -> String:
	var c := sheet.character
	var out := PackedStringArray()
	out.append("[b]%s[/b]" % _escape(c.name))
	out.append("%s · %s nível %d · %s" % [sheet.species.get("name", "?"), sheet.class_entry.get("name", "?"),
			c.level, sheet.background.get("name", "?")])
	out.append("")

	out.append("[table=6]")
	for header in ["CA", "PV", "Iniciativa", "Desloc.", "Prof.", "Perc. passiva"]:
		out.append("[cell][color=#8597b8]%s[/color]  [/cell]" % header)
	for value in [str(sheet.armor_class), "%d/%d" % [c.current_hp, sheet.max_hp],
			Ability.format_modifier(sheet.initiative), "%d %s" % [sheet.speed, DISTANCE_UNIT],
			Ability.format_modifier(sheet.proficiency_bonus), str(sheet.passive_perception)]:
		out.append("[cell]%s  [/cell]" % value)
	out.append("[/table]")
	out.append("")

	out.append("[b]Atributos[/b]  [color=#8597b8](valor, modificador, resistência)[/color]")
	out.append("[table=3]")
	for ability: StringName in Ability.ALL:
		var save: Dictionary = sheet.saving_throws[ability]
		out.append("[cell]%s %d (%s), res. %s%s    [/cell]" % [Ability.SHORT_NAMES[ability], sheet.scores[ability],
				Ability.format_modifier(sheet.modifiers[ability]), Ability.format_modifier(save["bonus"]),
				" " + PROFICIENT_MARK if save["proficient"] else ""])
	out.append("[/table]")
	out.append("")

	out.append("[b]Perícias[/b]  [color=#8597b8]%s proficiente · %s especialização[/color]" % [PROFICIENT_MARK, EXPERTISE_MARK])
	out.append("[table=3]")
	var names: Array[StringName] = Skill.all()
	names.sort_custom(func(a: StringName, b: StringName) -> bool: return Skill.NAMES[a] < Skill.NAMES[b])
	for skill in names:
		var entry: Dictionary = sheet.skills[skill]
		var mark := EXPERTISE_MARK if entry["expertise"] else (PROFICIENT_MARK if entry["proficient"] else "")
		var label := "%s %s %s" % [Skill.NAMES[skill], Ability.format_modifier(entry["bonus"]), mark]
		if entry["proficient"]:
			label = "[b]%s[/b]" % label
		out.append("[cell]%s   [/cell]" % label.strip_edges())
	out.append("[/table]")
	out.append("")

	out.append("[b]Equipamento[/b]")
	if sheet.armor.is_empty():
		out.append("Sem armadura")
	else:
		out.append("%s (CA %d%s)%s" % [sheet.armor["name"], sheet.armor["base_ac"], _dex_note(sheet.armor),
				" · desvantagem em Furtividade" if sheet.stealth_disadvantage else ""])
	if not sheet.shield.is_empty():
		out.append("%s (+%d CA)" % [sheet.shield["name"], sheet.shield["ac_bonus"]])
	for weapon in sheet.weapons:
		out.append("%s (%s %s)" % [weapon.get("name", "?"), weapon.get("damage", "?"), _damage_type_name(weapon.get("damage_type", ""))])
	out.append("")

	out.append("[b]Características[/b]")
	for feature in sheet.features:
		out.append("- %s%s" % [feature["name"], "" if feature["implemented"] else " [color=#8597b8](ainda não implementada)[/color]"])
	return "\n".join(out)


static func _dex_note(armor: Dictionary) -> String:
	if armor.get("armor_category") == "heavy":
		return ""
	if int(armor.get("dex_cap", -1)) >= 0:
		return " + Des, máx. %d" % armor["dex_cap"]
	return " + Des"


static func _damage_type_name(damage_type: String) -> String:
	const NAMES := {"piercing": "perfurante", "slashing": "cortante", "bludgeoning": "contundente"}
	return NAMES.get(damage_type, damage_type)


## Impede que textos vindos do jogador (ex.: nome) sejam interpretados como BBCode.
static func _escape(text: String) -> String:
	return text.replace("[", "[lb]")
