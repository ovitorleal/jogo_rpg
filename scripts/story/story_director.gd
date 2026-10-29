class_name StoryDirector
extends RefCounted
## Cenas de história (data/story/) e crônicas do mundo (data/lore/). Uma cena dispara num momento
## ("arrive" ao chegar num mapa, "rest" depois de um descanso longo) quando a condição é verdadeira, uma única vez;
## os companheiros presentes no grupo comentam. As crônicas aparecem no diário quando a condição de desbloqueio
## é verdadeira. Condições usam a mesma sintaxe dos diálogos (DialogueRunner.check). Só lógica: quem mostra é o mapa.

const TRIGGERS := ["arrive", "rest"]


## Cenas pendentes para o momento: condição verdadeira, ainda não vistas e (se tiver mapa) neste mapa.
static func pending_beats(trigger: String, map_id: String, conditions: DialogueRunner, registry: ContentRegistry,
		seen: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for id in registry.ids("story"):
		var beat := registry.get_entry("story", id)
		if beat["trigger"] != trigger or seen.has(id):
			continue
		var beat_map := str(beat.get("map_id", ""))
		if not beat_map.is_empty() and beat_map != map_id:
			continue
		if conditions.check(str(beat.get("condition", ""))):
			result.append(beat)
	return result


## Falas dos companheiros que estão no grupo ("Nome: fala"), na ordem dos dados.
static func remarks_for(beat: Dictionary, party: Array[CharacterData]) -> Array[String]:
	var lines: Array[String] = []
	var present := {}
	for c in party:
		present[CompanionRoster.companion_id_of(c)] = c
	for remark: Dictionary in beat.get("remarks", []):
		var c: CharacterData = present.get(remark["companion"])
		if c != null:
			lines.append("%s: \"%s\"" % [c.name.get_slice(" ", 0), remark["text"]])
	return lines


## Texto completo de uma cena: narração e, abaixo, os comentários do grupo.
static func beat_text(beat: Dictionary, party: Array[CharacterData]) -> String:
	var remarks := remarks_for(beat, party)
	if remarks.is_empty():
		return str(beat["text"])
	return "%s\n\n%s" % [beat["text"], "\n".join(remarks)]


## Crônicas desbloqueadas, na ordem de leitura.
static func unlocked_lore(conditions: DialogueRunner, registry: ContentRegistry) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for id in registry.ids("lore"):
		var entry := registry.get_entry("lore", id)
		if conditions.check(str(entry.get("unlock", ""))):
			result.append(entry)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["order"]) < int(b["order"]))
	return result
