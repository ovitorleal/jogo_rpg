extends Node
## Autoload "QuestManager": diário de missões do jogo atual e avisos pendentes para o HUD.

var log := QuestLog.new()
## Mensagens geradas fora do mapa (ex.: no combate), mostradas ao voltar à exploração.
var pending_messages: Array[String] = []


func notify(kind: String, target: String) -> Array[String]:
	var messages := log.notify(kind, target, Content.registry)
	return messages


## Notificação vinda de outra cena: guarda as mensagens para exibir depois.
func notify_later(kind: String, target: String) -> void:
	pending_messages.append_array(notify(kind, target))


func take_pending_messages() -> Array[String]:
	var messages := pending_messages.duplicate()
	pending_messages.clear()
	return messages


func reset() -> void:
	log = QuestLog.new()
	pending_messages.clear()
