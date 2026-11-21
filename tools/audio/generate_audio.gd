extends SceneTree
## Gera os efeitos sonoros e as músicas do jogo (som original, sintetizado por código, licença do projeto).
## Uso: godot --headless --path . --script res://tools/audio/generate_audio.gd
##
## Estilo 8/16-bit, para combinar com a pixel art: ondas quadrada, triângulo e seno, ruído, envelope e filtro.
## Determinístico: o ruído vem de um hash, não de random, então rodar de novo gera os mesmos arquivos.

const RATE := 22050
const SFX_DIR := "res://assets/audio/sfx"
const MUSIC_DIR := "res://assets/audio/music"

var _buf := PackedFloat32Array()


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SFX_DIR))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(MUSIC_DIR))
	var ok := true
	for sfx_name: String in SFX:
		_buf = PackedFloat32Array()
		call("_sfx_" + sfx_name)
		ok = _save("%s/%s.wav" % [SFX_DIR, sfx_name], 0.9) and ok
	for track: String in MUSIC:
		_buf = PackedFloat32Array()
		_compose(MUSIC[track])
		# Música mais baixa que os efeitos: fica de fundo.
		ok = _save("%s/%s.wav" % [MUSIC_DIR, track], 0.2) and ok
	quit(0 if ok else 1)


# --- Síntese ---------------------------------------------------------------------------------------

## Ruído determinístico em [-1, 1].
func _noise(i: int, salt: int) -> float:
	var h := (i * 374761393 + salt * 668265263) & 0x7fffffff
	h = (h ^ (h >> 13)) * 1274126177 & 0x7fffffff
	return float(h % 20001) / 10000.0 - 1.0


func _wave(kind: String, phase: float, duty: float = 0.5) -> float:
	var p := phase - floorf(phase)
	match kind:
		"square":
			return 1.0 if p < duty else -1.0
		"tri":
			return 4.0 * absf(p - 0.5) - 1.0
		"saw":
			return 2.0 * p - 1.0
	return sin(p * TAU)


## Envelope ataque/decaimento simples (amplitude 0..1) para o instante t de uma nota de duração d.
func _env(t: float, d: float, attack: float, release: float) -> float:
	if t < attack:
		return t / maxf(attack, 0.0001)
	if t > d - release:
		return maxf(0.0, (d - t) / maxf(release, 0.0001))
	return 1.0


func _ensure(n: int) -> void:
	if _buf.size() < n:
		var old := _buf.size()
		_buf.resize(n)
		for i in range(old, n):
			_buf[i] = 0.0


## Soma uma nota ao buffer: frequência que pode deslizar de f0 a f1, onda, volume, envelope.
func _tone(start: float, dur: float, f0: float, f1: float, kind: String, vol: float, attack: float = 0.005,
		release: float = 0.05, duty: float = 0.5) -> void:
	var s := int(start * RATE)
	var n := int(dur * RATE)
	_ensure(s + n)
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		var f := lerpf(f0, f1, t / dur)
		phase += f / RATE
		_buf[s + i] += _wave(kind, phase, duty) * vol * _env(t, dur, attack, release)


## Ruído com filtro passa-baixa (cutoff 0..1: 1 = sem filtro), volume e envelope.
func _hiss(start: float, dur: float, cutoff: float, vol: float, attack: float = 0.002, release: float = 0.05,
		salt: int = 1, cutoff_end: float = -1.0) -> void:
	var s := int(start * RATE)
	var n := int(dur * RATE)
	_ensure(s + n)
	var y := 0.0
	for i in n:
		var t := float(i) / RATE
		var c := lerpf(cutoff, cutoff_end if cutoff_end >= 0.0 else cutoff, t / dur)
		y += (_noise(i + s, salt) - y) * clampf(c, 0.01, 1.0)
		_buf[s + i] += y * vol * _env(t, dur, attack, release)


static func _midi(note: float) -> float:
	return 440.0 * pow(2.0, (note - 69.0) / 12.0)


func _save(path: String, peak: float) -> bool:
	var top := 0.0
	for v in _buf:
		top = maxf(top, absf(v))
	var gain := peak / top if top > 0.0 else 1.0
	var bytes := PackedByteArray()
	bytes.resize(_buf.size() * 2)
	for i in _buf.size():
		bytes.encode_s16(i * 2, int(clampf(_buf[i] * gain, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = bytes
	var err := wav.save_to_wav(ProjectSettings.globalize_path(path))
	if err != OK:
		push_error("Falha ao salvar %s: %s" % [path, error_string(err)])
		return false
	print("Gerado: %s (%.2f s)" % [path, float(_buf.size()) / RATE])
	return true


# --- Efeitos sonoros -------------------------------------------------------------------------------

const SFX := ["hit", "crit", "miss", "spell", "heal", "down", "dissolve", "death_save", "step", "click", "open",
		"coin", "level_up", "victory", "defeat", "potion", "quest"]


func _sfx_hit() -> void:
	_hiss(0.0, 0.11, 0.55, 0.9, 0.001, 0.08, 3, 0.1)
	_tone(0.0, 0.12, 160.0, 70.0, "square", 0.45, 0.001, 0.08, 0.3)


func _sfx_crit() -> void:
	_sfx_hit()
	_tone(0.02, 0.28, 880.0, 1320.0, "square", 0.25, 0.002, 0.2, 0.25)
	_tone(0.06, 0.24, 1320.0, 1760.0, "tri", 0.2, 0.002, 0.18)


func _sfx_miss() -> void:
	_hiss(0.0, 0.24, 0.05, 0.7, 0.08, 0.14, 5, 0.6)


func _sfx_spell() -> void:
	var notes := [72, 76, 79, 84, 88, 91]
	for i in notes.size():
		_tone(i * 0.045, 0.22, _midi(notes[i]), _midi(notes[i]), "tri", 0.35, 0.004, 0.16)
	_hiss(0.0, 0.32, 0.9, 0.08, 0.05, 0.2, 9)


func _sfx_heal() -> void:
	for i in 3:
		var n: int = [84, 88, 91][i]
		_tone(i * 0.08, 0.42, _midi(n), _midi(n), "sine", 0.4, 0.01, 0.3)
		_tone(i * 0.08, 0.42, _midi(n + 12), _midi(n + 12), "sine", 0.1, 0.01, 0.3)


func _sfx_down() -> void:
	_tone(0.0, 0.36, 170.0, 55.0, "square", 0.5, 0.002, 0.2, 0.4)
	_hiss(0.03, 0.2, 0.2, 0.5, 0.002, 0.15, 11)


func _sfx_dissolve() -> void:
	_hiss(0.0, 0.55, 0.9, 0.5, 0.01, 0.4, 13, 0.08)
	_tone(0.0, 0.5, 600.0, 180.0, "tri", 0.2, 0.01, 0.35)


func _sfx_death_save() -> void:
	_tone(0.0, 0.12, 70.0, 50.0, "sine", 0.9, 0.003, 0.08)
	_tone(0.18, 0.12, 70.0, 50.0, "sine", 0.7, 0.003, 0.08)


func _sfx_step() -> void:
	_hiss(0.0, 0.045, 0.25, 0.6, 0.002, 0.035, 17)


## Clique suave: triângulo grave e curto, sem a aspereza da onda quadrada.
func _sfx_click() -> void:
	_tone(0.0, 0.05, 520.0, 440.0, "tri", 0.35, 0.004, 0.04)
	_tone(0.0, 0.05, 1040.0, 880.0, "sine", 0.06, 0.004, 0.04)


func _sfx_open() -> void:
	_tone(0.0, 0.06, 660.0, 660.0, "square", 0.3, 0.001, 0.02, 0.35)
	_tone(0.06, 0.08, 990.0, 990.0, "square", 0.3, 0.001, 0.04, 0.35)


func _sfx_coin() -> void:
	_tone(0.0, 0.06, 1568.0, 1568.0, "square", 0.3, 0.001, 0.02, 0.5)
	_tone(0.06, 0.2, 2093.0, 2093.0, "square", 0.3, 0.001, 0.15, 0.5)


func _sfx_level_up() -> void:
	var notes := [72, 76, 79, 84]
	for i in notes.size():
		_tone(i * 0.09, 0.3 if i < 3 else 0.6, _midi(notes[i]), _midi(notes[i]), "square", 0.3, 0.003, 0.15, 0.5)
		_tone(i * 0.09, 0.3 if i < 3 else 0.6, _midi(notes[i] - 12), _midi(notes[i] - 12), "tri", 0.25, 0.003, 0.15)


func _sfx_victory() -> void:
	var notes := [67, 72, 76, 79]
	var times := [0.0, 0.12, 0.24, 0.36]
	for i in notes.size():
		var d := 0.14 if i < 3 else 0.7
		_tone(times[i], d, _midi(notes[i]), _midi(notes[i]), "square", 0.3, 0.003, 0.1, 0.5)
		_tone(times[i], d, _midi(notes[i] - 24), _midi(notes[i] - 24), "tri", 0.3, 0.003, 0.1)


func _sfx_defeat() -> void:
	var notes := [69, 67, 64, 57]
	for i in notes.size():
		var d := 0.28 if i < 3 else 0.9
		_tone(i * 0.28, d, _midi(notes[i]), _midi(notes[i]), "square", 0.28, 0.005, 0.2, 0.5)
		_tone(i * 0.28, d, _midi(notes[i] - 12), _midi(notes[i] - 12), "tri", 0.3, 0.005, 0.2)


func _sfx_potion() -> void:
	for i in 5:
		var f := 400.0 + 120.0 * i
		_tone(i * 0.05, 0.06, f, f * 1.4, "sine", 0.4, 0.004, 0.04)


func _sfx_quest() -> void:
	var notes := [79, 84, 88]
	for i in notes.size():
		_tone(i * 0.1, 0.5 if i == 2 else 0.2, _midi(notes[i]), _midi(notes[i]), "tri", 0.4, 0.004, 0.2)


# --- Músicas ---------------------------------------------------------------------------------------
# Cada música: andamento, compassos (4 tempos), acordes (nota-raiz MIDI e tipo), escala da melodia, timbres e
# bateria. A melodia sai das notas da escala, escolhidas de forma determinística (hash), para soar composta.

const MUSIC := {
	"title": {"bpm": 76, "chords": [[60, "maj7"], [57, "m7"], [53, "maj7"], [55, "sus"], [60, "maj7"], [57, "m7"],
			[53, "maj7"], [55, "maj"]], "scale": [0, 2, 4, 7, 9], "lead": "tri", "density": 0.45, "drums": "none",
			"arp": true, "seed": 3},
	"village": {"bpm": 100, "chords": [[60, "maj"], [57, "min"], [53, "maj"], [55, "maj"], [60, "maj"], [57, "min"],
			[50, "min"], [55, "maj"]], "scale": [0, 2, 4, 5, 7, 9], "lead": "square", "density": 0.65, "drums": "light",
			"arp": false, "seed": 7},
	"forest": {"bpm": 72, "chords": [[62, "min"], [60, "maj"], [58, "maj"], [60, "maj"], [62, "min"], [65, "maj"],
			[58, "maj"], [57, "min"]], "scale": [0, 2, 3, 5, 7, 9, 10], "lead": "tri", "density": 0.35, "drums": "none",
			"arp": true, "seed": 11},
	"combat": {"bpm": 140, "chords": [[57, "min"], [53, "maj"], [55, "maj"], [52, "maj"], [57, "min"], [53, "maj"],
			[50, "min"], [52, "maj"], [57, "min"], [53, "maj"], [55, "maj"], [52, "maj"], [57, "min"], [55, "maj"],
			[53, "maj"], [52, "maj"]], "scale": [0, 2, 3, 5, 7, 8, 11], "lead": "square", "density": 0.8,
			"drums": "full", "arp": false, "seed": 19},
}
const CHORD_TONES := {"maj": [0, 4, 7], "min": [0, 3, 7], "maj7": [0, 4, 7, 11], "m7": [0, 3, 7, 10], "sus": [0, 5, 7]}


func _compose(song: Dictionary) -> void:
	var beat := 60.0 / float(song["bpm"])
	var bar := beat * 4.0
	var chords: Array = song["chords"]
	var key_root := int(chords[0][0])
	var scale: Array = song["scale"]
	var seed := int(song["seed"])
	var total := bar * chords.size()
	_ensure(int(total * RATE) + 1)
	for b in chords.size():
		var start := b * bar
		var root := int(chords[b][0])
		var tones: Array = CHORD_TONES[chords[b][1]]
		# Baixo: raiz no tempo 1 e 3 (combate: colcheias).
		var bass_steps := 8 if song["drums"] == "full" else 2
		for k in bass_steps:
			var d := bar / bass_steps
			var note := root - 12 if k % 2 == 0 or bass_steps == 2 else root - 5
			_tone(start + k * d, d * 0.95, _midi(note), _midi(note), "tri", 0.5, 0.005, 0.04)
		# Acompanhamento: arpejo em colcheias ou acorde sustentado e suave.
		if song["arp"]:
			for k in 8:
				var n := root + int(tones[k % tones.size()]) + (12 if k >= 4 else 0)
				_tone(start + k * beat / 2.0, beat / 2.0 * 0.9, _midi(n), _midi(n), "sine", 0.13, 0.01, 0.08)
		else:
			for t: int in tones:
				_tone(start, bar * 0.98, _midi(root + t), _midi(root + t), "square", 0.045, 0.03, 0.2, 0.25)
		# Melodia: colcheias da escala, presas às notas do acorde no tempo forte.
		var prev := 0
		for k in 8:
			var r := (_noise(b * 97 + k * 13, seed) + 1.0) / 2.0
			if r > float(song["density"]) and k % 2 == 1:
				continue
			var degree: int
			if k % 4 == 0:
				degree = (root - key_root + int(tones[int(r * tones.size()) % tones.size()]) + 24) % 12
			else:
				var step := int(r * 5.0) - 2
				var idx := clampi(scale.find(prev) + step, 0, scale.size() - 1) if scale.has(prev) else int(r * scale.size())
				degree = int(scale[idx])
			prev = degree
			var len_steps := 2 if (k % 2 == 0 and r < 0.35) else 1
			var note := key_root + 12 + degree
			_tone(start + k * beat / 2.0, beat / 2.0 * len_steps * 0.92, _midi(note), _midi(note), str(song["lead"]),
					0.22, 0.008, 0.06, 0.5)
		# Bateria.
		if song["drums"] != "none":
			for k in 8:
				var tt := start + k * beat / 2.0
				_hiss(tt, 0.03, 0.9, 0.12 if song["drums"] == "full" else 0.07, 0.001, 0.025, 23 + k)
				if song["drums"] == "full":
					if k % 4 == 0:
						_tone(tt, 0.12, 120.0, 45.0, "sine", 0.8, 0.001, 0.08)
					if k % 4 == 2:
						_hiss(tt, 0.12, 0.5, 0.35, 0.001, 0.09, 29)
	# Recorta no tamanho exato do laço, para a volta ao início não estalar.
	_buf.resize(int(total * RATE))
