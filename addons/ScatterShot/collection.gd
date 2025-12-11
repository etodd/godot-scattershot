@tool
@abstract
class_name ScatterShotCollection
extends Resource

## Rendering layers to apply to instances in this collection.
@export_flags_3d_render var visibility_layers: int = 1:
	set(value):
		visibility_layers = value
		_changed()

enum Align { ZONE, SURFACE, WORLD }

## How to align instances in this collection.
##
## ZONE: Align to the ScatterShotZone's up direction.
## SURFACE: Align to the surface normal at the instance position.
## WORLD: Align to the world's up direction.
@export var align: Align:
	set(value):
		align = value
		_changed()

@export_range(0, 90, 1, "radians_as_degrees") var max_angle: float = PI * 0.25:
	set(value):
		max_angle = value
		_changed()
		
## Maximum random X axis offset to apply to instance positions (relative to
## grid cell).
@export_range(0.0, 1.0) var random_offset_x: float = 0.5:
	set(value):
		random_offset_x = value
		_changed()

## Maximum random Z axis offset to apply to instance positions (relative to
## grid cell).
@export_range(0.0, 1.0) var random_offset_z: float = 0.5:
	set(value):
		random_offset_z = value
		_changed()

## Maximum random yaw rotation to apply to instances (relative to their alignment).
@export_range(0, 360, 1, "radians_as_degrees") var random_yaw: float = PI * 2.0:
	set(value):
		random_yaw = value
		_changed()

## Maximum random pitch rotation to apply to instances (relative to their alignment).
@export_range(0, 360, 1, "radians_as_degrees") var random_pitch: float:
	set(value):
		random_pitch = value
		_changed()

## Maximum random roll rotation to apply to instances (relative to their alignment).
@export_range(0, 360, 1, "radians_as_degrees") var random_roll: float:
	set(value):
		random_roll = value
		_changed()

## Maximum random scale increase to apply to instances.
@export_range(0.0, 10.0, 0.001, "or_greater") var random_scale: float:
	set(value):
		random_scale = value
		_changed()

## A bitmask determining which modulators affect instances in this collection.
@export_flags("1", "2", "3", "4", "5", "6", "7", "8") var modulator_mask: int = 1:
	set(value):
		modulator_mask = value
		_changed()

func _changed() -> void:
	emit_changed()

func proportion_sum() -> int:
	push_error("proportion_sum not overridden")
	return -1

func item_index(proportion: int) -> int:
	push_error("item_index not overridden")
	return -1
