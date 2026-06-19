# ============================================================
# Level_05.gd - 第五关（双世界 PixelTearing 侵蚀预览）
# 安全区跟随玩家，player_uv 映射到 TopSprite 的 UV 空间
# ← → 侵蚀深度  /  空格切换上层地图
# ============================================================
extends LevelBase
class_name Level_05

@onready var _top_sprite: Sprite2D = $TopSprite
@onready var _bot_sprite: Sprite2D = $BotSprite
@onready var _cyber_collisions: Node2D = $CyberCollisions
@onready var _lingnan_collisions: Node2D = $LingnanCollisions

var _top_mat: ShaderMaterial = null
var _edge_tear: ColorRect = null
var _corruption: float = 0.35
var _top_is_lingnan: bool = true
var _debug_panel: Control = null
var _in_boss_arena: bool = false
var _boss_instance: Node2D = null
var _current_player_skin: String = "Cyber"   # 当前玩家皮肤（"Cyber"/"Lingnan"），用于G键切换
var _layer_swap_cd: float = 0.0              # 双世界切换冷却（防战斗中频繁切换）
const LAYER_SWAP_COOLDOWN: float = 1.2       # 切换冷却时长

# ---- bg5 区域（Boss击杀后灯笼对话跳转） ----
var _in_bg5: bool = false
var _lantern_instance: Node2D = null
@onready var _bg5_bg: Sprite2D = $Bg5
@onready var _bg5_collisions: Node2D = $Bg5Collisions
const BG5_CENTER_X: float = 569.0            # bg5区域x中心（与bg4远离）
const BG5_PLAYER_POS := Vector2(569, 8076)
const BG5_CAM_LEFT: int = 200
const BG5_CAM_RIGHT: int = 2200
const BG5_CAM_TOP: int = 7700
const BG5_CAM_BOTTOM: int = 8300

# ---- 交互物 ----
var _all_interactives: Array[InteractiveObject] = []

# ---- Boss 血条 ----
var _boss_bar_container: Control = null
var _boss_bar_fill: ColorRect = null
var _boss_bar_label: Label = null
const BOSS_BAR_MAX_WIDTH: float = 400.0

# ---- 对话框 ----
var _dialog_panel: Panel = null
var _dialog_label: RichTextLabel = null
var _dialog_enter_pressed: bool = false
var _dialog_open: bool = false
var _dialog_callback: Callable = Callable()
var _dialog_lines: Array[String] = []
var _dialog_index: int = 0
var _dialog_close_cooldown: float = 0.0   # 对话关闭后的输入冷却，防Enter串扰

# ---- 侵蚀值 ----
var _erosion_value: float = 0.0
var _erosion_bar_bg: ColorRect = null
var _erosion_bar_fill: ColorRect = null
var _erosion_label: Label = null
const EROSION_MAX: float = 100.0
const EROSION_RATE: float = 0.35
const EROSION_KILL_REDUCE: float = 15.0

# ---- 敌人 ----
## 所有敌人：换层时清空重建
var _all_enemies: Array[Node2D] = []
var _enemy_lantern_scene: PackedScene = null
var _enemy_paper_scene: PackedScene = null
var _enemy_wolf_scene: PackedScene = null
var _enemy_bull_scene: PackedScene = null


func _setup_player() -> void:
	# 清除 lv4 遗留的旧玩家引用
	if GameManager.player_ref:
		if is_instance_valid(GameManager.player_ref):
			GameManager.player_ref.queue_free()
		GameManager.player_ref = null

	var path = "res://PlayerModule/Formal/Player_Warrior_Cyber.tscn"
	if ResourceLoader.exists(path):
		var p = load(path).instantiate()
		p.position = Vector2(-1603, 380)
		_current_player_skin = "Cyber"
		add_child(p)
		GameManager.register_player(p)
		var cam = p.get_node_or_null("SmoothCamera") as SmoothCamera
		if cam:
			cam.limit_left = -1702; cam.limit_right = 2982
			cam.limit_top = 210; cam.limit_bottom = 540
			cam.zoom = Vector2(1.25, 1.25)
			cam.bind_target(p)
			cam.follow_enabled = true
			cam.make_current()
		# 推送血量到 HUD
		EventBus.emit(GlobalDefine.EventName.HEALTH_CHANGED, {
			"target": p,
			"current_health": p.current_health,
			"max_health": p.max_health
		})

func _swap_player_skin(skin: String) -> void:
	var old = GameManager.player_ref
	if not old or not is_instance_valid(old): return
	var h = old.current_health; var m = old.max_health
	var f = old.is_facing_right; var pos = old.global_position
	# 保存旧摄像机限制
	var old_cam = old.get_node_or_null("SmoothCamera")
	var saved_limits = null
	if old_cam:
		saved_limits = [old_cam.limit_left, old_cam.limit_right, old_cam.limit_top, old_cam.limit_bottom]
	if InputManager.game_action.is_connected(old._on_game_action):
		InputManager.game_action.disconnect(old._on_game_action)
	GameManager.player_ref = null; old.queue_free()
	var path = "res://PlayerModule/Formal/Player_Warrior_" + skin + ".tscn"
	if not ResourceLoader.exists(path): return
	var p = load(path).instantiate()
	p.global_position = pos; p.current_health = h
	p.max_health = m; p.is_facing_right = f; p.velocity = Vector2.ZERO
	add_child(p); GameManager.register_player(p)
	# 恢复摄像机：设限制 → bind_target(snap+reset) → 激活
	var cam = p.get_node_or_null("SmoothCamera") as SmoothCamera
	if cam:
		if saved_limits:
			cam.limit_left = saved_limits[0]; cam.limit_right = saved_limits[1]
			cam.limit_top = saved_limits[2]; cam.limit_bottom = saved_limits[3]
		cam.zoom = Vector2(1.25, 1.25)
		cam.bind_target(p)
		cam.follow_enabled = true
		cam.make_current()
	# 推送血量到 HUD（修复换皮肤后血条不更新）
	EventBus.emit(GlobalDefine.EventName.HEALTH_CHANGED, {
		"target": p,
		"current_health": p.current_health,
		"max_health": p.max_health
	})

## G键切换人物形象（仅bg4 Boss区域）：赛博 ↔ 岭南
func _toggle_boss_skin() -> void:
	var new_skin = "Lingnan" if _current_player_skin == "Cyber" else "Cyber"
	var path = "res://PlayerModule/Formal/Player_Warrior_" + new_skin + ".tscn"
	if not ResourceLoader.exists(path):
		print("[Level_05] 切换皮肤失败，场景不存在: %s" % path)
		return
	_current_player_skin = new_skin
	_swap_player_skin(new_skin)

func _snap_camera(p: CharacterBody2D) -> void:
	var c = p.get_node_or_null("SmoothCamera")
	if c: c.global_position = p.global_position

func _set_camera_limits(l: int, r: int, t: int, b: int) -> void:
	var p = GameManager.player_ref; if not p or not is_instance_valid(p): return
	var c = p.get_node_or_null("SmoothCamera") as SmoothCamera; if not c: return
	c.limit_left = l; c.limit_right = r; c.limit_top = t; c.limit_bottom = b

func _on_ready() -> void:
	super._on_ready()

	# 继承 lv4 的侵蚀值和血量
	var flags = GameManager.dream_runtime_flags
	if flags.has("erosion_value"):
		_erosion_value = flags["erosion_value"]
	if flags.has("player_health") and flags.has("player_max_health"):
		var p = GameManager.player_ref
		if p and is_instance_valid(p):
			p.current_health = flags["player_health"]
			p.max_health = flags["player_max_health"]

	# 订阅敌人死亡事件
	EventBus.subscribe(GlobalDefine.EventName.ENEMY_DIED, self, "_on_enemy_died")
	# 订阅战斗事件：击中敌人/被击中 → 触发双世界切换
	EventBus.subscribe(GlobalDefine.EventName.PLAYER_ATTACK_HIT, self, "_on_combat_swap_layer")
	EventBus.subscribe(GlobalDefine.EventName.PLAYER_HURT, self, "_on_combat_swap_layer")
	# 订阅交互事件
	EventBus.subscribe(GlobalDefine.EventName.INTERACTIVE_OBJECT_TRIGGERED, self, "_on_object_interacted")

	# 加载 HUD（修复 lv5 血条不显示）
	_load_hud()

	# 缓存交互物
	_cache_interactives()

	# 加载敌人场景
	_enemy_lantern_scene = _load_scene("res://EnemyModule/Formal/Enemy_LanternGhost.tscn")
	_enemy_paper_scene   = _load_scene("res://EnemyModule/Formal/Enemy_PaperEffigy.tscn")
	_enemy_wolf_scene    = _load_scene("res://EnemyModule/Formal/Enemy_CyberWolf.tscn")
	_enemy_bull_scene    = _load_scene("res://EnemyModule/Formal/Enemy_CyberBull.tscn")

	# 初始：岭南在上 → 赛博在下层透出 → 激活赛博碰撞体
	_set_collision_group_active(_cyber_collisions, true)
	_set_collision_group_active(_lingnan_collisions, false)
	# bg5 碰撞体初始禁用（tscn 已设 visible=false，碰撞体需脚本关闭）
	_set_bg5_area_active(false)

	# 岭南在上 → 纸人 + 灯笼
	_spawn_all_enemies(true)

	var shader = load("res://LevelModule/Formal/PixelTearing.gdshader")
	if shader:
		_top_mat = ShaderMaterial.new()
		_top_mat.shader = shader
		var noise = load("res://Resources/TearingNoiseTexture.tres")
		_top_mat.set_shader_parameter("noise_tex", noise)
		_top_mat.set_shader_parameter("noise_size", Vector2(512.0, 512.0))
		_top_mat.set_shader_parameter("corruption_level", _corruption)
		_top_mat.set_shader_parameter("player_uv", Vector2(0.5, 0.5))
		_top_mat.set_shader_parameter("chunk_size", 20.0)
		_top_mat.set_shader_parameter("glitch_color", Color(0.8, 0.1, 0.6, 1.0))
		_top_sprite.material = _top_mat

	# 边缘撕裂覆盖层
	var cv = get_node_or_null("CanvasLayer")
	if cv:
		_edge_tear = ColorRect.new()
		_edge_tear.name = "EdgeTear"
		_edge_tear.set_anchors_preset(Control.PRESET_FULL_RECT)
		_edge_tear.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_edge_tear.z_index = 110
		var tear_shader = load("res://LevelModule/Formal/edge_tear.gdshader")
		if tear_shader:
			var mat = ShaderMaterial.new()
			mat.shader = tear_shader
			mat.set_shader_parameter("intensity", 0.2)
			_edge_tear.material = mat
		cv.add_child(_edge_tear)

	# 侵蚀进度条
	_build_erosion_bar()

	set_process_input(true)
	set_process(true)

	# 检查点恢复：如果之前在bg4死亡，直接传送玩家到bg4区域重新开始Boss战
	print("[Level_05] 检查点阶段: %d, 路径: %s" % [GameManager.checkpoint_stage, GameManager.checkpoint_scene_path])
	if GameManager.checkpoint_stage >= 4:
		# 跳过bg3，直接进入bg4
		_in_boss_arena = true
		# 标记交互点已完成（避免重复触发）
		for obj in _all_interactives:
			if obj.object_id == "enter_boss":
				obj.mark_completed()
		# 直接传送到bg4并生成Boss
		_teleport_and_setup_camera(Vector2(931, 5037), 620, 1710, 4509, 5135, 1.5)
		_set_boss_area_active(true)
		_set_map_sprites_visible(false)
		_spawn_boss()
		_show_boss_bar()
		# 恢复玩家满血
		var pp = GameManager.player_ref
		if pp and is_instance_valid(pp):
			pp.current_health = pp.max_health
			EventBus.emit(GlobalDefine.EventName.HEALTH_CHANGED, {
				"target": pp,
				"current_health": pp.current_health,
				"max_health": pp.max_health
			})
		print("[Level_05] 从检查点恢复：直接进入bg4 Boss战")




func _process(delta: float) -> void:
	# 切换冷却递减
	_layer_swap_cd = maxf(0.0, _layer_swap_cd - delta)
	# 对话期间暂停侵蚀
	if not _dialog_open and not _in_bg5:
		_modify_erosion(EROSION_RATE * delta)
	_corruption = _erosion_value / 100.0

	# player_uv → 玩家在屏幕上的 UV
	var player_uv = Vector2(0.5, 0.5)
	var p = GameManager.player_ref
	var vp = get_viewport()
	if p and is_instance_valid(p) and vp:
		var size = vp.get_visible_rect().size
		if size.x > 0.0 and size.y > 0.0:
			# get_global_transform_with_canvas() 包含相机变换 → 真实屏幕像素坐标
			var screen_pos = p.get_global_transform_with_canvas().origin
			player_uv = Vector2(
				clampf(screen_pos.x / size.x, 0.0, 1.0),
				clampf(screen_pos.y / size.y, 0.0, 1.0)
			)

	_top_mat.set_shader_parameter("corruption_level", _corruption)
	_top_mat.set_shader_parameter("player_uv", player_uv)

	# 边缘撕裂强度随侵蚀值上升
	if _edge_tear and _edge_tear.material:
		_edge_tear.material.set_shader_parameter("intensity", clampf(_corruption * 0.6, 0.05, 0.5))

	# 交互物轮询兜底（对话期间不检测；冷却期间仍检测距离，只防Enter串扰）
	var pl = GameManager.player_ref
	if pl and is_instance_valid(pl) and not _dialog_open:
		for obj in _all_interactives:
			if is_instance_valid(obj):
				obj.check_player_in_range(pl)
	# 对话关闭冷却递减
	_dialog_close_cooldown = maxf(0.0, _dialog_close_cooldown - delta)
	# 灯笼提示更新
	_update_lantern_prompt()

	# Boss 血条更新
	_update_boss_bar()

	# 对话推进
	if _dialog_open and _dialog_enter_pressed:
		_dialog_enter_pressed = false
		_advance_dialog()

func _input(event: InputEvent) -> void:
	# 对话框打开时，Enter 推进对话
	if _dialog_open:
		if event.is_action_pressed("ui_accept"):
			_dialog_enter_pressed = true
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_left"):
		_corruption = maxf(0.0, _corruption - 0.05)
		get_viewport().set_input_as_handled()
		_update_label()
	elif event.is_action_pressed("ui_right"):
		_corruption = minf(1.0, _corruption + 0.05)
		get_viewport().set_input_as_handled()
		_update_label()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_1:
		_toggle_debug_panel()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		if _dialog_close_cooldown > 0:
			get_viewport().set_input_as_handled()
		else:
			# 优先检测灯笼（自定义交互）
			if _is_player_near_lantern() and not _in_bg5:
				_on_lantern_interacted()
				get_viewport().set_input_as_handled()
			else:
				var obj = _find_nearby_interactive()
				if obj:
					EventBus.emit(GlobalDefine.EventName.INTERACTIVE_OBJECT_TRIGGERED, {"object_id": obj.object_id})
					get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_G:
		# G键切换人物形象（仅限bg4 Boss区域，赛博/岭南之间切换）
		if _in_boss_arena and not _dialog_open:
			_toggle_boss_skin()
			get_viewport().set_input_as_handled()


## 切换双世界上下层（bg3区域）：战斗触发，带抖屏效果
func _swap_world_layer() -> void:
	_top_is_lingnan = not _top_is_lingnan
	if _top_is_lingnan:
		_top_sprite.texture = load("res://LevelModule/Scenes/PixelworkMapStitch/Level05_Lingnan/bg 3-2.png")
		_top_sprite.scale = Vector2(1.6, 1.6)
		_bot_sprite.texture = load("res://LevelModule/Scenes/PixelworkMapStitch/Level05_Cyber/bg 3-1.png")
		_bot_sprite.scale = Vector2(0.8, 0.8)
		_top_mat.set_shader_parameter("glitch_color", Color(0.8, 0.1, 0.6, 1.0))
		_set_collision_group_active(_lingnan_collisions, false)
		_set_collision_group_active(_cyber_collisions, true)
		_spawn_all_enemies(true)
	else:
		_top_sprite.texture = load("res://LevelModule/Scenes/PixelworkMapStitch/Level05_Cyber/bg 3-1.png")
		_top_sprite.scale = Vector2(0.8, 0.8)
		_bot_sprite.texture = load("res://LevelModule/Scenes/PixelworkMapStitch/Level05_Lingnan/bg 3-2.png")
		_bot_sprite.scale = Vector2(1.6, 1.6)
		_top_mat.set_shader_parameter("glitch_color", Color(0.1, 0.8, 0.9, 1.0))
		_set_collision_group_active(_lingnan_collisions, true)
		_set_collision_group_active(_cyber_collisions, false)
		_spawn_all_enemies(false)
	_update_label()
	# 抖屏效果：世界撕裂感
	_trigger_screen_shake(8.0, 0.25)


## 触发抖屏（通过玩家相机的 shake 方法）
func _trigger_screen_shake(strength: float, duration: float) -> void:
	var p = GameManager.player_ref
	if not p or not is_instance_valid(p): return
	var cam = p.get_node_or_null("SmoothCamera") as SmoothCamera
	if cam and cam.has_method("shake"):
		cam.shake(strength, duration)


## 战斗触发双世界切换：击中敌人或被击中时（仅bg3区域，带冷却防频繁切换）
func _on_combat_swap_layer(_data: Dictionary) -> void:
	# 仅在bg3双世界区域生效，Boss区域/bg5内不触发
	if _in_boss_arena or _in_bg5: return
	if _dialog_open: return
	if _layer_swap_cd > 0.0: return
	_layer_swap_cd = LAYER_SWAP_COOLDOWN
	_swap_world_layer()


func _set_collision_group_active(group: Node2D, active: bool) -> void:
	if not group: return
	for child in group.get_children():
		if child is CollisionShape2D:
			child.set_deferred("disabled", not active)
		elif child is StaticBody2D:
			for c in child.get_children():
				if c is CollisionShape2D:
					c.set_deferred("disabled", not active)

func _update_label() -> void:
	pass  # InfoLabel 已移除，侵蚀信息由 _erosion_label 显示

func _load_scene(path: String) -> PackedScene:
	if ResourceLoader.exists(path):
		return load(path)
	return null

func _load_hud() -> void:
	var p = "res://UI/HUD.tscn"
	if ResourceLoader.exists(p):
		var hud = load(p).instantiate()
		add_child(hud)
		# 立即推送当前血量到 HUD
		var pl = GameManager.player_ref
		if pl and is_instance_valid(pl):
			EventBus.emit(GlobalDefine.EventName.HEALTH_CHANGED, {
				"target": pl,
				"current_health": pl.current_health,
				"max_health": pl.max_health
			})

func _cache_interactives() -> void:
	_all_interactives.clear()
	for child in get_children():
		if child is InteractiveObject:
			_all_interactives.append(child)
			# 复用关卡一的光点视觉
			child.apply_level01_dot_visual()

func _find_nearby_interactive() -> InteractiveObject:
	for obj in _all_interactives:
		if is_instance_valid(obj) and obj.is_active and not obj.completed and obj.is_player_in_range:
			return obj
	return null

func _on_object_interacted(data: Dictionary) -> void:
	var oid: String = data.get("object_id", "")
	if oid == "enter_boss":
		_enter_boss_arena()

## Boss死亡时缓结束后：恢复时缓，生成灯笼，显示死亡对话
func _on_boss_death_recover(death_pos: Vector2) -> void:
	Engine.time_scale = 1.0
	_spawn_lantern(death_pos)
	_show_dialog([
		"[color=#ff6b9d]花旦：[/color]为什么要拥抱……残酷的现实……",
	], Callable())

## 在Boss死亡位置生成灯笼交互物
func _spawn_lantern(pos: Vector2) -> void:
	if _lantern_instance and is_instance_valid(_lantern_instance):
		_lantern_instance.queue_free()
	var lantern = Node2D.new()
	lantern.name = "BossLantern"
	lantern.global_position = pos + Vector2(0, 15)
	# 灯笼背后的发光
	var glow = Sprite2D.new()
	glow.name = "Glow"
	var tex = load("res://Assets/Effects/灯笼.png") as Texture2D
	if tex:
		glow.texture = tex
		glow.scale = Vector2(0.05, 0.05)
		glow.modulate = Color(1.0, 0.8, 0.3, 0.6)
		glow.z_index = 4
		lantern.add_child(glow)
	# 灯笼贴图
	if tex:
		var spr = Sprite2D.new()
		spr.name = "LanternSprite"
		spr.texture = tex
		spr.scale = Vector2(0.05, 0.05)
		spr.z_index = 5
		lantern.add_child(spr)
	# 交互提示标签
	var prompt = Label.new()
	prompt.name = "Prompt"
	prompt.text = "按 Enter 拾起灯笼"
	prompt.visible = false
	prompt.add_theme_font_size_override("font_size", 14)
	prompt.add_theme_color_override("font_color", Color(1, 0.9, 0.2, 0.95))
	prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.position = Vector2(-80, -55)
	prompt.size = Vector2(160, 20)
	lantern.add_child(prompt)
	add_child(lantern)
	_lantern_instance = lantern
	if tex and glow:
		_play_lantern_spawn(lantern, glow)
	print("[Level_05] 灯笼已生成于 %s" % lantern.global_position)

## 灯笼出场动效：从小变大出现 + 落地弹两下
## 注意：只移动 sprite/glow 子节点（视觉），不移动 lantern 本身（Area2D位置不变，防body_exited误触发）
func _play_lantern_spawn(lantern: Node2D, glow: Sprite2D) -> void:
	var spr = lantern.get_node_or_null("LanternSprite") as Sprite2D
	if not spr: return
	# 视觉初始位置：上方100px，scale从0增长
	spr.position = Vector2(0, -100)
	glow.position = Vector2(0, -100)
	spr.scale = Vector2(0.0, 0.0)
	glow.scale = Vector2(0.0, 0.0)
	# glow 呼吸动画（持续循环）
	var glow_tw = glow.create_tween().set_loops()
	glow_tw.tween_property(glow, "modulate:a", 0.3, 0.8).set_trans(Tween.TRANS_SINE)
	glow_tw.tween_property(glow, "modulate:a", 0.7, 0.8).set_trans(Tween.TRANS_SINE)
	# 出现：scale 0→0.05（0.4s），sprite/glow 从上方下落
	var tw = spr.create_tween()
	var gtw = glow.create_tween()
	tw.tween_property(spr, "scale", Vector2(0.05, 0.05), 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	gtw.tween_property(glow, "scale", Vector2(0.07, 0.07), 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# 下落到地面（y=0，即 lantern 中心）
	tw.tween_property(spr, "position:y", 0.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	gtw.parallel().tween_property(glow, "position:y", 0.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	# 弹起第一次（上移40，再落回）
	tw.tween_property(spr, "position:y", -40.0, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	gtw.parallel().tween_property(glow, "position:y", -40.0, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(spr, "position:y", 0.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	gtw.parallel().tween_property(glow, "position:y", 0.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	# 弹起第二次（上移15，再落回）
	tw.tween_property(spr, "position:y", -15.0, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	gtw.parallel().tween_property(glow, "position:y", -15.0, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(spr, "position:y", 0.0, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	gtw.parallel().tween_property(glow, "position:y", 0.0, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

## 玩家与灯笼交互：对话后跳转bg5
func _on_lantern_interacted() -> void:
	# 灯笼设为 allow_repeat，不标记 completed，对话结束后仍可再次交互
	_show_dialog([
		"[color=cyan]阿明：[/color]这是……爷爷给我的手提灯笼？",
	], _teleport_to_bg5)

## 检查玩家是否在灯笼交互范围内（自定义距离检测，不依赖Area2D）
func _is_player_near_lantern() -> bool:
	if not _lantern_instance or not is_instance_valid(_lantern_instance): return false
	var p = GameManager.player_ref
	if not p or not is_instance_valid(p): return false
	return p.global_position.distance_to(_lantern_instance.global_position) <= 130.0

## 更新灯笼提示标签显隐（每帧调用）
func _update_lantern_prompt() -> void:
	if not _lantern_instance or not is_instance_valid(_lantern_instance): return
	var prompt = _lantern_instance.get_node_or_null("Prompt")
	if not prompt: return
	var near = _is_player_near_lantern() and not _dialog_open and not _in_bg5
	prompt.visible = near
	if near:
		var alpha = 0.6 + 0.4 * abs(sin(Time.get_ticks_msec() * 0.004))
		prompt.add_theme_color_override("font_color", Color(1, 0.9, 0.2, alpha))

## 传送至bg5区域（激活bg5节点 + 传送 + 隐藏bg3/bg4）
func _teleport_to_bg5() -> void:
	_in_boss_arena = false
	_in_bg5 = true
	_set_boss_area_active(false)
	_set_map_sprites_visible(false)
	_set_bg5_area_active(true)
	_teleport_and_setup_camera(BG5_PLAYER_POS, BG5_CAM_LEFT, BG5_CAM_RIGHT, BG5_CAM_TOP, BG5_CAM_BOTTOM, 1.5)
	_hide_boss_bar()
	print("[Level_05] 已进入 bg5 区域")

## 激活/禁用bg5区域节点（背景显隐 + 碰撞体开关）
func _set_bg5_area_active(active: bool) -> void:
	if _bg5_bg:
		_bg5_bg.visible = active
	if _bg5_collisions:
		_bg5_collisions.visible = active
		_set_collision_group_active(_bg5_collisions, active)

func _enter_boss_arena() -> void:
	if _in_boss_arena: return
	_in_boss_arena = true
	# 标记交互完成
	for obj in _all_interactives:
		if obj.object_id == "enter_boss":
			obj.mark_completed()
	# 显示对话 → 对话结束后传送到 Boss 区域
	_show_dialog([
		"[color=#ff6b9d]花旦：[/color]阿明，你瞧，技术能给你你想要的一切",
		"[color=#ff6b9d]花旦：[/color]它能让回忆拥有形状，它能让记忆死而复生",
		"[color=#ff6b9d]花旦：[/color]留下来吧，永远留在这个温暖的世界里……",
	], _teleport_to_boss)

func _teleport_to_boss() -> void:
	_teleport_and_setup_camera(Vector2(931, 5037), 620, 1710, 4509, 5135, 1.5)
	_set_boss_area_active(true)
	_set_map_sprites_visible(false)
	_spawn_boss()
	_show_boss_bar()
	# 更新检查点阶段为4（bg4），重新开始时直接回到bg4
	GameManager.update_checkpoint_stage(4)

func _spawn_all_enemies(lingnan_on_top: bool) -> void:
	_clear_all_enemies()

	var ground_spots = [Vector2(-1000, 420), Vector2(0, 415), Vector2(800, 425)]
	var special_spots = [Vector2(200, 380), Vector2(600, 370)]

	if lingnan_on_top:
		# 纸人 + 灯笼
		for sp in ground_spots:
			_spawn_one(_enemy_paper_scene, sp)
		for sp in special_spots:
			_spawn_one(_enemy_lantern_scene, sp)
	else:
		# 狼人 + 冲撞兽
		for sp in ground_spots:
			_spawn_one(_enemy_wolf_scene, sp)
		for sp in special_spots:
			_spawn_one(_enemy_bull_scene, sp)

func _spawn_one(scene: PackedScene, pos: Vector2) -> void:
	if not scene: return
	var e = scene.instantiate()
	e.global_position = pos
	add_child(e)
	GameManager.register_enemy(e)
	_all_enemies.append(e)

func _clear_all_enemies() -> void:
	for e in _all_enemies:
		if is_instance_valid(e):
			GameManager.unregister_enemy(e)
			e.queue_free()
	_all_enemies.clear()


# ============================================================
# 侵蚀值
# ============================================================

func _build_erosion_bar() -> void:
	var cv = get_node_or_null("CanvasLayer")
	if not cv: return
	var bar = Control.new()
	bar.name = "ErosionBar"
	bar.position = Vector2(8, 52); bar.size = Vector2(280, 22)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.z_index = 130
	cv.add_child(bar)

	_erosion_bar_bg = ColorRect.new()
	_erosion_bar_bg.size = Vector2(280, 18); _erosion_bar_bg.position = Vector2(0, 2)
	_erosion_bar_bg.color = Color(0.1, 0.05, 0.12, 0.9)
	_erosion_bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(_erosion_bar_bg)

	_erosion_bar_fill = ColorRect.new()
	_erosion_bar_fill.size = Vector2(0, 18); _erosion_bar_fill.position = Vector2(0, 2)
	_erosion_bar_fill.color = Color(0.65, 0.15, 0.8, 0.95)
	_erosion_bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(_erosion_bar_fill)

	_erosion_label = Label.new()
	_erosion_label.size = Vector2(280, 18); _erosion_label.position = Vector2(0, 2)
	_erosion_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_erosion_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_erosion_label.add_theme_font_size_override("font_size", 11)
	_erosion_label.add_theme_color_override("font_color", Color.WHITE)
	_erosion_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(_erosion_label)

func _update_erosion_bar() -> void:
	if not _erosion_bar_fill or not _erosion_label: return
	var ratio = _erosion_value / EROSION_MAX
	_erosion_bar_fill.size.x = 280.0 * ratio
	_erosion_label.text = "侵蚀 %.0f%%" % _erosion_value
	if ratio > 0.7:
		_erosion_bar_fill.color = Color(0.9, 0.1, 0.2, 0.95)
	elif ratio > 0.4:
		_erosion_bar_fill.color = Color(0.8, 0.25, 0.5, 0.95)

func _modify_erosion(delta: float) -> void:
	_erosion_value = clampf(_erosion_value + delta, 0.0, EROSION_MAX)
	_update_erosion_bar()
	if _erosion_value >= EROSION_MAX:
		print("[Level_05] 侵蚀值已满！")
		GameManager.trigger_game_over()

func _on_enemy_died(data: Dictionary) -> void:
	var e = data.get("enemy")
	if not e or not is_instance_valid(e): return
	if e in _all_enemies:
		_modify_erosion(-EROSION_KILL_REDUCE)
	# Boss 死亡处理
	if e == _boss_instance:
		var death_pos: Vector2 = e.global_position
		_hide_boss_bar()
		GameManager.boss_target = null
		_boss_instance = null
		# 剧烈抖屏 + 时缓效果
		_trigger_screen_shake(22.0, 0.8)
		Engine.time_scale = 0.25
		# 1.5秒后恢复时缓，生成灯笼并显示死亡对话（ignore_time_scale 不受时缓影响）
		var t = get_tree().create_timer(1.5, true, false, true)
		t.timeout.connect(_on_boss_death_recover.bind(death_pos))


# ============================================================
# 调试面板 (按 1)
# ============================================================

func _toggle_debug_panel() -> void:
	if not _debug_panel:
		_create_debug_panel()
	_debug_panel.visible = not _debug_panel.visible

func _create_debug_panel() -> void:
	_debug_panel = Control.new()
	_debug_panel.name = "DebugPanel"
	_debug_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_debug_panel.position = Vector2(-220, 10)
	_debug_panel.size = Vector2(200, 60)
	_debug_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_debug_panel.z_index = 300

	var bgg = ColorRect.new()
	bgg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bgg.color = Color(0, 0, 0, 0.75)
	_debug_panel.add_child(bgg)

	var l = Label.new()
	l.text = "调试 [1]"
	l.position = Vector2(10, 5)
	l.add_theme_color_override("font_color", Color.WHITE)
	_debug_panel.add_child(l)

	var btn_bg3 = Button.new()
	btn_bg3.text = "bg3 (撕裂)"
	btn_bg3.position = Vector2(10, 28)
	btn_bg3.size = Vector2(85, 25)
	btn_bg3.pressed.connect(_debug_to_bg3)
	_debug_panel.add_child(btn_bg3)

	var btn_bg4 = Button.new()
	btn_bg4.text = "bg4 (Boss)"
	btn_bg4.position = Vector2(105, 28)
	btn_bg4.size = Vector2(85, 25)
	btn_bg4.pressed.connect(_debug_to_bg4)
	_debug_panel.add_child(btn_bg4)

	var btn_bg5 = Button.new()
	btn_bg5.text = "bg5"
	btn_bg5.position = Vector2(10, 56)
	btn_bg5.size = Vector2(85, 25)
	btn_bg5.pressed.connect(_debug_to_bg5)
	_debug_panel.add_child(btn_bg5)

	_debug_panel.size = Vector2(200, 90)

	var cv = get_node_or_null("CanvasLayer")
	if cv: cv.add_child(_debug_panel)
	else: add_child(_debug_panel)

func _debug_to_bg3() -> void:
	_debug_panel.visible = false
	_in_boss_arena = false
	_in_bg5 = false
	_hide_boss_bar()
	GameManager.boss_target = null
	_teleport_and_setup_camera(Vector2(-1603, 380), -1702, 2982, 210, 540, 1.25)
	_set_boss_area_active(false)
	_set_bg5_area_active(false)
	_set_map_sprites_visible(true)
	_despawn_boss()

func _debug_to_bg4() -> void:
	_debug_panel.visible = false
	_in_boss_arena = true
	_in_bg5 = false
	_set_bg5_area_active(false)
	_teleport_and_setup_camera(Vector2(931, 5037), 620, 1710, 4509, 5135, 1.5)
	_set_boss_area_active(true)
	_set_map_sprites_visible(false)
	_spawn_boss()
	_show_boss_bar()
	# 更新检查点阶段为4（bg4），重新开始时直接回到bg4
	GameManager.update_checkpoint_stage(4)

func _debug_to_bg5() -> void:
	_debug_panel.visible = false
	_in_boss_arena = false
	_in_bg5 = true
	_set_boss_area_active(false)
	_set_map_sprites_visible(false)
	_set_bg5_area_active(true)
	_hide_boss_bar()
	GameManager.boss_target = null
	_despawn_boss()
	_teleport_and_setup_camera(BG5_PLAYER_POS, BG5_CAM_LEFT, BG5_CAM_RIGHT, BG5_CAM_TOP, BG5_CAM_BOTTOM, 1.5)

func _spawn_boss() -> void:
	if _boss_instance and is_instance_valid(_boss_instance):
		_boss_instance.queue_free()
	var boss_scene = load("res://EnemyModule/Formal/Enemy_BossHuadan.tscn") as PackedScene
	if not boss_scene:
		printerr("[Level_05] 无法加载 Boss 场景")
		return
	_boss_instance = boss_scene.instantiate()
	_boss_instance.global_position = Vector2(1300, 5037)
	add_child(_boss_instance)
	# 设置 Boss 引用，供弹体自动瞄准
	GameManager.boss_target = _boss_instance
	print("[Level_05] Boss 已生成: %s" % _boss_instance.global_position)

func _despawn_boss() -> void:
	if _boss_instance and is_instance_valid(_boss_instance):
		_boss_instance.queue_free()
		_boss_instance = null
	GameManager.boss_target = null

func _teleport_and_setup_camera(pos: Vector2, lim_l: int, lim_r: int, lim_t: int, lim_b: int, z: float = 1.25) -> void:
	var p = GameManager.player_ref
	if not p or not is_instance_valid(p): return
	p.global_position = pos
	p.velocity = Vector2.ZERO
	var cam = p.get_node_or_null("SmoothCamera") as SmoothCamera
	if cam:
		cam.limit_left = lim_l; cam.limit_right = lim_r
		cam.limit_top = lim_t; cam.limit_bottom = lim_b
		cam.zoom = Vector2(z, z)
		cam.bind_target(p)           # snap 到玩家位置 + 重置 _last_target_x/_lookahead
		cam.follow_enabled = true    # 确保 _pan_camera 未残留关闭
		cam.make_current()
		print("[Level_05] 摄像机: limits=%d,%d,%d,%d zoom=%.2f pos=%s" % [lim_l, lim_r, lim_t, lim_b, z, pos])

func _set_boss_area_active(active: bool) -> void:
	var boss = get_node_or_null("BossCollisions")
	if boss:
		boss.visible = active
		_set_collision_group_active(boss, active)
	var bg4 = get_node_or_null("BossBg")
	if bg4:
		bg4.visible = active

func _set_map_sprites_visible(v: bool) -> void:
	_top_sprite.visible = v
	_bot_sprite.visible = v


# ============================================================
# 对话框系统
# ============================================================

func _show_dialog(lines: Array[String], callback: Callable = Callable()) -> void:
	_dialog_lines = lines
	_dialog_index = 0
	_dialog_callback = callback
	_dialog_open = true
	InputManager.block_input("对话", self)
	if not _dialog_panel:
		_create_dialog_panel()
	_dialog_panel.visible = true
	_show_dialog_line()

func _create_dialog_panel() -> void:
	var cv = get_node_or_null("CanvasLayer")
	if not cv: cv = self
	_dialog_panel = Panel.new()
	_dialog_panel.name = "DialogPanel"
	_dialog_panel.visible = false
	_dialog_panel.size = Vector2(1280, 200)
	_dialog_panel.position = Vector2(0, 520)
	_dialog_panel.z_index = 200
	_dialog_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 仿照前三关 NarrativePanel 样式：纯黑半透背景 + 圆角，无紫色边框
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.85)
	style.set_corner_radius_all(8)
	_dialog_panel.add_theme_stylebox_override("panel", style)
	cv.add_child(_dialog_panel)

	_dialog_label = RichTextLabel.new()
	_dialog_label.name = "RichTextLabel"
	_dialog_label.size = Vector2(1240, 160)
	_dialog_label.position = Vector2(20, 20)
	_dialog_label.bbcode_enabled = true
	_dialog_label.fit_content = true
	_dialog_label.add_theme_font_size_override("normal_font_size", 18)
	# 仿照前三关：暖色调文字（0.9, 0.85, 0.75），非纯白
	_dialog_label.add_theme_color_override("default_color", Color(0.9, 0.85, 0.75))
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
	_dialog_close_cooldown = 0.4  # 关闭后0.4秒内不检测交互，防Enter串扰
	InputManager.unblock_input("对话")
	if _dialog_callback.is_valid():
		_dialog_callback.call()


# ============================================================
# Boss 血条
# ============================================================

func _show_boss_bar() -> void:
	if not _boss_bar_container:
		_create_boss_bar()
	_boss_bar_container.visible = true
	# 订阅 Boss 受伤事件
	EventBus.subscribe(GlobalDefine.EventName.ENEMY_HURT, self, "_on_boss_hurt")

func _create_boss_bar() -> void:
	var cv = get_node_or_null("CanvasLayer")
	if not cv: cv = self
	_boss_bar_container = Control.new()
	_boss_bar_container.name = "BossBarContainer"
	_boss_bar_container.position = Vector2(440, 20)
	_boss_bar_container.size = Vector2(BOSS_BAR_MAX_WIDTH, 28)
	_boss_bar_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_bar_container.z_index = 150
	_boss_bar_container.visible = false
	cv.add_child(_boss_bar_container)

	var bg = ColorRect.new()
	bg.size = Vector2(BOSS_BAR_MAX_WIDTH, 28)
	bg.color = Color(0.1, 0.05, 0.12, 0.9)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_bar_container.add_child(bg)

	_boss_bar_fill = ColorRect.new()
	_boss_bar_fill.size = Vector2(BOSS_BAR_MAX_WIDTH, 28)
	_boss_bar_fill.color = Color(0.85, 0.1, 0.3, 0.95)
	_boss_bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_bar_container.add_child(_boss_bar_fill)

	_boss_bar_label = Label.new()
	_boss_bar_label.size = Vector2(BOSS_BAR_MAX_WIDTH, 28)
	_boss_bar_label.text = "花旦"
	_boss_bar_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_bar_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_boss_bar_label.add_theme_font_size_override("font_size", 15)
	_boss_bar_label.add_theme_color_override("font_color", Color.WHITE)
	_boss_bar_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_bar_container.add_child(_boss_bar_label)

func _update_boss_bar() -> void:
	if not _boss_bar_container or not _boss_bar_container.visible: return
	if not _boss_instance or not is_instance_valid(_boss_instance): return
	var hp = _boss_instance.current_health
	var max_hp = _boss_instance.max_health
	var ratio = clampf(float(hp) / float(max_hp), 0.0, 1.0)
	_boss_bar_fill.size.x = BOSS_BAR_MAX_WIDTH * ratio
	_boss_bar_label.text = "花旦  %d / %d" % [hp, max_hp]
	# 狂暴变色
	if ratio < 0.3:
		_boss_bar_fill.color = Color(0.95, 0.2, 0.1, 0.95)
	elif ratio < 0.6:
		_boss_bar_fill.color = Color(0.9, 0.4, 0.15, 0.95)

func _on_boss_hurt(data: Dictionary) -> void:
	var enemy = data.get("enemy")
	if enemy and enemy == _boss_instance:
		# 血条会在 _update_boss_bar 中自动更新
		pass

func _hide_boss_bar() -> void:
	if _boss_bar_container:
		_boss_bar_container.visible = false
	EventBus.unsubscribe(GlobalDefine.EventName.ENEMY_HURT, self)
