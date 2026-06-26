# ============================================================
# LevelConfig.gd - 关卡数值配置资源类
# 在编辑器中创建 .tres 实例，填入具体数值
# ============================================================
extends Resource
class_name LevelConfig

@export_group("关卡信息")
@export var level_name: String = "未命名关卡"
@export var level_id: String = ""
@export var bgm_resource: AudioStream = null
@export var bgm_path: String = ""        # BGM 文件路径（备用，bgm_resource 优先）
@export var bg_color: Color = Color(0.1, 0.1, 0.2)

@export_group("摄像机")
@export var camera_limit_left: int = -10000
@export var camera_limit_right: int = 10000
@export var camera_limit_top: int = -10000
@export var camera_limit_bottom: int = 10000

@export_group("重生点")
@export var spawn_point: Vector2 = Vector2(100, 500)

@export_group("玩家")
@export var player_scene_path: String = "res://PlayerModule/Formal/Player_Warrior.tscn"
