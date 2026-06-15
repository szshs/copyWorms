# ============================================================
# Level02Data.gd - 关卡2文案/谜题数据资源类
# 所有关卡2叙事文案、IDE对话、配置谜题、触发参数统一入此
# 在编辑器中创建 .tres 实例填入具体内容（Level02Data.tres）
# ============================================================
class_name Level02Data
extends Resource

@export_category("Dream Attic")
@export_multiline var attic_intro_text: String = ""
@export_multiline var window_text_l2: String = ""
@export_multiline var attic_door_text: String = ""

@export_category("Dream Street")
@export_multiline var rattan_chair_monologue: String = ""
@export var street_enemy_spawn_points: Array[Vector2] = []

@export_category("Cliff Loop")
@export_multiline var cliff_first_sight_text: String = ""
@export var cliff_safe_spawn: Vector2 = Vector2(3340, 550)
@export var interference_fall_threshold: int = 1
@export var dream_phone_echo_sender: String = "来自：妈妈"
@export_multiline var dream_phone_echo_text: String = ""
@export var wake_hold_required: float = 1.5

@export_category("Reality Room")
@export_multiline var wake_up_monologue: String = ""
@export_multiline var computer_locked_text: String = ""
@export_multiline var bed_locked_text: String = ""
@export var reality_phone_sender: String = "来自：妈妈"
@export_multiline var reality_phone_content: String = ""
@export_multiline var reality_phone_monologue: String = ""

@export_category("IDE Chat")
## 与 ide_texts 一一对应: "System" / "CodeBuddy" / "Ming"
@export var ide_speakers: Array[String] = []
@export_multiline var ide_texts: Array[String] = []

@export_category("Config Puzzle")
@export var config_item_ids: Array[String] = []
@export var config_item_labels: Array[String] = []
@export var config_initial_values: Array[String] = []
@export var config_target_values: Array[String] = []
## UI 显示用中文文案（与 initial/target_values 一一对应；为空时回退到 values 本身）
@export var config_initial_display: Array[String] = []
@export var config_target_display: Array[String] = []
@export var config_success_feedbacks: Array[String] = []
@export var recompilation_lines: Array[String] = []
@export_multiline var compile_success_text: String = ""
@export_multiline var bed_unlocked_text: String = ""

@export_category("Audio Hooks")
## 音效资源路径挂点：资源不存在时安全跳过，不阻断流程
@export var sfx_phone_vibrate_path: String = ""
@export var sfx_electric_noise_path: String = ""
@export var bgm_dream_warm_path: String = ""

@export_category("Ending")
@export_multiline var dream_rebuilt_text: String = "西关梦境 v2.0 重构完毕。意识正在下沉……闭上眼睛，回到梦里。"
@export var next_level_path: String = "res://LevelModule/Formal/Level_03.tscn"
