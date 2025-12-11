@tool
class_name ScatterShotChunk
extends RefCounted

var layer: ScatterShotLayer

var instance_rids: Array[RID] = []
var active_instance_count: int = 0
var scenario: RID

var body_rids: Array[RID] = []
var active_body_count: int = 0
var space: RID

func _init(scatter_layer: ScatterShotLayer, render_scenario: RID, physics_space: RID):
	layer = scatter_layer
	scenario = render_scenario
	space = physics_space

func items_begin() -> void:
	active_instance_count = 0
	active_body_count = 0

func items_add(collection: ScatterShotCollection, item_index: int, transform: Transform3D) -> void:
	if collection is ScatterShotMeshes:
		_add_mesh(collection, item_index, transform)
	elif collection is ScatterShotDecals:
		_add_decal(collection, item_index, transform)
	else:
		push_error("items_add not implemented for this collection type")

func _add_mesh(collection: ScatterShotMeshes, item_index: int, transform: Transform3D) -> void:
	var mesh_rid: RID = collection.mesh_library.get_item_mesh(item_index).get_rid()
	var instance_rid: RID = _add_instance(mesh_rid, transform, collection.visibility_layers)
	var surface_override_materials: Array[BaseMaterial3D] = collection.surface_override_materials(layer, item_index)
	for surface_index: int in surface_override_materials.size():
		var material := surface_override_materials[surface_index]
		RenderingServer.instance_set_surface_override_material(instance_rid, surface_index, material.get_rid() if material else RID())

	# collision
	var shapes: Array = collection.mesh_library.get_item_shapes(item_index)
	if shapes.size() == 0:
		return
	var shape_rid: RID = shapes[0].get_rid()
	var shape_transform: Transform3D = shapes[1]
	var body_rid: RID
	if active_body_count < body_rids.size():
		body_rid = body_rids[active_body_count]
		PhysicsServer3D.body_set_shape(body_rid, 0, shape_rid)
		PhysicsServer3D.body_set_shape_transform(body_rid, 0, shape_transform)
	else:
		body_rid = PhysicsServer3D.body_create()
		PhysicsServer3D.body_set_mode(body_rid, PhysicsServer3D.BODY_MODE_STATIC)
		PhysicsServer3D.body_set_space(body_rid, space)
		PhysicsServer3D.body_add_shape(body_rid, shape_rid, shape_transform)
		body_rids.push_back(body_rid)
	active_body_count += 1
	PhysicsServer3D.body_attach_object_instance_id(body_rid, collection.get_instance_id())
	PhysicsServer3D.body_set_state(body_rid, PhysicsServer3D.BODY_STATE_TRANSFORM, transform)
	PhysicsServer3D.body_set_collision_layer(body_rid, collection.collision_layer)
	PhysicsServer3D.body_set_collision_mask(body_rid, collection.collision_mask)

func _add_decal(collection: ScatterShotDecals, item_index: int, transform: Transform3D) -> void:
	var decal_rid: RID = collection.decal_rid(layer, item_index)
	_add_instance(decal_rid, transform, collection.visibility_layers)

func _add_instance(base_rid: RID, transform: Transform3D, visibility_layers: int) -> RID:
	var instance_rid: RID
	if active_instance_count < instance_rids.size():
		instance_rid = instance_rids[active_instance_count]
		RenderingServer.instance_set_base(instance_rid, base_rid)
	else:
		instance_rid = RenderingServer.instance_create2(base_rid, scenario)
		instance_rids.push_back(instance_rid)
	active_instance_count += 1
	RenderingServer.instance_set_transform(instance_rid, transform)
	RenderingServer.instance_teleport(instance_rid)
	RenderingServer.instance_set_layer_mask(instance_rid, visibility_layers)
	return instance_rid

func items_end() -> void:
	var i: int = active_instance_count
	while i < instance_rids.size():
		RenderingServer.free_rid(instance_rids[i])
		i += 1
	instance_rids.resize(active_instance_count)

	i = active_body_count
	while i < body_rids.size():
		PhysicsServer3D.free_rid(body_rids[i])
		i += 1
	body_rids.resize(active_body_count)
