# ============================================================
# Level_04_UIBuilder.gd - UI 构建器
# ============================================================
extends RefCounted
class_name Level_04_UIBuilder

var level: Level_04
var canvas: CanvasLayer

func _init(parent: Level_04, canvas_layer: CanvasLayer) -> void:
	level = parent
	canvas = canvas_layer

func build_all() -> void:
	_build_narrative_panel()
	_build_glitch_overlay()
	_build_ending_prompt()


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


func _build_ending_prompt() -> void:
	var prompt = Control.new()
	prompt.name = "EndingPrompt"
	prompt.visible = false
	prompt.set_anchors_preset(Control.PRESET_FULL_RECT)
	prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var bg = ColorRect.new()
	bg.name = "Background"
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.95)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prompt.add_child(bg)

	var label = Label.new()
	label.name = "EndingLabel"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color(0.8, 0.1, 0.3, 0.95))
	label.position = Vector2(240, 240)
	label.size = Vector2(800, 240)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prompt.add_child(label)
	level._ending_label = label
	canvas.add_child(prompt)
	level._ending_prompt = prompt
