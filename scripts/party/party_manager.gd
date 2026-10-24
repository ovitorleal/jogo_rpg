extends Node
## Autoload "PartyManager": guarda o grupo do jogador entre cenas.
## No MVP o grupo tem só o protagonista; companheiros virão com o recrutamento.

signal party_changed

## Rações com que um grupo novo começa.
const STARTING_RATIONS := 6

var members: Array[CharacterData] = []
## Suprimentos do grupo (o inventário completo vem na Fase 5).
var supplies: Dictionary = {"rations": STARTING_RATIONS}


func start_new_party(leader: CharacterData) -> void:
	members = [leader]
	supplies = {"rations": STARTING_RATIONS}
	party_changed.emit()


func get_leader() -> CharacterData:
	return members[0] if not members.is_empty() else null


func has_party() -> bool:
	return not members.is_empty()


func clear() -> void:
	members.clear()
	supplies = {"rations": STARTING_RATIONS}
	party_changed.emit()
