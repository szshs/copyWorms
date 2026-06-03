extends Node
class_name EnemyStateMachine

## 敌人状态机 —— 管理状态切换，解耦行为逻辑

enum State { PATROL, CHASE, ATTACK, HURT, DEAD }

signal state_changed(old_state: State, new_state: State)

var current_state: State = State.PATROL
var enemy: EnemyBase

## 各状态的引用（由子类赋值）
var patrol_behavior: PatrolBehavior
var chase_behavior: ChaseBehavior


func init_refs(owner_enemy: EnemyBase) -> void:
	enemy = owner_enemy


func transition_to(new_state: State) -> void:
	if new_state == current_state:
		return
	var old := current_state
	current_state = new_state
	state_changed.emit(old, new_state)
	_on_state_enter(new_state)


func _on_state_enter(state: State) -> void:
	match state:
		State.PATROL:
			if patrol_behavior:
				patrol_behavior.enter()
		State.CHASE:
			if chase_behavior:
				chase_behavior.enter()
		State.ATTACK:
			pass
		State.HURT:
			pass
		State.DEAD:
			pass
