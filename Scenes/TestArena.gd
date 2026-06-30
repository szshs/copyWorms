# ============================================================
# TestArena.gd - 玩家测试场景
# 主界面按1进入，场景含地面+无限血量怪物，按0切换怪物类型
# 玩家2000血，可按G切人（赛博/岭南）
# ============================================================
extends Node2D

var _current_enemy: Node2D = null
var _enemy_index: int = 0
var _enemy_scenes: Array = []
var _enemy_names: Array = []

var _current_skin: String = "Cyber"
var _cyber_health: int = 2000
var _lingnan_health: int = 2000
const DUAL_CHAR_MAX_HP: int = 2000

var _test_panel: CanvasLayer = null
var _panel_visible: bool = false
var _drop_archive_screen: LingnanDropArchiveScreen = null

# ---- 掉落物测试 ----
var _active_drops: Array[DropItem] = []
const DROP_TYPES = ["月饼", "虾饺", "木棉", "醒狮", "烧卖", "蒲葵扇"]
const DROP_GROUND_Y: float = 730.0  # 地面表面上方（地面中心800，高度80，顶面760，掉落物中心730）

func _ready() -> void:
	# 背景
	var bg = ColorRect.new()
	bg.color = Color(0.15, 0.15, 0.18)
	bg.size = Vector2(1920, 1080)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.z_index = -10
	add_child(bg)

	# 地面（StaticBody2D + CollisionShape2D）
	var ground = StaticBody2D.new()
	ground.position = Vector2(960, 800)
	var ground_col = CollisionShape2D.new()
	var ground_shape = RectangleShape2D.new()
	ground_shape.size = Vector2(1920, 80)
	ground_col.shape = ground_shape
	ground.add_child(ground_col)
	add_child(ground)
	# 地面视觉
	var ground_vis = ColorRect.new()
	ground_vis.color = Color(0.3, 0.3, 0.35)
	ground_vis.size = Vector2(1920, 80)
	ground_vis.position = Vector2(0, 900)
	ground_vis.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ground_vis)

	# 加载所有敌人场景
	_load_enemy_scenes()

	# 创建玩家
	_setup_player()

	# 加载 HUD
	_load_hud()

	# 生成初始敌人
	_spawn_enemy(0)

	# 测试面板
	_build_test_panel()

	set_process_input(true)
	set_process(true)
	print("[TestArena] 测试场景加载完成")

func _load_enemy_scenes() -> void:
	var scenes = [
		{"path": "res://EnemyModule/Formal/Enemy_Slime.tscn", "name": "史莱姆"},
		{"path": "res://EnemyModule/Formal/Enemy_CyberWolf.tscn", "name": "赛博狼人"},
		{"path": "res://EnemyModule/Formal/Enemy_CyberBull.tscn", "name": "冲撞兽"},
		{"path": "res://EnemyModule/Formal/Enemy_LanternGhost.tscn", "name": "灯笼鬼"},
		{"path": "res://EnemyModule/Formal/Enemy_PaperEffigy.tscn", "name": "纸符人"},
		{"path": "res://EnemyModule/Formal/Enemy_BossHuadan.tscn", "name": "花旦Boss"},
	]
	for s in scenes:
		if ResourceLoader.exists(s.path):
			_enemy_scenes.append(load(s.path))
			_enemy_names.append(s.name)

func _setup_player() -> void:
	if GameManager.player_ref and is_instance_valid(GameManager.player_ref):
		GameManager.player_ref.queue_free()
		GameManager.player_ref = null
	var path = "res://PlayerModule/Formal/Player_Warrior_Cyber.tscn"
	if ResourceLoader.exists(path):
		var p = load(path).instantiate()
		p.position = Vector2(600, 700)
		_current_skin = "Cyber"
		_lingnan_health = DUAL_CHAR_MAX_HP
		add_child(p)
		GameManager.register_player(p)
		p.max_health = DUAL_CHAR_MAX_HP
		p.current_health = _cyber_health
		var cam = p.get_node_or_null("SmoothCamera") as SmoothCamera
		if cam:
			cam.zoom = Vector2(1.5, 1.5)
			cam.limit_left = 0
			cam.limit_right = 1920
			cam.limit_top = 0
			cam.limit_bottom = 1080
			cam.bind_target(p)
			cam.follow_enabled = true
			cam.make_current()
		EventBus.emit(GlobalDefine.EventName.HEALTH_CHANGED, {
			"target": p,
			"current_health": p.current_health,
			"max_health": p.max_health
		})

func _load_hud() -> void:
	var p = "res://UI/HUD.tscn"
	if ResourceLoader.exists(p):
		add_child(load(p).instantiate())

func _spawn_enemy(index: int) -> void:
	if _current_enemy and is_instance_valid(_current_enemy):
		GameManager.unregister_enemy(_current_enemy)
		_current_enemy.queue_free()
	_enemy_index = index % _enemy_scenes.size()
	if _enemy_scenes.is_empty(): return
	var e = _enemy_scenes[_enemy_index].instantiate()
	e.global_position = Vector2(1200, 700)
	add_child(e)
	GameManager.register_enemy(e)
	_current_enemy = e
	# 无限血量：覆写 max_health
	e.max_health = 999999
	e.current_health = 999999
	print("[TestArena] 生成敌人: %s" % _enemy_names[_enemy_index])

func _process(_delta: float) -> void:
	# 敌人死亡自动重生
	if not _current_enemy or not is_instance_valid(_current_enemy):
		_spawn_enemy(_enemy_index)
		return
	# 保持满血
	if _current_enemy.current_health < 999999:
		_current_enemy.current_health = 999999
		_current_enemy.is_dead = false
	# 掉落物距离轮询
	_process_drops()

func _input(event: InputEvent) -> void:
	if _drop_archive_screen and is_instance_valid(_drop_archive_screen) and _drop_archive_screen.visible:
		return
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_0:
				_open_lingnan_drop_archive()
				get_viewport().set_input_as_handled()
			KEY_1:
				_panel_visible = not _panel_visible
				if _test_panel:
					_test_panel.get_node_or_null("Panel").visible = _panel_visible
				get_viewport().set_input_as_handled()
			KEY_G:
				_toggle_skin()
				get_viewport().set_input_as_handled()
			KEY_ESCAPE:
				SceneTransitionManager.request_scene_change("res://UI/TitleScreen.tscn", self)
			KEY_2:
				_spawn_drop(0)
				get_viewport().set_input_as_handled()
			KEY_3:
				_spawn_drop(1)
				get_viewport().set_input_as_handled()
			KEY_4:
				_spawn_drop(2)
				get_viewport().set_input_as_handled()
			KEY_5:
				_spawn_drop(3)
				get_viewport().set_input_as_handled()
			KEY_6:
				_spawn_drop(4)
				get_viewport().set_input_as_handled()
			KEY_7:
				_spawn_drop(5)
				get_viewport().set_input_as_handled()
			KEY_ENTER, KEY_KP_ENTER:
				_try_pickup_drop()
				get_viewport().set_input_as_handled()

func _toggle_skin() -> void:
	var old = GameManager.player_ref
	if not old or not is_instance_valid(old): return
	if _current_skin == "Cyber":
		_cyber_health = old.current_health
	else:
		_lingnan_health = old.current_health
	var new_skin = "Lingnan" if _current_skin == "Cyber" else "Cyber"
	var f = old.is_facing_right; var pos = old.global_position
	if InputManager.game_action.is_connected(old._on_game_action):
		InputManager.game_action.disconnect(old._on_game_action)
	GameManager.player_ref = null; old.queue_free()
	var path = "res://PlayerModule/Formal/Player_Warrior_" + new_skin + ".tscn"
	if not ResourceLoader.exists(path): return
	var p = load(path).instantiate()
	p.global_position = pos
	p.is_facing_right = f; p.velocity = Vector2.ZERO
	add_child(p); GameManager.register_player(p)
	_current_skin = new_skin
	p.max_health = DUAL_CHAR_MAX_HP
	p.current_health = _cyber_health if new_skin == "Cyber" else _lingnan_health
	var cam = p.get_node_or_null("SmoothCamera") as SmoothCamera
	if cam:
		cam.zoom = Vector2(1.5, 1.5)
		cam.limit_left = 0; cam.limit_right = 1920
		cam.limit_top = 0; cam.limit_bottom = 1080
		cam.bind_target(p)
		cam.follow_enabled = true
		cam.make_current()
	EventBus.emit(GlobalDefine.EventName.HEALTH_CHANGED, {
		"target": p,
		"current_health": p.current_health,
		"max_health": p.max_health
	})

func _build_test_panel() -> void:
	_test_panel = CanvasLayer.new()
	_test_panel.layer = 500
	add_child(_test_panel)
	var panel = Panel.new()
	panel.name = "Panel"
	panel.position = Vector2(500, 200)
	panel.size = Vector2(280, 114 + _enemy_names.size() * 50)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.08, 0.92)
	style.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_test_panel.add_child(panel)
	var title = Label.new()
	title.text = "怪物切换 (按1开关)\n图鉴: 0=岭南梦物志\n掉落物: 2=月饼 3=虾饺 4=木棉 5=醒狮 6=烧卖 7=蒲葵扇"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
	title.position = Vector2(10, 10)
	title.size = Vector2(260, 94)
	panel.add_child(title)
	for i in _enemy_names.size():
		var btn = Button.new()
		btn.text = _enemy_names[i]
		btn.position = Vector2(10, 104 + i * 50)
		btn.size = Vector2(260, 40)
		btn.add_theme_font_size_override("font_size", 16)
		btn.focus_mode = Control.FOCUS_NONE
		var idx = i
		btn.pressed.connect(func(): _spawn_enemy(idx))
		panel.add_child(btn)
	panel.visible = false

func _open_lingnan_drop_archive() -> void:
	if _drop_archive_screen and is_instance_valid(_drop_archive_screen):
		return
	_drop_archive_screen = LingnanDropArchiveScreen.show_archive(self)
	_drop_archive_screen.closed.connect(func() -> void:
		_drop_archive_screen = null
	)

# ---- 掉落物系统 ----

## 生成掉落物（index: 0=月饼 1=虾饺 2=木棉 3=醒狮）
func _spawn_drop(index: int) -> void:
	if index < 0 or index >= DROP_TYPES.size(): return
	var drop_type = DROP_TYPES[index]
	# 随机X坐标（地面范围内 100~1820）
	var x = randf_range(100.0, 1820.0)
	var pos = Vector2(x, DROP_GROUND_Y)
	var drop = DropItem.new()
	drop.drop_type = drop_type
	drop.object_id = "drop_%s" % drop_type
	drop.global_position = pos
	drop.collision_layer = 0
	drop.collision_mask = GlobalDefine.Collision.PLAYER
	add_child(drop)
	_active_drops.append(drop)
	print("[TestArena] 生成掉落物 %s 于 (%.0f, %.0f)" % [drop_type, pos.x, pos.y])

## 每帧轮询掉落物距离（检测玩家是否在拾取范围内）
func _process_drops() -> void:
	var pl = GameManager.player_ref
	if not pl or not is_instance_valid(pl): return
	for drop in _active_drops:
		if is_instance_valid(drop):
			drop.check_player_in_range(pl)

## 尝试拾取附近的掉落物
func _try_pickup_drop() -> void:
	for drop in _active_drops:
		if not is_instance_valid(drop) or drop.completed: continue
		if drop.is_player_in_range:
			drop.on_collected()
			_active_drops.erase(drop)
			return

## 掉落物拾取展示（DropItem.on_collected 通过 level._show_drop_showcase 调用）
func _show_drop_showcase(drop_type: String) -> void:
	var showcase = DropItemShowcase.new()
	add_child(showcase)
	showcase.show_item(drop_type)

## 注册掉落物（DropSystem 调用，TestArena 直接用 _active_drops 无需此方法）
func _register_drop(drop: DropItem) -> void:
	_active_drops.append(drop)

func _exit_tree() -> void:
	EventBus.unsubscribe_all(self)
