extends Player_Warrior
class_name Player_Warrior_Cyber

var _hit_pending: bool = false

# ---- 闪电突进技能 ----
var _is_charging: bool = false
var _charge_time: float = 0.0
const CYBER_SKILL_CD := 4.0        # 赛博技能CD
const CHARGE_THRESHOLD := 0.15     # 最短蓄力时间才算长按
const MAX_CHARGE_TIME := 1.0       # 最大蓄力时间
var _is_lightning_dash: bool = false
var _dash_timer: float = 0.0
var _dash_dir: float = 1.0
var _dash_speed: float = 1200.0
var _dash_duration: float = 0.25
var _dash_start_pos: Vector2 = Vector2.ZERO
var _dash_hit_enemies: Array = []
var _lightning_cooldown: float = 0.0
var _was_invincible: bool = false

func _on_ready():
	super._on_ready()
	_anim_map = {
		GlobalDefine.PlayerState.IDLE:   "idle",
		GlobalDefine.PlayerState.RUN:    "walk",
		GlobalDefine.PlayerState.JUMP:   "jump",
		GlobalDefine.PlayerState.FALL:   "jump",
		GlobalDefine.PlayerState.DASH:   "idle",
		GlobalDefine.PlayerState.ATTACK: "attack",
		GlobalDefine.PlayerState.SKILL:  "attack",
		GlobalDefine.PlayerState.HURT:   "hit",
		GlobalDefine.PlayerState.DEAD:   "defeated",
	}
	_has_hit_anim = true
	_has_defeated_anim = true

func _on_attack() -> void:
	_hit_pending = true
	get_tree().create_timer(0.1).timeout.connect(_do_delayed_hit)

func _do_delayed_hit() -> void:
	if not _hit_pending:
		return
	_hit_pending = false
	if not is_attacking or has_hit_this_attack:
		return
	has_hit_this_attack = true

	var attack_dir := _get_attack_direction()
	var attack_center = global_position + attack_dir * 40
	var attack_range = config.attack_range if config else 80.0

	for enemy in GameManager.get_enemies():
		if not is_instance_valid(enemy):
			continue
		if attack_center.distance_to(enemy.global_position) <= attack_range:
			var result = DamageCalculator.calculate(
				config.attack_damage if config else 25, 0, GlobalDefine.DamageType.PHYSICAL
			)
			var kb_dir = attack_dir.normalized() if attack_dir != Vector2.ZERO else Vector2(1, 0)
			if enemy.has_method("take_damage"):
				enemy.take_damage(result["damage"], kb_dir)
			EventBus.emit(GlobalDefine.EventName.PLAYER_ATTACK_HIT, {
				"attacker": self, "target": enemy, "damage": result["damage"], "is_crit": result["is_crit"]
			})
			break

# ---- 赛博技能：长按蓄力 → 闪电突进 ----

func _on_skill() -> void:
	# 不调用 super，完全覆盖为赛博专属技能
	_is_charging = true
	_charge_time = 0.0
	attack_cooldown_timer = 0.0
	_skill_cooldown_timer = CYBER_SKILL_CD
	_change_state(GlobalDefine.PlayerState.SKILL)
	# 蓄力期间霸体：受击不击退不中断，只扣血
	_is_super_armor = true
	# 蓄力中减速
	velocity.x = move_toward(velocity.x, 0, 600.0)
	# 播放 attack 动画并冻结在第2帧
	if _anim_sprite and _anim_sprite.sprite_frames:
		if _anim_sprite.sprite_frames.has_animation("attack"):
			_anim_sprite.play("attack")
			_anim_sprite.frame = 2
			_anim_sprite.pause()

func _on_physics_process(delta: float) -> void:
	super._on_physics_process(delta)

	# 蓄力帧逻辑
	if _is_charging:
		_charge_time += delta
		# 蓄力视觉：角色微闪烁
		if _anim_sprite:
			var blink = 0.7 + 0.3 * abs(sin(_charge_time * 15.0))
			_anim_sprite.modulate = Color(blink, blink, 1.2, 1.0)
		# 冻结动画帧
		if _anim_sprite and _anim_sprite.animation == "attack":
			var max_frame = _anim_sprite.sprite_frames.get_frame_count("attack") - 1 if _anim_sprite.sprite_frames else 0
			_anim_sprite.frame = mini(2, max(0, max_frame))
			_anim_sprite.pause()
		# 超过最大蓄力自动释放
		if _charge_time >= MAX_CHARGE_TIME:
			_release_skill()
			return
		# 检测松开
		if not Input.is_action_pressed("player_skill"):
			_release_skill()
		return

	# 闪电突进帧逻辑
	if _is_lightning_dash:
		_dash_timer -= delta
		_lightning_cooldown -= delta
		velocity.x = _dash_dir * _dash_speed
		velocity.y = 0
		# 闪电特效（节流：每0.04s一道）
		if _lightning_cooldown <= 0:
			_spawn_lightning_bolt()
			_lightning_cooldown = 0.04
		# 突进中持续检测路径上敌人
		_check_dash_hit()
		if _dash_timer <= 0:
			_end_lightning_dash()
		return

# ---- 释放技能 ----

func _release_skill() -> void:
	_is_charging = false
	_is_super_armor = false
	if _anim_sprite:
		_anim_sprite.modulate = Color.WHITE
		_anim_sprite.position = Vector2.ZERO

	if _charge_time < CHARGE_THRESHOLD:
		# 短按 → 发射冲击波
		_fire_shockwave()
		is_attacking = true
		attack_timer = 0.3
		return

	# 长按 → 闪电突进
	_do_lightning_dash()

# ---- 短按：发射冲击波 ----

func _fire_shockwave() -> void:
	var facing_dir := 1.0 if is_facing_right else -1.0
	var projectile_script = load("res://Tools/SwordQiProjectile.gd")
	var projectile = Area2D.new()
	projectile.set_script(projectile_script)
	var parent = get_parent()
	if parent:
		parent.add_child(projectile)
		projectile.global_position = global_position + Vector2(facing_dir * 25, -10)
		projectile.setup(Vector2(facing_dir, 0), 25, self, 350.0)
	# 电弧视觉
	_spawn_shockwave_arc(facing_dir)

## 短按电弧视觉（单道，比技能全扇形简单）
func _spawn_shockwave_arc(facing_dir: float) -> void:
	var parent = get_parent()
	if not parent:
		return
	var attack_dir = Vector2(facing_dir, -0.15).normalized()
	var line = Line2D.new()
	line.width = 2.5
	line.default_color = Color(0.4, 0.7, 1.0, 0.9)
	line.z_index = 9
	var start = global_position + Vector2(facing_dir * 15, -10)
	var points = [parent.to_local(start)]
	var pos = start
	for j in range(4):
		var seg_len = 18.0 + randf() * 12.0
		var jitter = randf_range(-0.25, 0.25)
		pos += attack_dir * seg_len + Vector2(jitter * 18, randf_range(-8, 8))
		points.append(parent.to_local(pos))
	for pt in points:
		line.add_point(pt)
	parent.add_child(line)
	var tween = line.create_tween()
	tween.tween_property(line, "modulate:a", 0.0, 0.25)
	tween.tween_callback(line.queue_free)

# ---- 闪电突进 ----

func _do_lightning_dash() -> void:
	_is_lightning_dash = true
	_dash_timer = _dash_duration
	_dash_dir = 1.0 if is_facing_right else -1.0
	_dash_start_pos = global_position
	_dash_hit_enemies.clear()
	_lightning_cooldown = 0.0
	is_attacking = true
	attack_timer = _dash_duration + 0.1
	# 全程无敌
	_was_invincible = is_invincible
	is_invincible = true
	invincible_timer = _dash_duration + 0.1
	_change_state(GlobalDefine.PlayerState.SKILL)
	# 起手闪电爆发
	_spawn_lightning_burst()

func _end_lightning_dash() -> void:
	_is_lightning_dash = false
	_is_super_armor = false
	# 恢复无敌状态
	if not _was_invincible:
		is_invincible = false
		_restore_visibility()
	# 终点再检测一次路径敌人
	var end_pos = global_position
	for enemy in GameManager.get_enemies():
		if not is_instance_valid(enemy):
			continue
		var eid = enemy.get_instance_id()
		if eid in _dash_hit_enemies:
			continue
		var dist = _point_to_segment_dist(enemy.global_position, _dash_start_pos, end_pos)
		if dist <= 55.0:
			_deal_dash_damage(enemy)
	# 终点闪电爆发
	_spawn_lightning_burst()
	# 震屏
	var cam = get_node_or_null("SmoothCamera")
	if cam and cam.has_method("shake"):
		cam.shake(5.0, 0.12)

func _check_dash_hit() -> void:
	for enemy in GameManager.get_enemies():
		if not is_instance_valid(enemy):
			continue
		var eid = enemy.get_instance_id()
		if eid in _dash_hit_enemies:
			continue
		if global_position.distance_to(enemy.global_position) <= 50.0:
			_deal_dash_damage(enemy)

func _deal_dash_damage(enemy: Node2D) -> void:
	_dash_hit_enemies.append(enemy.get_instance_id())
	var result = DamageCalculator.calculate(30, 0, GlobalDefine.DamageType.MAGIC, 0.15)
	var kb_dir = Vector2(_dash_dir, -0.3).normalized()
	if enemy.has_method("take_damage"):
		enemy.take_damage(result["damage"], kb_dir)
	EventBus.emit(GlobalDefine.EventName.PLAYER_ATTACK_HIT, {
		"attacker": self, "target": enemy, "damage": result["damage"], "is_crit": result["is_crit"]
	})

## 点到线段距离
func _point_to_segment_dist(point: Vector2, seg_a: Vector2, seg_b: Vector2) -> float:
	var ab = seg_b - seg_a
	if ab.dot(ab) < 0.01:
		return point.distance_to(seg_a)
	var ap = point - seg_a
	var t = clampf(ap.dot(ab) / ab.dot(ab), 0.0, 1.0)
	var closest = seg_a + ab * t
	return point.distance_to(closest)

# ---- 闪电视觉特效 ----

## 突进路径闪电（纵向短折线）
func _spawn_lightning_bolt() -> void:
	var parent = get_parent()
	if not parent:
		return
	var line = Line2D.new()
	line.width = 2.5
	line.default_color = Color(0.3, 0.6, 1.0, 0.9)
	line.z_index = 9
	var start = global_position + Vector2(0, -5)
	var points = [parent.to_local(start)]
	var pos = start
	var seg_count = 3 + randi_range(0, 2)
	for i in range(seg_count):
		var seg_len = 8.0 + randf() * 6.0
		var jitter_x = randf_range(-12.0, 12.0)
		pos += Vector2(jitter_x, seg_len)
		points.append(parent.to_local(pos))
	for pt in points:
		line.add_point(pt)
	parent.add_child(line)
	# 闪电淡出
	var tween = line.create_tween()
	tween.tween_property(line, "modulate:a", 0.0, 0.2)
	tween.tween_callback(line.queue_free)

## 起手/终点闪电爆发（放射状折线）
func _spawn_lightning_burst() -> void:
	var parent = get_parent()
	if not parent:
		return
	for i in range(5):
		var angle = TAU * i / 5.0 + randf_range(-0.3, 0.3)
		var arc_dir = Vector2.from_angle(angle)
		var line = Line2D.new()
		line.width = 2.0
		line.default_color = Color(0.5, 0.8, 1.0, 0.85)
		line.z_index = 9
		var start = global_position + Vector2(0, -10)
		var points = [parent.to_local(start)]
		var pos = start
		var seg_count = 3 + randi_range(0, 2)
		for j in range(seg_count):
			var seg_len = 15.0 + randf() * 10.0
			var jitter = randf_range(-0.3, 0.3)
			pos += arc_dir * seg_len + Vector2(jitter * 15, randf_range(-8, 8))
			points.append(parent.to_local(pos))
		for pt in points:
			line.add_point(pt)
		parent.add_child(line)
		var tween = line.create_tween()
		tween.tween_property(line, "modulate:a", 0.0, 0.25)
		tween.tween_callback(line.queue_free)

# ---- 覆盖：蓄力期间冻结动画 ----

func _update_animation() -> void:
	if _is_charging and _anim_sprite:
		return  # 蓄力期间不更新动画
	super._update_animation()

func _handle_attack_state(delta: float) -> void:
	if _is_lightning_dash:
		return  # 突进有自己的速度控制
	super._handle_attack_state(delta)

# ---- 覆盖：技能执行中不接受其他操作 ----

func _on_game_action(action: StringName, _event: InputEvent) -> void:
	if _is_charging or _is_lightning_dash:
		return
	super._on_game_action(action, _event)

# ---- 死亡时清理技能状态 ----

func _on_die() -> void:
	_is_charging = false
	_is_lightning_dash = false
	_is_super_armor = false
	if _anim_sprite:
		_anim_sprite.modulate = Color.WHITE
		_anim_sprite.position = Vector2.ZERO
	super._on_die()
