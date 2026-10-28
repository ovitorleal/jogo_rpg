class_name MapBackdrop
extends Sprite2D
## Fundo pintado de um mapa (estilo de As Crônicas de Arghaz): uma imagem grande esticada sobre a área
## jogável. O mapa continua com as colisões dos tiles e adereços, mas eles deixam de ser desenhados;
## a câmera fica presa à área do fundo, e paredes invisíveis fecham as bordas.

## Área do mapa coberta pela imagem, em pixels do mundo.
@export var map_rect: Rect2 = Rect2(0, 0, 640, 360)

const BORDER := 16.0


func _ready() -> void:
	centered = false
	z_index = -100
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	position = map_rect.position
	if texture != null:
		scale = map_rect.size / texture.get_size()
	_build_borders.call_deferred()


## Paredes invisíveis em volta da área pintada (o jogador não sai da imagem), irmãs do fundo.
func _build_borders() -> void:
	var body := StaticBody2D.new()
	body.name = "BackdropBorders"
	body.collision_mask = 0
	var r := map_rect
	for rect: Rect2 in [Rect2(r.position.x - BORDER, r.position.y - BORDER, r.size.x + BORDER * 2, BORDER),
			Rect2(r.position.x - BORDER, r.end.y, r.size.x + BORDER * 2, BORDER),
			Rect2(r.position.x - BORDER, r.position.y, BORDER, r.size.y),
			Rect2(r.end.x, r.position.y, BORDER, r.size.y)]:
		var shape := CollisionShape2D.new()
		var box := RectangleShape2D.new()
		box.size = rect.size
		shape.shape = box
		shape.position = rect.get_center()
		body.add_child(shape)
	get_parent().add_child(body)
