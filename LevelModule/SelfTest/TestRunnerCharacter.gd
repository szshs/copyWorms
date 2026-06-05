# res://LevelModule/SelfTest/TestRunnerCharacter.gd
# 自动向右行走的测试角色，超出 X=300 时触发崩溃信号
extends CharacterBody2D

const AUTO_SPEED: float = 120.0
const CRASH_BOUNDARY: float = 300.0

var _has_crashed: bool = false


func _ready() -> void:
	collision_layer = 4
	collision_mask = 1


func _physics_process(_delta: float) -> void:
	if _has_crashed:
		return
	
	velocity.x = AUTO_SPEED
	move_and_slide()
	
	if global_position.x > CRASH_BOUNDARY:
		_has_crashed = true
		velocity = Vector2.ZERO
		var parent = get_parent()
		if parent and parent.has_signal("prototype_crashed"):
			parent.prototype_crashed.emit()
