extends CharacterBody2D

## 近战敌人 —— 巡逻 / 索敌 / 蓄力冲撞 / 范围AOE / 受击 / 死亡
## 注意：此文件属于份C_敌人系统，通过场景文件加载，不使用 class_name 避免冲突

enum State { IDLE, PATROL, ALERT, CHASE, PREPARE_CHARGE, ATTACK_CHARGE, PREPARE_AOE, ATTACK_AOE, HURT, DEAD }
enum AttackType { CHARGE, AOE }

signal health_changed(current: int, max_hp: int)
signal enemy_died

# ---- 导出属性 ----
@export var max_health: int = 3
@export var gravity: float = 1200.0
@export var hurt_knockback: float = 250.0
@export var hurt_stun_duration: float = 0.35

# 巡逻
@export var patrol_speed: float = 60.0
@export var patrol_walk_time_min: float = 1.5
@export var patrol_walk_time_max: float = 4.0
@export var patrol_idle_time_min: float = 0.8
@export var patrol_idle_time_max: float = 2.5

# 索敌
@export var chase_speed: float = 150.0
@export var detection_range: float = 250.0
@export var lose_target_time: float = 4.0
@export var edge_check_distance: float = 45.0

# 蓄力冲撞
@export var charge_prepare_time: float = 0.7     # 前摇时间（较长）
@export var charge_dash_time: float = 0.35        # 冲撞判定时间
@export var charge_cooldown_time: float = 0.3     # 后摇时间
@export var charge_speed: float = 450.0
@export var charge_damage: int = 2
@export var charge_attack_range: float = 200.0    # 触发冲撞的距离

# 范围AOE
@export var aoe_prepare_time: float = 0.9         # 前摇时间（较长）
@export var aoe_active_time: float = 0.2          # 判定时间
@export var aoe_recover_time: float = 0.35        # 后摇
@export var aoe_radius: float = 70.0
@export var aoe_damage: int = 1
@export var aoe_attack_range: float = 55.0        # 触发AOE的距离

# 攻击通用
@export var attack_cooldown_min: float = 1.8
@export var attack_cooldown_max: float = 3.5
@export var charge_probability: float = 0.35      # 发动冲撞的概率

# ---- 运行时状态 ----
var current_state: State = State.IDLE
var health: int
var is_dead: bool = false
var facing_dir: int = -1  # 1=右, -1=左

# 计时器
var state_timer: float = 0.0
var attack_cooldown: float = 0.0
var lose_target_timer: float = 0.0
var patrol_is_walking: bool = true
var next_attack_type: AttackType = AttackType.AOE

# 玩家引用
var player_ref = null
var player_in_range: bool = false

# 攻击阶段: 0=前摇, 1=判定帧, 2=后摇
var attack_phase: int = 0
var attack_phase_timer: float = 0.0

# ---- 节点引用 ----
@onready var sprite: Sprite2D = $Sprite2D
@onready var detection_area: Area2D = $DetectionArea
@onready var attack_area: Area2D = $AttackArea
@onready var hurt_area: Area2D = $HurtArea
@onready var ground_ray: RayCast2D = $GroundCheck
@onready var wall_ray: RayCast2D = $WallCheck
@onready var aoe_indicator: Sprite2D = $AoeIndicator


func _ready() -> void:
	health = max_health
	add_to_group("enemy")

	# 配置检测区域信号
	if detection_area:
		detection_area.body_entered.connect(_on_detection_body_entered)
		detection_area.body_exited.connect(_on_detection_body_exited)

	# 受伤区域信号
	if hurt_area:
		hurt_area.area_entered.connect(_on_hurt_area_entered)

	# 攻击区域默认关闭
	if attack_area:
		attack_area.monitoring = false
		attack_area.body_entered.connect(_on_attack_hit)

	# AOE 指示器
	if aoe_indicator:
		aoe_indicator.visible = false

	_generate_sprite()
	_generate_aoe_indicator()
	_transition_to(State.PATROL)


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	# 攻击冷却
	if attack_cooldown > 0:
		attack_cooldown -= delta

	# 状态机
	match current_state:
		State.IDLE:
			_update_idle(delta)
		State.PATROL:
			_update_patrol(delta)
		State.ALERT:
			_update_alert(delta)
		State.CHASE:
			_update_chase(delta)
		State.PREPARE_CHARGE:
			_update_prepare_charge(delta)
		State.ATTACK_CHARGE:
			_update_attack_charge(delta)
		State.PREPARE_AOE:
			_update_prepare_aoe(delta)
		State.ATTACK_AOE:
			_update_attack_aoe(delta)
		State.HURT:
			_update_hurt(delta)

	# 重力（DEAD/ATTACK_CHARGE/HURT 状态各自特殊处理，此处排除）
	if not is_on_floor() and current_state not in [State.DEAD, State.ATTACK_CHARGE, State.HURT]:
		velocity.y += gravity * delta

	move_and_slide()

	# 掉出屏幕
	if global_position.y > 600:
		die()


# ============================================================
#  状态转换
# ============================================================

func _transition_to(st: State) -> void:
	if is_dead and st != State.DEAD:
		return
	if current_state == st:
		return
	_exit_state(current_state)
	current_state = st
	_enter_state(st)


func _enter_state(st: State) -> void:
	match st:
		State.IDLE:
			velocity.x = 0
			state_timer = randf_range(0.5, 1.5)
			sprite.modulate = Color(0.6, 0.6, 0.6, 1.0)
		State.PATROL:
			patrol_is_walking = true
			state_timer = randf_range(patrol_walk_time_min, patrol_walk_time_max)
			sprite.modulate = Color.WHITE
		State.ALERT:
			velocity.x = 0
			state_timer = 0.4
			sprite.modulate = Color.YELLOW
		State.CHASE:
			lose_target_timer = 0.0
			sprite.modulate = Color(1.0, 0.7, 0.5, 1.0)
		State.PREPARE_CHARGE:
			velocity.x = 0
			attack_phase = 0
			attack_phase_timer = charge_prepare_time
			sprite.modulate = Color.RED
			sprite.scale = Vector2(1.1, 0.95)
		State.ATTACK_CHARGE:
			attack_phase = 1
			attack_phase_timer = charge_dash_time
			velocity.x = facing_dir * charge_speed
			velocity.y = -60
			_enable_attack_hitbox()
			sprite.modulate = Color(1.0, 0.3, 0.2, 1.0)
		State.PREPARE_AOE:
			velocity.x = 0
			attack_phase = 0
			attack_phase_timer = aoe_prepare_time
			sprite.modulate = Color(1.0, 0.5, 0.0, 1.0)
			sprite.scale = Vector2(1.15, 0.85)
			if aoe_indicator:
				aoe_indicator.visible = true
				aoe_indicator.modulate.a = 0.0
				var tw := create_tween()
				tw.tween_property(aoe_indicator, "modulate:a", 0.6, aoe_prepare_time * 0.5)
		State.ATTACK_AOE:
			attack_phase = 1
			attack_phase_timer = aoe_active_time
			_enable_attack_hitbox()
			# 扩大攻击区域到AOE范围
			if attack_area:
				var shape := attack_area.get_node("CollisionShape2D") as CollisionShape2D
				if shape and shape.shape is CircleShape2D:
					shape.shape.radius = aoe_radius
			sprite.modulate = Color(1.0, 0.6, 0.0, 1.0)
			if aoe_indicator:
				aoe_indicator.modulate.a = 0.9
		State.HURT:
			state_timer = hurt_stun_duration
			sprite.modulate = Color.RED
			sprite.scale = Vector2.ONE
			if aoe_indicator:
				aoe_indicator.visible = false
		State.DEAD:
			is_dead = true
			velocity = Vector2.ZERO
			collision_layer = 0
			collision_mask = 0
			if detection_area: detection_area.monitoring = false
			if attack_area: attack_area.monitoring = false
			if hurt_area: hurt_area.monitoring = false
			if aoe_indicator: aoe_indicator.visible = false
			sprite.modulate = Color(0.3, 0.3, 0.3, 0.5)
			var tw := create_tween()
			tw.tween_property(sprite, "scale", Vector2(0.1, 0.1), 0.5)
			tw.parallel().tween_property(sprite, "modulate:a", 0.0, 0.5)
			tw.tween_callback(queue_free)


func _exit_state(st: State) -> void:
	match st:
		State.PREPARE_CHARGE, State.ATTACK_CHARGE, State.PREPARE_AOE, State.ATTACK_AOE:
			_disable_attack_hitbox()
			sprite.scale = Vector2.ONE
			if attack_area:
				var shape := attack_area.get_node("CollisionShape2D") as CollisionShape2D
				if shape and shape.shape is CircleShape2D:
					shape.shape.radius = 45.0  # 恢复默认


# ============================================================
#  各状态更新
# ============================================================

func _update_idle(delta: float) -> void:
	_check_player_detection()
	state_timer -= delta
	if state_timer <= 0:
		facing_dir *= -1
		_transition_to(State.PATROL)


func _update_patrol(delta: float) -> void:
	_check_player_detection()
	state_timer -= delta

	if state_timer <= 0:
		if patrol_is_walking:
			# 走路结束 → 停顿
			patrol_is_walking = false
			velocity.x = 0
			state_timer = randf_range(patrol_idle_time_min, patrol_idle_time_max)
			sprite.modulate = Color(0.6, 0.6, 0.6, 1.0)
		else:
			# 停顿结束 → 换方向继续走
			patrol_is_walking = true
			facing_dir *= -1
			state_timer = randf_range(patrol_walk_time_min, patrol_walk_time_max)
			sprite.modulate = Color.WHITE
		return

	if patrol_is_walking:
		velocity.x = move_toward(velocity.x, facing_dir * patrol_speed, patrol_speed * 3 * delta)
		_update_facing(facing_dir)

		# 撞墙回头
		if is_on_wall():
			facing_dir *= -1
			state_timer = randf_range(patrol_walk_time_min, patrol_walk_time_max)

		# 边缘检测
		if not _is_ground_ahead(facing_dir):
			facing_dir *= -1


func _update_alert(delta: float) -> void:
	state_timer -= delta
	if player_ref and is_instance_valid(player_ref):
		_face_player()
	if state_timer <= 0:
		_transition_to(State.CHASE)


func _update_chase(delta: float) -> void:
	if not player_ref or not is_instance_valid(player_ref):
		lose_target_timer += delta
		if lose_target_timer > lose_target_time:
			_transition_to(State.PATROL)
			lose_target_timer = 0
		return

	lose_target_timer = 0
	_face_player()

	var dist := global_position.distance_to(player_ref.global_position)
	var dir_to_player := signf(player_ref.global_position.x - global_position.x)

	# 视线检测
	var has_los := _has_line_of_sight()

	# 攻击判断（有冷却 + 有视线）
	if attack_cooldown <= 0 and has_los:
		if dist <= aoe_attack_range:
			# 近距离：AOE 为主，小概率冲撞
			if randf() < charge_probability and dist >= 30:
				next_attack_type = AttackType.CHARGE
				_transition_to(State.PREPARE_CHARGE)
			else:
				next_attack_type = AttackType.AOE
				_transition_to(State.PREPARE_AOE)
			return
		elif dist <= charge_attack_range:
			# 中距离：冲撞
			next_attack_type = AttackType.CHARGE
			_transition_to(State.PREPARE_CHARGE)
			return

	# 追逐移动
	var ideal_dist := 80.0
	if dist > ideal_dist + 30:
		velocity.x = move_toward(velocity.x, dir_to_player * chase_speed, chase_speed * 3 * delta)
	elif dist < ideal_dist - 30:
		velocity.x = move_toward(velocity.x, -dir_to_player * chase_speed * 0.6, chase_speed * 2 * delta)
	else:
		velocity.x = move_toward(velocity.x, 0, chase_speed * 3 * delta)

	# 边缘检测：前方无地面就停
	if not _is_ground_ahead(dir_to_player):
		velocity.x = 0


func _update_prepare_charge(delta: float) -> void:
	attack_phase_timer -= delta
	if player_ref and is_instance_valid(player_ref):
		_face_player()

	# 蓄力动画：压扁
	var progress := 1.0 - (attack_phase_timer / charge_prepare_time)
	sprite.scale = Vector2(1.0 + progress * 0.2, 1.0 - progress * 0.15)

	if attack_phase_timer <= 0:
		_transition_to(State.ATTACK_CHARGE)


func _update_attack_charge(delta: float) -> void:
	attack_phase_timer -= delta

	if attack_phase == 1:
		# 冲撞中
		if not is_on_floor():
			velocity.y += gravity * delta

		if attack_phase_timer <= 0:
			# 冲撞结束 → 后摇
			attack_phase = 2
			attack_phase_timer = charge_cooldown_time
			_disable_attack_hitbox()
			velocity.x = 0

	elif attack_phase == 2:
		velocity.x = move_toward(velocity.x, 0, charge_speed * 2 * delta)
		if attack_phase_timer <= 0:
			attack_cooldown = randf_range(attack_cooldown_min, attack_cooldown_max)
			_after_attack()


func _update_prepare_aoe(delta: float) -> void:
	attack_phase_timer -= delta
	if player_ref and is_instance_valid(player_ref):
		_face_player()

	var progress := 1.0 - (attack_phase_timer / aoe_prepare_time)
	sprite.scale = Vector2(1.0 + progress * 0.25, 1.0 - progress * 0.2)

	if attack_phase_timer <= 0:
		_transition_to(State.ATTACK_AOE)


func _update_attack_aoe(delta: float) -> void:
	attack_phase_timer -= delta

	if attack_phase == 1:
		if attack_phase_timer <= 0:
			attack_phase = 2
			attack_phase_timer = aoe_recover_time
			_disable_attack_hitbox()
			if aoe_indicator:
				aoe_indicator.visible = false

	elif attack_phase == 2:
		if attack_phase_timer <= 0:
			attack_cooldown = randf_range(attack_cooldown_min, attack_cooldown_max)
			_after_attack()


func _update_hurt(delta: float) -> void:
	state_timer -= delta
	if not is_on_floor():
		velocity.y += gravity * delta
	if state_timer <= 0 and (is_on_floor() or state_timer < -0.5):
		_on_hurt_end()


# ============================================================
#  攻击系统
# ============================================================

func _enable_attack_hitbox() -> void:
	if attack_area:
		attack_area.monitoring = true


func _disable_attack_hitbox() -> void:
	if attack_area:
		attack_area.monitoring = false


func _on_attack_hit(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("take_damage"):
		var dmg := charge_damage if next_attack_type == AttackType.CHARGE else aoe_damage
		var kb_dir := (body.global_position - global_position).normalized()
		body.take_damage(dmg, kb_dir)


func _after_attack() -> void:
	sprite.modulate = Color.WHITE
	sprite.scale = Vector2.ONE
	if aoe_indicator:
		aoe_indicator.visible = false
	if player_ref and is_instance_valid(player_ref):
		_transition_to(State.CHASE)
	else:
		_transition_to(State.PATROL)


# ============================================================
#  受击 / 死亡
# ============================================================

func _on_hurt_area_entered(area: Area2D) -> void:
	if is_dead or current_state == State.HURT:
		return
	# 玩家攻击判定：攻击区域碰撞层为4，敌人 HurtArea 检测层为4
	var parent := area.get_parent()
	if parent and parent.is_in_group("player"):
		take_damage(1, parent.global_position)


func _on_hurt_end() -> void:
	sprite.modulate = Color.WHITE
	sprite.scale = Vector2.ONE
	if player_ref and is_instance_valid(player_ref):
		_transition_to(State.CHASE)
	else:
		_transition_to(State.PATROL)


func take_damage(amount: int, attacker_pos: Vector2) -> void:
	if is_dead or current_state == State.DEAD:
		return

	health -= amount
	health_changed.emit(health, max_health)

	# 被打断攻击
	if current_state in [State.PREPARE_CHARGE, State.ATTACK_CHARGE, State.PREPARE_AOE, State.ATTACK_AOE]:
		_disable_attack_hitbox()
		sprite.scale = Vector2.ONE
		if aoe_indicator:
			aoe_indicator.visible = false

	if health <= 0:
		die()
		return

	# 受击硬直 + 击退
	var kb_dir := signf(global_position.x - attacker_pos.x)
	if kb_dir == 0:
		kb_dir = -facing_dir
	velocity.x = kb_dir * hurt_knockback
	velocity.y = -180

	_transition_to(State.HURT)

	var tw := create_tween()
	tw.tween_property(sprite, "modulate", Color.WHITE, 0.25).set_trans(Tween.TRANS_SINE)


func die() -> void:
	if is_dead:
		return
	_transition_to(State.DEAD)
	enemy_died.emit()


# ============================================================
#  检测系统
# ============================================================

func _check_player_detection() -> void:
	if not detection_area:
		return
	for body in detection_area.get_overlapping_bodies():
		if body.is_in_group("player") and is_instance_valid(body):
			player_ref = body
			player_in_range = true
			_transition_to(State.ALERT)
			return


func _on_detection_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and is_instance_valid(body):
		player_ref = body
		player_in_range = true
		if current_state in [State.IDLE, State.PATROL]:
			_transition_to(State.ALERT)


func _on_detection_body_exited(body: Node2D) -> void:
	if body == player_ref:
		player_in_range = false
		lose_target_timer = 0


func _has_line_of_sight() -> bool:
	if not player_ref or not is_instance_valid(player_ref):
		return false
	var space_state := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(global_position, player_ref.global_position)
	query.exclude = [self]
	var result := space_state.intersect_ray(query)
	if result.is_empty():
		return true
	return result.collider == player_ref


func _is_ground_ahead(dir: float) -> bool:
	if not ground_ray:
		return true
	var original := ground_ray.target_position
	ground_ray.target_position = Vector2(dir * edge_check_distance, 30)
	ground_ray.force_raycast_update()
	var hit := ground_ray.is_colliding()
	ground_ray.target_position = original
	return hit


func _update_facing(dir: int) -> void:
	if dir == 0:
		return
	facing_dir = dir
	sprite.scale.x = abs(sprite.scale.x) * dir


func _face_player() -> void:
	if player_ref and is_instance_valid(player_ref):
		var dir := signf(player_ref.global_position.x - global_position.x)
		if dir != 0:
			_update_facing(int(dir))


# ============================================================
#  精灵生成
# ============================================================

func _generate_sprite() -> void:
	var w := 32
	var h := 36
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)

	# 身体（椭圆红色）
	var cx := float(w) / 2
	var cy := float(h) / 2 + 2
	for x in range(w):
		for y in range(h):
			var dx := (x - cx) / (w / 2.5)
			var dy := (y - cy) / (h / 2.2)
			if dx * dx + dy * dy <= 1.0:
				# 身体渐变：上浅下深
				var t := float(y) / h
				img.set_pixel(x, y, Color(
					0.7 + t * 0.2,
					0.15 + t * 0.05,
					0.15,
					1.0
				))

	# 眼睛（黄色发光）
	var eye_y := int(cy) - 8
	# 左眼
	for dy in range(-3, 4):
		for dx in range(-3, 4):
			if dx * dx + dy * dy <= 9:
				img.set_pixel(int(cx) - 6 + dx, eye_y + dy, Color(1.0, 0.9, 0.3, 1.0))
	img.set_pixel(int(cx) - 6, eye_y, Color(0.1, 0.1, 0.1, 1.0))
	# 右眼
	for dy in range(-3, 4):
		for dx in range(-3, 4):
			if dx * dx + dy * dy <= 9:
				img.set_pixel(int(cx) + 6 + dx, eye_y + dy, Color(1.0, 0.9, 0.3, 1.0))
	img.set_pixel(int(cx) + 6, eye_y, Color(0.1, 0.1, 0.1, 1.0))

	# 角
	for y in range(0, 10):
		var x_off := 10 - y
		img.set_pixel(int(cx) - 10 - x_off, y, Color(0.5, 0.1, 0.1, 1.0))
		img.set_pixel(int(cx) + 10 + x_off, y, Color(0.5, 0.1, 0.1, 1.0))

	var tex := ImageTexture.create_from_image(img)
	sprite.texture = tex


func _generate_aoe_indicator() -> void:
	if not aoe_indicator:
		return
	var r := int(aoe_radius)
	var d := r * 2 + 4
	var img := Image.create(d, d, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for x in range(d):
		for y in range(d):
			var dx := x - r - 2
			var dy := y - r - 2
			var dist := sqrt(dx * dx + dy * dy)
			if dist >= r - 3 and dist <= r + 1:
				img.set_pixel(x, y, Color(1.0, 0.3, 0.1, 0.7))
			elif dist < r - 3:
				img.set_pixel(x, y, Color(1.0, 0.2, 0.1, 0.15))
	var tex := ImageTexture.create_from_image(img)
	aoe_indicator.texture = tex
	aoe_indicator.centered = true
	aoe_indicator.z_index = 5
