# ============================================================
# Player_Warrior.gd - 战士玩家角色
# 继承 PlayerBase，实现视觉层、动画控制、攻击特效、战斗逻辑
# ============================================================
extends PlayerBase
class_name Player_Warrior

var _anim_sprite: AnimatedSprite2D = null
var _last_anim: String = ""
var _anim_map: Dictionary = {}
var _skill_cooldown_timer: float = 0.0  # 技能独立CD，不影响普攻
const SKILL_COOLDOWN := 3.0

# 子类标记：是否有专属 hit / defeated 动画
var _has_hit_anim: bool = false
var _has_defeated_anim: bool = false

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
	# 技能独立CD计时
	if _skill_cooldown_timer > 0:
		_skill_cooldown_timer -= delta
	_update_animation()
	_update_facing_override()
	_update_attack_effect()

# ---- 覆盖：技能独立CD ----
func perform_skill() -> void:
	if _skill_cooldown_timer > 0 or is_attacking or is_dashing:
		return
	_on_skill()

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
	# defeated 动画播完即停（不循环）
	if target_anim == "defeated" and _anim_sprite.is_playing():
		if not _anim_sprite.sprite_frames.get_animation_loop("defeated"):
			if _anim_sprite.frame >= _anim_sprite.sprite_frames.get_frame_count("defeated") - 1:
				_anim_sprite.pause()
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
	if current_state == GlobalDefine.PlayerState.HURT: return
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

	# _spawn_attack_effect()  # 白色方块演示特效已隐藏
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

# 闪电剑气：前方扇形电弧 + 飞行剑气弹体
func _on_skill() -> void:
	super._on_skill()
	var skill_config = load("res://DataConfig/Skill/SlashConfig.tres") as SkillConfig
	if not skill_config:
		return
	is_attacking = true
	has_hit_this_attack = false
	attack_timer = 0.5
	attack_cooldown_timer = 0.0  # 不占用普攻CD
	_skill_cooldown_timer = SKILL_COOLDOWN  # 技能独立CD
	_change_state(GlobalDefine.PlayerState.SKILL)
	
	var facing_dir := 1.0 if is_facing_right else -1.0
	var attack_dir := Vector2(facing_dir, -0.2).normalized()
	
	# 1. 扇形区域判定（120°，半径150px）
	var attack_center = global_position + Vector2(facing_dir * 40, -10)
	for enemy in GameManager.get_enemies():
		if not is_instance_valid(enemy):
			continue
		var to_enemy = enemy.global_position - attack_center
		var dist = to_enemy.length()
		if dist > 150.0:
			continue
		var angle = attack_dir.angle_to(to_enemy.normalized())
		if abs(angle) > deg_to_rad(60):
			continue
		var result = DamageCalculator.calculate(20, 0, GlobalDefine.DamageType.MAGIC, 0.15)
		var kb_dir = to_enemy.normalized() if to_enemy != Vector2.ZERO else Vector2(facing_dir, 0)
		if enemy.has_method("take_damage"):
			enemy.take_damage(result["damage"], kb_dir)
		EventBus.emit(GlobalDefine.EventName.PLAYER_ATTACK_HIT, {"attacker": self, "target": enemy, "damage": result["damage"], "is_crit": result["is_crit"]})
	
	# 2. 生成飞行剑气弹体
	var projectile_script = load("res://Tools/SwordQiProjectile.gd")
	var projectile = Area2D.new()
	projectile.set_script(projectile_script)
	var parent = get_parent()
	if parent:
		parent.add_child(projectile)
		projectile.global_position = global_position + Vector2(facing_dir * 25, -10)
		projectile.setup(Vector2(facing_dir, 0), 25, self, 350.0)
	
	# 3. 扇形电弧视觉
	_spawn_arc_effect(attack_dir, facing_dir)
	
	# 4. 震屏
	var cam = get_node_or_null("SmoothCamera")
	if cam and cam.has_method("shake"):
		cam.shake(6.0, 0.15)

## 生成扇形电弧视觉（Line2D 随机折线）
func _spawn_arc_effect(attack_dir: Vector2, facing_dir: float) -> void:
	var parent = get_parent()
	if not parent:
		return
	# 3道电弧，扇形分布
	for i in range(3):
		var arc_angle = attack_dir.angle() + deg_to_rad(-40 + i * 40) + randf_range(-0.1, 0.1)
		var arc_dir = Vector2.from_angle(arc_angle)
		var line = Line2D.new()
		line.width = 2.0
		line.default_color = Color(0.4, 0.7, 1.0, 0.9)
		line.z_index = 9
		# 随机折线点
		var start = global_position + Vector2(facing_dir * 15, -10)
		var points = [start]
		var pos = start
		var seg_count = 5 + randi_range(0, 3)
		for j in range(seg_count):
			var seg_len = 20.0 + randf() * 15.0
			var jitter = randf_range(-0.3, 0.3)
			pos += arc_dir * seg_len + Vector2(jitter * 20, randf_range(-10, 10))
			points.append(pos)
		for pt in points:
			line.add_point(parent.to_local(pt))
		parent.add_child(line)
		# 淡出动画
		var tween = line.create_tween()
		tween.tween_property(line, "modulate:a", 0.0, 0.3)
		tween.tween_callback(line.queue_free)

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
