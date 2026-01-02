@tool
@abstract
class_name ScatterShotShape extends Node3D

## Density of instances to spawn within this shape.
@export_range(-1.0, 1.0, 0.01) var density: float = 1.0:
	set(value):
		density = value
		_changed()

## Image to modulate instance density.
@export var density_map: Texture2D:
	set(value):
		if density_map:
			density_map.changed.disconnect(_density_map_changed)
		density_map = value
		if density_map:
			density_map.changed.connect(_density_map_changed)
		_density_map_changed()

var _density_map_image: Image
func _density_map_changed() -> void:
	_density_map_image = density_map.get_image() if density_map else null
	_changed()
		
## Hardness of the shape's edges. At full hardness, the density is 1.0 within
## the shape and 0.0 outside it. At zero hardness, the density fades smoothly
## from 1.0 at the center of the shape to 0.0 at the edges.
@export_range(0.0, 1.0, 0.01) var hardness: float = 0.5:
	set(value):
		hardness = value
		_changed()

enum Shape { RECT, CIRCLE }

@export var shape: Shape:
	set(value):
		shape = value
		notify_property_list_changed()
		_changed()
		
@export var rect_size: Vector2 = Vector2(50.0, 50.0):
	set(value):
		rect_size = value
		_changed()
		
@export var circle_radius: float = 50.0:
	set(value):
		circle_radius = value
		_changed()

## A bitmask determining which collections this shape affects.
@export_flags("1", "2", "3", "4", "5", "6", "7", "8") var collection_mask: int = -1:
	set(value):
		collection_mask = value
		_changed()

func _changed() -> void:
	pass

func _validate_property(property: Dictionary) -> void:
	if (property.name == "rect_size" and shape == Shape.RECT) \
		or (property.name == "circle_radius" and shape == Shape.CIRCLE):
		property.usage = PROPERTY_USAGE_DEFAULT
	elif (property.name == "rect_size" and shape != Shape.RECT) \
		or (property.name == "circle_radius" and shape != Shape.CIRCLE):
		property.usage = PROPERTY_USAGE_NO_EDITOR

func density_at(local_pos: Vector2) -> float:
	match shape:
		Shape.RECT:
			var p: Vector2 = (local_pos - (rect_size * -0.5)) / rect_size
			if p.x < 0.0 or p.y < 0.0 or p.x > 1.0 or p.y > 1.0:
				return 0.0
			var d: float = density
			if _density_map_image:
				d *= _density_map_image.get_pixel(p.x * _density_map_image.get_width(), p.y * _density_map_image.get_height()).r
			if hardness == 1.0:
				return d
			var soft_range: float = min(rect_size.x, rect_size.y) * 0.5 * (1.0 - hardness)
			var inner_rect: Rect2 = Rect2(rect_size * -0.5, rect_size).grow(-soft_range)
			var inner_pos: Vector2 = local_pos.clamp(inner_rect.position, inner_rect.end)
			return lerpf(d, 0.0, clampf((local_pos - inner_pos).length() / soft_range, 0.0, 1.0))
		Shape.CIRCLE:
			var distance: float = local_pos.length()
			if distance > circle_radius:
				return 0.0
			var d: float = density
			if _density_map_image:
				var p: Vector2 = (local_pos + Vector2(circle_radius, circle_radius)) / (circle_radius * 2.0)
				d *= _density_map_image.get_pixel(p.x * _density_map_image.get_width(), p.y * _density_map_image.get_height()).r
			if hardness == 1.0:
				return d
			var inner_radius: float = circle_radius * hardness
			return lerpf(d, 0.0, clampf((distance - inner_radius) / (circle_radius - inner_radius), 0.0, 1.0))
		_:
			return 0.0
