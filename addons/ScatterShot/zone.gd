@tool
class_name ScatterShotZone
extends ScatterShotShape

@export var pattern: ScatterShotPattern:
	set(value):
		if pattern:
			pattern.changed.disconnect(self._changed)
		if value:
			value.changed.connect(self._changed)
		pattern = value
		_changed()

## How far to raycast down to find surfaces for instance placement.
@export var depth: float = 50.0:
	set(value):
		depth = value
		_changed()

class ChunkJob:
	var zone: ScatterShotZone
	var chunk_origin: Vector2i
	var target_distance_squared: float
	var in_frustum: bool

static var _global_frame_index: int
static var _global_zones: Array[ScatterShotZone] = []

static func chunk_job_for_layer(jobs: Dictionary[ScatterShotLayer, ChunkJob], layer: ScatterShotLayer) -> ChunkJob:
	var untyped := jobs.get(layer)
	if untyped == null:
		var j: ChunkJob = ChunkJob.new()
		untyped = j
		jobs[layer] = j
	return untyped

func _enter_tree() -> void:
	_global_zones.push_back(self)
	if Engine.is_editor_hint():
		set_notify_transform(true)
	zone_moved()

func _exit_tree() -> void:
	_global_zones.erase(self)
	for layer: ScatterShotLayer in _layer_chunks.keys():
		clear(layer)

func _notification(what: Variant) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		zone_moved()
		_changed()

var _raycast: RayCast3D
var _layer_chunks: Dictionary[ScatterShotLayer, Dictionary] = {}
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _modulators: Dictionary[ScatterShotModulator, bool] = {}

func _ready() -> void:
	_raycast = RayCast3D.new()
	_raycast.hit_back_faces = false
	_raycast.enabled = false
	_raycast.visible = false
	_raycast.process_mode = Node.PROCESS_MODE_DISABLED
	_raycast.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_raycast.top_level = true
	add_child(_raycast, false, Node.INTERNAL_MODE_FRONT)


func _process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		return
	_global_update(EditorInterface.get_editor_viewport_3d().get_camera_3d(), Engine.get_process_frames())

func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var camera: Camera3D = get_viewport().get_camera_3d()
	if not camera:
		return
	_global_update(camera, Engine.get_physics_frames())

static func _global_update(camera: Camera3D, frame_index: int) -> void:
	if frame_index == _global_frame_index:
		# already updated this frame
		return
	_global_frame_index = frame_index
	
	var grow_jobs: Dictionary[ScatterShotLayer, ChunkJob] = {}
	var prune_jobs: Dictionary[ScatterShotLayer, ChunkJob] = {}
	
	var camera_pos: Vector3 = camera.global_position
	var camera_frustum: Array[Plane] = camera.get_frustum()
	for zone: ScatterShotZone in _global_zones:
		if not zone.pattern:
			continue
		for layer: ScatterShotLayer in zone.pattern.layers:
			zone.accumulate_jobs(layer, camera_pos, camera_frustum, grow_jobs, prune_jobs)
	
	for layer: ScatterShotLayer in prune_jobs:
		var prune_job: ChunkJob = prune_jobs[layer]
		if not prune_job.zone:
			continue
		var pruned_chunk: ScatterShotChunk = prune_job.zone.remove_chunk(layer, prune_job.chunk_origin)

		if not pruned_chunk:
			# already removed, maybe due to a change in pattern settings
			continue
			
		var grow_job: ChunkJob = grow_jobs.get(layer)
		if not grow_job or not grow_job.zone:
			# clear it
			pruned_chunk.items_begin()
			pruned_chunk.items_end()
			continue

		# repurpose existing chunk
		grow_job.zone.add_chunk(layer, pruned_chunk, grow_job.chunk_origin)
		grow_job.zone = null # mark job done
			

	for layer: ScatterShotLayer in grow_jobs:
		var grow_job: ChunkJob = grow_jobs[layer]
		if not grow_job.zone:
			continue

		var world3d: World3D = grow_job.zone.get_world_3d()
		var new_chunk: ScatterShotChunk = ScatterShotChunk.new(layer, world3d.scenario, world3d.space)
		grow_job.zone.add_chunk(layer, new_chunk, grow_job.chunk_origin)

func accumulate_jobs(layer: ScatterShotLayer, camera_pos: Vector3, camera_frustum: Array[Plane], grow_jobs: Dictionary[ScatterShotLayer, ChunkJob], prune_jobs: Dictionary[ScatterShotLayer, ChunkJob]) -> void:
	if not layer or layer.collections.size() == 0:
		return
	var chunk_size: float = layer.chunk_size * layer.grid_scale
	var inverse_global_basis: Basis = global_basis.inverse()
	var center3d: Vector3 = inverse_global_basis * global_position
	var center: Vector2 = Vector2(center3d.x, center3d.z)
	var chunk_rect: Rect2i
	match shape:
		Shape.RECT:
			chunk_rect.position = Vector2i(((center - rect_size * 0.5) / chunk_size).floor())
			chunk_rect.end = Vector2i(((center + rect_size * 0.5) / chunk_size).ceil())
		Shape.CIRCLE:
			chunk_rect.position = Vector2i(((center - Vector2(circle_radius, circle_radius)) / chunk_size).floor())
			chunk_rect.end = Vector2i(((center + Vector2(circle_radius, circle_radius)) / chunk_size).ceil())
	var target3d: Vector3 = inverse_global_basis * camera_pos
	if target3d.y < center3d.y - depth - layer.view_distance or target3d.y > center3d.y + layer.view_distance:
		clear(layer)
		return
	var target: Vector2 = Vector2(target3d.x, target3d.z)
	var view_distance: float = layer.view_distance + (chunk_size * 0.7071067812)
	var target_rect: Rect2i
	target_rect.position = Vector2i(((target - Vector2(view_distance, view_distance)) / chunk_size).floor())
	target_rect.end = Vector2i(((target + Vector2(view_distance, view_distance)) / chunk_size).ceil())
	chunk_rect = chunk_rect.intersection(target_rect)
	if not chunk_rect.has_area():
		clear(layer)
		return
	
	var prune_job: ChunkJob = chunk_job_for_layer(prune_jobs, layer)
	if not prune_job.zone:
		prune_job.target_distance_squared = (view_distance + layer.grid_scale * 2) * (view_distance + layer.grid_scale * 2)
	var chunks: Dictionary[Vector2i, ScatterShotChunk] = chunks_for_layer(layer)
	for chunk_origin: Vector2i in chunks:
		var chunk_pos_2d: Vector2 = (Vector2(chunk_origin) + Vector2(0.5 * layer.chunk_size, 0.5 * layer.chunk_size)) * layer.grid_scale
		var chunk_distance_squared: float = chunk_pos_2d.distance_squared_to(target)
		if chunk_distance_squared < prune_job.target_distance_squared:
			continue
		prune_job.zone = self
		prune_job.chunk_origin = chunk_origin
		prune_job.target_distance_squared = chunk_distance_squared
	
	var grow_job: ChunkJob = chunk_job_for_layer(grow_jobs, layer)
	if not grow_job.zone:
		grow_job.target_distance_squared = view_distance * view_distance
	var y: int = chunk_rect.position.y
	var chunk_radius: float = layer.chunk_size * layer.grid_scale * 0.8660254038
	while y < chunk_rect.end.y:
		var x: int = chunk_rect.position.x
		while x < chunk_rect.end.x:
			var chunk_origin: Vector2i = Vector2i(x, y) * layer.chunk_size
			if chunks.has(chunk_origin):
				x += 1
				continue
			var chunk_pos_2d: Vector2 = (Vector2(chunk_origin) + Vector2(0.5 * layer.chunk_size, 0.5 * layer.chunk_size)) * layer.grid_scale
			var chunk_pos_3d: Vector3 = global_basis * Vector3(chunk_pos_2d.x, target3d.y, chunk_pos_2d.y)
			var in_frustum: bool = _in_frustum(chunk_pos_3d, chunk_radius, camera_frustum)
			if not in_frustum and grow_job.in_frustum:
				x += 1
				continue
			var chunk_distance_squared: float = chunk_pos_2d.distance_squared_to(target)
			if chunk_distance_squared > grow_job.target_distance_squared:
				x += 1
				continue
			grow_job.zone = self
			grow_job.chunk_origin = chunk_origin
			grow_job.target_distance_squared = chunk_distance_squared
			grow_job.in_frustum = in_frustum
			x += 1
		y += 1

static func _in_frustum(point: Vector3, radius: float, frustum: Array[Plane]) -> bool:
	for plane: Plane in frustum:
		if plane.distance_to(point) < -radius:
			return false
	return true

func remove_chunk(layer: ScatterShotLayer, origin: Vector2i) -> ScatterShotChunk:
	var chunks := _layer_chunks.get(layer)
	if not chunks:
		return null
	var chunk: Variant = chunks.get(origin)
	if not chunk:
		return null
	chunks.erase(origin)
	return chunk
	
func add_chunk(layer: ScatterShotLayer, chunk: ScatterShotChunk, origin: Vector2i) -> void:
	_raycast.collision_mask = layer.raycast_mask

	var chunks: Dictionary[Vector2i, ScatterShotChunk] = chunks_for_layer(layer)
	chunks[origin] = chunk
	
	var inverse_global_basis: Basis = global_basis.inverse()
	var center3d: Vector3 = inverse_global_basis * global_position

	_rng.seed = hash(origin)
	var raycast_target_position_offset: Vector3 = global_basis * Vector3(0, -depth, 0)
	chunk.items_begin()
	var y: int = 0
	while y < layer.chunk_size:
		var x: int = 0
		while x < layer.chunk_size:
			var random_offset: Vector3 = Vector3(_rng.randf(), _rng.randf(), _rng.randf())
			var random_rotation: Vector3 = Vector3(_rng.randf(), _rng.randf(), _rng.randf())
			var random_scale: float = _rng.randf()
			var pixel: Vector2i = origin + Vector2i(x, y)
			var sample: Color = layer.sample(pixel)
			if sample.r == 0.0:
				x += 1
				continue
			var proportion: int = max(0, ceili(sample.g * float(layer.proportion_sum())) - 1)
			var proportion_sum: int = 0
			var collection: ScatterShotCollection
			for c: ScatterShotCollection in layer.collections:
				if not c:
					continue
				var new_sum: int = proportion_sum + c.proportion_sum()
				if proportion < new_sum:
					collection = c
					break
				proportion_sum = new_sum
			if not collection:
				x += 1
				continue
			var grid_space: Vector2 = Vector2(pixel.x + (random_offset.x - 0.5) * collection.random_offset_x, pixel.y + (random_offset.y - 0.5) * collection.random_offset_z) * layer.grid_scale
			var density: float = 0.0
			if (collection_mask & collection.modulator_mask) != 0:
				density += density_at(grid_space - Vector2(center3d.x, center3d.z))
			var global: Vector3 = global_basis * Vector3(grid_space.x, center3d.y, grid_space.y)
			for modulator: ScatterShotModulator in _modulators:
				if (modulator.collection_mask & collection.modulator_mask) == 0:
					continue
				# project pixel onto modulator
				var denom: float = global_basis.y.dot(modulator.global_basis.y)
				if is_zero_approx(denom):
					continue
				var t: float = (modulator.global_position - global).dot(modulator.global_basis.y) / denom;
				var modulator_local: Vector3 = modulator.to_local(global + global_basis.y * t)
				density += modulator.density_at(Vector2(modulator_local.x, modulator_local.z))
			if density * layer.density_at(pixel) < sample.r:
				x += 1
				continue
			_raycast.position = global
			_raycast.target_position = raycast_target_position_offset
			_raycast.force_raycast_update()
			if not _raycast.is_colliding():
				x += 1
				continue
			if _raycast.get_collision_normal().dot(global_basis.y) < cos(collection.max_angle):
				x += 1
				continue
			var transform: Transform3D
			transform.origin = _raycast.get_collision_point()
			match collection.align:
				ScatterShotCollection.Align.ZONE:
					transform.basis = global_basis
				ScatterShotCollection.Align.SURFACE:
					transform.basis = Basis.looking_at(_raycast.get_collision_normal(), global_basis.x)
					transform.basis = Basis(transform.basis.x, -transform.basis.z, transform.basis.y)
			transform.origin += transform.basis.y * lerpf(collection.min_offset_y, collection.max_offset_y, random_offset.y)
			transform.basis = transform.basis * Basis.from_euler(Vector3(
				lerpf(collection.min_pitch, collection.max_pitch, random_rotation.x),
				lerpf(collection.min_yaw, collection.max_yaw, random_rotation.y),
				lerpf(collection.min_roll, collection.max_roll, random_rotation.y)
			))
			transform.basis *= lerpf(collection.min_scale, collection.max_scale, random_scale)
			chunk.items_add(collection, collection.item_index(proportion - proportion_sum), transform)
			x += 1
		y += 1
	chunk.items_end()
	_raycast.position = Vector3.ZERO
	_raycast.target_position = Vector3.ZERO

func clear(layer: ScatterShotLayer) -> void:
	var chunks := _layer_chunks.get(layer)
	if not chunks:
		return
	for chunk_origin: Vector2i in chunks:
		var chunk: ScatterShotChunk = chunks[chunk_origin]
		chunk.items_begin()
		chunk.items_end()
	chunks.clear()
	_layer_chunks.erase(layer)

func _changed() -> void:
	for layer: ScatterShotLayer in _layer_chunks.keys():
		clear(layer)
	if Engine.is_editor_hint():
		update_gizmos()

func chunks_for_layer(layer: ScatterShotLayer) -> Dictionary[Vector2i, ScatterShotChunk]:
	var untyped := _layer_chunks.get(layer)
	if untyped == null:
		var d: Dictionary[Vector2i, ScatterShotChunk] = {}
		untyped = d
		_layer_chunks[layer] = d
	return untyped

static func modulator_moved(modulator: ScatterShotModulator) -> void:
	for zone: ScatterShotZone in _global_zones:
		var overlap: bool = zone.overlaps(modulator)
		if zone._modulators.has(modulator):
			if not overlap:
				zone._modulators.erase(modulator)
			zone._changed()
		else:
			if overlap:
				zone._modulators[modulator] = true
				zone._changed()

static func modulator_changed(modulator: ScatterShotModulator) -> void:
	for zone: ScatterShotZone in _global_zones:
		if not zone._modulators.has(modulator):
			continue
		zone._changed()

func zone_moved() -> void:
	for modulator: ScatterShotModulator in _modulators.keys():
		if ScatterShotModulator._global_modulators.has(modulator) and overlaps(modulator):
			continue
		_modulators.erase(modulator)
		_changed()
	for modulator: ScatterShotModulator in ScatterShotModulator._global_modulators:
		if _modulators.has(modulator):
			continue
		if not overlaps(modulator):
			continue
		_modulators[modulator] = true
		_changed()

func overlaps(modulator: ScatterShotModulator) -> bool:
	if not ScatterShotModulator._global_modulators.has(modulator):
		return false
	# extremely simple conservative check; if the shapes are anywhere close, they overlap
	var modulator_radius: float
	match modulator.shape:
		Shape.RECT:
			modulator_radius = maxf(modulator.rect_size.x, modulator.rect_size.y) / 2.0
		Shape.CIRCLE:
			modulator_radius = modulator.circle_radius
	var local: Vector3 = to_local(modulator.global_position)
	if local.y < -depth - modulator_radius:
		return false
	if local.y > modulator_radius:
		return false
	var local2d: Vector2 = Vector2(local.x, local.z)
	match shape:
		Shape.RECT:
			var half_size: Vector2 = Vector2(modulator_radius, modulator_radius)
			if not Rect2(rect_size * -0.5, rect_size).intersects(Rect2(local2d - half_size, half_size * 2.0)):
				return false
		Shape.CIRCLE:
			if local2d.length() > modulator_radius + circle_radius:
				return false
	return true
