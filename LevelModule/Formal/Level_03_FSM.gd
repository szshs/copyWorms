# ============================================================
# Level_03_FSM.gd - 关卡3状态交互分发
# 新状态机: TEA_SHOP_FRONT → LINGNAN_COMBAT → WORLD_SHIFT → CYBER_CITY → MEMORY_COLLECTION → AWAKENING → LEVEL_END_TRANSIT
# ============================================================
extends RefCounted
class_name Level_03_FSM

var level: Level_03

func _init(parent: Level_03) -> void:
	level = parent

func handle_interaction(object_id: String) -> void:
	match level.current_state:
		Level_03.LevelState.TEA_SHOP_FRONT:
			if object_id == "grandpa":
				level._start_grandpa_dialogue()
		Level_03.LevelState.CYBER_CITY, Level_03.LevelState.MEMORY_COLLECTION:
			if object_id == "memory_echo_1":
				level._handle_memory_echo_1()
			elif object_id == "memory_echo_2":
				level._handle_memory_echo_2()
	# 不在此处重置 _is_interacting：叙事面板/回调链（含 _show_narrative）
	# 是异步的（内部有 await），由 _show_narrative 和 _run_safely 自行管理状态
