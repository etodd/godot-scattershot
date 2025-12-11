@tool
class_name ScatterShotModulator
extends ScatterShotShape

static var _global_modulators: Dictionary[ScatterShotModulator, bool] = {}

func _enter_tree() -> void:
	_global_modulators[self] = true
	if Engine.is_editor_hint():
		set_notify_transform(true)
	ScatterShotZone.modulator_moved(self)

func _notification(what: Variant) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		ScatterShotZone.modulator_moved(self)

func _exit_tree() -> void:
	_global_modulators.erase(self)
	ScatterShotZone.modulator_moved(self)

func _changed() -> void:
	ScatterShotZone.modulator_changed(self)
	if Engine.is_editor_hint():
		update_gizmos()
