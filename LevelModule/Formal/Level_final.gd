# ============================================================
# Level_final.gd - 终局关卡（视频演出后进入）
# 玩家出生 (784,576)，交互点 (472,472)，交互后显示"太阳照常升起"
# ============================================================
extends Node2D

var _all_interactives: Array[InteractiveObject] = []
var _dialog_open: bool = false
var _dialog_panel: Panel = null
var _dialog_label: RichTextLabel = null
var _dialog_lines: Array[String] = []
var _dialog_index: int = 0

const PLAYER_SPAWN := Vector2(320, 616)
const INTERACT_POS := Vector2(192, 584)
const INTERACT_ID := "final_sun"

func _ready() -> void:
	# 清除旧玩家
	if GameManager.player_ref and is_instance_valid(GameManager.player_ref):
		GameManager.player_ref.queue_free()
		GameManager.player_ref = null
	# 创建玩家（普通外观，非赛博非岭南）
	var path := "res://PlayerModule/Formal/Player_Warrior.tscn"
	if ResourceLoader.exists(path):
		var p = load(path).instantiate()
		p.position = PLAYER_SPAWN
		add_child(p)
		GameManager.register_player(p)
		# 禁用跳跃/攻击/闪避/技能
		p.can_jump = false
		p.can_dash = false
		p.can_attack = false
		p.can_skill = false
		var cam = p.get_node_or_null("SmoothCamera") as SmoothCamera
		if cam:
			# 完全复用关卡1：zoom 2倍 + lerp_speed 2.5 + 边界
			cam.limit_left = 0
			cam.limit_right = 400
			cam.limit_top = 504
			cam.limit_bottom = 640
			cam.zoom = Vector2(2, 2)
			cam.offset = Vector2.ZERO
			cam.lerp_speed = 2.5
			cam.bind_target(p)
			cam.follow_enabled = true
			cam.make_current()
	# 不加载 HUD（不显示血条和技能图标）
	# 创建交互点
	_create_interactive()
	# 订阅交互事件
	EventBus.subscribe(GlobalDefine.EventName.INTERACTIVE_OBJECT_TRIGGERED, self, "_on_object_interacted")
	set_process(true)
	set_process_input(true)
	print("[Level_final] 终局关卡加载完成")

func _create_interactive() -> void:
	var obj = InteractiveObject.new()
	obj.object_id = INTERACT_ID
	obj.is_active = true
	obj.prompt_text = "按 Enter 交互"
	obj.position = INTERACT_POS
	obj.collision_layer = 0
	obj.collision_mask = GlobalDefine.Collision.PLAYER
	var col = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = Vector2(80, 80)
	col.shape = rect
	obj.add_child(col)
	add_child(obj)
	_all_interactives.append(obj)
	# 复用关卡1光点视觉
	obj.apply_level01_dot_visual()

func _process(_delta: float) -> void:
	var pl = GameManager.player_ref
	if pl and is_instance_valid(pl) and not _dialog_open:
		for obj in _all_interactives:
			if is_instance_valid(obj):
				obj.check_player_in_range(pl)

func _input(event: InputEvent) -> void:
	var is_left_click = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	if _dialog_open:
		if (event is InputEventKey and event.pressed and event.keycode == KEY_ENTER) or is_left_click:
			_advance_dialog()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_accept") or is_left_click:
		var obj = _find_nearby_interactive()
		if obj:
			EventBus.emit(GlobalDefine.EventName.INTERACTIVE_OBJECT_TRIGGERED, {"object_id": obj.object_id})
			get_viewport().set_input_as_handled()

func _find_nearby_interactive() -> InteractiveObject:
	for obj in _all_interactives:
		if is_instance_valid(obj) and obj.is_active and not obj.completed and obj.is_player_in_range:
			return obj
	return null

func _on_object_interacted(data: Dictionary) -> void:
	var oid = data.get("object_id", "")
	if oid == INTERACT_ID:
		_show_dialog(["太阳照常升起"])

# ============================================================
# 对话框
# ============================================================

func _show_dialog(lines: Array[String]) -> void:
	_dialog_lines = lines
	_dialog_index = 0
	_dialog_open = true
	InputManager.block_input("对话", self)
	if not _dialog_panel:
		_create_dialog_panel()
	_dialog_panel.visible = true
	_show_dialog_line()

func _create_dialog_panel() -> void:
	var cv = CanvasLayer.new()
	cv.name = "DialogLayer"
	cv.layer = 50
	add_child(cv)
	_dialog_panel = Panel.new()
	_dialog_panel.position = Vector2(240, 520)
	_dialog_panel.size = Vector2(800, 140)
	_dialog_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.85)
	style.set_corner_radius_all(8)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	_dialog_panel.add_theme_stylebox_override("panel", style)
	cv.add_child(_dialog_panel)
	_dialog_label = RichTextLabel.new()
	_dialog_label.bbcode_enabled = true
	_dialog_label.fit_content = true
	_dialog_label.position = Vector2(20, 16)
	_dialog_label.size = Vector2(760, 108)
	_dialog_label.add_theme_font_size_override("normal_font_size", 22)
	_dialog_label.add_theme_color_override("default_color", Color(0.95, 0.9, 0.8))
	_dialog_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dialog_panel.add_child(_dialog_label)

func _show_dialog_line() -> void:
	if _dialog_index < _dialog_lines.size():
		_dialog_label.text = _dialog_lines[_dialog_index]
	else:
		_close_dialog()

func _advance_dialog() -> void:
	_dialog_index += 1
	_show_dialog_line()

func _close_dialog() -> void:
	_dialog_open = false
	_dialog_panel.visible = false
	InputManager.unblock_input("对话")
