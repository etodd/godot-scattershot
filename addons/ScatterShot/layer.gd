@tool
class_name ScatterShotLayer
extends Resource

static var blue_noise: Image = preload("uid://dvwiogor3np1w")

## Collections of items to scatter.
@export var collections: Array[ScatterShotCollection]:
	set(value):
		for collection: ScatterShotCollection in collections:
			if collection:
				collection.changed.disconnect(self._on_collection_changed)
		for collection: ScatterShotCollection in value:
			if collection:
				collection.changed.connect(self._on_collection_changed)
		collections = value
		_on_collection_changed()

## Density of instances to spawn. At 1.0, every grid cell will have an instance.
## For performance, it's better to set a larger grid scale to achieve sparse
## instances than it is to set a low density. However, high density will make
## the grid pattern more apparent. Set this as high as you can get away with.
@export var density: float = 0.25:
	set(value):
		density = value
		emit_changed()

## Image to modulate instance density.
@export var density_map: Texture2D:
	set(value):
		if density_map:
			density_map.changed.disconnect(_density_map_changed)
		density_map = value
		if density_map:
			density_map.changed.connect(_density_map_changed)
		_density_map_changed()

## The physics layers to raycast against.
@export_flags_3d_physics var raycast_mask: int = 1:
	set(value):
		raycast_mask = value
		emit_changed()

func _reset_state() -> void:
	_density_map_changed()
	_on_collection_changed()

var _density_map_image: Image
func _density_map_changed() -> void:
	_density_map_image = density_map.get_image() if density_map else null
	emit_changed()

## Offset to use when sampling the density map.
@export var density_map_offset: Vector2i:
	set(value):
		density_map_offset = value
		emit_changed()

enum Variation {A, B, C, D}

## Which blue noise pattern variation to use.
@export var variation: Variation:
	set(value):
		variation = value
		emit_changed()

## Size of one grid cell in world units.
@export var grid_scale: float = 1.0:
	set(value):
		grid_scale = value
		emit_changed()

## Maximum view distance within which instances will be created.
@export var view_distance: float = 64.0:
	set(value):
		view_distance = value
		emit_changed()

## The distance at which instances start fading out.
@export var fade_distance: float = 60.0:
	set(value):
		fade_distance = value
		emit_changed()

## Size of one edge of a chunk, in grid cells. A larger chunk size means more
## instances will be created/removed at once in a single frame.
@export_range(4, 32) var chunk_size: int = 16: # size of one edge of a chunk, in pixels
	set(value):
		chunk_size = value
		emit_changed()

func _on_collection_changed() -> void:
	_proportion_sum = 0 # mark dirty
	emit_changed()

func sample(p: Vector2i) -> Color:
	var pixel: Color = blue_noise.get_pixel(posmod(p.x, blue_noise.get_width()), posmod(p.y, blue_noise.get_height()))
	match variation:
		Variation.A:
			return pixel
		Variation.B:
			return Color(pixel.g, pixel.b, pixel.a, pixel.r)
		Variation.C:
			return Color(pixel.b, pixel.a, pixel.r, pixel.g)
		Variation.D:
			return Color(pixel.a, pixel.r, pixel.g, pixel.b)
		_:
			return pixel

func density_at(p: Vector2i) -> float:
	if not _density_map_image:
		return density
	p += density_map_offset
	return density * _density_map_image.get_pixel(posmod(p.x, _density_map_image.get_width()), posmod(p.y, _density_map_image.get_height())).r

var _proportion_sum: int
func proportion_sum() -> int:
	if _proportion_sum == 0: # recalculate sum
		for collection: ScatterShotCollection in collections:
			if not collection:
				continue
			_proportion_sum += collection.proportion_sum()
	return _proportion_sum
