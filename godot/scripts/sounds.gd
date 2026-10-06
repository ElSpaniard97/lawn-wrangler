class_name Sounds
extends Node
## Every sound in the game is synthesized here when the yard loads: short
## seamless loops for the engine, the mower blades, the weed eater and the
## rustle of grass being cut, plus a chime for finishing. No sound files are
## loaded. Loops fade in and out instead of starting and stopping.

const RATE := 22050
const FADE := 6.0
## Cells are cut in bursts as the blade crosses them, so the rustle holds
## on this long after the last cut instead of flickering.
const RUSTLE_HOLD := 0.25

var engine: AudioStreamPlayer
var blades: AudioStreamPlayer
var trimmer: AudioStreamPlayer
var rustle: AudioStreamPlayer
var chime_player: AudioStreamPlayer
## Target loudness (0..1) for each loop, eased towards in _process.
var targets := {}
var rustle_left := 0.0


func _ready() -> void:
	engine = _loop_player("Engine", _engine_wave())
	blades = _loop_player("Blades", _blades_wave())
	trimmer = _loop_player("Trimmer", _trimmer_wave())
	rustle = _loop_player("Rustle", _rustle_wave())
	chime_player = AudioStreamPlayer.new()
	chime_player.name = "Chime"
	chime_player.stream = _chime_wave()
	chime_player.volume_db = -6.0
	chime_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(chime_player)


## Called every frame by the yard with what the player is doing.
## `speed_ratio` is the current speed as a fraction of top speed. Once the
## run is over everything settles to the engine idling.
func update(on_mower: bool, speed_ratio: float, blades_on: bool, cutting: bool, running := true) -> void:
	if not running:
		on_mower = false
		speed_ratio = 0.0
	targets[engine] = (0.35 + 0.4 * speed_ratio) if on_mower else 0.12
	engine.pitch_scale = 0.85 + 0.5 * speed_ratio if on_mower else 0.8
	targets[blades] = 0.35 if on_mower and blades_on else 0.0
	targets[trimmer] = 0.4 if running and not on_mower else 0.0
	trimmer.pitch_scale = 1.0 + 0.15 * speed_ratio
	if cutting:
		rustle_left = RUSTLE_HOLD


func _process(delta: float) -> void:
	rustle_left = maxf(rustle_left - delta, 0.0)
	targets[rustle] = 0.5 if rustle_left > 0.0 else 0.0
	for player: AudioStreamPlayer in targets:
		player.volume_linear = move_toward(player.volume_linear, targets[player], FADE * delta)


func _exit_tree() -> void:
	# Stop playback now so the audio server releases the generated streams.
	for player in [engine, blades, trimmer, rustle, chime_player]:
		player.stop()


func chime() -> void:
	chime_player.play()


static func toggle_mute() -> bool:
	var muted := not AudioServer.is_bus_mute(0)
	AudioServer.set_bus_mute(0, muted)
	return muted


func _loop_player(player_name: String, wave: AudioStreamWAV) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = player_name
	player.stream = wave
	player.volume_linear = 0.0
	player.autoplay = true
	add_child(player)
	targets[player] = 0.0
	return player


## Packs samples (-1..1) into a 16-bit mono stream.
static func make_wave(samples: PackedFloat32Array, loop: bool) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var wave := AudioStreamWAV.new()
	wave.format = AudioStreamWAV.FORMAT_16_BITS
	wave.mix_rate = RATE
	wave.stereo = false
	wave.data = data
	if loop:
		wave.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wave.loop_begin = 0
		wave.loop_end = samples.size()
	return wave


## One-pole low-pass run over the loop twice so its end meets its start.
static func smooth(samples: PackedFloat32Array, amount: float) -> PackedFloat32Array:
	var state := 0.0
	for _pass in 2:
		for i in samples.size():
			state += (samples[i] - state) * amount
			if _pass == 1:
				samples[i] = state
	return samples


static func _saw(phase: float) -> float:
	return 2.0 * fposmod(phase, 1.0) - 1.0


## Low thumping engine: 50 Hz saw and harmonics, pulsing like cylinders firing.
## Every frequency is a whole number of Hz, so the one-second loop is seamless.
func _engine_wave() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var s := PackedFloat32Array()
	s.resize(RATE)
	for i in RATE:
		var t := float(i) / RATE
		var v := 0.5 * _saw(50.0 * t) + 0.3 * sin(TAU * 100.0 * t) + 0.15 * sin(TAU * 150.0 * t)
		v *= 0.65 + 0.35 * sin(TAU * 25.0 * t)
		s[i] = v + rng.randf_range(-0.15, 0.15)
	return make_wave(smooth(s, 0.18), true)


## Steady whir of the deck blades: soft hum over rushing air.
func _blades_wave() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2
	var s := PackedFloat32Array()
	s.resize(RATE)
	for i in RATE:
		var t := float(i) / RATE
		s[i] = 0.25 * sin(TAU * 120.0 * t) + 0.12 * sin(TAU * 240.0 * t) + rng.randf_range(-0.6, 0.6)
	return make_wave(smooth(s, 0.08), true)


## The weed eater's high buzzing whine.
func _trimmer_wave() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var s := PackedFloat32Array()
	s.resize(RATE)
	for i in RATE:
		var t := float(i) / RATE
		var v := 0.45 * _saw(190.0 * t) + 0.25 * _saw(380.0 * t) + rng.randf_range(-0.2, 0.2)
		s[i] = v * (0.75 + 0.25 * sin(TAU * 30.0 * t))
	return make_wave(smooth(s, 0.35), true)


## Crackly rustle of grass being chopped.
func _rustle_wave() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	var s := PackedFloat32Array()
	s.resize(RATE)
	for i in RATE:
		var crackle := rng.randf_range(-1.0, 1.0) if rng.randf() < 0.04 else 0.0
		s[i] = rng.randf_range(-0.4, 0.4) + crackle
	var low := smooth(s.duplicate(), 0.03)
	for i in RATE:
		s[i] = (s[i] - low[i]) * 0.6
	return make_wave(smooth(s, 0.5), true)


## A rising three-note chime (C, E, G) for finishing the lawn.
func _chime_wave() -> AudioStreamWAV:
	var length := int(RATE * 1.6)
	var s := PackedFloat32Array()
	s.resize(length)
	var notes := [523.25, 659.25, 783.99]
	for n in notes.size():
		var start := int(RATE * 0.16 * n)
		for i in range(start, length):
			var t := float(i - start) / RATE
			var env := exp(-t * 3.0) * minf(t * 200.0, 1.0)
			s[i] += 0.3 * env * (sin(TAU * notes[n] * t) + 0.3 * sin(TAU * notes[n] * 2.0 * t))
	return make_wave(s, false)
