# ============================================================
# Ladder.gd - 梯子
# ============================================================
extends Area2D
class_name Ladder

@export var ladder_top_y: float = -344.0     # 顶端 Y（小值=上方）
@export var ladder_bottom_y: float = 15.0    # 底端 Y（大值=下方）
@export var climb_speed: float = 250.0
@export var ladder_width: float = 40.0
@export var ladder_vertical_pad: float = 30.0

var _player: CharacterBody2D = null
var _climbing: bool = false
var _last_climb_dir: float = 0.0

var _label_w: Label = null
var _label_s: Label = null


func _ready() -> void:
	collision_layer = 0
	collision_mask = GlobalDefine.Collision.PLAYER
	monitoring = true
	monitorable = false

	var h = abs(ladder_top_y - ladder_bottom_y)
	var col = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = Vector2(ladder_width, h + ladder_vertical_pad * 2)
	col.shape = rect
	add_child(col)

	var vis = ColorRect.new()
	vis.color = Color(1.0, 0.95, 0.6, 0.35)  # 很淡的黄色
	vis.size = Vector2(ladder_width, h)
	vis.position = Vector2(-ladder_width / 2.0, -h / 2.0)
	vis.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vis)

	_label_w = Label.new()
	_label_w.text = "W 上"
	_label_w.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label_w.add_theme_font_size_override("font_size", 20)
	_label_w.add_theme_color_override("font_color", Color(0, 1, 0.3))
	_label_w.size = Vector2(60, 20)
	_label_w.position = Vector2(-30, ladder_bottom_y - global_position.y + 5)
	_label_w.visible = false
	add_child(_label_w)

	_label_s = Label.new()
	_label_s.text = "S 下"
	_label_s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label_s.add_theme_font_size_override("font_size", 20)
	_label_s.add_theme_color_override("font_color", Color(0, 1, 0.3))
	_label_s.size = Vector2(60, 20)
	_label_s.position = Vector2(-30, ladder_top_y - global_position.y - 25)
	_label_s.visible = false
	add_child(_label_s)

	body_entered.connect(_on_enter)
	body_exited.connect(_on_exit)
	set_process(true)


func _on_enter(body: Node2D) -> void:
	if _climbing: return
	if not body is CharacterBody2D: return
	if not (body.collision_layer & GlobalDefine.Collision.PLAYER): return
	print("[Ladder] player entered")
	_player = body

func _on_exit(body: Node2D) -> void:
	if body != _player: return
	print("[Ladder] player exited (climbing=%s)" % _climbing)
	if _climbing:
		_finish_climb(false)
	_player = null
	_label_w.visible = false
	_label_s.visible = false


func _process(delta: float) -> void:
	if _climbing:
		_climb_tick(delta)
		return
	if not _player or not is_instance_valid(_player):
		return

	var py = _player.global_position.y
	_label_w.visible = py > ladder_top_y
	_label_s.visible = py < ladder_bottom_y

	# 双向：在梯子宽度区域内任意高度，W 向上，S 向下。
	if _label_w.visible and Input.is_action_just_pressed("player_up"):
		print("[Ladder] W pressed, climbing UP")
		_start_climb(-1)
	elif _label_s.visible and Input.is_action_just_pressed("player_down"):
		print("[Ladder] S pressed, climbing DOWN")
		_start_climb(1)


func _start_climb(dir: float) -> void:
	_climbing = true
	_last_climb_dir = dir
	_label_w.visible = false
	_label_s.visible = false
	if dir > 0.0 and _player.global_position.y < ladder_top_y:
		_player.global_position.y = ladder_top_y
	elif dir < 0.0 and _player.global_position.y > ladder_bottom_y:
		_player.global_position.y = ladder_bottom_y
	if _player.has_method("begin_ladder_climb"):
		_player.call("begin_ladder_climb")
	else:
		_player.set_physics_process(false)
	print("[Ladder] climb start at y=%.1f, dir=%.0f" % [_player.global_position.y, dir])


func _climb_tick(delta: float) -> void:
	if not _player or not is_instance_valid(_player):
		_finish_climb(false); return

	if Input.is_action_just_pressed("player_jump"):
		print("[Ladder] climb cancelled by jump")
		_finish_climb(false)
		return

	var input_dir := 0.0
	if Input.is_action_pressed("player_up") and _player.global_position.y > ladder_top_y:
		input_dir -= 1.0
	if Input.is_action_pressed("player_down") and _player.global_position.y < ladder_bottom_y:
		input_dir += 1.0
	if input_dir != 0.0:
		_last_climb_dir = input_dir
		_player.global_position.y = clampf(
			_player.global_position.y + input_dir * climb_speed * delta,
			ladder_top_y,
			ladder_bottom_y
		)

	if _last_climb_dir < 0.0 and _player.global_position.y <= ladder_top_y:
		print("[Ladder] climb complete at top y=%.1f" % _player.global_position.y)
		_last_climb_dir = -1.0
		_finish_climb(true)
	elif _last_climb_dir > 0.0 and _player.global_position.y >= ladder_bottom_y:
		print("[Ladder] climb complete at bottom y=%.1f" % _player.global_position.y)
		_last_climb_dir = 1.0
		_finish_climb(true)


func _finish_climb(snap_to_endpoint: bool = true) -> void:
	var landing_dir = _last_climb_dir
	_climbing = false
	_last_climb_dir = 0.0
	if _player and is_instance_valid(_player):
		if snap_to_endpoint and landing_dir > 0:  # 向下爬完，落在底端平台上方
			_player.global_position.y = ladder_bottom_y - 15.0
		elif snap_to_endpoint and landing_dir < 0:  # 向上爬完，落在顶端平台上方
			_player.global_position.y = ladder_top_y - 15.0
		if _player.has_method("end_ladder_climb"):
			_player.call("end_ladder_climb")
		else:
			_player.set_physics_process(true)
			_player.velocity = Vector2.ZERO
	print("[Ladder] climb finished, player at y=%.1f" % _player.global_position.y if _player and is_instance_valid(_player) else -999.0)
