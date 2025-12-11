@tool
class_name ScatterShotGizmoPlugin
extends EditorNode3DGizmoPlugin

var _plugin: ScatterShotPlugin

var gizmo_circle: ScatterShotGizmoCircle
var gizmo_rect: ScatterShotGizmoRect
var gizmo_null: ScatterShotGizmo

const _icon_texture: Texture2D = preload("uid://8fjoc5gvqu7x")

const COLOR_ZONE: Color = Color(1.0, 1.0, 1.0)
const COLOR_MODULATOR_POSITIVE: Color = Color(0.9, 0.7, 0.2, 0.15)
const COLOR_MODULATOR_NEGATIVE: Color = Color(0.9, 0.1, 0.2, 0.15)
const ICON_SCALE: float = 0.015

static func color_for_shape(shape: ScatterShotShape) -> Color:
	if shape is ScatterShotZone:
		return COLOR_ZONE
	if shape.density > 0.0:
		return COLOR_MODULATOR_POSITIVE
	return COLOR_MODULATOR_NEGATIVE

func _init(plugin: ScatterShotPlugin):
	_plugin = plugin
	create_icon_material("icon", _icon_texture, false, Color.WHITE)

	create_custom_material("lines", Color(1, 0.4, 0))

	create_material("zone", COLOR_ZONE)
	create_material("modulator_positive", COLOR_MODULATOR_POSITIVE)
	create_material("modulator_negative", COLOR_MODULATOR_NEGATIVE)

	create_handle_material("default_handle")

	gizmo_circle = ScatterShotGizmoCircle.new(plugin)
	gizmo_rect = ScatterShotGizmoRect.new(plugin)
	gizmo_null = ScatterShotGizmo.new(plugin)


func _get_gizmo_name() -> String:
	return "ScatterShot"

func _has_gizmo(node: Node3D) -> bool:
	return node is ScatterShotShape

func _get_handle_name(gizmo: EditorNode3DGizmo, handle_id: int, secondary: bool) -> String:
	return get_gizmo(gizmo).get_handle_name(gizmo, handle_id, secondary)

func _get_handle_value(gizmo: EditorNode3DGizmo, handle_id: int, secondary: bool) -> Variant:
	return get_gizmo(gizmo).get_handle_value(gizmo, handle_id, secondary)

func _set_handle(gizmo: EditorNode3DGizmo, handle_id: int, secondary: bool, camera: Camera3D, screen_pos: Vector2) -> void:
	get_gizmo(gizmo).set_handle(gizmo, handle_id, secondary, camera, screen_pos)

func _commit_handle(gizmo: EditorNode3DGizmo, handle_id: int, secondary: bool, restore: Variant, cancel: bool) -> void:
	get_gizmo(gizmo).commit_handle(gizmo, handle_id, secondary, restore, cancel)

func _redraw(gizmo: EditorNode3DGizmo) -> void:
	get_gizmo(gizmo).redraw(self, gizmo)

func forward_3d_gui_input(viewport_camera: Camera3D, event: InputEvent) -> int:
	if gizmo_rect.forward_3d_gui_input(viewport_camera, event):
		return EditorPlugin.AFTER_GUI_INPUT_STOP
	if gizmo_circle.forward_3d_gui_input(viewport_camera, event):
		return EditorPlugin.AFTER_GUI_INPUT_STOP
	return EditorPlugin.AFTER_GUI_INPUT_PASS

# Creates a standard material displayed on top of everything.
# Only exists because 'create_material() on_top' parameter doesn't seem to work.
func create_custom_material(name: String, color := Color.WHITE) -> void:
	var material := StandardMaterial3D.new()
	material.set_blend_mode(StandardMaterial3D.BLEND_MODE_ADD)
	material.set_shading_mode(StandardMaterial3D.SHADING_MODE_UNSHADED)
	material.set_flag(StandardMaterial3D.FLAG_DISABLE_DEPTH_TEST, true)
	material.set_albedo(color)
	material.render_priority = 100

	add_material(name, material)

func get_gizmo(gizmo: EditorNode3DGizmo) -> ScatterShotGizmo:
	var node: ScatterShotShape = gizmo.get_node_3d()
	match node.shape:
		ScatterShotShape.Shape.RECT:
			return gizmo_rect
		ScatterShotShape.Shape.CIRCLE:
			return gizmo_circle
		_:
			return gizmo_null
