# ============================================================
# PixelGlitch.gd - 像素崩坏覆盖层（A1彩色雪花 + B2行偏移）
# 继承 Control，用 _draw() 纯代码绘制，B2采样当前帧。
# 用法：
#   var pg = PixelGlitch.new()
#   canvas.add_child(pg)
#   pg.start_glitch()            # 开始
#   pg.intensity = 0.6           # 0~1，强度越高噪点/偏移/色散越剧烈
#   pg.stop_glitch()             # 停止（淡出）
# 设计参考：CodeRain.gd 的生命周期模式 + erosion_vignette 的强度驱动
# ============================================================
extends Control
class_name PixelGlitch


# ---- 可调参数 ----

## 整体强度 0~1（驱动三类效果的密度和幅度）
@export var intensity: float = 0.0 : set = set_intensity

## 雪花噪点方块尺寸（像素），越小越细腻
@export var noise_block_size: int = 3

## 屏幕上同时存在的噪点方块数量上限
@export var noise_block_count: int = 150

## 行偏移：受影响的行占总行数的比例（0~1）
@export var row_shift_ratio: float = 0.03

## 行偏移最大水平位移（像素），为原始的 1/3
@export var row_shift_max_px: float = 7.0

## 淡入/淡出时长（秒）
@export var fade_duration: float = 0.6

## 噪点颜色池（A1 彩色雪花，黑红紫绿四色）
@export var noise_colors: Array[Color] = [
	Color(0, 0, 0, 0.9),       # 黑
	Color(1, 0.2, 0.3, 0.9),   # 红
	Color(0.6, 0.1, 0.9, 0.9), # 紫
	Color(0.1, 0.9, 0.3, 0.9), # 绿
]


# ---- 内部状态 ----

var _active: bool = false
var _visible_alpha: float = 0.0

# A1 雪花噪点：每帧随机生成的方块列表 {pos, size, color}
var _noise_blocks: Array = []

# B2 行偏移：每帧随机生成的行偏移列表 {y, offset}
var _row_shifts: Array = []

# 画面纹理缓存（B2 行偏移需要采样当前帧）
var _screen_tex: ViewportTexture = null


# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	set_anchors_preset(PRESET_FULL_RECT)
	visible = false
	modulate.a = 0.0
	set_process(false)
	set_process_internal(false)


func _process(delta: float) -> void:
	if not _active:
		return
	# 缓存屏幕纹理引用（B2 行偏移采样用）
	var vp = get_viewport()
	if vp:
		_screen_tex = vp.get_texture()
	# 按强度生成各效果的随机数据
	_generate_noise_blocks()
	_generate_row_shifts()
	queue_redraw()


# ============================================================
# 公开接口
# ============================================================

## 开始崩坏效果（淡入）
func start_glitch() -> void:
	if _active:
		return
	_active = true
	visible = true
	modulate.a = 0.0
	set_process(true)
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, fade_duration)


## 停止崩坏效果（淡出）
func stop_glitch() -> void:
	if not _active:
		return
	_active = false
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, fade_duration)
	tween.tween_callback(func():
		set_process(false)
		visible = false
		_noise_blocks.clear()
		_row_shifts.clear()
		_screen_tex = null
	)


func set_intensity(v: float) -> void:
	intensity = clampf(v, 0.0, 1.0)


# ============================================================
# 数据生成
# ============================================================

## A1: 生成雪花噪点方块
func _generate_noise_blocks() -> void:
	_noise_blocks.clear()
	if intensity <= 0.0 or noise_colors.is_empty():
		return
	var vp_size = get_viewport_rect().size
	if vp_size.x <= 0 or vp_size.y <= 0:
		return
	# 数量随强度缩放
	var count = int(noise_block_count * intensity)
	var bs = noise_block_size
	var cols = noise_colors
	var cols_n = cols.size()
	for i in range(count):
		var px = randf() * vp_size.x
		var py = randf() * vp_size.y
		_noise_blocks.append({
			"pos": Vector2(px, py),
			"size": float(bs + (randi() % 2) * bs),  # 1~2倍方块尺寸，略带变化
			"color": cols[randi() % cols_n],
		})


## B2: 生成行偏移数据
func _generate_row_shifts() -> void:
	_row_shifts.clear()
	if intensity <= 0.0:
		return
	var vp_size = get_viewport_rect().size
	if vp_size.y <= 0:
		return
	# 受影响行数随强度增加
	var total_rows = int(vp_size.y)
	var affected = int(total_rows * row_shift_ratio * intensity)
	if affected <= 0:
		return
	var max_px = row_shift_max_px * intensity
	for i in range(affected):
		var y = randi() % total_rows
		var offset = randf_range(-max_px, max_px)
		_row_shifts.append({"y": y, "offset": offset})


# ============================================================
# 绘制
# ============================================================

func _draw() -> void:
	if not _active or modulate.a <= 0.01:
		return
	# A1: 绘制彩色雪花噪点
	for b in _noise_blocks:
		draw_rect(Rect2(b["pos"], Vector2(b["size"], b["size"])), b["color"], true)

	# B2: 绘制行偏移（采样当前画面行）
	_draw_row_shifts()


## B2 行偏移：从屏幕纹理截取整行，水平偏移重绘
func _draw_row_shifts() -> void:
	if _row_shifts.is_empty() or not _screen_tex:
		return
	var vp_size = get_viewport_rect().size
	# 按行分组（同一 y 合并，减少 draw_texture_rect 调用）
	var y_to_offset: Dictionary = {}
	for rs in _row_shifts:
		y_to_offset[rs["y"]] = rs["offset"]
	for y in y_to_offset:
		var offset: float = y_to_offset[y]
		if absf(offset) < 0.5:
			continue
		# 截取该行（高度1px），在偏移位置重绘
		var src_rect = Rect2(0.0, float(y) / vp_size.y, 1.0, 1.0 / vp_size.y)
		var dst_rect = Rect2(offset, y, vp_size.x, 1.0)
		draw_texture_rect_region(_screen_tex, dst_rect, src_rect)
