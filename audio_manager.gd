extends Node
## AudioManager — central SFX registry + pooled playback + 3D engine loop.
## Autoload as "Audio".

# --- SFX paths ---
const SFX := {
	"ui_click":      preload("res://assets/audio/ui_click.ogg"),
	"ui_hover":      preload("res://assets/audio/ui_hover.ogg"),
	"countdown":     preload("res://assets/audio/countdown_beep.ogg"),
	"countdown_go":  preload("res://assets/audio/countdown_go.ogg"),
	"checkpoint":    preload("res://assets/audio/checkpoint.ogg"),
	"crash":         preload("res://assets/audio/crash.ogg"),
	"explosion":     preload("res://assets/audio/explosion.ogg"),
	"boost_kick":    preload("res://assets/audio/boost_kick.ogg"),
	"boost_whoosh":  preload("res://assets/audio/boost_whoosh.ogg"),
	"finish":        preload("res://assets/audio/finish_fanfare.ogg"),
}
const ENGINE_STREAM := preload("res://assets/audio/engine_loop.ogg")

# --- Buses ---
const BUS_SFX := "Master"
const BUS_MUSIC := "Master"

# --- Pool config ---
const POOL_SIZE := 12

var _pool: Array[AudioStreamPlayer] = []
var _pool_idx := 0

# 3D engine attached to player car
var _engine_3d: AudioStreamPlayer3D
var _engine_target: Node3D
var _engine_target_speed_ratio := 0.0
var _engine_current_pitch := 1.0

# 3D screech loop (drift/hard brake)
var _screech_3d: AudioStreamPlayer3D
var _screech_active := false
var _screech_volume_current := -40.0
var _screech_volume_target := -40.0

# Procedural SFX generated once at _ready
var _screech_stream: AudioStreamWAV
var _brake_stream: AudioStreamWAV

# Mute
var muted := false


func _ready() -> void:
	for i in range(POOL_SIZE):
		var p := AudioStreamPlayer.new()
		p.bus = BUS_SFX
		add_child(p)
		_pool.append(p)
	_screech_stream = _make_screech_stream()
	_brake_stream = _make_brake_stream()


# =============================================================================
# PROCEDURAL SFX SYNTHESIS
# =============================================================================

func _make_screech_stream() -> AudioStreamWAV:
	# Tire squeal: bandpass-filtered noise, formant modulation, ~0.6s loop
	var sr := 22050
	var dur := 0.6
	var n := int(sr * dur)
	var buf := PackedByteArray()
	buf.resize(n * 2)

	# Two-pole resonant filter state
	var x1 := 0.0
	var x2 := 0.0
	var y1 := 0.0
	var y2 := 0.0
	var wobble_phase := 0.0
	for i in range(n):
		# Slight LFO wobble on filter frequency 1800-2600 Hz
		wobble_phase += 22.0 / sr
		var f_center := 2200.0 + sin(wobble_phase * TAU) * 400.0 + sin(wobble_phase * TAU * 1.7) * 150.0
		# Biquad bandpass coefficients
		var w := TAU * f_center / sr
		var q := 8.0
		var alpha := sin(w) / (2.0 * q)
		var cosw := cos(w)
		var b0 := alpha
		var b2 := -alpha
		var a0 := 1.0 + alpha
		var a1 := -2.0 * cosw
		var a2 := 1.0 - alpha
		# White noise input
		var x0 := randf_range(-1.0, 1.0)
		var y0 := (b0 * x0 + b2 * x2 - a1 * y1 - a2 * y2) / a0
		x2 = x1
		x1 = x0
		y2 = y1
		y1 = y0
		var sample := y0 * 0.6
		var s16 := int(clampf(sample, -1.0, 1.0) * 32767.0)
		if s16 < 0:
			s16 += 65536
		buf[i * 2] = s16 & 0xff
		buf[i * 2 + 1] = (s16 >> 8) & 0xff

	var stream := AudioStreamWAV.new()
	stream.data = buf
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sr
	stream.stereo = false
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = n
	return stream


func _make_brake_stream() -> AudioStreamWAV:
	# Brake hiss: noise with lowpass sweep from bright to dark, ~0.25s one-shot
	var sr := 22050
	var dur := 0.3
	var n := int(sr * dur)
	var buf := PackedByteArray()
	buf.resize(n * 2)
	var prev := 0.0
	for i in range(n):
		var t := float(i) / float(sr)
		var env := exp(-t * 12.0)
		# Lowpass: one-pole, coefficient rising (becoming darker)
		var coef := lerpf(0.85, 0.15, t / dur)
		var noise := randf_range(-1.0, 1.0)
		prev = prev * coef + noise * (1.0 - coef)
		var sample := prev * 0.55 * env
		var s16 := int(clampf(sample, -1.0, 1.0) * 32767.0)
		if s16 < 0:
			s16 += 65536
		buf[i * 2] = s16 & 0xff
		buf[i * 2 + 1] = (s16 >> 8) & 0xff

	var stream := AudioStreamWAV.new()
	stream.data = buf
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sr
	stream.stereo = false
	return stream


func play(name: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if muted:
		return
	if not SFX.has(name):
		push_warning("Audio: unknown sfx '%s'" % name)
		return
	var p := _pool[_pool_idx]
	_pool_idx = (_pool_idx + 1) % POOL_SIZE
	p.stream = SFX[name]
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.play()


func play_random_pitch(name: String, volume_db: float = 0.0, pitch_range: Vector2 = Vector2(0.9, 1.1)) -> void:
	play(name, volume_db, randf_range(pitch_range.x, pitch_range.y))


# =============================================================================
# ENGINE LOOP — 3D positional, pitched by speed
# =============================================================================

func start_engine(target: Node3D) -> void:
	stop_engine()
	_engine_target = target
	_engine_3d = AudioStreamPlayer3D.new()
	var stream := ENGINE_STREAM.duplicate() as AudioStream
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	_engine_3d.stream = stream
	_engine_3d.bus = BUS_SFX
	_engine_3d.volume_db = -6.0
	_engine_3d.unit_size = 15.0
	_engine_3d.max_distance = 80.0
	_engine_3d.autoplay = false

	target.add_child(_engine_3d)
	_engine_3d.play()

	# Screech loop (silent until triggered)
	_screech_3d = AudioStreamPlayer3D.new()
	_screech_3d.stream = _screech_stream
	_screech_3d.bus = BUS_SFX
	_screech_3d.volume_db = -40.0
	_screech_3d.unit_size = 12.0
	_screech_3d.max_distance = 60.0
	target.add_child(_screech_3d)
	_screech_3d.play()
	_screech_active = false
	_screech_volume_current = -40.0
	_screech_volume_target = -40.0


func stop_engine() -> void:
	if _engine_3d and is_instance_valid(_engine_3d):
		_engine_3d.stop()
		_engine_3d.queue_free()
	if _screech_3d and is_instance_valid(_screech_3d):
		_screech_3d.stop()
		_screech_3d.queue_free()
	_engine_3d = null
	_screech_3d = null
	_engine_target = null
	_screech_active = false


func update_engine(speed_ratio: float, is_boosting: bool = false) -> void:
	_engine_target_speed_ratio = clampf(speed_ratio, 0.0, 1.5)
	if is_boosting:
		_engine_target_speed_ratio = maxf(_engine_target_speed_ratio, 1.3)


func _process(delta: float) -> void:
	if _engine_3d and is_instance_valid(_engine_3d):
		# Pitch: 0.55 (idle) to 1.8 (full boost)
		var target_pitch := lerpf(0.55, 1.8, _engine_target_speed_ratio / 1.5)
		_engine_current_pitch = lerpf(_engine_current_pitch, target_pitch, 5.0 * delta)
		_engine_3d.pitch_scale = _engine_current_pitch

	# Screech fade in/out
	if _screech_3d and is_instance_valid(_screech_3d):
		_screech_volume_target = -8.0 if _screech_active else -40.0
		_screech_volume_current = lerpf(_screech_volume_current, _screech_volume_target, 10.0 * delta)
		_screech_3d.volume_db = _screech_volume_current
		# Pitch vary with speed — higher speed = higher pitch
		_screech_3d.pitch_scale = lerpf(0.85, 1.4, clampf(_engine_target_speed_ratio, 0.0, 1.2))


# =============================================================================
# HIGH-LEVEL GAME EVENTS
# =============================================================================

func on_countdown_tick() -> void:
	play("countdown", -4.0)


func on_countdown_go() -> void:
	play("countdown_go", -2.0)


func on_checkpoint() -> void:
	play("checkpoint", -2.0, randf_range(0.95, 1.05))


func on_crash(heavy: bool = false) -> void:
	if heavy:
		play("explosion", 0.0)
	else:
		play_random_pitch("crash", -4.0, Vector2(0.85, 1.15))


func on_boost_start() -> void:
	play("boost_kick", -3.0, randf_range(0.95, 1.1))


func on_boost_loop() -> void:
	# Continuous whoosh — fire-and-forget short loop
	play("boost_whoosh", -8.0)


func on_finish() -> void:
	play("finish", 0.0)


func on_ui_click() -> void:
	play_random_pitch("ui_click", -10.0, Vector2(0.95, 1.05))


func on_ui_hover() -> void:
	play("ui_hover", -14.0)


func set_screech(active: bool) -> void:
	_screech_active = active


func on_brake_hiss() -> void:
	# Play procedural brake on pool channel
	if muted or not _brake_stream:
		return
	var p := _pool[_pool_idx]
	_pool_idx = (_pool_idx + 1) % POOL_SIZE
	p.stream = _brake_stream
	p.volume_db = -6.0
	p.pitch_scale = randf_range(0.9, 1.1)
	p.play()
