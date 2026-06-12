# ============================================================
# Level_03_FSM.gd - 第三关有限状态机
# 负责 state × obj_id 的交互分发 + 二次幂等防线
# 只调用主控公共方法，不直接操作 SceneBuilder/UI
# ============================================================
extends RefCounted
class_name Level_03_FSM

var level: Level_03

func _init(parent: Level_03) -> void:
	level = parent

func handle_interaction(obj_id: String) -> void:
	# 二次幂等防线（与关卡1/2一致）
	var obj_ref = level._get_interactive_by_id(obj_id)
	if obj_ref and obj_ref.completed and not obj_ref.allow_repeat:
		print("[Level_03] 拦截重复交互: %s 在 FSM 入口已完成" % obj_id)
		return

	match level.current_state:
		Level_03.LevelState.TEA_SHOP_FRONT:
			match obj_id:
				"grandpa":
					level._start_grandpa_dialogue()
				_:
					print("[Level_03] TEA_SHOP_FRONT 不支持与 '%s' 交互" % obj_id)

		Level_03.LevelState.CYBER_TRANSITION:
			# 转场期间锁定一切交互
			print("[Level_03] CYBER_TRANSITION 交互被锁定")

		Level_03.LevelState.CYBER_CITY:
			match obj_id:
				"memory_echo_1":
					level._handle_memory_echo_1()
				"memory_echo_2":
					level._handle_memory_echo_2()
				_:
					print("[Level_03] CYBER_CITY 不支持与 '%s' 交互" % obj_id)

		Level_03.LevelState.MEMORY_COLLECTION:
			match obj_id:
				"memory_echo_1":
					level._handle_memory_echo_1()
				"memory_echo_2":
					level._handle_memory_echo_2()
				_:
					print("[Level_03] MEMORY_COLLECTION 不支持与 '%s' 交互" % obj_id)

		Level_03.LevelState.AWAKENING:
			# 觉醒期间锁定一切交互
			print("[Level_03] AWAKENING 交互被锁定")

		Level_03.LevelState.LEVEL_END_TRANSIT:
			# 终局由 _handle_accept_input 处理 Enter 确认
			pass

		_:
			print("[Level_03] 状态 %d 下无交互处理" % level.current_state)
