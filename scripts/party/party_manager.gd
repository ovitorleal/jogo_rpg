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


func start_new_party(leader: CharacterData) -> void:
	members = [leader]
	inventory = Inventory.starting_inventory()
	roster = CompanionRoster.new()
	party_changed.emit()


## Grupo e inventário vindos de um salvamento já validado.
func restore(saved_members: Array[CharacterData], saved_inventory: Inventory,
		saved_roster: CompanionRoster = null) -> void:
	members = saved_members.duplicate()
	inventory = saved_inventory
	roster = saved_roster if saved_roster != null else CompanionRoster.new()
	party_changed.emit()


func get_leader() -> CharacterData:
	return members[0] if not members.is_empty() else null


func has_party() -> bool:
	return not members.is_empty()


func clear() -> void:
	members.clear()
	inventory = Inventory.starting_inventory()
	roster = CompanionRoster.new()
	party_changed.emit()
