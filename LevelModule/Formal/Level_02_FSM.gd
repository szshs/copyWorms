# ============================================================
# Level_02_FSM.gd - 第二关有限状态机（简化版：阁楼 → 老街）
# ============================================================
extends RefCounted
class_name Level_02_FSM

var level: Level_02

func _init(parent: Level_02) -> void:
	level = parent

func handle_interaction(obj_id: String) -> void:
	var obj_ref = level._get_interactive_by_id(obj_id)
	if obj_ref and obj_ref.completed and not obj_ref.allow_repeat:
		print("[Level_02] 拦截重复交互: %s 在 FSM 入口已完成" % obj_id)
		return

	match level.current_state:
		Level_02.LevelState.DREAM_ATTIC:
			match obj_id:
				"window_l2":
					level._handle_window_observe()
				"attic_door":
					level._transition_attic_to_street()
				_:
					print("[Level_02] DREAM_ATTIC 不支持与 '%s' 交互" % obj_id)

		Level_02.LevelState.DREAM_STREET:
			match obj_id:
				"rattan_chair":
					_handle_rattan_chair()
				"sub02_portal":
					level._transition_to_sub02()
				"chips_cat":
					level._handle_chips_cat_interaction()
				"window_l2":
					level._handle_window_observe()
				_:
					print("[Level_02] 当前梦境状态不支持与 '%s' 交互" % obj_id)

		_:
			print("[Level_02] 状态 %d 下无交互处理" % level.current_state)

func _handle_rattan_chair() -> void:
	if level.has_triggered_chair_memory:
		return
	if not level.level_data:
		printerr("[Level_02] level_data 为 null")
		return
	level.has_triggered_chair_memory = true
	level._mark_interaction_completed("rattan_chair")
	level._show_narrative(level.level_data.rattan_chair_monologue)
