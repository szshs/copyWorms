# ============================================================
# Enemy_PaperEffigy.gd - 岭南怪物「纸符人」
# 行为：发现玩家→追踪→靠近后连续攻击2次→原地静止1秒→再次追踪
# 只有主动攻击造成伤害，触碰玩家不造成伤害
# 逻辑与赛博狼人完全一致
# ============================================================
extends EnemyBase
class_name Enemy_PaperEffigy

var _anim_sprite: AnimatedSprite2D = null
var _attack_anim_timer: float = 0.0
const ATTACK_ANIM_DURATION: float = 0.4

# 连击系统
var _combo_count: int = 0
var _combo_timer: float = 0.0
var _rest_timer: float = 0.0
const COMBO_PAUSE: float = 0.5
const REST_DURATION: float = 1.0

# 前摇系统
var _windup_timer: float = 0.0
var _pending_hit: int = 0
const WINDUP_DURATION: float = 0.15

# 追踪方向滞后
var _chase_dir: int = 0
const CHASE_DIR_THRESHOLD: float = 8.0

# 不可达检测：玩家在高处时停下
var _unreachable_timer: float = 0.0
var _lose_interest_timer: float = 0.0
const UNREACHABLE_TIME: float = 1.5
const LOSE_INTEREST_TIME: float = 3.0
const HEIGHT_UNREACHABLE: float = -40.0

# 朝向死区
const FACING_DEAD_ZONE: float = 5.0

func _on_ready() -> void:
	super._on_ready()
	if not config:
		config = load("res://DataConfig/Enemy/PaperEffigyConfig.tres") as EnemyConfig
		_apply_config()
	_init_anim_sprite()
	_adjust_collision_position()
	is_facing_right = patrol_direction > 0
	if _anim_sprite:
		_anim_sprite.flip_h = not is_facing_right

func _get_collision_size() -> Vector2:
	return Vector2(36, 60)

func _adjust_collision_position() -> void:
	var col = get_node_or_null("CollisionShape")
	if col:
		col.position = Vector2(0, -12)

func _init_anim_sprite() -> void:
	_anim_sprite = get_node_or_null("Sprite") as AnimatedSprite2D
	if _anim_sprite:
		_anim_sprite.play("idle")
		_anim_sprite.offset = Vector2(0, -24)
	var old = get_node_or_null("PlaceholderSprite")
	if old:
		old.queue_free()
	var blink = get_node_or_null("LowHPBlink")
	if blink:
		blink.queue_free()

# ---- AI 拦截 ----

func _handle_ai(delta: float) -> void:
	if _is_combo_active():
		_post_attack_pause = 0.0
		velocity.x = move_toward(velocity.x, 0, 300 * delta)
		return
	super._handle_ai(delta)

func _is_combo_active() -> bool:
	return _windup_timer > 0 or _combo_timer > 0 or _rest_timer > 0

# ---- 攻击锁定：前摇/连击/休息期间禁止移动与转向 ----

func _is_attack_locked() -> bool:
	return super._is_attack_locked() or _is_combo_active()

# ---- 追踪检测覆写 ----

func _can_detect_target() -> bool:
	if _lose_interest_timer > 0:
		return false
	return super._can_detect_target()

# ---- 追踪 ----

func _ai_chase(delta: float) -> void:
	if not target or not is_instance_valid(target):
		_change_state(GlobalDefine.EnemyState.IDLE)
		_chase_dir = 0
		_unreachable_timer = 0.0
		return

	if _is_attack_locked():
		velocity.x = 0.0
		return

	var x_diff: float = target.global_position.x - global_position.x
	var y_diff: float = target.global_position.y - global_position.y
	var dist: float = global_position.distance_to(target.global_position)
	var attack_range: float = config.attack_range if config else 40.0

	if y_diff < HEIGHT_UNREACHABLE:
		_unreachable_timer += delta
		velocity.x = move_toward(velocity.x, 0, 300 * delta)
		_chase_dir = 0
		if _unreachable_timer >= UNREACHABLE_TIME:
			_lose_interest_timer = LOSE_INTEREST_TIME
			_unreachable_timer = 0.0
			_change_state(GlobalDefine.EnemyState.IDLE)
		return

	_unreachable_timer = 0.0

	if abs(x_diff) > CHASE_DIR_THRESHOLD:
		_chase_dir = signf(x_diff)

	if dist <= attack_range:
		velocity.x = move_toward(velocity.x, 0, 300 * delta)
		if _can_attack_target():
			_change_state(GlobalDefine.EnemyState.ATTACK)
			return
	else:
		if _chase_dir != 0:
			var speed: float = config.move_speed if config else 100.0
			var multiplier: float = config.chase_speed_multiplier if config else 1.8
			velocity.x = _chase_dir * speed * multiplier
		else:
			velocity.x = move_toward(velocity.x, 0, 300 * delta)

	if not _can_detect_target():
		_change_state(GlobalDefine.EnemyState.IDLE)
		_chase_dir = 0

# ---- 攻击 ----

func _ai_attack(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0, 300 * delta)
	if attack_cooldown_timer <= 0 and target and is_instance_valid(target):
		_perform_attack()
		attack_cooldown_timer = config.attack_cooldown if config else 1.5
	_change_state(GlobalDefine.EnemyState.CHASE)

# ---- 核心行为逻辑 ----

func _on_physics_process(delta: float) -> void:
	if _lose_interest_timer > 0:
		_lose_interest_timer -= delta

	# 1) 连击后休息
	if _rest_timer > 0:
		_rest_timer -= delta
		velocity.x = move_toward(velocity.x, 0, 300 * delta)
		if current_state != GlobalDefine.EnemyState.IDLE:
			_change_state(GlobalDefine.EnemyState.IDLE)
		_attack_anim_timer = 0.0
		_update_enemy_animation()
		if _rest_timer <= 0:
			_combo_count = 0
		return

	# 2) 前摇
	if _windup_timer > 0:
		_windup_timer -= delta
		velocity.x = move_toward(velocity.x, 0, 300 * delta)
		_update_enemy_animation()
		if _windup_timer <= 0:
			_do_attack_hit()
			if _pending_hit == 1:
				_combo_count = 1
				_combo_timer = COMBO_PAUSE
			elif _pending_hit == 2:
				_combo_count = 2
				_rest_timer = REST_DURATION
			_pending_hit = 0
		return

	# 3) 连击间隔
	if _combo_timer > 0:
		_combo_timer -= delta
		velocity.x = move_toward(velocity.x, 0, 300 * delta)
		if _combo_timer <= 0 and _combo_count == 1:
			_start_windup(2)
		_update_enemy_animation()
		return

	# 4) 正常追踪时重置连击计数
	if _combo_count > 0 and current_state == GlobalDefine.EnemyState.CHASE and _post_attack_pause <= 0:
		_combo_count = 0

	if _attack_anim_timer > 0:
		_attack_anim_timer -= delta
	_update_enemy_animation()

# ---- 基类攻击回调 ----

func _on_attack() -> void:
	_start_windup(1)
	_post_attack_pause = 0.0

func _start_windup(hit_number: int) -> void:
	_pending_hit = hit_number
	_windup_timer = WINDUP_DURATION
	_attack_anim_timer = ATTACK_ANIM_DURATION

func _do_attack_hit() -> void:
	_attack_anim_timer = ATTACK_ANIM_DURATION
	if not target or not is_instance_valid(target):
		return
	# 攻击命中前检查距离：玩家闪避/突进拉开距离则攻击落空
	var dist = global_position.distance_to(target.global_position)
	var attack_range = config.attack_range if config else 40.0
	if dist > attack_range + 30.0:
		return
	if target.has_method("take_damage"):
		var atk = config.attack_damage if config else 8
		var result = DamageCalculator.calculate(atk, 0, GlobalDefine.DamageType.PHYSICAL)
		var kb_dir = DamageCalculator.get_knockback_direction(global_position, target.global_position)
		target.take_damage(result["damage"], kb_dir)

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
		elif abs(velocity.x) > 10:
			should_face_right = velocity.x > 0
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
	if _attack_anim_timer > 0:
		if _anim_sprite.animation != "attack":
			_anim_sprite.play("attack")
		return
	var target_anim: String = "idle"
	match current_state:
		GlobalDefine.EnemyState.IDLE:
			target_anim = "idle"
		GlobalDefine.EnemyState.PATROL:
			target_anim = "walk"
		GlobalDefine.EnemyState.CHASE:
			target_anim = "walk" if abs(velocity.x) > 10 else "idle"
		GlobalDefine.EnemyState.ATTACK:
			target_anim = "attack"
		GlobalDefine.EnemyState.HURT, GlobalDefine.EnemyState.DEAD:
			target_anim = "idle"
	if _anim_sprite.animation != target_anim:
		_anim_sprite.play(target_anim)

# ---- 占位视觉 ----

func _get_placeholder_color() -> Color:
	return Color(0.9, 0.9, 0.85, 0.6)

func _get_placeholder_size() -> Vector2:
	return Vector2(44, 44)
