class_name PixelCanvas
extends RefCounted
## Utilitário de pixel art usado pelas ferramentas de geração e pelo CharacterPainter em tempo de execução.
## Estilo: partes com sombreamento automático (luz do alto à esquerda) e contorno seletivo
## (cada borda recebe uma versão escura da cor vizinha).
##
## Resolução: as coordenadas das formas são "lógicas" (o desenho de 32 px) e a imagem tem k vezes
## mais pixels. Com k = 2, curvas e diagonais saem mais suaves, o contorno fica com metade da
## espessura e o sombreamento ganha tons intermediários; detalhes finos (olhos, brilhos) usam as
## funções *_fine, em pixels reais. Com k = 1 o resultado é idêntico ao estilo original.

## Tamanho lógico.
var width: int
var height: int
## Fator de resolução e tamanho real da imagem.
var k: int
var pw: int
var ph: int
var image: Image


func _init(w: int, h: int, scale: int = 1) -> void:
	width = w
	height = h
	k = maxi(1, scale)
	pw = w * k
	ph = h * k
	image = Image.create_empty(pw, ph, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))


func inside(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < width and y < height


func inside_fine(px: int, py: int) -> bool:
	return px >= 0 and py >= 0 and px < pw and py < ph


## Pixel lógico (bloco k x k).
func set_px(x: int, y: int, color: Color) -> void:
	for oy in k:
		for ox in k:
			set_fine(x * k + ox, y * k + oy, color)


func get_px(x: int, y: int) -> Color:
	return get_fine(x * k + k / 2, y * k + k / 2) if inside(x, y) else Color(0, 0, 0, 0)


func blend_px(x: int, y: int, color: Color) -> void:
	for oy in k:
		for ox in k:
			blend_fine(x * k + ox, y * k + oy, color)


## Pixel real da imagem.
func set_fine(px: int, py: int, color: Color) -> void:
	if inside_fine(px, py):
		image.set_pixel(px, py, color)


func get_fine(px: int, py: int) -> Color:
	return image.get_pixel(px, py) if inside_fine(px, py) else Color(0, 0, 0, 0)


func blend_fine(px: int, py: int, color: Color) -> void:
	if inside_fine(px, py):
		image.set_pixel(px, py, image.get_pixel(px, py).blend(color))


## Pixel real na posição lógica (x, y) com precisão de 1/k.
func dot(x: float, y: float, color: Color) -> void:
	set_fine(floori(x * k), floori(y * k), color)


# --- Partes: máscaras com sombreamento ----------------------------------------

## Máscara vazia do tamanho da imagem (pixels reais).
func new_mask() -> PackedByteArray:
	var mask := PackedByteArray()
	mask.resize(pw * ph)
	return mask


## Marca o pixel lógico inteiro (bloco k x k).
func mask_set(mask: PackedByteArray, x: int, y: int, value: int = 1) -> void:
	for oy in k:
		for ox in k:
			fine_set(mask, x * k + ox, y * k + oy, value)


## Pixel lógico pela amostra do centro do bloco.
func mask_get(mask: PackedByteArray, x: int, y: int) -> bool:
	return inside(x, y) and fine_get(mask, x * k + k / 2, y * k + k / 2)


func fine_set(mask: PackedByteArray, px: int, py: int, value: int = 1) -> void:
	if inside_fine(px, py):
		mask[py * pw + px] = value


func fine_get(mask: PackedByteArray, px: int, py: int) -> bool:
	return inside_fine(px, py) and mask[py * pw + px] != 0


## Coordenada lógica do centro de um pixel real.
func logical(p: int) -> float:
	return (p + 0.5) / k


func mask_rect(mask: PackedByteArray, x: int, y: int, w: int, h: int) -> void:
	for py in range(y * k, (y + h) * k):
		for px in range(x * k, (x + w) * k):
			fine_set(mask, px, py)


## Retângulo com bordas em frações de pixel lógico (arredondadas para pixels reais).
func mask_rect_f(mask: PackedByteArray, x: float, y: float, w: float, h: float) -> void:
	for py in range(roundi(y * k), roundi((y + h) * k)):
		for px in range(roundi(x * k), roundi((x + w) * k)):
			fine_set(mask, px, py)


## Polígono (pontos em coordenadas lógicas), preenchido pelos centros dos pixels reais.
func mask_polygon(mask: PackedByteArray, points: PackedVector2Array) -> void:
	var box := Rect2(points[0], Vector2.ZERO)
	for point in points:
		box = box.expand(point)
	for py in range(floori(box.position.y * k), ceili(box.end.y * k) + 1):
		for px in range(floori(box.position.x * k), ceili(box.end.x * k) + 1):
			if Geometry2D.is_point_in_polygon(Vector2(logical(px), logical(py)), points):
				fine_set(mask, px, py)


## Retângulo de cantos arredondados (raio r em pixels lógicos) — membros, tronco, capa.
func mask_round_rect(mask: PackedByteArray, x: float, y: float, w: float, h: float, r: float) -> void:
	var radius := minf(r, minf(w, h) * 0.5)
	for py in range(floori(y * k), ceili((y + h) * k)):
		for px in range(floori(x * k), ceili((x + w) * k)):
			var lx := logical(px)
			var ly := logical(py)
			if lx < x or ly < y or lx > x + w or ly > y + h:
				continue
			var qx := clampf(lx, x + radius, x + w - radius)
			var qy := clampf(ly, y + radius, y + h - radius)
			if Vector2(lx, ly).distance_to(Vector2(qx, qy)) <= radius:
				fine_set(mask, px, py)


func mask_ellipse(mask: PackedByteArray, cx: float, cy: float, rx: float, ry: float) -> void:
	for py in range(floori((cy - ry) * k) - 1, ceili((cy + ry) * k) + 2):
		for px in range(floori((cx - rx) * k) - 1, ceili((cx + rx) * k) + 2):
			var dx := (logical(px) - cx) / rx
			var dy := (logical(py) - cy) / ry
			if dx * dx + dy * dy <= 1.0:
				fine_set(mask, px, py)


## Linha grossa de a até b. Com k = 1, pincel quadrado (Bresenham repetido); com k > 1,
## pincel redondo de diâmetro thickness (em pixels lógicos).
func mask_line(mask: PackedByteArray, a: Vector2, b: Vector2, thickness: float = 1.0) -> void:
	if k == 1:
		var t := maxi(1, roundi(thickness))
		var steps := maxi(1, ceili(a.distance_to(b) * 2.0))
		for i in steps + 1:
			var p := a.lerp(b, float(i) / steps)
			for oy in t:
				for ox in t:
					fine_set(mask, roundi(p.x - 0.5) + ox - t / 2, roundi(p.y - 0.5) + oy - t / 2)
		return
	# Distância de cada pixel ao segmento (uma passada sobre a caixa da linha).
	var radius := maxf(0.5, thickness * k * 0.5)
	var fa := a * k
	var fb := b * k
	var seg := fb - fa
	var len_sq := maxf(seg.length_squared(), 0.0001)
	var r_sq := radius * radius
	for py in range(maxi(0, floori(minf(fa.y, fb.y) - radius)), mini(ph, ceili(maxf(fa.y, fb.y) + radius) + 1)):
		var cy := py + 0.5
		for px in range(maxi(0, floori(minf(fa.x, fb.x) - radius)), mini(pw, ceili(maxf(fa.x, fb.x) + radius) + 1)):
			var cx := px + 0.5
			var u := clampf(((cx - fa.x) * seg.x + (cy - fa.y) * seg.y) / len_sq, 0.0, 1.0)
			var dx := cx - (fa.x + seg.x * u)
			var dy := cy - (fa.y + seg.y * u)
			if dx * dx + dy * dy <= r_sq:
				mask[py * pw + px] = 1


## Pinta a máscara com uma rampa [escuro, base, claro]: bordas de cima/esquerda clareiam,
## bordas de baixo/direita escurecem. light_depth > 1 alarga a faixa iluminada.
## Com k > 1 cada faixa ganha um tom intermediário (volume mais suave) e, com contact = true,
## as bordas que encostam em partes já pintadas recebem uma linha interna escura (separação nítida).
func paint_part(mask: PackedByteArray, ramp: Array, light_depth: int = 1, shadow_depth: int = 1,
		contact: bool = true) -> void:
	if k == 1:
		_paint_part_flat(mask, ramp, light_depth, shadow_depth)
		return
	var deep: Color = ramp[0]
	var base: Color = ramp[1]
	var light: Color = ramp[2]
	var half_dark := deep.lerp(base, 0.5)
	var half_light := base.lerp(light, 0.5)
	var line := deep.darkened(0.3)
	var lit_reach := light_depth * k
	var shade_reach := shadow_depth * k
	var first := mask.find(1)
	if first < 0:
		return
	# Só as linhas que a parte ocupa. Distâncias até a borda nas 4 direções por programação dinâmica
	# (O(n)); os vizinhos fora da máscara nunca são escritos aqui, então a imagem atual serve como
	# "o que já estava pintado" para as linhas internas.
	var y0 := first / pw
	var y1 := mask.rfind(1) / pw
	var rows := y1 - y0 + 1
	var up := PackedInt32Array()
	var left := PackedInt32Array()
	var down := PackedInt32Array()
	var right := PackedInt32Array()
	for arr: PackedInt32Array in [up, left, down, right]:
		arr.resize(rows * pw)
	up = _fill(up); left = _fill(left); down = _fill(down); right = _fill(right)
	for ry in rows:
		var row := (y0 + ry) * pw
		var run := 0
		for px in pw:
			run = run + 1 if mask[row + px] != 0 else 0
			left[ry * pw + px] = run
			up[ry * pw + px] = (up[(ry - 1) * pw + px] + 1 if ry > 0 else 1) if mask[row + px] != 0 else 0
		run = 0
		for px in range(pw - 1, -1, -1):
			run = run + 1 if mask[row + px] != 0 else 0
			right[ry * pw + px] = run
	for ry in range(rows - 1, -1, -1):
		var row := (y0 + ry) * pw
		for px in pw:
			down[ry * pw + px] = (down[(ry + 1) * pw + px] + 1 if ry < rows - 1 else 1) if mask[row + px] != 0 else 0
	var data := image.get_data()
	for ry in rows:
		var py := y0 + ry
		for px in pw:
			if mask[py * pw + px] == 0:
				continue
			var i := ry * pw + px
			var lit_d := mini(up[i], left[i])
			var shade_d := mini(down[i], right[i])
			var color := base
			if shade_d <= shade_reach / 2:
				color = deep
			elif shade_d <= shade_reach:
				color = half_dark
			elif lit_d <= lit_reach / 2:
				color = light
			elif lit_d <= lit_reach:
				color = half_light
			if contact and _touches_painted(mask, data, px, py):
				color = line
			image.set_pixel(px, py, color)


func _fill(arr: PackedInt32Array) -> PackedInt32Array:
	arr.fill(0)
	return arr


func _touches_painted(mask: PackedByteArray, data: PackedByteArray, px: int, py: int) -> bool:
	if py > 0 and mask[(py - 1) * pw + px] == 0 and data[((py - 1) * pw + px) * 4 + 3] > 252:
		return true
	if px > 0 and mask[py * pw + px - 1] == 0 and data[(py * pw + px - 1) * 4 + 3] > 252:
		return true
	if px < pw - 1 and mask[py * pw + px + 1] == 0 and data[(py * pw + px + 1) * 4 + 3] > 252:
		return true
	if py < ph - 1 and mask[(py + 1) * pw + px] == 0 and data[((py + 1) * pw + px) * 4 + 3] > 252:
		return true
	return false


func _paint_part_flat(mask: PackedByteArray, ramp: Array, light_depth: int, shadow_depth: int) -> void:
	for y in height:
		for x in width:
			if not fine_get(mask, x, y):
				continue
			var color: Color = ramp[1]
			var lit := false
			for d in range(1, light_depth + 1):
				if not fine_get(mask, x, y - d) or not fine_get(mask, x - d, y):
					lit = true
			var shaded := false
			for d in range(1, shadow_depth + 1):
				if not fine_get(mask, x, y + d) or not fine_get(mask, x + d, y):
					shaded = true
			if shaded:
				color = ramp[0]
			elif lit:
				color = ramp[2]
			set_fine(x, y, color)


## Contorno seletivo: pixels transparentes vizinhos (4 direções) de pixels opacos recebem uma
## versão bem escura da cor vizinha; pixels vizinhos de diagonais recebem nada (visual mais limpo).
## Com k > 1 o contorno tem 1 pixel real e é um pouco mais claro do lado iluminado (alto/esquerda).
func outline(darkness: float = 0.65, base: Color = Color8(26, 16, 32)) -> void:
	var source := image.duplicate() as Image
	var data := source.get_data()  # RGBA8: alfa no byte 4i + 3
	for py in ph:
		for px in pw:
			if data[(py * pw + px) * 4 + 3] > 0:
				continue
			var neighbor := Color(0, 0, 0, 0)
			var lit_side := false
			for offset: Vector2i in [Vector2i(0, -1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, 1)]:
				var n: Vector2i = Vector2i(px, py) + offset
				if inside_fine(n.x, n.y) and data[(n.y * pw + n.x) * 4 + 3] > 252:
					neighbor = source.get_pixel(n.x, n.y)
					lit_side = offset.x > 0 or offset.y > 0
					break
			if neighbor.a > 0.0:
				var c := neighbor.darkened(darkness).lerp(base, 0.5)
				if k > 1 and lit_side:
					c = c.lerp(neighbor, 0.18)
				c.a = 1.0
				image.set_pixel(px, py, c)


## Sombra elíptica semitransparente no chão.
func shadow(cx: float, cy: float, rx: float, ry: float, alpha: float = 0.28) -> void:
	for py in range(floori((cy - ry) * k) - 1, ceili((cy + ry) * k) + 2):
		for px in range(floori((cx - rx) * k) - 1, ceili((cx + rx) * k) + 2):
			var dx := (logical(px) - cx) / rx
			var dy := (logical(py) - cy) / ry
			if dx * dx + dy * dy <= 1.0 and get_fine(px, py).a == 0.0:
				set_fine(px, py, Color(0.05, 0.03, 0.08, alpha))


## Copia outra imagem para (ox, oy) em pixels reais, opcionalmente espelhada, pulando transparentes.
func blit(source: Image, ox: int, oy: int, flip_h: bool = false) -> void:
	for y in source.get_height():
		for x in source.get_width():
			var c := source.get_pixel(source.get_width() - 1 - x if flip_h else x, y)
			if c.a > 0.0:
				set_fine(ox + x, oy + y, c)


static func hex(code: String) -> Color:
	return Color.html(code)


static func ramp(dark: String, base: String, light: String) -> Array:
	return [hex(dark), hex(base), hex(light)]
