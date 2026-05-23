extends CharacterBody2D
class_name Enemy

## 敌人AI —— 缓慢巡逻，发现玩家后冲刺攻击

enum State { PATROL, CHASE, HURT, DEAD }

@export var patrol_speed: float = 60.0
@export var chase_speed: float = 200.0
@export var charge_speed: float = 400.0       # 首次冲刺速度
@export var charge_duration: float = 0.6       # 冲刺持续时间
@export var max_health: int = 3
@export var gravity: float = 1200.0
@export var detection_range: float = 250.0
@export var chase_duration: float = 2.0        # 追逐持续多久后回到巡逻
@export var hurt_knockback: float = 250.0

var health: int
var current_state: State = State.PATROL
var patrol_direction: int = -1                 # 初始向左巡逻
var chase_timer: float = 0.0
var hurt_timer: float = 0.0
var charge_timer: float = 0.0                  # 冲刺计时器
var player_ref: Player = null
var player_in_range: bool = false

@onready var sprite: Sprite2D = $Sprite2D
@onready var detection_area: Area2D = $DetectionArea
@onready var detection_collision: CollisionShape2D = $DetectionArea/CollisionShape2D
@onready var hurt_area: Area2D = $HurtArea


func _ready() -> void:
	health = max_health
	add_to_group("enemy")
	_generate_sprite_texture()

	# 设置检测范围
	if detection_collision and detection_collision.shape is CircleShape2D:
		detection_collision.shape.radius = detection_range

	# 连接信号
	detection_area.body_entered.connect(_on_detection_body_entered)
	detection_area.body_exited.connect(_on_detection_body_exited)
	hurt_area.area_entered.connect(_on_hurt_area_entered)


func _generate_sprite_texture() -> void:
	# 生成敌人精灵贴图（暗红色怪物）
	var img := Image.create(30, 36, false, Image.FORMAT_RGBA8)
	# 身体（椭圆形）
	for x in range(3, 27):
		for y in range(6, 32):
			var dx := float(x - 15) / 12.0
			var dy := float(y - 18) / 14.0
			if dx * dx + dy * dy <= 1.0:
				img.set_pixel(x, y, Color(0.75, 0.2, 0.2, 1.0))
	# 眼睛（发亮）
	for x in range(10, 13):
		for y in range(8, 12):
			img.set_pixel(x, y, Color(1.0, 0.9, 0.3, 1.0))
	for x in range(17, 20):
		for y in range(8, 12):
			img.set_pixel(x, y, Color(1.0, 0.9, 0.3, 1.0))
	# 角
	for y in range(0, 8):
		img.set_pixel(8, y, Color(0.6, 0.1, 0.1, 1.0))
		img.set_pixel(21, y, Color(0.6, 0.1, 0.1, 1.0))

	var tex := ImageTexture.create_from_image(img)
	sprite.texture = tex


func _physics_process(delta: float) -> void:
	if current_state == State.DEAD:
		return

	# 受伤硬直
	if current_state == State.HURT:
		hurt_timer -= delta
		if not is_on_floor():
			velocity.y += gravity * delta
		if hurt_timer <= 0:
			current_state = State.CHASE if player_in_range else State.PATROL
			chase_timer = chase_duration
		move_and_slide()
		return

	# 重力
	if not is_on_floor():
		velocity.y += gravity * delta

	match current_state:
		State.PATROL:
			_patrol_behavior(delta)
		State.CHASE:
			_chase_behavior(delta)

	move_and_slide()

	# 防止掉出屏幕自动移除
	if global_position.y > 600:
		queue_free()


func _patrol_behavior(_delta: float) -> void:
	velocity.x = patrol_direction * patrol_speed
	sprite.flip_h = patrol_direction > 0
	sprite.modulate = Color.WHITE  # 巡逻时正常颜色

	# 碰到墙或边缘就回头
	if is_on_wall():
		patrol_direction *= -1


func _chase_behavior(delta: float) -> void:
	chase_timer -= delta

	# 追逐超时后若无玩家则回巡逻
	if chase_timer <= 0 and not player_in_range:
		current_state = State.PATROL
		return

	# 重置追逐计时（如果玩家还在范围内）
	if player_in_range:
		chase_timer = chase_duration

	# 冲向玩家
	if player_ref and is_instance_valid(player_ref):
		var dir := signf(player_ref.global_position.x - global_position.x)
		
		# 冲刺阶段使用高速
		var speed := charge_speed if charge_timer > 0 else chase_speed
		if charge_timer > 0:
			charge_timer -= delta
		
		velocity.x = dir * speed
		sprite.flip_h = dir > 0
		
		# 冲刺时眼睛变亮
		if charge_timer > 0:
			sprite.modulate = Color(1.3, 0.8, 0.8, 1.0)
		else:
			sprite.modulate = Color(1.15, 0.85, 0.85, 1.0)
	else:
		# 玩家引用失效，回巡逻
		player_in_range = false
		current_state = State.PATROL


func _on_detection_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = true
		player_ref = body as Player
		if current_state == State.PATROL:
			current_state = State.CHASE
			chase_timer = chase_duration
			charge_timer = charge_duration  # 首次发现玩家时冲刺


func _on_detection_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = false
		# 不要立即切换状态，让追逐持续到计时结束


func _on_hurt_area_entered(area: Area2D) -> void:
	# 检测是否是玩家的攻击区域
	if area.get_parent() is Player:
		var player := area.get_parent() as Player
		if player.is_attacking:
			_take_damage(1, player.global_position)


func _take_damage(amount: int, attacker_pos: Vector2) -> void:
	health -= amount
	print("敌人受伤! 剩余血量: ", health)

	if health <= 0:
		_die()
		return

	# 受伤硬直 + 击退
	current_state = State.HURT
	hurt_timer = 0.35

	var kb_dir := signf(global_position.x - attacker_pos.x)
	velocity.x = kb_dir * hurt_knockback
	velocity.y = -200

	# 受伤闪烁
	sprite.modulate = Color.RED
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.3)


func _die() -> void:
	current_state = State.DEAD
	print("敌人死亡!")

	# 死亡动画效果
	sprite.modulate = Color(0.3, 0.3, 0.3, 0.5)
	var tween := create_tween()
	tween.tween_property(sprite, "modulate:a", 0.0, 0.4)

	# 禁用碰撞和检测
	collision_layer = 0
	collision_mask = 0
	detection_area.monitoring = false
	hurt_area.monitoring = false
	set_physics_process(false)

	# 延迟移除
	tween.tween_callback(queue_free).set_delay(0.4)
