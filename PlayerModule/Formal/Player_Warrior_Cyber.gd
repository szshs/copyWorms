extends Player_Warrior
class_name Player_Warrior_Cyber

var _hit_pending: bool = false

# ---- 长按普攻：闪电突进（原技能突进逻辑，独立CD不影响普攻） ----
var _attack_hold_time: float = 0.0
const ATTACK_HOLD_THRESHOLD := 0.18   # 长按阈值（略微减少）
var _dash_cd_timer: float = 0.0        # 突进独立CD（不影响普攻）
const DASH_CD := 3.0                   # 突进CD（略微减少）
const DASH_WINDUP_TIME := 0.2          # 突进前摇蓄力时长
var _dash_windup: bool = false         # 突进蓄力中
var _dash_windup_timer: float = 0.0    # 蓄力计时

# ---- 技能蓄力（I键）：短按1发，0.2-0.5s蓄力3发，超0.5s蓄力5发 ----
var _skill_charging: bool = false
var _skill_charge_time: float = 0.0
const SKILL_CHARGE_TIER1 := 0.2   # 3发阈值
const SKILL_CHARGE_TIER2 := 0.5   # 5发阈值

# ---- 闪电突进状态 ----
var _is_lightning_dash: bool = false
var _dash_timer: float = 0.0
var _dash_dir: float = 1.0
var _dash_speed: float = 1200.0
var _dash_duration: float = 0.25
var _dash_start_pos: Vector2 = Vector2.ZERO
var _dash_hit_enemies: Array = []
var _lightning_cooldown: float = 0.0
var _was_invincible: bool = false

const CYBER_SKILL2_WINDOW := 2.0
const CYBER_SKILL2_CD := 5.0
const CYBER_SKILL2_FRONT_OFFSET := 64.0
const CYBER_SKILL2_STAB_DISTANCE := 92.0
const CYBER_SKILL2_POSE_TARGET_HEIGHT := 66.0
const CYBER_SKILL2_STAB_TEXTURE := preload("res://Assets/Sprites/player_cyber Ani/技能二.png")
const CYBER_SKILL2_SLASH_TEXTURE := preload("res://Assets/Sprites/player_cyber Ani/技能二1.png")
const CYBER_SKILL2_EFFECT_A := preload("res://Assets/Effects/蓝色直线斩击特效 1.png")
const CYBER_SKILL2_EFFECT_B := preload("res://Assets/Effects/蓝色直线斩击特效.png")
var _skill2_charging: bool = false
var _skill2_timer: float = 0.0
var _skill2_cooldown_timer: float = 0.0
var _skill2_sequence_active: bool = false
var _skill2_pose_sprite: Sprite2D = null
var _skill2_saved_invincible: bool = false
var _skill2_saved_super_armor: bool = false
var _skill2_saved_facing_right: bool = true
var _skill2_manual_dash_visual: bool = false

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

# ---- 长按普攻：闪电突进 ----

func _on_physics_process(delta: float) -> void:
	super._on_physics_process(delta)

	if _skill2_cooldown_timer > 0:
		_skill2_cooldown_timer -= delta

	if _skill2_charging:
		_skill2_timer += delta
		_update_skill_charge_sfx(clampf(_skill2_timer / CYBER_SKILL2_WINDOW, 0.0, 1.0))
		if _anim_sprite:
			var blink2 = 0.75 + 0.25 * abs(sin(_skill2_timer * 22.0))
			_anim_sprite.modulate = Color(0.75, 0.95, 1.35, 1.0) * blink2
		velocity.x = move_toward(velocity.x, 0, 900.0 * delta)
		if Input.is_action_just_pressed("player_attack"):
			_do_skill2_manual_stab()
			return
		if _skill2_timer >= CYBER_SKILL2_WINDOW or not Input.is_action_pressed("player_skill_2"):
			_cancel_skill2_charge()
			return

	# 技能蓄力检测：按住 I 键蓄力，松开按蓄力时长决定子弹数
	if _skill_charging:
		_skill_charge_time += delta
		# 蓄力期间允许转向（以输入方向为准）
		var input_dir = _get_input_direction()
		if abs(input_dir.x) > 0.1:
			is_facing_right = input_dir.x > 0
		_update_skill_charge_sfx(clampf(_skill_charge_time / SKILL_CHARGE_TIER2, 0.0, 1.0))
		# 蓄力视觉：角色微闪烁，强度随蓄力时间增强
		if _anim_sprite:
			var intensity = clampf(_skill_charge_time / SKILL_CHARGE_TIER2, 0.0, 1.0)
			var blink = 0.8 + 0.2 * abs(sin(_skill_charge_time * 25.0))
			_anim_sprite.modulate = Color(blink, blink, 1.0 + 0.3 * intensity, 1.0)
			# 保持 attack 动画冻结在第2帧（攻击前摇视觉）
			if _anim_sprite.sprite_frames and _anim_sprite.sprite_frames.has_animation("attack"):
				if _anim_sprite.animation != "attack":
					_anim_sprite.play("attack")
				var max_frame = _anim_sprite.sprite_frames.get_frame_count("attack") - 1
				_anim_sprite.frame = mini(2, max(0, max_frame))
				_anim_sprite.pause()
		# 松开释放
		if not Input.is_action_pressed("player_skill"):
			_release_skill()
		return

	# 突进CD递减
	if _dash_cd_timer > 0:
		_dash_cd_timer -= delta

	# 长按普攻检测：按下时计时，超过阈值触发突进蓄力
	if can_attack_hold_dash and not _is_lightning_dash and not _dash_windup and not is_attacking and not is_dashing:
		if Input.is_action_pressed("player_attack") and _dash_cd_timer <= 0:
			_attack_hold_time += delta
			if _attack_hold_time >= ATTACK_HOLD_THRESHOLD:
				_attack_hold_time = 0.0
				_start_dash_windup()
		else:
			_attack_hold_time = 0.0
	else:
		_attack_hold_time = 0.0

	# 突进蓄力帧逻辑：最少蓄力 DASH_WINDUP_TIME，之后由玩家松开普攻键释放
	if _dash_windup:
		_dash_windup_timer -= delta
		# 蓄力期间允许转向（以输入方向为准）
		var input_dir = _get_input_direction()
		if abs(input_dir.x) > 0.1:
			is_facing_right = input_dir.x > 0
		# 蓄力视觉：角色微闪烁（随蓄力时长增强）
		if _anim_sprite:
			var charge_ratio = clampf(1.0 - _dash_windup_timer / DASH_WINDUP_TIME, 0.0, 1.0)
			var blink = 0.7 + 0.3 * abs(sin(_dash_windup_timer * 30.0))
			_anim_sprite.modulate = Color(blink, blink, 1.2 + 0.3 * charge_ratio, 1.0)
		# 冻结 attack 动画在第2帧
		if _anim_sprite and _anim_sprite.sprite_frames:
			if _anim_sprite.sprite_frames.has_animation("attack"):
				if _anim_sprite.animation != "attack":
					_anim_sprite.play("attack")
				var max_frame = _anim_sprite.sprite_frames.get_frame_count("attack") - 1
				_anim_sprite.frame = mini(2, max(0, max_frame))
				_anim_sprite.pause()
		# 蓄力期间减速
		velocity.x = move_toward(velocity.x, 0, 600.0)
		# 最少蓄力时间过后，玩家松开普攻键 → 突进
		if _dash_windup_timer <= 0:
			if not Input.is_action_pressed("player_attack"):
				_dash_windup = false
				if _anim_sprite:
					_anim_sprite.modulate = Color.WHITE
				_do_lightning_dash()
			# 否则继续蓄力，等待玩家释放
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

# ---- 技能（I键）：蓄力释放远程剑气 ----

func _on_skill() -> void:
	# 开始蓄力，由玩家选择释放时机（松开I键释放）
	_skill_charging = true
	_skill_charge_time = 0.0
	_start_skill_charge_sfx()
	attack_cooldown_timer = 0.0
	# 技能CD在释放时才开始
	_change_state(GlobalDefine.PlayerState.SKILL)
	# 减速蓄力
	velocity.x = move_toward(velocity.x, 0, 600.0)
	# 播放 attack 动画并冻结在第2帧（攻击前摇视觉）
	if _anim_sprite and _anim_sprite.sprite_frames:
		if _anim_sprite.sprite_frames.has_animation("attack"):
			_anim_sprite.play("attack")
			_anim_sprite.frame = 2
			_anim_sprite.pause()

func _release_skill() -> void:
	_play_skill_release_sfx()
	_skill_charging = false
	if _anim_sprite:
		_anim_sprite.modulate = Color.WHITE
	# 释放时才开始技能CD
	_skill_cooldown_timer = CYBER_SKILL_CD
	# 根据蓄力时长决定子弹数
	var count: int
	if _skill_charge_time < SKILL_CHARGE_TIER1:
		count = 1
	elif _skill_charge_time < SKILL_CHARGE_TIER2:
		count = 3
	else:
		count = 5
	is_attacking = true
	has_hit_this_attack = false
	attack_timer = 0.6
	# 连发剑气弹体（散射+追踪Boss）
	var facing_dir := 1.0 if is_facing_right else -1.0
	# Boss战时散射中心朝向Boss，否则朝面向方向
	var base_dir = Vector2(facing_dir, 0)
	if GameManager.boss_target and is_instance_valid(GameManager.boss_target):
		var to_boss = GameManager.boss_target.global_position - global_position
		if to_boss.length() > 10:
			base_dir = to_boss.normalized()
	var projectile_script = load("res://Tools/SwordQiProjectile.gd")
	var parent = get_parent()
	for i in range(count):
		var projectile = Area2D.new()
		projectile.set_script(projectile_script)
		if parent:
			parent.add_child(projectile)
			# 扇形散布，散射后追踪Boss
			var spread_angle = deg_to_rad(-30 + i * (60.0 / max(count - 1, 1))) if count > 1 else 0.0
			var dir = base_dir.rotated(spread_angle)
			projectile.global_position = global_position + Vector2(facing_dir * 25, -10) + Vector2(0, (i - (count - 1) / 2.0) * 8)
			projectile.setup_homing(dir, 20 - 1, self, 600.0, true)
	# 扇形电弧视觉
	_spawn_arc_effect(Vector2(facing_dir, -0.2).normalized(), facing_dir)
	# 震屏
	var cam = get_node_or_null("SmoothCamera")
	if cam and cam.has_method("shake"):
		cam.shake(6.0, 0.15)

const CYBER_SKILL_CD := 4.0  # 技能CD（保持不变）

func perform_skill_2() -> void:
	if _skill2_charging or _skill2_sequence_active or _skill_charging or _is_lightning_dash or _dash_windup:
		return
	if _skill2_cooldown_timer > 0 or is_attacking or is_dashing:
		return
	_skill2_charging = true
	_skill2_timer = 0.0
	_skill2_cooldown_timer = CYBER_SKILL2_CD
	_start_skill_charge_sfx()
	_change_state(GlobalDefine.PlayerState.SKILL)
	velocity.x = move_toward(velocity.x, 0, 600.0)
	if _anim_sprite:
		_anim_sprite.modulate = Color(0.65, 0.95, 1.4, 1.0)

func _cancel_skill2_charge() -> void:
	_stop_skill_charge_sfx()
	_skill2_charging = false
	_skill2_timer = 0.0
	if _anim_sprite:
		_anim_sprite.modulate = Color.WHITE
	if current_state == GlobalDefine.PlayerState.SKILL:
		_change_state(GlobalDefine.PlayerState.IDLE)

func _do_skill2_manual_stab() -> void:
	if not _skill2_charging:
		return
	_stop_skill_charge_sfx()
	_skill2_charging = false
	_skill2_timer = 0.0
	_skill2_sequence_active = true
	_skill2_saved_invincible = is_invincible
	_skill2_saved_super_armor = _is_super_armor
	_skill2_saved_facing_right = is_facing_right
	var input_dir := _get_input_direction()
	if abs(input_dir.x) > 0.1:
		is_facing_right = input_dir.x > 0
	scale.x = 1
	if _anim_sprite:
		_anim_sprite.flip_h = not is_facing_right
	is_invincible = true
	_is_super_armor = true
	invincible_timer = maxf(invincible_timer, _dash_duration + 0.35)
	_change_state(GlobalDefine.PlayerState.SKILL)
	_skill2_manual_dash_visual = true
	_play_skill2_pose(CYBER_SKILL2_STAB_TEXTURE)
	_do_lightning_dash()
	await get_tree().create_timer(_dash_duration + 0.08).timeout
	_clear_skill2_pose()
	_finish_skill2_sequence(true)

func take_damage(damage: int, knockback_dir: Vector2 = Vector2.ZERO) -> void:
	if _skill2_sequence_active:
		return
	if _skill2_charging:
		_trigger_skill2_counter(_find_skill2_attacker(knockback_dir))
		return
	super.take_damage(damage, knockback_dir)

func _take_contact_damage(enemy: Node2D) -> void:
	if _skill2_sequence_active:
		return
	if _skill2_charging:
		_trigger_skill2_counter(enemy)
		return
	super._take_contact_damage(enemy)

func _trigger_skill2_counter(enemy: Node2D) -> void:
	if _skill2_sequence_active:
		return
	_stop_skill_charge_sfx()
	_skill2_charging = false
	_skill2_timer = 0.0
	if not is_instance_valid(enemy):
		enemy = _find_nearest_enemy()
	if not is_instance_valid(enemy):
		_cancel_skill2_charge()
		return
	_skill2_sequence_active = true
	_skill2_saved_invincible = is_invincible
	_skill2_saved_super_armor = _is_super_armor
	_skill2_saved_facing_right = is_facing_right
	is_invincible = true
	_is_super_armor = true
	invincible_timer = maxf(invincible_timer, CYBER_SKILL2_WINDOW + 1.0)
	is_attacking = true
	attack_timer = 1.1
	_change_state(GlobalDefine.PlayerState.SKILL)
	_run_skill2_counter_sequence(enemy)

func _run_skill2_counter_sequence(enemy: Node2D) -> void:
	_spawn_skill2_afterimage_stack()
	await get_tree().create_timer(0.16).timeout
	if not is_instance_valid(enemy):
		_finish_skill2_sequence()
		return
	var side := signf(global_position.x - enemy.global_position.x)
	if side == 0:
		side = -1.0 if is_facing_right else 1.0
	var front_pos := enemy.global_position + Vector2(side * CYBER_SKILL2_FRONT_OFFSET, 0)
	var back_pos := enemy.global_position - Vector2(side * CYBER_SKILL2_FRONT_OFFSET, 0)

	global_position = front_pos
	_face_skill2_target(enemy)
	_play_normal_attack_on_skill2(enemy)
	await get_tree().create_timer(0.30).timeout

	if is_instance_valid(enemy):
		global_position = back_pos
		_face_skill2_target(enemy)
		_play_skill2_pose(CYBER_SKILL2_SLASH_TEXTURE)
		_spawn_skill2_slash_effect(enemy, CYBER_SKILL2_EFFECT_A)
		_deal_skill2_damage(enemy, 18, 10.0, 0.18)
	await get_tree().create_timer(0.36).timeout

	if is_instance_valid(enemy):
		global_position = front_pos
		_face_skill2_target(enemy)
		_play_skill2_pose(CYBER_SKILL2_STAB_TEXTURE)
		_spawn_skill2_slash_effect(enemy, CYBER_SKILL2_EFFECT_B)
		_deal_skill2_damage(enemy, 22, 12.0, 0.20)
		var dash_dir := 1.0 if is_facing_right else -1.0
		var tween := create_tween()
		tween.tween_property(self, "global_position", global_position + Vector2(dash_dir * CYBER_SKILL2_STAB_DISTANCE, 0), 0.20).set_trans(Tween.TRANS_QUAD)
		await tween.finished
	else:
		await get_tree().create_timer(0.12).timeout
	_clear_skill2_pose()
	_finish_skill2_sequence()

func _finish_skill2_sequence(force_recover_state: bool = true) -> void:
	if _is_lightning_dash:
		_end_lightning_dash()
	_skill2_manual_dash_visual = false
	_skill2_sequence_active = false
	_is_lightning_dash = false
	_dash_timer = 0.0
	_lightning_cooldown = 0.0
	_dash_windup = false
	_dash_windup_timer = 0.0
	_dash_hit_enemies.clear()
	_attack_hold_time = 0.0
	_hit_pending = false
	is_attacking = false
	attack_timer = 0.0
	has_hit_this_attack = false
	_attack_started_in_air = false
	_attack_windup_pending = false
	_attack_windup_timer = 0.0
	if not _skill2_saved_invincible:
		is_invincible = false
		_restore_visibility()
	_is_super_armor = _skill2_saved_super_armor
	_clear_skill2_pose()
	if _anim_sprite:
		_anim_sprite.visible = true
		_anim_sprite.modulate = Color.WHITE
		_anim_sprite.position = Vector2.ZERO
		_anim_sprite.speed_scale = 1.0
	var input_dir := _get_input_direction()
	if abs(input_dir.x) > 0.1:
		is_facing_right = input_dir.x > 0
	else:
		is_facing_right = _skill2_saved_facing_right
	velocity.x = 0.0
	scale.x = 1
	if _anim_sprite:
		_anim_sprite.flip_h = not is_facing_right
	if force_recover_state or current_state == GlobalDefine.PlayerState.SKILL or current_state == GlobalDefine.PlayerState.ATTACK:
		_recover_skill2_animation_state()

func _recover_skill2_animation_state() -> void:
	var next_state := GlobalDefine.PlayerState.IDLE
	if not is_on_floor():
		next_state = GlobalDefine.PlayerState.FALL if velocity.y > 0.0 else GlobalDefine.PlayerState.JUMP
	elif abs(_get_input_direction().x) > 0.1:
		next_state = GlobalDefine.PlayerState.RUN
	_change_state(next_state)
	_last_anim = ""
	_update_animation()
	if _anim_sprite and _anim_sprite.sprite_frames:
		var target_anim := _get_anim_for_state()
		if _anim_sprite.sprite_frames.has_animation(target_anim):
			_anim_sprite.play(target_anim)

# ---- 突进蓄力 ----

func _play_skill2_pose(texture: Texture2D) -> void:
	_clear_skill2_pose()
	if _anim_sprite:
		_anim_sprite.visible = false
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.centered = true
	sprite.z_index = 15
	var bounds := _get_skill2_pose_visible_bounds(texture)
	var visible_center := bounds.position + bounds.size * 0.5
	var texture_center := Vector2(texture.get_width(), texture.get_height()) * 0.5
	var s := CYBER_SKILL2_POSE_TARGET_HEIGHT / maxf(bounds.size.y, 1.0)
	sprite.position = Vector2(0, -10) + (texture_center - visible_center) * s
	sprite.scale = Vector2(s * (1.0 if is_facing_right else -1.0), s)
	add_child(sprite)
	_skill2_pose_sprite = sprite

func _get_skill2_pose_visible_bounds(texture: Texture2D) -> Rect2:
	if texture == CYBER_SKILL2_STAB_TEXTURE:
		return Rect2(104, 216, 2001, 929)
	if texture == CYBER_SKILL2_SLASH_TEXTURE:
		return Rect2(716, 124, 1549, 1349)
	return Rect2(0, 0, texture.get_width(), texture.get_height())

func _clear_skill2_pose() -> void:
	if _skill2_pose_sprite and is_instance_valid(_skill2_pose_sprite):
		_skill2_pose_sprite.queue_free()
	_skill2_pose_sprite = null
	if _anim_sprite:
		_anim_sprite.visible = true

func _spawn_skill2_afterimage_stack() -> void:
	var parent = get_parent()
	if not parent or not _anim_sprite or not _anim_sprite.sprite_frames:
		return
	var tex := _anim_sprite.sprite_frames.get_frame_texture(_anim_sprite.animation, _anim_sprite.frame)
	if not tex:
		return
	for i in range(6):
		var ghost := Sprite2D.new()
		ghost.texture = tex
		ghost.centered = true
		ghost.global_position = global_position + Vector2((i - 2) * -5.0 * (1.0 if is_facing_right else -1.0), -10 - i * 2.0)
		ghost.global_scale = Vector2(1.0 if is_facing_right else -1.0, 1.0)
		ghost.modulate = Color(0.35, 0.8, 1.0, 0.38 - i * 0.04)
		ghost.z_index = 12 - i
		parent.add_child(ghost)
		var tween := ghost.create_tween()
		tween.tween_property(ghost, "modulate:a", 0.0, 0.28)
		tween.tween_callback(ghost.queue_free)

func _spawn_skill2_slash_effect(enemy: Node2D, texture: Texture2D) -> void:
	var parent = get_parent()
	if not parent or not is_instance_valid(enemy):
		return
	var fx := Sprite2D.new()
	fx.texture = texture
	fx.centered = true
	fx.z_index = 18
	var bounds := _get_skill2_effect_visible_bounds(texture)
	var visible_center := bounds.position + bounds.size * 0.5
	var texture_center := Vector2(texture.get_width(), texture.get_height()) * 0.5
	var scale_by_width := 180.0 / maxf(bounds.size.x, 1.0)
	parent.add_child(fx)
	fx.global_position = enemy.global_position + Vector2(0, -8) + (texture_center - visible_center) * scale_by_width
	fx.global_scale = Vector2(scale_by_width * (1.0 if is_facing_right else -1.0), scale_by_width)
	var tween := fx.create_tween()
	tween.tween_property(fx, "modulate:a", 0.0, 0.24)
	tween.tween_callback(fx.queue_free)

func _get_skill2_effect_visible_bounds(texture: Texture2D) -> Rect2:
	if texture == CYBER_SKILL2_EFFECT_A:
		return Rect2(0, 216, 2729, 1029)
	if texture == CYBER_SKILL2_EFFECT_B:
		return Rect2(0, 392, 2549, 725)
	return Rect2(0, 0, texture.get_width(), texture.get_height())

func _deal_skill2_damage(enemy: Node2D, base_damage: int, shake_strength: float = 8.0, shake_duration: float = 0.14) -> void:
	if not is_instance_valid(enemy):
		return
	var result = DamageCalculator.calculate(base_damage, 0, GlobalDefine.DamageType.MAGIC, 0.15)
	var kb_dir = (enemy.global_position - global_position).normalized()
	if kb_dir == Vector2.ZERO:
		kb_dir = Vector2(1.0 if is_facing_right else -1.0, 0)
	if enemy.has_method("take_damage"):
		enemy.take_damage(result["damage"], kb_dir)
	EventBus.emit(GlobalDefine.EventName.PLAYER_ATTACK_HIT, {
		"attacker": self, "target": enemy, "damage": result["damage"], "is_crit": result["is_crit"]
	})
	_skill2_hit_feedback(shake_strength, shake_duration)

func _play_normal_attack_on_skill2(enemy: Node2D) -> void:
	if _anim_sprite and _anim_sprite.sprite_frames and _anim_sprite.sprite_frames.has_animation("attack"):
		_anim_sprite.visible = true
		_anim_sprite.play("attack")
	_deal_skill2_damage(enemy, config.attack_damage if config else 25, 9.0, 0.16)

func _skill2_hit_feedback(shake_strength: float, shake_duration: float) -> void:
	var cam = get_node_or_null("SmoothCamera")
	if cam and cam.has_method("shake"):
		cam.shake(shake_strength, shake_duration)
	_start_skill2_hitstop(0.045)

func _start_skill2_hitstop(duration: float) -> void:
	if Engine.time_scale < 0.99:
		return
	Engine.time_scale = 0.08
	get_tree().create_timer(duration, true, false, true).timeout.connect(_end_skill2_hitstop)

func _end_skill2_hitstop() -> void:
	if Engine.time_scale < 0.99:
		Engine.time_scale = 1.0

func _face_skill2_target(enemy: Node2D) -> void:
	if not is_instance_valid(enemy):
		return
	is_facing_right = enemy.global_position.x >= global_position.x
	scale.x = 1
	if _anim_sprite:
		_anim_sprite.flip_h = not is_facing_right

func _find_skill2_attacker(knockback_dir: Vector2) -> Node2D:
	var best: Node2D = null
	var best_score := INF
	for enemy in GameManager.get_enemies():
		if not is_instance_valid(enemy):
			continue
		var to_enemy := enemy.global_position - global_position
		var dist := to_enemy.length()
		var score := dist
		if knockback_dir != Vector2.ZERO and signf(to_enemy.x) == -signf(knockback_dir.x):
			score *= 0.45
		if score < best_score:
			best_score = score
			best = enemy
	return best

func _find_nearest_enemy() -> Node2D:
	var best: Node2D = null
	var best_dist := INF
	for enemy in GameManager.get_enemies():
		if not is_instance_valid(enemy):
			continue
		var dist := global_position.distance_to(enemy.global_position)
		if dist < best_dist:
			best_dist = dist
			best = enemy
	return best

func _start_dash_windup() -> void:
	_dash_windup = true
	_dash_windup_timer = DASH_WINDUP_TIME
	_change_state(GlobalDefine.PlayerState.ATTACK)

# ---- 闪电突进 ----

func _do_lightning_dash() -> void:
	_play_charge_attack_sfx()
	_is_lightning_dash = true
	_dash_timer = _dash_duration
	_dash_dir = 1.0 if is_facing_right else -1.0
	_dash_start_pos = global_position
	_dash_hit_enemies.clear()
	_lightning_cooldown = 0.0
	_dash_cd_timer = DASH_CD  # 突进独立CD
	is_attacking = true
	attack_timer = _dash_duration + 0.1
	# 全程无敌
	_was_invincible = is_invincible
	is_invincible = true
	invincible_timer = _dash_duration + 0.1 + 0.3
	_change_state(GlobalDefine.PlayerState.ATTACK)
	# 起手闪电爆发
	_spawn_lightning_burst()

func _end_lightning_dash() -> void:
	_is_lightning_dash = false
	# 恢复无敌状态
	if _skill2_sequence_active:
		is_invincible = true
		_is_super_armor = true
	elif not _was_invincible:
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
		if dist <= 75.0:
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
		if global_position.distance_to(enemy.global_position) <= 70.0:
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

# ---- 扇形电弧视觉（技能用） ----

func _spawn_arc_effect(attack_dir: Vector2, facing_dir: float) -> void:
	var parent = get_parent()
	if not parent:
		return
	for i in range(3):
		var arc_angle = attack_dir.angle() + deg_to_rad(-40 + i * 40) + randf_range(-0.1, 0.1)
		var arc_dir = Vector2.from_angle(arc_angle)
		var line = Line2D.new()
		line.width = 2.0
		line.default_color = Color(0.4, 0.7, 1.0, 0.9)
		line.z_index = 9
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
		var tween = line.create_tween()
		tween.tween_property(line, "modulate:a", 0.0, 0.3)
		tween.tween_callback(line.queue_free)

# ---- 覆盖：突进期间不更新动画 ----

func _update_animation() -> void:
	if _is_lightning_dash or _dash_windup or _skill_charging or _skill2_charging or _skill2_sequence_active:
		return  # 突进/蓄力有自己的动画控制
	super._update_animation()

func _handle_attack_state(delta: float) -> void:
	if _is_lightning_dash or _dash_windup or _skill_charging or _skill2_charging or _skill2_sequence_active:
		return  # 突进/蓄力有自己的速度控制
	super._handle_attack_state(delta)

# ---- 覆盖：突进/蓄力中不接受其他操作 ----

func _on_game_action(action: StringName, _event: InputEvent) -> void:
	if _skill2_charging:
		if action == &"player_attack":
			_do_skill2_manual_stab()
		return
	if _is_lightning_dash or _dash_windup or _skill_charging or _skill2_sequence_active:
		return
	super._on_game_action(action, _event)

# ---- 死亡时清理状态 ----

func _on_die() -> void:
	_stop_skill_charge_sfx()
	_is_lightning_dash = false
	_dash_windup = false
	_skill_charging = false
	_skill2_charging = false
	_skill2_sequence_active = false
	_skill_charge_time = 0.0
	_skill2_timer = 0.0
	_attack_hold_time = 0.0
	_clear_skill2_pose()
	if _anim_sprite:
		_anim_sprite.modulate = Color.WHITE
		_anim_sprite.position = Vector2.ZERO
	super._on_die()
