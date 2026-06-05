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
		# 已完成 → 灰色静态提示
		_prompt_label.text = "已完成 ✓"
		_prompt_label.add_theme_color_override("font_color", Color(0.4, 0.5, 0.4, 0.8))
	else:
		# 可交互 → 黄色呼吸闪烁
		_prompt_label.text = prompt_text
		var alpha = 0.6 + 0.4 * abs(sin(Time.get_ticks_msec() * 0.004))
		_prompt_label.add_theme_color_override("font_color", Color(1, 0.9, 0.2, alpha))


# ---- 碰撞检测 ----

func _on_body_entered(body: Node2D) -> void:
	if not is_active:
		return
	# 检测玩家层 (collision_layer 4)
	if body is CharacterBody2D and (body.collision_layer & 4):
		is_player_in_range = true
		print("[InteractiveObject] 玩家进入 %s 范围%s" % [object_id, " [已完成]" if completed else ""])
		player_entered.emit()


func _on_body_exited(body: Node2D) -> void:
	if body is CharacterBody2D and (body.collision_layer & 4):
		is_player_in_range = false
		print("[InteractiveObject] 玩家离开 %s 范围" % object_id)
		player_exited.emit()


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
