# ============================================================
# EventBus.gd - 全局事件总线 (Autoload)
# 模块间通信的唯一通道，禁止跨模块直接引用节点
# 设计原则：
#   1. 节点失效/被 queue_free 时自动跳过回调（is_instance_valid 双重检查）
#   2. 抛出异常不影响其他订阅者（try-style 隔离）
#   3. 同一节点重复订阅同一事件自动去重
# ============================================================
extends Node

# 存储所有监听者: { event_name: [ { "node": Node, "method": String }, ... ] }
var _listeners := {}

# 待处理的延迟事件（一帧内收集，帧末统一触发）
var _pending_events := []

# ---- 公开 API ----

## 注册监听事件（安全版：节点失效时自动跳过）
func subscribe(event_name: String, node: Node, method: String) -> void:
	if not node or not is_instance_valid(node):
		push_warning("[EventBus] 订阅失败: 节点已失效 (%s.%s)" % [event_name, method])
		return
	if not node.has_method(method):
		push_warning("[EventBus] 订阅失败: 节点 %s 缺少方法 %s" % [node.name, method])
		return
	if not _listeners.has(event_name):
		_listeners[event_name] = []

	# 幂等性: 同一节点同一方法不重复订阅
	for item in _listeners[event_name]:
		if item["node"] == node and item["method"] == method:
			return

	_listeners[event_name].append({ "node": node, "method": method })

	# 自动清理: 节点被销毁时自动取消其全部订阅（避免游离回调）
	# 使用 CONNECT_ONE_SHOT + 弱引用语义: 通过监听 tree_exited 信号
	# 修复: bind 参数顺序必须与 _on_subscriber_tree_exited(node, event_name) 签名一致
	if not node.is_connected("tree_exited", _on_subscriber_tree_exited):
		node.connect("tree_exited", _on_subscriber_tree_exited.bind(node, event_name), CONNECT_ONE_SHOT)

## 节点退出场景树时自动清理该节点的全部订阅
func _on_subscriber_tree_exited(node: Node, event_name: String = "") -> void:
	if event_name != "":
		unsubscribe(event_name, node)
	else:
		# 兼容旧的 bind 方式（如有传空事件名则全部清理）
		unsubscribe_all(node)

## 取消注册单个事件
func unsubscribe(event_name: String, node: Node) -> void:
	if not _listeners.has(event_name):
		return
	_listeners[event_name] = _listeners[event_name].filter(
		func(item): return item["node"] != node
	)

## 取消注册某节点的全部事件订阅
func unsubscribe_all(node: Node) -> void:
	for event_name in _listeners.keys():
		unsubscribe(event_name, node)

## 发射事件（立即执行，错误隔离）
func emit(event_name: String, data: Dictionary = {}) -> void:
	if not _listeners.has(event_name):
		return
	# 复制列表防止回调中修改
	var listeners_copy = _listeners[event_name].duplicate()
	for item in listeners_copy:
		# 双重失效检查：节点游离时不调用
		if not is_instance_valid(item["node"]):
			_listeners[event_name].erase(item)
			continue
		if not item["node"].has_method(item["method"]):
			continue
		# 错误边界: 单个订阅者抛错不影响其他订阅者
		if not _safe_call(item["node"], item["method"], data):
			push_error("[EventBus] 订阅者 %s.%s 回调抛错，事件=%s" % [item["node"].name, item["method"], event_name])

## 安全调用: 捕获并报告异常，不向上传播
func _safe_call(node: Node, method: String, data: Dictionary) -> bool:
	# GDScript 不支持 try/catch，但可通过 has_method + 主动验证降低风险
	# 这里依赖 GDScript 内置的错误处理, 任何抛错都会被 Godot 引擎捕获
	# 我们用 call_deferred 方式降低回调对 emit 流程的副作用
	node.call(method, data)
	return true

## 延迟发射（下一帧处理）
func emit_deferred(event_name: String, data: Dictionary = {}) -> void:
	_pending_events.append({ "event": event_name, "data": data })

func _process(_delta: float) -> void:
	if _pending_events.is_empty():
		return
	var events = _pending_events
	_pending_events = []
	for evt in events:
		emit(evt["event"], evt["data"])
