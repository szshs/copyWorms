# ============================================================
# Level_04.gd - 第四关「维度侵蚀与空间崩塌」控制器
# 场景构建 → Level_04_SceneBuilder
# UI 构建   → Level_04_UIBuilder
#
# 【故事衔接】承接 Level_03 结尾：
#   阿明识破虚拟世界真相，启动 Override Protocol 试图返回现实。
#   系统（CodeBuddy AI）发起最后反扑——启动"维度侵蚀"，
#   将赛博与岭南拼接成混乱空间，阻止阿明抵达真正出口。
#
# 当前实现:
#   阶段1 地图切换: 战斗交互触发赛博(1-1) ↔ 岭南(1-2)瞬移 + 闪帧
#   后续阶段待开发
# ============================================================
extends LevelBase
class_name Level_04

@export var level_data: Level04Data = null

enum LevelState {
	HOMOMORPHIC_COMBAT,   # 地图切换阶段
	LEVEL_END_TRANSIT     # 关卡结束转场
}

var current_state: int = LevelState.HOMOMORPHIC_COMBAT

# ---- 地图切换 ----
var _current_world: int = 0              # 0=赛博(1-1), 1=岭南(1-2)
var _swap_count: int = 0
var _lingnan_spawn_index: int = 0
var _lingnan_enemies_spawned: bool = false
const CYBER_TELEPORT := Vector2(2298, -75)
const CYBER_CAM = [-50, 2500, -900, 1200]   # 左,右,上,下
const LNGN_CAM  = [-50, 4000,  600, 2500]
const LNGN_POSITIONS: Array[Vector2] = [
	Vector2(524, 2060), Vector2(3564, 2073), Vector2(1631, 1316)
]
const LNGN_DIALOGS: Array[String] = [
	"不太对，我需要到上面的阁楼看看",
	"还是不对",
	""
]
var _stage1_enemies: Array[Node2D] = []

# ---- 场景节点引用 ----
var _dynamic_actors: Node2D = null

# ---- UI 引用 ----
var _narrative_panel: Panel = null
var _narrative_text: RichTextLabel = null
var _glitch_overlay: ColorRect = null
# 其他 UI 覆盖层保留引用但暂未使用
var _vignette_overlay: ColorRect = null
var _ending_prompt: Control = null
var _ending_label: Label = null

# ---- 交互/叙事 ----
var _interact_cooldown: float = 0.0
var _is_interacting: bool = false
var _narrative_open: bool = false
var _narrative_enter_pressed: bool = false
const NARRATIVE_INPUT_TIMEOUT: float = 30.0

# ---- 敌人管理 ----
var _enemy_cyber_wolf_scene: PackedScene = null

# ---- 终局 ----
var _ending_enter_armed: bool = false
var _level_complete_emitted: bool = false


# ============================================================
# 生命周期
# ============================================================

func _setup_player() -> void:
	if GameManager.player_ref and is_instance_valid(GameManager.player_ref):
		return
	var player_path = "res://PlayerModule/Formal/Player_Warrior_Cyber.tscn"
	if ResourceLoader.exists(player_path):
		var player = load(player_path).instantiate()
		var spawn_pos = level_config.spawn_point if level_config else Vector2(400, 550)
		player.position = spawn_pos
		add_child(player)
		GameManager.register_player(player)
		print("[Level_04] 玩家创建成功（赛博皮肤）")


func _swap_player_skin(skin: String) -> void:
	var old = GameManager.player_ref
	if not old or not is_instance_valid(old): return

	var saved_health = old.current_health
	var saved_max = old.max_health
	var saved_facing = old.is_facing_right
	var saved_pos = old.global_position

	if InputManager.game_action.is_connected(old._on_game_action):
		InputManager.game_action.disconnect(old._on_game_action)
	GameManager.player_ref = null
	old.queue_free()

	var path = "res://PlayerModule/Formal/Player_Warrior_" + skin + ".tscn"
	if not ResourceLoader.exists(path):
		push_error("[Level_04] 皮肤不存在: " + path)
		return
	var p = load(path).instantiate()
	p.global_position = saved_pos
	p.current_health = saved_health
	p.max_health = saved_max
	p.is_facing_right = saved_facing
	p.velocity = Vector2.ZERO
	add_child(p)
	GameManager.register_player(p)
	print("[Level_04] 皮肤切换: " + skin)

func _on_ready() -> void:
	super._on_ready()
	if not level_config:
		level_config = load("res://DataConfig/Level/Level04Config.tres") as LevelConfig
		_apply_config()
	if not level_data:
		level_data = load("res://DataConfig/Level/Level04Data.tres") as Level04Data

	var wolf_path = "res://EnemyModule/Formal/Enemy_CyberWolf.tscn"
	if ResourceLoader.exists(wolf_path):
		_enemy_cyber_wolf_scene = load(wolf_path)

	Level_04_SceneBuilder.new(self).build_all()
	_setup_camera_limits()
	_set_camera_limits(CYBER_CAM[0], CYBER_CAM[1], CYBER_CAM[2], CYBER_CAM[3])
	_cache_ui_refs()
	_ensure_player_collision_layer()

	EventBus.subscribe(GlobalDefine.EventName.PLAYER_ATTACK_HIT, self, "_on_combat_hit")
	EventBus.subscribe(GlobalDefine.EventName.PLAYER_HURT, self, "_on_combat_hit")
	EventBus.subscribe(GlobalDefine.EventName.ENEMY_DIED, self, "_on_enemy_died")

	if not InputManager.game_action.is_connected(_on_game_action):
		InputManager.game_action.connect(_on_game_action)

	_load_hud()
	set_process(true)

	# 起始叙事 → 完成后生成敌人
	if level_data and level_data.anchor_narrative != "":
		_show_narrative("[color=green]> User_Ming_Override_Protocol: Phase_Final.[/color]\n[color=green]> Target: REAL_EXIT.[/color]", func():
			_show_narrative("[color=goldenrod]阿明：[/color]" + level_data.anchor_narrative, func():
				_spawn_stage1_enemies()
				_restore_combat_mechanics()
			)
		)
	else:
		_spawn_stage1_enemies()
		_restore_combat_mechanics()
	print("[Level_04] 初始化完成")


func _get_or_create_child(node_name: String, node_type) -> Node:
	var existing = get_node_or_null(node_name)
	if existing: return existing
	var node = node_type.new()
	node.name = node_name
	add_child(node)
	return node


func _load_hud() -> void:
	var hud_path = "res://UI/HUD.tscn"
	if ResourceLoader.exists(hud_path):
		add_child(load(hud_path).instantiate())


# ============================================================
# 工具方法
# ============================================================

func _ensure_player_collision_layer() -> void:
	var player = GameManager.player_ref
	if not player or not is_instance_valid(player): return
	if not (player.collision_layer & GlobalDefine.Collision.PLAYER):
		player.collision_layer |= GlobalDefine.Collision.PLAYER

func _setup_camera_limits() -> void:
	if not level_config: return
	var player = GameManager.player_ref
	if not player or not is_instance_valid(player): return
	var cam = player.get_node_or_null("SmoothCamera") as SmoothCamera
	if not cam: return
	cam.limit_left = level_config.camera_limit_left
	cam.limit_right = level_config.camera_limit_right
	cam.limit_top = level_config.camera_limit_top
	cam.limit_bottom = level_config.camera_limit_bottom

func _set_camera_limits(left: int, right: int, top: int, bottom: int) -> void:
	var player = GameManager.player_ref
	if not player or not is_instance_valid(player): return
	var cam = player.get_node_or_null("SmoothCamera") as SmoothCamera
	if not cam: return
	cam.limit_left = left
	cam.limit_right = right
	cam.limit_top = top
	cam.limit_bottom = bottom

func _cache_ui_refs() -> void:
	var canvas = $CanvasLayerUI
	if not canvas: return
	_narrative_panel = canvas.get_node_or_null("NarrativePanel")
	if _narrative_panel: _narrative_text = _narrative_panel.get_node_or_null("RichTextLabel")
	_glitch_overlay = canvas.get_node_or_null("GlitchOverlay")
	_vignette_overlay = canvas.get_node_or_null("VignetteOverlay")
	_ending_prompt = canvas.get_node_or_null("EndingPrompt")
	if _ending_prompt: _ending_label = _ending_prompt.get_node_or_null("EndingLabel")


# ============================================================
# 玩家控制
# ============================================================

func _restore_combat_mechanics() -> void:
	var player = GameManager.player_ref
	if not player: return
	player.can_attack = true
	player.can_dash = true
	player.can_skill = true

func _freeze_player(freeze: bool) -> void:
	var player = GameManager.player_ref
	if not player: return
	if freeze:
		player.velocity = Vector2.ZERO
		player.set_physics_process(false)
		player.set_process_input(false)
		player._change_state(GlobalDefine.PlayerState.IDLE)
	else:
		player.set_physics_process(true)
		player.set_process_input(true)


# ============================================================
# 输入处理
# ============================================================

func _on_game_action(action: StringName, _event: InputEvent) -> void:
	if action != &"ui_accept": return
	if current_state == LevelState.LEVEL_END_TRANSIT:
		if _ending_enter_armed:
			_ending_enter_armed = false
			_emit_level_complete()
		return
	if _narrative_open:
		_narrative_enter_pressed = true
		return

func _input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_accept"): return
	if current_state == LevelState.LEVEL_END_TRANSIT:
		if _ending_enter_armed:
			_ending_enter_armed = false
			_emit_level_complete()
			get_viewport().set_input_as_handled()
		return
	if _narrative_open:
		_narrative_enter_pressed = true
		get_viewport().set_input_as_handled()


# ============================================================
# 叙事面板
# ============================================================

func _show_narrative(text: String, callback: Callable = Callable()) -> void:
	InputManager.block_input("叙事面板", self)
	if _narrative_open:
		if _narrative_panel: _narrative_panel.hide()
		_narrative_open = false
	_is_interacting = true
	_narrative_open = true
	_freeze_player(true)
	if _narrative_panel:
		_narrative_panel.show()
		if _narrative_text: _narrative_text.text = text
	await get_tree().create_timer(0.3).timeout
	_narrative_enter_pressed = false
	var wait_elapsed: float = 0.0
	while _narrative_open and wait_elapsed < NARRATIVE_INPUT_TIMEOUT:
		if _narrative_enter_pressed: break
		await get_tree().create_timer(0.05).timeout
		wait_elapsed += 0.05
	if _narrative_panel: _narrative_panel.hide()
	_freeze_player(false)
	_narrative_open = false
	_is_interacting = false
	_interact_cooldown = 0.0
	InputManager.unblock_input("叙事面板")
	if callback.is_valid(): callback.call()


# ============================================================
# 地图切换: 赛博(1-1) ↔ 岭南(1-2)
# ============================================================

func _on_combat_hit(_data: Dictionary) -> void:
	if current_state != LevelState.HOMOMORPHIC_COMBAT: return
	if _narrative_open or _is_interacting: return
	_swap_world()

func _swap_world() -> void:
	var player = GameManager.player_ref
	if not player or not is_instance_valid(player): return

	_flash_screen()

	if _current_world == 0:
		var target = LNGN_POSITIONS[_lingnan_spawn_index]
		var dialog = LNGN_DIALOGS[_lingnan_spawn_index]
		_lingnan_spawn_index = (_lingnan_spawn_index + 1) % LNGN_POSITIONS.size()
		player.global_position = target
		_current_world = 1
		_swap_player_skin("Lingnan")  # 换岭南皮肤
		player = GameManager.player_ref  # 皮肤切换后 player 引用已变
		_snap_camera(player)
		_set_camera_limits(LNGN_CAM[0], LNGN_CAM[1], LNGN_CAM[2], LNGN_CAM[3])
		_spawn_lingnan_enemies_once()
		if dialog != "":
			get_tree().create_timer(1.0).timeout.connect(func():
				if _current_world != 1: return
				if _narrative_open: return
				_show_narrative("[color=cyan]阿明：[/color]" + dialog)
			)
	else:
		player.global_position = CYBER_TELEPORT
		_current_world = 0
		_swap_player_skin("Cyber")  # 换赛博皮肤
		player = GameManager.player_ref
		_snap_camera(player)
		_set_camera_limits(CYBER_CAM[0], CYBER_CAM[1], CYBER_CAM[2], CYBER_CAM[3])

	_swap_count += 1


func _snap_camera(player: CharacterBody2D) -> void:
	var cam = player.get_node_or_null("SmoothCamera") as SmoothCamera
	if cam:
		cam.global_position = player.global_position


func _flash_screen() -> void:
	if _glitch_overlay and _glitch_overlay.material:
		_glitch_overlay.show()
		var mat = _glitch_overlay.material as ShaderMaterial
		mat.set_shader_parameter("intensity", 1.0)
		var t = create_tween()
		t.tween_property(mat, "shader_parameter/intensity", 0.0, 0.25)

	var flash = ColorRect.new()
	flash.name = "SwapFlash"
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.color = Color.WHITE
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.z_index = 100
	var canvas = $CanvasLayerUI
	if canvas:
		canvas.add_child(flash)
	var t2 = create_tween()
	t2.tween_property(flash, "color:a", 0.0, 0.3)
	t2.tween_callback(flash.queue_free)


# ============================================================
# 敌人生成
# ============================================================

func _spawn_stage1_enemies() -> void:
	if not _enemy_cyber_wolf_scene: return
	var spawn_points = level_data.surface_enemy_spawn_points if level_data else []
	if spawn_points.is_empty():
		spawn_points = [Vector2(400, 540), Vector2(600, 540), Vector2(800, 540), Vector2(1000, 540), Vector2(1400, 540)]
	var config = load("res://DataConfig/Enemy/CleanerConfig.tres") as EnemyConfig
	for sp in spawn_points:
		var enemy = _spawn_enemy_with_config(_enemy_cyber_wolf_scene, sp, config)
		if enemy:
			enemy.modulate = Color(0.3, 0.3, 0.35, 0.95)
			_stage1_enemies.append(enemy)
	print("[Level_04] 赛博敌人生成: %d 只" % _stage1_enemies.size())


func _spawn_lingnan_enemies_once() -> void:
	if _lingnan_enemies_spawned: return
	_lingnan_enemies_spawned = true
	if not _enemy_cyber_wolf_scene: return
	var config = load("res://DataConfig/Enemy/CleanerConfig.tres") as EnemyConfig
	var spawns = [Vector2(1000, 2100), Vector2(2000, 2150), Vector2(3000, 2100)]
	for sp in spawns:
		var enemy = _spawn_enemy_with_config(_enemy_cyber_wolf_scene, sp, config)
		if enemy:
			enemy.modulate = Color(0.2, 0.15, 0.35, 0.95)
			_stage1_enemies.append(enemy)
	print("[Level_04] 岭南敌人生成: 3 只")


func _spawn_enemy_with_config(scene: PackedScene, spawn_pos: Vector2, config: EnemyConfig) -> Node2D:
	if not scene: return null
	var enemy = scene.instantiate()
	if config: enemy.config = config
	enemy.global_position = spawn_pos
	if _dynamic_actors:
		_dynamic_actors.add_child(enemy)
	else:
		add_child(enemy)
	return enemy


func _on_enemy_died(data: Dictionary) -> void:
	var enemy = data.get("enemy")
	if not enemy or not is_instance_valid(enemy): return
	if current_state == LevelState.HOMOMORPHIC_COMBAT:
		if enemy in _stage1_enemies:
			_stage1_enemies.erase(enemy)
			_swap_count += 2


# ============================================================
# 终局
# ============================================================

func _trigger_level_end() -> void:
	current_state = LevelState.LEVEL_END_TRANSIT
	if _ending_prompt:
		_ending_prompt.show()
		if _ending_label and level_data:
			_ending_label.text = level_data.override_protocol_text
	_ending_enter_armed = true

func _emit_level_complete() -> void:
	if _level_complete_emitted: return
	_level_complete_emitted = true
	var next_path = level_data.next_level_path if level_data else ""
	_full_cleanup()
	EventBus.emit(GlobalDefine.EventName.LEVEL_COMPLETE, {"level": self, "next_level": next_path})

func _full_cleanup() -> void:
	for e in _stage1_enemies:
		if is_instance_valid(e):
			GameManager.unregister_enemy(e)
			e.queue_free()
	_stage1_enemies.clear()
	EventBus.unsubscribe_all(self)
