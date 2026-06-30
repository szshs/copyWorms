@tool
extends Node2D

const ADJUST_Z_INDEX := -2
const ACTOR_SCAN_INTERVAL := 0.35
const STREAM_UPDATE_INTERVAL := 0.05
const TILE_WINDOW_RADIUS := 1
const MAX_TILE_WINDOW_KEYS := 9
const MAX_TILE_LOADS_PER_TICK := 4
const MAX_TILE_ATTACHES_PER_TICK := 3
const AIR_WALL_MAX_DOTS := 96
const MANIFEST_META := "map_stitch_manifest_path"
const TILE_SPRITE_META := "map_stitch_runtime_tile_sprite"
const TILE_SPRITE_PATH_META := "map_stitch_runtime_tile_path"
const DISPLAY_MODE_EDIT_PREVIEW := 0
const DISPLAY_MODE_RUNTIME_STREAM := 1
const PLAYER_GROUPS := ["player", "Player", "npc_library_player"]
const NPC_LIBRARY_RUNTIME_GATE_SINGLETON := "NpcLibraryRuntimeGate"
const NPC_LIBRARY_RUNTIME_GATE_PATH := "res://addons/npc_library_tool/runtime/npc_library_runtime_gate.gd"
const NPC_LIBRARY_MAP_RUNTIME_FEATURE := "pixelwork_map_stitch_runtime_v1"
const FREE_RUNTIME_COLLISION_LIMIT := 5

@export_group("Pixelwork")
@export var enable_runtime_regions: bool = false
@export_enum("Edit Preview", "Runtime Stream") var map_display_mode: int = DISPLAY_MODE_EDIT_PREVIEW
@export var editor_preview_tiles: bool = true
@export var show_adjust_ghost: bool = true
@export_range(0.0, 1.0, 0.01) var adjust_ghost_alpha: float = 0.45
@export var adjust_ghost_z_index: int = 130
@export var show_air_wall_hint: bool = true
@export var air_wall_hint_color: Color = Color(0.15, 0.72, 1.0, 0.86)
@export_range(0.05, 1.0, 0.01) var air_wall_hint_duration: float = 0.28
@export_range(1.0, 12.0, 0.5) var air_wall_hint_dot_radius: float = 2.5
@export_range(4.0, 32.0, 0.5) var air_wall_hint_dot_spacing: float = 9.0
@export_range(12.0, 200.0, 1.0) var air_wall_hint_contact_width: float = 96.0
@export var air_wall_hint_z_index: int = 140

var _tile_records: Array = []
var _tile_bounds := {}
var _tile_margin_pixels := 512.0
var _collision_records: Array = []
var _adjust_records: Array = []
var _collision_records_by_tile := {}
var _adjust_records_by_tile := {}
var _region_collision_objects: Array = []
var _region_adjust_areas: Array = []
var _region_collision_objects_by_tile := {}
var _region_adjust_areas_by_tile := {}
var _actors := {}
var _visual_state := {}
var _adjust_ghosts := {}
var _air_wall_hint_root: Node2D = null
var _air_wall_hint_time_left := 0.0
var _air_wall_hint_key := ""
var _actor_scan_timer := 0.0
var _stream_timer := 0.0
var _active_region_tile_key := ""
var _enabled_region_tile_keys := {}
var _regions_enabled_applied := false
var _runtime_gate_warning_shown := false
var _free_collision_warning_shown := false
var _free_collision_limit_warning_shown := false

func _ready() -> void:
	process_priority = 1000
	_hide_annotation_visuals()
	_load_tile_manifest()
	if not Engine.is_editor_hint():
		_clear_layer_tile_sprites()
	_collect_runtime_shapes()
	var regions_enabled_now := _runtime_regions_enabled()
	_set_runtime_regions_enabled(regions_enabled_now)
	var tile_updates_enabled: bool = _tile_updates_enabled()
	set_process(tile_updates_enabled and not _tile_records.is_empty())
	set_physics_process(not Engine.is_editor_hint() and regions_enabled_now and (not _collision_records.is_empty() or not _adjust_records.is_empty()))
	if tile_updates_enabled:
		_update_visible_tiles(true)

func _exit_tree() -> void:
	_clear_all_adjust_ghosts()
	_clear_air_wall_hint()
	for index in range(_tile_records.size()):
		var record: Dictionary = _tile_records[index]
		_unload_tile(record)
		_tile_records[index] = record

func _process(delta: float) -> void:
	if not _tile_updates_enabled():
		return
	_update_air_wall_hint(delta)
	_stream_timer -= delta
	if _stream_timer <= 0.0:
		_stream_timer = STREAM_UPDATE_INTERVAL
		_update_visible_tiles(false)

func _hide_annotation_visuals() -> void:
	var annotations: CanvasItem = get_node_or_null("Annotations") as CanvasItem
	if annotations != null:
		annotations.visible = false

func _load_tile_manifest() -> void:
	_tile_records.clear()
	_tile_bounds.clear()
	var manifest_path := String(get_meta(MANIFEST_META, ""))
	if manifest_path.is_empty() or not FileAccess.file_exists(manifest_path):
		return
	var manifest_text := FileAccess.get_file_as_string(manifest_path)
	var parsed = JSON.parse_string(manifest_text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Pixelwork map manifest is invalid: %s" % manifest_path)
		return
	var manifest: Dictionary = parsed
	var resource_root: String = String(manifest.get("resource_root", ""))
	var layers = manifest.get("layers", [])
	if typeof(layers) != TYPE_ARRAY:
		return
	for layer_data in layers:
		if typeof(layer_data) != TYPE_DICTIONARY:
			continue
		_load_manifest_layer(layer_data as Dictionary, resource_root)

func _load_manifest_layer(layer_data: Dictionary, resource_root: String) -> void:
	var layer_id: String = String(layer_data.get("id", ""))
	var layer_node: Node2D = get_node_or_null(layer_id) as Node2D
	if layer_node == null:
		return
	layer_node.z_index = int(layer_data.get("order", layer_node.z_index))
	layer_node.visible = bool(layer_data.get("visible", layer_node.visible))
	var tiles = layer_data.get("tiles", [])
	if typeof(tiles) != TYPE_ARRAY:
		return
	for tile_data in tiles:
		if typeof(tile_data) != TYPE_DICTIONARY:
			continue
		var tile: Dictionary = tile_data
		var pixel = tile.get("pixel", {})
		if typeof(pixel) != TYPE_DICTIONARY:
			continue
		var pixel_data: Dictionary = pixel
		var rect := Rect2(
			Vector2(float(pixel_data.get("x", 0.0)), float(pixel_data.get("y", 0.0))),
			Vector2(float(pixel_data.get("width", 0.0)), float(pixel_data.get("height", 0.0)))
		)
		if not rect.has_area():
			continue
		var key: String = String(tile.get("key", ""))
		var image_path: String = _manifest_resource_path(resource_root, String(tile.get("image", "")))
		if image_path.is_empty():
			continue
		var editor_preview_path: String = _manifest_resource_path(resource_root, String(tile.get("editor_preview_image", "")))
		_tile_margin_pixels = max(_tile_margin_pixels, max(rect.size.x, rect.size.y))
		_tile_records.append({
			"key": key,
			"name": String(tile.get("name", "tile")),
			"layer": layer_id,
			"layer_node": layer_node,
			"path": image_path,
			"editor_preview_path": editor_preview_path,
			"rect": rect,
			"visible": bool(layer_data.get("visible", true)),
			"texture": null,
			"sprite": null,
			"loading": false,
			"loading_path": "",
			"loaded_path": "",
			"sprite_path": "",
			"wanted": false,
		})
		if key.is_empty():
			continue
		if _tile_bounds.has(key):
			var existing: Rect2 = _tile_bounds[key]
			_tile_bounds[key] = existing.merge(rect)
		else:
			_tile_bounds[key] = rect

func _manifest_resource_path(resource_root: String, image_path: String) -> String:
	if image_path.is_empty():
		return ""
	if image_path.begins_with("res://") or image_path.begins_with("user://"):
		return image_path
	return "res://%s/%s" % [resource_root, image_path]

func _update_visible_tiles(force: bool) -> void:
	var load_all: bool = not _runtime_tile_streaming_enabled()
	var load_keys: Dictionary = {}
	if _is_editor_edit_preview():
		load_all = true
	elif not load_all:
		load_keys = _runtime_tile_window_keys()
	var priority_center := _stream_priority_center()
	var load_candidates: Array = []
	var attach_candidates: Array = []
	for index in range(_tile_records.size()):
		var record: Dictionary = _tile_records[index]
		var rect: Rect2 = record.get("rect", Rect2())
		var key: String = String(record.get("key", ""))
		var is_visible_layer: bool = bool(record.get("visible", true))
		var should_load := is_visible_layer and (load_all or load_keys.has(key))
		var should_keep := should_load
		record["wanted"] = should_load
		if should_load:
			_sync_tile_path_state(record)
		_poll_tile_load(record)
		if should_load:
			var distance := _tile_distance_sq(rect, priority_center)
			if record.get("texture", null) != null and not _tile_sprite_is_valid(record):
				attach_candidates.append({"index": index, "distance": distance})
			elif record.get("texture", null) == null and not bool(record.get("loading", false)):
				load_candidates.append({"index": index, "distance": distance})
		if not should_keep and (force or _tile_has_loaded_content(record)):
			_unload_tile(record)
		_tile_records[index] = record
	_process_tile_load_candidates(load_candidates, MAX_TILE_LOADS_PER_TICK)
	_process_tile_attach_candidates(attach_candidates, MAX_TILE_ATTACHES_PER_TICK)

func _is_editor_edit_preview() -> bool:
	return Engine.is_editor_hint() and map_display_mode == DISPLAY_MODE_EDIT_PREVIEW

func _tile_updates_enabled() -> bool:
	return not Engine.is_editor_hint() or editor_preview_tiles

func _runtime_tile_streaming_enabled() -> bool:
	if Engine.is_editor_hint() and map_display_mode != DISPLAY_MODE_RUNTIME_STREAM:
		return false
	if _npc_library_runtime_available():
		return true
	if map_display_mode == DISPLAY_MODE_RUNTIME_STREAM:
		_warn_runtime_gate_locked("Runtime Stream")
	return false

func _runtime_regions_enabled() -> bool:
	if not enable_runtime_regions:
		return false
	if _npc_library_runtime_available():
		return true
	return _free_collision_regions_enabled()

func _runtime_full_features_enabled() -> bool:
	return enable_runtime_regions and _npc_library_runtime_available()

func _free_collision_regions_enabled() -> bool:
	if _collision_records.is_empty():
		_warn_runtime_gate_locked("Enable Runtime Regions")
		return false
	if _collision_records.size() > FREE_RUNTIME_COLLISION_LIMIT:
		_warn_free_collision_limit_exceeded()
		return false
	_warn_free_collision_limited()
	return true

func _npc_library_runtime_available() -> bool:
	var autoload_key := "autoload/%s" % NPC_LIBRARY_RUNTIME_GATE_SINGLETON
	if is_inside_tree():
		var gate := get_node_or_null("/root/%s" % NPC_LIBRARY_RUNTIME_GATE_SINGLETON)
		if gate != null:
			if gate.has_method("allows_pixelwork_map_stitch_runtime"):
				return bool(gate.call("allows_pixelwork_map_stitch_runtime"))
			if gate.has_method("has_feature"):
				return bool(gate.call("has_feature", NPC_LIBRARY_MAP_RUNTIME_FEATURE))
			return true
	if ProjectSettings.has_setting(autoload_key):
		var value := String(ProjectSettings.get_setting(autoload_key, ""))
		return value.find(NPC_LIBRARY_RUNTIME_GATE_PATH) >= 0 and ResourceLoader.exists(NPC_LIBRARY_RUNTIME_GATE_PATH)
	return false

func _warn_runtime_gate_locked(feature_name: String) -> void:
	if _runtime_gate_warning_shown:
		return
	_runtime_gate_warning_shown = true
	push_warning("%s requires the NPC Library Tool runtime gate. Enable res://addons/npc_library_tool/plugin.cfg to unlock Pixelwork runtime map features; this scene will load the full map instead." % feature_name)

func _warn_free_collision_limited() -> void:
	if _free_collision_warning_shown:
		return
	_free_collision_warning_shown = true
	push_warning("Pixelwork free runtime enabled limited collision: up to 5 collision bodies are active. 需要 NPC Library Tool 满血版才能解锁完整碰撞、调节层和动态地图加载。")

func _warn_free_collision_limit_exceeded() -> void:
	if _free_collision_limit_warning_shown:
		return
	_free_collision_limit_warning_shown = true
	push_warning("Pixelwork free runtime found %d collision bodies, but the free limit is %d. Runtime collision is disabled; 需要 NPC Library Tool 满血版才能解锁完整碰撞、调节层和动态地图加载。" % [_collision_records.size(), FREE_RUNTIME_COLLISION_LIMIT])

func _stream_margin_pixels() -> float:
	return _tile_margin_pixels

func _stream_priority_center() -> Vector2:
	for key in _actors.keys():
		var state: Dictionary = _actors[key]
		if not bool(state.get("primary", false)):
			continue
		var actor := _actor_from_state(state)
		if actor != null and is_instance_valid(actor):
			return to_local(actor.global_position)
	var camera: Camera2D = get_viewport().get_camera_2d() if get_viewport() != null else null
	if camera != null:
		return to_local(camera.global_position)
	var fallback_key := _fallback_stream_tile_key()
	if not fallback_key.is_empty() and _tile_bounds.has(fallback_key):
		var rect: Rect2 = _tile_bounds[fallback_key]
		return rect.get_center()
	return Vector2.ZERO

func _runtime_tile_window_keys() -> Dictionary:
	var keys := {}
	var focus := _stream_priority_center()
	var forced_keys := _runtime_forced_tile_keys()
	for key in forced_keys:
		keys[String(key)] = true
	var candidates: Array = []
	for key in _tile_bounds.keys():
		var tile_key := String(key)
		if keys.has(tile_key):
			continue
		var rect: Rect2 = _tile_bounds[key]
		candidates.append({"key": tile_key, "distance": _tile_distance_sq(rect, focus)})
	var limit: int = int(max(1, (TILE_WINDOW_RADIUS * 2 + 1) * (TILE_WINDOW_RADIUS * 2 + 1)))
	limit = int(min(limit, MAX_TILE_WINDOW_KEYS))
	while keys.size() < limit and not candidates.is_empty():
		var candidate_position := _best_tile_candidate_position(candidates)
		if candidate_position < 0:
			break
		var candidate: Dictionary = candidates[candidate_position]
		keys[String(candidate.get("key", ""))] = true
		candidates.remove_at(candidate_position)
	return keys

func _runtime_forced_tile_keys() -> Array:
	var out: Array = []
	for key in _actors.keys():
		var state: Dictionary = _actors[key]
		if not bool(state.get("primary", false)):
			continue
		var actor := _actor_from_state(state)
		if actor == null:
			continue
		_append_unique_strings(out, _actor_tile_keys(actor))
	if out.is_empty():
		var fallback_key := _fallback_stream_tile_key()
		if not fallback_key.is_empty():
			out.append(fallback_key)
	return out

func _actor_tile_keys(actor: Node2D) -> Array:
	var keys: Array = []
	for point in _actor_foot_probe_points(actor):
		var key := _tile_key_at_local_position(to_local(point))
		if not key.is_empty() and not keys.has(key):
			keys.append(key)
	var probe_rect := _actor_tile_probe_rect(actor)
	if probe_rect.has_area():
		for key in _tile_bounds.keys():
			var tile_key := String(key)
			if keys.has(tile_key):
				continue
			var rect: Rect2 = _tile_bounds[key]
			if rect.intersects(probe_rect, true):
				keys.append(tile_key)
	if keys.is_empty():
		var fallback_key := _tile_key_at_local_position(to_local(actor.global_position))
		if not fallback_key.is_empty():
			keys.append(fallback_key)
	return keys

func _append_unique_strings(target: Array, values: Array) -> void:
	for value in values:
		var text := String(value)
		if not text.is_empty() and not target.has(text):
			target.append(text)

func _actor_tile_probe_rect(actor: Node2D) -> Rect2:
	var points := PackedVector2Array()
	for polygon in _actor_foot_polygons(actor):
		for point in polygon:
			points.append(to_local(point))
	if points.is_empty():
		points.append(to_local(actor.global_position))
	var rect := _rect_from_points(points)
	var margin := _actor_tile_probe_margin()
	if rect.has_area():
		return rect.grow(margin)
	var center: Vector2 = points[0]
	return Rect2(center - Vector2(margin, margin), Vector2(margin * 2.0, margin * 2.0))

func _actor_tile_probe_margin() -> float:
	return max(8.0, min(_tile_margin_pixels * 0.03, 48.0))

func _runtime_origin_tile_keys() -> Array:
	var out: Array = []
	for key in _actors.keys():
		var state: Dictionary = _actors[key]
		if not bool(state.get("primary", false)):
			continue
		var actor := _actor_from_state(state)
		if actor == null:
			continue
		var tile_key := _tile_key_for_actor(actor)
		if not tile_key.is_empty() and not out.has(tile_key):
			out.append(tile_key)
	if out.is_empty():
		var fallback_key := _fallback_stream_tile_key()
		if not fallback_key.is_empty():
			out.append(fallback_key)
	return out

func _tile_window_keys(origin_key: String) -> Dictionary:
	var keys := {}
	if origin_key.is_empty() or not _tile_bounds.has(origin_key):
		return keys
	keys[origin_key] = true
	var origin_rect: Rect2 = _tile_bounds[origin_key]
	var candidates: Array = []
	for key in _tile_bounds.keys():
		var tile_key := String(key)
		if tile_key == origin_key:
			continue
		var rect: Rect2 = _tile_bounds[key]
		candidates.append({"key": tile_key, "distance": _tile_distance_sq(rect, origin_rect.get_center())})
	var limit: int = int(max(1, (TILE_WINDOW_RADIUS * 2 + 1) * (TILE_WINDOW_RADIUS * 2 + 1)))
	while keys.size() < min(limit, MAX_TILE_WINDOW_KEYS) and not candidates.is_empty():
		var candidate_position := _best_tile_candidate_position(candidates)
		if candidate_position < 0:
			break
		var candidate: Dictionary = candidates[candidate_position]
		keys[String(candidate.get("key", ""))] = true
		candidates.remove_at(candidate_position)
	return keys

func _fallback_stream_tile_key() -> String:
	var camera: Camera2D = get_viewport().get_camera_2d() if get_viewport() != null else null
	if camera != null:
		var camera_key := _tile_key_at_local_position(to_local(camera.global_position))
		if not camera_key.is_empty():
			return camera_key
	if not _active_region_tile_key.is_empty():
		return _active_region_tile_key
	if not _tile_bounds.is_empty():
		return String(_tile_bounds.keys()[0])
	return ""

func _tile_distance_sq(rect: Rect2, point: Vector2) -> float:
	return rect.get_center().distance_squared_to(point)

func _visible_local_rect() -> Rect2:
	var viewport := get_viewport()
	if viewport == null:
		return Rect2()
	var viewport_rect := viewport.get_visible_rect()
	if not viewport_rect.has_area():
		return Rect2()
	var inverse_canvas := viewport.get_canvas_transform().affine_inverse()
	var points := PackedVector2Array()
	points.append(to_local(inverse_canvas * viewport_rect.position))
	points.append(to_local(inverse_canvas * (viewport_rect.position + Vector2(viewport_rect.size.x, 0.0))))
	points.append(to_local(inverse_canvas * (viewport_rect.position + viewport_rect.size)))
	points.append(to_local(inverse_canvas * (viewport_rect.position + Vector2(0.0, viewport_rect.size.y))))
	return _rect_from_points(points)

func _fallback_stream_rect() -> Rect2:
	var camera: Camera2D = get_viewport().get_camera_2d() if get_viewport() != null else null
	if camera != null:
		var center := to_local(camera.global_position)
		var key := _tile_key_at_local_position(center)
		if not key.is_empty() and _tile_bounds.has(key):
			return _tile_bounds[key]
	if not _tile_bounds.is_empty():
		var first_key: String = String(_tile_bounds.keys()[0])
		return _tile_bounds[first_key]
	return Rect2()

func _rect_from_points(points: PackedVector2Array) -> Rect2:
	if points.is_empty():
		return Rect2()
	var min_point: Vector2 = points[0]
	var max_point: Vector2 = points[0]
	for point in points:
		min_point.x = min(min_point.x, point.x)
		min_point.y = min(min_point.y, point.y)
		max_point.x = max(max_point.x, point.x)
		max_point.y = max(max_point.y, point.y)
	return Rect2(min_point, max_point - min_point)

func _tile_texture_path(record: Dictionary) -> String:
	if _is_editor_edit_preview():
		var preview_path: String = String(record.get("editor_preview_path", ""))
		if not preview_path.is_empty():
			return preview_path
	return String(record.get("path", ""))

func _sync_tile_path_state(record: Dictionary) -> void:
	var desired_path: String = _tile_texture_path(record)
	if desired_path.is_empty():
		return
	var loading_path: String = String(record.get("loading_path", ""))
	var loaded_path: String = String(record.get("loaded_path", ""))
	var sprite_path: String = String(record.get("sprite_path", ""))
	var stale: bool = false
	if bool(record.get("loading", false)) and not loading_path.is_empty() and loading_path != desired_path:
		stale = true
	if not loaded_path.is_empty() and loaded_path != desired_path:
		stale = true
	if not sprite_path.is_empty() and sprite_path != desired_path:
		stale = true
	if stale:
		record["loading"] = false
		record["loading_path"] = ""
		_unload_tile(record)

func _request_tile_load(record: Dictionary, can_start: bool) -> bool:
	var existing: Sprite2D = record.get("sprite", null) as Sprite2D
	if existing != null and is_instance_valid(existing):
		return false
	if record.get("texture", null) != null:
		return false
	if bool(record.get("loading", false)):
		_poll_tile_load(record)
		return false
	if not can_start:
		return false
	var path: String = _tile_texture_path(record)
	if path.is_empty():
		return false
	var error: int = ResourceLoader.load_threaded_request(path, "Texture2D", true, ResourceLoader.CACHE_MODE_REUSE)
	if error != OK and error != ERR_BUSY:
		record["loading"] = false
		record["loading_path"] = ""
		return false
	record["loading"] = true
	record["loading_path"] = path
	_poll_tile_load(record)
	return true

func _process_tile_load_candidates(candidates: Array, budget: int) -> void:
	var remaining: int = int(min(budget, candidates.size()))
	while remaining > 0 and not candidates.is_empty():
		var candidate_position := _best_tile_candidate_position(candidates)
		if candidate_position < 0:
			return
		var candidate: Dictionary = candidates[candidate_position]
		var index: int = int(candidate.get("index", -1))
		if index >= 0 and index < _tile_records.size():
			var record: Dictionary = _tile_records[index]
			_request_tile_load(record, true)
			_tile_records[index] = record
		candidates.remove_at(candidate_position)
		remaining -= 1

func _process_tile_attach_candidates(candidates: Array, budget: int) -> void:
	var remaining: int = int(min(budget, candidates.size()))
	while remaining > 0 and not candidates.is_empty():
		var candidate_position := _best_tile_candidate_position(candidates)
		if candidate_position < 0:
			return
		var candidate: Dictionary = candidates[candidate_position]
		var index: int = int(candidate.get("index", -1))
		if index >= 0 and index < _tile_records.size():
			var record: Dictionary = _tile_records[index]
			if bool(record.get("wanted", false)):
				_ensure_tile_sprite(record)
			_tile_records[index] = record
		candidates.remove_at(candidate_position)
		remaining -= 1

func _best_tile_candidate_position(candidates: Array) -> int:
	var best_position := -1
	var best_distance := 1.0e30
	for position in range(candidates.size()):
		var candidate: Dictionary = candidates[position]
		var distance: float = float(candidate.get("distance", 1.0e30))
		if distance < best_distance:
			best_distance = distance
			best_position = position
	return best_position

func _poll_tile_load(record: Dictionary) -> void:
	if not bool(record.get("loading", false)):
		return
	var path: String = String(record.get("loading_path", ""))
	if path.is_empty():
		path = _tile_texture_path(record)
	if path.is_empty():
		record["loading"] = false
		record["loading_path"] = ""
		return
	var status: int = ResourceLoader.load_threaded_get_status(path)
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		var texture: Texture2D = ResourceLoader.load_threaded_get(path) as Texture2D
		record["loading"] = false
		record["loading_path"] = ""
		if texture != null:
			var desired_path: String = _tile_texture_path(record)
			if path == desired_path:
				record["texture"] = texture
				record["loaded_path"] = path
	elif status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		record["loading"] = false
		record["loading_path"] = ""

func _ensure_tile_sprite(record: Dictionary) -> void:
	var existing: Sprite2D = record.get("sprite", null) as Sprite2D
	if existing != null and is_instance_valid(existing):
		return
	var layer_node: Node = record.get("layer_node", null) as Node
	if layer_node == null or not is_instance_valid(layer_node):
		return
	var texture: Texture2D = record.get("texture", null) as Texture2D
	if texture == null:
		return
	var path: String = String(record.get("loaded_path", ""))
	if path.is_empty():
		path = _tile_texture_path(record)
	if path != _tile_texture_path(record):
		return
	var rect: Rect2 = record.get("rect", Rect2())
	var sprite := Sprite2D.new()
	sprite.name = String(record.get("name", "tile"))
	sprite.centered = false
	sprite.position = rect.position
	sprite.texture = texture
	sprite.set_meta(TILE_SPRITE_META, true)
	sprite.set_meta(TILE_SPRITE_PATH_META, path)
	var texture_size: Vector2 = texture.get_size()
	if texture_size.x > 0.0 and texture_size.y > 0.0:
		sprite.scale = Vector2(rect.size.x / texture_size.x, rect.size.y / texture_size.y)
	layer_node.add_child(sprite)
	record["sprite"] = sprite
	record["sprite_path"] = path

func _tile_sprite_is_valid(record: Dictionary) -> bool:
	var sprite: Node = record.get("sprite", null) as Node
	if sprite == null or not is_instance_valid(sprite):
		return false
	var desired_path: String = _tile_texture_path(record)
	var sprite_path: String = String(record.get("sprite_path", ""))
	if sprite_path.is_empty() and sprite.has_meta(TILE_SPRITE_PATH_META):
		sprite_path = String(sprite.get_meta(TILE_SPRITE_PATH_META, ""))
	return desired_path.is_empty() or sprite_path.is_empty() or sprite_path == desired_path

func _tile_has_loaded_content(record: Dictionary) -> bool:
	return _tile_sprite_is_valid(record) or record.get("texture", null) != null

func _unload_tile(record: Dictionary) -> void:
	record["wanted"] = false
	var sprite: Node = record.get("sprite", null) as Node
	if sprite != null and is_instance_valid(sprite):
		sprite.queue_free()
	record["sprite"] = null
	record["sprite_path"] = ""
	if not bool(record.get("loading", false)):
		record["texture"] = null
		record["loaded_path"] = ""
		record["loading_path"] = ""

func _clear_layer_tile_sprites() -> void:
	var layer_nodes: Dictionary = {}
	var tile_names: Dictionary = {}
	for record_value in _tile_records:
		var record: Dictionary = record_value as Dictionary
		var layer_node: Node = record.get("layer_node", null) as Node
		if layer_node != null and is_instance_valid(layer_node):
			layer_nodes[int(layer_node.get_instance_id())] = layer_node
		var tile_name: String = String(record.get("name", ""))
		if not tile_name.is_empty():
			tile_names[tile_name] = true
	for layer_value in layer_nodes.values():
		var layer_node: Node = layer_value as Node
		if layer_node == null or not is_instance_valid(layer_node):
			continue
		for child_value in layer_node.get_children():
			var child: Node = child_value as Node
			if child == null or not (child is Sprite2D):
				continue
			if bool(child.get_meta(TILE_SPRITE_META, false)) or tile_names.has(String(child.name)):
				child.queue_free()

func _collect_runtime_shapes() -> void:
	_collision_records.clear()
	_adjust_records.clear()
	_collision_records_by_tile.clear()
	_adjust_records_by_tile.clear()
	_region_collision_objects.clear()
	_region_adjust_areas.clear()
	_region_collision_objects_by_tile.clear()
	_region_adjust_areas_by_tile.clear()
	_enabled_region_tile_keys.clear()
	var annotations := get_node_or_null("Annotations")
	if annotations == null:
		return
	var collision_root := annotations.get_node_or_null("collision")
	if collision_root != null:
		_collect_collision_polygons(collision_root, _collision_records, "")
	var adjust_root := annotations.get_node_or_null("adjust")
	if adjust_root != null:
		_collect_collision_polygons(adjust_root, _adjust_records, "")
	_build_shape_record_index(_collision_records, _collision_records_by_tile)
	_build_shape_record_index(_adjust_records, _adjust_records_by_tile)
	_build_region_record_index(_region_collision_objects, _region_collision_objects_by_tile)
	_build_region_record_index(_region_adjust_areas, _region_adjust_areas_by_tile)

func _build_shape_record_index(records: Array, target: Dictionary) -> void:
	target.clear()
	for record in records:
		var shape_record: Dictionary = record as Dictionary
		var tile_key: String = String(shape_record.get("tile_key", ""))
		var bucket: Array = target.get(tile_key, [])
		bucket.append(shape_record)
		target[tile_key] = bucket

func _build_region_record_index(records: Array, target: Dictionary) -> void:
	target.clear()
	for record in records:
		var region_record: Dictionary = record as Dictionary
		var tile_key: String = String(region_record.get("tile_key", ""))
		var bucket: Array = target.get(tile_key, [])
		bucket.append(region_record)
		target[tile_key] = bucket

func _collect_collision_polygons(node: Node, target: Array, inherited_tile_key: String) -> void:
	var tile_key := inherited_tile_key
	if node.has_meta("map_stitch_tile_key"):
		tile_key = String(node.get_meta("map_stitch_tile_key", ""))
	if node is StaticBody2D:
		_region_collision_objects.append({"node": node, "tile_key": tile_key})
	elif node is Area2D:
		_region_adjust_areas.append({"node": node, "tile_key": tile_key})
	if node is CollisionPolygon2D:
		var polygon: CollisionPolygon2D = node as CollisionPolygon2D
		if polygon.polygon.size() >= 3:
			target.append({"shape": polygon, "tile_key": tile_key})
	for child in node.get_children():
		if child is Node:
			_collect_collision_polygons(child, target, tile_key)

func _set_runtime_regions_enabled(enabled: bool) -> void:
	_regions_enabled_applied = enabled
	if not enabled:
		_restore_all_adjustments()
		for tile_key in _all_region_tile_keys().keys():
			_apply_region_tile_key(String(tile_key), false)
		_enabled_region_tile_keys.clear()
		return
	var next_keys: Dictionary = _desired_region_tile_keys() if enabled else {}
	for tile_key in _enabled_region_tile_keys.keys():
		if not next_keys.has(tile_key):
			_apply_region_tile_key(String(tile_key), false)
	for tile_key in next_keys.keys():
		if not _enabled_region_tile_keys.has(tile_key):
			_apply_region_tile_key(String(tile_key), true)
	_enabled_region_tile_keys = next_keys

func _desired_region_tile_keys() -> Dictionary:
	if not _runtime_full_features_enabled():
		return _free_collision_region_tile_keys()
	var keys := {"": true}
	var window := _runtime_tile_window_keys()
	for key in window.keys():
		keys[String(key)] = true
	return keys

func _free_collision_region_tile_keys() -> Dictionary:
	var keys := {}
	for tile_key in _region_collision_objects_by_tile.keys():
		keys[String(tile_key)] = true
	return keys

func _all_region_tile_keys() -> Dictionary:
	var keys := {}
	for tile_key in _region_collision_objects_by_tile.keys():
		keys[String(tile_key)] = true
	for tile_key in _region_adjust_areas_by_tile.keys():
		keys[String(tile_key)] = true
	return keys

func _apply_region_tile_key(tile_key: String, active: bool) -> void:
	for record in _region_records_for_tile(_region_collision_objects_by_tile, tile_key):
		var collision_object: CollisionObject2D = (record as Dictionary).get("node", null) as CollisionObject2D
		if collision_object == null or not is_instance_valid(collision_object):
			continue
		collision_object.collision_layer = int(collision_object.get_meta("map_stitch_collision_layer", 1)) if active else 0
		collision_object.collision_mask = int(collision_object.get_meta("map_stitch_collision_mask", 1)) if active else 0
	var adjust_active: bool = active and _runtime_full_features_enabled()
	for record in _region_records_for_tile(_region_adjust_areas_by_tile, tile_key):
		var area: Area2D = (record as Dictionary).get("node", null) as Area2D
		if area == null or not is_instance_valid(area):
			continue
		area.collision_layer = int(area.get_meta("map_stitch_collision_layer", 1)) if adjust_active else 0
		area.collision_mask = int(area.get_meta("map_stitch_collision_mask", 1)) if adjust_active else 0
		area.monitoring = adjust_active
		area.monitorable = adjust_active

func _region_records_for_tile(index: Dictionary, tile_key: String) -> Array:
	var records: Array = index.get(tile_key, [])
	return records

func _physics_process(delta: float) -> void:
	var regions_enabled_now := _runtime_regions_enabled()
	if _regions_enabled_applied != regions_enabled_now:
		_set_runtime_regions_enabled(regions_enabled_now)
	if not regions_enabled_now:
		return
	_actor_scan_timer -= delta
	var scanned := false
	if _actor_scan_timer <= 0.0:
		_actor_scan_timer = ACTOR_SCAN_INTERVAL
		_refresh_runtime_actors()
		scanned = true
	_update_active_region_tile()
	if scanned:
		_set_runtime_regions_enabled(regions_enabled_now)
	_update_runtime_actors()

func _refresh_runtime_actors() -> void:
	if not is_inside_tree():
		return
	var tree = get_tree()
	if tree == null:
		return
	var root: Node = tree.current_scene
	if root == null:
		root = tree.root
	if root == null:
		return
	var detection_keys := _runtime_tile_window_keys()
	_collect_actor_candidates(root, detection_keys)
	_prune_runtime_actors(detection_keys)

func _collect_actor_candidates(node: Node, detection_keys: Dictionary) -> void:
	if node is Node2D:
		var actor: Node2D = node as Node2D
		if _is_primary_runtime_actor(node):
			_register_actor(actor, true)
			return
		if _is_npc_runtime_actor(node) and _actor_is_in_detection_keys(actor, detection_keys):
			_register_actor(actor, false)
			return
	if _is_annotation_node(node):
		return
	for child in node.get_children():
		if child is Node:
			_collect_actor_candidates(child, detection_keys)

func _is_primary_runtime_actor(node: Node) -> bool:
	if node == self or not (node is Node2D) or _is_annotation_node(node):
		return false
	for group_name in PLAYER_GROUPS:
		if node.is_in_group(group_name):
			return true
	if _get_bool_property(node, "player_control_enabled", false):
		return true
	return _primary_actor_name_matches(node) and not _visual_targets(node as Node2D).is_empty()

func _is_npc_runtime_actor(node: Node) -> bool:
	if node == self or not (node is Node2D) or _is_annotation_node(node):
		return false
	if _is_primary_runtime_actor(node):
		return false
	for group_name in ["npc", "NPC", "enemy", "Enemy"]:
		if node.is_in_group(group_name):
			return true
	if node is CharacterBody2D:
		return true
	if _npc_actor_name_matches(node):
		return not _visual_targets(node as Node2D).is_empty()
	return node.get_node_or_null("InteractArea") is Area2D and not _visual_targets(node as Node2D).is_empty()

func _primary_actor_name_matches(node: Node) -> bool:
	var name_text := String(node.name).to_lower()
	return name_text.contains("player") or name_text.contains("hero") or name_text.contains("main")

func _npc_actor_name_matches(node: Node) -> bool:
	var name_text := String(node.name).to_lower()
	return name_text.contains("npc") or name_text.contains("enemy") or name_text.contains("mob") or name_text.contains("villager") or name_text.contains("character")

func _actor_is_in_detection_keys(actor: Node2D, detection_keys: Dictionary) -> bool:
	var actor_key := _tile_key_for_actor(actor)
	return not actor_key.is_empty() and detection_keys.has(actor_key)

func _actor_from_state(state: Dictionary) -> Node2D:
	var node_value: Variant = state.get("node", null)
	if node_value == null:
		return null
	if not is_instance_valid(node_value):
		return null
	if not (node_value is Node2D):
		return null
	return node_value as Node2D

func _prune_runtime_actors(detection_keys: Dictionary) -> void:
	for key in _actors.keys():
		var state: Dictionary = _actors[key]
		var actor := _actor_from_state(state)
		if actor == null:
			_clear_adjust_ghost_for_key(int(key))
			_actors.erase(key)
			continue
		if bool(state.get("primary", false)):
			continue
		if not _actor_is_in_detection_keys(actor, detection_keys):
			if bool(state.get("adjusted", false)):
				_restore_adjust(actor)
			_actors.erase(key)

func _is_annotation_node(node: Node) -> bool:
	var annotations := get_node_or_null("Annotations")
	return annotations != null and (node == annotations or annotations.is_ancestor_of(node))

func _register_actor(actor: Node2D, primary: bool) -> void:
	var key: int = int(actor.get_instance_id())
	if _actors.has(key):
		var state: Dictionary = _actors[key]
		state["primary"] = bool(state.get("primary", false)) or primary
		_actors[key] = state
		return
	_actors[key] = {"node": actor, "previous_pos": actor.global_position, "has_previous": true, "adjusted": false, "primary": primary}

func _update_active_region_tile() -> void:
	var next_tile_key := ""
	for key in _actors.keys():
		var state: Dictionary = _actors[key]
		if not bool(state.get("primary", false)):
			continue
		var actor := _actor_from_state(state)
		if actor == null:
			continue
		next_tile_key = _tile_key_for_actor(actor)
		break
	if next_tile_key.is_empty():
		for key in _actors.keys():
			var state: Dictionary = _actors[key]
			var actor := _actor_from_state(state)
			if actor == null:
				continue
			next_tile_key = _tile_key_for_actor(actor)
			break
	if next_tile_key != _active_region_tile_key:
		_active_region_tile_key = next_tile_key
		_set_runtime_regions_enabled(_runtime_regions_enabled())

func _update_runtime_actors() -> void:
	for key in _actors.keys():
		var state: Dictionary = _actors[key]
		var actor := _actor_from_state(state)
		if actor == null:
			_clear_adjust_ghost_for_key(int(key))
			_actors.erase(key)
			continue
		var is_primary: bool = bool(state.get("primary", false))
		var collision_records := _shape_records_for_actor(_collision_records_by_tile, actor)
		var collision_hit := _actor_collision_hit_info(actor, collision_records) if is_primary else {}
		var has_collision := not collision_hit.is_empty() if is_primary else _actor_overlaps_shape_records(actor, collision_records)
		if has_collision:
			if bool(state.get("has_previous", false)):
				if is_primary:
					_show_air_wall_hint(collision_hit)
				actor.global_position = state.get("previous_pos", actor.global_position)
		else:
			state["previous_pos"] = actor.global_position
			state["has_previous"] = true
		var full_features_enabled: bool = _runtime_full_features_enabled()
		var in_adjust: bool = full_features_enabled and _actor_overlaps_shape_records(actor, _shape_records_for_actor(_adjust_records_by_tile, actor))
		if in_adjust and not bool(state.get("adjusted", false)):
			_apply_adjust(actor, is_primary)
		elif in_adjust:
			if is_primary:
				_sync_adjust_ghost(actor)
			else:
				_clear_adjust_ghost_for_key(int(actor.get_instance_id()))
		elif not in_adjust and bool(state.get("adjusted", false)):
			_restore_adjust(actor)
		state["adjusted"] = in_adjust
		_actors[key] = state

func _tile_key_for_actor(actor: Node2D) -> String:
	for point in _actor_foot_probe_points(actor):
		var key := _tile_key_at_local_position(to_local(point))
		if not key.is_empty():
			return key
	return _tile_key_at_local_position(to_local(actor.global_position))

func _tile_key_at_local_position(local_position: Vector2) -> String:
	for key in _tile_bounds.keys():
		var rect: Rect2 = _tile_bounds[key]
		if rect.has_point(local_position):
			return String(key)
	return ""

func _shape_records_for_tile(index: Dictionary, tile_key: String) -> Array:
	var records: Array = []
	if index.has(""):
		var global_records: Array = index[""]
		records.append_array(global_records)
	if not tile_key.is_empty() and index.has(tile_key):
		var tile_records: Array = index[tile_key]
		records.append_array(tile_records)
	return records

func _shape_records_for_actor(index: Dictionary, actor: Node2D) -> Array:
	var records: Array = []
	if index.has(""):
		var global_records: Array = index[""]
		records.append_array(global_records)
	for tile_key in _actor_tile_keys(actor):
		var key := String(tile_key)
		if key.is_empty() or not index.has(key):
			continue
		var tile_records: Array = index[key]
		records.append_array(tile_records)
	return records

func _actor_overlaps_shape_records(actor: Node2D, records: Array) -> bool:
	if records.is_empty():
		return false
	var foot_polygons := _actor_foot_polygons(actor)
	var foot_points := _actor_foot_probe_points_from_polygons(foot_polygons, actor.global_position)
	for record in records:
		var shape_record: Dictionary = record as Dictionary
		var shape: CollisionPolygon2D = shape_record.get("shape", null) as CollisionPolygon2D
		if shape == null:
			continue
		for foot_polygon in foot_polygons:
			if _polygons_overlap(foot_polygon, shape):
				return true
		for point in foot_points:
			if _shape_contains_global_point(shape, point):
				return true
	return false

func _actor_collision_hit_info(actor: Node2D, records: Array) -> Dictionary:
	if records.is_empty():
		return {}
	var foot_polygons := _actor_foot_polygons(actor)
	var foot_points := _actor_foot_probe_points_from_polygons(foot_polygons, actor.global_position)
	var probe_points: Array = []
	probe_points.append_array(foot_points)
	for foot_polygon in foot_polygons:
		for point in foot_polygon:
			probe_points.append(point)
	if probe_points.is_empty():
		probe_points.append(actor.global_position)
	var contact_origin: Vector2 = _actor_contact_origin(foot_points, actor.global_position)
	var best_distance: float = INF
	var best_hit: Dictionary = {}
	for record in records:
		var shape_record: Dictionary = record as Dictionary
		var shape: CollisionPolygon2D = shape_record.get("shape", null) as CollisionPolygon2D
		if shape == null:
			continue
		var shape_polygon := _shape_global_polygon(shape)
		if shape_polygon.size() < 2:
			continue
		var overlaps := false
		for foot_polygon in foot_polygons:
			if _polygons_overlap(foot_polygon, shape):
				overlaps = true
				break
		if not overlaps:
			for point in foot_points:
				if Geometry2D.is_point_in_polygon(point, shape_polygon):
					overlaps = true
					break
		if not overlaps:
			continue
		for index in range(shape_polygon.size()):
			var a: Vector2 = shape_polygon[index]
			var b: Vector2 = shape_polygon[(index + 1) % shape_polygon.size()]
			if a.distance_squared_to(b) <= 1.0:
				continue
			var tangent: Vector2 = (b - a).normalized()
			var edge_distance: float = INF
			for probe_point in probe_points:
				var point: Vector2 = probe_point
				var contact_point: Vector2 = _closest_point_on_segment(point, a, b)
				var distance: float = point.distance_squared_to(contact_point)
				if distance < edge_distance:
					edge_distance = distance
			if edge_distance < best_distance:
				best_distance = edge_distance
				var centered_contact_point: Vector2 = _closest_point_on_segment(contact_origin, a, b)
				best_hit = {"point": centered_contact_point, "tangent": tangent, "distance": edge_distance}
	return best_hit

func _actor_contact_origin(points: Array, fallback: Vector2) -> Vector2:
	if points.is_empty():
		return fallback
	var total: Vector2 = Vector2.ZERO
	for value in points:
		var point: Vector2 = value
		total += point
	return total / float(points.size())

func _closest_point_on_segment(point: Vector2, a: Vector2, b: Vector2) -> Vector2:
	var segment: Vector2 = b - a
	var length_sq: float = segment.length_squared()
	if length_sq <= 0.0001:
		return a
	var t: float = clamp((point - a).dot(segment) / length_sq, 0.0, 1.0)
	return a + segment * t

func _actor_foot_polygons(actor: Node2D) -> Array:
	var polygons: Array = []
	for shadow in _foot_shadow_targets(actor):
		if shadow is Sprite2D:
			var polygon: PackedVector2Array = _sprite_global_polygon(shadow as Sprite2D)
			if polygon.size() >= 3:
				polygons.append(polygon)
	return polygons

func _actor_foot_probe_points(actor: Node2D) -> Array:
	return _actor_foot_probe_points_from_polygons(_actor_foot_polygons(actor), actor.global_position)

func _actor_foot_probe_points_from_polygons(polygons: Array, fallback: Vector2) -> Array:
	var points: Array = []
	for polygon in polygons:
		points.append_array(_polygon_probe_points(polygon))
	if not points.is_empty():
		return points
	points.append(fallback)
	return points

func _shape_contains_global_point(shape: CollisionPolygon2D, global_point: Vector2) -> bool:
	return Geometry2D.is_point_in_polygon(shape.to_local(global_point), shape.polygon)

func _polygons_overlap(global_polygon: PackedVector2Array, shape: CollisionPolygon2D) -> bool:
	var shape_polygon := _shape_global_polygon(shape)
	if global_polygon.size() < 3 or shape_polygon.size() < 3:
		return false
	for point in global_polygon:
		if Geometry2D.is_point_in_polygon(point, shape_polygon):
			return true
	for point in shape_polygon:
		if Geometry2D.is_point_in_polygon(point, global_polygon):
			return true
	return not Geometry2D.intersect_polygons(global_polygon, shape_polygon).is_empty()

func _shape_global_polygon(shape: CollisionPolygon2D) -> PackedVector2Array:
	var points := PackedVector2Array()
	for point in shape.polygon:
		points.append(shape.to_global(point))
	return points

func _sprite_global_polygon(sprite: Sprite2D) -> PackedVector2Array:
	var rect := sprite.get_rect()
	var points := PackedVector2Array()
	points.append(sprite.to_global(rect.position))
	points.append(sprite.to_global(rect.position + Vector2(rect.size.x, 0)))
	points.append(sprite.to_global(rect.position + rect.size))
	points.append(sprite.to_global(rect.position + Vector2(0, rect.size.y)))
	return points

func _polygon_probe_points(polygon: PackedVector2Array) -> Array:
	var points: Array = []
	if polygon.is_empty():
		return points
	var center := Vector2.ZERO
	for point in polygon:
		points.append(point)
		center += point
	center /= float(polygon.size())
	points.append(center)
	for index in range(polygon.size()):
		points.append((polygon[index] + polygon[(index + 1) % polygon.size()]) * 0.5)
	return points

func _foot_shadow_targets(actor: Node2D) -> Array:
	var targets: Array = []
	_collect_foot_shadow_targets(actor, targets)
	return targets

func _collect_foot_shadow_targets(node: Node, targets: Array) -> void:
	if node is Sprite2D and _is_foot_shadow_node(node):
		targets.append(node)
		return
	for child in node.get_children():
		if child is Node:
			_collect_foot_shadow_targets(child, targets)

func _is_foot_shadow_node(node: Node) -> bool:
	var name_text := String(node.name).to_lower()
	var parent := node.get_parent()
	var parent_name: String = String(parent.name).to_lower() if parent != null else ""
	return name_text.contains("shadow") or name_text.contains("foot") or name_text.contains("feet") or name_text.contains("影") or name_text.contains("脚") or parent_name.contains("shadow") or parent_name.contains("foot") or parent_name.contains("feet") or parent_name.contains("影") or parent_name.contains("脚")

func _apply_adjust(actor: Node2D, show_ghost: bool) -> void:
	for target in _visual_targets(actor):
		var visual: CanvasItem = target as CanvasItem
		if visual == null or not is_instance_valid(visual):
			continue
		if bool(visual.get_meta("map_stitch_adjust_ghost", false)):
			continue
		var key: int = int(visual.get_instance_id())
		if not _visual_state.has(key):
			_visual_state[key] = {"node": visual, "z_index": visual.z_index, "z_as_relative": visual.z_as_relative}
		visual.z_as_relative = false
		visual.z_index = ADJUST_Z_INDEX
	if show_ghost:
		_sync_adjust_ghost(actor)
	else:
		_clear_adjust_ghost_for_key(int(actor.get_instance_id()))

func _restore_adjust(actor: Node2D) -> void:
	_clear_adjust_ghost_for_key(int(actor.get_instance_id()))
	for target in _visual_targets(actor):
		var visual: CanvasItem = target as CanvasItem
		if visual == null:
			continue
		if bool(visual.get_meta("map_stitch_adjust_ghost", false)):
			continue
		var key: int = int(visual.get_instance_id())
		if not _visual_state.has(key):
			continue
		var state: Dictionary = _visual_state[key]
		if is_instance_valid(visual):
			visual.z_index = int(state.get("z_index", visual.z_index))
			visual.z_as_relative = bool(state.get("z_as_relative", visual.z_as_relative))
		_visual_state.erase(key)

func _restore_all_adjustments() -> void:
	for key in _actors.keys():
		var state: Dictionary = _actors[key]
		var actor := _actor_from_state(state)
		if actor != null:
			_restore_adjust(actor)
		else:
			_clear_adjust_ghost_for_key(int(key))
		state["adjusted"] = false
		_actors[key] = state
	_clear_all_adjust_ghosts()

func _sync_adjust_ghost(actor: Node2D) -> void:
	var actor_key := int(actor.get_instance_id())
	if not show_adjust_ghost:
		_clear_adjust_ghost_for_key(actor_key)
		return
	var ghosts: Dictionary = _adjust_ghosts.get(actor_key, {})
	var next_visual_keys := {}
	for target in _visual_targets(actor):
		var visual: CanvasItem = target as CanvasItem
		if visual == null or not is_instance_valid(visual):
			continue
		if bool(visual.get_meta("map_stitch_adjust_ghost", false)):
			continue
		var visual_key := int(visual.get_instance_id())
		next_visual_keys[visual_key] = true
		var ghost: CanvasItem = ghosts.get(visual_key, null) as CanvasItem
		if ghost == null or not is_instance_valid(ghost):
			ghost = _create_adjust_ghost_visual(visual)
		if ghost == null:
			continue
		ghosts[visual_key] = ghost
		_sync_adjust_ghost_visual(visual, ghost)
	for visual_key in ghosts.keys():
		if next_visual_keys.has(visual_key):
			continue
		var stale: Node = ghosts[visual_key] as Node
		if stale != null and is_instance_valid(stale):
			stale.queue_free()
		ghosts.erase(visual_key)
	if ghosts.is_empty():
		_adjust_ghosts.erase(actor_key)
	else:
		_adjust_ghosts[actor_key] = ghosts

func _create_adjust_ghost_visual(visual: CanvasItem) -> CanvasItem:
	var parent := visual.get_parent()
	if parent == null:
		return null
	var clone_node := visual.duplicate(0)
	if not (clone_node is CanvasItem):
		clone_node.free()
		return null
	clone_node.name = "%s_AdjustGhost" % String(visual.name)
	clone_node.set_script(null)
	clone_node.process_mode = Node.PROCESS_MODE_DISABLED
	clone_node.set_process(false)
	clone_node.set_physics_process(false)
	clone_node.set_meta("map_stitch_adjust_ghost", true)
	for child in clone_node.get_children():
		clone_node.remove_child(child)
		child.free()
	parent.add_child(clone_node)
	var ghost: CanvasItem = clone_node as CanvasItem
	ghost.z_as_relative = false
	ghost.z_index = adjust_ghost_z_index
	return ghost

func _sync_adjust_ghost_visual(visual: CanvasItem, ghost: CanvasItem) -> void:
	ghost.visible = visual.visible
	ghost.z_as_relative = false
	ghost.z_index = adjust_ghost_z_index
	var ghost_modulate := visual.modulate
	ghost_modulate.a *= clamp(adjust_ghost_alpha, 0.0, 1.0)
	ghost.modulate = ghost_modulate
	ghost.self_modulate = visual.self_modulate
	if visual is Node2D and ghost is Node2D:
		(ghost as Node2D).transform = (visual as Node2D).transform
	if visual is Sprite2D and ghost is Sprite2D:
		_sync_sprite_ghost(visual as Sprite2D, ghost as Sprite2D)
	elif visual is AnimatedSprite2D and ghost is AnimatedSprite2D:
		_sync_animated_sprite_ghost(visual as AnimatedSprite2D, ghost as AnimatedSprite2D)

func _sync_sprite_ghost(source: Sprite2D, ghost: Sprite2D) -> void:
	ghost.texture = source.texture
	ghost.centered = source.centered
	ghost.offset = source.offset
	ghost.flip_h = source.flip_h
	ghost.flip_v = source.flip_v
	ghost.hframes = source.hframes
	ghost.vframes = source.vframes
	ghost.frame = source.frame
	ghost.region_enabled = source.region_enabled
	ghost.region_rect = source.region_rect

func _sync_animated_sprite_ghost(source: AnimatedSprite2D, ghost: AnimatedSprite2D) -> void:
	ghost.sprite_frames = source.sprite_frames
	ghost.animation = source.animation
	ghost.set_frame_and_progress(source.frame, source.frame_progress)
	ghost.speed_scale = source.speed_scale
	ghost.centered = source.centered
	ghost.offset = source.offset
	ghost.flip_h = source.flip_h
	ghost.flip_v = source.flip_v

func _clear_adjust_ghost_for_key(actor_key: int) -> void:
	if not _adjust_ghosts.has(actor_key):
		return
	var ghosts: Dictionary = _adjust_ghosts[actor_key]
	for value in ghosts.values():
		var ghost: Node = value as Node
		if ghost != null and is_instance_valid(ghost):
			ghost.queue_free()
	_adjust_ghosts.erase(actor_key)

func _clear_all_adjust_ghosts() -> void:
	for actor_key in _adjust_ghosts.keys():
		_clear_adjust_ghost_for_key(int(actor_key))
	_adjust_ghosts.clear()

func _show_air_wall_hint(hit_info: Dictionary) -> void:
	if not show_air_wall_hint:
		_clear_air_wall_hint()
		return
	if not hit_info.has("point") or not hit_info.has("tangent"):
		return
	var contact_point: Vector2 = hit_info.get("point", Vector2.ZERO)
	var tangent: Vector2 = hit_info.get("tangent", Vector2.RIGHT)
	if tangent.length_squared() <= 0.0001:
		return
	tangent = tangent.normalized()
	var signature: String = _air_wall_hint_signature(contact_point, tangent)
	var root: Node2D = _ensure_air_wall_hint_root()
	if root == null:
		return
	root.z_as_relative = false
	root.z_index = air_wall_hint_z_index
	root.visible = true
	root.modulate = Color(1, 1, 1, 1)
	_air_wall_hint_time_left = max(0.05, air_wall_hint_duration)
	if _air_wall_hint_key == signature and root.get_child_count() > 0:
		return
	_air_wall_hint_key = signature
	_clear_air_wall_hint_children(root)
	var spacing: float = max(4.0, air_wall_hint_dot_spacing)
	var radius: float = max(1.0, air_wall_hint_dot_radius)
	var contact_width: float = max(12.0, air_wall_hint_contact_width)
	var local_center: Vector2 = to_local(contact_point)
	var local_tangent: Vector2 = to_local(contact_point + tangent) - local_center
	if local_tangent.length_squared() <= 0.0001:
		local_tangent = Vector2.RIGHT
	else:
		local_tangent = local_tangent.normalized()
	var local_normal: Vector2 = Vector2(-local_tangent.y, local_tangent.x)
	var row_offsets: Array[float] = [0.0]
	if contact_width >= spacing * 2.0:
		row_offsets = [0.0, -radius * 2.8, radius * 2.8, -radius * 5.2, radius * 5.2]
	var max_count_per_row: int = int(max(3, int(AIR_WALL_MAX_DOTS / max(1, row_offsets.size()))))
	var count: int = int(clamp(int(floor(contact_width / spacing)) + 1, 3, max_count_per_row))
	if count % 2 == 0:
		if count < max_count_per_row:
			count += 1
		else:
			count -= 1
	var half_width: float = float(count - 1) * spacing * 0.5
	var dot_polygon: PackedVector2Array = _air_wall_dot_polygon(radius)
	var row_fade_distance: float = max(1.0, radius * 5.2)
	for row_offset in row_offsets:
		var row_ratio: float = abs(float(row_offset)) / row_fade_distance
		for index in range(count):
			var offset_along: float = float(index) * spacing - half_width
			var along_ratio: float = 0.0
			if half_width > 0.0:
				along_ratio = abs(offset_along) / half_width
			var distance_ratio: float = clamp(sqrt(along_ratio * along_ratio + row_ratio * row_ratio), 0.0, 1.0)
			var intensity: float = clamp(1.0 - distance_ratio * 0.78, 0.22, 1.0)
			var dot_color: Color = air_wall_hint_color
			dot_color.a = air_wall_hint_color.a * intensity
			var dot: Polygon2D = Polygon2D.new()
			dot.name = "AirWallDot"
			dot.polygon = dot_polygon
			dot.color = dot_color
			dot.position = local_center + local_tangent * offset_along + local_normal * float(row_offset)
			root.add_child(dot)

func _ensure_air_wall_hint_root() -> Node2D:
	if _air_wall_hint_root != null and is_instance_valid(_air_wall_hint_root):
		return _air_wall_hint_root
	var root := Node2D.new()
	root.name = "PixelworkAirWallHint"
	root.z_as_relative = false
	root.z_index = air_wall_hint_z_index
	root.visible = false
	add_child(root)
	_air_wall_hint_root = root
	return root

func _update_air_wall_hint(delta: float) -> void:
	if _air_wall_hint_root == null or not is_instance_valid(_air_wall_hint_root):
		_air_wall_hint_root = null
		_air_wall_hint_key = ""
		return
	if not show_air_wall_hint:
		_clear_air_wall_hint()
		return
	if _air_wall_hint_time_left <= 0.0:
		_clear_air_wall_hint()
		return
	_air_wall_hint_time_left -= delta
	if _air_wall_hint_time_left <= 0.0:
		_clear_air_wall_hint()
		return
	var duration: float = max(0.05, air_wall_hint_duration)
	var alpha: float = clamp(_air_wall_hint_time_left / duration, 0.0, 1.0)
	_air_wall_hint_root.modulate = Color(1, 1, 1, alpha)

func _air_wall_hint_signature(point: Vector2, tangent: Vector2) -> String:
	return "%d,%d:%d,%d" % [int(round(point.x)), int(round(point.y)), int(round(tangent.x * 100.0)), int(round(tangent.y * 100.0))]

func _air_wall_dot_polygon(radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(8):
		var angle := TAU * float(index) / 8.0
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points

func _clear_air_wall_hint_children(root: Node) -> void:
	for child in root.get_children():
		root.remove_child(child)
		child.free()

func _clear_air_wall_hint() -> void:
	if _air_wall_hint_root != null and is_instance_valid(_air_wall_hint_root):
		_air_wall_hint_root.queue_free()
	_air_wall_hint_root = null
	_air_wall_hint_time_left = 0.0
	_air_wall_hint_key = ""

func _visual_targets(actor: Node2D) -> Array:
	var targets: Array = []
	_collect_visual_targets(actor, targets)
	if targets.is_empty() and actor is CanvasItem:
		targets.append(actor)
	return targets

func _collect_visual_targets(node: Node, targets: Array) -> void:
	if node is AnimatedSprite2D or node is Sprite2D:
		targets.append(node)
	for child in node.get_children():
		if child is Node:
			_collect_visual_targets(child, targets)

func _get_bool_property(object: Object, property_name: String, fallback: bool) -> bool:
	if not _has_property(object, property_name):
		return fallback
	return bool(object.get(property_name))

func _has_property(object: Object, property_name: String) -> bool:
	for property in object.get_property_list():
		if String(property.get("name", "")) == property_name:
			return true
	return false
