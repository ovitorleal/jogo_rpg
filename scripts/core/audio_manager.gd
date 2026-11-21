extends Node
## Som do jogo (autoload "AudioManager"): efeitos curtos e música por lugar, com troca suave entre faixas.
## Só apresentação: nenhuma regra depende de som. Volumes e silenciar vêm do autoload Settings; a tecla M
## silencia em qualquer tela. Os arquivos são gerados por tools/audio/generate_audio.gd.

const SFX_DIR := "res://assets/audio/sfx"
const MUSIC_DIR := "res://assets/audio/music"
const SFX_NAMES: Array[String] = ["hit", "crit", "miss", "spell", "heal", "down", "dissolve", "death_save", "step",
		"click", "open", "coin", "level_up", "victory", "defeat", "potion", "quest"]
const MUSIC_TRACKS: Array[String] = ["title", "village", "forest", "combat"]
const MUSIC_BUS := &"Music"
const SFX_BUS := &"SFX"
const SFX_VOICES := 8
## Efeitos que soam baixo de propósito (repetem muito).
const QUIET := {"step": -10.0, "click": -14.0}
const FADE := 0.8

var current_track := ""
## Último efeito tocado e quantos já tocaram (para testes e depuração).
var last_sfx := ""
var sfx_played := 0

var _music: Array[AudioStreamPlayer] = []
var _active := 0
var _voices: Array[AudioStreamPlayer] = []
var _next_voice := 0
var _cache := {}
var _fades: Array[Tween] = []


## Monta tudo ao entrar na árvore (antes do primeiro quadro): os testes e as primeiras cenas já podem tocar.
func _enter_tree() -> void:
	if not _music.is_empty():
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_bus(MUSIC_BUS)
	_ensure_bus(SFX_BUS)
	for i in 2:
		var player := AudioStreamPlayer.new()
		player.bus = MUSIC_BUS
		add_child(player)
		_music.append(player)
	for i in SFX_VOICES:
		var voice := AudioStreamPlayer.new()
		voice.bus = SFX_BUS
		add_child(voice)
		_voices.append(voice)
	Settings.changed.connect(func(_key: String) -> void: apply_volumes())
	apply_volumes()
	get_tree().node_added.connect(_on_node_added)


func sfx_path(sfx: String) -> String:
	return "%s/%s.wav" % [SFX_DIR, sfx]


func music_path(track: String) -> String:
	return "%s/%s.wav" % [MUSIC_DIR, track]


## Toca um efeito pelo nome. Falso se o nome não existe. `pitch_jitter` varia a altura (ex.: 0.08 = ±8%).
func play_sfx(sfx: String, pitch_jitter: float = 0.0) -> bool:
	if not SFX_NAMES.has(sfx):
		return false
	var stream := _stream(sfx_path(sfx))
	if stream == null:
		return false
	var voice := _voices[_next_voice]
	_next_voice = (_next_voice + 1) % _voices.size()
	voice.stream = stream
	voice.volume_db = QUIET.get(sfx, 0.0)
	voice.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter) if pitch_jitter > 0.0 else 1.0
	if voice.is_inside_tree():
		voice.play()
	last_sfx = sfx
	sfx_played += 1
	return true


## Troca a música com fade. "" para a música. Falso se a faixa não existe ou já está tocando.
func play_music(track: String, fade: float = FADE) -> bool:
	if track == current_track:
		return false
	if not track.is_empty() and not MUSIC_TRACKS.has(track):
		return false
	var stream: AudioStream = null
	if not track.is_empty():
		stream = _stream(music_path(track))
		if stream == null:
			return false
	current_track = track
	for tween in _fades:
		if tween.is_valid():
			tween.kill()
	_fades.clear()
	var old := _music[_active]
	_active = 1 - _active
	var new := _music[_active]
	if stream != null:
		new.stream = stream
		new.volume_db = -40.0 if fade > 0.0 else 0.0
		if new.is_inside_tree():
			new.play()
	else:
		new.stop()
	if fade <= 0.0:
		old.stop()
		return true
	if stream != null:
		_fades.append(_fade(new, 0.0, fade, false))
	if old.playing:
		_fades.append(_fade(old, -40.0, fade, true))
	return true


func stop_music(fade: float = FADE) -> void:
	play_music("", fade)


func toggle_mute() -> void:
	Settings.set_value("muted", not Settings.muted)


## Aplica volumes e silenciar das opções nos barramentos.
func apply_volumes() -> void:
	_set_bus(&"Master", 1.0, Settings.muted)
	_set_bus(MUSIC_BUS, Settings.music_volume, false)
	_set_bus(SFX_BUS, Settings.sfx_volume, false)


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_M:
		toggle_mute()
		if is_inside_tree():
			get_viewport().set_input_as_handled()


## Todo botão do jogo faz clique ao ser apertado.
func _on_node_added(node: Node) -> void:
	var button := node as BaseButton
	if button != null and not button.pressed.is_connected(_on_button_pressed):
		button.pressed.connect(_on_button_pressed)


func _on_button_pressed() -> void:
	play_sfx("click")


func _fade(player: AudioStreamPlayer, to_db: float, time: float, stop_after: bool) -> Tween:
	var tween := create_tween()
	tween.tween_property(player, "volume_db", to_db, time)
	if stop_after:
		tween.tween_callback(player.stop)
	return tween


func _stream(path: String) -> AudioStream:
	if not _cache.has(path):
		_cache[path] = load(path) if ResourceLoader.exists(path) else null
	return _cache[path]


static func _ensure_bus(bus: StringName) -> void:
	if AudioServer.get_bus_index(bus) >= 0:
		return
	AudioServer.add_bus()
	var index := AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, bus)
	AudioServer.set_bus_send(index, &"Master")


static func _set_bus(bus: StringName, volume: float, muted: bool) -> void:
	var index := AudioServer.get_bus_index(bus)
	if index < 0:
		return
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(volume, 0.0001)))
	AudioServer.set_bus_mute(index, muted or volume <= 0.0)
