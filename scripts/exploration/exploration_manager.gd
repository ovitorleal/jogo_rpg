extends Node
## Autoload "ExplorationManager": estado da exploração que precisa sobreviver às trocas de
## cena — onde voltar depois de um combate, encontros já resolvidos e o último resultado.
## Serializável (to_dict/from_dict) para o salvamento da Fase 6.

const COMBAT_SCENE := "res://scenes/combat/combat_scene.tscn"
const TITLE_SCENE := "res://scenes/menus/title_screen.tscn"
const TRAVEL_SCENE := "res://scenes/travel/travel_scene.tscn"

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
## Viagem em andamento (TravelSystem.to_dict()); vazio fora de viagem.
var travel_state: Dictionary = {}
## Entrada (Marker2D) onde o jogador deve aparecer no próximo mapa carregado.
var pending_entrance: String = ""
var pending_map_scene: String = ""


func begin_encounter(encounter_id: String, trigger_id: String, scene_path: String, position: Vector2,
		remember_position: bool = true) -> Error:
	pending_encounter_id = encounter_id
	pending_trigger_id = trigger_id
	return_scene = scene_path
	return_position = position
	has_return_position = remember_position
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
	if is_traveling():
		return ""
	var message := ""
	match last_outcome:
		CombatManager.Outcome.VICTORY:
			message = "Vitória! Você ganhou %d XP." % last_xp
		CombatManager.Outcome.FLED:
			message = "Você conseguiu fugir."
	last_outcome = CombatManager.Outcome.NONE
	return message


## Inicia uma viagem pela rota e vai para a tela de viagem.
func begin_travel(route_id: String, seed_number: int = -1) -> Error:
	var route := Content.registry.get_entry("route", route_id)
	if route.is_empty():
		push_error("Rota desconhecida: %s" % route_id)
		return ERR_DOES_NOT_EXIST
	var travel := TravelSystem.new()
	travel.start(route, seed_number if seed_number >= 0 else randi())
	travel_state = travel.to_dict()
	if not scene_changes_enabled:
		return OK
	return get_tree().change_scene_to_file(TRAVEL_SCENE)


func is_traveling() -> bool:
	return not travel_state.is_empty()


func current_travel() -> TravelSystem:
	return TravelSystem.from_dict(travel_state) if is_traveling() else null


func store_travel(travel: TravelSystem) -> void:
	travel_state = travel.to_dict()


## Combate surgido na viagem: ao terminar, volta para a tela de viagem.
func begin_travel_encounter(encounter_id: String) -> Error:
	return begin_encounter(encounter_id, "", TRAVEL_SCENE, Vector2.ZERO, false)


## Resultado do combate da viagem, consumido uma única vez.
func take_combat_outcome() -> int:
	var outcome := last_outcome
	last_outcome = CombatManager.Outcome.NONE
	return outcome


## Termina a viagem e vai ao mapa de destino, na entrada definida pela rota.
func finish_travel() -> String:
	var travel := current_travel()
	if travel == null:
		return ""
	var route := travel.route(Content.registry)
	var map := Content.registry.get_entry("map", route["to_map"])
	pending_map_scene = map["scene"]
	pending_entrance = route["to_entrance"]
	travel_state = {}
	if scene_changes_enabled:
		get_tree().change_scene_to_file(pending_map_scene)
	return pending_map_scene


## Nome da entrada onde o jogador deve aparecer neste mapa, consumido uma única vez.
func take_entrance(scene_path: String) -> String:
	if pending_entrance.is_empty() or scene_path != pending_map_scene:
		return ""
	var entrance := pending_entrance
	pending_entrance = ""
	pending_map_scene = ""
	return entrance


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
	travel_state = {}
	pending_entrance = ""
	pending_map_scene = ""


func to_dict() -> Dictionary:
	return {"resolved_triggers": resolved_triggers.keys(), "travel": travel_state.duplicate(true)}
