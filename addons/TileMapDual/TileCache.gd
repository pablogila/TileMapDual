## Caches the sprite location and terrains of each tile in the TileMapDual world grid.
class_name TileCache
extends Resource


##[br] Maps a cell coordinate to the stored tile data.
##[codeblock]
##  Dictionary{
##    key: Vector2i = # The coordinates of this tile in the world grid.
##    value: Dictionary{
##      'sid': int = # The Source ID of this tile.
##      'tile': Vector2i = # The coordinates of this tile in its Atlas.
##      'terrain': int = # The terrain assigned to this tile.
##    } = # The data stored at this tile.
##  }
##[/codeblock]
var cells := {}
func _init() -> void:
	pass

##[br] Updates specific cells of the TileCache based on the current layer data at those points.
##[br] Makes corrections in case the user accidentally places invalid tiles.
func update(world: TileMapLayer, edited: Array = cells.keys()) -> void:
	var tile_set := world.tile_set
	if tile_set == null:
		push_error('Attempted to update TileCache while tile set was null')
		return
	for cell in edited:
		# Invalid cells will be treated as empty and ignored
		var sid := world.get_cell_source_id(cell)
		if sid == -1:
			cells.erase(cell)
			continue
		if not tile_set.has_source(sid):
			continue
		var src = tile_set.get_source(sid)
		var tile := world.get_cell_atlas_coords(cell)
		if not src.has_tile(tile):
			continue
		var data := world.get_cell_tile_data(cell)
		if data == null:
			continue
		# Accidental cells should be reset to their previous value
		# They will be treated as unchanged
		if data.terrain == -1 or data.terrain_set != 0:
			if cell not in cells:
				world.erase_cell(cell)
				continue
			var cached: Dictionary = cells[cell]
			sid = cached.sid
			tile = cached.tile
			world.set_cell(cell, cached.sid, cached.tile)
		cells[cell] = {'sid': sid, 'tile': tile, 'terrain': data.terrain}


##[br] Returns the terrain value of the tile at the given cell coordinates.
##[br] Empty cells have a terrain of -1.
func get_terrain_at(cell: Vector2i) -> int:
	if cell not in cells:
		return -1
	return cells[cell].terrain
