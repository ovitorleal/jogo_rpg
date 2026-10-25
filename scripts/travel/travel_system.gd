class_name TravelSystem
extends RefCounted
## Viagem por uma rota dividida em trechos. Controla tempo, rações, descanso, o acontecimento
## de cada trecho (via EncounterDirector) e a chegada. Só lógica; estado serializável
## (to_dict/from_dict) para sobreviver à troca de cena durante um combate.
##
## Regras do projeto (ver docs/RULES_POLICY.md):
## - cada trecho consome 1 ração por membro do grupo; sem ração, o grupo segue faminto e não
##   pode acampar (descanso longo);
## - descanso curto: 1 hora, gasta um Dado de Vida do líder por vez;
## - acampar: 8 horas, consome 1 ração por membro, descanso longo completo;
## - perigos de eventos nunca derrubam a 0 PV (o personagem fica com no mínimo 1 PV).

const SHORT_REST_HOURS := 1
const LONG_REST_HOURS := 8
const RATIONS_PER_MEMBER := 1

var route_id: String = ""
var segments_done: int = 0
## Horas desde a meia-noite do primeiro dia.
var clock: int = 8
var seed_value: int = 0
var history: Array = []
var resolved_once: Dictionary = {}
## Acontecimento aguardando resolução: {"kind": "event"|"combat", "id": String} ou vazio.
var pending: Dictionary = {}
var hungry: bool = false
var log: Array = []
## Só para testes: substitui os roladores derivados da semente.
var roller_override: DiceRoller = null
var _rolls: int = 0


func start(route: Dictionary, seed_number: int) -> void:
	route_id = route["id"]
	segments_done = 0
	clock = int(route.get("start_hour", 8))
	seed_value = seed_number
	history.clear()
	pending.clear()
	hungry = false
	log = ["Partida pela %s." % route["name"]]
	_rolls = 0


func route(registry: ContentRegistry) -> Dictionary:
	return registry.get_entry("route", route_id)


func total_segments(registry: ContentRegistry) -> int:
	return int(route(registry).get("segments", 1))


func is_arrived(registry: ContentRegistry) -> bool:
	return segments_done >= total_segments(registry) and pending.is_empty()


func day() -> int:
	@warning_ignore("integer_division")
	return clock / 24 + 1


func hour() -> int:
	return posmod(clock, 24)


func time_label() -> String:
	var h := hour()
	var period := "madrugada" if h < 6 else ("manhã" if h < 12 else ("tarde" if h < 19 else "noite"))
	return "Dia %d, %02d:00 (%s)" % [day(), h, period]


## Percorre o próximo trecho. Retorna {"ok", "error", "kind", "id", "text"}.
## kind: "quiet", "event", "combat" ou "arrived".
func advance(party: Array[CharacterData], registry: ContentRegistry, inventory: Inventory) -> Dictionary:
	if not pending.is_empty():
		return _fail("Resolva o acontecimento atual antes de seguir")
	var r := route(registry)
	if segments_done >= int(r["segments"]):
		return _fail("A viagem já terminou")
	segments_done += 1
	clock += int(r["hours_per_segment"])
	var needed := RATIONS_PER_MEMBER * party.size()
	if inventory.remove(Inventory.RATIONS, needed):
		hungry = false
	else:
		hungry = true
		_log("Sem rações: o grupo segue com fome.")
	var leader_level := party[0].level if not party.is_empty() else 1
	var pick := EncounterDirector.choose(registry.get_entry("region", r["region_id"]), hour(), leader_level,
			party.size(), history, resolved_once, registry, _next_roller())
	# Acontecimento roteirizado da rota (uma vez por jogo): substitui o sorteio deste trecho.
	for scripted: Dictionary in r.get("scripted_events", []):
		if int(scripted["segment"]) == segments_done and not resolved_once.has(str(scripted["id"])):
			pick = {"kind": scripted["kind"], "id": scripted["id"]}
			resolved_once[str(scripted["id"])] = true
	var result := {"ok": true, "error": "", "kind": pick["kind"], "id": pick["id"], "text": ""}
	match pick["kind"]:
		"quiet":
			result["text"] = "Trecho %d de %d: a trilha segue tranquila." % [segments_done, int(r["segments"])]
			history.append("quiet")
		"event":
			pending = {"kind": "event", "id": pick["id"]}
			result["text"] = "Trecho %d de %d: %s." % [segments_done, int(r["segments"]),
					registry.get_entry("event", pick["id"])["name"]]
		"combat":
			pending = {"kind": "combat", "id": pick["id"]}
			result["text"] = "Trecho %d de %d: %s!" % [segments_done, int(r["segments"]),
					registry.get_entry("encounter", pick["id"])["name"]]
	_log(result["text"])
	if pick["kind"] == "quiet" and segments_done >= int(r["segments"]):
		result["kind"] = "arrived"
		_log("Você chega ao destino.")
	return result


## Resolve a escolha do evento pendente: teste de perícia (se houver) e efeitos.
## Retorna {"ok", "error", "success", "text", "check": D20Test ou null, "effects": Array[String]}.
func choose_option(choice_id: String, party: Array[CharacterData], registry: ContentRegistry,
		inventory: Inventory) -> Dictionary:
	if pending.get("kind") != "event":
		return _fail("Nenhum evento aguardando escolha")
	var event := registry.get_entry("event", pending["id"])
	var choice: Dictionary = {}
	for option: Dictionary in event["choices"]:
		if option["id"] == choice_id:
			choice = option
	if choice.is_empty():
		return _fail("Escolha desconhecida: '%s'" % choice_id)
	var leader := party[0]
	var roller := _next_roller()
	var check: D20Test = null
	var success := true
	if not str(choice.get("skill", "")).is_empty():
		var sheet := CharacterSheet.build(leader, registry)
		check = sheet.roll_skill_check(StringName(choice["skill"]), int(choice["dc"]), roller)
		success = check.success
		# Mente Tática (Guerreiro 2): soma 1d10 a um teste que falhou; gasta Retomar o Fôlego só se der certo.
		if not success and "feature.tactical_mind" in sheet.feature_ids and ClassFeatures.remaining(leader, registry, "second_wind") > 0:
			var bonus := roller.roll_die(10)
			if check.total + bonus >= check.dc:
				check.total += bonus
				check.modifier += bonus
				check.success = true
				success = true
				ClassFeatures.spend(leader, "second_wind")
				_log("Mente Tática: +%d no teste (Retomar o Fôlego gasto)." % bonus)
	var effects: Array[String] = []
	if success:
		_change_rations(inventory, int(choice.get("success_rations", 0)), effects)
		var xp := int(choice.get("success_xp", 0))
		if xp > 0:
			effects.append("+%d XP" % xp)
			for c in party:
				for up in Progression.award_xp(c, xp, registry):
					effects.append(Progression.describe(c, up))
		if not str(choice.get("success_heal", "")).is_empty():
			var healed := _heal(leader, registry, DiceExpression.parse(choice["success_heal"]).roll(roller))
			effects.append("+%d PV" % healed)
	else:
		_change_rations(inventory, int(choice.get("failure_rations", 0)), effects)
		if not str(choice.get("failure_damage", "")).is_empty():
			var raw := DiceExpression.parse(choice["failure_damage"]).roll(roller)
			var species := registry.get_entry("species", leader.species_id)
			var damage := Attack.apply_damage_modifiers(raw, str(choice.get("failure_damage_type", "bludgeoning")),
					species.get("damage_resistances", []))
			var before := leader.current_hp
			leader.current_hp = maxi(1, leader.current_hp - damage)
			effects.append("-%d PV" % (before - leader.current_hp))
	var text: String = choice["success_text"] if success else choice["failure_text"]
	_finish_pending(event.get("id"), bool(_row_once(registry, event["id"])))
	_log(text)
	return {"ok": true, "error": "", "success": success, "text": text, "check": check, "effects": effects}


## Registra o fim do combate pendente (vitória ou fuga; derrota encerra o jogo antes).
func resolve_combat(outcome: int) -> String:
	if pending.get("kind") != "combat":
		return ""
	var text := "O combate terminou."
	match outcome:
		CombatManager.Outcome.VICTORY:
			text = "Vitória! A viagem continua."
		CombatManager.Outcome.FLED:
			text = "Você escapou e retomou a trilha."
	_finish_pending(pending["id"], false)
	_log(text)
	return text


func short_rest(party: Array[CharacterData], registry: ContentRegistry) -> Dictionary:
	if not pending.is_empty():
		return _fail("Não é possível descansar agora")
	var result := Rest.spend_hit_die(party[0], registry, _next_roller())
	var slots := 0
	var features: Array[String] = []
	for c in party:
		slots += Spellcasting.short_rest(c, registry)
		features.append_array(ClassFeatures.short_rest(c, registry))
	if result["ok"] or slots > 0 or not features.is_empty():
		clock += SHORT_REST_HOURS
		var healed := int(result.get("healed", 0))
		_log("Descanso curto: %s recupera %d PV%s%s." % [party[0].name, healed,
				" e %d espaço(s) de magia" % slots if slots > 0 else "",
				"; recarrega %s" % ", ".join(features) if not features.is_empty() else ""])
		return {"ok": true, "error": "", "healed": healed, "slots": slots}
	return result


func long_rest(party: Array[CharacterData], registry: ContentRegistry, inventory: Inventory) -> Dictionary:
	if not pending.is_empty():
		return _fail("Não é possível acampar agora")
	var needed := RATIONS_PER_MEMBER * party.size()
	if not inventory.remove(Inventory.RATIONS, needed):
		return _fail("Sem rações para acampar")
	var healed := 0
	for c in party:
		healed += Rest.long_rest(c, registry)
	clock += LONG_REST_HOURS
	hungry = false
	_log("Acampamento: o grupo descansa 8 horas e recupera %d PV." % healed)
	return {"ok": true, "error": "", "healed": healed}


func to_dict() -> Dictionary:
	return {"route_id": route_id, "segments_done": segments_done, "clock": clock, "seed": seed_value,
			"history": history.duplicate(), "resolved_once": resolved_once.keys(), "pending": pending.duplicate(),
			"hungry": hungry, "log": log.duplicate(), "rolls": _rolls}


static func from_dict(data: Dictionary) -> TravelSystem:
	var travel := TravelSystem.new()
	travel.route_id = str(data.get("route_id", ""))
	travel.segments_done = int(data.get("segments_done", 0))
	travel.clock = int(data.get("clock", 8))
	travel.seed_value = int(data.get("seed", 0))
	travel.history = Array(data.get("history", []))
	for key: Variant in data.get("resolved_once", []):
		travel.resolved_once[str(key)] = true
	travel.pending = Dictionary(data.get("pending", {}))
	travel.hungry = bool(data.get("hungry", false))
	travel.log = Array(data.get("log", []))
	travel._rolls = int(data.get("rolls", 0))
	return travel


# --- Auxiliares ---------------------------------------------------------------

## Cada sorteio usa um rolador derivado da semente e de um contador: reproduzível e serializável.
func _next_roller() -> DiceRoller:
	_rolls += 1
	if roller_override != null:
		return roller_override
	return DiceRoller.new(absi(hash([seed_value, _rolls])))


func _finish_pending(id: String, once: bool) -> void:
	history.append(id)
	if once:
		resolved_once[id] = true
	pending.clear()


func _row_once(registry: ContentRegistry, id: String) -> bool:
	var region := registry.get_entry("region", route(registry).get("region_id", ""))
	for row: Dictionary in region.get("table", []):
		if row["id"] == id:
			return row.get("once", false)
	return false


func _heal(c: CharacterData, registry: ContentRegistry, amount: int) -> int:
	var before := c.current_hp
	c.current_hp = mini(CharacterSheet.build(c, registry).max_hp, c.current_hp + maxi(0, amount))
	return c.current_hp - before


func _change_rations(inventory: Inventory, amount: int, effects: Array[String]) -> void:
	if amount == 0:
		return
	var before := inventory.count(Inventory.RATIONS)
	if amount > 0:
		inventory.add(Inventory.RATIONS, amount)
	else:
		inventory.remove(Inventory.RATIONS, mini(before, -amount))
	var delta := inventory.count(Inventory.RATIONS) - before
	effects.append("%s %s" % [Ability.format_modifier(delta), "ração" if absi(delta) == 1 else "rações"])


func _log(text: String) -> void:
	log.append(text)


func _fail(message: String) -> Dictionary:
	return {"ok": false, "error": message}
