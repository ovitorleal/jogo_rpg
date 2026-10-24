class_name Npc
extends Interactable
## Personagem não jogável: um Interactable com sprite animado. A conversa é a ação
## "talk:<dialogue_id>", executada pelo mapa.

@export_file("*.png") var sheet: String = ""
@export var facing: String = "down"


func _ready() -> void:
	super._ready()
	var sprite := get_node_or_null("Sprite") as AnimatedSprite2D
	if sprite != null and not sheet.is_empty():
		sprite.sprite_frames = SpriteLibrary.frames_for(sheet)
		sprite.offset = SpriteLibrary.FEET_OFFSET
		sprite.play(SpriteLibrary.animation_name(sprite.sprite_frames, "idle", facing))
