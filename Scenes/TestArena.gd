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

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_0:
				_panel_visible = not _panel_visible
				if _test_panel:
					_test_panel.get_node_or_null("Panel").visible = _panel_visible
				get_viewport().set_input_as_handled()
			KEY_G:
				_toggle_skin()
				get_viewport().set_input_as_handled()
			KEY_ESCAPE:
				SceneTransitionManager.request_scene_change("res://UI/TitleScreen.tscn", self)

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
	panel.size = Vector2(280, 60 + _enemy_names.size() * 50)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.08, 0.92)
	style.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_test_panel.add_child(panel)
	var title = Label.new()
	title.text = "怪物切换 (按0开关)"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
	title.position = Vector2(10, 10)
	title.size = Vector2(260, 30)
	panel.add_child(title)
	for i in _enemy_names.size():
		var btn = Button.new()
		btn.text = _enemy_names[i]
		btn.position = Vector2(10, 50 + i * 50)
		btn.size = Vector2(260, 40)
		btn.add_theme_font_size_override("font_size", 20)
		btn.focus_mode = Control.FOCUS_NONE
		var idx = i
		btn.pressed.connect(func(): _spawn_enemy(idx))
		panel.add_child(btn)
	panel.visible = false

func _exit_tree() -> void:
	EventBus.unsubscribe_all(self)
