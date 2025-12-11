@tool
class_name ScatterShotGizmoRect
extends ScatterShotGizmo

# 3D Gizmo for the Rect shape.


func get_handle_name(_gizmo: EditorNode3DGizmo, _handle_id: int, _secondary: bool) -> String:
	return "Rect Size"


func get_handle_value(gizmo: EditorNode3DGizmo, handle_id: int, _secondary: bool) -> Variant:
	return (gizmo.get_node_3d() as ScatterShotShape).rect_size


func set_handle(gizmo: EditorNode3DGizmo, handle_id: int, _secondary: bool, camera: Camera3D, screen_pos: Vector2) -> void:
	if handle_id < 0 or handle_id > 1:
		return

	var axis := Vector3.ZERO
	match handle_id:
		0:
			axis.x = 1.0
		_:
			axis.z = 1.0
	var shape: ScatterShotShape = gizmo.get_node_3d()
	var gt := shape.get_global_transform()
	var gt_inverse := gt.affine_inverse()

	var origin := gt.origin
	var drag_axis := (axis * 4096) * gt_inverse
	var ray_from = camera.project_ray_origin(screen_pos)
	var ray_to = ray_from + camera.project_ray_normal(screen_pos) * 4096

	var points = Geometry3D.get_closest_points_between_segments(origin, drag_axis, ray_from, ray_to)

	var axis2d: Vector2 = Vector2(axis.x, axis.z)
	var size = shape.rect_size
	size -= axis2d * size
	var dist = origin.distance_to(points[0]) * 2.0
	size += axis2d * dist

	shape.rect_size = size


func commit_handle(gizmo: EditorNode3DGizmo, handle_id: int, _secondary: bool, restore: Variant, cancel: bool) -> void:
	var shape: ScatterShotShape = gizmo.get_node_3d()
	if cancel:
		shape.rect_size = restore
		return

	var undo_redo: EditorUndoRedoManager = _plugin.get_undo_redo()
	undo_redo.create_action("Set Scatter Rect Size")
	undo_redo.add_undo_method(self, "_set_rect_size", shape, restore)
	undo_redo.add_do_method(self, "_set_rect_size", shape, shape.rect_size)
	undo_redo.commit_action()


func redraw(plugin: EditorNode3DGizmoPlugin, gizmo: EditorNode3DGizmo):
	gizmo.clear()
	
	var node: ScatterShotShape = gizmo.get_node_3d()
	
	var icon: Material = plugin.get_material("icon", gizmo)
	gizmo.add_unscaled_billboard(icon, ScatterShotGizmoPlugin.ICON_SCALE, ScatterShotGizmoPlugin.color_for_shape(node))

	### Draw the Box lines
	var lines = PackedVector3Array()
	var lines_material := plugin.get_material("lines", gizmo)
	var half_size: Vector3 = Vector3(node.rect_size.x * 0.5, 0.0, node.rect_size.y * 0.5)

	lines.push_back(Vector3(-1, 0, -1) * half_size)
	lines.push_back(Vector3(-1, 0, 1) * half_size)
	
	lines.push_back(Vector3(-1, 0, 1) * half_size)
	lines.push_back(Vector3(1, 0, 1) * half_size)
	
	lines.push_back(Vector3(1, 0, 1) * half_size)
	lines.push_back(Vector3(1, 0, -1) * half_size)
	
	lines.push_back(Vector3(1, 0, -1) * half_size)
	lines.push_back(Vector3(-1, 0, -1) * half_size)

	gizmo.add_lines(lines, lines_material)
	gizmo.add_collision_segments(lines)

	if not is_selected(gizmo):
		return
		
	### Fills the box inside
	var mesh = BoxMesh.new()

	var mesh_material: StandardMaterial3D = plugin.get_material("modulator_positive" if (node is ScatterShotZone or node.density > 0.0) else "modulator_negative", gizmo) 

	if node is ScatterShotZone:
		mesh.size = Vector3(node.rect_size.x, node.depth, node.rect_size.y)
		gizmo.add_mesh(mesh, mesh_material, Transform3D(Basis.IDENTITY, Vector3(0, node.depth * -0.5, 0)))
	else:
		mesh.size = Vector3(node.rect_size.x, 0.0, node.rect_size.y)
		gizmo.add_mesh(mesh, mesh_material)

	### Draw the handles, one for each axis
	var handles := PackedVector3Array()
	var handles_ids := PackedInt32Array()
	var handles_material := plugin.get_material("default_handle", gizmo)

	handles.push_back(Vector3.RIGHT * node.rect_size.x * 0.5)
	handles.push_back(Vector3.BACK * node.rect_size.y * 0.5)

	gizmo.add_handles(handles, handles_material, handles_ids)


func _set_rect_size(shape: ScatterShotShape, size: Vector2) -> void:
	if shape:
		shape.rect_size = size
