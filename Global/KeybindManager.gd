# ============================================================
# KeybindManager.gd - 按键绑定管理器 (Autoload)
# 运行时修改 InputMap 并持久化到 user://keybindings.json
# 不修改任何现有输入逻辑，Input.is_action_pressed 等自动适配
# ============================================================
extends Node

const SAVE_PATH := "user://keybindings.json"

## 可重绑定的动作列表（动作名 → 显示名）
const REBINDABLE_ACTIONS: Dictionary = {
	&"player_attack": "攻击",
	&"player_dash": "闪避",
	&"player_skill": "技能",
	&"player_skill_2": "技能2",
	&"player_jump": "跳跃",
	&"ui_left": "左移",
	&"ui_right": "右移",
	&"ui_up": "上移",
	&"ui_down": "下移",
}

## 默认绑定（启动时快照，用于恢复出厂）
var _default_bindings: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_save_current_as_defaults()
	_load_bindings()

## ================================================================
##  公共 API
## ================================================================

## 保存当前 InputMap 为默认快照
func _save_current_as_defaults() -> void:
	for action: StringName in REBINDABLE_ACTIONS:
		_default_bindings[action] = InputMap.action_get_events(action).duplicate(true)

## 重绑定单个动作（替换所有事件为传入的单个事件）
func rebind_action(action: StringName, event: InputEvent) -> void:
	if not REBINDABLE_ACTIONS.has(action):
		push_warning("[KeybindManager] 不可重绑定的动作: %s" % action)
		return
	InputMap.action_erase_events(action)
	InputMap.action_add_event(action, event)
	_save_bindings()

## 恢复所有默认绑定
func reset_to_defaults() -> void:
	for action: StringName in REBINDABLE_ACTIONS:
		InputMap.action_erase_events(action)
		for ev: InputEvent in _default_bindings[action]:
			InputMap.action_add_event(action, ev.duplicate())
	_save_bindings()

## 获取动作的中文显示名
func get_action_display_name(action: StringName) -> String:
	return str(REBINDABLE_ACTIONS.get(action, action))

## 获取输入事件的显示文本
func get_event_display_text(ev: InputEvent) -> String:
	if ev is InputEventKey:
		return _key_display_text(ev)
	elif ev is InputEventMouseButton:
		return _mouse_button_display_text(ev)
	elif ev is InputEventJoypadButton:
		return _joypad_button_display_text(ev)
	elif ev is InputEventJoypadMotion:
		return _joypad_motion_display_text(ev)
	return "?"

## ================================================================
##  持久化：加载 / 保存 JSON
## ================================================================

func _load_bindings() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var json_text := file.get_as_text()
	file.close()
	var result: Variant = JSON.parse_string(json_text)
	if result == null or not result is Dictionary:
		push_warning("[KeybindManager] 配置文件无效，使用默认绑定")
		return
	var data: Dictionary = result
	for action: StringName in REBINDABLE_ACTIONS:
		if not data.has(action):
			continue
		var events_array: Variant = data[action]
		if not events_array is Array:
			continue
		InputMap.action_erase_events(action)
		for ev_dict: Variant in events_array:
			if not ev_dict is Dictionary:
				continue
			var ev: InputEvent = _dict_to_event(ev_dict)
			if ev != null:
				InputMap.action_add_event(action, ev)

func _save_bindings() -> void:
	var data: Dictionary = {}
	for action: StringName in REBINDABLE_ACTIONS:
		var events: Array[InputEvent] = InputMap.action_get_events(action)
		var arr: Array = []
		for ev: InputEvent in events:
			arr.append(_event_to_dict(ev))
		data[action] = arr
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("[KeybindManager] 无法保存按键配置")
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()

## ================================================================
##  序列化：InputEvent ↔ Dictionary
## ================================================================

func _event_to_dict(ev: InputEvent) -> Dictionary:
	var d: Dictionary = {"type": ev.get_class()}
	if ev is InputEventKey:
		var k: InputEventKey = ev
		d["physical_keycode"] = k.physical_keycode
		d["keycode"] = k.keycode
		d["unicode"] = k.unicode
		d["key_label"] = k.key_label
		d["location"] = k.location
		d["alt_pressed"] = k.alt_pressed
		d["shift_pressed"] = k.shift_pressed
		d["ctrl_pressed"] = k.ctrl_pressed
		d["meta_pressed"] = k.meta_pressed
	elif ev is InputEventMouseButton:
		var m: InputEventMouseButton = ev
		d["button_index"] = m.button_index
	elif ev is InputEventJoypadButton:
		var j: InputEventJoypadButton = ev
		d["button_index"] = j.button_index
	elif ev is InputEventJoypadMotion:
		var j: InputEventJoypadMotion = ev
		d["axis"] = j.axis
		d["axis_value"] = j.axis_value
	return d

func _dict_to_event(d: Dictionary) -> Variant:
	var type: String = d.get("type", "")
	match type:
		"InputEventKey":
			var ev := InputEventKey.new()
			ev.physical_keycode = d.get("physical_keycode", 0)
			ev.keycode = d.get("keycode", 0)
			ev.unicode = d.get("unicode", 0)
			ev.key_label = d.get("key_label", 0)
			ev.location = d.get("location", 0)
			ev.alt_pressed = d.get("alt_pressed", false)
			ev.shift_pressed = d.get("shift_pressed", false)
			ev.ctrl_pressed = d.get("ctrl_pressed", false)
			ev.meta_pressed = d.get("meta_pressed", false)
			return ev
		"InputEventMouseButton":
			var ev := InputEventMouseButton.new()
			ev.button_index = d.get("button_index", 0)
			return ev
		"InputEventJoypadButton":
			var ev := InputEventJoypadButton.new()
			ev.button_index = d.get("button_index", 0)
			return ev
		"InputEventJoypadMotion":
			var ev := InputEventJoypadMotion.new()
			ev.axis = d.get("axis", 0)
			ev.axis_value = d.get("axis_value", 0.0)
			return ev
	push_warning("[KeybindManager] 未知输入事件类型: %s" % type)
	return null

## ================================================================
##  显示文本辅助
## ================================================================

func _key_display_text(ev: InputEventKey) -> String:
	var parts: Array = []
	if ev.ctrl_pressed:
		parts.append("Ctrl")
	if ev.alt_pressed:
		parts.append("Alt")
	if ev.shift_pressed:
		parts.append("Shift")
	if ev.meta_pressed:
		parts.append("Meta")
	var key_name: String = ""
	if ev.physical_keycode != 0:
		key_name = OS.get_keycode_string(ev.physical_keycode)
	elif ev.keycode != 0:
		key_name = OS.get_keycode_string(ev.keycode)
	if key_name == "":
		key_name = "Key_%d" % ev.physical_keycode
	parts.append(key_name)
	return "+".join(parts)

func _mouse_button_display_text(ev: InputEventMouseButton) -> String:
	match ev.button_index:
		1: return "鼠标左键"
		2: return "鼠标右键"
		3: return "鼠标中键"
		4: return "滚轮上"
		5: return "滚轮下"
		6: return "滚轮左"
		7: return "滚轮右"
		8: return "鼠标侧键1"
		9: return "鼠标侧键2"
		_: return "鼠标键%d" % ev.button_index

func _joypad_button_display_text(ev: InputEventJoypadButton) -> String:
	match ev.button_index:
		0: return "手柄A"
		1: return "手柄B"
		2: return "手柄X"
		3: return "手柄Y"
		4: return "手柄选择"
		5: return "手柄开始"
		6: return "手柄LB"
		7: return "手柄RB"
		_: return "手柄键%d" % ev.button_index

func _joypad_motion_display_text(ev: InputEventJoypadMotion) -> String:
	var axis_name: String = ""
	match ev.axis:
		0: axis_name = "左摇杆"
		1: axis_name = "左摇杆"
		2: axis_name = "右摇杆"
		3: axis_name = "右摇杆"
		_: return "轴%d" % ev.axis
	var dir: String = ""
	match ev.axis:
		0: dir = "左" if ev.axis_value < 0 else "右"
		1: dir = "上" if ev.axis_value < 0 else "下"
		2: dir = "左" if ev.axis_value < 0 else "右"
		3: dir = "上" if ev.axis_value < 0 else "下"
		_: dir = ""
	return axis_name + dir
