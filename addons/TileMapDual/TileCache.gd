## Caches the sprite location and terrains of each tile in the TileMapDual world grid.
class_name TileCache
extends Resource


## Maps a cell coordinate to the stored tile data
##
## Dictionary{
##   key: Vector2i = The coordinates of this tile in the world grid.
##   value: Dictionary{
##     'sid': int = The Source ID of this tile.
##     'tile': Vector2i = The coordinates of this tile in its Atlas.
##     'terrain': int = The terrain assigned to this tile.
##   } = The data stored at this tile.
## }
var cells := {}
func _init() -> void:
	pass


## Computes a new TileCache based on the current layer data.
## Needs the old TileCache in case corrections need to made due to accidents.
func compute(tile_set: TileSet, layer: TileMapLayer, cache: TileCache) -> void:
	if tile_set == null:
		push_error('Attempted to construct TileCache while tile set was null')
		return
	for cell in layer.get_used_cells():
		# Invalid cells will be treated as empty and ignored
		var sid := layer.get_cell_source_id(cell)
		if not tile_set.has_source(sid):
			continue
		var src = tile_set.get_source(sid)
		var tile := layer.get_cell_atlas_coords(cell)
		if not src.has_tile(tile):
			continue
		var data := layer.get_cell_tile_data(cell)
		if data == null:
			continue
		# Accidental cells should be reset to their previous value
		# They will be treated as unchanged
		if data.terrain == -1 or data.terrain_set != 0:
			if cell not in cache.cells:
				layer.erase_cell(cell)
				continue
			var cached: Dictionary = cache.cells[cell]
			sid = cached.sid
			tile = cached.tile
			layer.set_cell(cell, cached.sid, cached.tile)
		cells[cell] = {'sid': sid, 'tile': tile, 'terrain': data.terrain}


## Returns the symmetric difference (xor) of two tile caches.
func xor(other: TileCache) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for key in cells:
		if key not in other.cells or cells[key].terrain != other.cells[key].terrain:
			out.push_back(key)
	for key in other.cells:
		if key not in cells:
			out.push_back(key)
	return out


## Returns the terrain value of the tile at the given cell coordinates.
## Empty cells have a terrain of -1.
func get_terrain_at(cell: Vector2i) -> int:
	if cell not in cells:
		return -1
	return cells[cell].terrain
