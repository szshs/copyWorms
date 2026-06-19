# ============================================================
# GameManager.gd - 游戏管理器 (Autoload)
# 统一管理游戏状态、运行模式、玩家/敌人引用
# ============================================================
extends Node

# 运行模式（根据场景自动切换）
var run_mode: int = GlobalDefine.RunMode.FORMAL

# 全局引用
var player_ref: Node2D = null
var current_level: Node = null
var enemy_list: Array[Node2D] = []

# 游戏状态
var is_paused: bool = false
var is_game_over: bool = false

# 跨关卡梦境运行时配置（关卡2"配置篡改"谜题写入，关卡3读取应用）
# 例: { "player_damage_reduction": true, "base_jump_height": 99,
#       "allow_external_signal": false, "dream_version": "2.0" }
var dream_runtime_flags: Dictionary = {}

# Boss 战引用（关卡设置，用于弹体自动瞄准等）
var boss_target: Node2D = null

# ---- 检查点系统 ----
# 记录玩家当前所处的关卡场景路径和阶段，用于"重新开始"时回到当前关卡而非Level_01
var checkpoint_scene_path: String = ""    # 检查点场景路径（如 "res://LevelModule/Formal/Level_02_01.tscn"）
var checkpoint_stage: int = 0             # 检查点阶段（用于同场景内多阶段关卡，如Level_04的stage2/Level_05的bg4/bg5）
var checkpoint_data: Dictionary = {}      # 检查点附加数据（如玩家血量等，可选）

# ---- 生命周期 ----

func _ready() -> void:
	_apply_global_font()
	_detect_run_mode()

## 全局字体：所有 UI 节点默认使用方正像素12
func _apply_global_font() -> void:
	var font := load("res://Assets/Fonts/方正像素/方正像素12.ttf") as FontFile
	if font == null:
		push_error("[GameManager] 方正像素12.ttf 加载失败")
		return
	# 设置项目默认主题字体，所有 Control 节点自动继承
	var default_theme := ThemeDB.get_default_theme()
	default_theme.set_default_font(font)
	print("[GameManager] 全局字体已设为方正像素12")

## 自动检测运行模式
func _detect_run_mode() -> void:
	var current_scene = get_tree().current_scene
	if current_scene == null:
		run_mode = GlobalDefine.RunMode.FORMAL
		return

	var scene_path = current_scene.scene_file_path
	if scene_path and "SelfTest" in scene_path:
		run_mode = GlobalDefine.RunMode.SELF_TEST
		print("[GameManager] 检测到自测模式: ", scene_path)
	else:
		run_mode = GlobalDefine.RunMode.FORMAL
		print("[GameManager] 正式模式: ", scene_path)

## 正式模式下，场景切换时重新检测
func _on_scene_changed() -> void:
	_detect_run_mode()

# ---- 公共方法 ----

## 注册玩家
func register_player(player: Node2D) -> void:
	player_ref = player
	EventBus.emit(GlobalDefine.EventName.PLAYER_SPAWNED, { "player": player })

## 注册敌人
func register_enemy(enemy: Node2D) -> void:
	enemy_list.append(enemy)
	EventBus.emit(GlobalDefine.EventName.ENEMY_SPAWNED, { "enemy": enemy })

## 注销敌人
func unregister_enemy(enemy: Node2D) -> void:
	enemy_list.erase(enemy)

## 获取所有敌人
func get_enemies() -> Array[Node2D]:
	enemy_list = enemy_list.filter(func(e): return is_instance_valid(e))
	return enemy_list

## 获取离某点最近的敌人
func get_nearest_enemy(pos: Vector2) -> Node2D:
	enemy_list = enemy_list.filter(func(e): return is_instance_valid(e))
	var nearest: Node2D = null
	var min_dist: float = INF
	for enemy in enemy_list:
		if not is_instance_valid(enemy):
			continue
		var dist = pos.distance_squared_to(enemy.global_position)
		if dist < min_dist:
			min_dist = dist
			nearest = enemy
	return nearest

## 暂停/恢复
func toggle_pause() -> void:
	is_paused = !is_paused
	get_tree().paused = is_paused
	if is_paused:
		EventBus.emit(GlobalDefine.EventName.GAME_PAUSE)
	else:
		EventBus.emit(GlobalDefine.EventName.GAME_RESUME)

## 游戏结束
func trigger_game_over() -> void:
	is_game_over = true
	EventBus.emit(GlobalDefine.EventName.GAME_OVER)

## 判断是否自测模式
func is_self_test() -> bool:
	return run_mode == GlobalDefine.RunMode.SELF_TEST

## 判断是否正式模式
func is_formal() -> bool:
	return run_mode == GlobalDefine.RunMode.FORMAL

# ---- 检查点系统 ----

## 设置检查点（关卡_on_ready时调用，记录当前场景路径）
func set_checkpoint(scene_path: String, stage: int = 0, data: Dictionary = {}) -> void:
	checkpoint_scene_path = scene_path
	checkpoint_stage = stage
	checkpoint_data = data

## 更新检查点阶段（同场景内阶段切换时调用，如Level_04 stage1→stage2）
func update_checkpoint_stage(stage: int, data: Dictionary = {}) -> void:
	checkpoint_stage = stage
	if not data.is_empty():
		checkpoint_data = data

## 重新开始：回到检查点关卡（而非reload_current_scene回到Level_01）
func restart_from_checkpoint() -> void:
	is_game_over = false
	is_paused = false
	get_tree().paused = false
	# 清理引用
	player_ref = null
	enemy_list.clear()
	boss_target = null
	InputManager.force_unblock_all()
	# 如果有检查点场景路径，重新加载该场景
	if checkpoint_scene_path != "" and ResourceLoader.exists(checkpoint_scene_path):
		print("[GameManager] 从检查点重新开始: %s (stage=%d)" % [checkpoint_scene_path, checkpoint_stage])
		# 检查是否在MainEntry托管模式下（current_scene是MainEntry）
		var cs = get_tree().current_scene
		if cs and cs.has_method("_switch_to_level"):
			# MainEntry模式：通过MainEntry的关卡切换逻辑重新加载检查点场景
			cs._switch_to_level(checkpoint_scene_path)
		else:
			# 独立模式：直接change_scene_to_file
			get_tree().change_scene_to_file(checkpoint_scene_path)
	else:
		# 无检查点，回退到reload_current_scene
		print("[GameManager] 无检查点，reload_current_scene")
		get_tree().reload_current_scene()
