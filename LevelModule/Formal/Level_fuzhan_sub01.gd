extends Node
class_name LevelFuzhanSub01

const LEVEL_02_03_PATH := "res://LevelModule/Formal/Level_02_03.tscn"
const FUZHAN_01_PATH := "res://LevelModule/Formal/Level_fuzhan_01.tscn"
const FUZHAN_02_PATH := "res://LevelModule/Formal/Level_fuzhan_02.tscn"
const LEVEL_02_BGM_PATH := "res://Assets/Music/2 test-2.ogg"
const NIGHTFALL_BGM_PATH := "res://Assets/Music/Nightfall.mp3"

const KEY_STARTED := "memory_recovery_started"
const KEY_RESUME_REALITY := "level0203_resume_reality"
const KEY_RETURN_REASON := "memory_return_reason"
const KEY_CURRENT_AREA := "memory_current_area"
const KEY_FUZHAN_01_COLLECTED := "fuzhan_01_collected"
const KEY_FUZHAN_02_COLLECTED := "fuzhan_02_collected"
const KEY_FUZHAN_01_COMPLETE := "fuzhan_01_complete"
const KEY_FUZHAN_02_COMPLETE := "fuzhan_02_complete"
const KEY_MEMORY_FRAGMENTS := "memory_fragments"
const KEY_CORE_STABILIZED := "core_memory_anchor_stabilized"

const REQUIRED_PER_AREA := 3
const REQUIRED_TOTAL := 6
const KILLS_PER_DROP := 10
const DROP_TYPES: Array[String] = ["月饼", "虾饺", "木棉", "醒狮", "烧卖", "蒲葵扇"]

const RETURN_NONE := ""
const RETURN_FUZHAN_01_COMPLETE := "fuzhan_01_complete"
const RETURN_FUZHAN_01_FAILED := "fuzhan_01_failed"
const RETURN_FUZHAN_02_COMPLETE := "fuzhan_02_complete"
const RETURN_FUZHAN_02_FAILED := "fuzhan_02_failed"

const WAKE_MONOLOGUE := "……又是这个天花板。\n梦里的裂缝、黑影，还有那条短信。\n\n我以为只要造出老街，就能回到爷爷身边。\n可我连凉茶铺都到不了。\n\n也许不是梦不够完整。\n是我记得的东西，还不够完整。"
const FUZHAN_01_COMPLETE_REALITY := "我回来了。\n但那些记忆没有散。\n\n它们还在。\n像被我从梦里带回了手心里。"
const FUZHAN_01_FAILED_REALITY := "……又醒了。\n刚才找到的感觉正在散掉。\n\n不行。\n这不是随便捡起几个东西就能完成的事。\n我要重新进去。\n直到这片记忆真正稳定下来。"
const FUZHAN_02_COMPLETE_REALITY := "……回来了。\n但这次不一样。\n\n我不是空着手醒来的。\n我把那些差点被我忘掉的东西，都带回来了。\n\n他在那些小小的回忆里。\n现在，我终于可以去见他了。"
const FUZHAN_02_FAILED_REALITY := "还不够。\n我刚刚差一点就想起来了。\n\n那些东西就在眼前。\n我不能停在这里。"

const FUZHAN_01_ENTER_TEXT := "西关梦境：记忆回收模式\n\n目标区域 01：level_fuzhan_01\n目标：击败敌对实体，回收 3 个童年回忆样本。\n\n地图结构已保持原样。\n记忆深层正在等待补全……"
const FUZHAN_02_ENTER_TEXT := "西关梦境：记忆回收模式\n\n目标区域 02：level_fuzhan_02\n地图来源：Level_02_01\n目标：击败敌对实体，回收 3 个童年回忆样本。\n\n总进度：3 / 6\n记忆核心同步中……"

const FUZHAN_01_INTRO := "这里和之前一样。\n满洲窗、阁楼、老街的光。\n\n这次不是为了逃进去。\n我要把那些散掉的童年回忆，一点一点找回来。\n\n只有这样，我才能真正走到爷爷面前。"
const FUZHAN_02_INTRO := "这里是另一段路。\n我以前总从这里跑去找爷爷。\n\n还有三个。\n只要再找回三个记忆样本，我就能去见他。\n\n不是去见一个空壳。\n而是带着我真正记得的一切，去见他。"

const FUZHAN_01_DROP_READY := "记忆波动增强。\n童年回忆正在凝结……\n\n童年回忆样本已出现。\n请回收。"
const FUZHAN_02_DROP_READY := "记忆回声正在靠近。\n童年回忆正在凝结……\n\n童年回忆样本已出现。\n请回收。"

const FUZHAN_01_COMPLETE_FIELD := "够了。\n这片老街的记忆，已经被我找回来了。\n\n还有别的地方。\n还有更多我差点忘掉的东西。"
const FUZHAN_02_COMPLETE_FIELD := "这回终于收集齐了，不会再有阻碍了。"

const FUZHAN_01_FAILED_FIELD := "意识稳定性下降。\n记忆回收中断。"
const FUZHAN_02_FAILED_FIELD := "意识稳定性下降。\n第二目标区域记忆回收中断。"


static func ensure_state() -> Dictionary:
	var flags := GameManager.dream_runtime_flags
	if not flags.has(KEY_STARTED):
		flags[KEY_STARTED] = false
	if not flags.has(KEY_RESUME_REALITY):
		flags[KEY_RESUME_REALITY] = false
	if not flags.has(KEY_RETURN_REASON):
		flags[KEY_RETURN_REASON] = RETURN_NONE
	if not flags.has(KEY_CURRENT_AREA):
		flags[KEY_CURRENT_AREA] = 1
	if not flags.has(KEY_FUZHAN_01_COLLECTED):
		flags[KEY_FUZHAN_01_COLLECTED] = 0
	if not flags.has(KEY_FUZHAN_02_COLLECTED):
		flags[KEY_FUZHAN_02_COLLECTED] = 0
	if not flags.has(KEY_FUZHAN_01_COMPLETE):
		flags[KEY_FUZHAN_01_COMPLETE] = false
	if not flags.has(KEY_FUZHAN_02_COMPLETE):
		flags[KEY_FUZHAN_02_COMPLETE] = false
	_recalculate_total(flags)
	GameManager.dream_runtime_flags = flags
	return flags


static func start_flow() -> void:
	var flags := ensure_state()
	flags[KEY_STARTED] = true
	flags[KEY_CURRENT_AREA] = current_target_area()
	GameManager.dream_runtime_flags = flags


static func should_resume_reality() -> bool:
	return bool(ensure_state().get(KEY_RESUME_REALITY, false))


static func consume_return_reason() -> String:
	var flags := ensure_state()
	var reason := str(flags.get(KEY_RETURN_REASON, RETURN_NONE))
	flags[KEY_RETURN_REASON] = RETURN_NONE
	flags[KEY_RESUME_REALITY] = false
	GameManager.dream_runtime_flags = flags
	return reason


static func current_target_area() -> int:
	var flags := ensure_state()
	if not bool(flags.get(KEY_FUZHAN_01_COMPLETE, false)):
		return 1
	if not bool(flags.get(KEY_FUZHAN_02_COMPLETE, false)):
		return 2
	return 0


static func area_scene_path(area: int) -> String:
	return FUZHAN_01_PATH if area == 1 else FUZHAN_02_PATH


static func enter_text(area: int) -> String:
	return FUZHAN_01_ENTER_TEXT if area == 1 else FUZHAN_02_ENTER_TEXT


static func intro_text(area: int) -> String:
	return FUZHAN_01_INTRO if area == 1 else FUZHAN_02_INTRO


static func drop_ready_text(area: int) -> String:
	return FUZHAN_01_DROP_READY if area == 1 else FUZHAN_02_DROP_READY


static func field_complete_text(area: int) -> String:
	return FUZHAN_01_COMPLETE_FIELD if area == 1 else FUZHAN_02_COMPLETE_FIELD


static func field_failed_text(area: int) -> String:
	return FUZHAN_01_FAILED_FIELD if area == 1 else FUZHAN_02_FAILED_FIELD


static func area_collected(area: int) -> int:
	var flags := ensure_state()
	return int(flags.get(KEY_FUZHAN_01_COLLECTED if area == 1 else KEY_FUZHAN_02_COLLECTED, 0))


static func total_fragments() -> int:
	return int(ensure_state().get(KEY_MEMORY_FRAGMENTS, 0))


static func add_fragment(area: int) -> int:
	var flags := ensure_state()
	var key := KEY_FUZHAN_01_COLLECTED if area == 1 else KEY_FUZHAN_02_COLLECTED
	var value := mini(int(flags.get(key, 0)) + 1, REQUIRED_PER_AREA)
	flags[key] = value
	if value >= REQUIRED_PER_AREA:
		if area == 1:
			flags[KEY_FUZHAN_01_COMPLETE] = true
		else:
			flags[KEY_FUZHAN_02_COMPLETE] = true
	_recalculate_total(flags)
	if int(flags[KEY_MEMORY_FRAGMENTS]) >= REQUIRED_TOTAL:
		flags[KEY_CORE_STABILIZED] = true
	GameManager.dream_runtime_flags = flags
	return value


static func can_open_config() -> bool:
	var flags := ensure_state()
	return int(flags.get(KEY_MEMORY_FRAGMENTS, 0)) >= REQUIRED_TOTAL \
		and bool(flags.get(KEY_FUZHAN_01_COMPLETE, false)) \
		and bool(flags.get(KEY_FUZHAN_02_COMPLETE, false))


static func request_return_to_reality(area: int, completed: bool) -> void:
	var flags := ensure_state()
	flags[KEY_RESUME_REALITY] = true
	if area == 1:
		flags[KEY_RETURN_REASON] = RETURN_FUZHAN_01_COMPLETE if completed else RETURN_FUZHAN_01_FAILED
	else:
		flags[KEY_RETURN_REASON] = RETURN_FUZHAN_02_COMPLETE if completed else RETURN_FUZHAN_02_FAILED
	flags[KEY_CURRENT_AREA] = current_target_area()
	GameManager.dream_runtime_flags = flags


static func reality_return_text(reason: String) -> String:
	match reason:
		RETURN_FUZHAN_01_COMPLETE:
			return FUZHAN_01_COMPLETE_REALITY
		RETURN_FUZHAN_01_FAILED:
			return FUZHAN_01_FAILED_REALITY
		RETURN_FUZHAN_02_COMPLETE:
			return FUZHAN_02_COMPLETE_REALITY
		RETURN_FUZHAN_02_FAILED:
			return FUZHAN_02_FAILED_REALITY
	return ""


static func free_chat_prompt() -> String:
	var total := total_fragments()
	if can_open_config():
		return "CodeBuddy: 记忆样本已补全。输入 /config 可进入配置编辑器。"
	if current_target_area() == 2:
		return "CodeBuddy: 第二目标区域已就绪。\n当前进度：%d / 6。\n输入 /memory 进入 level_fuzhan_02。" % total
	return "CodeBuddy: 童年回忆补全流程已就绪。\n当前进度：%d / 6。\n输入 /memory 可进入复战区域。\n回收 6 个童年回忆样本后，配置编辑器将开放。" % total


static func config_locked_prompt() -> String:
	var total := total_fragments()
	var area := current_target_area()
	var area_name := "level_fuzhan_01" if area == 1 else "level_fuzhan_02"
	return "CodeBuddy: 当前记忆锚点不足。\n配置编辑器暂未开放。\n请先完成童年回忆补全流程：%d / 6。\n\n提示：输入 /memory 进入 %s。" % [total, area_name]


static func memory_launch_prompt(area: int) -> String:
	var area_name := "level_fuzhan_01" if area == 1 else "level_fuzhan_02"
	return "CodeBuddy: 正在启动记忆回收模式。\n目标区域：%s。\n目标：回收 3 个童年回忆样本。" % area_name


static func ide_speakers_for_stage(default_speakers: Array[String]) -> Array[String]:
	if not bool(ensure_state().get(KEY_STARTED, false)):
		return default_speakers
	if can_open_config():
		return ["System", "CodeBuddy", "Ming", "CodeBuddy", "Ming", "CodeBuddy", "System"]
	if bool(ensure_state().get(KEY_FUZHAN_01_COMPLETE, false)):
		return ["System", "CodeBuddy", "Ming", "CodeBuddy", "Ming", "CodeBuddy", "System"]
	return ["CodeBuddy"]


static func ide_texts_for_stage(default_texts: Array[String]) -> Array[String]:
	var flags := ensure_state()
	if not bool(flags.get(KEY_STARTED, false)):
		return default_texts
	if can_open_config():
		return [
			"Memory Recovery Complete.\nRecovered Memory Fragments: 6 / 6.\nCore Area Access: Unlocked.",
			"童年回忆补全流程已完成。\n检测到 6 个稳定记忆样本。\n核心区域“凉茶铺”的生成精度已提升。",
			"终于啊，我能见到爷爷了？这回不会再有什么干扰了吧。",
			"可以进入更深层的梦境。\n但请注意：\n此次进入将无法离开。\n按照您的要求，我进行了场景封闭。\n这里没有回头路",
			"我不在乎。\n让我见到他！\n这一次不要再让外界信息干扰了！让我畅通无阻地见到爷爷！",
			"理解。\n配置编辑器现已开放。\n您可以继续修改梦境参数。\n完成重新编译后，将进入核心区域：凉茶铺。",
			"Configuration editor unlocked.\nAwaiting input...",
		]
	if bool(flags.get(KEY_FUZHAN_01_COMPLETE, false)):
		return [
			"Area 01 Memory Recovery Complete.\nRecovered Memory Fragments: 3 / 6.",
			"第一目标区域 level_fuzhan_01 回收完成。\n前半段童年回忆已稳定。\n但通往凉茶铺的核心路径仍未开放。",
			"还差一半，对吧？",
			"是。\n剩余记忆样本位于第二目标区域：level_fuzhan_02。\n\n该区域对应您更深一层的童年路径。\n地图来源为 Level_02_01。\n进入后，地图结构仍将保持原样。\n但敌对实体强度可能提升。",
			"又要回到那个地方嘛....",
			"第二目标区域准备完成。\n目标：继续回收 3 个童年回忆样本。\n完成后，深层梦境入口将开放。\n届时，您可以正式修改配置，并前往“凉茶铺”。",
			"Target Area 02: level_fuzhan_02\nSource Map: Level_02_01\nRequired Memory Fragments: 3 / 3\nPreparing Local Dream Viewport...",
		]
	var reason := str(flags.get(KEY_RETURN_REASON, RETURN_NONE))
	if reason == RETURN_FUZHAN_01_FAILED:
		return ["检测到意识中断。\nlevel_fuzhan_01 记忆样本未完成稳定。\n请重新进入该区域，并回收 3 个童年回忆样本。"]
	if reason == RETURN_FUZHAN_02_FAILED:
		return ["检测到 level_fuzhan_02 回收失败。\n当前区域记忆样本未完成稳定。\n请重新进入，并回收 3 个童年回忆样本。"]
	return default_texts


static func ide_speakers_for_return_reason(reason: String) -> Array[String]:
	match reason:
		RETURN_FUZHAN_01_FAILED, RETURN_FUZHAN_02_FAILED:
			return ["CodeBuddy"]
	return []


static func ide_texts_for_return_reason(reason: String) -> Array[String]:
	match reason:
		RETURN_FUZHAN_01_FAILED:
			return ["检测到意识中断。\nlevel_fuzhan_01 记忆样本未完成稳定。\n请重新进入该区域，并回收 3 个童年回忆样本。"]
		RETURN_FUZHAN_02_FAILED:
			return ["检测到 level_fuzhan_02 回收失败。\n当前区域记忆样本未完成稳定。\n请重新进入，并回收 3 个童年回忆样本。"]
	return []


static func apply_core_flags() -> void:
	var flags := ensure_state()
	flags["memory_fragments"] = REQUIRED_TOTAL
	flags["core_memory_anchor_stabilized"] = true
	flags["fuzhan_01_complete"] = true
	flags["fuzhan_02_complete"] = true
	flags["core_area"] = "herbal_tea_shop"
	GameManager.dream_runtime_flags = flags


static func _recalculate_total(flags: Dictionary) -> void:
	flags[KEY_MEMORY_FRAGMENTS] = int(flags.get(KEY_FUZHAN_01_COLLECTED, 0)) + int(flags.get(KEY_FUZHAN_02_COLLECTED, 0))
