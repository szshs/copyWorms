extends Node
class_name AIController

## AI 控制器 —— 管理检测区域和状态切换

@export var detection_range: float = 250.0

var enemy: EnemyBase
var state_machine: EnemyStateMachine
var patrol: PatrolBehavior
var chase: ChaseBehavior

@onready var detection_area: Area2D = $"../DetectionArea"
@onready var detection_collision: CollisionShape2D = $"../DetectionArea/CollisionShape2D"


func _init(owner_enemy: EnemyBase, sm: EnemyStateMachine, p: PatrolBehavior, c: ChaseBehavior) -> void:
	enemy = owner_enemy
	state_machine = sm
	patrol = p
	chase = c


func setup() -> void:
	if detection_collision and detection_collision.shape is CircleShape2D:
		detection_collision.shape.radius = detection_range

	detection_area.body_entered.connect(_on_detection_body_entered)
	detection_area.body_exited.connect(_on_detection_body_exited)


func _on_detection_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		chase.set_player(body as Player)
		if state_machine.current_state == EnemyStateMachine.State.PATROL:
			state_machine.transition_to(EnemyStateMachine.State.CHASE)


func _on_detection_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		chase.clear_player()
