# ============================================================
# MusicManager.gd - 全局音乐管理器 (Autoload)
# 负责 BGM 播放、淡入淡出、场景切换过渡
#
# 使用方式:
#   MusicManager.play_bgm("res://Assets/Music/lv3.wav")
#   MusicManager.fade_to("res://Assets/Music/lv5-bossfight.wav", 1.5)
#   MusicManager.stop_bgm(0.8)
#   MusicManager.set_volume_db(-6.0)
# ============================================================
extends Node

# 当前播放的 BGM 路径（用于去重）
var _current_bgm_path: String = ""
# 是否正在淡入中
var _fading_in: bool = false
# 淡出 Tween
var _fade_tween: Tween = null

# 基础音量（线性 0.0~1.0），由 set_volume_db 控制
var _base_volume_db: float = 0.0


func _ready() -> void:
	# 监听暂停/恢复事件，控制音频输出
	EventBus.subscribe(GlobalDefine.EventName.GAME_PAUSE, self, "_on_game_pause")
	EventBus.subscribe(GlobalDefine.EventName.GAME_RESUME, self, "_on_game_resume")


## 游戏暂停：暂停所有 BGM 播放器（不销毁，恢复后继续）
func _on_game_pause(_data: Dictionary = {}) -> void:
	for child in get_children():
		if child is AudioStreamPlayer and is_instance_valid(child):
			child.stream_paused = true


## 游戏恢复：恢复播放
func _on_game_resume(_data: Dictionary = {}) -> void:
	for child in get_children():
		if child is AudioStreamPlayer and is_instance_valid(child):
			child.stream_paused = false


## 播放 BGM（若已播放同一曲则跳过）
func play_bgm(stream_path: String, from_position: float = 0.0) -> void:
	if stream_path == "" or not ResourceLoader.exists(stream_path):
		push_warning("[MusicManager] BGM 资源不存在: %s" % stream_path)
		return

	# 去重：同一曲目不重复播放
	if _current_bgm_path == stream_path and _has_active_player():
		return

	# 停止当前
	stop_bgm(0.0)

	var stream = load(stream_path)
	if not stream:
		push_error("[MusicManager] BGM 加载失败: %s" % stream_path)
		return

	_create_player(stream, from_position)
	_current_bgm_path = stream_path


## 直接从已加载的 AudioStream 播放（用于 editor 中直接拖入 Resource 的情况）
func play_bgm_from_stream(stream: Resource, from_position: float = 0.0) -> void:
	if not stream:
		return

	stop_bgm(0.0)
	_create_player(stream, from_position)
	_current_bgm_path = stream.resource_path


## 淡入淡出切换到新 BGM
func fade_to(stream_path: String, duration: float = 1.0, from_position: float = 0.0) -> void:
	if stream_path == _current_bgm_path and _has_active_player():
		return

	if stream_path == "" or not ResourceLoader.exists(stream_path):
		stop_bgm(duration)
		return

	var stream = load(stream_path)
	if not stream:
		push_error("[MusicManager] BGM 加载失败: %s" % stream_path)
		return

	# 淡出当前 → 淡入新曲
	var old_player = _get_active_player()

	# 创建新播放器（静音起播，之后淡入）
	var new_player = _create_player(stream, from_position)
	new_player.volume_db = -80.0  # 静音起播

	if old_player and is_instance_valid(old_player):
		# 同时：淡出旧播放器 + 淡入新播放器
		_kill_tween()
		_fading_in = true
		_fade_tween = create_tween().set_parallel(true)
		_fade_tween.tween_property(old_player, "volume_db", -80.0, duration).set_trans(Tween.TRANS_SINE)
		_fade_tween.tween_property(new_player, "volume_db", _base_volume_db, duration).set_trans(Tween.TRANS_SINE)
		_fade_tween.tween_callback(func():
			if is_instance_valid(old_player):
				old_player.queue_free()
			_fading_in = false
		).set_delay(duration)
	else:
		# 无旧播放器，只淡入
		_fading_in = true
		_kill_tween()
		_fade_tween = create_tween()
		_fade_tween.tween_property(new_player, "volume_db", _base_volume_db, duration).set_trans(Tween.TRANS_SINE)
		_fade_tween.tween_callback(func(): _fading_in = false)

	_current_bgm_path = stream_path


## 停止 BGM（可选淡出时长）
func stop_bgm(fade_duration: float = 0.5) -> void:
	var player = _get_active_player()
	if not player or not is_instance_valid(player):
		_current_bgm_path = ""
		return

	if fade_duration <= 0.0:
		player.stop()
		player.queue_free()
		_current_bgm_path = ""
		return

	_kill_tween()
	_fade_tween = create_tween()
	_fade_tween.tween_property(player, "volume_db", -80.0, fade_duration).set_trans(Tween.TRANS_SINE)
	_fade_tween.tween_callback(func():
		if is_instance_valid(player):
			player.stop()
			player.queue_free()
	)
	_current_bgm_path = ""


## 设置音量（分贝，-80~0，0=满音量）
func set_volume_db(db: float) -> void:
	_base_volume_db = clamp(db, -80.0, 0.0)
	var player = _get_active_player()
	if player and is_instance_valid(player) and not _fading_in:
		player.volume_db = _base_volume_db


## 获取当前 BGM 路径
func get_current_bgm() -> String:
	return _current_bgm_path


## 是否正在播放
func is_playing() -> bool:
	var p = _get_active_player()
	return p != null and is_instance_valid(p) and p.playing


# ---- 内部 ----

func _has_active_player() -> bool:
	return _get_active_player() != null

func _get_active_player() -> AudioStreamPlayer:
	for child in get_children():
		if child is AudioStreamPlayer and is_instance_valid(child) and child.playing:
			return child
	return null

func _create_player(stream: Resource, from_position: float = 0.0) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = "BGMPlayer"
	player.stream = stream
	player.volume_db = _base_volume_db
	player.bus = "Master"
	# finished 信号 → 自动重播（实现循环，不设置 loop_mode 避免某些 WAV 静音）
	player.finished.connect(func():
		if is_instance_valid(player) and _current_bgm_path != "":
			player.play()
	)
	add_child(player)

	if from_position > 0.0 and stream is AudioStreamWAV:
		player.play(from_position)
	else:
		player.play()

	return player

func _kill_tween() -> void:
	if _fade_tween and is_instance_valid(_fade_tween):
		_fade_tween.kill()
	_fade_tween = null
