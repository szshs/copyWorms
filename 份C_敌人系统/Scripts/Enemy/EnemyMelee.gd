extends CharacterBody2D
class_name EnemyMelee

## 近战敌人 —— 巡逻防掉落 + 追逐 + 受伤 + 死亡（单文件版本）

enum State { PATROL, CHASE, ATTACK, HURT, DEAD }

signal health_changed(current: int, max_hp: int)
signal enemy_died

# ---- 导出属性 ----
@export var max_health: int = 3
@export var gravity: float = 1200.0
@export var hurt_knockback: float = 250.0
@export var hurt_stun_duration: float = 0.35

@export var patrol_speed: float = 60.0
@export var chase_speed: float = 200.0
@export var charge_speed: float = 400.0
@export var charge_duration: float = 0.6
@export var chase_duration: float = 2.0
@export var detection_range: float = 250.0
@export var edge_check_distance: float = 40.0

# ---- 运行时状态 ----
var current_state: State = State.PATROL
var health: int
var is_dead: bool = false
var is_hurt: bool = false
var hurt_timer: float = 0.0

# 巡逻
var patrol_dir: int = -1

# 追逐
var player_ref = null
var player_in_range: bool = false
var chase_timer: float = 0.0
var charge_timer: float = 0.0

# ---- 节点引用 ----
@onready var sprite: Sprite2D = $Sprite2D
@onready var hurt_area: Area2D = $HurtArea
@onready var detection_area: Area2D = $DetectionArea
@onready var detection_collision: CollisionShape2D = $DetectionArea/CollisionShape2D


func _ready() -> void:
	health = max_health
	add_to_group("enemy")

	# 配置检测区域
	if detection_collision and detection_collision.shape is CircleShape2D:
		detection_collision.shape.radius = detection_range

	# 受伤区域信号
	if hurt_area:
		hurt_area.area_entered.connect(_on_hurt_area_entered)

	# 检测区域信号
	if detection_area:
		detection_area.body_entered.connect(_on_detection_body_entered)
		detection_area.body_exited.connect(_on_detection_body_exited)

	_generate_sprite()


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	# 受伤硬直
	if is_hurt:
		hurt_timer -= delta
		if not is_on_floor():
			velocity.y += gravity * delta
		if hurt_timer <= 0:
			is_hurt = false
			_on_hurt_end()
		move_and_slide()
		return

	# 重力
	if not is_on_floor():
		velocity.y += gravity * delta

	# 状态行为
	match current_state:
		State.PATROL:
			_update_patrol(delta)
		State.CHASE:
			_update_chase(delta)
		State.ATTACK:
			pass
		State.HURT:
			pass

	move_and_slide()

	# 掉出屏幕
	if global_position.y > 600:
		queue_free()


# ==================== 巡逻 ====================
func _update_patrol(_delta: float) -> void:
	velocity.x = patrol_dir * patrol_speed
	sprite.flip_h = patrol_dir > 0

	# 撞墙回头
	if is_on_wall():
		patrol_dir *= -1
		return

	# 边缘检测 —— 前方没有地面就回头
	if not is_ground_ahead(patrol_dir):
		patrol_dir *= -1


# ==================== 追逐 ====================
func _update_chase(delta: float) -> void:
	chase_timer -= delta

	# 超时且玩家不在范围 → 回巡逻
	if chase_timer <= 0 and not player_in_range:
		_transition_to(State.PATROL)
		return

	if player_in_range:
		chase_timer = chase_duration

	if player_ref and is_instance_valid(player_ref):
		var dir := signf(player_ref.global_position.x - global_position.x)

		# 边缘检测
		if not is_ground_ahead(dir):
			_transition_to(State.PATROL)
			return

		var spd := charge_speed if charge_timer > 0 else chase_speed
		if charge_timer > 0:
			charge_timer -= delta

		velocity.x = dir * spd
		sprite.flip_h = dir > 0

		# 视觉反馈
		sprite.modulate = Color(1.3, 0.8, 0.8, 1.0) if charge_timer > 0 else Color(1.15, 0.85, 0.85, 1.0)
	else:
		player_in_range = false
		_transition_to(State.PATROL)


# ==================== 边缘检测 ====================
func is_ground_ahead(direction: float) -> bool:
	var space_state := get_world_2d().direct_space_state
	var check_pos := global_position + Vector2(direction * edge_check_distance, 0)
	var from := check_pos + Vector2(0, -10)
	var to := check_pos + Vector2(0, 50)
	var query := PhysicsRayQueryParameters2D.create(from, to)
	query.collision_mask = 1
	var result := space_state.intersect_ray(query)
	return not result.is_empty()


# ==================== 状态切换 ====================
func _transition_to(new_state: State) -> void:
	if new_state == current_state:
		return
	current_state = new_state
	match new_state:
		State.CHASE:
			charge_timer = charge_duration
		State.PATROL:
			sprite.modulate = Color.WHITE


# ==================== 检测区域信号 ====================
func _on_detection_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_ref = body
		player_in_range = true
		chase_timer = chase_duration
		if current_state == State.PATROL:
			_transition_to(State.CHASE)


func _on_detection_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = false


# ==================== 受伤 ====================
func _on_hurt_area_entered(area: Area2D) -> void:
	if is_dead or is_hurt:
		return
	if area.get_parent().has_method("_perform_attack") or area.get_parent().is_in_group("player"):
		take_damage(1, area.get_parent().global_position)


func _on_hurt_end() -> void:
	if player_in_range:
		_transition_to(State.CHASE)
	else:
		_transition_to(State.PATROL)


func take_damage(amount: int, attacker_pos: Vector2) -> void:
	if is_dead:
		return

	health -= amount
	health_changed.emit(health, max_health)

	if health <= 0:
		die()
		return

	is_hurt = true
	hurt_timer = hurt_stun_duration

	var kb_dir := signf(global_position.x - attacker_pos.x)
	velocity.x = kb_dir * hurt_knockback
	velocity.y = -200

	sprite.modulate = Color.RED
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.3)


func die() -> void:
	if is_dead:
		return
	is_dead = true
	enemy_died.emit()

	sprite.modulate = Color(0.3, 0.3, 0.3, 0.5)
	var tween := create_tween()
	tween.tween_property(sprite, "modulate:a", 0.0, 0.4)

	collision_layer = 0
	collision_mask = 0
	set_physics_process(false)

	tween.tween_callback(queue_free).set_delay(0.4)


# ==================== 精灵生成 ====================
func _generate_sprite() -> void:
	var img := Image.create(30, 36, false, Image.FORMAT_RGBA8)
	for x in range(3, 27):
		for y in range(6, 32):
			var dx := float(x - 15) / 12.0
			var dy := float(y - 18) / 14.0
			if dx * dx + dy * dy <= 1.0:
				img.set_pixel(x, y, Color(0.75, 0.2, 0.2, 1.0))
	for x in range(10, 13):
		for y in range(8, 12):
			img.set_pixel(x, y, Color(1.0, 0.9, 0.3, 1.0))
	for x in range(17, 20):
		for y in range(8, 12):
			img.set_pixel(x, y, Color(1.0, 0.9, 0.3, 1.0))
	for y in range(0, 8):
		img.set_pixel(8, y, Color(0.6, 0.1, 0.1, 1.0))
		img.set_pixel(21, y, Color(0.6, 0.1, 0.1, 1.0))
	var tex := ImageTexture.create_from_image(img)
	sprite.texture = tex
