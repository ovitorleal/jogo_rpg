class_name Interactable
extends Area2D
## Componente de interação: o jogador detecta esta área e pode acioná-la.
## Não decide o que acontece; quem escuta "interacted" (o mapa) decide.

const GROUP := &"interactable"

signal interacted(source: Interactable)

## Texto curto exibido no aviso de interação, ex.: "Ler placa".
@export var prompt_text: String = "Interagir"
## Mensagem exibida ao interagir. Vazio = nenhuma mensagem.
@export_multiline var message_text: String = ""
@export var enabled: bool = true


func _ready() -> void:
	add_to_group(GROUP)


func interact() -> void:
	if enabled:
		interacted.emit(self)
