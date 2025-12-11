@tool
class_name ScatterShotPattern
extends Resource

## A pattern can contain multiple layers of items that do not affect each other.
## The system will create/remove one chunk of instances per layer per physics
## frame. To force instances to be created faster, increase the chunk size.
@export var layers: Array[ScatterShotLayer]:
	set(value):
		for layer: ScatterShotLayer in layers:
			if layer:
				layer.changed.disconnect(emit_changed)
		layers = value
		for layer: ScatterShotLayer in value:
			if layer:
				layer.changed.connect(emit_changed)
		emit_changed()
