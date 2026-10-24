extends Node
## Autoload "PartyManager": guarda o grupo do jogador entre cenas.
## No MVP o grupo tem só o protagonista; companheiros virão com o recrutamento.

signal party_changed

var members: Array[CharacterData] = []
## Itens e ouro do grupo (rações, poções, equipamento guardado).
var inventory: Inventory = Inventory.starting_inventory()


func start_new_party(leader: CharacterData) -> void:
	members = [leader]
	inventory = Inventory.starting_inventory()
	party_changed.emit()


## Grupo e inventário vindos de um salvamento já validado.
func restore(saved_members: Array[CharacterData], saved_inventory: Inventory) -> void:
	members = saved_members.duplicate()
	inventory = saved_inventory
	party_changed.emit()


func get_leader() -> CharacterData:
	return members[0] if not members.is_empty() else null


func has_party() -> bool:
	return not members.is_empty()


func clear() -> void:
	members.clear()
	inventory = Inventory.starting_inventory()
	party_changed.emit()
