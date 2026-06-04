# ============================================================
# Player_Warrior.gd - 战士玩家角色
# 继承 PlayerBase，实现战士特有的攻击和技能逻辑
# ============================================================
extends PlayerBase
class_name Player_Warrior

var _anim_sprite: AnimatedSprite2D = null
var _last_anim: String = ""

func _on_ready() -> void:
	super._on_ready()
	if not config:
		config = load("res://DataConfig/Player/WarriorConfig.tres") as PlayerConfig
		_apply_config()
	can_double_jump = true

	# 删除基类创建的占位 ColorRect
	var old = get_node_or_null("PlaceholderSprite")
	if old:
		old.queue_free()

	# 获取编辑器中的 AnimatedSprite2D
	_anim_sprite = get_node_or_null("Sprite")
	if _anim_sprite:
		_sprite_node = _anim_sprite
		# 向下偏移让脚踩到碰撞体底部
		# scale 在编辑器中控制，代码不覆盖
		_anim_sprite.offset = Vector2(0, -1.5)

		# 默认播放 idle
		if _anim_sprite.sprite_frames and _anim_sprite.sprite_frames.has_animation("idle"):
			_anim_sprite.play("idle")

# 重写碰撞体尺寸，匹配放大后的精灵
func _get_collision_size() -> Vector2:
	return Vector2(50, 55)

func _on_physics_process(delta: float) -> void:
	super._on_physics_process(delta)
	_update_animation()
	_update_facing_override()

func _update_animation() -> void:
	if not _anim_sprite or not _anim_sprite.sprite_frames:
		return

	var target_anim = "idle"

	match current_state:
		GlobalDefine.PlayerState.RUN:
			target_anim = "walk" if _anim_sprite.sprite_frames.has_animation("walk") else "idle"
		_:
			target_anim = "idle"

	if target_anim != _last_anim:
		_last_anim = target_anim
		if _anim_sprite.sprite_frames.has_animation(target_anim):
			_anim_sprite.play(target_anim)

	# idle 原始帧 128×128，walk 原始帧 64×64
	# 用代码缩放补偿，让两个动画视觉大小一致
	if target_anim == "walk":
		_anim_sprite.scale = Vector2(2, 2)       # 128px 帧不放大
	else:
		_anim_sprite.scale = Vector2(1, 1)       # 64px 帧放大到 128px

## 覆盖基类的 scale.x 翻转，统一用 flip_h 控制朝向
## 避免 scale.x 和 flip_h 双重翻转导致的频闪
func _update_facing_override() -> void:
	if is_dashing:
		return

	if velocity.x > 10:
		# 向右走
		scale.x = 1
		is_facing_right = true
		if _anim_sprite:
			_anim_sprite.flip_h = false
	elif velocity.x < -10:
		# 向左走
		scale.x = 1  # 不用 scale 翻转！
		is_facing_right = false
		if _anim_sprite:
			_anim_sprite.flip_h = true
	# velocity.x ≈ 0 时保持朝向不变

func _on_attack() -> void:
	super._on_attack()
	if has_hit_this_attack:
		return
	has_hit_this_attack = true

	var facing_dir = 1.0 if is_facing_right else -1.0
	var attack_center = global_position + Vector2(facing_dir * 40, -10)
	var attack_range = config.attack_range if config else 80.0

	for enemy in GameManager.get_enemies():
		if not is_instance_valid(enemy):
			continue
		if attack_center.distance_to(enemy.global_position) <= attack_range:
			var result = DamageCalculator.calculate(
				config.attack_damage if config else 25,
				0,
				GlobalDefine.DamageType.PHYSICAL
			)
			var kb_dir = Vector2(facing_dir, -0.3).normalized()
			if enemy.has_method("take_damage"):
				enemy.take_damage(result["damage"], kb_dir)
			EventBus.emit(GlobalDefine.EventName.PLAYER_ATTACK_HIT, {
				"attacker": self,
				"target": enemy,
				"damage": result["damage"],
				"is_crit": result["is_crit"]
			})
			break

func _on_skill() -> void:
	super._on_skill()
	var skill_config = load("res://DataConfig/Skill/SlashConfig.tres") as SkillConfig
	if not skill_config:
		return

	is_attacking = true
	has_hit_this_attack = false
	attack_timer = 0.4
	attack_cooldown_timer = skill_config.cooldown
	_change_state(GlobalDefine.PlayerState.SKILL)

	var facing_dir = 1.0 if is_facing_right else -1.0
	var attack_center = global_position + Vector2(facing_dir * 40, -10)
	for enemy in GameManager.get_enemies():
		if not is_instance_valid(enemy):
			continue
		if attack_center.distance_to(enemy.global_position) <= skill_config.range_x:
			var result = DamageCalculator.calculate(
				skill_config.damage,
				0,
				skill_config.damage_type,
				0.15
			)
			var kb_dir = Vector2(facing_dir, -0.3).normalized()
			if enemy.has_method("take_damage"):
				enemy.take_damage(result["damage"], kb_dir)
			EventBus.emit(GlobalDefine.EventName.PLAYER_ATTACK_HIT, {
				"attacker": self,
				"target": enemy,
				"damage": result["damage"],
				"is_crit": result["is_crit"]
			})

func _get_placeholder_color() -> Color:
	return Color.TRANSPARENT

func _on_die() -> void:
	super._on_die()
	GameManager.trigger_game_over()
