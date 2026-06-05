# res://LevelModule/Formal/Level_01.gd
# 第一关控制器 - FSM 有限状态机驱动
# 继承 LevelBase，实现现实家中的颓废与苏醒叙事
extends LevelBase
class_name Level_01

## 关卡数据资源（所有文本与配置）
@export var level_data: Level01Data = null

# ---- FSM 状态枚举 ----
enum LevelState {
	LIVING_ROOM,    # 阶段1：客厅。纸箱阻挡激活。
	CORRIDOR,       # 阶段2：走廊。衣服阻挡激活，纸箱已清除。
	BEDROOM,        # 阶段3：卧室。衣服已清除，床和电脑处于可互动状态。
	IDE_CHAT,       # 阶段4：电脑互动。打开全屏 UI，冻结真实玩家输入，进入对话。
	IDE_PREVIEW,    # 阶段5：预览测试。输入重定向至 SubViewport 微型场景。
	PHONE_RINGING,  # 阶段6：退出电脑。电话开始震动闪烁，玩家恢复移动。
	GLITCH_TRANSIT  # 阶段7：手机交互触发全屏 Shader 扭曲，准备切关。
}

var current_state: int = LevelState.LIVING_ROOM
var sleep_count: int = 0
var current_chat_index: int = 0

# 缓存玩家原始配置值（用于恢复）
var _original_jump_velocity: float = 0.0
var _original_dash_speed: float = 0.0
var _original_attack_damage: int = 0

# UI 节点引用
@onready var _narrative_panel: Panel = null
@onready var _narrative_text: RichTextLabel = null
@onready var _sleep_overlay: ColorRect = null
@onready var _ide_ui: Control = null
@onready var _chat_window: RichTextLabel = null
@onready var _viewport_container: SubViewportContainer = null
@onready var _mini_viewport: SubViewport = null
@onready var _glitch_overlay: ColorRect = null

# 交互物引用
var _obstacle_box: InteractiveObject = null
var _obstacle_clothes: InteractiveObject = null
var _bed_node: InteractiveObject = null
var _computer_node: InteractiveObject = null
var _phone_node: InteractiveObject = null

# 交互冷却（控制器级别，防重复触发）
var _interact_cooldown: float = 0.0
# 全局交互锁：同一时间只允许一个交互进行（叙事/睡眠/IDE/预览期间禁止其他交互）
var _is_interacting: bool = false


# ---- 生命周期 ----

func _on_ready() -> void:
	super._on_ready()
	
	# 0. 启用控制器的 input 处理（核心: 统一在此处理所有交互输入）
	#    取代 InteractiveObject 上的 _input（动态创建节点的 _input 不可靠）
	set_process_input(true)
	set_process_unhandled_input(true)
	
	# 1. 确保关卡配置已加载
	if not level_config:
		level_config = load("res://DataConfig/Level/Level01Config.tres") as LevelConfig
		_apply_config()
	
	# 2. 加载关卡数据资源
	if not level_data:
		level_data = load("res://DataConfig/Level/Level01Data.tres") as Level01Data
	
	# 3. 构建场景结构
	_build_scene_structure()
	
	# 4. 缓存 UI 节点引用
	_cache_ui_refs()
	
	# 5. 禁用玩家除移动外的所有能力
	_restrict_player_mechanics()
	
	# 6. 初始化交互物状态
	_phone_node.is_active = false
	
	# 7. 订阅 EventBus 交互信号
	EventBus.subscribe("interactive_object_triggered", self, "_on_object_interacted")
	
	print("[Level_01] ========================================")
	print("[Level_01] 关卡初始化完成")
	print("[Level_01] 当前状态: LIVING_ROOM")
	print("[Level_01] 可交互物: box(纸箱)")
	print("[Level_01] 操作: 走向右侧灰色方块，按 Enter 交互")
	print("[Level_01] ========================================")


# ---- 场景结构构建 ----

func _build_scene_structure() -> void:
	_build_terrain_segment()
	_build_interactive_objects()
	_build_spawn_points()
	_build_canvas_ui()


func _build_terrain_segment() -> void:
	# 创建 Terrain 根节点
	var terrain = _get_or_create_child("Terrain", Node2D)
	
	# 主地面 Y=620, X=0~1500
	var ground = _create_static_body("MainGround", Vector2(750, 620), Vector2(1500, 40), Color(0.3, 0.28, 0.25))
	terrain.add_child(ground)
	
	# 左墙 X=-20
	var left_wall = _create_static_body("LeftWall", Vector2(-20, 360), Vector2(20, 720), Color(0.25, 0.23, 0.2))
	terrain.add_child(left_wall)
	
	# 右墙 X=1520
	var right_wall = _create_static_body("RightWall", Vector2(1520, 360), Vector2(20, 720), Color(0.25, 0.23, 0.2))
	terrain.add_child(right_wall)


func _build_interactive_objects() -> void:
	var container = _get_or_create_child("InteractiveObjects", Node2D)
	
	# --- Obstacle_Box: 客厅纸箱 (Area2D + StaticBody2D 物理阻挡) ---
	_obstacle_box = _create_interactive("Obstacle_Box", "box", Vector2(500, 580), Vector2(120, 80))
	_add_physics_blocker(_obstacle_box, Vector2(120, 80))
	container.add_child(_obstacle_box)
	
	# --- Obstacle_Clothes: 走廊衣服 (Area2D + StaticBody2D 物理阻挡) ---
	_obstacle_clothes = _create_interactive("Obstacle_Clothes", "clothes", Vector2(850, 580), Vector2(100, 80))
	_add_physics_blocker(_obstacle_clothes, Vector2(100, 80))
	container.add_child(_obstacle_clothes)
	
	# --- Bed: 卧室床 (X=1300, allow_repeat — 可多次睡眠) ---
	_bed_node = _create_interactive("Bed", "bed", Vector2(1300, 580), Vector2(160, 60))
	_bed_node.allow_repeat = true
	container.add_child(_bed_node)
	
	# --- Computer: 电脑 (X=1100, 仅交互无阻挡) ---
	_computer_node = _create_interactive("Computer", "computer", Vector2(1100, 550), Vector2(80, 60))
	container.add_child(_computer_node)
	
	# --- Phone: 手机 (X=1050, 初始不激活) ---
	_phone_node = _create_interactive("Phone", "phone", Vector2(1050, 570), Vector2(50, 40))
	_phone_node.is_active = false
	container.add_child(_phone_node)


func _build_spawn_points() -> void:
	var spawn_container = _get_or_create_child("SpawnPoints", Node2D)
	var spawn_marker = Marker2D.new()
	spawn_marker.name = "PlayerSpawnPoint"
	spawn_marker.position = Vector2(100, 550)
	spawn_container.add_child(spawn_marker)
	player_spawn_point = spawn_marker


func _build_canvas_ui() -> void:
	var canvas = _get_or_create_child("CanvasLayerUI", CanvasLayer)
	canvas.layer = 2  # 确保在所有内容之上
	canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	
	# --- SleepOverlay: 睡眠黑屏（最先添加=最低层，确保 NarrativePanel 在上层可见）---
	_build_sleep_overlay(canvas)
	
	# --- NarrativePanel: 底部叙事面板（后添加=上层，睡眠对话可正常显示）---
	_build_narrative_panel(canvas)
	
	# --- IdeUI: 全屏 IDE 界面 ---
	_build_ide_ui(canvas)
	
	# --- GlitchOverlay: Shader 故障效果（最后添加=最上层）---
	_build_glitch_overlay(canvas)


func _build_sleep_overlay(canvas: CanvasLayer) -> void:
	var overlay = ColorRect.new()
	overlay.name = "SleepOverlay"
	overlay.visible = false
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(overlay)
	_sleep_overlay = overlay


func _build_narrative_panel(canvas: CanvasLayer) -> void:
	var panel = Panel.new()
	panel.name = "NarrativePanel"
	panel.visible = false
	panel.size = Vector2(1280, 200)
	panel.position = Vector2(0, 520)
	
	# 半透明深色背景
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.85)
	style.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", style)
	
	# 文本标签
	var label = RichTextLabel.new()
	label.name = "RichTextLabel"
	label.size = Vector2(1240, 160)
	label.position = Vector2(20, 20)
	label.bbcode_enabled = true
	label.fit_content = true
	label.add_theme_font_size_override("normal_font_size", 18)
	label.add_theme_color_override("default_color", Color(0.9, 0.85, 0.75))
	panel.add_child(label)
	_narrative_text = label
	
	canvas.add_child(panel)
	_narrative_panel = panel


func _build_ide_ui(canvas: CanvasLayer) -> void:
	var ide = Control.new()
	ide.name = "IdeUI"
	ide.visible = false
	ide.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	# 深色全屏 IDE 背景
	var bg = ColorRect.new()
	bg.name = "Background"
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.06, 0.07, 0.1, 0.97)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ide.add_child(bg)
	
	# ---- 标题栏 ----
	var title_bar = ColorRect.new()
	title_bar.name = "TitleBar"
	title_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title_bar.color = Color(0.1, 0.12, 0.18, 1.0)
	title_bar.size = Vector2(0, 40)
	ide.add_child(title_bar)
	
	var title_label = Label.new()
	title_label.name = "TitleLabel"
	title_label.text = "◆ AI IDE v0.1-Beta — localhost:8080"
	title_label.add_theme_font_size_override("font_size", 15)
	title_label.add_theme_color_override("font_color", Color(0.4, 0.85, 0.5))
	title_label.position = Vector2(15, 10)
	ide.add_child(title_label)
	
	# ---- 聊天面板（带边框的 Panel） ----
	var chat_panel = Panel.new()
	chat_panel.name = "ChatPanel"
	chat_panel.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	chat_panel.anchor_right = 0.5
	chat_panel.offset_left = 20
	chat_panel.offset_top = 55
	chat_panel.offset_right = -15
	chat_panel.offset_bottom = -25
	
	var chat_style = StyleBoxFlat.new()
	chat_style.bg_color = Color(0.08, 0.1, 0.14, 0.9)
	chat_style.border_width_left = 2
	chat_style.border_width_right = 2
	chat_style.border_width_top = 2
	chat_style.border_width_bottom = 2
	chat_style.border_color = Color(0.2, 0.25, 0.35)
	chat_style.set_corner_radius_all(6)
	chat_panel.add_theme_stylebox_override("panel", chat_style)
	ide.add_child(chat_panel)
	
	# 聊天标签页指示
	var tab_label = Label.new()
	tab_label.name = "TabLabel"
	tab_label.text = "  Terminal / Chat  "
	tab_label.add_theme_font_size_override("font_size", 12)
	tab_label.add_theme_color_override("font_color", Color(0.5, 0.6, 0.7))
	tab_label.position = Vector2(30, 42)
	ide.add_child(tab_label)
	
	# 聊天窗口
	var chat = RichTextLabel.new()
	chat.name = "ChatWindow"
	chat.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	chat.anchor_right = 0.5
	chat.offset_left = 30
	chat.offset_top = 68
	chat.offset_right = -25
	chat.offset_bottom = -35
	chat.bbcode_enabled = true
	chat.scroll_following = true
	chat.add_theme_font_size_override("normal_font_size", 15)
	chat.add_theme_color_override("default_color", Color(0.85, 0.85, 0.85))
	ide.add_child(chat)
	_chat_window = chat
	
	# ---- 预览面板 ----
	var preview_panel = Panel.new()
	preview_panel.name = "PreviewPanel"
	preview_panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	preview_panel.anchor_left = 0.52
	preview_panel.offset_left = 15
	preview_panel.offset_top = 55
	preview_panel.offset_right = -20
	preview_panel.offset_bottom = -25
	
	var preview_style = StyleBoxFlat.new()
	preview_style.bg_color = Color(0.08, 0.1, 0.14, 0.9)
	preview_style.border_width_left = 2
	preview_style.border_width_right = 2
	preview_style.border_width_top = 2
	preview_style.border_width_bottom = 2
	preview_style.border_color = Color(0.2, 0.25, 0.35)
	preview_style.set_corner_radius_all(6)
	preview_panel.add_theme_stylebox_override("panel", preview_style)
	ide.add_child(preview_panel)
	
	# 预览标签页
	var preview_tab = Label.new()
	preview_tab.name = "PreviewTab"
	preview_tab.text = "  Local Test Viewport  "
	preview_tab.add_theme_font_size_override("font_size", 12)
	preview_tab.add_theme_color_override("font_color", Color(0.5, 0.6, 0.7))
	preview_tab.position = Vector2(678, 42)
	ide.add_child(preview_tab)
	
	# ViewportContainer
	var viewport_container = SubViewportContainer.new()
	viewport_container.name = "ViewportContainer"
	viewport_container.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	viewport_container.anchor_left = 0.52
	viewport_container.offset_left = 25
	viewport_container.offset_top = 68
	viewport_container.offset_right = -30
	viewport_container.offset_bottom = -35
	viewport_container.stretch = true
	
	var mini_viewport = SubViewport.new()
	mini_viewport.name = "MiniViewport"
	mini_viewport.size = Vector2(600, 400)
	mini_viewport.transparent_bg = true
	viewport_container.add_child(mini_viewport)
	_mini_viewport = mini_viewport
	_viewport_container = viewport_container
	
	ide.add_child(viewport_container)
	
	# ---- 状态栏 ----
	var status_bar = ColorRect.new()
	status_bar.name = "StatusBar"
	status_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	status_bar.color = Color(0.1, 0.12, 0.18, 1.0)
	status_bar.size = Vector2(0, 22)
	ide.add_child(status_bar)
	
	canvas.add_child(ide)
	_ide_ui = ide


func _build_glitch_overlay(canvas: CanvasLayer) -> void:
	var overlay = ColorRect.new()
	overlay.name = "GlitchOverlay"
	overlay.visible = false
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# 加载并应用 Shader
	var shader = load("res://LevelModule/Formal/glitch_effect.gdshader")
	if shader:
		var mat = ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter("intensity", 0.0)
		overlay.material = mat
	
	canvas.add_child(overlay)
	_glitch_overlay = overlay


# ---- 工具方法 ----

func _get_or_create_child(node_name: String, node_type) -> Node:
	var existing = get_node_or_null(node_name)
	if existing:
		return existing
	var node = node_type.new()
	node.name = node_name
	add_child(node)
	return node


func _create_static_body(node_name: String, pos: Vector2, size: Vector2, col: Color) -> StaticBody2D:
	var body = StaticBody2D.new()
	body.name = node_name
	body.position = pos
	body.collision_layer = 1
	body.collision_mask = 0
	
	var col_shape = CollisionShape2D.new()
	var rect_shape = RectangleShape2D.new()
	rect_shape.size = size
	col_shape.shape = rect_shape
	col_shape.name = "CollisionShape2D"
	body.add_child(col_shape)
	
	var color_rect = ColorRect.new()
	color_rect.name = "ColorRect"
	color_rect.color = col
	color_rect.size = size
	color_rect.position = -size / 2
	body.add_child(color_rect)
	
	return body


func _create_interactive(node_name: String, obj_id: String, pos: Vector2, size: Vector2) -> InteractiveObject:
	var obj = InteractiveObject.new()
	obj.name = node_name
	obj.position = pos
	obj.object_id = obj_id
	obj.collision_layer = 0
	obj.collision_mask = 4  # 只检测玩家层
	
	# 检测区域必须大于物理阻挡区域，否则玩家被 StaticBody2D 挡住时
	# CharacterBody2D 无法进入 Area2D 范围，body_entered 永远不会触发
	# X 方向扩大到 2.5 倍（确保玩家被挡住时身体已进入检测范围）
	var col_shape = CollisionShape2D.new()
	col_shape.name = "CollisionShape2D"
	var rect_shape = RectangleShape2D.new()
	rect_shape.size = Vector2(size.x * 2.5, size.y * 1.1)
	col_shape.shape = rect_shape
	obj.add_child(col_shape)
	
	# 交互物视觉指示（保持原始大小，准确反映物体外观）
	var indicator = ColorRect.new()
	indicator.name = "Indicator"
	indicator.color = Color(0.5, 0.5, 0.5, 0.3)
	indicator.size = size
	indicator.position = -size / 2
	obj.add_child(indicator)
	
	return obj


func _add_physics_blocker(parent: Node2D, size: Vector2) -> void:
	var blocker = StaticBody2D.new()
	blocker.name = "StaticBody2D"
	blocker.collision_layer = 1
	blocker.collision_mask = 0
	blocker.position = Vector2.ZERO
	
	var col_shape = CollisionShape2D.new()
	col_shape.name = "CollisionShape2D"
	var rect = RectangleShape2D.new()
	rect.size = size
	col_shape.shape = rect
	blocker.add_child(col_shape)
	
	parent.add_child(blocker)


func _cache_ui_refs() -> void:
	var canvas = $CanvasLayerUI
	if not canvas:
		return
	
	_narrative_panel = canvas.get_node_or_null("NarrativePanel")
	if _narrative_panel:
		_narrative_text = _narrative_panel.get_node_or_null("RichTextLabel")
	
	# 睡眠覆盖层现在是 CanvasLayerUI 的直接子节点
	_sleep_overlay = canvas.get_node_or_null("SleepOverlay")
	
	_ide_ui = canvas.get_node_or_null("IdeUI")
	if _ide_ui:
		_chat_window = _ide_ui.get_node_or_null("ChatWindow")
		_viewport_container = _ide_ui.get_node_or_null("ViewportContainer")
		if _viewport_container:
			_mini_viewport = _viewport_container.get_node_or_null("MiniViewport")
	
	_glitch_overlay = canvas.get_node_or_null("GlitchOverlay")


# ---- 玩家能力限制与冻结 ----

## 禁用玩家除移动外的所有能力（只保留行走）
func _restrict_player_mechanics() -> void:
	var player = GameManager.player_ref
	if not player or not player.config:
		return
	
	# 缓存原始值
	_original_jump_velocity = player.config.jump_velocity
	_original_dash_speed = player.config.dash_speed
	_original_attack_damage = player.config.attack_damage
	
	# 禁用跳跃、冲刺、攻击
	player.config.jump_velocity = 0.0
	player.config.dash_speed = 0.0
	player.config.attack_damage = 0


## 恢复玩家能力
func _restore_player_mechanics() -> void:
	var player = GameManager.player_ref
	if not player or not player.config:
		return
	
	player.config.jump_velocity = _original_jump_velocity
	player.config.dash_speed = _original_dash_speed
	player.config.attack_damage = _original_attack_damage


## 冻结/解冻玩家实体
func _freeze_player(freeze: bool) -> void:
	var player = GameManager.player_ref
	if not player:
		return
	
	if freeze:
		player.velocity = Vector2.ZERO
		player.set_physics_process(false)
		player.set_process_input(false)
		player._change_state(GlobalDefine.PlayerState.IDLE)
	else:
		player.set_physics_process(true)
		player.set_process_input(true)


# ---- 控制器级 _input（统一交互入口）----

## Godot 4 中动态创建的子节点 _input() 不可靠，将所有交互输入集中到控制器处理
func _input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_accept"):
		return
	
	# 路径 1: IDE_CHAT 状态 → 推进对话
	if current_state == LevelState.IDE_CHAT:
		if level_data:
			print("[Level_01] IDE_CHAT: _input 推进对话 (%d/%d)" % [current_chat_index, level_data.ide_speakers.size()])
		_render_next_chat_line()
		get_viewport().set_input_as_handled()
		return
	
	# 路径 2: 全局交互锁 — 叙事/睡眠/IDE 进行时禁止新交互
	if _is_interacting:
		return
	
	if _interact_cooldown > 0.0:
		return
	
	var nearby_obj = _find_nearby_interactive()
	if nearby_obj:
		_interact_cooldown = 0.3
		print("[Level_01] _input 触发交互: %s" % nearby_obj.object_id)
		EventBus.emit("interactive_object_triggered", {"object_id": nearby_obj.object_id})
		get_viewport().set_input_as_handled()


## 在玩家附近的交互物中查找 is_player_in_range 且未完成的物体
## 关键：completed 物体不在候选范围内，避免已完成的物体遮挡未完成的物体
func _find_nearby_interactive() -> InteractiveObject:
	var candidates: Array[InteractiveObject] = [
		_obstacle_box,
		_obstacle_clothes,
		_bed_node,
		_computer_node,
		_phone_node,
	]
	for obj in candidates:
		# is_instance_valid 是关键: freed 对象在 Godot 中 "if obj" 仍为 true,
		# 但访问其属性会导致崩溃或类型检查失败
		# completed 过滤: 已完成物体从候选中排除，不对未完成物体产生遮挡干扰
		if is_instance_valid(obj) and obj.is_active and not obj.completed and obj.is_player_in_range:
			return obj
	return null


func _process(delta: float) -> void:
	if _interact_cooldown > 0.0:
		_interact_cooldown -= delta


# ---- FSM: 全局状态调度 ----

func _on_object_interacted(data: Dictionary) -> void:
	var obj_id: String = data.get("object_id", "")
	print("[Level_01] 收到交互事件: object_id=%s, 当前状态=%d" % [obj_id, current_state])
	
	# ---- 二次幂等性防线: FSM 入口再次检查完成状态 ----
	var obj_ref = _get_interactive_by_id(obj_id)
	if obj_ref and obj_ref.completed:
		print("[Level_01] 拦截重复交互: %s 在 FSM 入口已完成" % obj_id)
		return  # 拒绝已完成的交互
	
	match current_state:
		LevelState.LIVING_ROOM:
			if obj_id == "box":
				_handle_box_interaction()
			else:
				print("[Level_01] LIVING_ROOM 状态下不支持与 '%s' 交互" % obj_id)
		
		LevelState.CORRIDOR:
			if obj_id == "clothes":
				_handle_clothes_interaction()
			else:
				print("[Level_01] CORRIDOR 状态下不支持与 '%s' 交互" % obj_id)
		
		LevelState.BEDROOM:
			if obj_id == "bed":
				_trigger_sleep_cycle()
			elif obj_id == "computer":
				_enter_ide_mode()
			else:
				print("[Level_01] BEDROOM 状态下不支持与 '%s' 交互" % obj_id)
		
		LevelState.PHONE_RINGING:
			if obj_id == "phone":
				_trigger_climax_transition()
			else:
				print("[Level_01] PHONE_RINGING 状态下不支持与 '%s' 交互" % obj_id)
		
		_:
			print("[Level_01] 当前状态 %d 下无交互处理" % current_state)


## 根据 object_id 查找对应的交互物引用
func _get_interactive_by_id(obj_id: String) -> InteractiveObject:
	match obj_id:
		"box":      return _obstacle_box
		"clothes":  return _obstacle_clothes
		"bed":      return _bed_node
		"computer": return _computer_node
		"phone":    return _phone_node
	return null


## 标记指定交互物为已完成（幂等性保障）
func _mark_interaction_completed(obj_id: String) -> void:
	var obj = _get_interactive_by_id(obj_id)
	if obj and not obj.allow_repeat:
		obj.mark_completed()
		print("[Level_01] 交互完成锁定: %s" % obj_id)


func _handle_box_interaction() -> void:
	if not level_data:
		printerr("[Level_01] level_data 为 null，无法显示纸箱叙事文本")
		return
	_mark_interaction_completed("box")
	_show_narrative(level_data.obstacle_1_text, func():
		_clear_obstacle(_obstacle_box)
		current_state = LevelState.CORRIDOR
		print("[Level_01] 纸箱清除，进入走廊阶段")
	)


func _handle_clothes_interaction() -> void:
	if not level_data:
		printerr("[Level_01] level_data 为 null，无法显示衣服叙事文本")
		return
	_mark_interaction_completed("clothes")
	_show_narrative(level_data.obstacle_2_text, func():
		_clear_obstacle(_obstacle_clothes)
		current_state = LevelState.BEDROOM
		print("[Level_01] 衣服清除，进入卧室阶段")
	)


# ---- 障碍物清除 ----

func _clear_obstacle(obstacle_node: InteractiveObject) -> void:
	# is_instance_valid 检查：freed 对象不等于 null，但 is_instance_valid 返回 false
	if not is_instance_valid(obstacle_node):
		printerr("[Level_01] _clear_obstacle 收到已释放的实例，跳过")
		return
	
	obstacle_node.is_active = false
	
	# 禁用物理碰撞
	var static_body = obstacle_node.get_node_or_null("StaticBody2D")
	if static_body:
		var col_shape = static_body.get_node_or_null("CollisionShape2D")
		if col_shape:
			col_shape.disabled = true
	
	# 清空对应成员变量，避免后续遍历时访问已释放的引用
	_match_and_clear_ref(obstacle_node)
	
	# 渐隐动效
	var tween = create_tween()
	tween.tween_property(obstacle_node, "modulate:a", 0.0, 0.5)
	tween.finished.connect(func():
		if is_instance_valid(obstacle_node):
			obstacle_node.queue_free()
	)


## 将障碍物引用置空，防止 _find_nearby_interactive 遍历到已释放对象
func _match_and_clear_ref(node: InteractiveObject) -> void:
	if node == _obstacle_box:
		_obstacle_box = null
	elif node == _obstacle_clothes:
		_obstacle_clothes = null


# ---- 叙事面板显示 ----

func _show_narrative(text: String, callback: Callable = Callable()) -> void:
	_is_interacting = true
	_freeze_player(true)
	if _narrative_panel:
		_narrative_panel.show()
		if _narrative_text:
			_narrative_text.text = text
	
	# 等待玩家按下确认键
	await get_tree().create_timer(0.3).timeout
	while true:
		if Input.is_action_just_pressed("ui_accept"):
			break
		await get_tree().process_frame
	
	if _narrative_panel:
		_narrative_panel.hide()
	
	_freeze_player(false)
	
	if callback.is_valid():
		callback.call()
	
	_is_interacting = false


# ---- 睡眠循环 ----

func _trigger_sleep_cycle() -> void:
	if not level_data:
		printerr("[Level_01] level_data 为 null，无法执行睡眠循环")
		return
	
	# 立即锁定床的完成状态，防止睡眠流程中（特别是 fade-out 期间）重复触发
	_bed_node.completed = true
	_is_interacting = true
	_freeze_player(true)
	
	var sleep_text: String
	if level_data.sleep_texts.is_empty():
		sleep_text = "……"
	elif sleep_count < level_data.sleep_texts.size():
		sleep_text = level_data.sleep_texts[sleep_count]
	else:
		sleep_text = level_data.sleep_texts[-1]
	
	sleep_count += 1
	print("[Level_01] 睡眠第 %d 次" % sleep_count)
	
	# 变黑转场
	if _sleep_overlay:
		_sleep_overlay.color.a = 0.0
		_sleep_overlay.show()
		var tween = create_tween()
		tween.tween_property(_sleep_overlay, "color:a", 1.0, 1.0)
		await tween.finished
	
	# 展示睡眠独白
	_show_narrative(sleep_text, func():
		# 变亮唤醒 → 结束后才解冻
		if _sleep_overlay:
			var tween_back = create_tween()
			tween_back.tween_property(_sleep_overlay, "color:a", 0.0, 1.0)
			tween_back.finished.connect(func():
				if _sleep_overlay:
					_sleep_overlay.hide()
				_freeze_player(false)
				# 重置床的完成状态，允许再次睡眠
				_bed_node.reset_completed()
			)
		else:
			_freeze_player(false)
			_bed_node.reset_completed()
	)


# ---- IDE 电脑模式 ----

func _enter_ide_mode() -> void:
	_mark_interaction_completed("computer")
	_is_interacting = true
	current_state = LevelState.IDE_CHAT
	_freeze_player(true)
	
	if _ide_ui:
		_ide_ui.show()
	
	current_chat_index = 0
	if _chat_window:
		_chat_window.text = ""
	
	_render_next_chat_line()
	print("[Level_01] 进入 IDE 聊天模式")


func _render_next_chat_line() -> void:
	if not level_data:
		printerr("[Level_01] level_data 为 null，无法渲染对话")
		_start_ide_viewport_preview()
		return
	
	var total = mini(level_data.ide_speakers.size(), level_data.ide_texts.size())
	if current_chat_index >= total:
		_start_ide_viewport_preview()
		return
	
	var speaker: String = level_data.ide_speakers[current_chat_index]
	var text: String = level_data.ide_texts[current_chat_index]
	
	var format_text: String = ""
	match speaker:
		"System":
			format_text = "[color=yellow][SYSTEM] " + text + "[/color]\n"
		"AI":
			format_text = "[color=cyan]AI: " + text + "[/color]\n"
		"Ming":
			format_text = "[color=white]阿明: " + text + "[/color]\n"
		_:
			format_text = text + "\n"
	
	if _chat_window:
		_chat_window.append_text(format_text)
	
	current_chat_index += 1


# ---- IDE 视口预览 ----

func _start_ide_viewport_preview() -> void:
	current_state = LevelState.IDE_PREVIEW
	
	if _chat_window:
		_chat_window.append_text("[color=green][SYSTEM] 正在启动 Local Test Viewport...[/color]\n")
	
	# 动态实例化微型场景
	var mini_scene_path = "res://LevelModule/SelfTest/MiniTestWorld.tscn"
	if not ResourceLoader.exists(mini_scene_path):
		if _chat_window:
			_chat_window.append_text("[color=red][FATAL ERROR] 找不到 MiniTestWorld.tscn[/color]\n")
		_on_preview_crashed()
		return
	
	var mini_world_scene = load(mini_scene_path)
	# ResourceLoader.exists 可能返回 true 但 load() 因解析错误返回 null
	if not mini_world_scene:
		if _chat_window:
			_chat_window.append_text("[color=red][FATAL ERROR] MiniTestWorld.tscn 加载失败 (null)[/color]\n")
		_on_preview_crashed()
		return
	
	var mini_world = mini_world_scene.instantiate()
	
	if _mini_viewport:
		_mini_viewport.add_child(mini_world)
	
	# 监听微型世界的边界崩溃信号
	if mini_world.has_signal("prototype_crashed"):
		mini_world.connect("prototype_crashed", _on_preview_crashed)
	
	print("[Level_01] 进入 IDE 预览模式")


func _on_preview_crashed() -> void:
	if _chat_window:
		_chat_window.append_text("[color=red][FATAL ERROR] 线程溢出: 'Xiguan_Dream' 崩溃。[/color]\n")
		_chat_window.append_text("[color=red][SYSTEM] 连接中断。物理交互环境已强行关闭。[/color]\n")
	
	await get_tree().create_timer(1.5).timeout
	
	# 清理 Viewport 子节点
	if _mini_viewport:
		for child in _mini_viewport.get_children():
			child.queue_free()
	
	# 关闭 IDE UI
	if _ide_ui:
		_ide_ui.hide()
	
	# 进入手机震动阶段
	current_state = LevelState.PHONE_RINGING
	if _phone_node:
		_phone_node.is_active = true
		_start_phone_vibration()
	
	_freeze_player(false)  # 解冻真实世界玩家
	_is_interacting = false  # 释放交互锁
	print("[Level_01] 进入手机震动阶段")


# ---- 手机震动动画（Tween 实现，无需 AnimationPlayer） ----

var _phone_vibrate_tween: Tween = null

func _start_phone_vibration() -> void:
	if not _phone_node:
		return
	
	_phone_vibrate_tween = create_tween()
	_phone_vibrate_tween.set_loops()
	
	var base_pos = _phone_node.position
	var amplitude = 3.0
	var speed = 0.05
	
	_phone_vibrate_tween.tween_property(_phone_node, "position:x", base_pos.x + amplitude, speed)
	_phone_vibrate_tween.tween_property(_phone_node, "position:x", base_pos.x - amplitude, speed)
	_phone_vibrate_tween.tween_property(_phone_node, "position:x", base_pos.x + amplitude * 0.5, speed)
	_phone_vibrate_tween.tween_property(_phone_node, "position:x", base_pos.x, speed)


func _stop_phone_vibration() -> void:
	if _phone_vibrate_tween and is_instance_valid(_phone_vibrate_tween):
		_phone_vibrate_tween.kill()
		_phone_vibrate_tween = null


# ---- 终局 Shader 转折 ----

func _trigger_climax_transition() -> void:
	if not level_data:
		printerr("[Level_01] level_data 为 null，跳过手机终局")
		_start_glitch_shader_effect()
		return
	
	_mark_interaction_completed("phone")
	_freeze_player(true)
	
	var message = level_data.phone_sender + ":\n" + level_data.phone_content
	
	_show_narrative(message, func():
		# 手机震动停止
		_stop_phone_vibration()
		
		# 启动 Shader 故障扭曲效果
		_start_glitch_shader_effect()
	)


func _start_glitch_shader_effect() -> void:
	if not _glitch_overlay:
		# 如果没有 shader overlay，直接触发切关
		EventBus.emit(GlobalDefine.EventName.LEVEL_COMPLETE, {
			"level": self,
			"next_level": "res://LevelModule/Formal/Level_02.tscn"
		})
		return
	
	_glitch_overlay.show()
	
	# 创建 Shader 强度渐变
	var tween = create_tween()
	tween.tween_property(_glitch_overlay.material, "shader_parameter/intensity", 1.0, 2.0)
	
	await tween.finished
	
	# 加载下一关
	EventBus.emit(GlobalDefine.EventName.LEVEL_COMPLETE, {
		"level": self,
		"next_level": "res://LevelModule/Formal/Level_02.tscn"
	})
