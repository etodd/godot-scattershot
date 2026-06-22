class_name ScatterShotEditorCamera
extends RefCounted

static func get_instance() -> Camera3D:
	return EditorInterface.get_editor_viewport_3d().get_camera_3d()
