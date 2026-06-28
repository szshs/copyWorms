class_name GameUIStyle
extends RefCounted

const COLOR_PANEL := Color(0.025, 0.035, 0.07, 0.86)
const COLOR_PANEL_BORDER := Color(0.16, 0.78, 0.9, 0.45)
const COLOR_BUTTON := Color(0.045, 0.075, 0.13, 0.94)
const COLOR_BUTTON_HOVER := Color(0.075, 0.16, 0.24, 0.98)
const COLOR_BUTTON_PRESSED := Color(0.025, 0.05, 0.09, 1.0)
const COLOR_BUTTON_DISABLED := Color(0.04, 0.045, 0.055, 0.72)
const COLOR_ACCENT := Color(0.25, 0.92, 1.0, 0.9)
const COLOR_ACCENT_SOFT := Color(0.18, 0.58, 0.72, 0.55)
const COLOR_GOLD := Color(1.0, 0.78, 0.24, 0.96)
const COLOR_GLASS := Color(0.5, 0.95, 1.0, 0.08)
const COLOR_TEXT := Color(0.94, 0.98, 1.0, 1.0)
const COLOR_TEXT_DIM := Color(0.62, 0.72, 0.82, 1.0)
const COLOR_LINGNAN_INTERACTION_TEXT := Color(0.12, 0.24, 0.16, 1.0)
const LINGNAN_INTERACTION_TEXT_BBCODE := "#1f3d29"
const UI_THEME_DEFAULT := "default"
const UI_THEME_LINGNAN := "lingnan"
const UI_THEME_CYBER := "cyber"
const BUTTON_TEXTURE_MARGIN_LEFT := 48.0
const BUTTON_TEXTURE_MARGIN_TOP := 28.0
const BUTTON_TEXTURE_MARGIN_RIGHT := 48.0
const BUTTON_TEXTURE_MARGIN_BOTTOM := 28.0
const LINGNAN_BUTTON_TEXTURE_MARGIN_LEFT := 38.0
const LINGNAN_BUTTON_TEXTURE_MARGIN_TOP := 30.0
const LINGNAN_BUTTON_TEXTURE_MARGIN_RIGHT := 38.0
const LINGNAN_BUTTON_TEXTURE_MARGIN_BOTTOM := 30.0
const INTERACTION_TEXT_PANEL_SIZE := Vector2(500.0, 320.0)
const INTERACTION_TEXT_PANEL_SMALL := Vector2(500.0, 282.0)
const INTERACTION_TEXT_PANEL_MEDIUM := Vector2(500.0, 320.0)
const INTERACTION_TEXT_PAGE_VISIBLE_LIMIT := 92
const INTERACTION_TEXT_PANEL_MARGIN_X := 64.0
const INTERACTION_TEXT_PANEL_MARGIN_TOP := 56.0
const INTERACTION_TEXT_PANEL_MARGIN_BOTTOM := 54.0
const INTERACTION_TEXT_PANEL_EDGE_GAP := 28.0
const INTERACTION_CODE_PANEL_MIN_SIZE := Vector2(360.0, 132.0)
const INTERACTION_CODE_PANEL_MAX_SIZE := Vector2(760.0, 300.0)
const INTERACTION_CODE_PANEL_MARGIN_X := 28.0
const INTERACTION_CODE_PANEL_MARGIN_TOP := 22.0
const INTERACTION_CODE_PANEL_MARGIN_BOTTOM := 22.0
const LINGNAN_INTERACTION_PANEL_SIZE := Vector2(760.0, 300.0)
const LINGNAN_INTERACTION_PANEL_MARGIN_X := 92.0
const LINGNAN_INTERACTION_PANEL_MARGIN_TOP := 82.0
const LINGNAN_INTERACTION_PANEL_MARGIN_BOTTOM := 76.0

static var _ui_theme: String = UI_THEME_CYBER

static func set_ui_theme(theme: String) -> void:
	match theme:
		UI_THEME_LINGNAN, UI_THEME_CYBER, UI_THEME_DEFAULT:
			_ui_theme = theme
		_:
			_ui_theme = UI_THEME_CYBER

static func get_ui_theme() -> String:
	return _ui_theme

static func is_lingnan_theme() -> bool:
	return _ui_theme == UI_THEME_LINGNAN

static func is_cyber_theme() -> bool:
	return _ui_theme == UI_THEME_CYBER

static func make_panel_style(alpha: float = 0.86) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(COLOR_PANEL.r, COLOR_PANEL.g, COLOR_PANEL.b, alpha)
	style.border_color = COLOR_PANEL_BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.shadow_color = Color(0, 0, 0, 0.38)
	style.shadow_size = 10
	style.shadow_offset = Vector2(0, 2)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	return style

static func make_button_style(state: String = "normal") -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	match state:
		"hover":
			style.bg_color = Color(COLOR_BUTTON_HOVER.r, COLOR_BUTTON_HOVER.g, COLOR_BUTTON_HOVER.b, 0.99)
			style.border_color = COLOR_ACCENT
			style.shadow_color = Color(0.1, 0.75, 0.95, 0.34)
			style.shadow_size = 14
		"pressed":
			style.bg_color = COLOR_BUTTON_PRESSED
			style.border_color = COLOR_GOLD
			style.shadow_color = Color(1.0, 0.65, 0.16, 0.26)
			style.shadow_size = 7
			style.content_margin_top = 3
		"disabled":
			style.bg_color = COLOR_BUTTON_DISABLED
			style.border_color = Color(0.25, 0.3, 0.35, 0.38)
		_:
			style.bg_color = COLOR_BUTTON
			style.border_color = COLOR_ACCENT_SOFT
			style.shadow_color = Color(0, 0, 0, 0.24)
			style.shadow_size = 6
	style.set_border_width_all(3)
	style.set_corner_radius_all(7)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = maxf(style.content_margin_top, 2)
	style.content_margin_bottom = 2
	return style

static func apply_panel(panel: Panel, alpha: float = 0.86) -> void:
	panel.add_theme_stylebox_override("panel", make_panel_style(alpha))

static func apply_pressed_button_panel(panel: Panel) -> void:
	var style := _make_lingnan_settings_panel_style() if is_lingnan_theme() else _make_panel_texture_style("pressed")
	if style:
		panel.add_theme_stylebox_override("panel", style)
	else:
		panel.add_theme_stylebox_override("panel", make_panel_style(0.9))

static func apply_interaction_text_panel(panel: Panel, text_label: RichTextLabel = null, font_size: int = 27) -> void:
	panel.anchor_left = 0.0
	panel.anchor_top = 0.0
	panel.anchor_right = 0.0
	panel.anchor_bottom = 0.0
	panel.size = INTERACTION_TEXT_PANEL_SIZE
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_interaction_text_panel_style(panel)
	if text_label:
		style_interaction_text_label(text_label, font_size, panel)

static func _apply_interaction_text_panel_style(panel: Panel) -> void:
	var style: StyleBox = null
	if _is_code_interaction_panel(panel):
		style = _make_code_interaction_text_style()
	elif _is_lingnan_interaction_panel(panel):
		style = _make_lingnan_interaction_text_style()
	else:
		var texture_state := "disabled"
		if panel.has_meta("dialog_texture_state"):
			texture_state = str(panel.get_meta("dialog_texture_state"))
		style = _make_interaction_text_style(texture_state)
	if style:
		panel.add_theme_stylebox_override("panel", style)
	else:
		panel.add_theme_stylebox_override("panel", make_panel_style(0.96))

static func style_interaction_text_label(label: RichTextLabel, font_size: int = 27, panel: Panel = null) -> void:
	label.anchor_left = 0.0
	label.anchor_top = 0.0
	label.anchor_right = 1.0
	label.anchor_bottom = 1.0
	label.offset_left = INTERACTION_TEXT_PANEL_MARGIN_X
	label.offset_top = INTERACTION_TEXT_PANEL_MARGIN_TOP
	label.offset_right = -INTERACTION_TEXT_PANEL_MARGIN_X
	label.offset_bottom = -INTERACTION_TEXT_PANEL_MARGIN_BOTTOM
	label.bbcode_enabled = true
	label.fit_content = false
	label.scroll_active = false
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("normal_font_size", font_size)
	label.add_theme_color_override("default_color", _interaction_text_color(panel))

static func fit_interaction_text_panel(panel: Panel, text_label: RichTextLabel, text: String) -> void:
	_apply_interaction_text_panel_style(panel)
	if text_label:
		text_label.text = _format_interaction_text_for_panel(text, panel)
		text_label.add_theme_color_override("default_color", _interaction_text_color(panel))
	var panel_size := _interaction_text_panel_size_for_text(text, panel)
	panel.size = panel_size
	if text_label:
		_apply_interaction_text_label_insets(text_label, panel_size, _is_code_interaction_panel(panel), _is_lingnan_interaction_panel(panel))
		text_label.scroll_active = false
	_position_interaction_text_panel(panel, panel_size)

static func paginate_interaction_text(text: String) -> Array[String]:
	var pages: Array[String] = []
	var clean := _strip_bbcode(text).strip_edges()
	if clean.length() <= INTERACTION_TEXT_PAGE_VISIBLE_LIMIT and _count_newlines(clean) <= 4:
		pages.append(text)
		return pages

	var page_start := 0
	var i := 0
	var visible_count := 0
	var last_break := -1
	var in_tag := false
	while i < text.length():
		var c := text.substr(i, 1)
		if c == "[":
			in_tag = true
		elif c == "]" and in_tag:
			in_tag = false
			i += 1
			continue
		elif not in_tag:
			visible_count += 1
			if _is_interaction_page_break_char(c):
				last_break = i + 1
		if visible_count >= INTERACTION_TEXT_PAGE_VISIBLE_LIMIT:
			var cut := last_break if last_break > page_start else i + 1
			var page := text.substr(page_start, cut - page_start).strip_edges()
			if page != "":
				pages.append(page)
			page_start = cut
			while page_start < text.length() and _is_interaction_page_leading_space(text.substr(page_start, 1)):
				page_start += 1
			i = page_start
			visible_count = 0
			last_break = -1
			in_tag = false
			continue
		i += 1

	var tail := text.substr(page_start).strip_edges()
	if tail != "":
		pages.append(tail)
	if pages.is_empty():
		pages.append(text)
	return pages

static func position_interaction_text_panel(panel: Panel) -> void:
	_position_interaction_text_panel(panel, panel.size if panel.size.x > 0.0 and panel.size.y > 0.0 else INTERACTION_TEXT_PANEL_SIZE)

static func _position_interaction_text_panel(panel: Panel, panel_size: Vector2) -> void:
	var viewport_size := Vector2(1280.0, 720.0)
	var viewport := panel.get_viewport()
	if viewport:
		viewport_size = viewport.get_visible_rect().size
	if viewport_size.x <= 0.0:
		viewport_size.x = 1280.0
	if viewport_size.y <= 0.0:
		viewport_size.y = 720.0
	panel.size = panel_size
	var x := _interaction_text_panel_x(panel, panel_size, viewport_size)
	var y := viewport_size.y - panel_size.y - INTERACTION_TEXT_PANEL_EDGE_GAP
	var preferred_zone := "auto"
	if panel.has_meta("dialog_preferred_zone"):
		preferred_zone = str(panel.get_meta("dialog_preferred_zone"))
	match preferred_zone:
		"top":
			y = INTERACTION_TEXT_PANEL_EDGE_GAP
		"bottom":
			y = viewport_size.y - panel_size.y - INTERACTION_TEXT_PANEL_EDGE_GAP
		_:
			var player = GameManager.player_ref
			if player and is_instance_valid(player):
				var screen_y: float = player.get_global_transform_with_canvas().origin.y
				if screen_y > viewport_size.y * 0.56:
					y = INTERACTION_TEXT_PANEL_EDGE_GAP
	panel.position = Vector2(x, y)

static func _interaction_text_panel_x(panel: Panel, panel_size: Vector2, viewport_size: Vector2) -> float:
	var preferred_x := "center"
	if panel.has_meta("dialog_preferred_x"):
		preferred_x = str(panel.get_meta("dialog_preferred_x"))
	match preferred_x:
		"left":
			return INTERACTION_TEXT_PANEL_EDGE_GAP
		"right":
			return viewport_size.x - panel_size.x - INTERACTION_TEXT_PANEL_EDGE_GAP
		_:
			return (viewport_size.x - panel_size.x) * 0.5

static func _interaction_text_panel_size_for_text(text: String, panel: Panel = null) -> Vector2:
	if panel != null and _is_code_interaction_panel(panel):
		return _code_interaction_text_panel_size_for_text(text)
	if panel != null and _is_lingnan_interaction_panel(panel):
		return LINGNAN_INTERACTION_PANEL_SIZE
	var clean := _strip_bbcode(text).strip_edges()
	var line_count := _count_newlines(clean) + 1
	var score := clean.length() + line_count * 12
	if score <= 42 and line_count <= 2:
		return INTERACTION_TEXT_PANEL_SMALL
	return INTERACTION_TEXT_PANEL_MEDIUM

static func _code_interaction_text_panel_size_for_text(text: String) -> Vector2:
	var clean := _strip_bbcode(text).strip_edges()
	var line_count := _count_newlines(clean) + 1
	var longest_line := 0
	for line in clean.split("\n"):
		longest_line = maxi(longest_line, String(line).length())
	var length := clean.length()
	var target_width := INTERACTION_CODE_PANEL_MIN_SIZE.x
	if length > 72 or longest_line > 24:
		target_width = 700.0
	elif length > 38 or longest_line > 15:
		target_width = 560.0
	else:
		target_width = maxf(INTERACTION_CODE_PANEL_MIN_SIZE.x, longest_line * 22.0 + 86.0)
	target_width = clampf(target_width, INTERACTION_CODE_PANEL_MIN_SIZE.x, INTERACTION_CODE_PANEL_MAX_SIZE.x)

	var content_width := maxf(target_width - INTERACTION_CODE_PANEL_MARGIN_X * 2.0, 120.0)
	var chars_per_line := maxi(8, floori(content_width / 22.0))
	var wrapped_lines := maxi(line_count, ceili(float(maxi(length, 1)) / float(chars_per_line)))
	var target_height := 70.0 + wrapped_lines * 34.0
	target_height = clampf(target_height, INTERACTION_CODE_PANEL_MIN_SIZE.y, INTERACTION_CODE_PANEL_MAX_SIZE.y)
	return Vector2(target_width, target_height)

static func _apply_interaction_text_label_insets(label: RichTextLabel, panel_size: Vector2, use_code_style: bool = false, use_lingnan_style: bool = false) -> void:
	if use_code_style:
		label.offset_left = INTERACTION_CODE_PANEL_MARGIN_X
		label.offset_top = INTERACTION_CODE_PANEL_MARGIN_TOP
		label.offset_right = -INTERACTION_CODE_PANEL_MARGIN_X
		label.offset_bottom = -INTERACTION_CODE_PANEL_MARGIN_BOTTOM
		return
	if use_lingnan_style:
		label.offset_left = LINGNAN_INTERACTION_PANEL_MARGIN_X
		label.offset_top = LINGNAN_INTERACTION_PANEL_MARGIN_TOP
		label.offset_right = -LINGNAN_INTERACTION_PANEL_MARGIN_X
		label.offset_bottom = -LINGNAN_INTERACTION_PANEL_MARGIN_BOTTOM
		return
	var margin_x := clampf(panel_size.x * 0.12, 54.0, 78.0)
	var margin_top := clampf(panel_size.y * 0.15, 46.0, 66.0)
	var margin_bottom := clampf(panel_size.y * 0.145, 44.0, 64.0)
	label.offset_left = margin_x
	label.offset_top = margin_top
	label.offset_right = -margin_x
	label.offset_bottom = -margin_bottom

static func _strip_bbcode(text: String) -> String:
	var result := ""
	var in_tag := false
	for i in range(text.length()):
		var c := text.substr(i, 1)
		if c == "[":
			in_tag = true
			continue
		if c == "]" and in_tag:
			in_tag = false
			continue
		if not in_tag:
			result += c
	return result

static func _format_interaction_text_for_panel(text: String, panel: Panel = null) -> String:
	if panel == null or not _is_lingnan_interaction_panel(panel):
		return text
	return _normalize_lingnan_warning_colors(text)

static func _normalize_lingnan_warning_colors(text: String) -> String:
	var color_regex := RegEx.new()
	color_regex.compile("\\[color=([^\\]]+)\\]")
	var matches := color_regex.search_all(text)
	if matches.is_empty():
		return text
	var result := ""
	var cursor := 0
	for match_result in matches:
		result += text.substr(cursor, match_result.get_start() - cursor)
		var color_name := match_result.get_string(1).strip_edges().to_lower()
		var target_color := "red" if _is_lingnan_warning_color(color_name) else LINGNAN_INTERACTION_TEXT_BBCODE
		result += "[color=%s]" % target_color
		cursor = match_result.get_end()
	result += text.substr(cursor)
	return result

static func _is_lingnan_warning_color(color_name: String) -> bool:
	return color_name in [
		"red",
		"yellow",
		"gold",
		"goldenrod",
		"orange",
		"darkorange",
		"crimson",
		"#f00",
		"#ff0000",
		"#ff0",
		"#ffff00",
		"#ffd700",
		"#ffa500",
		"#ff8c00",
		"#dc143c"
	]

static func _count_newlines(text: String) -> int:
	var count := 0
	for i in range(text.length()):
		if text.substr(i, 1) == "\n":
			count += 1
	return count

static func _is_interaction_page_break_char(c: String) -> bool:
	return c == "\n" or c == "。" or c == "！" or c == "？" or c == "，" or c == "、" or c == "；" or c == " " or c == "."

static func _is_interaction_page_leading_space(c: String) -> bool:
	return c == "\n" or c == "\t" or c == " "

static func apply_button(button: Button, font_size: int = 24) -> void:
	button.focus_mode = Control.FOCUS_NONE
	var use_texture := _should_use_texture_for_size(button.size)
	button.add_theme_stylebox_override("normal", _make_button_visual_style("normal", use_texture))
	button.add_theme_stylebox_override("hover", _make_button_visual_style("hover", use_texture))
	button.add_theme_stylebox_override("pressed", _make_button_visual_style("pressed", use_texture))
	button.add_theme_stylebox_override("disabled", _make_button_visual_style("disabled", use_texture))
	button.add_theme_color_override("font_color", COLOR_TEXT)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", COLOR_GOLD)
	button.add_theme_color_override("font_disabled_color", COLOR_TEXT_DIM)
	button.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	button.add_theme_constant_override("outline_size", 3)
	button.add_theme_font_size_override("font_size", font_size)

static func apply_code_button(button: Button, font_size: int = 24) -> void:
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_stylebox_override("normal", make_button_style("normal"))
	button.add_theme_stylebox_override("hover", make_button_style("hover"))
	button.add_theme_stylebox_override("pressed", make_button_style("pressed"))
	button.add_theme_stylebox_override("disabled", make_button_style("disabled"))
	button.add_theme_color_override("font_color", COLOR_TEXT)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", COLOR_GOLD)
	button.add_theme_color_override("font_disabled_color", COLOR_TEXT_DIM)
	button.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	button.add_theme_constant_override("outline_size", 3)
	button.add_theme_font_size_override("font_size", font_size)

static func apply_texture_button(button: TextureButton, font_size: int = 24, force_simple: bool = false) -> void:
	button.texture_normal = null
	button.texture_hover = null
	button.texture_pressed = null
	button.texture_disabled = null
	button.ignore_texture_size = true
	button.focus_mode = Control.FOCUS_NONE
	button.modulate = Color.WHITE
	button.clip_contents = true
	button.set_meta("force_simple_texture_button", force_simple)
	button.set_meta("use_button_texture", false if force_simple else _should_use_texture_for_size(button.size))

	var skin := button.get_node_or_null("DreamButtonSkin") as Panel
	if skin == null:
		skin = Panel.new()
		skin.name = "DreamButtonSkin"
		skin.set_anchors_preset(Control.PRESET_FULL_RECT)
		skin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(skin)
		button.move_child(skin, 0)
	_ensure_texture_button_decoration(button)
	_apply_texture_button_state(button, skin, "normal")

	var label := button.get_node_or_null("Label") as Label
	if label:
		style_button_label(label, font_size)
		button.move_child(label, button.get_child_count() - 1)

	button.mouse_entered.connect(func() -> void:
		if not button.disabled:
			_apply_texture_button_state(button, skin, "hover")
	)
	button.mouse_exited.connect(func() -> void:
		_apply_texture_button_state(button, skin, "normal" if not button.disabled else "disabled")
	)
	button.button_down.connect(func() -> void:
		if not button.disabled:
			_apply_texture_button_state(button, skin, "pressed")
	)
	button.button_up.connect(func() -> void:
		_apply_texture_button_state(button, skin, "hover" if not button.disabled else "disabled")
	)

static func apply_lingnan_pressed_texture_button(button: TextureButton, font_size: int = 24) -> void:
	button.texture_normal = null
	button.texture_hover = null
	button.texture_pressed = null
	button.texture_disabled = null
	button.ignore_texture_size = true
	button.focus_mode = Control.FOCUS_NONE
	button.modulate = Color.WHITE
	button.clip_contents = true
	button.set_meta("use_lingnan_pressed_button", true)
	button.set_meta("force_simple_texture_button", false)
	button.set_meta("use_button_texture", true)

	var skin := button.get_node_or_null("DreamButtonSkin") as Panel
	if skin == null:
		skin = Panel.new()
		skin.name = "DreamButtonSkin"
		skin.set_anchors_preset(Control.PRESET_FULL_RECT)
		skin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(skin)
		button.move_child(skin, 0)
	_set_decor_visible(button, false)
	_apply_lingnan_pressed_button_state(button, skin, "normal")

	var label := button.get_node_or_null("Label") as Label
	if label:
		style_button_label(label, font_size)
		button.move_child(label, button.get_child_count() - 1)

	button.mouse_entered.connect(func() -> void:
		if not button.disabled:
			_apply_lingnan_pressed_button_state(button, skin, "hover")
	)
	button.mouse_exited.connect(func() -> void:
		_apply_lingnan_pressed_button_state(button, skin, "normal" if not button.disabled else "disabled")
	)
	button.button_down.connect(func() -> void:
		if not button.disabled:
			_apply_lingnan_pressed_button_state(button, skin, "pressed")
	)
	button.button_up.connect(func() -> void:
		_apply_lingnan_pressed_button_state(button, skin, "hover" if not button.disabled else "disabled")
	)

static func refresh_texture_button(button: TextureButton) -> void:
	var skin := button.get_node_or_null("DreamButtonSkin") as Panel
	if skin == null:
		return
	if bool(button.get_meta("use_lingnan_pressed_button", false)):
		_apply_lingnan_pressed_button_state(button, skin, "disabled" if button.disabled else "normal")
		return
	var force_simple := bool(button.get_meta("force_simple_texture_button", false))
	button.set_meta("use_button_texture", false if force_simple else _should_use_texture_for_size(button.size))
	_apply_texture_button_state(button, skin, "disabled" if button.disabled else "normal")

static func style_button_label(label: Label, font_size: int = 24) -> void:
	label.anchor_left = 0.0
	label.anchor_top = 0.0
	label.anchor_right = 1.0
	label.anchor_bottom = 1.0
	label.offset_left = 0.0
	label.offset_top = 4.0
	label.offset_right = 0.0
	label.offset_bottom = 4.0
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.self_modulate = Color.WHITE
	label.add_theme_color_override("font_color", COLOR_TEXT)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.86))
	label.add_theme_constant_override("outline_size", 2 if font_size >= 34 else 3)
	label.add_theme_font_size_override("font_size", font_size)
	var settings := label.label_settings
	if settings == null:
		settings = LabelSettings.new()
	label.label_settings = settings
	settings.font_size = font_size
	settings.font_color = COLOR_TEXT
	settings.outline_color = Color(0, 0, 0, 0.86)
	settings.outline_size = 2 if font_size >= 34 else 3

static func set_texture_button_disabled(button: TextureButton, disabled: bool) -> void:
	button.disabled = disabled
	var skin := button.get_node_or_null("DreamButtonSkin") as Panel
	if skin:
		if bool(button.get_meta("use_lingnan_pressed_button", false)):
			_apply_lingnan_pressed_button_state(button, skin, "disabled" if disabled else "normal")
			return
		_apply_texture_button_state(button, skin, "disabled" if disabled else "normal")

static func _apply_lingnan_pressed_button_state(button: TextureButton, skin: Panel, state: String) -> void:
	var style := _make_lingnan_pressed_button_style()
	if style:
		skin.add_theme_stylebox_override("panel", style)
	else:
		skin.add_theme_stylebox_override("panel", make_button_style(state))
	_set_decor_visible(button, false)
	var label := button.get_node_or_null("Label") as Label
	if label == null:
		return
	match state:
		"hover":
			_apply_button_label_color(label, Color.WHITE)
		"pressed":
			_apply_button_label_color(label, COLOR_GOLD)
		"disabled":
			_apply_button_label_color(label, COLOR_TEXT_DIM)
		_:
			_apply_button_label_color(label, COLOR_TEXT)

static func _apply_texture_button_state(button: TextureButton, skin: Panel, state: String) -> void:
	var use_texture := bool(button.get_meta("use_button_texture", true))
	var texture_style := _make_button_texture_style(state) if use_texture else null
	if texture_style:
		skin.add_theme_stylebox_override("panel", texture_style)
		_set_decor_visible(button, false)
	elif not use_texture:
		skin.add_theme_stylebox_override("panel", make_button_style(state))
		_set_decor_visible(button, false)
	else:
		skin.add_theme_stylebox_override("panel", make_button_style(state))
		_set_decor_visible(button, true)
		_apply_decor_state(button, state)
	var label := button.get_node_or_null("Label") as Label
	if label == null:
		return
	match state:
		"hover":
			_apply_button_label_color(label, Color.WHITE)
		"pressed":
			_apply_button_label_color(label, COLOR_GOLD)
		"disabled":
			_apply_button_label_color(label, COLOR_TEXT_DIM)
		_:
			_apply_button_label_color(label, COLOR_TEXT)

static func _apply_button_label_color(label: Label, color: Color) -> void:
	label.add_theme_color_override("font_color", color)
	if label.label_settings:
		label.label_settings.font_color = color

static func _make_button_visual_style(state: String, use_texture: bool = true) -> StyleBox:
	var texture_style := _make_button_texture_style(state) if use_texture else null
	if texture_style:
		return texture_style
	return make_button_style(state)

static func _make_button_texture_style(state: String) -> StyleBoxTexture:
	var path := _button_texture_path(state)
	if path == "":
		return null
	var tex := _load_ui_texture(path)
	if tex == null:
		return null
	var style := StyleBoxTexture.new()
	style.texture = tex
	if is_lingnan_theme():
		style.texture_margin_left = LINGNAN_BUTTON_TEXTURE_MARGIN_LEFT
		style.texture_margin_top = LINGNAN_BUTTON_TEXTURE_MARGIN_TOP
		style.texture_margin_right = LINGNAN_BUTTON_TEXTURE_MARGIN_RIGHT
		style.texture_margin_bottom = LINGNAN_BUTTON_TEXTURE_MARGIN_BOTTOM
	else:
		style.texture_margin_left = BUTTON_TEXTURE_MARGIN_LEFT
		style.texture_margin_top = BUTTON_TEXTURE_MARGIN_TOP
		style.texture_margin_right = BUTTON_TEXTURE_MARGIN_RIGHT
		style.texture_margin_bottom = BUTTON_TEXTURE_MARGIN_BOTTOM
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	style.draw_center = true
	return style

static func _make_panel_texture_style(state: String) -> StyleBoxTexture:
	var style := _make_button_texture_style(state)
	if style == null:
		return null
	style.texture_margin_left = 54
	style.texture_margin_top = 42
	style.texture_margin_right = 54
	style.texture_margin_bottom = 42
	style.content_margin_left = 32
	style.content_margin_right = 32
	style.content_margin_top = 28
	style.content_margin_bottom = 28
	return style

static func _make_interaction_text_style(state: String = "disabled") -> StyleBoxTexture:
	var path := _button_texture_path(state)
	if path == "":
		return null
	var tex := _load_ui_texture(path)
	if tex == null:
		return null
	var style := StyleBoxTexture.new()
	style.texture = tex
	style.texture_margin_left = 46
	style.texture_margin_top = 40
	style.texture_margin_right = 46
	style.texture_margin_bottom = 40
	style.content_margin_left = INTERACTION_TEXT_PANEL_MARGIN_X
	style.content_margin_right = INTERACTION_TEXT_PANEL_MARGIN_X
	style.content_margin_top = INTERACTION_TEXT_PANEL_MARGIN_TOP
	style.content_margin_bottom = INTERACTION_TEXT_PANEL_MARGIN_BOTTOM
	style.draw_center = true
	return style

static func _make_code_interaction_text_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.015, 0.025, 0.045, 0.92)
	style.border_color = Color(0.16, 0.74, 0.9, 0.78)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
	style.shadow_size = 12
	style.shadow_offset = Vector2(0, 3)
	style.content_margin_left = INTERACTION_CODE_PANEL_MARGIN_X
	style.content_margin_right = INTERACTION_CODE_PANEL_MARGIN_X
	style.content_margin_top = INTERACTION_CODE_PANEL_MARGIN_TOP
	style.content_margin_bottom = INTERACTION_CODE_PANEL_MARGIN_BOTTOM
	return style

static func _make_lingnan_interaction_text_style() -> StyleBoxTexture:
	return _make_texture_style(
		"res://Assets/UI/Lingnan/lingnan_botton_dialog.png",
		Vector4(96, 82, 96, 76),
		Vector4(
			LINGNAN_INTERACTION_PANEL_MARGIN_X,
			LINGNAN_INTERACTION_PANEL_MARGIN_TOP,
			LINGNAN_INTERACTION_PANEL_MARGIN_X,
			LINGNAN_INTERACTION_PANEL_MARGIN_BOTTOM
		)
	)

static func _make_lingnan_pressed_button_style() -> StyleBoxTexture:
	return _make_texture_style(
		"res://Assets/UI/Lingnan/lingnanbotton_pressed.png",
		Vector4(
			LINGNAN_BUTTON_TEXTURE_MARGIN_LEFT,
			LINGNAN_BUTTON_TEXTURE_MARGIN_TOP,
			LINGNAN_BUTTON_TEXTURE_MARGIN_RIGHT,
			LINGNAN_BUTTON_TEXTURE_MARGIN_BOTTOM
		),
		Vector4(18, 8, 18, 8)
	)

static func _make_lingnan_settings_panel_style() -> StyleBoxTexture:
	return _make_texture_style(
		"res://Assets/UI/Lingnan/lingnan_panel_roof.png",
		Vector4(88, 116, 88, 66),
		Vector4(74, 96, 74, 62)
	)

static func _make_texture_style(path: String, texture_margins: Vector4, content_margins: Vector4) -> StyleBoxTexture:
	var tex := _load_ui_texture(path)
	if tex == null:
		return null
	var style := StyleBoxTexture.new()
	style.texture = tex
	style.texture_margin_left = texture_margins.x
	style.texture_margin_top = texture_margins.y
	style.texture_margin_right = texture_margins.z
	style.texture_margin_bottom = texture_margins.w
	style.content_margin_left = content_margins.x
	style.content_margin_top = content_margins.y
	style.content_margin_right = content_margins.z
	style.content_margin_bottom = content_margins.w
	style.draw_center = true
	return style

static func _is_code_interaction_panel(panel: Panel) -> bool:
	return _interaction_panel_style_key(panel) == "code"

static func _is_lingnan_interaction_panel(panel: Panel) -> bool:
	return _interaction_panel_style_key(panel) == "lingnan"

static func _interaction_panel_style_key(panel: Panel) -> String:
	var visual_style := ""
	if panel and panel.has_meta("dialog_visual_style"):
		visual_style = str(panel.get_meta("dialog_visual_style"))
	match visual_style:
		"code":
			return "code"
		"lingnan":
			return "lingnan"
		"theme":
			return "lingnan" if is_lingnan_theme() else "code"
		_:
			return "lingnan" if is_lingnan_theme() else "texture"

static func _interaction_text_color(panel: Panel = null) -> Color:
	return COLOR_LINGNAN_INTERACTION_TEXT if panel != null and _is_lingnan_interaction_panel(panel) else Color(0.9, 0.85, 0.75)

static func _button_texture_path(state: String) -> String:
	if is_lingnan_theme():
		match state:
			"hover":
				return "res://Assets/UI/Lingnan/lingnan_button_hover.png"
			"pressed":
				return "res://Assets/UI/Lingnan/lingnan_button_pressed.png"
			"disabled":
				return "res://Assets/UI/Lingnan/lingnan_button_disabled.png"
			_:
				return "res://Assets/UI/Lingnan/lingnan_button_normal.png"
	match state:
		"hover":
			return "res://Assets/UI/button_hover.png"
		"pressed":
			return "res://Assets/UI/button_pressed.png"
		"disabled":
			return "res://Assets/UI/button_disabled.png"
		_:
			return "res://Assets/UI/button_normal.png"

static func _load_ui_texture(path: String) -> Texture2D:
	var tex := load(path) as Texture2D
	if tex:
		return tex
	if FileAccess.file_exists(path):
		var image := Image.load_from_file(path)
		if image:
			return ImageTexture.create_from_image(image)
	return null

static func _should_use_texture_for_size(size: Vector2) -> bool:
	if size.x <= 0 or size.y <= 0:
		return true
	if size.x < 180.0 or size.y < 52.0:
		return false
	if size.x / size.y > 3.35:
		return false
	return true

static func _ensure_texture_button_decoration(button: TextureButton) -> void:
	var inner := button.get_node_or_null("DreamInnerFrame") as Panel
	if inner == null:
		inner = Panel.new()
		inner.name = "DreamInnerFrame"
		inner.set_anchors_preset(Control.PRESET_FULL_RECT)
		inner.offset_left = 4
		inner.offset_top = 4
		inner.offset_right = -4
		inner.offset_bottom = -4
		inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(inner)

	var top_glow := button.get_node_or_null("DreamTopGlow") as ColorRect
	if top_glow == null:
		top_glow = ColorRect.new()
		top_glow.name = "DreamTopGlow"
		top_glow.anchor_left = 0.0
		top_glow.anchor_top = 0.0
		top_glow.anchor_right = 1.0
		top_glow.anchor_bottom = 0.0
		top_glow.offset_left = 10
		top_glow.offset_top = 5
		top_glow.offset_right = -10
		top_glow.offset_bottom = 9
		top_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(top_glow)

	var scan := button.get_node_or_null("DreamScanLine") as ColorRect
	if scan == null:
		scan = ColorRect.new()
		scan.name = "DreamScanLine"
		scan.anchor_left = 0.08
		scan.anchor_right = 0.92
		scan.anchor_top = 0.46
		scan.anchor_bottom = 0.46
		scan.offset_top = -1
		scan.offset_bottom = 1
		scan.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(scan)

	_ensure_corner_line(button, "DreamCornerTL_H", Vector2(8, 8), Vector2(34, 3))
	_ensure_corner_line(button, "DreamCornerTL_V", Vector2(8, 8), Vector2(3, 20))
	_ensure_corner_line(button, "DreamCornerBR_H", Vector2(-42, -11), Vector2(34, 3), true)
	_ensure_corner_line(button, "DreamCornerBR_V", Vector2(-11, -28), Vector2(3, 20), true)

static func _ensure_corner_line(button: TextureButton, node_name: String, pos: Vector2, size: Vector2, from_bottom_right: bool = false) -> void:
	var line := button.get_node_or_null(node_name) as ColorRect
	if line:
		return
	line = ColorRect.new()
	line.name = node_name
	line.size = size
	if from_bottom_right:
		line.anchor_left = 1.0
		line.anchor_top = 1.0
		line.anchor_right = 1.0
		line.anchor_bottom = 1.0
	line.position = pos
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(line)

static func _apply_decor_state(button: TextureButton, state: String) -> void:
	var inner := button.get_node_or_null("DreamInnerFrame") as Panel
	if inner:
		var inner_style := StyleBoxFlat.new()
		inner_style.bg_color = Color(0, 0, 0, 0)
		inner_style.set_border_width_all(1)
		inner_style.set_corner_radius_all(4)
		match state:
			"hover":
				inner_style.border_color = Color(0.75, 1.0, 1.0, 0.5)
			"pressed":
				inner_style.border_color = Color(COLOR_GOLD.r, COLOR_GOLD.g, COLOR_GOLD.b, 0.68)
			"disabled":
				inner_style.border_color = Color(0.5, 0.55, 0.62, 0.18)
			_:
				inner_style.border_color = Color(0.7, 0.95, 1.0, 0.26)
		inner.add_theme_stylebox_override("panel", inner_style)

	var top_glow := button.get_node_or_null("DreamTopGlow") as ColorRect
	if top_glow:
		match state:
			"hover":
				top_glow.color = Color(0.75, 1.0, 1.0, 0.26)
			"pressed":
				top_glow.color = Color(COLOR_GOLD.r, COLOR_GOLD.g, COLOR_GOLD.b, 0.2)
			"disabled":
				top_glow.color = Color(0.7, 0.8, 0.9, 0.04)
			_:
				top_glow.color = COLOR_GLASS

	var scan := button.get_node_or_null("DreamScanLine") as ColorRect
	if scan:
		match state:
			"hover":
				scan.color = Color(0.35, 0.95, 1.0, 0.24)
			"pressed":
				scan.color = Color(COLOR_GOLD.r, COLOR_GOLD.g, COLOR_GOLD.b, 0.22)
			_:
				scan.color = Color(0.2, 0.7, 0.9, 0.09)

	var corner_color := Color(COLOR_GOLD.r, COLOR_GOLD.g, COLOR_GOLD.b, 0.48)
	match state:
		"hover":
			corner_color = Color(COLOR_GOLD.r, COLOR_GOLD.g, COLOR_GOLD.b, 0.9)
		"pressed":
			corner_color = Color(0.35, 0.95, 1.0, 0.85)
		"disabled":
			corner_color = Color(0.5, 0.55, 0.62, 0.22)
	for node_name in ["DreamCornerTL_H", "DreamCornerTL_V", "DreamCornerBR_H", "DreamCornerBR_V"]:
		var line := button.get_node_or_null(node_name) as ColorRect
		if line:
			line.color = corner_color

static func _set_decor_visible(button: TextureButton, visible: bool) -> void:
	for node_name in ["DreamInnerFrame", "DreamTopGlow", "DreamScanLine", "DreamCornerTL_H", "DreamCornerTL_V", "DreamCornerBR_H", "DreamCornerBR_V"]:
		var node := button.get_node_or_null(node_name) as CanvasItem
		if node:
			node.visible = visible
