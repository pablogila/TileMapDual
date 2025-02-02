## Utility functions.
class_name Util


## Merges an Array of keys and an Array of values into a Dictionary.
static func arrays_to_dict(keys: Array, values: Array) -> Dictionary:
	var out := {}
	for i in keys.size():
		out[keys[i]] = values[i]
	return out


## Swaps the X and Y axes of a Vector2i.
static func transpose_vec(v: Vector2i) -> Vector2i:
	return Vector2i(v.y, v.x)


# TODO: transposed(TileSet.CellNeighbor) -> Tileset.CellNeighbor


## Reverses the direction of a CellNeighbor.
static func reverse_neighbor(neighbor: TileSet.CellNeighbor) -> TileSet.CellNeighbor:
	return (neighbor + 8) % 16


## Returns a shorthand name for a CellNeighbor.
static func neighbor_name(neighbor: TileSet.CellNeighbor) -> String:
	const DIRECTIONS := ['E', 'SE', 'S', 'SW', 'W', 'NW', 'N', 'NE']
	return DIRECTIONS[neighbor >> 1]


## Returns a pretty-printable neighborhood.
static func neighborhood_str(neighborhood: Array) -> String:
	var neighbors := array_of(-1, 16)
	for i in neighborhood.size():
		neighbors[neighborhood[i]] = i

	var get := func(neighbor: TileSet.CellNeighbor) -> String:
		var terrain = neighbors[neighbor]
		return '-' if terrain == -1 else str(terrain)

	var nw = get.call(TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER)
	var n = get.call(TileSet.CELL_NEIGHBOR_TOP_CORNER)
	var ne = get.call(TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER)
	var w = get.call(TileSet.CELL_NEIGHBOR_LEFT_CORNER)
	var e = get.call(TileSet.CELL_NEIGHBOR_RIGHT_CORNER)
	var sw = get.call(TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER)
	var s = get.call(TileSet.CELL_NEIGHBOR_BOTTOM_CORNER)
	var se = get.call(TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER)

	return (
		"%2s %2s %2s\n" % [nw, n, ne] +
		"%2s  C %2s\n" % [w, e] +
		"%2s %2s %2s\n" % [sw, s, se]
	)

## Returns an Array of the given size, all filled with the given value.
static func array_of(value: Variant, size: int) -> Array[Variant]:
	var out := []
	out.resize(size)
	out.fill(value)
	return out
