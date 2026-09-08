extends Node
## Owns audio playback and cancellable scene crossfades.
const FADE_SECONDS := 1.2
const AMBIENT_GAIN := 0.2511886 # -12 dB, interpolated in linear amplitude.
var players: Array[AudioStreamPlayer] = []
const TOUCH := preload("res://assets/touch_soft.wav")
const BUBBLE := preload("res://assets/bubble_soft.wav")
const CONFIRM := preload("res://assets/confirm_soft.wav")
var voices: Array[AudioStreamPlayer] = []
var rubber: AudioStreamPlayer
var wet: AudioStreamPlayer
var fade: Tween
var audible := false

func _ready():
	for i in 3:
		var player := AudioStreamPlayer.new()
		player.stream = load("res://assets/ambient_%d.wav" % i)
		player.volume_linear = 0.0
		add_child(player)
		players.append(player)
	for i in 3:
		var voice := AudioStreamPlayer.new()
		add_child(voice)
		voices.append(voice)
	rubber = AudioStreamPlayer.new()
	var rubbing: AudioStreamWAV = load("res://assets/balloon_recorded.wav").duplicate()
	rubbing.loop_mode = AudioStreamWAV.LOOP_FORWARD
	rubbing.loop_begin = 0
	rubbing.loop_end = roundi(rubbing.get_length() * rubbing.mix_rate)
	rubber.stream = rubbing
	rubber.volume_linear = 0.0
	add_child(rubber)
	wet = AudioStreamPlayer.new()
	var slime: AudioStreamWAV = load("res://assets/slime_recorded.wav").duplicate()
	slime.loop_mode = AudioStreamWAV.LOOP_FORWARD
	slime.loop_end = roundi(slime.get_length() * slime.mix_rate)
	wet.stream = slime
	wet.volume_linear = 0.0
	add_child(wet)

func select(index: int, enabled: bool, focused: bool):
	index = 2 # One continuous public-domain music box in every destination.
	audible = enabled and focused
	if fade:
		fade.kill()
	if not audible:
		# Focus loss and mute take effect immediately, including an active effect.
		for voice in voices:
			voice.stop()
		rubber.volume_linear = 0.0
		rubber.stream_paused = true
		wet.volume_linear = 0.0
		wet.stream_paused = true
		for player in players:
			player.volume_linear = 0.0
			player.stream_paused = true
		return
	fade = create_tween().set_parallel(true)
	for i in players.size():
		var player := players[i]
		if i == index:
			if not player.playing:
				player.play()
			player.stream_paused = false
		fade.tween_property(player, "volume_linear", AMBIENT_GAIN if i == index else 0.0, FADE_SECONDS)
	fade.chain().tween_callback(_pause_inactive.bind(index))

func _pause_inactive(index: int):
	for i in players.size():
		players[i].stream_paused = i != index

func play_touch(pitch: float):
	_play_effect(TOUCH, clampf(pitch, 0.9, 1.1), -14.0)

func play_bubble():
	_play_effect(BUBBLE, 1.0, -17.0)

func play_pop():
	_play_effect(BUBBLE, 1.35, -25.0)

func play_confirm():
	_play_effect(CONFIRM, 1.0, -20.0)

func update_rubbing(delta: float, pressure: float, motion: float, balloon: bool):
	var intensity := clampf(pressure, 0, 1) * (0.15 + clampf(motion, 0, 0.85)) if audible and pressure > 0.025 else 0.0
	for player in [rubber, wet]:
		var weight := (0.40 if balloon else 0.12) if player == rubber else (0.15 if balloon else 0.38)
		var target: float = intensity * weight
		if target > 0.0:
			if not player.playing:
				player.play()
			player.stream_paused = false
		player.pitch_scale = (0.74 if player == rubber else 0.82) + clampf(pressure, 0, 1) * 0.10
		player.volume_linear = lerpf(player.volume_linear, target, 1.0 - exp(-delta * 9.0))
		if target == 0.0 and player.volume_linear < 0.0005:
			player.volume_linear = 0.0
			player.stream_paused = true

func _play_effect(stream: AudioStream, pitch: float, gain_db: float):
	if not audible:
		return
	# Let each rounded release finish. A busy pool skips a sound instead of cutting it.
	for voice in voices:
		if not voice.playing:
			voice.stream = stream
			voice.pitch_scale = pitch
			voice.volume_db = gain_db
			voice.play()
			return

func effects_playing() -> bool:
	for voice in voices:
		if voice.playing:
			return true
	return false

func shutdown():
	if fade:
		fade.kill()
	for player in players:
		player.stream_paused = false
		player.stop()
		player.stream = null
	for voice in voices:
		voice.stop()
		voice.stream = null
	rubber.stream_paused = false
	rubber.stop()
	rubber.stream = null
	wet.stream_paused = false
	wet.stop()
	wet.stream = null

func _exit_tree():
	shutdown()
