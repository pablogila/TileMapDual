class_name Display
extends Node2D
##[br] A Node designed to hold and manage up to 2 DisplayLayer children.
##[br] See [DisplayLayer] for details.

## Emitted when the tiles in the map have been edited.
signal world_tiles_changed(changed: Array)

## Every meaningfully different TileSet.tile_shape * TileSet.tile_offset_axis combination.
enum GridShape {
	SQUARE,
	ISO,
	HALF_OFF_HORI,
	HALF_OFF_VERT,
	HEX_HORI,
	HEX_VERT,
}

##[br] How to deal with every available GridShape.
##[br] See [DisplayLayer] for more information about these fields.
const GRIDS: Dictionary[GridShape, Array] = {
	GridShape.SQUARE: [
		{
			# []
			'offset': Vector2(-0.5, -0.5),
		},
	],
	GridShape.ISO: [
		{
			# <>
			'offset': Vector2(0, -0.5),
		},
	],
	GridShape.HALF_OFF_HORI: [
		{
			# v
			'offset': Vector2(0.0, -0.5),
		},
		{
			# ^
			'offset': Vector2(-0.5, -0.5),
		},
	],
	GridShape.HALF_OFF_VERT: [
		{
			# >
			'offset': Vector2(-0.5, 0.0),
		},
		{
			# <
			'offset': Vector2(-0.5, -0.5),
		},
	],
	GridShape.HEX_HORI: [
		{
			# v
			'offset': Vector2(0.0, -3.0 / 8.0),
		},
		{
			# ^
			'offset': Vector2(-0.5, -3.0 / 8.0),
		},
	],
	GridShape.HEX_VERT: [
		{
			# >
			'offset': Vector2(-3.0 / 8.0, 0.0),
		},
		{
			# <
			'offset': Vector2(-3.0 / 8.0, -0.5),
		},
	],
}

## The parent TileMapDual to base the terrains off of.
@export var world: TileMapDual

## See [TerrainDual]
var terrain: TerrainDual
## The TileCache computed from the last time update() was called.
var cached_cells := TileCache.new()
## See [TileSetWatcher]
var _tileset_watcher: TileSetWatcher


# TODO: phase out GridShape and simply transpose everything when the offset axis is vertical
##[br] Returns what kind of grid a TileSet is.
##[br] Will default to SQUARE if Godot decides to add a new TileShape.
static func tileset_gridshape(tile_set: TileSet) -> GridShape:
	var hori: bool = tile_set.tile_offset_axis == TileSet.TILE_OFFSET_AXIS_HORIZONTAL
	match tile_set.tile_shape:
		TileSet.TileShape.TILE_SHAPE_SQUARE:
			return GridShape.SQUARE
		TileSet.TileShape.TILE_SHAPE_ISOMETRIC:
			return GridShape.ISO
		TileSet.TileShape.TILE_SHAPE_HALF_OFFSET_SQUARE:
			return GridShape.HALF_OFF_HORI if hori else GridShape.HALF_OFF_VERT
		TileSet.TileShape.TILE_SHAPE_HEXAGON:
			return GridShape.HEX_HORI if hori else GridShape.HEX_VERT
		_:
			return GridShape.SQUARE


## Creates a new Display that updates when the TileSet updates.
func _init(world: TileMapDual, tileset_watcher: TileSetWatcher) -> void:
	#print('initializing Display...')
	self.world = world
	_tileset_watcher = tileset_watcher
	terrain = TerrainDual.new(tileset_watcher)
	terrain.changed.connect(_terrain_changed, 1)
	world_tiles_changed.connect(_world_tiles_changed, 1)
	# let parent materal through to the displaylayers
	use_parent_material = true
	# Enable Y sorting
	y_sort_enabled = true


## Updates the display based on the cells changed in the world TileMapDual.
func update(updated: Array) -> void:
	if _tileset_watcher.tile_set == null:
		return
	_update_properties()
	if not updated.is_empty():
		cached_cells.update(world, updated)
		world_tiles_changed.emit(updated)


## Activates when the TerrainDual changes.
func _terrain_changed() -> void:
	cached_cells.update(world)
	_delete_layers()
	if _tileset_watcher.tile_set != null:
		_create_layers()


func _world_tiles_changed(changed: Array) -> void:
	#print('SIGNAL EMITTED: world_tiles_changed(%s)' % {'changed': changed})
	for child in get_children(true):
		child.update_tiles(cached_cells, changed)


## Initializes and configures new DisplayLayers according to the grid shape.
func _create_layers() -> void:
	#print('GRID SHAPE: %s' % _tileset_watcher.grid_shape)
	var grid: Array = GRIDS[_tileset_watcher.grid_shape]
	for i: int in grid.size():
		var layer_config: Dictionary = grid[i]
		#print('layer_config: %s' % layer_config)
		var layer := DisplayLayer.new(world, _tileset_watcher, layer_config, terrain.layers[i])
		add_child(layer)
		layer.update_tiles_all(cached_cells)


## Deletes all of the DisplayLayers.
func _delete_layers() -> void:
	for child in get_children(true):
		child.queue_free()


## Activates when the properties of the parent TileMapDual have been edited.
func _update_properties() -> void:
	for child in get_children(true):
		child.update_properties(world)
