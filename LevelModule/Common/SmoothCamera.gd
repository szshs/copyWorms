# ============================================================
# SmoothCamera.gd - 通用平滑跟随摄像机
# 死区 + lerp + lookahead 混合算法
# - 在死区内摄像机静止（避免抖动）
# - 超出死区时按 lerp_speed 插值
# - 按玩家水平运动方向预先偏移（lookahead）
# - 位置 clamp 到 limit_left/right/top/bottom 范围
# 适用于横版卷轴/类超级马里奥/空洞骑士风格的关卡
# ============================================================
extends Camera2D
class_name SmoothCamera

# ---- 跟随参数（可在 Inspector 调） ----

## lerp 插值速度（越大越快）
@export_range(0.1, 20.0, 0.1) var lerp_speed: float = 5.0

## 死区半宽半高（玩家在此范围内摄像机不主动移动）
@export var deadzone_size: Vector2 = Vector2(60.0, 80.0)

## 玩家水平运动时摄像机预判偏移量（像素）
@export_range(0.0, 200.0, 1.0) var lookahead_offset: float = 80.0

## lookahead 平滑插值速度
@export_range(0.1, 10.0, 0.1) var lookahead_lerp: float = 3.0

# ---- 内部状态 ----

var _target: Node2D = null
var _last_target_x: float = 0.0
var _lookahead_x: float = 0.0


func _ready() -> void:
	# 启用 _process
	set_process(true)


## 绑定跟随目标（玩家），并将摄像机立即对齐到目标位置避免开局抖动
func bind_target(node: Node2D) -> void:
	_target = node
	if _target:
		global_position = _target.global_position
		_last_target_x = _target.global_position.x
		_lookahead_x = 0.0


func _process(delta: float) -> void:
	if not _target or not is_instance_valid(_target):
		return

	var target_pos: Vector2 = _target.global_position
	var cam_pos: Vector2 = global_position
	var _cam_offset: Vector2 = target_pos - cam_pos

	# ---- 1) 死区 + lookahead 决策 ----
	var target_with_lookahead: Vector2 = target_pos

	# X 方向：玩家速度估算 + lookahead 平滑插值
	var player_vx: float = target_pos.x - _last_target_x
	if abs(_cam_offset.x) > deadzone_size.x and abs(player_vx) > 0.1:
		var dir: float = sign(player_vx)
		_lookahead_x = lerp(_lookahead_x, dir * lookahead_offset, clamp(lookahead_lerp * delta, 0.0, 1.0))
		target_with_lookahead.x += _lookahead_x
	else:
		# 死区内或玩家静止 → lookahead 衰减
		_lookahead_x = lerp(_lookahead_x, 0.0, clamp(lookahead_lerp * delta, 0.0, 1.0))

	# 死区内：摄像机该轴不主动移动
	if abs(_cam_offset.x) < deadzone_size.x:
		target_with_lookahead.x = cam_pos.x
	if abs(_cam_offset.y) < deadzone_size.y:
		target_with_lookahead.y = cam_pos.y

	# ---- 2) lerp 插值 ----
	var t: float = clamp(lerp_speed * delta, 0.0, 1.0)
	var new_pos: Vector2 = cam_pos.lerp(target_with_lookahead, t)

	# ---- 3) clamp 到 limit 边界 ----
	var vp_size: Vector2 = get_viewport_rect().size
	if limit_left < limit_right:
		new_pos.x = clamp(new_pos.x, limit_left + vp_size.x * 0.5, limit_right - vp_size.x * 0.5)
	if limit_top < limit_bottom:
		new_pos.y = clamp(new_pos.y, limit_top + vp_size.y * 0.5, limit_bottom - vp_size.y * 0.5)

	global_position = new_pos
	_last_target_x = target_pos.x
