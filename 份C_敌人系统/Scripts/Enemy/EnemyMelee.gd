extends EnemyBase
class_name EnemyMelee

## 近战敌人 —— 整合巡逻、追逐、受伤、死亡

@export var patrol_speed: float = 60.0
@export var chase_speed: float = 200.0
@export var charge_speed: float = 400.0
@export var charge_duration: float = 0.6
@export var chase_duration: float = 2.0
@export var detection_range: float = 250.0

var state_machine: EnemyStateMachine
var patrol_behavior: PatrolBehavior
var chase_behavior: ChaseBehavior
var ai_controller: AIController


func _setup_extra() -> void:
	# 创建状态机
	state_machine = EnemyStateMachine.new(self)
	state_machine.name = "StateMachine"
	add_child(state_machine)

	# 创建巡逻行为
	patrol_behavior = PatrolBehavior.new(self)
	patrol_behavior.name = "PatrolBehavior"
	patrol_behavior.speed = patrol_speed
	add_child(patrol_behavior)
	state_machine.patrol_behavior = patrol_behavior

	# 创建追逐行为
	chase_behavior = ChaseBehavior.new(self)
	chase_behavior.name = "ChaseBehavior"
	chase_behavior.chase_speed = chase_speed
	chase_behavior.charge_speed = charge_speed
	chase_behavior.charge_duration = charge_duration
	chase_behavior.chase_duration = chase_duration
	add_child(chase_behavior)
	state_machine.chase_behavior = chase_behavior

	# 创建 AI 控制器
	ai_controller = AIController.new(self, state_machine, patrol_behavior, chase_behavior)
	ai_controller.name = "AIController"
	ai_controller.detection_range = detection_range
	add_child(ai_controller)
	ai_controller.setup()

	# 初始化状态
	state_machine.transition_to(EnemyStateMachine.State.PATROL)


func _update_behavior(delta: float) -> void:
	if not is_instance_valid(state_machine):
		return

	match state_machine.current_state:
		EnemyStateMachine.State.PATROL:
			patrol_behavior.update(delta)
		EnemyStateMachine.State.CHASE:
			chase_behavior.update(delta)


func _on_hurt_end() -> void:
	if ai_controller and is_instance_valid(ai_controller):
		var in_range := ai_controller.detection_area.has_overlapping_bodies()
		var player_nearby := false
		if in_range:
			for body in ai_controller.detection_area.get_overlapping_bodies():
				if body.is_in_group("player"):
					player_nearby = true
					break
		state_machine.transition_to(
			EnemyStateMachine.State.CHASE if player_nearby else EnemyStateMachine.State.PATROL
		)


func die() -> void:
	if is_dead:
		return
	state_machine.transition_to(EnemyStateMachine.State.DEAD)
	super.die()
