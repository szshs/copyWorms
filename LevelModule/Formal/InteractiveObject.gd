# res://LevelModule/Formal/InteractiveObject.gd
# 统一交互物基类 - 独立交互模块
# 职责: 碰撞检测(body_entered) + 视觉反馈(提示标签) + 完成状态追踪
# 输入处理已移至 Level_01 控制器，解决动态创建节点 _input() 不可靠问题
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
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# 显示在物体上方 50px，居中
	_prompt_label.position = Vector2(-80, -55)
	_prompt_label.size = Vector2(160, 20)
	add_child(_prompt_label)


func _process(_delta: float) -> void:
	if not _prompt_label:
		return
	
	if not is_active or not is_player_in_range:
		_prompt_label.visible = false
		return
	
	_prompt_label.visible = true
	
	if completed:
		_prompt_label.text = "已完成 ✓"
		_prompt_label.add_theme_color_override("font_color", Color(0.4, 0.5, 0.4, 0.8))
	else:
		_prompt_label.text = prompt_text
		var alpha = 0.6 + 0.4 * abs(sin(Time.get_ticks_msec() * 0.004))
		_prompt_label.add_theme_color_override("font_color", Color(1, 0.9, 0.2, alpha))

	# 直接在这里检测 Enter 交互
	if is_player_in_range and is_active and not completed:
		if Input.is_action_just_pressed("ui_accept"):
			print("[InteractiveObject] 交互触发: %s" % object_id)
			EventBus.emit("interactive_object_triggered", {"object_id": object_id})


# ---- 碰撞检测 ----

func _on_body_entered(body: Node2D) -> void:
	if not is_active:
		return
	# B8 修复: 强化玩家识别 — 即使 collision_layer 位运算失败也尝试按 group/name 兜底
	if _is_player(body):
		is_player_in_range = true
		print("[InteractiveObject] 玩家进入 %s 范围%s" % [object_id, " [已完成]" if completed else ""])


func _on_body_exited(body: Node2D) -> void:
	if _is_player(body):
		is_player_in_range = false
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
			print("[InteractiveObject] 玩家进入 %s 范围%s (轮询检测)" % [object_id, " [已完成]" if completed else ""])
		else:
			print("[InteractiveObject] 玩家离开 %s 范围 (轮询检测)" % object_id)

## 用 AABB 矩形检测玩家是否在 CollisionShape2D 范围内
func _rect_overlaps_player(player: Node2D) -> bool:
	var col_shape: CollisionShape2D = get_node_or_null("CollisionShape2D")
	if not col_shape or not col_shape.shape:
		return false
	# 玩家碰撞尺寸 (从 PlayerBase._get_collision_size 取)
	var p_size: Vector2 = Vector2(50, 55)  # 默认值
	if player.has_method("_get_collision_size"):
		p_size = player._get_collision_size()
	# 玩家 AABB
	var p_rect: Rect2 = Rect2(player.global_position - p_size / 2.0, p_size)
	# 交互物 AABB (CollisionShape2D 的 shape 在交互物的 local 空间,以 global_transform 转世界)
	var shape_rect: Rect2 = col_shape.shape.get_rect() if col_shape.shape is RectangleShape2D else Rect2()
	if shape_rect.size == Vector2.ZERO:
		return false
	# transform 2D 应用
	var xform: Transform2D = col_shape.global_transform
	var corners: Array[Vector2] = [
		xform * shape_rect.position,
		xform * (shape_rect.position + Vector2(shape_rect.size.x, 0)),
		xform * (shape_rect.position + Vector2(0, shape_rect.size.y)),
		xform * (shape_rect.position + shape_rect.size)
	]
	# 取 AABB 包络
	var min_pt: Vector2 = corners[0]
	var max_pt: Vector2 = corners[0]
	for c in corners:
		min_pt = Vector2(min(min_pt.x, c.x), min(min_pt.y, c.y))
		max_pt = Vector2(max(max_pt.x, c.x), max(max_pt.y, c.y))
	var obj_rect: Rect2 = Rect2(min_pt, max_pt - min_pt)
	return obj_rect.intersects(p_rect)


## 标记交互为已完成（幂等性：调用后该物体不可再触发的交互）
func mark_completed() -> void:
	completed = true
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
