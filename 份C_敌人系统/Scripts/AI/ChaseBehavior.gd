extends Node
class_name ChaseBehavior

## 追逐行为 —— 发现玩家后追击，首次冲刺，超时回巡逻

@export var chase_speed: float = 200.0
@export var charge_speed: float = 400.0       ## 首次冲刺速度
@export var charge_duration: float = 0.6       ## 冲刺持续时间
@export var chase_duration: float = 2.0        ## 追逐超时
@export var edge_check_distance: float = 40.0  ## 边缘检测距离

var enemy: EnemyBase
var player_ref: Player = null
var player_in_range: bool = false
var chase_timer: float = 0.0
var charge_timer: float = 0.0


func _init(owner_enemy: EnemyBase) -> void:
	enemy = owner_enemy


func enter() -> void:
	charge_timer = charge_duration  ## 进入追逐时冲刺


func set_player(player: Player) -> void:
	player_ref = player
	player_in_range = true
	chase_timer = chase_duration


func clear_player() -> void:
	player_in_range = false


func update(delta: float) -> void:
	if not is_instance_valid(enemy):
		return

	chase_timer -= delta

	# 超时或玩家不在范围内
	if chase_timer <= 0 and not player_in_range:
		enemy.get_node("StateMachine").transition_to(EnemyStateMachine.State.PATROL)
		return

	# 重置计时
	if player_in_range:
		chase_timer = chase_duration

	# 冲/追逐玩家
	if player_ref and is_instance_valid(player_ref):
		var dir := signf(player_ref.global_position.x - enemy.global_position.x)

		# 边缘检测 —— 前方是悬崖则停止追逐，回巡逻
		if not enemy.is_ground_ahead(dir, edge_check_distance):
			enemy.get_node("StateMachine").transition_to(EnemyStateMachine.State.PATROL)
			return

		var speed := charge_speed if charge_timer > 0 else chase_speed
		if charge_timer > 0:
			charge_timer -= delta

		enemy.velocity.x = dir * speed
		enemy.sprite.flip_h = dir > 0

		# 冲刺时视觉反馈
		if charge_timer > 0:
			enemy.sprite.modulate = Color(1.3, 0.8, 0.8, 1.0)
		else:
			enemy.sprite.modulate = Color(1.15, 0.85, 0.85, 1.0)
	else:
		player_in_range = false
		enemy.get_node("StateMachine").transition_to(EnemyStateMachine.State.PATROL)
