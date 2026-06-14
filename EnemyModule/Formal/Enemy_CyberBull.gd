# ============================================================
# Enemy_CyberBull.gd - 赛博冲撞兽
# 行为：发现玩家→追踪→靠近后冲撞攻击→冲撞结束短暂眩晕→再次追踪
# 冲撞期间接触玩家造成伤害，非冲撞状态无接触伤害
# ============================================================
extends EnemyBase
class_name Enemy_CyberBull

var _anim_sprite: AnimatedSprite2D = null

# ---- 冲撞系统 ----
var _is_winding_up: bool = false      # 冲撞前摇中
var _is_charging: bool = false        # 冲撞冲刺中
var _is_recovering: bool = false      # 冲撞后眩晕中
var _charge_dir: int = 0              # 冲撞锁定方向
var _charge_timer: float = 0.0        # 当前阶段计时
var _charge_hit: bool = false         # 本次冲撞是否已命中

const WINDUP_DURATION: float = 0.35   # 前摇时长
const CHARGE_SPEED: float = 550.0     # 冲撞速度
const CHARGE_DURATION: float = 0.4    # 冲撞持续时长
const CHARGE_RANGE: float = 180.0     # 冲撞触发距离（比普通攻击范围大）
const RECOVERY_DURATION: float = 0.8  # 冲撞后眩晕时长
const CHARGE_COOLDOWN: float = 2.5    # 冲撞冷却

# 追踪方向滞后
var _chase_dir: int = 0
const CHASE_DIR_THRESHOLD: float = 8.0

# 不可达检测
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
		config = load("res://DataConfig/Enemy/CyberBullConfig.tres") as EnemyConfig
		_apply_config()
	_init_anim_sprite()
	_adjust_collision_position()
	is_facing_right = patrol_direction > 0
	if _anim_sprite:
		_anim_sprite.flip_h = not is_facing_right

# 碰撞体：宽矮体型（冲撞兽更宽更矮）
func _get_collision_size() -> Vector2:
	return Vector2(48, 44)

func _adjust_collision_position() -> void:
	var col = get_node_or_null("CollisionShape")
	if col:
		col.position = Vector2(0, -4)

func _init_anim_sprite() -> void:
	_anim_sprite = get_node_or_null("Sprite") as AnimatedSprite2D
	if _anim_sprite:
		_anim_sprite.play("idle")
		_anim_sprite.offset = Vector2(0, -12)
	var old = get_node_or_null("PlaceholderSprite")
	if old:
		old.queue_free()
	var blink = get_node_or_null("LowHPBlink")
	if blink:
		blink.queue_free()

# ---- 冲撞状态判定 ----

func _is_charge_active() -> bool:
	return _is_winding_up or _is_charging or _is_recovering

# ---- 接触伤害：仅冲撞期间 ----

func deals_contact_damage() -> bool:
	return _is_charging

# ---- AI 拦截 ----

func _handle_ai(delta: float) -> void:
	# 冲撞阶段完全接管
	if _is_charge_active():
		_post_attack_pause = 0.0
		_handle_charge(delta)
		return
	super._handle_ai(delta)

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

	if _post_attack_pause > 0:
		velocity.x = move_toward(velocity.x, 0, 400 * delta)
		return

	var x_diff: float = target.global_position.x - global_position.x
	var y_diff: float = target.global_position.y - global_position.y
	var dist: float = global_position.distance_to(target.global_position)
	var attack_range: float = config.attack_range if config else 60.0

	# 不可达检测
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

	# 方向滞后
	if abs(x_diff) > CHASE_DIR_THRESHOLD:
		_chase_dir = signf(x_diff)

	# 在冲撞范围内且冷却完毕 → 减速并启动冲撞
	if dist <= CHARGE_RANGE and attack_cooldown_timer <= 0:
		velocity.x = move_toward(velocity.x, 0, 300 * delta)
		_start_charge()
		return
	# 其余情况正常追踪（冲撞冷却中或距离外，不要减速）
	if _chase_dir != 0:
		var speed: float = config.move_speed if config else 100.0
		var multiplier: float = config.chase_speed_multiplier if config else 1.8
		velocity.x = _chase_dir * speed * multiplier
	else:
		velocity.x = move_toward(velocity.x, 0, 300 * delta)

	if not _can_detect_target():
		_change_state(GlobalDefine.EnemyState.IDLE)
		_chase_dir = 0

# ---- 攻击：直接启动冲撞 ----

func _ai_attack(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0, 300 * delta)
	# 冲撞由 _ai_chase 中 _start_charge 触发，不应进入 ATTACK 状态
	_change_state(GlobalDefine.EnemyState.CHASE)

# ---- 冲撞系统 ----

func _start_charge() -> void:
	_is_winding_up = true
	_is_charging = false
	_is_recovering = false
	_charge_timer = WINDUP_DURATION
	_charge_hit = false
	# 锁定冲撞方向为玩家当前方向
	if target and is_instance_valid(target):
		_charge_dir = signf(target.global_position.x - global_position.x)
		if _charge_dir == 0:
			_charge_dir = 1 if is_facing_right else -1
	else:
		_charge_dir = 1 if is_facing_right else -1
	# 立即面朝冲撞方向
	is_facing_right = _charge_dir > 0
	if _anim_sprite:
		_anim_sprite.flip_h = not is_facing_right
	attack_cooldown_timer = CHARGE_COOLDOWN

func _handle_charge(delta: float) -> void:
	if _is_winding_up:
		_charge_timer -= delta
		velocity.x = move_toward(velocity.x, 0, 300 * delta)
		# 前摇期间面朝冲撞方向
		is_facing_right = _charge_dir > 0
		if _anim_sprite:
			_anim_sprite.flip_h = not is_facing_right
		if _charge_timer <= 0:
			_is_winding_up = false
			_is_charging = true
			_charge_timer = CHARGE_DURATION
	elif _is_charging:
		_charge_timer -= delta
		velocity.x = _charge_dir * CHARGE_SPEED
		# 冲撞中持续检测碰撞伤害
		_check_charge_hit()
		if _charge_timer <= 0:
			_is_charging = false
			_is_recovering = true
			_charge_timer = RECOVERY_DURATION
			velocity.x = move_toward(velocity.x, 0, 300 * delta)
	elif _is_recovering:
		_charge_timer -= delta
		velocity.x = move_toward(velocity.x, 0, 300 * delta)
		if _charge_timer <= 0:
			_is_recovering = false
			_change_state(GlobalDefine.EnemyState.CHASE)

# ---- 冲撞碰撞检测 ----

func _check_charge_hit() -> void:
	if _charge_hit:
		return
	if not target or not is_instance_valid(target):
		return
	var es = _get_collision_size()
	var my_rect = Rect2(global_position - es / 2, es)
	var ps = Vector2(36, 36)
	if target.has_method("_get_collision_size"):
		ps = target._get_collision_size()
	var player_rect = Rect2(target.global_position - ps / 2, ps)
	if my_rect.intersects(player_rect):
		_charge_hit = true
		_do_charge_damage()

func _do_charge_damage() -> void:
	if not target or not is_instance_valid(target):
		return
	if target.has_method("take_damage"):
		var atk = config.attack_damage if config else 12
		var result = DamageCalculator.calculate(atk, 0, GlobalDefine.DamageType.PHYSICAL)
		var kb_dir = DamageCalculator.get_knockback_direction(global_position, target.global_position)
		target.take_damage(result["damage"], kb_dir)

# ---- 基类攻击回调 ----

func _on_attack() -> void:
	_start_charge()
	_post_attack_pause = 0.0

# ---- 核心行为逻辑 ----

func _on_physics_process(delta: float) -> void:
	if _lose_interest_timer > 0:
		_lose_interest_timer -= delta
	_update_enemy_animation()

# ---- 朝向：flip_h + 死区 + 速度回退 ----

func _update_facing() -> void:
	if stun_timer > 0:
		return
	# 冲撞期间方向已锁定，不更新朝向
	if _is_charge_active():
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
	# 冲撞阶段
	if _is_charging:
		if _anim_sprite.animation != "attack":
			_anim_sprite.play("attack")
		return
	if _is_winding_up:
		if _anim_sprite.animation != "attack":
			_anim_sprite.play("attack")
		return
	# 正常状态
	var target_anim: String = "idle"
	if _is_recovering:
		target_anim = "idle"
	else:
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

# ---- 占位视觉（fallback） ----

func _get_placeholder_color() -> Color:
	return Color(0.8, 0.5, 0.2, 0.6)

func _get_placeholder_size() -> Vector2:
	return Vector2(48, 44)
