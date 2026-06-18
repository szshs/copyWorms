# ============================================================
# Level_05.gd - 第五关（双世界 PixelTearing 侵蚀预览）
# 安全区跟随玩家，player_uv 映射到 TopSprite 的 UV 空间
# ← → 侵蚀深度  /  空格切换上层地图
# ============================================================
extends LevelBase
class_name Level_05

@onready var _top_sprite: Sprite2D = $TopSprite
@onready var _bot_sprite: Sprite2D = $BotSprite
@onready var _label: Label = $CanvasLayer/InfoLabel
@onready var _cyber_collisions: Node2D = $CyberCollisions
@onready var _lingnan_collisions: Node2D = $LingnanCollisions

var _top_mat: ShaderMaterial = null
var _edge_tear: ColorRect = null
var _corruption: float = 0.35
var _top_is_lingnan: bool = true

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
		add_child(p)
		GameManager.register_player(p)
		var cam = p.get_node_or_null("SmoothCamera")
		if cam and cam is Camera2D:
			cam.enabled = true
			cam.make_current()
			cam.zoom = Vector2(1.25, 1.25)
			cam.limit_left = -1702; cam.limit_right = 2982
			cam.limit_top = 210; cam.limit_bottom = 540

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

	# 加载敌人场景
	_enemy_lantern_scene = _load_scene("res://EnemyModule/Formal/Enemy_LanternGhost.tscn")
	_enemy_paper_scene   = _load_scene("res://EnemyModule/Formal/Enemy_PaperEffigy.tscn")
	_enemy_wolf_scene    = _load_scene("res://EnemyModule/Formal/Enemy_CyberWolf.tscn")
	_enemy_bull_scene    = _load_scene("res://EnemyModule/Formal/Enemy_CyberBull.tscn")

	# 初始：岭南在上 → 赛博在下层透出 → 激活赛博碰撞体
	_set_collision_group_active(_cyber_collisions, true)
	_set_collision_group_active(_lingnan_collisions, false)

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

	_label.add_theme_font_size_override("font_size", 16)
	_label.add_theme_color_override("font_color", Color.WHITE)
	_update_label()

	set_process_input(true)
	set_process(true)




func _process(delta: float) -> void:
	# 侵蚀值随时间增长
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

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_left"):
		_corruption = maxf(0.0, _corruption - 0.05)
		get_viewport().set_input_as_handled()
		_update_label()
	elif event.is_action_pressed("ui_right"):
		_corruption = minf(1.0, _corruption + 0.05)
		get_viewport().set_input_as_handled()
		_update_label()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_E:
		get_viewport().set_input_as_handled()
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
	var top_name = "岭南" if _top_is_lingnan else "赛博"
	_label.text = "侵蚀:%.0f%% | E换层 | 上层:%s" % [_erosion_value, top_name]

func _load_scene(path: String) -> PackedScene:
	if ResourceLoader.exists(path):
		return load(path)
	return null

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
