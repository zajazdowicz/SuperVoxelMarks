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

# Mute
var muted := false


func _ready() -> void:
	for i in range(POOL_SIZE):
		var p := AudioStreamPlayer.new()
		p.bus = BUS_SFX
		add_child(p)
		_pool.append(p)


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


func stop_engine() -> void:
	if _engine_3d and is_instance_valid(_engine_3d):
		_engine_3d.stop()
		_engine_3d.queue_free()
	_engine_3d = null
	_engine_target = null


func update_engine(speed_ratio: float, is_boosting: bool = false) -> void:
	_engine_target_speed_ratio = clampf(speed_ratio, 0.0, 1.5)
	if is_boosting:
		_engine_target_speed_ratio = maxf(_engine_target_speed_ratio, 1.3)


func _process(delta: float) -> void:
	if not _engine_3d or not is_instance_valid(_engine_3d):
		return
	# Pitch: 0.55 (idle) to 1.8 (full boost)
	var target_pitch := lerpf(0.55, 1.8, _engine_target_speed_ratio / 1.5)
	_engine_current_pitch = lerpf(_engine_current_pitch, target_pitch, 5.0 * delta)
	_engine_3d.pitch_scale = _engine_current_pitch


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
