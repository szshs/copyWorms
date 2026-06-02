extends Node
class_name PatrolBehavior

## 巡逻行为 —— 来回走动，边缘/墙壁检测自动回头，防止掉落

@export var speed: float = 60.0
@export var edge_check_distance: float = 40.0   ## 边缘检测距离

var enemy: EnemyBase
var direction: int = -1  ## 初始向左巡逻


func _init(owner_enemy: EnemyBase) -> void:
	enemy = owner_enemy


func enter() -> void:
	pass


func update(delta: float) -> void:
	if not is_instance_valid(enemy):
		return

	enemy.velocity.x = direction * speed
	enemy.sprite.flip_h = direction > 0

	# 撞墙回头
	if enemy.is_on_wall():
		_reverse_direction()
		return

	# 边缘检测 —— 前方没有地面就回头
	if not enemy.is_ground_ahead(direction, edge_check_distance):
		_reverse_direction()


func _reverse_direction() -> void:
	direction *= -1
