extends Node
## Autoload "ExplorationManager": estado da exploração que precisa sobreviver às trocas de
## cena — onde voltar depois de um combate, encontros já resolvidos e o último resultado.
## Serializável (to_dict/from_dict) para o salvamento da Fase 6.

const COMBAT_SCENE := "res://scenes/combat/combat_scene.tscn"
const TITLE_SCENE := "res://scenes/menus/title_screen.tscn"

## Gatilhos de encontro já vencidos: {trigger_id: true}.
var resolved_triggers: Dictionary = {}
var pending_encounter_id: String = ""
var pending_trigger_id: String = ""
## Gatilho que não deve disparar até o jogador sair dele (após uma fuga).
var disarmed_trigger_id: String = ""
var return_scene: String = ""
var return_position := Vector2.ZERO
var has_return_position: bool = false
var last_outcome: int = CombatManager.Outcome.NONE
var last_xp: int = 0
## Desligado nos testes para registrar o estado sem trocar de cena.
var scene_changes_enabled: bool = true


func begin_encounter(encounter_id: String, trigger_id: String, scene_path: String, position: Vector2) -> Error:
	pending_encounter_id = encounter_id
	pending_trigger_id = trigger_id
	return_scene = scene_path
	return_position = position
	has_return_position = true
	last_outcome = CombatManager.Outcome.NONE
	if not scene_changes_enabled:
		return OK
	return get_tree().change_scene_to_file(COMBAT_SCENE)


## Registra o resultado e decide para onde ir: vitória/fuga voltam ao mapa; derrota vai ao título.
## Retorna a cena de destino (não troca de cena se change_scene = false; útil em testes).
func finish_encounter(outcome: int, xp: int, change_scene: bool = true) -> String:
	last_outcome = outcome
	last_xp = xp
	match outcome:
		CombatManager.Outcome.VICTORY:
			if not pending_trigger_id.is_empty():
				resolved_triggers[pending_trigger_id] = true
		CombatManager.Outcome.FLED:
			disarmed_trigger_id = pending_trigger_id
	pending_encounter_id = ""
	pending_trigger_id = ""
	var destination := return_scene
	if outcome == CombatManager.Outcome.DEFEAT or destination.is_empty():
		destination = TITLE_SCENE
		reset()
		PartyManager.clear()
		last_outcome = outcome
	if change_scene and scene_changes_enabled:
		get_tree().change_scene_to_file(destination)
	return destination


## Posição de retorno para este mapa, consumida uma única vez.
func take_return_position(scene_path: String) -> Variant:
	if has_return_position and scene_path == return_scene:
		has_return_position = false
		return return_position
	return null


## Mensagem a mostrar ao voltar ao mapa, consumida uma única vez.
func take_return_message() -> String:
	var message := ""
	match last_outcome:
		CombatManager.Outcome.VICTORY:
			message = "Vitória! Você ganhou %d XP." % last_xp
		CombatManager.Outcome.FLED:
			message = "Você conseguiu fugir."
	last_outcome = CombatManager.Outcome.NONE
	return message


func is_resolved(trigger_id: String) -> bool:
	return resolved_triggers.has(trigger_id)


func reset() -> void:
	resolved_triggers.clear()
	pending_encounter_id = ""
	pending_trigger_id = ""
	disarmed_trigger_id = ""
	return_scene = ""
	has_return_position = false
	last_outcome = CombatManager.Outcome.NONE
	last_xp = 0


func to_dict() -> Dictionary:
	return {"resolved_triggers": resolved_triggers.keys()}
