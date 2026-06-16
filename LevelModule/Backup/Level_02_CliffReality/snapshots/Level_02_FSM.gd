# ============================================================
# Level_02_FSM.gd - 第二关有限状态机
# 负责 state × obj_id 的交互分发 + 二次幂等防线
# 只调用主控公共方法，不直接操作 SceneBuilder/UI
# ============================================================
extends RefCounted

var level: Level_02

func _init(parent: Level_02) -> void:
	level = parent

func handle_interaction(obj_id: String) -> void:
	# 二次幂等防线（与关卡1一致）
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

		Level_02.LevelState.DREAM_STREET, Level_02.LevelState.DREAM_CLIFF_LOOP:
			match obj_id:
				"rattan_chair":
					_handle_rattan_chair()
				"window_l2":
					# 满洲窗仍可远观（若未完成）
					level._handle_window_observe()
				_:
					print("[Level_02] 当前梦境状态不支持与 '%s' 交互" % obj_id)

		Level_02.LevelState.DREAM_INTERFERENCE, Level_02.LevelState.WAKING_HOLD_TAB:
			# 干扰期锁定一切交互，玩家唯一出路是长按 Tab
			print("[Level_02] 干扰期交互被锁定，长按 Tab 睁眼")

		Level_02.LevelState.REALITY_PHONE_LOCKED:
			match obj_id:
				"reality_phone":
					level._handle_reality_phone()
				"reality_computer":
					if level.level_data:
						level._show_narrative(level.level_data.computer_locked_text)
				"reality_bed":
					if level.level_data:
						level._show_narrative(level.level_data.bed_locked_text)
				_:
					print("[Level_02] REALITY_PHONE_LOCKED 不支持与 '%s' 交互" % obj_id)

		Level_02.LevelState.REALITY_PHONE_READ:
			match obj_id:
				"reality_computer":
					level._enter_ide_chat()
				"reality_bed":
					if level.level_data:
						level._show_narrative(level.level_data.bed_locked_text)
				_:
					print("[Level_02] REALITY_PHONE_READ 不支持与 '%s' 交互" % obj_id)

		Level_02.LevelState.REALITY_BED_READY:
			if obj_id == "reality_bed":
				level._trigger_level_end()
			else:
				print("[Level_02] REALITY_BED_READY 仅允许与床交互")

		_:
			print("[Level_02] 状态 %d 下无交互处理" % level.current_state)

# ---- 旧藤椅记忆（仅一次） ----

func _handle_rattan_chair() -> void:
	if level.has_triggered_chair_memory:
		return
	if not level.level_data:
		printerr("[Level_02] level_data 为 null")
		return
	level.has_triggered_chair_memory = true
	level._mark_interaction_completed("rattan_chair")
	level._show_narrative(level.level_data.rattan_chair_monologue)
