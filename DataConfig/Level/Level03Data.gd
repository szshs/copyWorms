# ============================================================
# Level03Data.gd - 关卡3文案/参数数据资源类
# 所有关卡3叙事文案、对话、敌人参数统一入此
# 在编辑器中创建 .tres 实例填入具体内容（Level03Data.tres）
# ============================================================
class_name Level03Data
extends Resource

@export_category("Tea Shop Dialogue")
## 爷爷对话链: [{speaker, text}] 6轮对话（Ming×3 + Grandpa×3）
@export var grandpa_dialogues: Array[Dictionary] = []
## 爷爷崩坏后文本
@export_multiline var grandpa_glitch_text: String = ""
## 明发现虚假后的反应文本
@export_multiline var ming_realization_text: String = ""

@export_category("Cyber Transition")
## CodeBuddy全频道广播文本（逐行显示）
@export var codebuddy_broadcast_lines: Array[String] = []

@export_category("AI Warnings")
## 1/3处AI阻挠弹窗文本
@export_multiline var ai_warning_1_text: String = ""
## 2/3处AI阻挠弹窗文本
@export_multiline var ai_warning_2_text: String = ""

@export_category("Memory Echoes")
## 光团1 - 三婆的声音字幕
@export_multiline var memory_echo_1_subtitle: String = ""
## 光团1 - CodeBuddy拦截文本
@export_multiline var memory_echo_1_codebuddy: String = ""
## 光团2 - 妈妈的声音字幕
@export_multiline var memory_echo_2_subtitle: String = ""
## 光团2 - CodeBuddy拦截文本
@export_multiline var memory_echo_2_codebuddy: String = ""

@export_category("Awakening")
## 觉醒独白全文
@export_multiline var awakening_monologue: String = ""
## 终局绿色系统文本
@export_multiline var override_protocol_text: String = ""

@export_category("Enemy Spawns")
## 清理程序出生点
@export var cleaner_spawn_points: Array[Vector2] = []
## 安保探照灯出生点
@export var security_spawn_points: Array[Vector2] = []
## 凉茶铺出生点
@export var tea_shop_spawn: Vector2 = Vector2(400, 550)
## 赛博城出生点
@export var cyber_spawn: Vector2 = Vector2(200, 550)
## 光团1位置
@export var memory_echo_1_pos: Vector2 = Vector2(8400, 550)
## 光团2位置
@export var memory_echo_2_pos: Vector2 = Vector2(10800, 550)

@export_category("Audio Hooks")
## 音效资源路径挂点：资源不存在时安全跳过
@export var sfx_code_rain_path: String = ""
@export var sfx_alarm_path: String = ""
@export var sfx_enter_key_path: String = ""

@export_category("Ending")
@export var next_level_path: String = "res://LevelModule/Formal/Level_04.tscn"
