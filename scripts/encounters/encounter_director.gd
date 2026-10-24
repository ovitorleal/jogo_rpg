class_name EncounterDirector
extends RefCounted
## Escolhe o que acontece num trecho de viagem a partir da tabela da região.
## Considera: horário (dia/noite), orçamento de XP do grupo (exclui combates fortes demais),
## eventos únicos já resolvidos e o histórico recente (não repete o último acontecimento).
## Sorteio por peso com o DiceRoller recebido (reproduzível com semente).

## Orçamento de XP por personagem por nível (heurística do projeto, ver RULES_POLICY.md).
const XP_BUDGET_PER_LEVEL := 100
const NIGHT_START := 19
const NIGHT_END := 6


static func is_night(hour: int) -> bool:
	var h := posmod(hour, 24)
	return h >= NIGHT_START or h < NIGHT_END


static func xp_budget(party_level: int, party_size: int) -> int:
	return XP_BUDGET_PER_LEVEL * maxi(1, party_level) * maxi(1, party_size)


static func encounter_xp(encounter: Dictionary, registry: ContentRegistry) -> int:
	var total := 0
	for group: Dictionary in encounter.get("enemies", []):
		total += int(registry.get_entry("monster", group["monster_id"]).get("xp", 0)) * int(group["count"])
	return total


## Linhas da tabela que podem acontecer agora, com o peso de cada uma.
static func candidates(region: Dictionary, hour: int, party_level: int, party_size: int,
		history: Array, resolved_once: Dictionary, registry: ContentRegistry) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var night := is_night(hour)
	var last: String = history[-1] if not history.is_empty() else ""
	var budget := xp_budget(party_level, party_size)
	for row: Dictionary in region.get("table", []):
		var time: String = row.get("time", "any")
		if (time == "day" and night) or (time == "night" and not night):
			continue
		if row.get("once", false) and resolved_once.has(row["id"]):
			continue
		if row["id"] == last:
			continue
		if row["kind"] == "combat" and encounter_xp(registry.get_entry("encounter", row["id"]), registry) > budget:
			continue
		result.append(row)
	return result


## Retorna {"kind": "quiet" | "combat" | "event", "id": String}.
static func choose(region: Dictionary, hour: int, party_level: int, party_size: int, history: Array,
		resolved_once: Dictionary, registry: ContentRegistry, roller: DiceRoller) -> Dictionary:
	var rows := candidates(region, hour, party_level, party_size, history, resolved_once, registry)
	var total := int(region.get("quiet_weight", 0))
	for row in rows:
		total += int(row["weight"])
	if total <= 0:
		return {"kind": "quiet", "id": ""}
	var roll := roller.roll_die(total)
	var acc := int(region.get("quiet_weight", 0))
	if roll <= acc:
		return {"kind": "quiet", "id": ""}
	for row in rows:
		acc += int(row["weight"])
		if roll <= acc:
			return {"kind": row["kind"], "id": row["id"]}
	return {"kind": "quiet", "id": ""}
