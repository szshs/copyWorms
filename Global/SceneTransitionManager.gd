# ============================================================
# SceneTransitionManager.gd - 统一场景切换与全局清理
#
# 职责:
#   1. 提供整树 change_scene_to_file 的唯一入口
#   2. 为 MainEntry 托管切换提供同一套全局清理
#   3. 在切换前调用关卡自定义 prepare_for_level_exit()
# ============================================================
extends Node

var is_transitioning: bool = false


func cleanup_for_transition(source: Node = null) -> void:
	_call_prepare_for_exit(source)
	var tree = get_tree()
	if tree != null:
		var current: Node = tree.current_scene
		if current != source:
			_call_prepare_for_exit(current)
		tree.paused = false

	GameManager.is_paused = false
	GameManager.is_game_over = false
	GameManager.player_ref = null
	GameManager.current_level = null
	GameManager.enemy_list.clear()
	GameManager.boss_target = null
	InputManager.force_unblock_all()
	MusicManager.clear_game_pause()
	var viewport := get_viewport()
	if viewport != null:
		viewport.gui_release_focus()


func _call_prepare_for_exit(node: Node) -> void:
	if node and is_instance_valid(node) and node.has_method("prepare_for_level_exit"):
		node.call("prepare_for_level_exit")


func request_scene_change(scene_path: String, source: Node = null) -> void:
	if is_transitioning:
		print("[SceneTransitionManager] 忽略重复切换请求: ", scene_path)
		return
	is_transitioning = true

	cleanup_for_transition(source)
	var tree = get_tree()
	if tree == null:
		push_warning("[SceneTransitionManager] SceneTree 不存在，无法切换场景: %s" % scene_path)
		is_transitioning = false
		return
	await tree.process_frame

	if scene_path == "" or not ResourceLoader.exists(scene_path):
		push_warning("[SceneTransitionManager] 目标场景不存在: %s" % scene_path)
		is_transitioning = false
		return

	print("[SceneTransitionManager] change_scene_to_file → ", scene_path)
	var err := tree.change_scene_to_file(scene_path)
	if err != OK:
		push_warning("[SceneTransitionManager] 切换失败: %s (err=%d)" % [scene_path, err])
		is_transitioning = false
		return

	await tree.process_frame
	is_transitioning = false


func request_checkpoint_restart() -> void:
	var tree = get_tree()
	var path := GameManager.checkpoint_scene_path
	if path == "" or not ResourceLoader.exists(path):
		print("[SceneTransitionManager] 无有效检查点，reload_current_scene")
		var fallback_current: Node = null
		if tree != null:
			fallback_current = tree.current_scene
		cleanup_for_transition(fallback_current)
		if tree != null:
			tree.reload_current_scene()
		return

	print("[SceneTransitionManager] 从检查点重新开始: %s (stage=%d)" % [path, GameManager.checkpoint_stage])
	var current: Node = null
	if tree != null:
		current = tree.current_scene
	if current and current.has_method("_switch_to_level"):
		if is_transitioning:
			return
		is_transitioning = true
		await current._switch_to_level(path)
		is_transitioning = false
	else:
		request_scene_change(path, current)
