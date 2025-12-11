@tool
class_name ScatterShotDecals
extends ScatterShotCollection

## List of decal textures to spawn and the proportions with which to spawn them.
@export var decals: Array[ScatterShotDecal]:
	set(value):
		for decal: ScatterShotDecal in decals:
			if decal:
				decal.changed.disconnect(_changed)
		decals = value
		for decal: ScatterShotDecal in value:
			if decal:
				decal.changed.connect(_changed)
		_changed()

## Blends the albedo Color of the decal with albedo Color of the underlying mesh.
## This can be set to 0.0 to create a decal that only affects normal or ORM. In
## this case, an albedo texture is still required as its alpha channel will
## determine where the normal and ORM will be overridden.
@export var albedo_mix: float = 1.0:
	set(value):
		albedo_mix = value
		_changed()

## Specifies which render layers this decal will project on. By default, Decals
## affect all layers. This is used so you can specify which types of objects
## receive the Decal and which do not. This is especially useful so you can
## ensure that dynamic objects don't accidentally receive a Decal intended for
## the terrain under them.
@export_flags_3d_render var cull_mask: int = 1048575:
	set(value):
		cull_mask = value
		_changed()

## Sets the curve over which the decal will fade as the surface gets further from
## the center of the AABB.
@export var lower_fade: float = 0.3:
	set(value):
		lower_fade = value
		_changed()

## Sets the curve over which the decal will fade as the surface gets further from
## the center of the AABB.
@export var upper_fade: float = 0.3:
	set(value):
		upper_fade = value
		_changed()

## Changes the Color of the Decal by multiplying the albedo and emission colors
## with this value. The alpha component is only taken into account when
## multiplying the albedo color, not the emission color.
@export var modulate: Color = Color.WHITE:
	set(value):
		modulate = value
		_changed()

## Fades the Decal if the angle between the Decal's AABB and the target surface
## becomes too large. A value of 0 projects the Decal regardless of angle, a
## value of 1 limits the Decal to surfaces that are nearly perpendicular.
@export var normal_fade: float = 0.0:
	set(value):
		normal_fade = value
		_changed()

## Sets the size of the AABB used by the decal. All dimensions must be set to a
## value greater than zero (they will be clamped to 0.001 if this is not the
## case). The AABB goes from -size/2 to size/2.
@export var size: Vector3 = Vector3(2, 2, 2):
	set(value):
		size = value
		_changed()

## If true, decals will smoothly fade away when far from the active Camera3D,
## and eventually be culled and not sent to the shader at all. Use this to reduce
## the number of active Decals in a scene and thus improve performance.
@export var distance_fade_enabled: bool = true:
	set(value):
		distance_fade_enabled = value
		_changed()

var _proportion_sum: int
func proportion_sum() -> int:
	if _proportion_sum == 0:
		for decal: ScatterShotDecal in decals:
			if decal:
				_proportion_sum += decal.proportion
	return _proportion_sum

func item_index(proportion: int) -> int:
	var sum: int = 0
	for item_index: int in decals.size():
		var new_sum: int = sum + decals[item_index].proportion
		if proportion < new_sum:
			return item_index
		sum = new_sum
	return -1 # should never happen

func _reset_state() -> void:
	_changed()

func _changed() -> void:
	super()
	_proportion_sum = 0 # mark dirty
	for layer: ScatterShotLayer in _layer_modified_decals:
		var decals: Dictionary[int, ModifiedDecal] = _layer_modified_decals[layer]
		for item_index: int in decals:
			var modified_decal: ModifiedDecal = decals[item_index]
			RenderingServer.free_rid(modified_decal.rid)
		decals.clear()
	_layer_modified_decals.clear()

func decal_rid(layer: ScatterShotLayer, item_index: int) -> RID:
	var modified_decals: Dictionary[int, ModifiedDecal] = _modified_decals_for_layer(layer)
	var modified_decal := modified_decals.get(item_index)
	if not modified_decal:
		modified_decal = ModifiedDecal.new()
		modified_decal.rid = RenderingServer.decal_create()
		RenderingServer.decal_set_albedo_mix(modified_decal.rid, albedo_mix)
		RenderingServer.decal_set_cull_mask(modified_decal.rid, cull_mask)
		RenderingServer.decal_set_fade(modified_decal.rid, upper_fade, lower_fade)
		RenderingServer.decal_set_modulate(modified_decal.rid, modulate)
		RenderingServer.decal_set_normal_fade(modified_decal.rid, normal_fade)
		RenderingServer.decal_set_size(modified_decal.rid, size)
		var decal: ScatterShotDecal = decals[item_index]
		if decal.texture_albedo:
			RenderingServer.decal_set_texture(modified_decal.rid, RenderingServer.DECAL_TEXTURE_ALBEDO, decal.texture_albedo.get_rid())
		if decal.texture_normal:
			RenderingServer.decal_set_texture(modified_decal.rid, RenderingServer.DECAL_TEXTURE_NORMAL, decal.texture_normal.get_rid())
		if decal.texture_orm:
			RenderingServer.decal_set_texture(modified_decal.rid, RenderingServer.DECAL_TEXTURE_ORM, decal.texture_orm.get_rid())
		if decal.texture_emission:
			RenderingServer.decal_set_texture(modified_decal.rid, RenderingServer.DECAL_TEXTURE_EMISSION, decal.texture_emission.get_rid())
		modified_decals[item_index] = modified_decal
	
	if modified_decal.view_distance == layer.view_distance and modified_decal.fade_distance == layer.fade_distance:
		return modified_decal.rid
	
	RenderingServer.decal_set_distance_fade(modified_decal.rid, distance_fade_enabled, layer.view_distance - layer.fade_distance, layer.fade_distance)
	modified_decal.view_distance = layer.view_distance
	modified_decal.fade_distance = layer.fade_distance
	return modified_decal.rid

class ModifiedDecal:
	var rid: RID
	var view_distance: float
	var fade_distance: float

var _layer_modified_decals: Dictionary[ScatterShotLayer, Dictionary] = {}
func _modified_decals_for_layer(layer: ScatterShotLayer) -> Dictionary[int, ModifiedDecal]:
	var untyped := _layer_modified_decals.get(layer)
	if not untyped:
		var d: Dictionary[int, ModifiedDecal] = {}
		untyped = d
		_layer_modified_decals[layer] = d
	return untyped

func _notification(what: Variant):
	if what == NOTIFICATION_PREDELETE:
		# can't call methods here; see https://github.com/godotengine/godot/issues/80834
		for layer: ScatterShotLayer in _layer_modified_decals:
			var decals: Dictionary[int, ModifiedDecal] = _layer_modified_decals[layer]
			for item_index: int in decals:
				var modified_decal: ModifiedDecal = decals[item_index]
				RenderingServer.free_rid(modified_decal.rid)
			decals.clear()
		_layer_modified_decals.clear()
