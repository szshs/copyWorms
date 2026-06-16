# ============================================================
# Level04Data.gd - 关卡4「维度侵蚀与空间崩塌」数据类
# 单坐标空间: 起始地(0-1200) + 战斗区(1200-2400) + 渗透区(2400-4800) + 撕裂区(4800-9600) + 终焉之域(9600-12800)
# ============================================================
extends Resource
class_name Level04Data

# ---- 阶段0: 起始地 ----
@export var anchor_narrative: String = "[color=goldenrod]前方的空间似乎不太稳定……空气中弥漫着异常的能量波动。[/color]"
@export var first_contact_text: String = "[color=red]警告：检测到维度异常！空间结构正在崩溃！[/color]"

# ---- 阶段1: 境域置换 —— 半对半空间硬切 ----
@export var domain_swap_text: String = "[color=cyan]维度壁垒正在破碎……两个世界开始重叠！[/color]"
@export var surface_enemy_count: int = 5
@export var surface_enemy_spawn_points: Array[Vector2] = []

# ---- 阶段2: 异质渗透 ----
@export var infiltration_text: String = "[color=darkviolet]异世界的碎片正在侵入当前空间……物理法则正在失效。[/color]"
@export var infiltration_enemy_count: int = 6
@export var infiltration_enemy_spawn_points: Array[Vector2] = []

# ---- 阶段3: 空间撕裂 ----
@export var space_tear_text: String = "[color=crimson]空间彻底撕裂！两个维度正在疯狂融合——[/color]"
@export var tear_enemy_count: int = 8
@export var tear_enemy_spawn_points: Array[Vector2] = []

# ---- 空间碎片（类似记忆光团，全局坐标） ----
@export var tear_fragment_1_pos: Vector2 = Vector2(6200, 480)
@export var tear_fragment_2_pos: Vector2 = Vector2(8200, 420)
@export var tear_fragment_1_text: String = "[color=cyan]碎片中回荡着低语：'……这不是终点……'[/color]"
@export var tear_fragment_2_text: String = "[color=cyan]碎片中映出扭曲的景象：两个世界在尽头交汇……[/color]"

# ---- 阶段4: 终焉之域 ----
@export var final_domain_text: String = "[color=white]所有的碎片开始向中心汇聚……一个孤立的平台正在形成。[/color]"
@export var boss_entrance_text: String = "[color=red][SHAKE] 终焉之主从裂隙中降临——[/color]"
@export var override_protocol_text: String = "[SYSTEM] 维度崩塌已完成 — 终焉序列启动\n按 Enter 继续"

# ---- 敌人刷新点（Surface/Infiltration/Tear 阶段） ----
@export var cleaner_spawn_points: Array[Vector2] = []
@export var security_spawn_points: Array[Vector2] = []

# ---- 转场 ----
@export var next_level_path: String = ""
