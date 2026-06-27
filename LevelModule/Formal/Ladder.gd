# ============================================================
# Ladder.gd - 梯子
# ============================================================
extends Area2D
class_name Ladder

@export var ladder_top_y: float = -344.0     # 顶端 Y（小值=上方）
@export var ladder_bottom_y: float = 15.0    # 底端 Y（大值=下方）
@export var climb_speed: float = 250.0

var _player: CharacterBody2D = null
var _climbing: bool = false
var _climb_start_y: float = 0.0
var _climb_target: float = 0.0
var _climb_dir_sign: float = 0.0
var _climb_progress: float = 0.0

var _label_w: Label = null
var _label_s: Label = null


func _ready() -> void:
	collision_layer = 0
	collision_mask = GlobalDefine.Collision.PLAYER
	monitoring = true
	monitorable = false

	var h = abs(ladder_top_y - ladder_bottom_y)
	const PAD := 30.0
	var col = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = Vector2(40, h + PAD * 2)
	col.shape = rect
	add_child(col)

	var vis = ColorRect.new()
	vis.color = Color(1.0, 0.95, 0.6, 0.35)  # 很淡的黄色
	vis.size = Vector2(40, h)
	vis.position = Vector2(-20, -h / 2.0)
	vis.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vis)

	_label_w = Label.new()
	_label_w.text = "W ↑"
	_label_w.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label_w.add_theme_font_size_override("font_size", 20)
	_label_w.add_theme_color_override("font_color", Color(0, 1, 0.3))
	_label_w.size = Vector2(60, 20)
	_label_w.position = Vector2(-30, ladder_bottom_y - global_position.y + 5)
	_label_w.visible = false
	add_child(_label_w)

	_label_s = Label.new()
	_label_s.text = "S ↓"
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
		_finish_climb()
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
	_label_w.visible = abs(py - ladder_bottom_y) < 60.0
	_label_s.visible = abs(py - ladder_top_y) < 60.0

	# 双向：底部按W向上，顶部按S向下
	if _label_w.visible and Input.is_action_just_pressed("player_up"):
		print("[Ladder] W pressed at bottom, climbing UP")
		_start_climb(ladder_bottom_y, ladder_top_y, -1)
	elif _label_s.visible and Input.is_action_just_pressed("player_down"):
		print("[Ladder] S pressed at top (py=%.1f, top=%.1f), climbing DOWN" % [py, ladder_top_y])
		_start_climb(ladder_top_y, ladder_bottom_y, 1)


func _start_climb(from_y: float, to_y: float, dir: float) -> void:
	_climbing = true
	_climb_start_y = from_y
	_climb_target = to_y
	_climb_dir_sign = dir
	_climb_progress = 0.0
	_label_w.visible = false
	_label_s.visible = false
	_player.set_physics_process(false)
	print("[Ladder] climb start: %.1f → %.1f, dir=%d" % [from_y, to_y, dir])


func _climb_tick(delta: float) -> void:
	if not _player or not is_instance_valid(_player):
		_finish_climb(); return

	var dist = abs(_climb_target - _climb_start_y)
	var step = climb_speed * delta
	_climb_progress += step / dist if dist > 0 else 1.0

	var y: float
	if _climb_progress >= 1.0:
		y = _climb_target
	else:
		y = _climb_start_y + _climb_dir_sign * _climb_progress * dist

	_player.global_position.y = y

	if _climb_progress >= 1.0:
		print("[Ladder] climb complete at y=%.1f" % y)
		_finish_climb()
	elif Input.is_action_just_pressed("player_jump"):
		print("[Ladder] climb cancelled by jump")
		_finish_climb()


func _finish_climb() -> void:
	var landing_dir = _climb_dir_sign
	_climbing = false
	_climb_dir_sign = 0.0
	if _player and is_instance_valid(_player):
		if landing_dir > 0:  # 向下爬完，落在底端平台上方
			_player.global_position.y = ladder_bottom_y - 15.0
		elif landing_dir < 0:  # 向上爬完，落在顶端平台上方
			_player.global_position.y = ladder_top_y - 15.0
		_player.set_physics_process(true)
		_player.velocity = Vector2.ZERO
	print("[Ladder] climb finished, player at y=%.1f" % _player.global_position.y if _player and is_instance_valid(_player) else -999.0)
