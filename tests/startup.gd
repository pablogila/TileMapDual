extends Node2D
## Regression scene for initial world updates that happen before _ready().

const TILE_SETS: Array[TileSet] = [
	preload("res://assets/tileset/square.tres"),
	preload("res://assets/tileset/iso.tres"),
]

var _failures: int = 0


func _ready() -> void:
	for tile_set: TileSet in TILE_SETS:
		var packed := _pack_world(tile_set)
		for preinitialize: bool in [false, true]:
			for repetition: int in 3:
				await _test_startup(packed, preinitialize, repetition)
	print("TileMapDual startup tests: %d failures" % _failures)
	get_tree().quit(1 if _failures else 0)


func _pack_world(tile_set: TileSet) -> PackedScene:
	var world := TileMapDual.new()
	world.tile_set = tile_set
	world.godot_4_3_compatibility = false
	var source_id := tile_set.get_source_id(0)
	var atlas := tile_set.get_source(source_id) as TileSetAtlasSource
	for index: int in atlas.get_tiles_count():
		var coords := atlas.get_tile_id(index)
		if atlas.get_tile_data(coords, 0).terrain != 1:
			continue
		for y: int in range(-3, 4):
			for x: int in range(-3, 4):
				world.set_cell(Vector2i(x, y), source_id, coords)
		break
	var packed := PackedScene.new()
	_check(packed.pack(world) == OK, "Could not pack the test world")
	world.free()
	return packed


func _test_startup(packed: PackedScene, preinitialize: bool, repetition: int) -> void:
	var world := packed.instantiate() as TileMapDual
	var label := "shape=%d preinitialize=%s repetition=%d" % [
		world.tile_set.tile_shape, preinitialize, repetition,
	]
	if preinitialize:
		# Consume the initial dirty cells before TileMapDual creates its Display.
		world.update_internals()
	add_child(world)
	await _settle()
	var display := world.get_child(0) as Display
	_check(world.get_used_cells().size() == 49, label + ": world cells changed")
	_check(display.cached_cells.cells.size() == 49, label + ": initial cells missing from cache")
	_check(_display_cells(display) > 0, label + ": generated display is empty")
	var original_display_cells := _display_cells(display)

	var added := Vector2i(10, 10)
	world.draw_cell(added, 1)
	await _settle()
	_check(display.cached_cells.get_terrain_at(added) == 1, label + ": draw did not update cache")
	_check(_display_cells(display) > original_display_cells, label + ": draw did not update display")
	world.draw_cell(added, -1)
	await _settle()
	_check(display.cached_cells.get_terrain_at(added) == -1, label + ": erase did not update cache")
	_check(_display_cells(display) == original_display_cells, label + ": erase did not restore display")
	print("Checked ", label, " world=", world.get_used_cells().size(), " display=", _display_cells(display))
	world.queue_free()
	await _settle()


func _settle() -> void:
	for frame: int in 4:
		await get_tree().process_frame


func _display_cells(display: Display) -> int:
	var count: int = 0
	for layer: Node in display.get_children():
		if layer is TileMapLayer:
			count += layer.get_used_cells().size()
	return count


func _check(condition: bool, message: String) -> void:
	# assert() is omitted from release exports, so use explicit failures.
	if not condition:
		_failures += 1
		push_error(message)
