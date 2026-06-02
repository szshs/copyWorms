extends CharacterBody2D
class_name EnemyBase

## 敌人基类 —— 管理生命值、碰撞、信号，供子类复用

signal health_changed(current: int, max_hp: int)
signal enemy_died

@export var max_health: int = 3
@export var gravity: float = 1200.0
@export var hurt_knockback: float = 250.0
@export var hurt_stun_duration: float = 0.35

var health: int
var is_dead: bool = false
var is_hurt: bool = false
var hurt_timer: float = 0.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var hurt_area: Area2D = $HurtArea


func _ready() -> void:
	health = max_health
	add_to_group("enemy")
	_setup_hurt_area()
	_generate_default_sprite()
	_setup_extra()


func _setup_hurt_area() -> void:
	if hurt_area:
		hurt_area.area_entered.connect(_on_hurt_area_entered)


## 子类重写此方法做额外初始化
func _setup_extra() -> void:
	pass


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

	# 调用子类的行为逻辑
	_update_behavior(delta)

	move_and_slide()

	# 掉出屏幕自动移除
	if global_position.y > 600:
		queue_free()


## 子类重写此方法实现行为
func _update_behavior(_delta: float) -> void:
	pass


## 受伤结束回调
func _on_hurt_end() -> void:
	pass


## 边缘检测 —— 在前方检测地面是否存在
## 返回 true 表示前方安全，false 表示前方是悬崖/空隙
func is_ground_ahead(direction: float, distance: float = 40.0) -> bool:
	var space_state := get_world_2d().direct_space_state
	var check_pos := global_position + Vector2(direction * 20, 0)
	var from := check_pos + Vector2(0, -10)
	var to := check_pos + Vector2(0, 50)
	var query := PhysicsRayQueryParameters2D.create(from, to)
	query.collision_mask = 1  # 只检测地面/平台层
	var result := space_state.intersect_ray(query)
	return not result.is_empty()


## 墙壁检测
func is_wall_ahead(direction: float) -> bool:
	return is_on_wall()


func _on_hurt_area_entered(area: Area2D) -> void:
	if is_dead or is_hurt:
		return
	# 检查是否是玩家攻击
	if area.get_parent() is Player:
		var player := area.get_parent() as Player
		if player.is_attacking:
			take_damage(1, player.global_position)


func take_damage(amount: int, attacker_pos: Vector2) -> void:
	if is_dead:
		return

	health -= amount
	health_changed.emit(health, max_health)

	if health <= 0:
		die()
		return

	# 受伤硬直 + 击退
	is_hurt = true
	hurt_timer = hurt_stun_duration

	var kb_dir := signf(global_position.x - attacker_pos.x)
	velocity.x = kb_dir * hurt_knockback
	velocity.y = -200

	# 闪烁效果
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


func _generate_default_sprite() -> void:
	# 默认暗红色怪物贴图（可被子类覆盖）
	var img := Image.create(30, 36, false, Image.FORMAT_RGBA8)
	for x in range(3, 27):
		for y in range(6, 32):
			var dx := float(x - 15) / 12.0
			var dy := float(y - 18) / 14.0
			if dx * dx + dy * dy <= 1.0:
				img.set_pixel(x, y, Color(0.75, 0.2, 0.2, 1.0))
	# 眼睛
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
