# ============================================================
# Level03Data.gd - 关卡3数据类
# 新布局: 凉茶铺(0-1200) + 岭南街巷(1200-2400) + 过渡走廊(2400-3600) + 赛博城(3600-15600)
# ============================================================
extends Resource
class_name Level03Data

# ---- 阶段1: 凉茶铺对话 ----
@export var grandpa_dialogues: Array[Dictionary] = []
@export var grandpa_glitch_text: String = ""
@export var ming_realization_text: String = ""

# ---- 阶段2: 岭南街巷战斗 ----
@export var lingnan_enemy_count: int = 5
@export var lingnan_enemy_spawn_points: Array[Vector2] = []

# ---- 阶段3: 世界异化 ----
@export var codebuddy_broadcast_lines: Array[String] = []

# ---- 阶段4: 赛博城探索 ----
@export var ai_warning_1_text: String = ""
@export var ai_warning_2_text: String = ""

# ---- 阶段5: 异常数据光团（全局坐标，赛博城偏移+3600后） ----
@export var memory_echo_1_pos: Vector2 = Vector2(5384, 550)
@export var memory_echo_2_pos: Vector2 = Vector2(6560, 544)
@export var memory_echo_1_subtitle: String = ""
@export var memory_echo_1_codebuddy: String = ""
@export var memory_echo_2_subtitle: String = ""
@export var memory_echo_2_codebuddy: String = ""

# ---- 阶段6: 觉醒 ----
@export var awakening_monologue: String = ""
@export var override_protocol_text: String = ""
@export var next_level_path: String = "res://LevelModule/Formal/Level_04.tscn"

# ---- 敌人刷新点（赛博阶段，全局坐标已偏移+3600） ----
@export var cleaner_spawn_points: Array[Vector2] = []
@export var security_spawn_points: Array[Vector2] = []
