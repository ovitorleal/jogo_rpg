class_name EncounterTrigger
extends Area2D
## Área que inicia um encontro quando o jogador entra. Não inicia o combate sozinha:
## emite "triggered" e o ExplorationMap decide. Some depois que o encontro é vencido;
## depois de uma fuga, só volta a disparar quando o jogador sair e entrar de novo.

const GROUP := &"encounter_trigger"

signal triggered(source: EncounterTrigger)

@export var encounter_id: String = ""
## Id estável deste gatilho no mapa (para lembrar que já foi resolvido).
@export var trigger_id: String = ""
## Folha de sprites do inimigo mostrado no mapa, como pista do perigo.
@export_file("*.png") var marker_sheet: String = ""
@export var marker_facing: String = "left"

var armed: bool = true


func _ready() -> void:
	add_to_group(GROUP)
	var marker := get_node_or_null("Marker") as AnimatedSprite2D
	if marker != null and not marker_sheet.is_empty():
		SpriteLibrary.attach(marker, SpriteLibrary.frames_for(marker_sheet))
		marker.play(SpriteLibrary.animation_name(marker.sprite_frames, "idle", marker_facing))
	if ExplorationManager.is_resolved(trigger_id):
		queue_free()
		return
	if ExplorationManager.disarmed_trigger_id == trigger_id:
		armed = false
		ExplorationManager.disarmed_trigger_id = ""
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node2D) -> void:
	if body is Player and armed:
		armed = false
		triggered.emit(self)


func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		armed = true
