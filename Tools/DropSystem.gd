# ============================================================
# DropSystem.gd - 掉落物管理系统
#
# 职责：
#   1. 监听 ENEMY_DIED 事件，统计击杀数
#   2. 达到阈值时生成掉落物（固定Y坐标、随机X坐标）
#   3. 掉落物拾取后触发全屏展示
#
# 使用方式（关卡 _on_ready 中）：
#   var _drop_system = DropSystem.new(self)
#   _drop_system.kills_threshold = 8
#   _drop_system.drop_y = 540
#   _drop_system.drop_x_range = Vector2(200, 1800)
#   _drop_system.drop_types = ["月饼", "虾饺", "木棉", "醒狮"]
# ============================================================
extends Node
class_name DropSystem

var _level: Node = null

## 击杀多少只怪后掉落
var kills_threshold: int = 8
## 掉落物生成 Y 坐标（固定）
var drop_y: float = 540.0
## 掉落物 X 坐标随机范围
var drop_x_range: Vector2 = Vector2(200.0, 1800.0)
## 可掉落的物品种类
var drop_types: Array[String] = ["月饼", "虾饺", "木棉", "醒狮"]

var _kill_count: int = 0
var _drop_triggered: bool = false
var _spawned_drops: Array[DropItem] = []

func _init(level: Node) -> void:
	_level = level
	# 订阅敌人死亡事件
	EventBus.subscribe(GlobalDefine.EventName.ENEMY_DIED, self, "_on_enemy_killed")
	# 订阅交互事件（处理掉落物拾取）
	EventBus.subscribe(GlobalDefine.EventName.INTERACTIVE_OBJECT_TRIGGERED, self, "_on_object_interacted")

func _on_enemy_killed(_data: Dictionary) -> void:
	if _drop_triggered: return
	_kill_count += 1
	if _kill_count >= kills_threshold:
		_drop_triggered = true
		_spawn_drop()

func _spawn_drop() -> void:
	# 随机选择掉落物类型
	var drop_type = drop_types[randi() % drop_types.size()]
	# 随机 X 坐标
	var x = randf_range(drop_x_range.x, drop_x_range.y)
	var pos = Vector2(x, drop_y)
	# 创建掉落物
	var drop = DropItem.new()
	drop.drop_type = drop_type
	drop.object_id = "drop_%s" % drop_type
	drop.global_position = pos
	drop.collision_layer = 0
	drop.collision_mask = GlobalDefine.Collision.PLAYER
	# 添加到关卡
	var parent = _level.get_node_or_null("DynamicActors")
	if parent:
		parent.add_child(drop)
	else:
		_level.add_child(drop)
	_spawned_drops.append(drop)
	# 注册到关卡的交互轮询列表
	if _level.has_method("_register_drop"):
		_level._register_drop(drop)
	print("[DropSystem] 击杀 %d 只，生成掉落物 %s 于 %s" % [_kill_count, drop_type, pos])

func _on_object_interacted(data: Dictionary) -> void:
	var obj_id: String = data.get("object_id", "")
	if not obj_id.begins_with("drop_"): return
	# 找到对应的掉落物
	for drop in _spawned_drops:
		if not is_instance_valid(drop): continue
		if drop.object_id == obj_id and not drop.completed:
			drop.on_collected()
			break

## 展示掉落物全屏动画（由 DropItem.on_collected → level._show_drop_showcase 调用）
func show_showcase(drop_type: String) -> void:
	var showcase = DropItemShowcase.new()
	_level.add_child(showcase)
	showcase.show_item(drop_type)

func cleanup() -> void:
	EventBus.unsubscribe_all(self)
	for drop in _spawned_drops:
		if is_instance_valid(drop):
			drop.queue_free()
	_spawned_drops.clear()
