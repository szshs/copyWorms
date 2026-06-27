# ============================================================
# Enemy_LanternGhost.gd - 岭南怪物「灯笼鬼」
# 行为：空中漂浮 → 发现玩家后悬停 → 释放火球攻击
# 不靠近玩家，保持距离远程攻击
# ============================================================
extends EnemyBase
class_name Enemy_LanternGhost

var _anim_sprite: AnimatedSprite2D = null

# 漂浮系统
var _float_base_y: float = 0.0
var _float_phase: float = 0.0
const FLOAT_AMPLITUDE: float = 12.0
const FLOAT_SPEED: float = 2.5

# 火球攻击
var _fireball_cooldown: float = 0.0
const FIREBALL_CD: float = 2.0
const FIREBALL_SPEED: float = 300.0
const FIREBALL_DAMAGE: int = 10
const FIREBALL_MAX_DIST: float = 500.0

# 悬停距离：不会靠近玩家，保持在此距离
const HOVER_MIN_DIST: float = 150.0
const HOVER_MAX_DIST: float = 300.0

# 追踪方向滞后
var _chase_dir: int = 0
const CHASE_DIR_THRESHOLD: float = 8.0

# 朝向死区
const FACING_DEAD_ZONE: float = 5.0

func _on_ready() -> void:
	super._on_ready()
	if not config:
		config = load("res://DataConfig/Enemy/LanternGhostConfig.tres") as EnemyConfig
		_apply_config()
	_init_anim_sprite()
	# 飞行模式：不受地面吸附
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	# 飞行但仍受地形碰撞限制，避免穿越关卡碰撞层
	collision_mask = GlobalDefine.Collision.TERRAIN
	# 初始漂浮高度：在生成位置上方60px
	_float_base_y = global_position.y - 60.0
	_float_phase = randf() * TAU
	is_facing_right = patrol_direction > 0
	if _anim_sprite:
		_anim_sprite.flip_h = not is_facing_right

func _get_collision_size() -> Vector2:
	return Vector2(32, 40)

func _init_anim_sprite() -> void:
	_anim_sprite = get_node_or_null("Sprite") as AnimatedSprite2D
	if _anim_sprite:
		_anim_sprite.play("idle")
		_anim_sprite.offset = Vector2(0, -16)
	var old = get_node_or_null("PlaceholderSprite")
	if old:
		old.queue_free()
	var blink = get_node_or_null("LowHPBlink")
	if blink:
		blink.queue_free()

# ---- 重力免疫 ----

func _apply_gravity(_delta: float) -> void:
	# 灯笼鬼不受重力
	pass

# ---- AI 拦截 ----

func _handle_ai(delta: float) -> void:
	if stun_timer > 0:
		velocity.x = move_toward(velocity.x, 0, 500 * delta)
		velocity.y = move_toward(velocity.y, 0, 300 * delta)
		return

	# 漂浮始终生效
	_float_phase += FLOAT_SPEED * delta
	var float_y = _float_base_y + sin(_float_phase) * FLOAT_AMPLITUDE
	velocity.y = (float_y - global_position.y) * 5.0

	match current_state:
		GlobalDefine.EnemyState.IDLE:
			_ai_idle(delta)
		GlobalDefine.EnemyState.PATROL:
			_ai_patrol(delta)
		GlobalDefine.EnemyState.CHASE:
			_ai_chase(delta)
		GlobalDefine.EnemyState.ATTACK:
			_ai_attack(delta)
		GlobalDefine.EnemyState.HURT:
			_ai_hurt(delta)

# ---- 巡逻：缓慢水平移动 + 漂浮 ----

func _ai_idle(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0, 200 * delta)
	if patrol_wait_timer <= 0:
		patrol_wait_timer = config.patrol_wait_time if config else 2.0
		_change_state(GlobalDefine.EnemyState.PATROL)
	if _can_detect_target():
		_change_state(GlobalDefine.EnemyState.CHASE)

func _ai_patrol(delta: float) -> void:
	var speed = (config.move_speed if config else 100.0) * 0.5
	velocity.x = patrol_direction * speed

	var dist_from_start = global_position.x - patrol_start_pos.x
	var wander = config.wander_radius if config else 100.0
	if abs(dist_from_start) > wander:
		patrol_direction *= -1
		_change_state(GlobalDefine.EnemyState.IDLE)

	if _can_detect_target():
		_change_state(GlobalDefine.EnemyState.CHASE)

# ---- 追踪：保持距离，不靠近 ----

func _ai_chase(delta: float) -> void:
	if not target or not is_instance_valid(target):
		_change_state(GlobalDefine.EnemyState.IDLE)
		_chase_dir = 0
		return

	if _post_attack_pause > 0:
		velocity.x = 0.0
		return

	var x_diff: float = target.global_position.x - global_position.x
	var dist: float = absf(x_diff)

	# 方向
	if absf(x_diff) > CHASE_DIR_THRESHOLD:
		_chase_dir = signf(x_diff)

	# 水平保持距离
	if dist < HOVER_MIN_DIST:
		# 太近，后退
		velocity.x = -_chase_dir * (config.move_speed if config else 100.0)
	elif dist > HOVER_MAX_DIST:
		# 太远，靠近一点
		if _chase_dir != 0:
			var speed: float = config.move_speed if config else 100.0
			velocity.x = _chase_dir * speed
	else:
		# 合适距离，减速悬停
		velocity.x = move_toward(velocity.x, 0, 300 * delta)

	# 悬停范围内且冷却完毕 → 发射火球
	if dist <= HOVER_MAX_DIST and attack_cooldown_timer <= 0:
		_change_state(GlobalDefine.EnemyState.ATTACK)
		return

	# 检测范围外则丢失
	if not _can_detect_target():
		_change_state(GlobalDefine.EnemyState.IDLE)
		_chase_dir = 0

# ---- 攻击：发射火球 ----

func _ai_attack(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0, 300 * delta)
	_fire_fireball()
	attack_cooldown_timer = config.attack_cooldown if config else 2.0
	_post_attack_pause = 0.7
	_change_state(GlobalDefine.EnemyState.CHASE)

# ---- 覆写攻击判定：用火球射程代替近战距离 ----

func _can_attack_target() -> bool:
	if not target or not is_instance_valid(target):
		return false
	var detect_range = config.detect_range if config else 300.0
	return global_position.distance_to(target.global_position) <= detect_range

# ---- 火球发射 ----

func _fire_fireball() -> void:
	if not target or not is_instance_valid(target):
		return

	var dir := (target.global_position - global_position).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2(is_facing_right, 0)

	var fireball = Area2D.new()
	fireball.set_script(load("res://Tools/FireballProjectile.gd"))
	var parent = get_parent()
	if parent:
		parent.add_child(fireball)
		fireball.global_position = global_position + dir * 20
		fireball.setup(dir, config.attack_damage if config else FIREBALL_DAMAGE, self, FIREBALL_MAX_DIST, FIREBALL_SPEED)

# ---- 无接触伤害 ----

func deals_contact_damage() -> bool:
	return false

# ---- 朝向 ----

func _update_facing() -> void:
	if stun_timer > 0:
		return
	if _is_attack_locked():
		return
	var should_face_right: bool = is_facing_right
	if target and is_instance_valid(target):
		var x_diff: float = target.global_position.x - global_position.x
		if x_diff > FACING_DEAD_ZONE:
			should_face_right = true
		elif x_diff < -FACING_DEAD_ZONE:
			should_face_right = false
	else:
		if velocity.x > 5:
			should_face_right = true
		elif velocity.x < -5:
			should_face_right = false
	is_facing_right = should_face_right
	if _anim_sprite:
		_anim_sprite.flip_h = not is_facing_right

# ---- 动画更新 ----

func _update_enemy_animation() -> void:
	if not _anim_sprite or not _anim_sprite.sprite_frames:
		return
	var target_anim: String = "idle"
	match current_state:
		GlobalDefine.EnemyState.IDLE:
			target_anim = "idle"
		GlobalDefine.EnemyState.PATROL:
			target_anim = "idle"
		GlobalDefine.EnemyState.CHASE:
			target_anim = "idle"
		GlobalDefine.EnemyState.ATTACK:
			target_anim = "attack"
		GlobalDefine.EnemyState.HURT, GlobalDefine.EnemyState.DEAD:
			target_anim = "idle"
	if _anim_sprite.animation != target_anim:
		_anim_sprite.play(target_anim)

# ---- 占位视觉 ----

func _get_placeholder_color() -> Color:
	return Color(1.0, 0.6, 0.2, 0.6)

func _get_placeholder_size() -> Vector2:
	return Vector2(40, 40)
