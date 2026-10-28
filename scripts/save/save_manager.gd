extends Node
## Autoload "SaveManager": um único slot de salvamento em user:// (no navegador, IndexedDB).
##
## Gravação segura: o texto é validado antes de tocar no disco, gravado num arquivo temporário e
## conferido; o salvamento anterior vira cópia de recuperação; só então o principal é substituído
## e relido. Na leitura, se o principal estiver corrompido, tenta o temporário e depois a cópia.
## Um salvamento válido nunca é substituído por dados inválidos.
##
## Autosave: pedidos de pontos seguros (request_autosave) são agrupados e gravados com um pequeno
## atraso, só quando o jogo está num estado consistente (mapa sem diálogo/ação pendente, ou tela de
## viagem parada). Fora disso o pedido espera.

signal save_finished(ok: bool, message: String)

const DEFAULT_DIR := "user://save"
const AUTOSAVE_DELAY := 0.4
const RETRY_DELAY := 1.0

## Pasta do slot (os testes usam outra e restauram).
var save_dir: String = DEFAULT_DIR
## Desligado nos testes para que pontos de autosave não gravem.
var autosave_enabled: bool = true
## Mostra o indicador "Salvando…/Jogo salvo" na tela.
var indicator_enabled: bool = true
var last_message: String = ""
var last_saved_at: int = 0

var _pending_reason: String = ""
var _timer: Timer
var _layer: CanvasLayer
var _label: Label
var _tween: Tween


func _ready() -> void:
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.timeout.connect(_on_autosave_timer)
	add_child(_timer)
	_layer = CanvasLayer.new()
	_layer.layer = 120
	add_child(_layer)
	_label = Label.new()
	_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_label.offset_right = -6
	_label.offset_bottom = -4
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_label.add_theme_font_size_override("font_size", 8)
	_label.add_theme_color_override("font_outline_color", Color(0.067, 0.086, 0.110))
	_label.add_theme_constant_override("outline_size", 3)
	_label.modulate.a = 0.0
	_layer.add_child(_label)


func main_path() -> String:
	return save_dir.path_join("slot_1.json")


func backup_path() -> String:
	return save_dir.path_join("slot_1.backup.json")


func temp_path() -> String:
	return save_dir.path_join("slot_1.tmp.json")


## No navegador, false quando o IndexedDB não está disponível (ex.: janela anônima restrita).
func storage_persistent() -> bool:
	return OS.is_userfs_persistent()


# --- Salvar -----------------------------------------------------------------------

## Salva o jogo atual. Retorna {ok, message}.
func save_now() -> Dictionary:
	var location := current_location()
	if not location["ok"]:
		return _finish(false, "Não é possível salvar agora: %s." % location["reason"])
	return save_state(SaveGame.capture(location["location"]))


## Grava um estado já capturado (usado por save_now e pelos testes).
func save_state(state: Dictionary) -> Dictionary:
	_show("Salvando…", Color(0.902, 0.882, 0.827))
	var text := SaveGame.encode(state)
	var check := SaveGame.decode(text, Content.registry)
	if not check["ok"]:
		return _finish(false, "Falha ao salvar: estado inválido (%s). O salvamento anterior foi mantido." % check["errors"][0])
	var err := DirAccess.make_dir_recursive_absolute(save_dir)
	if err != OK and not DirAccess.dir_exists_absolute(save_dir):
		return _finish(false, "Falha ao salvar: armazenamento local indisponível (%s)." % error_string(err))
	if not _write_verified(temp_path(), text):
		return _finish(false, "Falha ao salvar: não foi possível gravar no armazenamento local.")
	var previous := _read(main_path())
	if not previous.is_empty() and SaveGame.decode(previous, Content.registry)["ok"]:
		_write_verified(backup_path(), previous)
	if not _write_verified(main_path(), text):
		return _finish(false, "Falha ao salvar: gravação não confirmada. Há uma cópia temporária para recuperação.")
	DirAccess.remove_absolute(temp_path())
	last_saved_at = int(state.get("saved_at", 0))
	if not storage_persistent():
		return _finish(true, "Jogo salvo nesta sessão, mas o navegador não guarda dados permanentes: o progresso será perdido ao fechar.")
	return _finish(true, "Jogo salvo.")


## Onde o jogo pode ser salvo agora: {ok, location, reason}.
func current_location() -> Dictionary:
	if not PartyManager.has_party():
		return {"ok": false, "reason": "não há personagem no grupo"}
	if not ExplorationManager.pending_encounter_id.is_empty():
		return {"ok": false, "reason": "um combate está começando"}
	var scene := get_tree().current_scene
	if scene is ExplorationMap:
		var map := scene as ExplorationMap
		var why := map.save_blocker()
		if not why.is_empty():
			return {"ok": false, "reason": why}
		var position := map.player_position()
		return {"ok": true, "location": {"kind": SaveGame.KIND_MAP, "scene": map.scene_file_path,
				"position": [position.x, position.y]}}
	if scene is TravelScene:
		var why := (scene as TravelScene).save_blocker()
		if not why.is_empty():
			return {"ok": false, "reason": why}
		return {"ok": true, "location": {"kind": SaveGame.KIND_TRAVEL, "scene": SaveGame.TRAVEL_SCENE}}
	return {"ok": false, "reason": "só é possível salvar durante a exploração ou a viagem"}


## Pede um autosave (ponto seguro). Pedidos próximos viram uma única gravação.
func request_autosave(reason: String) -> void:
	if not autosave_enabled or not PartyManager.has_party():
		return
	_pending_reason = reason
	if _timer.is_stopped():
		_timer.start(AUTOSAVE_DELAY)


func has_pending_autosave() -> bool:
	return not _pending_reason.is_empty()


func _on_autosave_timer() -> void:
	if _pending_reason.is_empty() or not autosave_enabled or not PartyManager.has_party():
		_pending_reason = ""
		return
	if not current_location()["ok"]:
		# Estado ainda inconsistente (diálogo, combate, troca de cena): tenta de novo depois.
		_timer.start(RETRY_DELAY)
		return
	_pending_reason = ""
	save_now()


# --- Carregar -----------------------------------------------------------------------

## Melhor salvamento disponível: {ok, state, source ("main", "temp", "backup"), errors, message}.
func peek() -> Dictionary:
	var problems: Array[String] = []
	for entry: Array in [[main_path(), "main"], [temp_path(), "temp"], [backup_path(), "backup"]]:
		var path: String = entry[0]
		if not FileAccess.file_exists(path):
			continue
		var decoded := SaveGame.decode(_read(path), Content.registry)
		if decoded["ok"]:
			var message := ""
			if entry[1] != "main":
				message = "O salvamento principal estava danificado; foi usada a cópia de recuperação."
			return {"ok": true, "state": decoded["state"], "source": entry[1], "errors": problems, "message": message}
		problems.append("%s: %s" % [path.get_file(), "; ".join(decoded["errors"])])
	if problems.is_empty():
		return {"ok": false, "state": {}, "source": "", "errors": problems, "message": ""}
	return {"ok": false, "state": {}, "source": "", "errors": problems,
			"message": "O salvamento está danificado e não pode ser carregado (%s)." % problems[0]}


func has_save() -> bool:
	return peek()["ok"]


## Aplica o melhor salvamento disponível. Retorna {ok, scene, message}; não troca de cena.
func load_game() -> Dictionary:
	var found := peek()
	if not found["ok"]:
		return {"ok": false, "scene": "", "message": found["message"] if not found["message"].is_empty() else "Nenhum jogo salvo."}
	var scene := SaveGame.apply(found["state"])
	last_saved_at = int(found["state"].get("saved_at", 0))
	_pending_reason = ""
	return {"ok": true, "scene": scene, "message": found["message"]}


## Apaga o slot (usado pelos testes).
func delete_save() -> void:
	for path in [main_path(), backup_path(), temp_path()]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


# --- Arquivos -----------------------------------------------------------------------

func _write_verified(path: String, text: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("Salvamento: não foi possível abrir %s (%s)" % [path, error_string(FileAccess.get_open_error())])
		return false
	file.store_string(text)
	file.close()
	return _read(path) == text


func _read(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	return file.get_as_text()


# --- Indicador ----------------------------------------------------------------------

func _finish(ok: bool, message: String) -> Dictionary:
	last_message = message
	_show(message, Color(0.62, 0.86, 0.6) if ok else Color(1.0, 0.55, 0.5), 2.0 if ok else 5.0)
	save_finished.emit(ok, message)
	return {"ok": ok, "message": message}


func _show(text: String, color: Color, hold: float = -1.0) -> void:
	if not indicator_enabled or _label == null:
		return
	_label.text = text
	_label.add_theme_color_override("font_color", color)
	if _tween != null:
		_tween.kill()
	_label.modulate.a = 1.0
	if hold > 0.0:
		_tween = create_tween()
		_tween.tween_interval(hold)
		_tween.tween_property(_label, "modulate:a", 0.0, 0.6)
