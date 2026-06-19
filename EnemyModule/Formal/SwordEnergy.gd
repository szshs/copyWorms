# ============================================================
# SwordEnergy.gd — Boss 剑气弹幕
# 朝玩家方向飞行，撞墙消失，对玩家造成伤害
# ============================================================
extends Area2D

var _velocity: Vector2 = Vector2.ZERO
var _damage: int = 12
var _lifetime: float = 0.0
const SPEED: float = 350.0
const MAX_LIFETIME: float = 8.0
const WALL_COLLISION: int = 1  # TERRAIN

@onready var _sprite: Sprite2D = $Sprite

func setup(target_pos: Vector2, dmg: int = 12) -> void:
	_damage = dmg
	var dir = (target_pos - global_position).normalized()
	_velocity = dir * SPEED
	rotation = dir.angle()

## 按指定方向初始化（用于扇形散布，瞄准方向而非固定点）
func setup_by_dir(dir: Vector2, dmg: int = 12) -> void:
	_damage = dmg
	_velocity = dir.normalized() * SPEED
	rotation = dir.angle()

func set_color(col: Color) -> void:
	if _sprite:
		_sprite.modulate = col

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	global_position += _velocity * delta
	_lifetime += delta
	if _lifetime > MAX_LIFETIME:
		queue_free()

func _on_body_entered(body: Node2D) -> void:
	# 只检测玩家层（collision_mask=4），剑气穿过所有地形
	if body == GameManager.player_ref:
		if body.has_method("take_damage"):
			var kb = (body.global_position - global_position).normalized()
			body.take_damage(_damage, kb)
		queue_free()
