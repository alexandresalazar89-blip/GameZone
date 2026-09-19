extends Resource
class_name GameMetadata

@export var id: StringName
@export var title: String = ""
@export var version: String = "0.0.0"
@export_multiline var controls_text: String = ""
@export var thumbnail: Texture2D
@export var entry_scene: PackedScene
@export var native_size: Vector2i = Vector2i(320, 180)


func is_valid() -> bool:
	return (
		not id.is_empty()
		and not title.is_empty()
		and entry_scene != null
		and native_size.x > 0
		and native_size.y > 0
	)
