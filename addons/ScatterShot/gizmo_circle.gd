@tool
class_name ScatterShotGizmoCircle
extends ScatterShotGizmo


# 3D Gizmo for the Sphere shape. Draws three circle on each axis to represent
# a sphere, displays one handle on the size to control the radius.
#
# (handle_id is ignored in every function since there's a single handle)


func get_handle_name(_gizmo: EditorNode3DGizmo, _handle_id: int, _secondary: bool) -> String:
	return "Circle Radius"


func get_handle_value(gizmo: EditorNode3DGizmo, _handle_id: int, _secondary: bool) -> Variant:
	return gizmo.get_node_3d().circle_radius


func set_handle(gizmo: EditorNode3DGizmo, _handle_id: int, _secondary: bool, camera: Camera3D, screen_pos: Vector2) -> void:
	var node = gizmo.get_node_3d()
	var gt := node.get_global_transform()
	var gt_inverse := gt.affine_inverse()
	var origin := gt.origin

	var ray_from = camera.project_ray_origin(screen_pos)
	var ray_to = ray_from + camera.project_ray_normal(screen_pos) * 4096
	var points = Geometry3D.get_closest_points_between_segments(origin, (Vector3.LEFT * 4096) * gt_inverse, ray_from, ray_to)
	node.circle_radius = origin.distance_to(points[0])


func commit_handle(gizmo: EditorNode3DGizmo, _handle_id: int, _secondary: bool, restore: Variant, cancel: bool) -> void:
	var node: Node3D = gizmo.get_node_3d()
	if cancel:
		node.circle_radius = restore
		return

	var undo_redo: EditorUndoRedoManager = _plugin.get_undo_redo()
	undo_redo.create_action("Set Scatter Circle Radius")
	undo_redo.add_undo_method(self, "_set_circle_radius", node, restore)
	undo_redo.add_do_method(self, "_set_circle_radius", node, node.circle_radius)
	undo_redo.commit_action()


func redraw(plugin: EditorNode3DGizmoPlugin, gizmo: EditorNode3DGizmo):
	gizmo.clear()

	var node: ScatterShotShape = gizmo.get_node_3d()
		
	var icon: Material = plugin.get_material("icon", gizmo)
	gizmo.add_unscaled_billboard(icon, ScatterShotGizmoPlugin.ICON_SCALE, ScatterShotGizmoPlugin.color_for_shape(node))

	var lines := PackedVector3Array()
	var lines_material := plugin.get_material("lines", gizmo)
	var steps: float = 32 # TODO: Update based on sphere radius maybe ?
	var step_angle: float = 2 * PI / steps
	var radius: float = node.circle_radius

	for i in steps:
		lines.append(Vector3(cos(i * step_angle), 0.0, sin(i * step_angle)) * radius)
		lines.append(Vector3(cos((i + 1) * step_angle), 0.0, sin((i + 1) * step_angle)) * radius)

	gizmo.add_lines(lines, lines_material)
	gizmo.add_collision_segments(lines)
	
	if not is_selected(gizmo):
		return
	
	### Fills the circle inside
	var mesh = CylinderMesh.new()
	mesh.cap_bottom = true
	mesh.cap_top = true
	mesh.rings = 0
	mesh.radial_segments = steps
	mesh.top_radius = radius
	mesh.bottom_radius = radius

	var mesh_material: StandardMaterial3D = plugin.get_material("modulator_positive" if (node is ScatterShotZone or node.density > 0.0) else "modulator_negative", gizmo) 

	if node is ScatterShotZone:
		mesh.height = node.depth
		gizmo.add_mesh(mesh, mesh_material, Transform3D(Basis.IDENTITY, Vector3(0, node.depth * -0.5, 0)))
	else:
		mesh.height = 0.0
		gizmo.add_mesh(mesh, mesh_material)

	### Draw the handle
	var handles := PackedVector3Array()
	var handles_ids := PackedInt32Array()
	var handles_material := plugin.get_material("default_handle", gizmo)

	var handle_position: Vector3 = Vector3.LEFT * radius
	handles.push_back(handle_position)

	gizmo.add_handles(handles, handles_material, handles_ids)


func _set_circle_radius(node: ScatterShotShape, radius: float) -> void:
	if node:
		node.circle_radius = radius
