# ============================================================
# Level_04.gd - 第四关「维度侵蚀与空间崩塌」控制器
# ============================================================
extends LevelBase
class_name Level_04

@export var level_data: Level04Data = null

enum LevelState { HOMOMORPHIC_COMBAT, LEVEL_END_TRANSIT }

var current_state: int = LevelState.HOMOMORPHIC_COMBAT

# ---- 地图切换 ----
var _current_world: int = 0
var _swap_count: int = 0
var _lingnan_spawn_index: int = 0
var _lingnan_enemies_spawned: bool = false
var _wall_dialog_shown: bool = false
var _cyber_return_dialog_shown: bool = false
var _swap_cooldown: float = 0.0
const CYBER_TELEPORT := Vector2(2298, -75)
const CYBER_CAM = [-50, 2500, -900, 1200]
const LNGN_CAM  = [-50, 4000,  600, 2500]
const LNGN_POSITIONS: Array[Vector2] = [
	Vector2(524, 2060), Vector2(3564, 2073), Vector2(1631, 1316)
]
const LNGN_DIALOGS: Array[String] = [
	"不太对，我需要到上面的阁楼看看", "还是不对", ""
]
var _stage1_enemies: Array[Node2D] = []

# ---- 交互物 ----
var _all_interactives: Array[InteractiveObject] = []

# ---- 场景节点 ----
var _dynamic_actors: Node2D = null

# ---- UI ----
var _narrative_panel: Panel = null
var _narrative_text: RichTextLabel = null
var _glitch_overlay: ColorRect = null
var _ending_prompt: Control = null
var _ending_label: Label = null

# ---- 叙事 ----
var _is_interacting: bool = false
var _narrative_open: bool = false
var _narrative_enter_pressed: bool = false
const NARRATIVE_INPUT_TIMEOUT: float = 30.0

# ---- 敌人 ----
var _enemy_cyber_wolf_scene: PackedScene = null

# ---- 终局 ----
var _ending_enter_armed: bool = false
var _level_complete_emitted: bool = false

# ---- 浮动文字 ----
var _float_text: Label = null
var _float_text_timer: float = 0.0


# ============================================================
# 生命周期
# ============================================================

func _setup_player() -> void:
	if GameManager.player_ref and is_instance_valid(GameManager.player_ref):
		return
	var path = "res://PlayerModule/Formal/Player_Warrior_Cyber.tscn"
	if ResourceLoader.exists(path):
		var p = load(path).instantiate()
		p.position = level_config.spawn_point if level_config else Vector2(400, 550)
		add_child(p)
		GameManager.register_player(p)

func _swap_player_skin(skin: String) -> void:
	var old = GameManager.player_ref
	if not old or not is_instance_valid(old): return
	var h = old.current_health; var m = old.max_health
	var f = old.is_facing_right; var pos = old.global_position
	if InputManager.game_action.is_connected(old._on_game_action):
		InputManager.game_action.disconnect(old._on_game_action)
	GameManager.player_ref = null; old.queue_free()
	var path = "res://PlayerModule/Formal/Player_Warrior_" + skin + ".tscn"
	if not ResourceLoader.exists(path): return
	var p = load(path).instantiate()
	p.global_position = pos; p.current_health = h
	p.max_health = m; p.is_facing_right = f; p.velocity = Vector2.ZERO
	add_child(p); GameManager.register_player(p)

func _on_ready() -> void:
	super._on_ready()
	if not level_config: level_config = load("res://DataConfig/Level/Level04Config.tres") as LevelConfig; _apply_config()
	if not level_data:  level_data  = load("res://DataConfig/Level/Level04Data.tres") as Level04Data

	var wolf = "res://EnemyModule/Formal/Enemy_CyberWolf.tscn"
	if ResourceLoader.exists(wolf): _enemy_cyber_wolf_scene = load(wolf)

	Level_04_SceneBuilder.new(self).build_all()
	_setup_camera_limits()
	_set_camera_limits(CYBER_CAM[0], CYBER_CAM[1], CYBER_CAM[2], CYBER_CAM[3])
	_cache_ui_refs()
	# 收集交互物引用 + 启动闪烁动画
	for c in get_node_or_null("Interactives").get_children():
		if c is InteractiveObject:
			_all_interactives.append(c)
			var ind = c.get_node_or_null("Indicator")
			var glw = c.get_node_or_null("Glow")
			if ind:
				var tw = ind.create_tween().set_loops()
				tw.tween_property(ind, "color:a", 0.2, 0.6).set_trans(Tween.TRANS_SINE)
				tw.tween_property(ind, "color:a", 0.9, 0.6).set_trans(Tween.TRANS_SINE)
			if glw:
				var tw2 = glw.create_tween().set_loops()
				tw2.tween_property(glw, "color:a", 0.0, 0.6).set_trans(Tween.TRANS_SINE)
				tw2.tween_property(glw, "color:a", 0.3, 0.6).set_trans(Tween.TRANS_SINE)
	var wt = get_node_or_null("Stage1Collisions/WallTrigger")
	if wt: wt.body_entered.connect(_on_wall_trigger)
	_ensure_player_collision_layer()

	EventBus.subscribe(GlobalDefine.EventName.INTERACTIVE_OBJECT_TRIGGERED, self, "_on_object_interacted")
	EventBus.subscribe(GlobalDefine.EventName.PLAYER_ATTACK_HIT, self, "_on_combat_hit")
	EventBus.subscribe(GlobalDefine.EventName.PLAYER_HURT, self, "_on_combat_hit")
	EventBus.subscribe(GlobalDefine.EventName.ENEMY_DIED, self, "_on_enemy_died")

	if not InputManager.game_action.is_connected(_on_game_action):
		InputManager.game_action.connect(_on_game_action)

	_load_hud(); set_process(true)

	if level_data and level_data.anchor_narrative != "":
		_show_narrative("[color=green]> User_Ming_Override_Protocol: Phase_Final.[/color]\n[color=green]> Target: REAL_EXIT.[/color]", func():
			_show_narrative("[color=goldenrod]阿明：[/color]" + level_data.anchor_narrative, func():
				_spawn_stage1_enemies(); _restore_combat_mechanics()
			)
		)
	else:
		_spawn_stage1_enemies(); _restore_combat_mechanics()
	print("[Level_04] 初始化完成")


func _get_or_create_child(node_name: String, node_type) -> Node:
	var e = get_node_or_null(node_name); if e: return e
	var n = node_type.new(); n.name = node_name; add_child(n); return n

func _load_hud() -> void:
	var p = "res://UI/HUD.tscn"
	if ResourceLoader.exists(p): add_child(load(p).instantiate())

func _cache_ui_refs() -> void:
	var c = $CanvasLayerUI
	if not c: return
	_narrative_panel = c.get_node_or_null("NarrativePanel")
	if _narrative_panel: _narrative_text = _narrative_panel.get_node_or_null("RichTextLabel")
	_glitch_overlay = c.get_node_or_null("GlitchOverlay")
	_ending_prompt = c.get_node_or_null("EndingPrompt")
	if _ending_prompt: _ending_label = _ending_prompt.get_node_or_null("EndingLabel")



# ============================================================
# 输入
# ============================================================

func _on_game_action(action: StringName, _event: InputEvent) -> void:
	if action != &"ui_accept": return
	if current_state == LevelState.LEVEL_END_TRANSIT:
		if _ending_enter_armed: _ending_enter_armed = false; _emit_level_complete()
		return
	if _narrative_open: _narrative_enter_pressed = true; return

func _input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_accept"): return
	if current_state == LevelState.LEVEL_END_TRANSIT:
		if _ending_enter_armed: _ending_enter_armed = false; _emit_level_complete(); get_viewport().set_input_as_handled()
		return
	if _narrative_open: _narrative_enter_pressed = true; get_viewport().set_input_as_handled(); return
	var obj = _find_nearby_interactive()
	if obj:
		EventBus.emit(GlobalDefine.EventName.INTERACTIVE_OBJECT_TRIGGERED, {"object_id": obj.object_id})
		get_viewport().set_input_as_handled()


func _find_nearby_interactive() -> InteractiveObject:
	for obj in _all_interactives:
		if is_instance_valid(obj) and obj.is_active and not obj.completed and obj.is_player_in_range:
			return obj
	var p = GameManager.player_ref
	if not p or not is_instance_valid(p): return null
	var best: InteractiveObject = null; var best_dist: float = INF
	for obj in _all_interactives:
		if not is_instance_valid(obj) or not obj.is_active or obj.completed: continue
		var d = p.global_position.distance_to(obj.global_position)
		if d < 120.0 and d < best_dist: best_dist = d; best = obj
	if best: best.is_player_in_range = true
	return best


func _poll_interactives_in_range() -> void:
	var p = GameManager.player_ref
	if not p or not is_instance_valid(p): return
	for obj in _all_interactives:
		if is_instance_valid(obj): obj.check_player_in_range(p)

func _on_object_interacted(data: Dictionary) -> void:
	var oid: String = data.get("object_id", "")
	if oid == "guide":
		if _float_text: _float_text.visible = false
		_show_narrative("[color=cyan]阿明：[/color]攻击怪物或被怪物攻击时，世界会瞬间切换。\n我需要借助世界切换来脱离这里的卡死。")
	elif oid == "greeting":
		_show_floating_text("晚上好，椰汁城")


# ============================================================
# 每帧
# ============================================================

func _process(delta: float) -> void:
	# 切换冷却计数
	if _swap_cooldown > 0.0: _swap_cooldown -= delta

	# 交互物轮询
	_poll_interactives_in_range()

	# 浮动文字计时
	if _float_text_timer > 0.0:
		_float_text_timer -= delta
		if _float_text_timer <= 0.0 and _float_text:
			_float_text.visible = false
		elif _float_text:
			var p = GameManager.player_ref
			if p and is_instance_valid(p):
				_float_text.global_position = p.global_position + Vector2(-40, -60)

	# 交互冷却后安全退出
	if _is_interacting and not _narrative_open:
		_is_interacting = false






func _show_floating_text(txt: String) -> void:
	if not _float_text:
		_float_text = Label.new()
		_float_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_float_text.add_theme_font_size_override("font_size", 16)
		_float_text.add_theme_color_override("font_color", Color(1, 0.9, 0.4))
		_float_text.size = Vector2(200, 30)
		add_child(_float_text)
	_float_text.text = txt
	_float_text.visible = true
	var p = GameManager.player_ref
	if p and is_instance_valid(p):
		_float_text.global_position = p.global_position + Vector2(-40, -60)
	_float_text_timer = 1.5


# ============================================================
# 其余函数
# ============================================================

func _ensure_player_collision_layer() -> void:
	var p = GameManager.player_ref
	if p and is_instance_valid(p) and not (p.collision_layer & GlobalDefine.Collision.PLAYER):
		p.collision_layer |= GlobalDefine.Collision.PLAYER

func _setup_camera_limits() -> void:
	if not level_config: return
	var p = GameManager.player_ref; if not p or not is_instance_valid(p): return
	var c = p.get_node_or_null("SmoothCamera") as SmoothCamera; if not c: return
	c.limit_left = level_config.camera_limit_left; c.limit_right = level_config.camera_limit_right
	c.limit_top = level_config.camera_limit_top; c.limit_bottom = level_config.camera_limit_bottom

func _set_camera_limits(l: int, r: int, t: int, b: int) -> void:
	var p = GameManager.player_ref; if not p or not is_instance_valid(p): return
	var c = p.get_node_or_null("SmoothCamera") as SmoothCamera; if not c: return
	c.limit_left = l; c.limit_right = r; c.limit_top = t; c.limit_bottom = b

func _restore_combat_mechanics() -> void:
	var p = GameManager.player_ref; if not p: return
	p.can_attack = true; p.can_dash = true; p.can_skill = true

func _freeze_player(f: bool) -> void:
	var p = GameManager.player_ref; if not p: return
	if f:
		p.velocity = Vector2.ZERO; p.set_physics_process(false); p.set_process_input(false)
		p._change_state(GlobalDefine.PlayerState.IDLE)
	else:
		p.set_physics_process(true); p.set_process_input(true)


# ---- 叙事 ----

func _show_narrative(text: String, cb: Callable = Callable()) -> void:
	InputManager.block_input("叙事面板", self)
	if _narrative_open: _narrative_panel.hide(); _narrative_open = false
	_is_interacting = true; _narrative_open = true; _freeze_player(true)
	if _narrative_panel: _narrative_panel.show(); _narrative_text.text = text
	await get_tree().create_timer(0.3).timeout
	_narrative_enter_pressed = false
	var w: float = 0.0
	while _narrative_open and w < NARRATIVE_INPUT_TIMEOUT:
		if _narrative_enter_pressed: break
		await get_tree().create_timer(0.05).timeout; w += 0.05
	_narrative_panel.hide(); _freeze_player(false)
	_narrative_open = false; _is_interacting = false
	InputManager.unblock_input("叙事面板")
	if cb.is_valid(): cb.call()


# ---- 地图切换 ----

func _on_combat_hit(_d: Dictionary) -> void:
	if current_state != LevelState.HOMOMORPHIC_COMBAT: return
	if _narrative_open or _is_interacting: return
	if _swap_cooldown > 0.0: return
	_swap_cooldown = 0.8
	_is_interacting = true
	_swap_world()
	_is_interacting = false


func _on_wall_trigger(_body: Node2D) -> void:
	if _wall_dialog_shown: return
	_wall_dialog_shown = true
	_show_narrative("[color=gray]前面没有路了……[/color]")

func _swap_world() -> void:
	var p = GameManager.player_ref; if not p or not is_instance_valid(p): return
	_flash_screen()

	if _current_world == 0:
		var tgt = LNGN_POSITIONS[_lingnan_spawn_index]
		var dia = LNGN_DIALOGS[_lingnan_spawn_index]
		_lingnan_spawn_index = (_lingnan_spawn_index + 1) % LNGN_POSITIONS.size()
		p.global_position = tgt; _current_world = 1
		_swap_player_skin("Lingnan"); p = GameManager.player_ref
		p.velocity = Vector2.ZERO
		_snap_camera(p)
		_set_camera_limits(LNGN_CAM[0], LNGN_CAM[1], LNGN_CAM[2], LNGN_CAM[3])
		_spawn_lingnan_enemies_once()
		if dia != "":
			get_tree().create_timer(1.0).timeout.connect(func():
				if _current_world != 1 or _narrative_open: return
				_show_narrative("[color=cyan]阿明：[/color]" + dia)
			)
	else:
		p.global_position = CYBER_TELEPORT; _current_world = 0
		_swap_player_skin("Cyber"); p = GameManager.player_ref
		p.velocity = Vector2.ZERO
		_snap_camera(p)
		_set_camera_limits(CYBER_CAM[0], CYBER_CAM[1], CYBER_CAM[2], CYBER_CAM[3])
		if not _cyber_return_dialog_shown:
			_cyber_return_dialog_shown = true
			get_tree().create_timer(1.0).timeout.connect(func():
				if _current_world != 0 or _narrative_open: return
				_show_narrative("[color=cyan]阿明：[/color]我又回来了，可能需要多切换几次。")
			)
	_swap_count += 1

func _snap_camera(p: CharacterBody2D) -> void:
	var c = p.get_node_or_null("SmoothCamera")
	if c: c.global_position = p.global_position

func _flash_screen() -> void:
	if _glitch_overlay and _glitch_overlay.material:
		_glitch_overlay.show()
		var m = _glitch_overlay.material as ShaderMaterial
		m.set_shader_parameter("intensity", 1.0)
		create_tween().tween_property(m, "shader_parameter/intensity", 0.0, 0.25)
	var f = ColorRect.new()
	f.name = "SwapFlash"; f.set_anchors_preset(Control.PRESET_FULL_RECT)
	f.color = Color.WHITE; f.mouse_filter = Control.MOUSE_FILTER_IGNORE; f.z_index = 100
	var cv = $CanvasLayerUI; if cv: cv.add_child(f)
	var t = create_tween(); t.tween_property(f, "color:a", 0.0, 0.3); t.tween_callback(f.queue_free)


# ---- 敌人 ----

func _spawn_stage1_enemies() -> void:
	if not _enemy_cyber_wolf_scene: return
	var sp = level_data.surface_enemy_spawn_points if level_data else []
	if sp.is_empty(): sp = [Vector2(400, 540), Vector2(600, 540), Vector2(800, 540), Vector2(1000, 540), Vector2(1400, 540)]
	var cf = load("res://DataConfig/Enemy/CleanerConfig.tres") as EnemyConfig
	for s in sp:
		var e = _spawn_enemy_with_config(_enemy_cyber_wolf_scene, s, cf)
		if e: e.modulate = Color(0.3, 0.3, 0.35, 0.95); _stage1_enemies.append(e)
	print("[Level_04] 赛博敌人生成: %d 只" % _stage1_enemies.size())

func _spawn_lingnan_enemies_once() -> void:
	if _lingnan_enemies_spawned: return
	_lingnan_enemies_spawned = true
	if not _enemy_cyber_wolf_scene: return
	var cf = load("res://DataConfig/Enemy/CleanerConfig.tres") as EnemyConfig
	for s in [Vector2(1000, 2100), Vector2(2000, 2150), Vector2(3000, 2100)]:
		var e = _spawn_enemy_with_config(_enemy_cyber_wolf_scene, s, cf)
		if e: e.modulate = Color(0.2, 0.15, 0.35, 0.95); _stage1_enemies.append(e)
	print("[Level_04] 岭南敌人生成: 3 只")

func _spawn_enemy_with_config(sc: PackedScene, sp: Vector2, cf: EnemyConfig) -> Node2D:
	if not sc: return null
	var e = sc.instantiate(); if cf: e.config = cf; e.global_position = sp
	(_dynamic_actors if _dynamic_actors else self).add_child(e); return e

func _on_enemy_died(data: Dictionary) -> void:
	var e = data.get("enemy")
	if not e or not is_instance_valid(e): return
	if current_state == LevelState.HOMOMORPHIC_COMBAT and e in _stage1_enemies:
		_stage1_enemies.erase(e); _swap_count += 2


# ---- 终局 ----

func _trigger_level_end() -> void:
	current_state = LevelState.LEVEL_END_TRANSIT
	if _ending_prompt: _ending_prompt.show()
	if _ending_label and level_data: _ending_label.text = level_data.override_protocol_text
	_ending_enter_armed = true

func _emit_level_complete() -> void:
	if _level_complete_emitted: return
	_level_complete_emitted = true
	_full_cleanup()
	EventBus.emit(GlobalDefine.EventName.LEVEL_COMPLETE, {"level": self, "next_level": level_data.next_level_path if level_data else ""})

func _full_cleanup() -> void:
	for e in _stage1_enemies:
		if is_instance_valid(e): GameManager.unregister_enemy(e); e.queue_free()
	_stage1_enemies.clear(); EventBus.unsubscribe_all(self)
