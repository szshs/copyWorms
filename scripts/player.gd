extends CharacterBody2D
class_name Player

## 玩家控制器 —— WASD移动、空格跳跃、鼠标左键攻击

signal health_changed(new_health: int, max_hp: int)
signal player_died

@export var speed: float = 300.0
@export var jump_velocity: float = -520.0
@export var gravity: float = 1200.0
@export var max_health: int = 5
@export var attack_cooldown: float = 0.35
@export var attack_duration: float = 0.15
@export var knockback_force: float = 300.0

var health: int
var attack_timer: float = 0.0
var facing_right: bool = true
var is_attacking: bool = false
var invincible_timer: float = 0.0
var invincible_duration: float = 0.8
var is_dead: bool = false

@onready var sprite: Sprite2D = $Sprite2D
@onready var attack_area: Area2D = $AttackArea
@onready var attack_collision: CollisionShape2D = $AttackArea/CollisionShape2D
@onready var hurt_area: Area2D = $HurtArea
@onready var slash_sprite: Sprite2D = $SlashSprite


func _ready() -> void:
	health = max_health
	add_to_group("player")
	attack_area.monitoring = false
	hurt_area.body_entered.connect(_on_enemy_contact)
	_generate_sprite_texture()
	_generate_slash_texture()
	slash_sprite.visible = false


func _generate_sprite_texture() -> void:
	# 生成一个简单的角色精灵贴图（蓝色战士）
	var img := Image.create(32, 44, false, Image.FORMAT_RGBA8)
	# 身体
	for x in range(4, 28):
		for y in range(8, 40):
			img.set_pixel(x, y, Color(0.25, 0.55, 0.85, 1.0))
	# 头部
	for x in range(6, 26):
		for y in range(0, 14):
			img.set_pixel(x, y, Color(0.3, 0.65, 0.95, 1.0))
	# 眼睛
	for x in range(18, 22):
		for y in range(3, 7):
			img.set_pixel(x, y, Color.WHITE)
	# 武器（小剑）
	for x in range(24, 32):
		for y in range(14, 18):
			img.set_pixel(x, y, Color(0.8, 0.8, 0.9, 1.0))
	var tex := ImageTexture.create_from_image(img)
	sprite.texture = tex


func _generate_slash_texture() -> void:
	var img := Image.create(60, 36, false, Image.FORMAT_RGBA8)
	var cx := 30.0
	var cy := 18.0
	for x in range(60):
		for y in range(36):
			var dx := (x - cx) / cx
			var dy := (y - cy) / cy
			var arc: float = 1.0 - abs(dy) * 1.5
			var fade_in: float = smoothstep(-1.0, -0.3, dx)
			var fade_out: float = 1.0 - smoothstep(0.3, 1.0, dx)
			var alpha: float = arc * fade_in * fade_out * 0.8
			if alpha > 0.05:
				img.set_pixel(x, y, Color(1.0, 0.95, 0.7, alpha))
	var tex := ImageTexture.create_from_image(img)
	slash_sprite.texture = tex
	slash_sprite.centered = true


func _physics_process(delta: float) -> void:
	# 无敌闪烁
	if invincible_timer > 0:
		invincible_timer -= delta
		sprite.modulate.a = 0.5 + sin(invincible_timer * 20.0) * 0.5
		if invincible_timer <= 0:
			sprite.modulate.a = 1.0

	# 重力
	if not is_on_floor():
		velocity.y += gravity * delta

	# 跳跃
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	# 水平移动
	var direction := Input.get_axis("move_left", "move_right")
	if direction != 0:
		velocity.x = direction * speed
		facing_right = direction > 0
		sprite.flip_h = not facing_right
	else:
		velocity.x = move_toward(velocity.x, 0, speed * 10 * delta)

	move_and_slide()

	# 攻击冷却计时
	if attack_timer > 0:
		attack_timer -= delta

	# 攻击输入
	if Input.is_action_just_pressed("attack") and attack_timer <= 0:
		_perform_attack()


func _perform_attack() -> void:
	is_attacking = true
	attack_timer = attack_cooldown

	# 攻击区域位置跟随朝向
	var offset_x := 30.0 if facing_right else -30.0
	attack_area.position.x = offset_x
	attack_area.position.y = -4
	attack_area.monitoring = true

	# 刀光特效
	slash_sprite.position.x = offset_x
	slash_sprite.position.y = -4
	slash_sprite.flip_h = not facing_right
	slash_sprite.modulate.a = 1.0
	slash_sprite.visible = true
	var tween := create_tween().set_parallel(true)
	tween.tween_property(slash_sprite, "modulate:a", 0.0, attack_duration)
	tween.tween_property(slash_sprite, "scale", Vector2(1.2, 1.0), attack_duration)

	# 短暂激活后关闭
	await get_tree().create_timer(attack_duration).timeout
	attack_area.monitoring = false
	is_attacking = false
	slash_sprite.visible = false
	slash_sprite.scale = Vector2.ONE


func _on_enemy_contact(body: Node2D) -> void:
	# 敌人接触伤害
	if body.is_in_group("enemy") and invincible_timer <= 0:
		var kb_dir := (global_position - body.global_position).normalized()
		kb_dir.y = -0.3  # 轻微向上击退
		take_damage(1, kb_dir.normalized())


func take_damage(amount: int, knockback_dir: Vector2 = Vector2.ZERO) -> void:
	if invincible_timer > 0:
		return

	health -= amount
	invincible_timer = invincible_duration

	# 击退效果
	if knockback_dir != Vector2.ZERO:
		velocity = knockback_dir * knockback_force

	health_changed.emit(health, max_health)

	if health <= 0:
		_die()


func _die() -> void:
	if is_dead:
		return
	is_dead = true
	print("玩家死亡! 返回主菜单...")
	player_died.emit()
	set_physics_process(false)
	# 延迟返回主菜单
	await get_tree().create_timer(1.5).timeout
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func heal(amount: int) -> void:
	health = min(health + amount, max_health)
