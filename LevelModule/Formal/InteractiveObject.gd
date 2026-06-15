# ============================================================
# InteractiveObject.gd - 交互物基类 (Area2D → InteractiveObject)
#
# 职责:
#   1. 碰撞检测: body_entered/exited 信号 + _process 轮询双重保障
#   2. 视觉提示: 呼吸闪烁 Label（未完成=黄字, 完成=灰字）
#   3. 状态追踪: completed(幂等性) / is_active(前置解锁) / allow_repeat
#   4. 冻结管理: freeze_monitoring() 禁用/恢复 monitoring, 防 body_exited 误触发
#
# 输入处理设计(v0.4.0变更):
#   本类 _process() 不再检测 ui_accept 输入。所有交互输入统一由:
#     Level_01._input() → _find_nearby_interactive() → EventBus.emit()
#   这解决了三路重复触发问题(原 InteractiveObject._process 也检测 Enter)。
#   设计关键点: 动态创建节点的 _input() 在 Godot 中不可靠,
#   统一收归 Level_01 控制器分发是更稳定的架构。
#
# 双重检测机制:
#   主路径: Area2D body_entered/exited 信号 (帧精度)
#   兜底路径: _process 中 check_player_in_range AABB 轮询 (解决 _ready 时序问题)
# ============================================================
extends Area2D
class_name InteractiveObject

signal player_entered
signal player_exited

## 编辑器配置: "box", "clothes", "bed", "computer", "phone"
@export var object_id: String = ""
@export var is_active: bool = true
@export var prompt_text: String = "按 Enter 交互"
## 是否允许重复交互（如床可多次睡眠）
@export var allow_repeat: bool = false

## 幂等性核心: 交互完成标志，完成后再触发直接拒绝
var completed: bool = false
var is_player_in_range: bool = false
var _prompt_label: Label = null


func _ready() -> void:
	# Area2D 配置
	monitoring = true       # 检测其他 body 进入
	monitorable = false     # 自身不被其他 area 检测

	# 连接信号
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	# 创建交互提示标签
	_create_prompt_label()


## 冻结感知: 关卡控制玩家冻结时调用,禁用 monitoring 防止冻结期 body_exited 误触发
## 解冻时恢复 monitoring;但 is_player_in_range 需要在解冻后立刻重算
var _frozen_cached_range: bool = false
func freeze_monitoring(frozen: bool) -> void:
	if frozen:
		# 缓存当前 in_range 状态(冻结时不会丢失玩家进入信息)
		_frozen_cached_range = is_player_in_range
		monitoring = false
	else:
		monitoring = true
		# 解冻时若玩家仍在范围内,_on_body_entered 不会重发(物理体未重新进入)
		# 显式恢复 is_player_in_range
		is_player_in_range = _frozen_cached_range


func _create_prompt_label() -> void:
	_prompt_label = Label.new()
	_prompt_label.name = "InteractionPrompt"
	_prompt_label.text = prompt_text
	_prompt_label.visible = false
	_prompt_label.add_theme_font_size_override("font_size", 14)
	_prompt_label.add_theme_color_override("font_color", Color(1, 0.9, 0.2, 0.95))
	_prompt_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# 显示在物体上方 50px，居中
	_prompt_label.position = Vector2(-80, -55)
	_prompt_label.size = Vector2(160, 20)
	add_child(_prompt_label)


func _process(_delta: float) -> void:
	if not _prompt_label:
		return
	
	if not is_active or not is_player_in_range or completed:
		_prompt_label.visible = false
		return
	
	_prompt_label.visible = true
	_prompt_label.text = prompt_text
	var alpha = 0.6 + 0.4 * abs(sin(Time.get_ticks_msec() * 0.004))
	_prompt_label.add_theme_color_override("font_color", Color(1, 0.9, 0.2, alpha))

	# 输入处理已统一收归 Level_01._input() 分发
	# 此处不再检测 ui_accept，避免与 Level_01 双重触发交互事件


# ---- 碰撞检测 ----

func _on_body_entered(body: Node2D) -> void:
	if not is_active:
		return
	# B8 修复: 强化玩家识别 — 即使 collision_layer 位运算失败也尝试按 group/name 兜底
	if _is_player(body):
		is_player_in_range = true
		player_entered.emit()
		print("[InteractiveObject] 玩家进入 %s 范围%s" % [object_id, " [已完成]" if completed else ""])


func _on_body_exited(body: Node2D) -> void:
	if _is_player(body):
		is_player_in_range = false
		player_exited.emit()
		print("[InteractiveObject] 玩家离开 %s 范围" % object_id)


## 玩家身份校验（双保险）:
##   1) 必须是 CharacterBody2D
##   2) collision_layer 包含 PLAYER 位
##   3) 兜底: 若 collision_layer == 0 则按 group "player" 识别
##      (兼容 PlayerBase._ready 中忘记设置 collision_layer 的场景)
func _is_player(body: Node2D) -> bool:
	if not body is CharacterBody2D:
		return false
	if body.collision_layer & GlobalDefine.Collision.PLAYER:
		return true
	# 兜底识别
	if body.is_in_group("player"):
		return true
	return false

## 主动距离检测（轮询式）— 解决 body_entered 信号在 _ready 时序或 collision_layer 不匹配下失效
## 调用方在 _process 中遍历,传入玩家位置;若玩家在触发区内则 is_player_in_range=true
func check_player_in_range(player: Node2D) -> void:
	if not is_active or not player or not is_instance_valid(player):
		is_player_in_range = false
		return
	var in_range: bool = _rect_overlaps_player(player)
	if in_range != is_player_in_range:
		is_player_in_range = in_range
		if in_range:
			player_entered.emit()
			print("[InteractiveObject] 玩家进入 %s 范围%s (轮询检测)" % [object_id, " [已完成]" if completed else ""])
		else:
			player_exited.emit()
			print("[InteractiveObject] 玩家离开 %s 范围 (轮询检测)" % object_id)

## 距离判定：玩家中心与交互物中心的距离是否在触发半径内
## 修复: 原 AABB 矩形检测在物理阻挡紧贴交互触发区时永远 false（玩家贴边差 0.02 像素）
## 改用更稳健的距离判定，半径 = 物体 size 最大边 + 32 像素容差
func _rect_overlaps_player(player: Node2D) -> bool:
	var col_shape: CollisionShape2D = get_node_or_null("CollisionShape2D")
	if not col_shape or not col_shape.shape:
		return false
	# 玩家中心到交互物中心的距离
	var dist: float = player.global_position.distance_to(global_position)
	# 触发半径 = 物体碰撞尺寸最大边的一半 + 玩家半宽 + 容差
	var half_max_dim: float = 0.0
	if col_shape.shape is RectangleShape2D:
		var s: Vector2 = col_shape.shape.size
		half_max_dim = max(s.x, s.y) / 2.0
	# 玩家半宽（取最长边的一半，兼容不同角色）
	var p_size: Vector2 = Vector2(50, 55)
	if player.has_method("_get_collision_size"):
		p_size = player._get_collision_size()
	var half_p: float = max(p_size.x, p_size.y) / 2.0
	# 触发半径 = 物体半径 + 玩家半径 + 16 像素容差
	const TOLERANCE: float = 16.0
	return dist <= (half_max_dim + half_p + TOLERANCE)


## 标记交互为已完成（幂等性：调用后该物体不可再触发的交互）
func mark_completed() -> void:
	completed = true
	# 隐藏光点指示器（床等允许重复交互的除外）
	if not allow_repeat:
		var indicator = get_node_or_null("Indicator")
		if indicator: indicator.visible = false
		var glow = get_node_or_null("Glow")
		if glow: glow.visible = false
	print("[InteractiveObject] %s 标记为已完成" % object_id)


## 重置完成状态（用于可重复交互的物体，如床）
func reset_completed() -> void:
	if allow_repeat:
		completed = false
		print("[InteractiveObject] %s 重置完成状态" % object_id)


## 公共方法: 程序化设置激活状态并更新提示
func set_active(active: bool) -> void:
	is_active = active
	if not active and _prompt_label:
		_prompt_label.visible = false
		is_player_in_range = false
	# 同步光点显隐：未激活时隐藏，激活时显示
	var indicator = get_node_or_null("Indicator")
	if indicator: indicator.visible = active
	var glow = get_node_or_null("Glow")
	if glow: glow.visible = active
