# ============================================================
# Level_04_SceneBuilder.gd — 只创建必要容器
# ============================================================
extends RefCounted
class_name Level_04_SceneBuilder

var level: Level_04

func _init(parent: Level_04) -> void:
	level = parent

func build_all() -> void:
	level._dynamic_actors = level._get_or_create_child("DynamicActors", Node2D)
	_build_canvas_ui()


func _build_canvas_ui() -> void:
	var canvas = level._get_or_create_child("CanvasLayerUI", CanvasLayer)
	canvas.layer = 2
	canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	Level_04_UIBuilder.new(level, canvas).build_all()
