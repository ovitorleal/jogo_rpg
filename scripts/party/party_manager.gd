extends Node
## Autoload "PartyManager": guarda o grupo do jogador entre cenas.
## No MVP o grupo tem só o protagonista; companheiros virão com o recrutamento.

signal party_changed

var members: Array[CharacterData] = []


func start_new_party(leader: CharacterData) -> void:
	members = [leader]
	party_changed.emit()


func get_leader() -> CharacterData:
	return members[0] if not members.is_empty() else null


func has_party() -> bool:
	return not members.is_empty()


func clear() -> void:
	members.clear()
	party_changed.emit()
