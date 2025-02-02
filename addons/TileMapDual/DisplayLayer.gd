## A single TileMapLayer whose purpose is to display tiles to maintain the Dual Grid illusion.
## Its contents are automatically computed and updated based on:
## - the contents of the parent TileMapDual
## - the rules set in its assigned TerrainLayer
class_name DisplayLayer
extends TileMapLayer


## How much to offset this DisplayLayer relative to the main TileMapDual grid.
## This is independent of tile size.
var offset: Vector2

## See TileSetWatcher.gd
var _tileset_watcher: TileSetWatcher

## See TerrainDual.gd
var _terrain: TerrainLayer

func _init(
	world: TileMapDual,
	tileset_watcher: TileSetWatcher,
	fields: Dictionary,
	layer: TerrainLayer
) -> void:
	# TODO: clone all properties of world: TileMapDual
	# possibly serialize the parent and use a for loop?
	#print('initializing Layer...')
	offset = fields.offset
	_tileset_watcher = tileset_watcher
	_terrain = layer
	tile_set = tileset_watcher.tile_set
	tileset_watcher.tileset_resized.connect(reposition, 1)
	reposition()


## Adjusts the position of this DisplayLayer based on the tile set's tile_size
func reposition() -> void:
	position = offset * Vector2(_tileset_watcher.tile_size)


## Updates all display tiles to reflect the current changes.
func update_tiles_all(cache: TileCache) -> void:
	update_tiles(cache, cache.cells.keys())


## Update all display tiles affected by the world cells
func update_tiles(cache: TileCache, updated_world_cells: Array) -> void:
	#push_warning('updating tiles')
	var already_updated := Set.new()
	for path: Array in _terrain.display_to_world_neighborhood:
		path = path.map(Util.reverse_neighbor)
		for world_cell: Vector2i in updated_world_cells:
			var display_cell := follow_path(world_cell, path)
			if already_updated.insert(display_cell):
				update_tile(cache, display_cell)


## Updates a specific world cell.
func update_tile(cache: TileCache, cell: Vector2i) -> void:
	var get_cell_at_path := func(path): return cache.get_terrain_at(follow_path(cell, path))
	var terrain_neighbors := _terrain.display_to_world_neighborhood.map(get_cell_at_path)
	var mapping: Dictionary = _terrain.apply_rule(terrain_neighbors)
	var sid: int = mapping.sid
	var tile: Vector2i = mapping.tile
	set_cell(cell, sid, tile)


## Finds the neighbor of a given cell by following a path of CellNeighbors
func follow_path(cell: Vector2i, path: Array) -> Vector2i:
	for neighbor: TileSet.CellNeighbor in path:
		cell = get_neighbor_cell(cell, neighbor)
	return cell
