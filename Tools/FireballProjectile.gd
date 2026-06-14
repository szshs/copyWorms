# ============================================================
# FireballProjectile.gd - 灯笼鬼火球弹体
# 核心：火球.png 精灵 + 代码粒子拖尾
# ============================================================
extends Area2D

var direction: Vector2 = Vector2.RIGHT
var speed: float = 300.0
var damage: int = 10
var damage_type: int = GlobalDefine.DamageType.MAGIC
var knockback_force: float = 200.0
var max_distance: float = 500.0
var _traveled: float = 0.0
var _owner: Node2D = null

# 拖尾粒子池
var _particles: Array = []  # {node, life}
const TRAIL_SPAWN_INTERVAL := 0.03
const TRAIL_PARTICLE_LIFE := 0.35
const TRAIL_MAX_PARTICLES := 20
var _trail_timer: float = 0.0

func _ready() -> void:
	# 碰撞形状
	var col_shape = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 12.0
	col_shape.shape = shape
	add_child(col_shape)

	# 火球核心精灵
	var fireball_tex = load("res://Assets/Effects/火球.png")
	if fireball_tex:
		var sprite = Sprite2D.new()
		sprite.texture = fireball_tex
		sprite.scale = Vector2(0.013, 0.013)
		sprite.z_index = 10
		add_child(sprite)
	else:
		# 后备：纯代码圆形
		var core = ColorRect.new()
		core.size = Vector2(16, 16)
		core.position = Vector2(-8, -8)
		core.color = Color(1.0, 0.7, 0.2, 0.95)
		core.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(core)

	# 信号
	body_entered.connect(_on_body_entered)

	# 碰撞层
	collision_layer = 0
	collision_mask = GlobalDefine.Collision.PLAYER

	rotation = direction.angle()

func setup(dir: Vector2, dmg: int, owner: Node2D, dist: float = 500.0, spd: float = 300.0) -> void:
	direction = dir.normalized()
	rotation = direction.angle()
	damage = dmg
	_owner = owner
	max_distance = dist
	speed = spd

func _physics_process(delta: float) -> void:
	var move = direction * speed * delta
	position += move
	_traveled += move.length()

	# 生成拖尾粒子
	_trail_timer += delta
	if _trail_timer >= TRAIL_SPAWN_INTERVAL:
		_trail_timer = 0.0
		_spawn_trail_particle()

	# 更新拖尾粒子
	var alive := []
	for p in _particles:
		p.life -= delta
		if p.life <= 0:
			p.node.queue_free()
		else:
			var ratio = p.life / TRAIL_PARTICLE_LIFE
			p.node.modulate.a = ratio * 0.6
			p.node.scale = Vector2(ratio * 0.4, ratio * 0.4)
			alive.append(p)
	_particles = alive

	# 超出距离消散
	if _traveled >= max_distance:
		_fade_out()

func _spawn_trail_particle() -> void:
	if _particles.size() >= TRAIL_MAX_PARTICLES:
		return

	var p = ColorRect.new()
	p.size = Vector2(14, 14)
	p.position = Vector2(-7, -7)
	p.color = Color(1.0, 0.45 + randf() * 0.15, 0.05, 0.6)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.z_index = 8
	# 放到父节点下，跟随世界坐标
	var parent = get_parent()
	if parent:
		parent.add_child(p)
		p.global_position = global_position + Vector2(randf_range(-3, 3), randf_range(-3, 3))
	_particles.append({node = p, life = TRAIL_PARTICLE_LIFE})

func _on_body_entered(body: Node2D) -> void:
	if not body or not is_instance_valid(body):
		return
	if not body.has_method("take_damage"):
		return

	var result = DamageCalculator.calculate(damage, 0, damage_type)
	var kb_dir = direction.normalized() if direction != Vector2.ZERO else Vector2(1, 0)
	body.take_damage(result["damage"], kb_dir)

	_spawn_hit_flash(body.global_position)
	_fade_out()

func _spawn_hit_flash(pos: Vector2) -> void:
	var parent = get_parent()
	if not parent:
		return
	# 爆炸闪光
	for i in range(6):
		var spark = ColorRect.new()
		var angle = randf() * TAU
		var dist = randf_range(5, 18)
		spark.size = Vector2(6, 6)
		spark.position = parent.to_local(pos) + Vector2(cos(angle), sin(angle)) * dist - spark.size / 2
		spark.color = Color(1.0, 0.5 + randf() * 0.3, 0.1, 0.9)
		spark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		spark.z_index = 12
		parent.add_child(spark)
		var tween = spark.create_tween()
		tween.tween_property(spark, "modulate:a", 0.0, 0.25)
		tween.tween_callback(spark.queue_free)

func _fade_out() -> void:
	set_physics_process(false)
	# 清理拖尾
	for p in _particles:
		if is_instance_valid(p.node):
			p.node.queue_free()
	_particles.clear()
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.15)
	tween.tween_callback(queue_free)
