# ============================================================
# DropItem.gd - 掉落物（继承 InteractiveObject）
#
# 复用交互物碰撞检测与提示系统，新增：
#   1. 多种外观（从 Assets/Effects 加载贴图）
#   2. 初次拾取 → 触发全屏展示动画
#   3. 拾取后消失（allow_repeat=false, 一次性）
# ============================================================
extends InteractiveObject
class_name DropItem

## 掉落物类型（对应 Assets/Effects 中的贴图文件名，不含扩展名）
@export var drop_type: String = "月饼"

var _drop_sprite: Sprite2D = null
var _float_phase: float = 0.0

# 掉落物类型 → 贴图路径映射
const DROP_TEXTURES: Dictionary = {
	"月饼": "res://Assets/Effects/月饼.png",
	"虾饺": "res://Assets/Effects/虾饺.png",
	"木棉": "res://Assets/Effects/木棉.png",
	"醒狮": "res://Assets/Effects/醒狮.png",
	"烧卖": "res://Assets/Effects/广式烧卖.png",
	"蒲葵扇": "res://Assets/Effects/蒲葵扇.png",
}

func _ready() -> void:
	super._ready()
	allow_repeat = false
	prompt_text = "按 Enter 拾取"
	_create_drop_visual()
	_float_phase = randf() * TAU

func _create_drop_visual() -> void:
	var tex_path: String = DROP_TEXTURES.get(drop_type, "")
	if tex_path == "" or not ResourceLoader.exists(tex_path):
		push_warning("[DropItem] 未知掉落物类型或贴图缺失: %s" % drop_type)
		return
	var tex = load(tex_path) as Texture2D
	if not tex: return
	_drop_sprite = Sprite2D.new()
	_drop_sprite.name = "DropSprite"
	_drop_sprite.texture = tex
	# 贴图约2048px，缩放到约64px显示在地图中
	_drop_sprite.scale = Vector2(0.03, 0.03)
	_drop_sprite.z_index = 8
	add_child(_drop_sprite)
	# 碰撞体
	var col = CollisionShape2D.new()
	col.name = "CollisionShape2D"
	var shape = RectangleShape2D.new()
	shape.size = Vector2(40, 40)
	col.shape = shape
	add_child(col)

func _process(delta: float) -> void:
	super._process(delta)
	# 漂浮动画
	_float_phase += delta * 2.0
	if _drop_sprite:
		_drop_sprite.position.y = sin(_float_phase) * 5.0
		# 微微旋转
		_drop_sprite.rotation = sin(_float_phase * 0.7) * 0.1

## 拾取时调用：触发全屏展示，然后移除自身
func on_collected(callback: Callable = Callable()) -> void:
	if completed: return
	mark_completed()
	var newly_owned := LingnanDropArchiveScreen.grant_drop_item_by_name(drop_type)
	# 直接创建全屏展示动画（不依赖关卡方法）
	var showcase = DropItemShowcase.new()
	var parent = get_parent()
	if parent:
		parent.add_child(showcase)
		showcase.show_item(drop_type, callback)
	elif callback.is_valid():
		callback.call()
	if newly_owned:
		print("[DropItem] 新增图鉴收录: %s" % drop_type)
	# 隐藏自身
	if _drop_sprite: _drop_sprite.visible = false
	if _prompt_label: _prompt_label.visible = false
	# 延迟释放（等展示动画启动）
	queue_free()
