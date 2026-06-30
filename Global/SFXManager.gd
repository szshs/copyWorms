# ============================================================
# SFXManager.gd - 全局音效管理器 (Autoload)
# 统一管理游戏内短音效的加载与播放
#
# 设计要点:
#   1. 预加载所有音效资源到字典，避免运行时 IO
#   2. 对象池轮询 AudioStreamPlayer，支持多音效同时播放不互相截断
#   3. 内置防抖: 同一 key 在 min_interval 内重复请求只播一次
#   4. 支持音调微变 (play_pitched): 频繁触发的音效(攻击/受击)避免单调
#   5. 暂停时自动静音 (订阅 GAME_PAUSE/RESUME)
#
# 使用方式:
#   SFXManager.play(SFXManager.SFX.PLAYER_ATTACK)
#   SFXManager.play_pitched(SFXManager.SFX.ENEMY_HURT, 0.92, 1.08)
# ============================================================
extends Node

# ---- 音效键 ----
const SFX = {
	PLAYER_ATTACK  = "player_attack",   # 玩家普攻
	PLAYER_CHARGE_ATTACK = "player_charge_attack", # 长按普攻蓄力突进
	PLAYER_SKILL   = "player_skill",    # 玩家技能（松开释放）
	PLAYER_HURT     = "player_hurt",    # 玩家受击
	PLAYER_WALK     = "player_walk",    # 玩家行走
	ENEMY_IDLE_WALK = "enemy_idle_walk",# 怪物待机/行走
	ENEMY_HURT      = "enemy_hurt",     # 怪物受击
	UI_CLICK        = "ui_click",       # UI 点击
	ENERGY_ACCUMULATE = "energy_accumulate", # 技能蓄力循环
}

# ---- 资源路径 ----
const _PATHS := {
	SFX.PLAYER_CHARGE_ATTACK : "res://Assets/Sound/sword sound3.mp3",
	SFX.PLAYER_SKILL    : "res://Assets/Sound/sword skill sound.mp3",
	SFX.PLAYER_HURT     : "res://Assets/Sound/玩家受击.mp3",
	SFX.PLAYER_WALK     : "res://Assets/Sound/玩家行走.mp3",
	SFX.ENEMY_IDLE_WALK : "res://Assets/Sound/怪物待机、行走.wav",
	SFX.ENEMY_HURT      : "res://Assets/Sound/monster hit.mp3",
	SFX.UI_CLICK        : "res://Assets/Sound/点击按钮.mp3",
	SFX.ENERGY_ACCUMULATE : "res://Assets/Sound/Energy Accumulate.mp3",
}

## 多版本音效：播放时随机选取其一
const _VARIANT_PATHS := {
	SFX.PLAYER_ATTACK: [
		"res://Assets/Sound/sword sound.mp3",
		"res://Assets/Sound/sword sound3.mp3",
	],
}

## 相对全局音量的额外比例（1.0 = 不变；0.4 = 现为原来的 40%）
const _VOLUME_RATIOS := {
	SFX.PLAYER_ATTACK: 0.4,
	SFX.PLAYER_CHARGE_ATTACK: 0.4,
	SFX.ENEMY_HURT: 0.4,
}

# ---- 内部状态 ----
var _streams: Dictionary = {}                 # {key: AudioStream}
var _stream_variants: Dictionary = {}           # {key: Array[AudioStream]}
var _players: Array[AudioStreamPlayer] = []   # 对象池
var _pool_index: int = 0
const POOL_SIZE := 8

var _last_play_msec: Dictionary = {}          # {key: msec} 防抖记录
const DEFAULT_MIN_INTERVAL := 0.05            # 50ms 默认防抖

var _volume_db: float = -4.4  # 默认音量（线性约0.6倍，降低40%）
var _muted: bool = false
var _charge_player: AudioStreamPlayer = null
var _charge_loop_active: bool = false
const CHARGE_PITCH_MIN := 0.85
const CHARGE_PITCH_MAX := 1.55

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # 暂停时仍可处理（用于静音）
	_load_streams()
	_init_pool()
	EventBus.subscribe(GlobalDefine.EventName.GAME_PAUSE, self, "_on_game_pause")
	EventBus.subscribe(GlobalDefine.EventName.GAME_RESUME, self, "_on_game_resume")

# ================================================================
#  初始化
# ================================================================

func _load_streams() -> void:
	for key in _PATHS.keys():
		_load_stream_path(key, _PATHS[key])
	for key in _VARIANT_PATHS.keys():
		var variants: Array[AudioStream] = []
		for path: String in _VARIANT_PATHS[key]:
			var stream := _load_stream_at_path(path)
			if stream:
				variants.append(stream)
		if variants.is_empty():
			push_warning("[SFXManager] 多版本音效全部加载失败: %s" % key)
			continue
		_stream_variants[key] = variants

func _load_stream_path(key: String, path: String) -> void:
	var stream := _load_stream_at_path(path)
	if stream:
		_streams[key] = stream

func _load_stream_at_path(path: String) -> AudioStream:
	if not ResourceLoader.exists(path):
		push_warning("[SFXManager] 音效文件不存在: %s" % path)
		return null
	var stream = load(path) as AudioStream
	if stream:
		return stream
	push_warning("[SFXManager] 音效加载失败: %s" % path)
	return null

func _init_pool() -> void:
	for i in POOL_SIZE:
		var p = AudioStreamPlayer.new()
		p.name = "SFXPlayer_%d" % i
		p.volume_db = _volume_db
		p.bus = "Master"
		add_child(p)
		_players.append(p)
	_ensure_charge_player()

func _ensure_charge_player() -> void:
	if _charge_player:
		return
	_charge_player = AudioStreamPlayer.new()
	_charge_player.name = "SkillChargeLoopPlayer"
	_charge_player.bus = "Master"
	_charge_player.volume_db = _volume_db
	add_child(_charge_player)

# ================================================================
#  公共 API
# ================================================================

## 播放音效（带默认防抖，防止同帧/连帧重复触发）
func play(key: String, min_interval: float = DEFAULT_MIN_INTERVAL) -> void:
	if _muted or not has(key):
		return
	if not _pass_debounce(key, min_interval):
		return
	_play_stream(_resolve_stream(key), 1.0, key)

## 带音调随机微变的播放（适用于频繁触发的攻击/受击音效，增加变化感）
func play_pitched(key: String, pitch_min: float = 0.95, pitch_max: float = 1.05, min_interval: float = DEFAULT_MIN_INTERVAL) -> void:
	if _muted or not has(key):
		return
	if not _pass_debounce(key, min_interval):
		return
	_play_stream(_resolve_stream(key), randf_range(pitch_min, pitch_max), key)

## 强制播放（跳过防抖，用于必须响起的场景）
func play_force(key: String) -> void:
	if _muted or not has(key):
		return
	_play_stream(_resolve_stream(key), 1.0, key)

## 音效是否存在（供外部判断）
func has(key: String) -> bool:
	return _streams.has(key) or _stream_variants.has(key)

## 设置音量（分贝，-80~0）
func set_volume_db(db: float) -> void:
	_volume_db = clamp(db, -80.0, 0.0)
	for p in _players:
		p.volume_db = _volume_db
	if _charge_player:
		_charge_player.volume_db = _volume_db_for_key(SFX.ENERGY_ACCUMULATE)

## 静音/取消静音
func set_muted(muted: bool) -> void:
	_muted = muted
	if muted:
		stop_skill_charge_loop()

## 技能蓄力：开始循环播放 Energy Accumulate
func start_skill_charge_loop() -> void:
	if _muted or not has(SFX.ENERGY_ACCUMULATE):
		return
	_ensure_charge_player()
	var base_stream: AudioStream = _streams[SFX.ENERGY_ACCUMULATE] as AudioStream
	if base_stream == null:
		return
	if base_stream is AudioStreamMP3:
		var mp3_stream := (base_stream as AudioStreamMP3).duplicate()
		mp3_stream.loop = true
		_charge_player.stream = mp3_stream
	elif base_stream is AudioStreamWAV:
		var wav_stream := (base_stream as AudioStreamWAV).duplicate()
		wav_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		_charge_player.stream = wav_stream
	else:
		_charge_player.stream = base_stream
	_charge_player.volume_db = _volume_db_for_key(SFX.ENERGY_ACCUMULATE)
	_charge_player.pitch_scale = CHARGE_PITCH_MIN
	if not _charge_player.playing:
		_charge_player.play()
	_charge_loop_active = true

## 技能蓄力：按进度 0~1 调整播放速度（pitch_scale）
func update_skill_charge_progress(progress: float) -> void:
	if not _charge_loop_active or not _charge_player:
		return
	var t := clampf(progress, 0.0, 1.0)
	_charge_player.pitch_scale = lerpf(CHARGE_PITCH_MIN, CHARGE_PITCH_MAX, t)

## 技能蓄力：停止循环
func stop_skill_charge_loop() -> void:
	_charge_loop_active = false
	if _charge_player and _charge_player.playing:
		_charge_player.stop()

# ================================================================
#  内部
# ================================================================

func _pass_debounce(key: String, min_interval: float) -> bool:
	var now := Time.get_ticks_msec()
	var last: int = _last_play_msec.get(key, 0)
	if now - last < min_interval * 1000.0:
		return false
	_last_play_msec[key] = now
	return true

func _resolve_stream(key: String) -> AudioStream:
	if _stream_variants.has(key):
		var variants: Array = _stream_variants[key]
		return variants[randi_range(0, variants.size() - 1)]
	return _streams[key]

func _volume_db_for_key(key: String) -> float:
	var ratio: float = float(_VOLUME_RATIOS.get(key, 1.0))
	return _volume_db + linear_to_db(ratio)

func _play_stream(stream: AudioStream, pitch: float, key: String = "") -> void:
	var p: AudioStreamPlayer = _players[_pool_index]
	_pool_index = (_pool_index + 1) % POOL_SIZE
	p.stream = stream
	p.pitch_scale = pitch
	p.volume_db = _volume_db_for_key(key)
	p.play()

# ================================================================
#  暂停联动
# ================================================================

func _on_game_pause(_data: Dictionary = {}) -> void:
	set_muted(true)

func _on_game_resume(_data: Dictionary = {}) -> void:
	_muted = false
