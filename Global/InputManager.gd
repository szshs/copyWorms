# ============================================================
# InputManager.gd - 统一输入管理器 (Autoload, PROCESS_MODE_ALWAYS)
#
# 阶段3(当前): 全面接管游戏操作输入 + 输入屏蔽 + 信号分发
#
# 职责:
#   1. 全局快捷键(ESC暂停) — 独占处理, 不受 pause 影响
#   2. 游戏操作信号分发(attack/dash/skill/accept) — 通过 game_action 信号
#   3. 输入屏蔽 — 暂停/对话/叙事时自动阻断所有游戏操作
#   4. 使用 _input + CanvasLayer GUI 检测 — 鼠标在 HUD 按钮上时不触发游戏操作
#
# 不接管(保留原有轮询):
#   - player_jump: 变高跳需要 is_action_pressed 连续状态
#   - ui_left/right/up/down: 移动需要 get_vector() 每帧向量值
#
# 使用方式(订阅者):
#   InputManager.game_action.connect(_on_game_action)
#   func _on_game_action(action: StringName, event: InputEvent): ...
#
# 屏蔽方式(外部模块):
#   InputManager.block_input("对话中", self)   # 阻断所有游戏操作
#   InputManager.unblock_input("对话结束")      # 解除阻断
# ============================================================
extends Node

## 游戏操作输入信号（仅未屏蔽 + 未暂停 + 无 UI 焦点时发射）
## 订阅者: PlayerBase(attack/dash/skill), Level_01(ui_accept)
signal game_action(action: StringName, event: InputEvent)

## 输入屏蔽标志
var is_input_blocked: bool = false

## 屏蔽原因（调试用，显示最外层屏蔽来源）
var block_reason: String = ""

## 屏蔽引用计数（栈式: block++, unblock--; 为0时才真正解除）
var _block_count: int = 0

## 暂停切换允许标志（按键设置界面打开时禁止）
var _pause_allowed: bool = true

## 本帧捕获的动作（用于外部查询）
var captured_this_frame: StringName = &""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

# ================================================================
#  核心输入处理
# ================================================================

func _input(event: InputEvent) -> void:
	# ---- 全局快捷键（始终响应，不受守卫影响）----
	
	if event.is_action_pressed("ui_pause"):
		if _pause_allowed:
			_handle_pause()
		return
	
	# ---- 守卫检查 ----
	if _should_block_game_input():
		return
	
	# ---- 鼠标事件：鼠标在可交互 GUI 控件上时不分发游戏操作 ----
	if event is InputEventMouseButton:
		if _is_mouse_over_interactive_gui(event as InputEventMouse):
			return
	
	# ---- 游戏操作键识别与分发 ----
	var action := _identify_game_action(event)
	if action != &"":
		_emit_action(action, event)

# ================================================================
#  守卫逻辑
# ================================================================

## 判断是否应该阻断游戏操作输入
func _should_block_game_input() -> bool:
	if GameManager.is_paused:
		return true
	if is_input_blocked:
		return true
	if _is_ui_focused():
		return true
	return false

## 检测 UI 焦点是否在 Control 节点上
func _is_ui_focused() -> bool:
	var focused = get_viewport().gui_get_focus_owner()
	return focused != null and focused is Control

## 检测鼠标是否在可交互的 GUI 控件上（mouse_filter != IGNORE）
## 策略: 只检查"真正的 UI 区域"，跳过 Node2D 场景中的装饰性 Control
##   - CanvasLayer 子树: HUD 按钮、暂停面板等（可能嵌套在 Node2D 场景根内）
##   - Control 场景根: TitleScreen 等纯 UI 场景
##   - 不检查 Node2D 下的 Control: 关卡地形 ColorRect 等装饰节点
func _is_mouse_over_interactive_gui(event: InputEventMouse) -> bool:
	var vp = get_viewport()
	if not vp:
		return false
	var mouse_pos = event.global_position
	for child in vp.get_children():
		if child is Control:
			# Control 场景根 (TitleScreen) → 检查整个子树
			if _find_interactive_control_at_pos(child, mouse_pos):
				return true
		elif child is CanvasLayer:
			# 直接 CanvasLayer 子节点 → 检查整个子树
			if _find_interactive_control_at_pos(child, mouse_pos):
				return true
		else:
			# Node2D 场景根 → 只穿透查找嵌套的 CanvasLayer，不检查其下的 Control
			if _find_canvas_layer_gui_at_pos(child, mouse_pos):
				return true
	return false

## 在节点子树中查找鼠标位置下的可交互 Control（完整递归）
func _find_interactive_control_at_pos(node: Node, pos: Vector2) -> bool:
	if node is Control:
		var ctrl = node as Control
		if ctrl.visible and ctrl.mouse_filter != Control.MOUSE_FILTER_IGNORE:
			if ctrl.get_global_rect().has_point(pos):
				return true
	for child in node.get_children():
		if _find_interactive_control_at_pos(child, pos):
			return true
	return false

## 在 Node2D 场景根中穿透查找 CanvasLayer，找到后检查其子树的交互控件
## 关键: 跳过 Node2D 下的 Control（地形 ColorRect），只进入 CanvasLayer 子树
func _find_canvas_layer_gui_at_pos(node: Node, pos: Vector2) -> bool:
	for child in node.get_children():
		if child is CanvasLayer:
			if _find_interactive_control_at_pos(child, pos):
				return true
		# 继续递归查找更深层的 CanvasLayer
		if _find_canvas_layer_gui_at_pos(child, pos):
			return true
	return false



# ================================================================
#  信号发射
# ================================================================

func _emit_action(action: StringName, event: InputEvent) -> void:
	game_action.emit(action, event)
	captured_this_frame = action
	get_viewport().set_input_as_handled()

# ================================================================
#  ESC 暂停处理（独占）
# ================================================================

func _handle_pause() -> void:
	var was_paused := GameManager.is_paused
	GameManager.toggle_pause()
	get_viewport().set_input_as_handled()

# ================================================================
#  日志
# ================================================================

# (已清理测试日志输出)

# ================================================================
#  动作识别（不包含 jump 和方向键，保留原轮询）
# ================================================================

func _identify_game_action(event: InputEvent) -> StringName:
	if event.is_action_pressed("player_attack"):   return &"player_attack"
	if event.is_action_pressed("player_dash"):     return &"player_dash"
	if event.is_action_pressed("player_skill"):    return &"player_skill"
	if event.is_action_pressed("ui_accept"):       return &"ui_accept"
	return &""

func _get_ui_focus_info() -> String:
	var focused = get_viewport().gui_get_focus_owner()
	if focused == null:
		return "none"
	return "%s(%s)" % [focused.name, focused.get_class()]

# ================================================================
#  公共 API: 输入屏蔽
# ================================================================

## 请求屏蔽游戏输入（栈式: 支持嵌套调用，每次 block 必须配对 unblock）
func block_input(reason: String, _caller: Node = null) -> void:
	_block_count += 1
	if not is_input_blocked:
		block_reason = reason
	is_input_blocked = true

## 取消屏蔽游戏输入（栈式: 引用计数归零时才真正解除，防止内层提前释放外层）
func unblock_input(_reason: String = "") -> void:
	_block_count = maxi(_block_count - 1, 0)
	if _block_count <= 0:
		is_input_blocked = false
		block_reason = ""
		_block_count = 0

## 设置是否允许暂停切换（按键设置界面打开时设为 false，关闭时恢复 true）
func set_pause_allowed(allowed: bool) -> void:
	_pause_allowed = allowed
