@tool
class_name ScatterShotPlugin
extends EditorPlugin

var gizmo_plugin: ScatterShotGizmoPlugin

func _enter_tree():
	gizmo_plugin = ScatterShotGizmoPlugin.new(self)
	add_node_3d_gizmo_plugin(gizmo_plugin)
	add_custom_type("ScatterShotShape", "Node3D", preload("shape.gd"), preload("icon.svg"))
	add_custom_type("ScatterShotModulator", "ScatterShotShape", preload("modulator.gd"), preload("icon.svg"))
	add_custom_type("ScatterShotZone", "ScatterShotShape", preload("zone.gd"), preload("icon.svg"))


func _exit_tree():
	remove_node_3d_gizmo_plugin(gizmo_plugin)
	remove_custom_type("ScatterShotShape")
	remove_custom_type("ScatterShotModulator")
	remove_custom_type("ScatterShotZone")
