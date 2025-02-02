## A set of _rules usable by a single DisplayLayer.
class_name TerrainLayer
extends Resource


## A list of which CellNeighbors to care about during terrain checking.
var terrain_neighborhood: Array = []

## When a cell in a DisplayLayer needs to be recomputed,
## the TerrainLayer needs to know which tiles surround it.
## This Array stores the paths from the affected cell to the neighboring world cells.
var display_to_world_neighborhood: Array

# TODO: document
var _rules: Dictionary = {}


func _init(fields: Dictionary) -> void:
	self.terrain_neighborhood = fields.terrain_neighborhood
	self.display_to_world_neighborhood = fields.display_to_world_neighborhood


## Register a new rule for a specific tile in an atlas.
func _register_tile(data: TileData, mapping: Dictionary) -> void:
	if data.terrain_set != 0:
		# This was already handled as an error in the parent TerrainDual
		return
	var terrain_neighbors := terrain_neighborhood.map(data.get_terrain_peering_bit)
	# Skip tiles with no peering bits in this filter
	# They might be used for a different layer,
	# or may have no peering bits at all, which will just be ignored by all layers
	if terrain_neighbors.any(func(neighbor): return neighbor == -1):
		if terrain_neighbors.any(func(neighbor): return neighbor != -1):
			push_warning(
				"Invalid Tile Neighborhood at %s.\n" % [mapping] +
				"Expected neighborhood: %s" % [terrain_neighborhood.map(Util.neighbor_name)]
			)
		return
	_register_rule(terrain_neighbors, mapping)


## Register a new rule for a set of surrounding terrain neighbors
func _register_rule(terrain_neighbors: Array, mapping: Dictionary) -> void:
	var node := _rules
	for terrain in terrain_neighbors:
		if terrain not in node:
			node[terrain] = {}
		node = node[terrain]
	if 'mapping' in node:
		var prev_mapping = node.mapping
		push_warning(
			"2 different tiles in this TileSet have the same Terrain neighbors:\n" +
			"Neighbor Configuration: %s\n" % [_neighbors_to_dict(terrain_neighbors)] +
			"1st: %s\n" % [prev_mapping] +
			"2nd: %s" % [mapping]
		)
	node.mapping = mapping


const TILE_EMPTY: Dictionary = {'sid': - 1, 'tile': Vector2i(-1, -1)}
## Returns the tile that should be used based on the surrounding terrain neighbors
func apply_rule(terrain_neighbors: Array) -> Dictionary:
	var is_empty := terrain_neighbors.all(func(terrain): return terrain == -1)
	if is_empty:
		return TILE_EMPTY
	var normalized_neighbors = terrain_neighbors.map(normalize_terrain)

	var node := _rules
	for terrain in normalized_neighbors:
		if terrain not in node:
			terrain = 0
		if terrain not in node:
			return TILE_EMPTY
		node = node[terrain]
	if 'mapping' not in node:
		return TILE_EMPTY
	return node.mapping


## Coerces all empty tiles to have a terrain of 0.
static func normalize_terrain(terrain):
	return terrain if terrain != -1 else 0


## Utility function for easier printing
func _neighbors_to_dict(terrain_neighbors: Array) -> Dictionary:
	return Util.arrays_to_dict(terrain_neighborhood.map(Util.neighbor_name), terrain_neighbors)
