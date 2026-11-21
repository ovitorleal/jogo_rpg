extends Node
## Opções do jogador (autoload "Settings"): volumes, silenciar e tremor de tela. Ficam em user://settings.cfg, fora do
## salvamento da partida, e valem para qualquer jogo. Arquivo ausente ou inválido: valores padrão.

signal changed(key: String)

const DEFAULT_PATH := "user://settings.cfg"
const DEFAULTS := {"music_volume": 0.25, "sfx_volume": 0.8, "muted": false, "screen_shake": true}

## Caminho do arquivo (os testes trocam por um arquivo próprio).
var path: String = DEFAULT_PATH
var music_volume: float = 0.25
var sfx_volume: float = 0.8
var muted: bool = false
var screen_shake: bool = true


func _ready() -> void:
	load_settings()


func reset_to_defaults() -> void:
	for key: String in DEFAULTS:
		set(key, DEFAULTS[key])


## Lê as opções do disco e avisa quem escuta (changed com chave vazia = todas), para o áudio já abrir com os
## volumes gravados.
func load_settings() -> void:
	_read()
	changed.emit("")


func _read() -> void:
	reset_to_defaults()
	var config := ConfigFile.new()
	if config.load(path) != OK:
		return
	music_volume = clampf(float(config.get_value("audio", "music_volume", DEFAULTS["music_volume"])), 0.0, 1.0)
	sfx_volume = clampf(float(config.get_value("audio", "sfx_volume", DEFAULTS["sfx_volume"])), 0.0, 1.0)
	muted = bool(config.get_value("audio", "muted", DEFAULTS["muted"]))
	screen_shake = bool(config.get_value("video", "screen_shake", DEFAULTS["screen_shake"]))


func save_settings() -> bool:
	var config := ConfigFile.new()
	config.set_value("audio", "music_volume", music_volume)
	config.set_value("audio", "sfx_volume", sfx_volume)
	config.set_value("audio", "muted", muted)
	config.set_value("video", "screen_shake", screen_shake)
	return config.save(path) == OK


## Muda uma opção, grava e avisa quem escuta (o áudio aplica os volumes).
func set_value(key: String, value: Variant) -> void:
	if not DEFAULTS.has(key):
		return
	match key:
		"music_volume", "sfx_volume":
			set(key, clampf(float(value), 0.0, 1.0))
		_:
			set(key, bool(value))
	save_settings()
	changed.emit(key)
