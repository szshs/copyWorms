# ============================================================
# Level_01_FSM.gd - 第一关有限状态机
# 负责 7 个叙事阶段的状态调度和交互处理
# ============================================================
extends RefCounted
class_name Level_01_FSM

var level: Level_01

func _init(parent: Level_01) -> void:
	level = parent

func handle_interaction(obj_id: String) -> void:
	# 二次幂等性防线
	var obj_ref = level._get_interactive_by_id(obj_id)
	if obj_ref and obj_ref.completed:
		print("[Level_01] 拦截重复交互: %s 在 FSM 入口已完成" % obj_id)
		return

	match level.current_state:
		Level_01.LevelState.LIVING_ROOM:
			if obj_id == "box":
				_handle_box()
			else:
				print("[Level_01] LIVING_ROOM 不支持与 '%s' 交互" % obj_id)

		Level_01.LevelState.CORRIDOR:
			if obj_id == "clothes":
				_handle_clothes()
			else:
				print("[Level_01] CORRIDOR 不支持与 '%s' 交互" % obj_id)

		Level_01.LevelState.BEDROOM:
			match obj_id:
				"notice": _handle_notice()
				"thermos": _handle_thermos()
				"bed": _handle_bed()
				"computer": _handle_computer()
				_:
					print("[Level_01] BEDROOM 不支持与 '%s' 交互" % obj_id)

		Level_01.LevelState.PHONE_RINGING:
			if obj_id == "phone":
				_handle_phone()
			else:
				print("[Level_01] PHONE_RINGING 不支持与 '%s' 交互" % obj_id)

		Level_01.LevelState.GLITCH_TRANSIT:
			if obj_id == "bed":
				_handle_final_bed()
			else:
				print("[Level_01] GLITCH_TRANSIT 锁定其他交互，仅允许与床交互")

		_:
			print("[Level_01] 状态 %d 下无交互处理" % level.current_state)

# ---- 客厅 → 走廊 ----

func _handle_box() -> void:
	if not level.level_data:
		printerr("[Level_01] level_data 为 null"); return
	level._mark_interaction_completed("box")
	level._show_narrative(level.level_data.obstacle_1_text, func():
		level._clear_obstacle(level._obstacle_box)
		level.current_state = Level_01.LevelState.CORRIDOR
		print("[Level_01] 纸箱清除，进入走廊阶段")
	)

# ---- 走廊 → 卧室 ----

func _handle_clothes() -> void:
	if not level.level_data:
		printerr("[Level_01] level_data 为 null"); return
	level._mark_interaction_completed("clothes")
	level._show_narrative(level.level_data.obstacle_2_text, func():
		level._clear_obstacle(level._obstacle_clothes)
		level.current_state = Level_01.LevelState.BEDROOM
		print("[Level_01] 衣服清除，进入卧室阶段")
	)

# ---- 卧室叙事细节 ----

func _handle_notice() -> void:
	if not level.level_data:
		printerr("[Level_01] level_data 为 null"); return
	# 休学告知书：一次性交互，弹完即标完成
	level._mark_interaction_completed("notice")
	level._show_narrative(level.level_data.notice_text, func():
		print("[Level_01] 休学告知书已阅")
	)

func _handle_thermos() -> void:
	if not level.level_data:
		printerr("[Level_01] level_data 为 null"); return
	# 旧保温杯：一次性交互，弹完即标完成
	level._mark_interaction_completed("thermos")
	level._show_narrative(level.level_data.thermos_text, func():
		print("[Level_01] 旧保温杯已阅")
	)

func _handle_bed() -> void:
	# 床：可重复触发睡眠循环；床的 allow_repeat=true，由 _trigger_sleep_cycle 内部 reset_completed
	level._trigger_sleep_cycle()

func _handle_computer() -> void:
	# 电脑：进入 IDE 对话模式
	level._enter_ide_mode()

# ---- 手机接听 → 短信 → 独白 → GLITCH_TRANSIT ----

func _handle_phone() -> void:
	level._trigger_climax_transition()

# ---- 终局：玩家在 GLITCH_TRANSIT 状态再次与床交互 ----

func _handle_final_bed() -> void:
	level._on_final_bed_trigger()
