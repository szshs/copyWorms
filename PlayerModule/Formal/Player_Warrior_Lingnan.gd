# ============================================================
# Player_Warrior_Lingnan.gd - 岭南风皮肤
# 继承 Player_Warrior，覆盖动画映射字典
# 由于 .tscn 中 Sprite 缺少 SpriteFrames，
# 在 _on_ready 中从 Player_Warrior.tscn 复制帧数据
# ============================================================
extends Player_Warrior
class_name Player_Warrior_Lingnan

func _on_ready():
	# 在调用 super._on_ready() 之前，先给 Sprite 补上 SpriteFrames
	# 这样 super 中的 get_node_or_null("Sprite") 分支能正确走通
	_ensure_sprite_frames()
	super._on_ready()
	_anim_map = {
		GlobalDefine.PlayerState.IDLE:    "idle",
		GlobalDefine.PlayerState.RUN:     "walk",
		GlobalDefine.PlayerState.JUMP:    "jump",
		GlobalDefine.PlayerState.FALL:    "jump",
		GlobalDefine.PlayerState.DASH:    "idle",
		GlobalDefine.PlayerState.ATTACK:  "attack",
		GlobalDefine.PlayerState.SKILL:   "idle",
		GlobalDefine.PlayerState.HURT:    "idle",
		GlobalDefine.PlayerState.DEAD:    "idle",
	}

## 从 Player_Warrior.tscn 获取 SpriteFrames 并赋给当前 Sprite 节点
func _ensure_sprite_frames() -> void:
	var sprite = get_node_or_null("Sprite") as AnimatedSprite2D
	if not sprite:
		return
	if sprite.sprite_frames and sprite.sprite_frames.has_animation("idle"):
		return  # 已有帧数据，无需补充

	var warrior_path = "res://PlayerModule/Formal/Player_Warrior.tscn"
	if not ResourceLoader.exists(warrior_path):
		push_warning("[Player_Warrior_Lingnan] Player_Warrior.tscn 不存在，无法获取 SpriteFrames")
		return

	# 临时实例化 Player_Warrior 来获取其 SpriteFrames
	var warrior_scene = load(warrior_path) as PackedScene
	if not warrior_scene:
		return
	var temp_warrior = warrior_scene.instantiate()
	var temp_sprite = temp_warrior.get_node_or_null("Sprite") as AnimatedSprite2D
	if temp_sprite and temp_sprite.sprite_frames:
		# 复制 SpriteFrames 资源（避免共享引用导致状态干扰）
		sprite.sprite_frames = temp_sprite.sprite_frames.duplicate()
	temp_warrior.free()
