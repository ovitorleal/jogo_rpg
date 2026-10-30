extends Node
## Autoload "PartyManager": guarda o grupo do jogador entre cenas.
## O grupo ativo é o protagonista mais até dois companheiros; os recrutados fora do grupo
## esperam na estalagem (roster).

signal party_changed

var members: Array[CharacterData] = []
## Itens e ouro do grupo (rações, poções, equipamento guardado).
var inventory: Inventory = Inventory.starting_inventory()
## Companheiros recrutados e quem espera na estalagem.
var roster := CompanionRoster.new()
## Nível já anunciado de cada personagem (id -> nível). Subidas acima disso viram aviso no mapa.
var seen_levels: Dictionary = {}


func start_new_party(leader: CharacterData) -> void:
	members = [leader]
	inventory = Inventory.starting_inventory()
	roster = CompanionRoster.new()
	mark_levels_seen()
	party_changed.emit()


## Grupo e inventário vindos de um salvamento já validado.
func restore(saved_members: Array[CharacterData], saved_inventory: Inventory,
		saved_roster: CompanionRoster = null) -> void:
	members = saved_members.duplicate()
	inventory = saved_inventory
	roster = saved_roster if saved_roster != null else CompanionRoster.new()
	mark_levels_seen()
	party_changed.emit()


## Considera anunciados os níveis atuais de todo o grupo e de quem espera na estalagem.
func mark_levels_seen() -> void:
	seen_levels.clear()
	take_level_ups()


## Membros do grupo que subiram de nível desde o último aviso (e registra os níveis atuais).
## Personagens novos (recém-recrutados) são registrados sem aviso.
func take_level_ups() -> Array[CharacterData]:
	var result: Array[CharacterData] = []
	for c in members:
		if c.level > int(seen_levels.get(c.id, c.level)):
			result.append(c)
		seen_levels[c.id] = c.level
	for c in roster.bench:
		seen_levels[c.id] = c.level
	return result


func get_leader() -> CharacterData:
	return members[0] if not members.is_empty() else null


func has_party() -> bool:
	return not members.is_empty()


func clear() -> void:
	members.clear()
	inventory = Inventory.starting_inventory()
	roster = CompanionRoster.new()
	seen_levels.clear()
	party_changed.emit()
