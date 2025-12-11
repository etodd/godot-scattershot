@tool
class_name ScatterShotMeshes
extends ScatterShotCollection

@export var mesh_library: MeshLibrary:
	set(value):
		if mesh_library:
			mesh_library.changed.disconnect(self._changed)
		mesh_library = value
		mesh_library.changed.connect(self._changed)
		_changed()

## Proportion of each mesh to spawn, relative to other meshes.
@export_range(1, 1000, 1, "or_greater") var mesh_proportions: Array[int]:
	set(value):
		mesh_proportions = value
		_proportion_sum = 0 # mark dirty
		_changed()

## Overrides the distance fade mode on all materials in the MeshLibrary.
@export var distance_fade_mode: BaseMaterial3D.DistanceFadeMode = BaseMaterial3D.DISTANCE_FADE_OBJECT_DITHER:
	set(value):
		distance_fade_mode = value
		_changed()

## The physics layers each mesh will exist in.
@export_flags_3d_physics var collision_layer: int = 2:
	set(value):
		collision_layer = value
		_changed()

## The physics layers each mesh will scan.
@export_flags_3d_physics var collision_mask: int = 1:
	set(value):
		collision_mask = value
		_changed()

## Arbitrary user data which you can refer to when handling collisions with
## meshes in this collection.
@export var collision_user_data: Variant

func _reset_state() -> void:
	_changed()

func _changed() -> void:
	super()
	for layer: ScatterShotLayer in _layer_surface_overrides:
		_layer_surface_overrides[layer].clear()
	_layer_surface_overrides.clear()
	_proportion_sum = 0 # mark dirty
	var mesh_ids: PackedInt32Array = mesh_library.get_item_list()
	if mesh_proportions.size() > mesh_ids.size():
		mesh_proportions.resize(mesh_ids.size())
	elif mesh_proportions.size() < mesh_ids.size():
		var i: int = mesh_proportions.size()
		while i < mesh_ids.size():
			mesh_proportions.push_back(10)
			i += 1

var _proportion_sum: int
func proportion_sum() -> int:
	if _proportion_sum == 0:
		for proportion: int in mesh_proportions:
			_proportion_sum += proportion
	return _proportion_sum

func item_index(proportion: int) -> int:
	var sum: int = 0
	for item_index: int in mesh_proportions.size():
		var new_sum: int = sum + mesh_proportions[item_index]
		if proportion < new_sum:
			return item_index
		sum = new_sum
	return -1 # should never happen

class SurfaceOverride:
	var materials: Array[BaseMaterial3D] = []
	var view_distance: float
	var fade_distance: float

func surface_override_materials(layer: ScatterShotLayer, item_index: int) -> Array[BaseMaterial3D]:
	var surface_overrides: Array[SurfaceOverride] = _surface_overrides_for_layer(layer)
	var surface_override := surface_overrides[item_index]
	if not surface_override:
		surface_override = SurfaceOverride.new()
		var mesh: Mesh = mesh_library.get_item_mesh(item_index)
		surface_override.materials.resize(mesh.get_surface_count())
		if distance_fade_mode != BaseMaterial3D.DISTANCE_FADE_DISABLED:
			for i: int in mesh.get_surface_count():
				var material: Material = mesh.surface_get_material(i)
				if not material is BaseMaterial3D:
					continue
				var material3d: BaseMaterial3D = material.duplicate()
				material3d.distance_fade_mode = distance_fade_mode
				surface_override.materials[i] = material3d
		surface_overrides[item_index] = surface_override
	
	if surface_override.view_distance == layer.view_distance and surface_override.fade_distance == layer.fade_distance:
		return surface_override.materials
	
	for material: BaseMaterial3D in surface_override.materials:
		if not material:
			continue
		material.distance_fade_min_distance = layer.view_distance
		material.distance_fade_max_distance = layer.fade_distance
	surface_override.view_distance = layer.view_distance
	surface_override.fade_distance = layer.fade_distance
	return surface_override.materials

var _layer_surface_overrides: Dictionary[ScatterShotLayer, Array] = {}
func _surface_overrides_for_layer(layer: ScatterShotLayer) -> Array[SurfaceOverride]:
	var untyped := _layer_surface_overrides.get(layer)
	if not untyped:
		var d: Array[SurfaceOverride] = []
		d.resize(mesh_library.get_item_list().size())
		untyped = d
		_layer_surface_overrides[layer] = d
	return untyped
