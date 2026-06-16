# ============================================================
# Level_04_FSM.gd - 关卡4状态交互分发（当前阶段1，后续扩展）
# ============================================================
extends RefCounted
class_name Level_04_FSM

var level: Level_04

func _init(parent: Level_04) -> void:
	level = parent

func handle_interaction(_object_id: String) -> void:
	# 后续阶段扩展
	pass
