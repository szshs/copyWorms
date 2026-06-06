# ============================================================
# Level_01.gd - 第一关控制器
# 场景构建 → Level_01_SceneBuilder
# UI 构建   → Level_01_UIBuilder
# 状态调度  → Level_01_FSM
# ============================================================
extends LevelBase
class_name Level_01

@export var level_data: Level01Data = null

enum LevelState { LIVING_ROOM, CORRIDOR, BEDROOM, IDE_CHAT, IDE_PREVIEW, PHONE_RINGING, GLITCH_TRANSIT }

var current_state: int = LevelState.LIVING_ROOM
var sleep_count: int = 0
var current_chat_index: int = 0

var _original_jump_velocity: float = 0.0
var _original_dash_speed: float = 0.0
var _original_attack_damage: int = 0

var _narrative_panel: Panel = null
var _narrative_text: RichTextLabel = null
var _sleep_overlay: ColorRect = null
var _ide_ui: Control = null
var _chat_window: RichTextLabel = null
var _viewport_container: SubViewportContainer = null
var _mini_viewport: SubViewport = null
var _glitch_overlay: ColorRect = null

var _obstacle_box: InteractiveObject = null
var _obstacle_clothes: InteractiveObject = null
var _bed_node: InteractiveObject = null
var _computer_node: InteractiveObject = null
var _phone_node: InteractiveObject = null

var _interact_cooldown: float = 0.0
var _is_interacting: bool = false
var _fsm: Level_01_FSM = null
var _phone_vibrate_tween: Tween = null


# ---- 生命周期 ----

func _on_ready() -> void:
	super._on_ready()
	set_process_input(true)
	set_process_unhandled_input(true)

	if not level_config:
		level_config = load("res://DataConfig/Level/Level01Config.tres") as LevelConfig
		_apply_config()
	if not level_data:
		level_data = load("res://DataConfig/Level/Level01Data.tres") as Level01Data

	var builder = Level_01_SceneBuilder.new(self)
	builder.build_all()

	_cache_ui_refs()
	_restrict_player_mechanics()
	_phone_node.is_active = false
	EventBus.subscribe("interactive_object_triggered", self, "_on_object_interacted")
	_fsm = Level_01_FSM.new(self)

	print("[Level_01] 初始化完成 — 当前: LIVING_ROOM")


# ---- 工具方法 ----

func _get_or_create_child(node_name: String, node_type) -> Node:
	var existing = get_node_or_null(node_name)
	if existing: return existing
	var node = node_type.new()
	node.name = node_name
	add_child(node)
	return node

func _create_static_body(node_name: String, pos: Vector2, size: Vector2, col: Color) -> StaticBody2D:
	var body = StaticBody2D.new()
	body.name = node_name
	body.position = pos
	body.collision_layer = GlobalDefine.Collision.TERRAIN
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
	obj.collision_mask = GlobalDefine.Collision.PLAYER
	var col_shape = CollisionShape2D.new()
	col_shape.name = "CollisionShape2D"
	var rect_shape = RectangleShape2D.new()
	rect_shape.size = Vector2(size.x * 2.5, size.y * 1.1)
	col_shape.shape = rect_shape
	obj.add_child(col_shape)
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
	blocker.collision_layer = GlobalDefine.Collision.TERRAIN
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
	if not canvas: return
	_narrative_panel = canvas.get_node_or_null("NarrativePanel")
	if _narrative_panel: _narrative_text = _narrative_panel.get_node_or_null("RichTextLabel")
	_sleep_overlay = canvas.get_node_or_null("SleepOverlay")
	_ide_ui = canvas.get_node_or_null("IdeUI")
	if _ide_ui:
		_chat_window = _ide_ui.get_node_or_null("ChatWindow")
		_viewport_container = _ide_ui.get_node_or_null("ViewportContainer")
		if _viewport_container: _mini_viewport = _viewport_container.get_node_or_null("MiniViewport")
	_glitch_overlay = canvas.get_node_or_null("GlitchOverlay")


# ---- 玩家控制 ----

func _restrict_player_mechanics() -> void:
	var player = GameManager.player_ref
	if not player or not player.config: return
	_original_jump_velocity = player.config.jump_velocity
	_original_dash_speed = player.config.dash_speed
	_original_attack_damage = player.config.attack_damage
	player.config.jump_velocity = 0.0
	player.config.dash_speed = 0.0
	player.config.attack_damage = 0

func _restore_player_mechanics() -> void:
	var player = GameManager.player_ref
	if not player or not player.config: return
	player.config.jump_velocity = _original_jump_velocity
	player.config.dash_speed = _original_dash_speed
	player.config.attack_damage = _original_attack_damage

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


# ---- 输入处理 ----

func _input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_accept"): return

	if current_state == LevelState.IDE_CHAT:
		_render_next_chat_line()
		get_viewport().set_input_as_handled()
		return

	if _is_interacting or _interact_cooldown > 0.0: return

	var nearby_obj = _find_nearby_interactive()
	if nearby_obj:
		_interact_cooldown = 0.3
		EventBus.emit("interactive_object_triggered", {"object_id": nearby_obj.object_id})
		get_viewport().set_input_as_handled()

func _find_nearby_interactive() -> InteractiveObject:
	for obj in [_obstacle_box, _obstacle_clothes, _bed_node, _computer_node, _phone_node]:
		if is_instance_valid(obj) and obj.is_active and not obj.completed and obj.is_player_in_range:
			return obj
	return null

func _process(delta: float) -> void:
	if _interact_cooldown > 0.0: _interact_cooldown -= delta


# ---- FSM 调度 ----

func _on_object_interacted(data: Dictionary) -> void:
	var obj_id: String = data.get("object_id", "")
	_fsm.handle_interaction(obj_id)

func _get_interactive_by_id(obj_id: String) -> InteractiveObject:
	match obj_id:
		"box": return _obstacle_box
		"clothes": return _obstacle_clothes
		"bed": return _bed_node
		"computer": return _computer_node
		"phone": return _phone_node
	return null

func _mark_interaction_completed(obj_id: String) -> void:
	var obj = _get_interactive_by_id(obj_id)
	if obj and not obj.allow_repeat:
		obj.mark_completed()


# ---- 障碍物 ----

func _clear_obstacle(obstacle_node: InteractiveObject) -> void:
	if not is_instance_valid(obstacle_node): return
	obstacle_node.is_active = false
	var static_body = obstacle_node.get_node_or_null("StaticBody2D")
	if static_body:
		var col_shape = static_body.get_node_or_null("CollisionShape2D")
		if col_shape: col_shape.disabled = true
	_match_and_clear_ref(obstacle_node)
	var tween = create_tween()
	tween.tween_property(obstacle_node, "modulate:a", 0.0, 0.5)
	tween.finished.connect(func(): if is_instance_valid(obstacle_node): obstacle_node.queue_free())

func _match_and_clear_ref(node: InteractiveObject) -> void:
	if node == _obstacle_box: _obstacle_box = null
	elif node == _obstacle_clothes: _obstacle_clothes = null


# ---- 叙事面板 ----

func _show_narrative(text: String, callback: Callable = Callable()) -> void:
	_is_interacting = true
	_freeze_player(true)
	if _narrative_panel:
		_narrative_panel.show()
		if _narrative_text: _narrative_text.text = text
	await get_tree().create_timer(0.3).timeout
	while true:
		if Input.is_action_just_pressed("ui_accept"): break
		await get_tree().process_frame
	if _narrative_panel: _narrative_panel.hide()
	_freeze_player(false)
	if callback.is_valid(): callback.call()
	_is_interacting = false


# ---- 睡眠循环 ----

func _trigger_sleep_cycle() -> void:
	if not level_data: return
	_bed_node.completed = true
	_is_interacting = true
	_freeze_player(true)

	var sleep_text = "……"
	if not level_data.sleep_texts.is_empty():
		sleep_text = level_data.sleep_texts[min(sleep_count, level_data.sleep_texts.size() - 1)]
	sleep_count += 1

	if _sleep_overlay:
		_sleep_overlay.color.a = 0.0
		_sleep_overlay.show()
		var tween = create_tween()
		tween.tween_property(_sleep_overlay, "color:a", 1.0, 1.0)
		await tween.finished

	_show_narrative(sleep_text, func():
		if _sleep_overlay:
			var tween_back = create_tween()
			tween_back.tween_property(_sleep_overlay, "color:a", 0.0, 1.0)
			tween_back.finished.connect(func():
				if _sleep_overlay: _sleep_overlay.hide()
				_freeze_player(false)
				_bed_node.reset_completed()
			)
		else:
			_freeze_player(false)
			_bed_node.reset_completed()
	)


# ---- IDE 模式 ----

func _enter_ide_mode() -> void:
	_mark_interaction_completed("computer")
	_is_interacting = true
	current_state = LevelState.IDE_CHAT
	_freeze_player(true)
	if _ide_ui: _ide_ui.show()
	current_chat_index = 0
	if _chat_window: _chat_window.text = ""
	_render_next_chat_line()

func _render_next_chat_line() -> void:
	if not level_data:
		_start_ide_viewport_preview(); return
	var total = min(level_data.ide_speakers.size(), level_data.ide_texts.size())
	if current_chat_index >= total:
		_start_ide_viewport_preview(); return
	var speaker = level_data.ide_speakers[current_chat_index]
	var text = level_data.ide_texts[current_chat_index]
	var format_text = ""
	match speaker:
		"System": format_text = "[color=yellow][SYSTEM] " + text + "[/color]\n"
		"AI": format_text = "[color=cyan]AI: " + text + "[/color]\n"
		"Ming": format_text = "[color=white]阿明: " + text + "[/color]\n"
		_: format_text = text + "\n"
	if _chat_window: _chat_window.append_text(format_text)
	current_chat_index += 1

func _start_ide_viewport_preview() -> void:
	current_state = LevelState.IDE_PREVIEW
	if _chat_window: _chat_window.append_text("[color=green][SYSTEM] 正在启动 Local Test Viewport...[/color]\n")
	var path = "res://LevelModule/SelfTest/MiniTestWorld.tscn"
	if not ResourceLoader.exists(path) or not load(path):
		if _chat_window: _chat_window.append_text("[color=red][FATAL ERROR] 加载失败[/color]\n")
		_on_preview_crashed(); return
	var mini_world = load(path).instantiate()
	if _mini_viewport: _mini_viewport.add_child(mini_world)
	if mini_world.has_signal("prototype_crashed"):
		mini_world.connect("prototype_crashed", _on_preview_crashed)

func _on_preview_crashed() -> void:
	if _chat_window:
		_chat_window.append_text("[color=red][FATAL ERROR] 线程溢出: 'Xiguan_Dream' 崩溃。[/color]\n")
		_chat_window.append_text("[color=red][SYSTEM] 连接中断。物理交互环境已强行关闭。[/color]\n")
	await get_tree().create_timer(1.5).timeout
	if _mini_viewport:
		for child in _mini_viewport.get_children(): child.queue_free()
	if _ide_ui: _ide_ui.hide()
	current_state = LevelState.PHONE_RINGING
	if _phone_node: _phone_node.is_active = true
	_start_phone_vibration()
	_freeze_player(false)
	_is_interacting = false


# ---- 手机震动 ----

func _start_phone_vibration() -> void:
	if not _phone_node: return
	_phone_vibrate_tween = create_tween()
	_phone_vibrate_tween.set_loops()
	var bp = _phone_node.position
	_phone_vibrate_tween.tween_property(_phone_node, "position:x", bp.x + 3, 0.05)
	_phone_vibrate_tween.tween_property(_phone_node, "position:x", bp.x - 3, 0.05)
	_phone_vibrate_tween.tween_property(_phone_node, "position:x", bp.x + 1.5, 0.05)
	_phone_vibrate_tween.tween_property(_phone_node, "position:x", bp.x, 0.05)

func _stop_phone_vibration() -> void:
	if _phone_vibrate_tween and is_instance_valid(_phone_vibrate_tween):
		_phone_vibrate_tween.kill()
		_phone_vibrate_tween = null


# ---- 终局 ----

func _trigger_climax_transition() -> void:
	if not level_data:
		_start_glitch_shader_effect(); return
	_mark_interaction_completed("phone")
	_freeze_player(true)
	var message = level_data.phone_sender + ":\n" + level_data.phone_content
	_show_narrative(message, func():
		_stop_phone_vibration()
		_start_glitch_shader_effect()
	)

func _start_glitch_shader_effect() -> void:
	if not _glitch_overlay:
		EventBus.emit(GlobalDefine.EventName.LEVEL_COMPLETE, {"level": self, "next_level": "res://LevelModule/Formal/Level_02.tscn"})
		return
	_glitch_overlay.show()
	var tween = create_tween()
	tween.tween_property(_glitch_overlay.material, "shader_parameter/intensity", 1.0, 2.0)
	await tween.finished
	EventBus.emit(GlobalDefine.EventName.LEVEL_COMPLETE, {"level": self, "next_level": "res://LevelModule/Formal/Level_02.tscn"})
