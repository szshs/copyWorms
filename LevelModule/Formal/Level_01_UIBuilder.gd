# ============================================================
# Level_01_UIBuilder.gd - UI 构建器
# 负责叙事面板、睡眠覆盖层、IDE界面、Glitch覆盖层的创建
# ============================================================
extends RefCounted
class_name Level_01_UIBuilder

var level: Level_01
var canvas: CanvasLayer

func _init(parent: Level_01, canvas_layer: CanvasLayer) -> void:
	level = parent
	canvas = canvas_layer

func build_all() -> void:
	_build_sleep_overlay()
	_build_narrative_panel()
	_build_ide_ui()
	_build_glitch_overlay()

func _build_sleep_overlay() -> void:
	var overlay = ColorRect.new()
	overlay.name = "SleepOverlay"
	overlay.visible = false
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(overlay)
	level._sleep_overlay = overlay

func _build_narrative_panel() -> void:
	var panel = Panel.new()
	panel.name = "NarrativePanel"
	panel.visible = false
	panel.size = Vector2(1280, 200)
	panel.position = Vector2(0, 520)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.85)
	style.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", style)

	var label = RichTextLabel.new()
	label.name = "RichTextLabel"
	label.size = Vector2(1240, 160)
	label.position = Vector2(20, 20)
	label.bbcode_enabled = true
	label.fit_content = true
	label.add_theme_font_size_override("normal_font_size", 18)
	label.add_theme_color_override("default_color", Color(0.9, 0.85, 0.75))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(label)
	level._narrative_text = label

	canvas.add_child(panel)
	level._narrative_panel = panel

func _build_ide_ui() -> void:
	var ide = Control.new()
	ide.name = "IdeUI"
	ide.visible = false
	ide.set_anchors_preset(Control.PRESET_FULL_RECT)

	var bg = ColorRect.new()
	bg.name = "Background"
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.06, 0.07, 0.1, 0.97)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ide.add_child(bg)

	# 标题栏
	var title_bar = ColorRect.new()
	title_bar.name = "TitleBar"
	title_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title_bar.color = Color(0.1, 0.12, 0.18, 1.0)
	title_bar.custom_minimum_size = Vector2(0, 40)
	title_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ide.add_child(title_bar)

	var title_label = Label.new()
	title_label.name = "TitleLabel"
	title_label.text = "◆ AI IDE v0.1-Beta — localhost:8080"
	title_label.add_theme_font_size_override("font_size", 15)
	title_label.add_theme_color_override("font_color", Color(0.4, 0.85, 0.5))
	title_label.position = Vector2(15, 10)
	ide.add_child(title_label)

	# 聊天面板
	var chat_panel = Panel.new()
	chat_panel.name = "ChatPanel"
	chat_panel.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	chat_panel.anchor_right = 0.5
	chat_panel.offset_left = 20
	chat_panel.offset_top = 55
	chat_panel.offset_right = -15
	chat_panel.offset_bottom = -25

	var chat_style = StyleBoxFlat.new()
	chat_style.bg_color = Color(0.08, 0.1, 0.14, 0.9)
	chat_style.border_width_left = 2
	chat_style.border_width_right = 2
	chat_style.border_width_top = 2
	chat_style.border_width_bottom = 2
	chat_style.border_color = Color(0.2, 0.25, 0.35)
	chat_style.set_corner_radius_all(6)
	chat_panel.add_theme_stylebox_override("panel", chat_style)
	ide.add_child(chat_panel)

	var tab_label = Label.new()
	tab_label.name = "TabLabel"
	tab_label.text = "  Terminal / Chat  "
	tab_label.add_theme_font_size_override("font_size", 12)
	tab_label.add_theme_color_override("font_color", Color(0.5, 0.6, 0.7))
	tab_label.position = Vector2(30, 42)
	ide.add_child(tab_label)

	var chat = RichTextLabel.new()
	chat.name = "ChatWindow"
	chat.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	chat.anchor_right = 0.5
	chat.offset_left = 30
	chat.offset_top = 68
	chat.offset_right = -25
	chat.offset_bottom = -35
	chat.bbcode_enabled = true
	chat.scroll_following = true
	chat.add_theme_font_size_override("normal_font_size", 15)
	chat.add_theme_color_override("default_color", Color(0.85, 0.85, 0.85))
	ide.add_child(chat)
	level._chat_window = chat

	# 代码滚动面板（IDE 对话"正在编译"阶段显示，替代预览面板位置）
	var code_panel = Panel.new()
	code_panel.name = "CodeScrollPanel"
	code_panel.visible = false
	code_panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	code_panel.anchor_left = 0.52
	code_panel.offset_left = 15
	code_panel.offset_top = 55
	code_panel.offset_right = -20
	code_panel.offset_bottom = -25

	var code_style = StyleBoxFlat.new()
	code_style.bg_color = Color(0.04, 0.05, 0.08, 0.95)
	code_style.border_width_left = 2
	code_style.border_width_right = 2
	code_style.border_width_top = 2
	code_style.border_width_bottom = 2
	code_style.border_color = Color(0.15, 0.55, 0.3)
	code_style.set_corner_radius_all(6)
	code_panel.add_theme_stylebox_override("panel", code_style)
	ide.add_child(code_panel)

	var code_tab = Label.new()
	code_tab.name = "CodeTab"
	code_tab.text = "  Xiguan_Dream.gd  ●  "
	code_tab.add_theme_font_size_override("font_size", 12)
	code_tab.add_theme_color_override("font_color", Color(0.3, 0.8, 0.45))
	code_tab.position = Vector2(678, 42)
	ide.add_child(code_tab)

	var code_text = RichTextLabel.new()
	code_text.name = "CodeScrollText"
	code_text.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	code_text.anchor_left = 0.52
	code_text.offset_left = 25
	code_text.offset_top = 68
	code_text.offset_right = -30
	code_text.offset_bottom = -35
	code_text.bbcode_enabled = true
	code_text.scroll_following = true
	code_text.add_theme_font_size_override("normal_font_size", 13)
	code_text.add_theme_color_override("default_color", Color(0.55, 0.9, 0.6))
	ide.add_child(code_text)
	level._code_scroll_panel = code_panel
	level._code_scroll_text = code_text

	# 预览面板
	var preview_panel = Panel.new()
	preview_panel.name = "PreviewPanel"
	preview_panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	preview_panel.anchor_left = 0.52
	preview_panel.offset_left = 15
	preview_panel.offset_top = 55
	preview_panel.offset_right = -20
	preview_panel.offset_bottom = -25

	var preview_style = StyleBoxFlat.new()
	preview_style.bg_color = Color(0.08, 0.1, 0.14, 0.9)
	preview_style.border_width_left = 2
	preview_style.border_width_right = 2
	preview_style.border_width_top = 2
	preview_style.border_width_bottom = 2
	preview_style.border_color = Color(0.2, 0.25, 0.35)
	preview_style.set_corner_radius_all(6)
	preview_panel.add_theme_stylebox_override("panel", preview_style)
	ide.add_child(preview_panel)

	var preview_tab = Label.new()
	preview_tab.name = "PreviewTab"
	preview_tab.text = "  Local Test Viewport  "
	preview_tab.add_theme_font_size_override("font_size", 12)
	preview_tab.add_theme_color_override("font_color", Color(0.5, 0.6, 0.7))
	preview_tab.position = Vector2(678, 42)
	ide.add_child(preview_tab)

	var viewport_container = SubViewportContainer.new()
	viewport_container.name = "ViewportContainer"
	viewport_container.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	viewport_container.anchor_left = 0.52
	viewport_container.offset_left = 25
	viewport_container.offset_top = 68
	viewport_container.offset_right = -30
	viewport_container.offset_bottom = -35
	viewport_container.stretch = true

	var mini_viewport = SubViewport.new()
	mini_viewport.name = "MiniViewport"
	mini_viewport.size = Vector2(600, 400)
	mini_viewport.transparent_bg = true
	viewport_container.add_child(mini_viewport)
	level._mini_viewport = mini_viewport
	level._viewport_container = viewport_container
	ide.add_child(viewport_container)

	# 状态栏
	var status_bar = ColorRect.new()
	status_bar.name = "StatusBar"
	status_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	status_bar.color = Color(0.1, 0.12, 0.18, 1.0)
	status_bar.custom_minimum_size = Vector2(0, 22)
	status_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ide.add_child(status_bar)

	canvas.add_child(ide)
	level._ide_ui = ide

func _build_glitch_overlay() -> void:
	var overlay = ColorRect.new()
	overlay.name = "GlitchOverlay"
	overlay.visible = false
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var shader = load("res://LevelModule/Formal/glitch_effect.gdshader")
	if shader:
		var mat = ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter("intensity", 0.0)
		overlay.material = mat

	canvas.add_child(overlay)
	level._glitch_overlay = overlay
