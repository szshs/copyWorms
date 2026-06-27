# ============================================================
# MusicManager.gd - 全局音乐管理器 (Autoload)
#
# 设计:
#   - 单一主播放器 + 一个可选淡入播放器
#   - transition_id 防止旧 Tween 回调污染新切换
#   - LevelBase 通过 play_level_bgm(level_config) 播放配置 BGM
#   - 关卡脚本仅在阶段内换曲时调用 fade_to()
# ============================================================
extends Node

var _current_bgm_path: String = ""
var _base_volume_db: float = 0.0
var _transition_id: int = 0
var _fade_tween: Tween = null
var _paused_by_game: bool = false

var _primary_player: AudioStreamPlayer = null
var _fade_player: AudioStreamPlayer = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	EventBus.subscribe(GlobalDefine.EventName.GAME_PAUSE, self, "_on_game_pause")
	EventBus.subscribe(GlobalDefine.EventName.GAME_RESUME, self, "_on_game_resume")


func _on_game_pause(_data: Dictionary = {}) -> void:
	_paused_by_game = true
	_apply_pause_state()


func _on_game_resume(_data: Dictionary = {}) -> void:
	_paused_by_game = false
	_apply_pause_state()


func play_level_bgm(config: LevelConfig, from_position: float = 0.0) -> void:
	if not config:
		return
	if config.bgm_resource:
		play_bgm_from_stream(config.bgm_resource, from_position)
	elif config.bgm_path != "":
		play_bgm(config.bgm_path, from_position)


func play_bgm(stream_path: String, from_position: float = 0.0) -> void:
	var stream := _load_stream(stream_path)
	if not stream:
		return
	if _is_current_or_loaded(stream_path):
		return
	_transition_id += 1
	_kill_tween()
	_free_player(_fade_player)
	_fade_player = null
	_free_player(_primary_player)
	_primary_player = _make_player(stream, _base_volume_db)
	_primary_player.play(from_position)
	_current_bgm_path = stream_path
	_apply_pause_state()


func restart_bgm(stream_path: String, from_position: float = 0.0) -> void:
	var stream := _load_stream(stream_path)
	if not stream:
		return
	_transition_id += 1
	_kill_tween()
	_free_player(_fade_player)
	_fade_player = null
	_free_player(_primary_player)
	_primary_player = _make_player(stream, _base_volume_db)
	_primary_player.play(from_position)
	_current_bgm_path = stream_path
	_apply_pause_state()


func play_bgm_from_stream(stream: Resource, from_position: float = 0.0) -> void:
	var audio_stream := stream as AudioStream
	if not audio_stream:
		return
	var key := audio_stream.resource_path
	if key != "" and _is_current_or_loaded(key):
		return
	_transition_id += 1
	_kill_tween()
	_free_player(_fade_player)
	_fade_player = null
	_free_player(_primary_player)
	_primary_player = _make_player(audio_stream, _base_volume_db)
	_primary_player.play(from_position)
	_current_bgm_path = key
	_apply_pause_state()


func fade_to(stream_path: String, duration: float = 1.0, from_position: float = 0.0) -> void:
	var stream := _load_stream(stream_path)
	if not stream:
		stop_bgm(duration)
		return
	if _is_current(stream_path):
		return

	_transition_id += 1
	var id := _transition_id
	_kill_tween()
	_free_player(_fade_player)

	_fade_player = _make_player(stream, -80.0)
	_fade_player.play(from_position)
	_current_bgm_path = stream_path
	_apply_pause_state()

	if duration <= 0.0 or not _primary_player or not is_instance_valid(_primary_player):
		_promote_fade_player(id)
		return

	var old_player := _primary_player
	_fade_tween = create_tween().set_parallel(true)
	_fade_tween.tween_property(old_player, "volume_db", -80.0, duration).set_trans(Tween.TRANS_SINE)
	_fade_tween.tween_property(_fade_player, "volume_db", _base_volume_db, duration).set_trans(Tween.TRANS_SINE)
	_fade_tween.tween_callback(func():
		if id != _transition_id:
			return
		_promote_fade_player(id)
	).set_delay(duration)


func stop_bgm(fade_duration: float = 0.5) -> void:
	_transition_id += 1
	var id := _transition_id
	_kill_tween()
	_free_player(_fade_player)
	_fade_player = null

	if not _primary_player or not is_instance_valid(_primary_player):
		_current_bgm_path = ""
		return

	var player := _primary_player
	_primary_player = null
	_current_bgm_path = ""
	if fade_duration <= 0.0:
		_free_player(player)
		return

	_fade_tween = create_tween()
	_fade_tween.tween_property(player, "volume_db", -80.0, fade_duration).set_trans(Tween.TRANS_SINE)
	_fade_tween.tween_callback(func():
		if id != _transition_id:
			return
		_free_player(player)
	)


func set_volume_db(db: float) -> void:
	_base_volume_db = clamp(db, -80.0, 0.0)
	if _primary_player and is_instance_valid(_primary_player):
		_primary_player.volume_db = _base_volume_db


func get_current_bgm() -> String:
	return _current_bgm_path


func is_playing() -> bool:
	return _primary_player != null and is_instance_valid(_primary_player) and _primary_player.playing


func is_paused_by_game() -> bool:
	return _paused_by_game


func clear_game_pause() -> void:
	_paused_by_game = false
	_apply_pause_state()


func _load_stream(stream_path: String) -> AudioStream:
	if stream_path == "" or not ResourceLoader.exists(stream_path):
		push_warning("[MusicManager] BGM 资源不存在: %s" % stream_path)
		return null
	var stream := load(stream_path) as AudioStream
	if not stream:
		push_error("[MusicManager] BGM 加载失败: %s" % stream_path)
	return stream


func _is_current(stream_path: String) -> bool:
	return stream_path != "" and stream_path == _current_bgm_path and is_playing()


func _is_current_or_loaded(stream_path: String) -> bool:
	return stream_path != "" \
		and stream_path == _current_bgm_path \
		and _primary_player != null \
		and is_instance_valid(_primary_player)


func _make_player(stream: AudioStream, volume_db: float) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = "BGMPlayer"
	player.stream = stream
	player.volume_db = volume_db
	player.bus = "Master"
	player.finished.connect(func():
		if is_instance_valid(player) and player == _primary_player and _current_bgm_path != "":
			player.play()
	)
	add_child(player)
	return player


func _promote_fade_player(id: int) -> void:
	if id != _transition_id:
		return
	_free_player(_primary_player)
	_primary_player = _fade_player
	_fade_player = null
	if _primary_player and is_instance_valid(_primary_player):
		_primary_player.volume_db = _base_volume_db
	_apply_pause_state()


func _apply_pause_state() -> void:
	for player in [_primary_player, _fade_player]:
		if player and is_instance_valid(player):
			player.stream_paused = _paused_by_game


func _free_player(player: AudioStreamPlayer) -> void:
	if player and is_instance_valid(player):
		player.stop()
		player.queue_free()


func _kill_tween() -> void:
	if _fade_tween and is_instance_valid(_fade_tween):
		_fade_tween.kill()
	_fade_tween = null
