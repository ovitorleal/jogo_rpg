class_name PixelCanvas
extends RefCounted
## Utilitário de pixel art usado só pelas ferramentas de geração (tools/ não é exportado).
## Estilo: partes com sombreamento automático em 3 tons (luz do alto à esquerda) e
## contorno seletivo (cada borda recebe uma versão escura da cor vizinha).

var width: int
var height: int
var image: Image


func _init(w: int, h: int) -> void:
	width = w
	height = h
	image = Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))


func inside(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < width and y < height


func set_px(x: int, y: int, color: Color) -> void:
	if inside(x, y):
		image.set_pixel(x, y, color)


func get_px(x: int, y: int) -> Color:
	return image.get_pixel(x, y) if inside(x, y) else Color(0, 0, 0, 0)


func blend_px(x: int, y: int, color: Color) -> void:
	if inside(x, y):
		image.set_pixel(x, y, image.get_pixel(x, y).blend(color))


# --- Partes: máscaras com sombreamento ----------------------------------------

## Máscara vazia do tamanho do quadro.
func new_mask() -> PackedByteArray:
	var mask := PackedByteArray()
	mask.resize(width * height)
	return mask


func mask_set(mask: PackedByteArray, x: int, y: int, value: int = 1) -> void:
	if inside(x, y):
		mask[y * width + x] = value


func mask_get(mask: PackedByteArray, x: int, y: int) -> bool:
	return inside(x, y) and mask[y * width + x] != 0


func mask_rect(mask: PackedByteArray, x: int, y: int, w: int, h: int) -> void:
	for yy in range(y, y + h):
		for xx in range(x, x + w):
			mask_set(mask, xx, yy)


func mask_ellipse(mask: PackedByteArray, cx: float, cy: float, rx: float, ry: float) -> void:
	for yy in range(floori(cy - ry) - 1, ceili(cy + ry) + 2):
		for xx in range(floori(cx - rx) - 1, ceili(cx + rx) + 2):
			var dx := (xx + 0.5 - cx) / rx
			var dy := (yy + 0.5 - cy) / ry
			if dx * dx + dy * dy <= 1.0:
				mask_set(mask, xx, yy)


## Linha grossa (Bresenham repetido) de a até b.
func mask_line(mask: PackedByteArray, a: Vector2, b: Vector2, thickness: int = 1) -> void:
	var steps := maxi(1, ceili(a.distance_to(b) * 2.0))
	for i in steps + 1:
		var p := a.lerp(b, float(i) / steps)
		for oy in thickness:
			for ox in thickness:
				mask_set(mask, roundi(p.x - 0.5) + ox - thickness / 2, roundi(p.y - 0.5) + oy - thickness / 2)


## Pinta a máscara com uma rampa [escuro, base, claro]: bordas de cima/esquerda clareiam,
## bordas de baixo/direita escurecem. light_depth > 1 alarga a faixa iluminada.
func paint_part(mask: PackedByteArray, ramp: Array, light_depth: int = 1, shadow_depth: int = 1) -> void:
	for y in height:
		for x in width:
			if not mask_get(mask, x, y):
				continue
			var color: Color = ramp[1]
			var lit := false
			for d in range(1, light_depth + 1):
				if not mask_get(mask, x, y - d) or not mask_get(mask, x - d, y):
					lit = true
			var shaded := false
			for d in range(1, shadow_depth + 1):
				if not mask_get(mask, x, y + d) or not mask_get(mask, x + d, y):
					shaded = true
			if shaded:
				color = ramp[0]
			elif lit:
				color = ramp[2]
			set_px(x, y, color)


## Contorno seletivo: pixels transparentes vizinhos (4 direções) de pixels opacos recebem uma
## versão bem escura da cor vizinha; pixels vizinhos de diagonais recebem nada (visual mais limpo).
func outline(darkness: float = 0.65, base: Color = Color8(26, 16, 32)) -> void:
	var source := image.duplicate() as Image
	for y in height:
		for x in width:
			if source.get_pixel(x, y).a > 0.0:
				continue
			var neighbor := Color(0, 0, 0, 0)
			for offset: Vector2i in [Vector2i(0, -1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, 1)]:
				var n: Vector2i = Vector2i(x, y) + offset
				if n.x >= 0 and n.y >= 0 and n.x < width and n.y < height and source.get_pixel(n.x, n.y).a > 0.99:
					neighbor = source.get_pixel(n.x, n.y)
					break
			if neighbor.a > 0.0:
				var c := neighbor.darkened(darkness).lerp(base, 0.5)
				c.a = 1.0
				image.set_pixel(x, y, c)


## Sombra elíptica semitransparente no chão.
func shadow(cx: float, cy: float, rx: float, ry: float, alpha: float = 0.28) -> void:
	for yy in range(floori(cy - ry) - 1, ceili(cy + ry) + 2):
		for xx in range(floori(cx - rx) - 1, ceili(cx + rx) + 2):
			var dx := (xx + 0.5 - cx) / rx
			var dy := (yy + 0.5 - cy) / ry
			if dx * dx + dy * dy <= 1.0 and get_px(xx, yy).a == 0.0:
				set_px(xx, yy, Color(0.05, 0.03, 0.08, alpha))


## Copia outra imagem para (ox, oy), opcionalmente espelhada, pulando transparentes.
func blit(source: Image, ox: int, oy: int, flip_h: bool = false) -> void:
	for y in source.get_height():
		for x in source.get_width():
			var c := source.get_pixel(source.get_width() - 1 - x if flip_h else x, y)
			if c.a > 0.0:
				set_px(ox + x, oy + y, c)


static func hex(code: String) -> Color:
	return Color.html(code)


static func ramp(dark: String, base: String, light: String) -> Array:
	return [hex(dark), hex(base), hex(light)]
