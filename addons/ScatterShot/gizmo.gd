@tool
class_name ScatterShotGizmo
extends RefCounted

# Abstract class.


var _plugin: ScatterShotPlugin

func _init(plugin: ScatterShotPlugin) -> void:
	_plugin = plugin


func get_handle_name(_gizmo: EditorNode3DGizmo, _handle_id: int, _secondary: bool) -> String:
	return ""


func get_handle_value(_gizmo: EditorNode3DGizmo, _handle_id: int, _secondary: bool) -> Variant:
	return null


func set_handle(_gizmo: EditorNode3DGizmo, _handle_id: int, _secondary: bool, _camera: Camera3D, _screen_pos: Vector2) -> void:
	pass


func commit_handle(_gizmo: EditorNode3DGizmo, _handle_id: int, _secondary: bool, _restore: Variant, _cancel: bool) -> void:
	pass


func redraw(_gizmo_plugin: EditorNode3DGizmoPlugin, _gizmo: EditorNode3DGizmo):
	pass


func forward_3d_gui_input(_viewport_camera: Camera3D, _event: InputEvent) -> bool:
	return false


func is_selected(gizmo: EditorNode3DGizmo) -> bool:
	if not _plugin:
		return true

	return gizmo.get_node_3d() in _plugin.get_editor_interface().get_selection().get_selected_nodes()
