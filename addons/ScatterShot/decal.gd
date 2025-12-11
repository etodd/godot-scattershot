@tool
class_name ScatterShotDecal
extends Resource

## Texture2D with the base Color of the Decal. Either this or the
## texture_emission must be set for the Decal to be visible. Use the alpha
## channel like a mask to smoothly blend the edges of the decal with the
## underlying object.
@export var texture_albedo: Texture2D:
	set(value):
		if texture_albedo:
			texture_albedo.changed.disconnect(emit_changed)
		texture_albedo = value
		if texture_albedo:
			texture_albedo.changed.connect(emit_changed)
		emit_changed()

## Texture2D with the emission Color of the Decal. Either this or the
## texture_albedo must be set for the Decal to be visible. Use the alpha channel
## like a mask to smoothly blend the edges of the decal with the underlying
## object.
@export var texture_emission: Texture2D:
	set(value):
		if texture_emission:
			texture_emission.changed.disconnect(emit_changed)
		texture_emission = value
		if texture_emission:
			texture_emission.changed.connect(emit_changed)
		emit_changed()

## Texture2D with the per-pixel normal map for the decal. Use this to add extra
## detail to decals.
@export var texture_normal: Texture2D:
	set(value):
		if texture_normal:
			texture_normal.changed.disconnect(emit_changed)
		texture_normal = value
		if texture_normal:
			texture_normal.changed.connect(emit_changed)
		emit_changed()

## Texture2D storing ambient occlusion, roughness, and metallic for the decal.
## Use this to add extra detail to decals.
@export var texture_orm: Texture2D:
	set(value):
		if texture_orm:
			texture_orm.changed.disconnect(emit_changed)
		texture_orm = value
		if texture_orm:
			texture_orm.changed.connect(emit_changed)
		emit_changed()

## Proportion of frequency with which this decal will spawn, relative to other
## decals.
@export var proportion: int = 10:
	set(value):
		proportion = value
		emit_changed()
