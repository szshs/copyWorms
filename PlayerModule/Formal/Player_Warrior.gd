# ============================================================
# Player_Warrior.gd - 战士玩家角色
# 继承 PlayerBase，实现视觉层、动画控制、攻击特效、战斗逻辑
# ============================================================
extends PlayerBase
class_name Player_Warrior

var _anim_sprite: AnimatedSprite2D = null
var _last_anim: String = ""
var _anim_map: Dictionary = {}

# 攻击特效（战士特有）
var _attack_effect_node: ColorRect = null

func _on_ready() -> void:
	super._on_ready()
	if not config:
		config = load("res://DataConfig/Player/WarriorConfig.tres") as PlayerConfig
		_apply_config()
	can_double_jump = true
	# 订阅命中事件，生成刀光特效
	EventBus.subscribe(GlobalDefine.EventName.PLAYER_ATTACK_HIT, self, "_on_player_attack_hit")

	# 创建占位视觉（后续子类替换为 AnimatedSprite2D）
	var sprite = ColorRect.new()
	sprite.name = "PlaceholderSprite"
	sprite.color = _get_placeholder_color()
	sprite.size = _get_placeholder_size()
	sprite.position = -sprite.size / 2
	sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sprite)
	_sprite_node = sprite

	_anim_sprite = get_node_or_null("Sprite")
	if _anim_sprite:
		var old = get_node_or_null("PlaceholderSprite")
		if old: old.queue_free()
		_sprite_node = _anim_sprite
		_anim_sprite.offset = Vector2(0, -10)
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
		if _anim_sprite.sprite_frames and _anim_sprite.sprite_frames.has_animation("idle"):
			_anim_sprite.play("idle")

func _get_collision_size() -> Vector2:
	return Vector2(50, 60)

func _get_placeholder_color() -> Color:
	return Color.TRANSPARENT

func _get_placeholder_size() -> Vector2:
	return Vector2(48, 64)

func _on_physics_process(delta: float) -> void:
	super._on_physics_process(delta)
	_update_animation()
	_update_facing_override()
	_update_attack_effect()

# ---- 动画控制 ----

func _update_animation() -> void:
	if not _anim_sprite or not _anim_sprite.sprite_frames: return
	var target_anim = _get_anim_for_state()
	if target_anim != _last_anim:
		_last_anim = target_anim
		if _anim_sprite.sprite_frames.has_animation(target_anim):
			if target_anim == "attack_in_air":
				_anim_sprite.sprite_frames.set_animation_speed("attack_in_air", 18.0)
			_anim_sprite.play(target_anim)
			_anim_sprite.frame = 0
	# jump/fall 帧锁定只在播放 jump 动画时生效，不覆盖攻击等动画
	if _anim_sprite.animation == "jump" and current_state == GlobalDefine.PlayerState.FALL:
		if velocity.y < 400:
			_anim_sprite.frame = 4
			_anim_sprite.pause()
		else:
			_anim_sprite.play("jump")

func _get_anim_for_state() -> String:
	var anim = _anim_map.get(current_state, "idle")
	# 空中攻击时使用独立动画（基于攻击发起时的状态）
	if current_state == GlobalDefine.PlayerState.ATTACK and _attack_started_in_air:
		if _anim_sprite.sprite_frames.has_animation("attack_in_air"):
			return "attack_in_air"
	return anim if _anim_sprite.sprite_frames.has_animation(anim) else "idle"

# ---- 朝向 ----

func _update_facing_override() -> void:
	if is_dashing: return
	if velocity.x > 10:
		scale.x = 1; is_facing_right = true
		if _anim_sprite: _anim_sprite.flip_h = false
	elif velocity.x < -10:
		scale.x = 1; is_facing_right = false
		if _anim_sprite: _anim_sprite.flip_h = true

# ---- 攻击 ----

func _on_attack() -> void:
	super._on_attack()
	if has_hit_this_attack:
		return
	has_hit_this_attack = true

	_spawn_attack_effect()
	var attack_dir := _get_attack_direction()
	var attack_center = global_position + attack_dir * 40
	var attack_range = config.attack_range if config else 80.0

	for enemy in GameManager.get_enemies():
		if not is_instance_valid(enemy):
			continue
		if attack_center.distance_to(enemy.global_position) <= attack_range:
			var result = DamageCalculator.calculate(config.attack_damage if config else 25, 0, GlobalDefine.DamageType.PHYSICAL)
			var kb_dir = attack_dir.normalized() if attack_dir != Vector2.ZERO else Vector2(1, 0)
			if enemy.has_method("take_damage"):
				enemy.take_damage(result["damage"], kb_dir)
			EventBus.emit(GlobalDefine.EventName.PLAYER_ATTACK_HIT, {"attacker": self, "target": enemy, "damage": result["damage"], "is_crit": result["is_crit"]})
			break

func _spawn_attack_effect() -> void:
	var parent = get_parent()
	if not parent:
		return
	if _attack_effect_node and is_instance_valid(_attack_effect_node):
		_attack_effect_node.queue_free()
	_attack_effect_node = ColorRect.new()
	_attack_effect_node.name = "AttackEffect"
	_attack_effect_node.size = Vector2(55, 10)
	_attack_effect_node.color = Color(1, 1, 1, 0.9)
	_attack_effect_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var facing = 1.0 if is_facing_right else -1.0
	_attack_effect_node.position = global_position + Vector2(facing * 35, -15)
	parent.add_child(_attack_effect_node)

func _update_attack_effect() -> void:
	if not _attack_effect_node or not is_instance_valid(_attack_effect_node):
		return
	if _attack_effect_node.color.a <= 0:
		_attack_effect_node.queue_free()
		_attack_effect_node = null
		return
	_attack_effect_node.color.a -= 0.07
	if _attack_effect_node.color.a < 0:
		_attack_effect_node.color.a = 0

func _get_attack_direction() -> Vector2:
	if is_on_floor(): return Vector2(1.0 if is_facing_right else -1.0, -0.2)
	var id = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if abs(id.x) > 0.1 or abs(id.y) > 0.1: return Vector2(id.x, id.y).normalized()
	return Vector2(1.0 if is_facing_right else -1.0, 0.0)

# ---- 技能 ----

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
			var result = DamageCalculator.calculate(skill_config.damage, 0, skill_config.damage_type, 0.15)
			if enemy.has_method("take_damage"):
				enemy.take_damage(result["damage"], Vector2(facing_dir, -0.3).normalized())
			EventBus.emit(GlobalDefine.EventName.PLAYER_ATTACK_HIT, {"attacker": self, "target": enemy, "damage": result["damage"], "is_crit": result["is_crit"]})

func _on_die() -> void:
	super._on_die()
	GameManager.trigger_game_over()

# ---- 刀光特效 ----

func _on_player_attack_hit(data: Dictionary) -> void:
	var target = data.get("target", null)
	if not target or not is_instance_valid(target):
		return
	_spawn_slash_effect(target, data.get("is_crit", false))

func _spawn_slash_effect(target: Node2D, is_crit: bool = false) -> void:
	var parent = get_parent()
	if not parent:
		return
	# 攻击方向: 玩家 → 敌人
	var attack_dir = (target.global_position - global_position).normalized()
	if attack_dir == Vector2.ZERO:
		attack_dir = Vector2(1.0 if is_facing_right else -1.0, 0.0)
	var fx := Sprite2D.new()
	fx.set_script(load("res://Tools/SlashEffect.gd"))
	fx.global_position = target.global_position + Vector2(0, -8)  # 稍偏上，命中中心
	fx.rotation = attack_dir.angle() + randf_range(-0.15, 0.15)
	if is_crit:
		fx.set_meta("size_multiplier", 1.5)
	parent.add_child(fx)
	# 震屏
	var cam = get_node_or_null("SmoothCamera")
	if cam and cam.has_method("shake"):
		cam.shake(8.0 if is_crit else 4.0, 0.15)
