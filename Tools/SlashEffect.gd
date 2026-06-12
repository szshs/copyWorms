# ============================================================
# SlashEffect.gd - 刀光命中特效
# 命中敌人时在敌人位置生成刀光，自动动画后销毁
#
# 动效设计:
#   1. 白色过曝闪光 → 快速弹出 → 回弹 → 淡出
#   2. 沿攻击方向滑行，产生动势
#   3. 暴击时放大 1.5 倍
#
# 生成方式:
#   var fx := Sprite2D.new()
#   fx.set_script(load("res://Tools/SlashEffect.gd"))
#   fx.global_position = ...
#   fx.rotation = attack_dir.angle()
#   fx.set_meta("size_multiplier", 1.5)  # 可选，暴击放大
#   parent.add_child(fx)
# ============================================================
extends Sprite2D

var _elapsed: float = 0.0
var _move_dir: Vector2 = Vector2.RIGHT
var _size_mult: float = 1.0

const DURATION := 0.35
const MOVE_SPEED := 120.0
const TEX_PATH := "res://Assets/Effects/刀光.png"
# 1134px 图片 → 屏幕上约 90px，适配 ~40px 体型的敌人
const BASE_SCALE := 0.08

func _ready() -> void:
	texture = load(TEX_PATH)
	z_index = 10
	# 读取外部传入的尺寸倍率（暴击放大等）
	if has_meta("size_multiplier"):
		_size_mult = get_meta("size_multiplier")
		remove_meta("size_multiplier")
	scale = Vector2(0.3 * BASE_SCALE * _size_mult, 0.3 * BASE_SCALE * _size_mult)
	modulate = Color(3, 3, 3, 1)  # 白色过曝闪光
	_move_dir = Vector2.RIGHT.rotated(rotation)
	centered = true

func _process(delta: float) -> void:
	_elapsed += delta
	var t := clampf(_elapsed / DURATION, 0.0, 1.0)

	# 沿攻击方向滑行，速度递减，产生动势
	position += _move_dir * MOVE_SPEED * delta * maxf(1.0 - t * 1.5, 0.0)

	# 缩放: 0.3 → 1.4 (快速弹出) → 1.0 (回弹)，均基于 BASE_SCALE
	var s: float
	if t < 0.08:
		s = lerpf(0.3, 1.4, t / 0.08)
	else:
		s = lerpf(1.4, 1.0, (t - 0.08) / 0.92)
	scale = Vector2(s * BASE_SCALE * _size_mult, s * BASE_SCALE * _size_mult)

	# 颜色: 白闪 → 原色 → 淡出
	if t < 0.05:
		var ft := t / 0.05
		modulate = Color(lerpf(3.0, 1.0, ft), lerpf(3.0, 1.0, ft), lerpf(3.0, 1.0, ft), 1.0)
	elif t < 0.2:
		modulate = Color(1, 1, 1, 1.0)
	else:
		var ft := (t - 0.2) / 0.8
		modulate = Color(1, 1, 1, lerpf(1.0, 0.0, ft * ft))  # ease-in 淡出

	if t >= 1.0:
		queue_free()
