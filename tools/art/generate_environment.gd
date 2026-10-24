extends SceneTree
## Gera o atlas de terreno (16x16) e os objetos de cenário (arte original, desenhada por código).
## Uso: godot --headless --path . --script res://tools/art/generate_environment.gd
##
## Atlas (overworld_tiles.png, 16 colunas):
##   linha 0: grama 0-3 (variações), 4 = bloqueio invisível, 5 = muro
##   linhas 1-4: transições terra sobre grama (máscara 0-15 em 4x4, colunas 0-3)
##              transições areia sobre grama (colunas 4-7)
##              transições água sobre areia (colunas 8-15: máscara m em (8 + (m % 4) * ... ) ver WATER_*)
## Máscara de cantos: bit 1 = canto superior esquerdo, 2 = superior direito, 4 = inferior direito,
## 8 = inferior esquerdo (o canto pertence ao terreno "de cima": terra, areia ou água).

const T := 16
const ATLAS_COLUMNS := 16
const ATLAS_ROWS := 9
const OUT_TILES := "res://assets/tilesets/overworld_tiles.png"
const OUT_TREE := "res://assets/environments/tree.png"
const OUT_PINE := "res://assets/environments/pine.png"
const OUT_BUSH := "res://assets/environments/bush.png"
const OUT_ROCK := "res://assets/environments/rock.png"
const OUT_SIGN := "res://assets/environments/sign.png"

## Posição no atlas: terra/areia em blocos 4x4 a partir de (0,1) e (4,1);
## água: 16 máscaras × 3 quadros de animação, a partir de (0,5), 12 colunas por linha.
const DIRT_ORIGIN := Vector2i(0, 1)
const SAND_ORIGIN := Vector2i(4, 1)
const WATER_ORIGIN := Vector2i(0, 5)
const WATER_FRAMES := 3

const GRASS := ["#3f7a34", "#4f9a3e", "#62b04a", "#7ccc5a"]
const DIRT := ["#7a5232", "#9c6c40", "#b88652", "#d2a46a"]
const SAND := ["#b89a5c", "#d8bc7a", "#ecd496", "#fae8b4"]
const WATER := ["#1e4a8c", "#2a64b0", "#3c82d0", "#8cc8f2"]
const FOAM := Color("#e6f6ff")
const STONE := ["#4a4a5c", "#6e6e84", "#9090a6", "#b8b8cc"]

var _seed := 1


func _initialize() -> void:
	var atlas := Image.create_empty(T * ATLAS_COLUMNS, T * ATLAS_ROWS, false, Image.FORMAT_RGBA8)
	for v in 4:
		_put(atlas, Vector2i(v, 0), _grass_tile(v))
	_put(atlas, Vector2i(5, 0), _wall_tile())
	for mask in 16:
		var cell := Vector2i(mask % 4, mask / 4)
		_put(atlas, DIRT_ORIGIN + cell, _transition_tile(mask, "dirt", 0))
		_put(atlas, SAND_ORIGIN + cell, _transition_tile(mask, "sand", 0))
		for frame in WATER_FRAMES:
			_put(atlas, water_coords(mask) + Vector2i(frame, 0), _transition_tile(mask, "water", frame))
	var ok := _save(atlas, OUT_TILES)
	ok = ok and _save(_tree(false), OUT_TREE)
	ok = ok and _save(_tree(true), OUT_PINE)
	ok = ok and _save(_bush(), OUT_BUSH)
	ok = ok and _save(_rock(), OUT_ROCK)
	ok = ok and _save(_sign(), OUT_SIGN)
	quit(0 if ok else 1)


static func water_coords(mask: int) -> Vector2i:
	@warning_ignore("integer_division")
	return WATER_ORIGIN + Vector2i((mask % 4) * WATER_FRAMES, mask / 4)


func _put(atlas: Image, cell: Vector2i, tile: Image) -> void:
	atlas.blit_rect(tile, Rect2i(0, 0, T, T), cell * T)


func _save(image: Image, path: String) -> bool:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var err := image.save_png(path)
	if err != OK:
		push_error("Falha ao salvar %s: %s" % [path, error_string(err)])
		return false
	print("Gerado: %s (%dx%d)" % [path, image.get_width(), image.get_height()])
	return true


## Ruído determinístico por pixel (mesmo resultado em toda execução).
func _hash(x: int, y: int, salt: int) -> float:
	var h := (x * 374761393 + y * 668265263 + salt * 2147483647) & 0x7fffffff
	h = (h ^ (h >> 13)) * 1274126177 & 0x7fffffff
	return float(h % 10000) / 10000.0


# --- Terreno -------------------------------------------------------------------

func _grass_pixel(x: int, y: int, variant: int) -> Color:
	var n := _hash(x, y, 7 + variant)
	var c := Color(GRASS[1])
	if n < 0.18:
		c = Color(GRASS[0])
	elif n > 0.86:
		c = Color(GRASS[2])
	# Manchas maiores, para quebrar a repetição.
	if _hash(x / 4, y / 4, 31 + variant) > 0.8:
		c = c.lightened(0.06)
	return c


func _grass_tile(variant: int) -> Image:
	var img := Image.create_empty(T, T, false, Image.FORMAT_RGBA8)
	for y in T:
		for x in T:
			img.set_pixel(x, y, _grass_pixel(x, y, variant))
	# Tufos de capim (forma de V) com luz no topo.
	var tufts := [[3, 9], [11, 4], [8, 13]] if variant == 1 else ([[12, 11]] if variant != 0 else [])
	for t: Array in tufts:
		var tx: int = t[0]
		var ty: int = t[1]
		img.set_pixel(tx, ty, Color(GRASS[3]))
		img.set_pixel(tx - 1, ty + 1, Color(GRASS[2]))
		img.set_pixel(tx + 1, ty + 1, Color(GRASS[2]))
		img.set_pixel(tx, ty + 1, Color(GRASS[0]))
		img.set_pixel(tx - 1, ty + 2, Color(GRASS[0]))
		img.set_pixel(tx + 1, ty + 2, Color(GRASS[0]))
	if variant >= 2:
		var petals := Color("#ffe066") if variant == 2 else Color("#ff8ca0")
		for f: Array in ([[4, 4], [10, 10]] if variant == 2 else [[5, 11], [12, 3], [2, 2]]):
			var fx: int = f[0]
			var fy: int = f[1]
			for o: Vector2i in [Vector2i(0, -1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, 1)]:
				img.set_pixel(fx + o.x, fy + o.y, petals)
			img.set_pixel(fx, fy, Color("#fff8e0"))
			img.set_pixel(fx, fy + 2, Color(GRASS[0]))
	return img


func _wall_tile() -> Image:
	var img := Image.create_empty(T, T, false, Image.FORMAT_RGBA8)
	for y in T:
		for x in T:
			var c: Color
			if y < 5:
				# Topo do muro: pedras chatas iluminadas.
				var seam := (x + (2 if y >= 3 else 0)) % 6 == 0 or y == 2
				c = Color(STONE[2]) if not seam else Color(STONE[1])
				if y == 0:
					c = Color(STONE[3])
			else:
				# Face: tijolos com junta escura e sombra embaixo.
				var row := (y - 5) / 4
				var offset := 3 if row % 2 == 1 else 0
				var joint := (y - 5) % 4 == 3 or (x + offset) % 7 == 6
				c = Color(STONE[0]) if joint else Color(STONE[1])
				if not joint and (y - 5) % 4 == 0:
					c = Color(STONE[2]).darkened(0.1)
				if y >= 14:
					c = c.darkened(0.35)
			img.set_pixel(x, y, c)
	return img


## Valor do campo do terreno "de cima" num pixel: interpolação bilinear dos cantos + ruído
## que se anula nas bordas do tile (as bordas de tiles vizinhos sempre se encaixam).
func _field(mask: int, x: int, y: int) -> float:
	var u := (x + 0.5) / T
	var v := (y + 0.5) / T
	var tl := 1.0 if mask & 1 else 0.0
	var tr := 1.0 if mask & 2 else 0.0
	var br := 1.0 if mask & 4 else 0.0
	var bl := 1.0 if mask & 8 else 0.0
	var top := lerpf(tl, tr, u)
	var bottom := lerpf(bl, br, u)
	var value := lerpf(top, bottom, v)
	var window := sin(PI * u) * sin(PI * v)
	return value + (_hash(x, y, 101 + mask) - 0.5) * 0.35 * window


func _transition_tile(mask: int, kind: String, frame: int) -> Image:
	var img := Image.create_empty(T, T, false, Image.FORMAT_RGBA8)
	var inside := []
	for y in T:
		inside.append([])
		for x in T:
			inside[y].append(_field(mask, x, y) >= 0.5)
	for y in T:
		for x in T:
			var is_top: bool = inside[y][x]
			var edge := false
			for o: Vector2i in [Vector2i(0, -1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, 1)]:
				var nx := x + o.x
				var ny := y + o.y
				if nx >= 0 and ny >= 0 and nx < T and ny < T and inside[ny][nx] != is_top:
					edge = true
			var c: Color
			match kind:
				"dirt":
					c = _dirt_pixel(x, y) if is_top else _grass_pixel(x, y, 0)
					if edge:
						c = Color(DIRT[0]) if is_top else Color(GRASS[2])
				"sand":
					c = _sand_pixel(x, y) if is_top else _grass_pixel(x, y, 0)
					if edge:
						c = Color(SAND[0]) if is_top else Color(GRASS[2])
				"water":
					c = _water_pixel(x, y, frame) if is_top else _sand_pixel(x, y)
					if edge and is_top:
						c = FOAM if (x + y + frame) % 3 != 0 else Color(WATER[3])
					elif edge:
						c = Color(SAND[0])
			img.set_pixel(x, y, c)
	return img


func _dirt_pixel(x: int, y: int) -> Color:
	var n := _hash(x, y, 13)
	if n < 0.15:
		return Color(DIRT[0]).lightened(0.1)
	if n > 0.9:
		return Color(DIRT[3])
	if n > 0.75:
		return Color(DIRT[2])
	return Color(DIRT[1])


func _sand_pixel(x: int, y: int) -> Color:
	var n := _hash(x, y, 17)
	if n < 0.12:
		return Color(SAND[0])
	if n > 0.85:
		return Color(SAND[3])
	return Color(SAND[1]) if n < 0.6 else Color(SAND[2])


func _water_pixel(x: int, y: int, frame: int) -> Color:
	var c := Color(WATER[1])
	if (y / 2) % 2 == 0:
		c = Color(WATER[1]).lerp(Color(WATER[0]), 0.35)
	# Ondas: traços claros que andam com o quadro.
	var wave := (x + frame * 2 + (y / 4) * 5) % 9
	if y % 4 == 1 and wave < 3:
		c = Color(WATER[2])
	if y % 4 == 1 and wave == 1:
		c = Color(WATER[3])
	return c


# --- Objetos ---------------------------------------------------------------------

## Árvore 32x48 com pivô na base do tronco (linha 44).
func _tree(pine: bool) -> Image:
	var c := PixelCanvas.new(32, 48)
	var bark := PixelCanvas.ramp("#3a2214", "#6a3e22", "#9a6232")
	var leaves := PixelCanvas.ramp("#1e4a24", "#2f7a34", "#58b046") if not pine \
			else PixelCanvas.ramp("#163a2a", "#245e3c", "#3e8a50")
	var trunk := c.new_mask()
	c.mask_rect(trunk, 13, 28, 6, 16)
	c.mask_rect(trunk, 11, 42, 10, 2)
	c.paint_part(trunk, bark, 2, 1)
	for y in range(30, 42, 3):
		c.set_px(15, y, bark[0])
		c.set_px(17, y + 1, bark[0])
	var canopy := c.new_mask()
	if pine:
		for i in 4:
			var w := 6 + i * 3
			var top := 3 + i * 7
			for y in range(top, top + 10):
				var half := int(lerpf(1.0, w, float(y - top) / 9.0))
				c.mask_rect(canopy, 16 - half, y, half * 2, 1)
	else:
		c.mask_ellipse(canopy, 16, 16, 13, 11)
		c.mask_ellipse(canopy, 9, 22, 7, 6)
		c.mask_ellipse(canopy, 23, 22, 7, 6)
		c.mask_ellipse(canopy, 16, 9, 9, 7)
	c.paint_part(canopy, leaves, 2, 3)
	# Folhas: tufos de luz e de sombra para dar volume.
	for i in 70:
		var x := int(_hash(i, 1, 900 + int(pine)) * 32)
		var y := int(_hash(i, 2, 900 + int(pine)) * 34)
		if c.mask_get(canopy, x, y) and c.mask_get(canopy, x + 1, y + 1):
			var lit := x + y < 30
			c.set_px(x, y, leaves[2].lightened(0.15) if lit else leaves[0])
			c.set_px(x + 1, y, leaves[2] if lit else leaves[0].darkened(0.1))
	c.outline()
	c.shadow(16, 44.5, 11, 3, 0.3)
	return c.image


func _bush() -> Image:
	var c := PixelCanvas.new(16, 16)
	var leaves := PixelCanvas.ramp("#1e4a24", "#3a8a3a", "#6cc04e")
	var bush := c.new_mask()
	c.mask_ellipse(bush, 8, 9, 7, 5)
	c.mask_ellipse(bush, 5, 7, 4, 4)
	c.mask_ellipse(bush, 11, 7, 4, 4)
	c.paint_part(bush, leaves, 1, 2)
	for b: Vector2i in [Vector2i(5, 9), Vector2i(10, 8), Vector2i(8, 11)]:
		c.set_px(b.x, b.y, Color("#e04050"))
		c.set_px(b.x, b.y - 1, Color("#ff8090"))
	c.outline()
	c.shadow(8, 14.5, 7, 1.5)
	return c.image


func _rock() -> Image:
	var c := PixelCanvas.new(16, 16)
	var stone := PixelCanvas.ramp(STONE[0], STONE[1], STONE[3])
	var rock := c.new_mask()
	c.mask_ellipse(rock, 8, 10, 6.5, 4.5)
	c.mask_ellipse(rock, 7, 8, 4.5, 3.5)
	c.paint_part(rock, stone, 2, 2)
	c.set_px(9, 10, Color(STONE[0]))
	c.set_px(10, 11, Color(STONE[0]))
	c.set_px(5, 7, Color(STONE[3]).lightened(0.2))
	var moss := c.new_mask()
	c.mask_rect(moss, 4, 7, 3, 1)
	c.mask_rect(moss, 3, 8, 2, 1)
	c.paint_part(moss, PixelCanvas.ramp("#2f6a2a", "#4f9a3e", "#7ccc5a"))
	c.outline()
	c.shadow(8, 14.5, 7, 1.5)
	return c.image


func _sign() -> Image:
	var c := PixelCanvas.new(16, 16)
	var wood := PixelCanvas.ramp("#5a341c", "#9a6438", "#c8915a")
	var post := c.new_mask()
	c.mask_rect(post, 7, 8, 2, 7)
	c.paint_part(post, wood)
	var board := c.new_mask()
	c.mask_rect(board, 2, 2, 12, 7)
	c.paint_part(board, wood, 1, 1)
	for y in [4, 6]:
		for x in range(4, 12):
			if (x + y) % 5 != 0:
				c.set_px(x, y, wood[0])
	c.outline()
	c.shadow(8, 15, 4, 1)
	return c.image
