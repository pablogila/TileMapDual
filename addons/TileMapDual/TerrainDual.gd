## Reads a TileSet and dictates which tiles in the display map
## match up with its neighbors in the world map
class_name TerrainDual
extends Resource


# Functions are ordered top to bottom in the transformation pipeline

## Maps a TileSet to a Neighborhood.
static func tileset_neighborhood(tile_set: TileSet) -> Neighborhood:
	return GRID_NEIGHBORHOODS[Display.tileset_gridshape(tile_set)]


## Maps a GridShape to a Neighborhood.
const GRID_NEIGHBORHOODS = {
	Display.GridShape.SQUARE: Neighborhood.SQUARE,
	Display.GridShape.ISO: Neighborhood.ISOMETRIC,
	Display.GridShape.HALF_OFF_HORI: Neighborhood.TRIANGLE_HORIZONTAL,
	Display.GridShape.HALF_OFF_VERT: Neighborhood.TRIANGLE_VERTICAL,
	Display.GridShape.HEX_HORI: Neighborhood.TRIANGLE_HORIZONTAL,
	Display.GridShape.HEX_VERT: Neighborhood.TRIANGLE_VERTICAL,
}


## A specific neighborhood that the Display tiles will look at.
enum Neighborhood {
	SQUARE,
	ISOMETRIC,
	TRIANGLE_HORIZONTAL,
	TRIANGLE_VERTICAL,
}


## Maps a Neighborhood to a set of atlas terrain neighbors.
const NEIGHBORHOOD_LAYERS := {
	Neighborhood.SQUARE: [
		{ # []
			'terrain_neighborhood': [
				TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER,
				TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER,
				TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER,
				TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER,
			],
			'display_to_world_neighborhood': [
				[TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER],
				[TileSet.CELL_NEIGHBOR_TOP_SIDE],
				[TileSet.CELL_NEIGHBOR_LEFT_SIDE],
				[],
			],
		},
	],
	Neighborhood.ISOMETRIC: [
		{ # <>
			'terrain_neighborhood': [
				TileSet.CELL_NEIGHBOR_TOP_CORNER,
				TileSet.CELL_NEIGHBOR_RIGHT_CORNER,
				TileSet.CELL_NEIGHBOR_LEFT_CORNER,
				TileSet.CELL_NEIGHBOR_BOTTOM_CORNER,
			],
			'display_to_world_neighborhood': [
				[TileSet.CELL_NEIGHBOR_TOP_CORNER],
				[TileSet.CELL_NEIGHBOR_TOP_RIGHT_SIDE],
				[TileSet.CELL_NEIGHBOR_TOP_LEFT_SIDE],
				[],
			],
		},
	],
	Neighborhood.TRIANGLE_HORIZONTAL: [
		{ # v
			'terrain_neighborhood': [
				TileSet.CELL_NEIGHBOR_BOTTOM_CORNER,
				TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER,
				TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER,
			],
			'display_to_world_neighborhood': [
				[],
				[TileSet.CELL_NEIGHBOR_TOP_LEFT_SIDE],
				[TileSet.CELL_NEIGHBOR_TOP_RIGHT_SIDE],
			],
		},
		{ # ^
			'terrain_neighborhood': [
				TileSet.CELL_NEIGHBOR_TOP_CORNER,
				TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER,
				TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER,
			],
			'display_to_world_neighborhood': [
				[TileSet.CELL_NEIGHBOR_TOP_LEFT_SIDE],
				[TileSet.CELL_NEIGHBOR_LEFT_SIDE],
				[],
			],
		},
	],
	# TODO: this is just TRIANGLE_HORIZONTAL but transposed. this can be refactored.
	Neighborhood.TRIANGLE_VERTICAL: [
		{ # >
			'terrain_neighborhood': [
				TileSet.CELL_NEIGHBOR_RIGHT_CORNER,
				TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER,
				TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER,
			],
			'display_to_world_neighborhood': [
				[],
				[TileSet.CELL_NEIGHBOR_TOP_LEFT_SIDE],
				[TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_SIDE],
			],
		},
		{ # <
			'terrain_neighborhood': [
				TileSet.CELL_NEIGHBOR_LEFT_CORNER,
				TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER,
				TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER,
			],
			'display_to_world_neighborhood': [
				[TileSet.CELL_NEIGHBOR_TOP_LEFT_SIDE],
				[TileSet.CELL_NEIGHBOR_TOP_SIDE],
				[],
			],
		},
	],
}


## The Neighborhood type of this TerrainDual.
var neighborhood: Neighborhood

## Maps a terrain type to its sprite as registered in the TerrainDual.
var terrains: Dictionary

## The TerrainLayers for this TerrainDual.
var layers: Array
var _tileset_watcher: TileSetWatcher
func _init(tileset_watcher: TileSetWatcher) -> void:
	_tileset_watcher = tileset_watcher
	_tileset_watcher.terrains_changed.connect(_changed, 1)
	_changed()


## Emitted when any of the terrains change.
## NOTE: Prefer connecting to TerrainDual.changed instead of TileSetWatcher.terrains_changed.
func _changed() -> void:
	#print('SIGNAL EMITTED: changed(%s)' % {})
	read_tileset(_tileset_watcher.tile_set)
	emit_changed()


## Create rules for every atlas in a TileSet.
func read_tileset(tile_set: TileSet) -> void:
	terrains = {}
	layers = []
	neighborhood = Neighborhood.SQUARE # default
	if tile_set == null:
		return
	neighborhood = tileset_neighborhood(tile_set)
	layers = NEIGHBORHOOD_LAYERS[neighborhood].map(TerrainLayer.new)
	for i in tile_set.get_source_count():
		var sid := tile_set.get_source_id(i)
		var src := tile_set.get_source(sid)
		if src is not TileSetAtlasSource:
			continue
		read_atlas(src, sid)


## Create rules for every tile in an atlas.
func read_atlas(atlas: TileSetAtlasSource, sid: int) -> void:
	var size = atlas.get_atlas_grid_size()
	for y in size.y:
		for x in size.x:
			var tile := Vector2i(x, y)
			# Take only existing tiles
			if not atlas.has_tile(tile):
				continue
			read_tile(atlas, sid, tile)


## Add a new rule for a specific tile in an atlas.
func read_tile(atlas: TileSetAtlasSource, sid: int, tile: Vector2i) -> void:
	var data := atlas.get_tile_data(tile, 0)
	var mapping := {'sid': sid, 'tile': tile}
	var terrain_set := data.terrain_set
	if terrain_set != 0:
		push_warning(
			"The tile at %s has a terrain set of %d. Only terrain set 0 is supported." % [mapping, terrain_set]
		)
		return
	var terrain := data.terrain
	if terrain != -1:
		if terrain in terrains:
			var prev_mapping = terrains[terrain]
			push_warning(
				"2 different tiles in this TileSet have the same Terrain type:\n" +
				"1st: %s\n" % [prev_mapping] +
				"2nd: %s" % [mapping]
			)
		terrains[terrain] = mapping
	var filters = NEIGHBORHOOD_LAYERS[neighborhood]
	for i in layers.size():
		var layer: TerrainLayer = layers[i]
		layer._register_tile(data, mapping)
