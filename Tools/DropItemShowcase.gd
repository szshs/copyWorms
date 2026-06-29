# ============================================================
# DropItemShowcase.gd - 掉落物拾取全屏展示
#
# 效果流程：
#   1. 全屏黑色遮罩淡入（0.3s）
#   2. 掉落物图片从 scale=0 放大到目标尺寸（0.5s，弹性缓动）
#   3. 停留 1.5s 供玩家观看
#   4. 图片淡出 + 遮罩淡出（0.4s）
#   5. 自动清理，恢复游戏
# ============================================================
extends CanvasLayer
class_name DropItemShowcase

const DROP_TEXTURES: Dictionary = {
	"月饼": "res://Assets/Effects/月饼.png",
	"虾饺": "res://Assets/Effects/虾饺.png",
	"木棉": "res://Assets/Effects/木棉.png",
	"醒狮": "res://Assets/Effects/醒狮.png",
	"烧卖": "res://Assets/Effects/广式烧卖.png",
	"蒲葵扇": "res://Assets/Effects/蒲葵扇.png",
}

var _overlay: ColorRect = null
var _item_sprite: Sprite2D = null
var _callback: Callable = Callable()

func _ready() -> void:
	layer = 800
	process_mode = Node.PROCESS_MODE_ALWAYS

## 展示掉落物
func show_item(drop_type: String, callback: Callable = Callable()) -> void:
	_callback = callback
	# 冻结玩家
	var player = GameManager.player_ref
	if player and player.has_method("set_frozen"):
		player.set_frozen(true)
	InputManager.block_input("掉落物展示", self)
	# 全屏遮罩
	_overlay = ColorRect.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.color = Color(0, 0, 0, 0.0)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)
	# 掉落物图片
	var tex_path: String = DROP_TEXTURES.get(drop_type, "")
	if tex_path == "" or not ResourceLoader.exists(tex_path):
		_finish()
		return
	var tex = load(tex_path) as Texture2D
	if not tex:
		_finish()
		return
	# 用 Sprite2D 显示，position 用 viewport 的实际渲染尺寸中心
	_item_sprite = Sprite2D.new()
	_item_sprite.texture = tex
	_item_sprite.centered = true
	# 用 viewport 的实际渲染尺寸居中
	var rect = get_viewport().get_visible_rect()
	_item_sprite.position = rect.position + rect.size / 2.0
	# 计算缩放：目标显示宽度 = 渲染宽度 25%
	var target_w = rect.size.x * 0.25
	var scale_val = target_w / float(tex.get_width())
	_item_sprite.modulate.a = 1.0
	_item_sprite.scale = Vector2.ZERO
	add_child(_item_sprite)
	# 动画序列
	var tw = create_tween()
	# 1. 遮罩淡入
	tw.tween_property(_overlay, "color:a", 0.85, 0.3)
	# 2. 图片放大（弹性）
	tw.tween_property(_item_sprite, "scale", Vector2(scale_val, scale_val), 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# 3. 停留
	tw.tween_interval(1.5)
	# 4. 淡出
	tw.tween_property(_item_sprite, "modulate:a", 0.0, 0.4)
	tw.parallel().tween_property(_overlay, "color:a", 0.0, 0.4)
	# 5. 完成
	tw.tween_callback(_finish)

func _finish() -> void:
	# 解冻玩家
	var player = GameManager.player_ref
	if player and is_instance_valid(player) and player.has_method("set_frozen"):
		player.set_frozen(false)
	InputManager.unblock_input("掉落物展示")
	if _callback.is_valid():
		_callback.call()
	queue_free()
