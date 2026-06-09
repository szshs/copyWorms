# res://DataConfig/Level/Level01Data.gd
class_name Level01Data
extends Resource

@export_category("Obstacle Narrative")
@export_multiline var obstacle_1_text: String = ""
@export_multiline var obstacle_2_text: String = ""

@export_category("Bed Sleep Cycles")
@export var sleep_texts: Array[String] = []

@export_category("AI IDE Dialogues")
## 与 ide_texts 一一对应: "System" / "AI" / "Ming"
@export var ide_speakers: Array[String] = []
## 与 ide_speakers 一一对应，每条对话的文本内容
@export_multiline var ide_texts: Array[String] = []

@export_category("Bedroom Detail Objects")
@export_multiline var notice_text: String = ""
@export_multiline var thermos_text: String = ""

@export_category("Phone Climax")
@export_multiline var phone_sender: String = ""
@export_multiline var phone_content: String = ""
@export_multiline var climax_monologue: String = ""
