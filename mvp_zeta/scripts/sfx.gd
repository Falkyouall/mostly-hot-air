extends Node
# Autoload. All sounds are synthesised at startup — the prototype ships no
# audio assets. One-shots via play(); burner and wind are loops with a volume.

const RATE := 22050

var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _burner: AudioStreamPlayer
var _wind: AudioStreamPlayer
var _burner_target := 0.0


func _ready() -> void:
	_streams["pickup"] = _tones([[520.0, 0.05], [780.0, 0.07]], 0.35)
	_streams["throw"] = _sweep(500.0, 180.0, 0.22, 0.3)
	_streams["refuel"] = _tones([[300.0, 0.08], [380.0, 0.08], [460.0, 0.12]], 0.35)
	_streams["deliver"] = _tones([[523.0, 0.1], [659.0, 0.1], [784.0, 0.1], [1047.0, 0.28]], 0.4)
	_streams["bullseye"] = _tones([[659.0, 0.08], [784.0, 0.08], [1047.0, 0.08], [1319.0, 0.08], [1568.0, 0.35]], 0.4)
	_streams["miss"] = _tones([[300.0, 0.15], [220.0, 0.3]], 0.35)
	_streams["hit"] = _noise_burst(0.45, 0.6)
	_streams["win"] = _tones([[523.0, 0.14], [659.0, 0.14], [784.0, 0.14], [1047.0, 0.14], [784.0, 0.14], [1047.0, 0.5]], 0.4)
	_streams["lose"] = _tones([[392.0, 0.25], [330.0, 0.25], [262.0, 0.6]], 0.4)
	for i in 6:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_burner = _loop_player(_noise_loop(1.5, 0.22), -60.0)
	_wind = _loop_player(_noise_loop(3.0, 0.04), -24.0)


func play(id: String) -> void:
	for p in _players:
		if not p.playing:
			p.stream = _streams[id]
			p.play()
			return


func set_burner(on: bool) -> void:
	_burner_target = 1.0 if on else 0.0


func _process(delta: float) -> void:
	var cur := db_to_linear(_burner.volume_db)
	cur = lerpf(cur, _burner_target, 1.0 - exp(-14.0 * delta))
	_burner.volume_db = linear_to_db(maxf(cur, 0.001))


func _loop_player(stream: AudioStreamWAV, volume_db: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = volume_db
	add_child(p)
	p.play()
	return p


func _wav(samples: PackedFloat32Array, looped := false) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.data = bytes
	if looped:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_end = samples.size()
	return wav


func _tones(notes: Array, gain: float) -> AudioStreamWAV:
	var out := PackedFloat32Array()
	for note in notes:
		var n := int(note[1] * RATE)
		for i in n:
			var t := float(i) / RATE
			var env := minf(t * 200.0, 1.0) * pow(1.0 - float(i) / n, 1.5)
			var s := sin(TAU * note[0] * t) + 0.3 * sin(TAU * note[0] * 2.0 * t)
			out.append(s * env * gain)
	return _wav(out)


func _sweep(f0: float, f1: float, dur: float, gain: float) -> AudioStreamWAV:
	var out := PackedFloat32Array()
	var n := int(dur * RATE)
	var phase := 0.0
	for i in n:
		var k := float(i) / n
		phase += TAU * lerpf(f0, f1, k) / RATE
		out.append(sin(phase) * (1.0 - k) * gain)
	return _wav(out)


func _noise_burst(dur: float, gain: float) -> AudioStreamWAV:
	var out := PackedFloat32Array()
	var n := int(dur * RATE)
	var lp := 0.0
	for i in n:
		lp = lerpf(lp, randf_range(-1.0, 1.0), 0.12)
		out.append(lp * pow(1.0 - float(i) / n, 2.0) * gain * 3.0)
	return _wav(out)


# Low-passed noise, cross-faded at the seam so the loop does not click.
func _noise_loop(dur: float, cutoff: float) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var fade := int(0.2 * RATE)
	var raw := PackedFloat32Array()
	var lp := 0.0
	for i in n + fade:
		lp = lerpf(lp, randf_range(-1.0, 1.0), cutoff)
		raw.append(lp * 2.5)
	var out := PackedFloat32Array()
	for i in n:
		var s := raw[i]
		if i < fade:
			var k := float(i) / fade
			s = raw[i] * k + raw[n + i] * (1.0 - k)
		out.append(s)
	return _wav(out, true)
