# ============================================================
# SmoothCamera.gd - 通用平滑跟随摄像机（v2.0）
# 算法: Y轴死区 + X轴软死区(lookahead) + lerp插值 + 转向清零防颤
#
# 架构设计:
#   - 本脚本作为 Camera2D 子节点预置于 Player_Warrior/Cyber/Lingnan 预制体中
#   - _ready() 自动绑定目标(owner → GameManager.player_ref), 无需外部调用
#   - set_as_top_level(true) 脱离父节点 transform 干扰
#   - _physics_process 与 CharacterBody2D 物理帧同步, 避免渲染/物理错位
#
# 核心算法 (3道防线):
#   1. 转向清零(第104-110行): player_vx反向时立即归零_lookahead_x,
#      消除残留值与新方向对抗导致的单帧错跟
#   2. lookahead只由速度控制(第112-120行): 删除abs(offset)>deadzone硬边界,
#      避免 offset 反复穿越边界导致 lookahead 开关振荡
#   3. Y轴保留硬死区(第122-124行): 垂直方向无 lookahead, 需要硬死区防抖
#
# 适用: 横版卷轴/类超级马里奥/空洞骑士风格的关卡
# 路径: res://PlayerModule/Formal/SmoothCamera.gd (从 LevelModule/Common 迁移)
# ============================================================
extends Camera2D
class_name SmoothCamera

# ---- 跟随参数（可在 Inspector 调） ----

## lerp 插值速度（越大越快）
@export_range(0.1, 20.0, 0.1) var lerp_speed: float = 5.0

## 死区半宽半高（玩家在此范围内摄像机不主动移动）
## 注意：X 死区不宜过大，否则配合 move_toward 渐近移动会导致相机"永远不跟随"
@export var deadzone_size: Vector2 = Vector2(10.0, 40.0)

## 玩家水平运动时摄像机预判偏移量（像素）
@export_range(0.0, 200.0, 1.0) var lookahead_offset: float = 80.0

## lookahead 平滑插值速度
@export_range(0.1, 10.0, 0.1) var lookahead_lerp: float = 3.0

# ---- 内部状态 ----

var _target: Node2D = null
var _last_target_x: float = 0.0
var _lookahead_x: float = 0.0

# ---- 震屏 ----
var _shake_strength: float = 0.0
var _shake_decay: float = 10.0


func _ready() -> void:
	# 设为 top_level：脱离父节点 transform 干扰，让 global_position 真正表示世界坐标
	# (否则作为 Player 子节点，camera 会被父节点 transform 拖着走，与 _physics_process 写 world pos 冲突)
	set_as_top_level(true)
	# 禁用 Camera2D 自身的平滑（避免与本脚本的 lerp 双重插值导致抖动）
	position_smoothing_enabled = false
	# 使用 DRAG_CENTER（默认值 0）：相机随节点移动但 position_smoothing 控制平滑
	# 这与下方 clamp 公式配合正确。之前用 FIXED_TOP_LEFT(1) 会导致画面偏移半屏
	if anchor_mode != Camera2D.ANCHOR_MODE_DRAG_CENTER:
		anchor_mode = Camera2D.ANCHOR_MODE_DRAG_CENTER
	# 强制 make_current：确保本相机为主相机
	make_current()
	# 用 _physics_process 与玩家 CharacterBody2D 同步（避免渲染帧/物理帧错位导致左右颤动）
	set_process(false)
	set_physics_process(true)

	# 自动检测跟随目标：优先使用 owner（场景树父节点）， fallback 到 GameManager
	_auto_bind_target()

	# 安全默认值：防止 level_config 缺失或 _setup_camera_limits() 未执行时
	# limit_right=-1 导致 _physics_process 中 clamp 逻辑短路（limit_left < limit_right 为 false）
	if limit_right < 0:
		limit_right = 10000
	if limit_bottom < 0:
		limit_bottom = 10000
	if limit_top > limit_bottom:
		limit_top = -10000


## 自动绑定跟随目标，不依赖外部调用 bind_target
## 查找顺序: owner(实例化时的父节点) → GameManager.player_ref
## 触发震屏
## strength: 初始偏移像素, duration: 持续时间(秒)
func shake(strength: float = 6.0, duration: float = 0.2) -> void:
	_shake_strength = strength
	_shake_decay = strength / maxf(duration, 0.01)


func _auto_bind_target() -> void:
	var candidate: Node2D = null
	# 1) owner 是最可靠的：SmoothCamera 作为 Player_Warrior 子节点预制时，
	#    实例化后 owner 指向 Player_Warrior 实例
	if owner and owner is Node2D:
		candidate = owner as Node2D
	# 2) Fallback: 通过 GameManager 获取
	elif GameManager.player_ref and is_instance_valid(GameManager.player_ref):
		candidate = GameManager.player_ref
	if candidate:
		bind_target(candidate)
	else:
		push_warning("[SmoothCamera] 无法自动找到跟随目标，等待手动 bind_target()")


## 绑定跟随目标（玩家），并将摄像机立即对齐到目标位置避免开局抖动
func bind_target(node: Node2D) -> void:
	_target = node
	if _target:
		global_position = _target.global_position
		_last_target_x = _target.global_position.x
		_lookahead_x = 0.0


func _physics_process(delta: float) -> void:
	if not _target or not is_instance_valid(_target):
		return

	var target_pos: Vector2 = _target.global_position
	var cam_pos: Vector2 = global_position
	var _cam_offset: Vector2 = target_pos - cam_pos

	# ---- 1) 死区 + lookahead 决策 ----
	var target_with_lookahead: Vector2 = target_pos

	# X 方向：玩家速度估算 + lookahead 平滑插值
	var player_vx: float = target_pos.x - _last_target_x

	# 转向检测：玩家移动方向与残留 lookahead 方向相反时，立即清零 lookahead
	# 根除反向移动时残留 lookahead 与新方向对抗导致的颤动
	if abs(player_vx) > 0.1 and abs(_lookahead_x) > 1.0:
		var current_dir: float = sign(player_vx)
		var lookahead_dir: float = sign(_lookahead_x)
		if current_dir != lookahead_dir:
			_lookahead_x = 0.0

	# lookahead 始终根据玩家速度计算（不受 offset 死区控制）
	# 避免 abs(offset)>deadzone 边界反复穿越导致 lookahead 开关振荡
	if abs(player_vx) > 0.1:
		var dir: float = sign(player_vx)
		_lookahead_x = lerp(_lookahead_x, dir * lookahead_offset, clamp(lookahead_lerp * delta, 0.0, 1.0))
		target_with_lookahead.x += _lookahead_x
	else:
		# 死区内或玩家静止 → lookahead 衰减
		_lookahead_x = lerp(_lookahead_x, 0.0, clamp(lookahead_lerp * delta, 0.0, 1.0))

	# Y 轴死区：垂直方向不需要 lookahead，保留死区避免上下微抖
	if abs(_cam_offset.y) < deadzone_size.y:
		target_with_lookahead.y = cam_pos.y
	# X 轴不设死区：lookahead 本身提供软死区效果
	# (player_vx≈0 时 lookahead 自动衰减为 0, 相机纯 lerp 慢跟)
	# 硬死区会导致玩家反向穿越死区边界时产生"锁止→猛跳→锁止"振荡

	# ---- 2) lerp 插值 ----
	var t: float = clamp(lerp_speed * delta, 0.0, 1.0)
	var new_pos: Vector2 = cam_pos.lerp(target_with_lookahead, t)

	# ---- 3) clamp 到 limit 边界 ----
	# FIXED_CENTER 模式：position = 视口中心的世界坐标
	# limit 值表示视口边缘可达的世界坐标极限
	var vp_size: Vector2 = get_viewport_rect().size
	if limit_left < limit_right:
		new_pos.x = clamp(new_pos.x, limit_left + vp_size.x * 0.5, limit_right - vp_size.x * 0.5)
	if limit_top < limit_bottom:
		new_pos.y = clamp(new_pos.y, limit_top + vp_size.y * 0.5, limit_bottom - vp_size.y * 0.5)

	global_position = new_pos

	# ---- 4) 震屏偏移 ----
	if _shake_strength > 0.1:
		global_position += Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake_strength
		_shake_strength = maxf(_shake_strength - _shake_decay * delta, 0.0)

	_last_target_x = target_pos.x
