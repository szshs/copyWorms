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
	PLAYER_ATTACK  = "player_attack",   # 玩家攻击
	PLAYER_HURT     = "player_hurt",    # 玩家受击
	PLAYER_WALK     = "player_walk",    # 玩家行走
	ENEMY_IDLE_WALK = "enemy_idle_walk",# 怪物待机/行走
	ENEMY_HURT      = "enemy_hurt",     # 怪物受击
	UI_CLICK        = "ui_click",       # UI 点击
}

# ---- 资源路径 ----
const _PATHS := {
	SFX.PLAYER_ATTACK  : "res://Assets/Sound/玩家攻击.mp3",
	SFX.PLAYER_HURT     : "res://Assets/Sound/玩家受击.mp3",
	SFX.PLAYER_WALK     : "res://Assets/Sound/玩家行走.mp3",
	SFX.ENEMY_IDLE_WALK : "res://Assets/Sound/怪物待机、行走.wav",
	SFX.ENEMY_HURT      : "res://Assets/Sound/怪物受击.mp3",
	SFX.UI_CLICK        : "res://Assets/Sound/点击按钮.mp3",
}

# ---- 内部状态 ----
var _streams: Dictionary = {}                 # {key: AudioStream}
var _players: Array[AudioStreamPlayer] = []   # 对象池
var _pool_index: int = 0
const POOL_SIZE := 8

var _last_play_msec: Dictionary = {}          # {key: msec} 防抖记录
const DEFAULT_MIN_INTERVAL := 0.05            # 50ms 默认防抖

var _volume_db: float = -4.4  # 默认音量（线性约0.6倍，降低40%）
var _muted: bool = false

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
		var p: String = _PATHS[key]
		if not ResourceLoader.exists(p):
			push_warning("[SFXManager] 音效文件不存在: %s" % p)
			continue
		var s = load(p) as AudioStream
		if s:
			_streams[key] = s
		else:
			push_warning("[SFXManager] 音效加载失败: %s" % p)

func _init_pool() -> void:
	for i in POOL_SIZE:
		var p = AudioStreamPlayer.new()
		p.name = "SFXPlayer_%d" % i
		p.volume_db = _volume_db
		p.bus = "Master"
		add_child(p)
		_players.append(p)

# ================================================================
#  公共 API
# ================================================================

## 播放音效（带默认防抖，防止同帧/连帧重复触发）
func play(key: String, min_interval: float = DEFAULT_MIN_INTERVAL) -> void:
	if _muted or not _streams.has(key):
		return
	if not _pass_debounce(key, min_interval):
		return
	_play_stream(_streams[key], 1.0)

## 带音调随机微变的播放（适用于频繁触发的攻击/受击音效，增加变化感）
func play_pitched(key: String, pitch_min: float = 0.95, pitch_max: float = 1.05, min_interval: float = DEFAULT_MIN_INTERVAL) -> void:
	if _muted or not _streams.has(key):
		return
	if not _pass_debounce(key, min_interval):
		return
	_play_stream(_streams[key], randf_range(pitch_min, pitch_max))

## 强制播放（跳过防抖，用于必须响起的场景）
func play_force(key: String) -> void:
	if _muted or not _streams.has(key):
		return
	_play_stream(_streams[key], 1.0)

## 音效是否存在（供外部判断）
func has(key: String) -> bool:
	return _streams.has(key)

## 设置音量（分贝，-80~0）
func set_volume_db(db: float) -> void:
	_volume_db = clamp(db, -80.0, 0.0)
	for p in _players:
		p.volume_db = _volume_db

## 静音/取消静音
func set_muted(muted: bool) -> void:
	_muted = muted

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

func _play_stream(stream: AudioStream, pitch: float) -> void:
	var p: AudioStreamPlayer = _players[_pool_index]
	_pool_index = (_pool_index + 1) % POOL_SIZE
	p.stream = stream
	p.pitch_scale = pitch
	p.volume_db = _volume_db
	p.play()

# ================================================================
#  暂停联动
# ================================================================

func _on_game_pause(_data: Dictionary = {}) -> void:
	set_muted(true)

func _on_game_resume(_data: Dictionary = {}) -> void:
	set_muted(false)
