extends Node
## Original, cached PCM cues. Independent RNG, bounded voices and wall-clock
## cooldowns keep dense fights quiet without changing the simulation's RNG.
const SAMPLE_RATE: int = 22050
const MAX_VOICES: int = 12
const AMBIENT_VOICES: int = 8
# Notes (Hz), duration, noise blend, gain (dB), cooldown, priority.
const CUES: Dictionary = {
	&"ui_hover": [[720.0], 0.045, 0.0, -19.0, 0.10, 0],
	&"ui_click": [[420.0, 620.0], 0.085, 0.0, -13.0, 0.075, 1],
	&"purchase": [[523.25, 783.99], 0.19, 0.0, -9.0, 0.10, 2],
	&"failed": [[174.61, 146.83], 0.20, 0.03, -10.0, 0.25, 2],
	&"deposit": [[880.0, 1174.66], 0.13, 0.025, -16.0, 0.48, 0],
	&"melee": [[180.0], 0.095, 0.42, -13.0, 0.09, 0],
	&"ranged": [[720.0], 0.13, 0.12, -16.0, 0.13, 0],
	&"tank": [[85.0], 0.24, 0.24, -9.0, 0.19, 1],
	&"tower_fire": [[160.0], 0.21, 0.22, -12.0, 0.17, 1],
	&"tower_build": [[261.63, 392.0, 523.25], 0.36, 0.10, -10.0, 0.20, 2],
	&"tower_upgrade": [[392.0, 523.25, 783.99], 0.38, 0.015, -9.0, 0.20, 2],
	&"tower_destroy": [[110.0, 73.42], 0.43, 0.34, -8.0, 0.25, 2],
	&"commander_death": [[392.0, 293.66, 196.0], 0.48, 0.015, -8.0, 0.50, 3],
	&"respawn": [[392.0, 523.25, 783.99], 0.45, 0.0, -8.0, 0.50, 3],
	&"king_warning": [[440.0, 0.0, 440.0, 0.0, 349.23], 0.65, 0.0, -7.0, 5.0, 4],
	&"king_death": [[196.0, 146.83, 98.0], 0.80, 0.10, -6.0, 1.0, 4],
	&"victory": [[392.0, 523.25, 659.25, 783.99], 0.95, 0.0, -7.0, 1.0, 4],
	&"defeat": [[329.63, 293.66, 220.0, 164.81], 0.95, 0.0, -7.0, 1.0, 4],
	&"route": [[392.0, 523.25], 0.14, 0.0, -13.0, 0.10, 1],
}
const COMBAT_CUES: Array[StringName] = [&"melee", &"ranged", &"tank", &"tower_fire"]
var streams: Dictionary = {}
var voices: Array[AudioStreamPlayer] = []
var last_played: Dictionary = {}
var last_combat_time: float = -1.0
var variation := RandomNumberGenerator.new()
var synthesis_microseconds: int = 0
var played_count: int = 0
var suppressed_count: int = 0
var playback_generation: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	variation.seed = 894317
	var start: int = Time.get_ticks_usec()
	for event in CUES:
		streams[event] = _synthesize(event, CUES[event])
	synthesis_microseconds = Time.get_ticks_usec() - start
	for index in range(MAX_VOICES):
		var voice := AudioStreamPlayer.new()
		voice.bus = "SFX"
		voice.set_meta("priority", -1)
		add_child(voice)
		voices.append(voice)


func _synthesize(event: StringName, cue: Array) -> AudioStreamWAV:
	var notes: Array = cue[0]
	var duration: float = cue[1]
	var count: int = ceili(duration * SAMPLE_RATE)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	var oscillator: float = 0.0
	var filtered_noise: float = 0.0
	var noise := RandomNumberGenerator.new()
	noise.seed = hash(event)
	for index in range(count):
		var seconds: float = float(index) / SAMPLE_RATE
		var note_duration: float = duration / notes.size()
		var note_index: int = mini(int(seconds / note_duration), notes.size() - 1)
		var note_time: float = fmod(seconds, note_duration)
		var frequency: float = notes[note_index]
		if event in COMBAT_CUES or event == &"tower_destroy":
			frequency *= 1.0 - 0.55 * seconds / duration
		oscillator += TAU * frequency / SAMPLE_RATE
		var envelope: float = minf(note_time / 0.006, 1.0) * pow(maxf(0.0, 1.0 - note_time / note_duration), 1.4)
		var tone: float = sin(oscillator) * 0.78 + sin(oscillator * 2.0) * 0.16 + sin(oscillator * 3.0) * 0.06
		filtered_noise = lerpf(filtered_noise, noise.randf_range(-1.0, 1.0), 0.34)
		var sample: float = (tone * (1.0 - float(cue[2])) + filtered_noise * float(cue[2])) * envelope * 0.6
		if frequency == 0.0:
			sample = 0.0
		bytes.encode_s16(index * 2, clampi(roundi(sample * 32767.0), -32768, 32767))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = bytes
	return stream


func play(event: StringName, world_position: Vector2 = Vector2.INF) -> bool:
	if not CUES.has(event) or not streams.has(event):
		return false
	var cue: Array = CUES[event]
	var now: float = Time.get_ticks_msec() / 1000.0
	var combat: bool = event in COMBAT_CUES
	if now - float(last_played.get(event, -100.0)) < float(cue[4]) or (combat and now - last_combat_time < 0.065):
		suppressed_count += 1
		return false
	var gain: float = _distance_gain(world_position)
	if gain <= 0.01:
		suppressed_count += 1
		return false
	var priority: int = cue[5]
	var selected: AudioStreamPlayer = null
	var lowest_priority: int = priority
	# Four reserved voices let warnings/results remain audible over ordinary combat.
	for index in range(MAX_VOICES if priority >= 3 else AMBIENT_VOICES):
		var voice: AudioStreamPlayer = voices[index]
		if not voice.playing and not voice.get_meta("pending", false):
			selected = voice
			break
		if priority >= 3 and int(voice.get_meta("priority")) < lowest_priority:
			selected = voice
			lowest_priority = int(voice.get_meta("priority"))
	if selected == null:
		suppressed_count += 1
		return false
	selected.stop()
	var voice_generation: int = int(selected.get_meta("start_generation", 0)) + 1
	selected.set_meta("start_generation", voice_generation)
	selected.stream = streams[event]
	selected.volume_db = float(cue[3]) + linear_to_db(gain)
	selected.pitch_scale = variation.randf_range(0.96, 1.04) if priority < 3 else 1.0
	selected.set_meta("priority", priority)
	# Starts scheduled earlier in this frame must not survive stop/restart/quit.
	# In particular, rapid play/stop with a headless audio driver can otherwise
	# leave mixer-owned WAV playback references alive during engine shutdown.
	selected.set_meta("pending", true)
	_start_voice.call_deferred(selected, playback_generation, voice_generation)
	last_played[event] = now
	if combat:
		last_combat_time = now
	played_count += 1
	return true

func _start_voice(voice: AudioStreamPlayer, generation: int, voice_generation: int) -> void:
	if generation != playback_generation or not is_instance_valid(voice) or not is_inside_tree():
		return
	if int(voice.get_meta("start_generation", -1)) != voice_generation:
		return
	voice.set_meta("pending", false)
	voice.play()


func _distance_gain(point: Vector2) -> float:
	if not point.is_finite():
		return 1.0
	var camera: Camera2D = get_viewport().get_camera_2d()
	if camera == null:
		return 1.0
	var distance: float = camera.get_screen_center_position().distance_to(point)
	return clampf(1.0 - maxf(0.0, distance - 320.0) / 900.0, 0.0, 1.0)


func bind_button(button: BaseButton) -> void:
	button.mouse_entered.connect(func():
		if not button.disabled:
			play(&"ui_hover")
	)
	button.pressed.connect(func(): play(&"ui_click"))


func stop_all() -> void:
	playback_generation += 1
	for voice in voices:
		voice.set_meta("pending", false)
		if voice.has_stream_playback():
			voice.get_stream_playback().stop()
		voice.stop()
		voice.stream = null
	last_played.clear()
	last_combat_time = -1.0


func _exit_tree() -> void:
	# Release mixer playback references before the scene tree destroys the pool.
	# This also avoids queued result cues surviving an immediate application quit.
	stop_all()
	streams.clear()


func active_voice_count() -> int:
	var count: int = 0
	for voice in voices:
		if voice.playing:
			count += 1
	return count
