## Functions for automatically generating terrains for an atlas.
class_name TerrainPreset


## Maps a Neighborhood to a Topology.
const NEIGHBORHOOD_TOPOLOGIES := {
	TerrainDual.Neighborhood.SQUARE: Topology.SQUARE,
	TerrainDual.Neighborhood.ISOMETRIC: Topology.SQUARE,
	TerrainDual.Neighborhood.TRIANGLE_HORIZONTAL: Topology.TRIANGLE,
	TerrainDual.Neighborhood.TRIANGLE_VERTICAL: Topology.TRIANGLE,
}


## Determines the available Terrain presets for a certain Atlas.
enum Topology {
	SQUARE,
	TRIANGLE,
}


## Maps a Neighborhood to a preset of the specified name.
static func neighborhood_preset(
	neighborhood: TerrainDual.Neighborhood,
	preset_name: String = 'Standard'
) -> Dictionary:
	var topology: Topology = NEIGHBORHOOD_TOPOLOGIES[neighborhood]
	# TODO: test when the preset doesn't exist
	var available_presets = PRESETS[topology]
	if preset_name not in available_presets:
		return {'size': Vector2i.ONE, 'layers': []}
	var out: Dictionary = available_presets[preset_name].duplicate(true)
	# All Horizontal neighborhoods can be transposed to Vertical
	if neighborhood == TerrainDual.Neighborhood.TRIANGLE_VERTICAL:
		out.size = Util.transpose_vec(out.size)
		out.fg = Util.transpose_vec(out.fg)
		out.bg = Util.transpose_vec(out.bg)
		for seq in out.layers:
			for i in seq.size():
				seq[i] = Util.transpose_vec(seq[i])
	return out


## Contains all of the builtin Terrain presets for each topology
const PRESETS := {
	Topology.SQUARE: {
		'Standard': {
			'size': Vector2i(4, 4),
			'bg': Vector2i(0, 3),
			'fg': Vector2i(2, 1),
			'layers': [
				[ # []
					Vector2i(0, 3),
					Vector2i(3, 3),
					Vector2i(0, 2),
					Vector2i(1, 2),
					Vector2i(0, 0),
					Vector2i(3, 2),
					Vector2i(2, 3),
					Vector2i(3, 1),
					Vector2i(1, 3),
					Vector2i(0, 1),
					Vector2i(1, 0),
					Vector2i(2, 2),
					Vector2i(3, 0),
					Vector2i(2, 0),
					Vector2i(1, 1),
					Vector2i(2, 1),
				],
			],
		},
	},
	Topology.TRIANGLE: {
		'Standard': {
			'size': Vector2i(4, 4),
			'bg': Vector2i(0, 0),
			'fg': Vector2i(0, 2),
			'layers': [
				[ # v
					Vector2i(0, 1),
					Vector2i(2, 3),
					Vector2i(3, 1),
					Vector2i(1, 3),
					Vector2i(1, 1),
					Vector2i(3, 3),
					Vector2i(2, 1),
					Vector2i(0, 3),
				],
				[ # ^
					Vector2i(0, 0),
					Vector2i(2, 2),
					Vector2i(3, 0),
					Vector2i(1, 2),
					Vector2i(1, 0),
					Vector2i(3, 2),
					Vector2i(2, 0),
					Vector2i(0, 2),
				],
			]
		},
		# Old template.
		# a bit inconvenient to use for Brick (Half-Off Square) tilesets.
		'Winged': {
			'size': Vector2i(4, 4),
			'bg': Vector2i(0, 0),
			'fg': Vector2i(0, 2),
			'layers': [
				[ # v
					Vector2i(0, 1),
					Vector2i(2, 1),
					Vector2i(3, 1),
					Vector2i(1, 3),
					Vector2i(1, 1),
					Vector2i(3, 3),
					Vector2i(2, 3),
					Vector2i(0, 3),
				],
				[ # ^
					Vector2i(0, 0),
					Vector2i(2, 0),
					Vector2i(3, 0),
					Vector2i(1, 2),
					Vector2i(1, 0),
					Vector2i(3, 2),
					Vector2i(2, 2),
					Vector2i(0, 2),
				],
			]
		},
		# Old template.
		# The gaps between triangles made them harder to align.
		'Alternating': {
			'size': Vector2i(4, 4),
			'bg': Vector2i(0, 0),
			'fg': Vector2i(0, 2),
			'layers': [
				[ # v
					Vector2i(0, 0),
					Vector2i(2, 0),
					Vector2i(3, 1),
					Vector2i(1, 3),
					Vector2i(1, 1),
					Vector2i(3, 3),
					Vector2i(2, 2),
					Vector2i(0, 2),
				],
				[ # ^
					Vector2i(0, 1),
					Vector2i(2, 1),
					Vector2i(3, 0),
					Vector2i(1, 2),
					Vector2i(1, 0),
					Vector2i(3, 2),
					Vector2i(2, 3),
					Vector2i(0, 3),
				],
			],
		},
	},
}

## Would you like to automatically create tiles in the atlas?
##
## NOTE: Assumes urm.create_action() was called. Does not actually do anything until urm.commit_action() is called.
## NOTE: Assumes atlas only has auto-generated tiles. Does not save peering bit information or anything else for undo/redo.
static func write_default_preset(urm: EditorUndoRedoManager, tile_set: TileSet, atlas: TileSetAtlasSource) -> void:
	#print('writing default')
	var neighborhood := TerrainDual.tileset_neighborhood(tile_set)
	var terrain := new_terrain(
		urm,
		tile_set,
		atlas.texture.resource_path.get_file()
	)
	write_preset(
		urm,
		atlas,
		neighborhood,
		terrain,
	)


## Creates terrain set 0 (the primary terrain set) and terrain 0 (the 'any' terrain)
##
## NOTE: Assumes urm.create_action() was called. Does not actually do anything until urm.commit_action() is called.
static func init_terrains(urm: EditorUndoRedoManager, tile_set: TileSet) -> void:
	urm.add_do_method(TerrainPreset, "_do_init_terrains", tile_set)
	urm.add_undo_method(TerrainPreset, "_undo_init_terrains", tile_set)

static func _do_init_terrains(tile_set: TileSet) -> void:
	tile_set.add_terrain_set()
	tile_set.set_terrain_set_mode(0, TileSet.TERRAIN_MODE_MATCH_CORNERS)
	tile_set.add_terrain(0)
	tile_set.set_terrain_name(0, 0, "<any>")
	tile_set.set_terrain_color(0, 0, Color.VIOLET)

static func _undo_init_terrains(tile_set: TileSet) -> void:
	tile_set.remove_terrain_set(0)


## Adds a new terrain type to terrain set 0 for the sprites to use.
##
## NOTE: Assumes urm.create_action() was called. Does not actually do anything until urm.commit_action() is called.
static func new_terrain(urm: EditorUndoRedoManager, tile_set: TileSet, terrain_name: String) -> int:
	var terrain: int
	if tile_set.get_terrain_sets_count() == 0:
		init_terrains(urm, tile_set)
		terrain = 1
	else:
		terrain = tile_set.get_terrains_count(0)
	urm.add_do_method(TerrainPreset, "_do_new_terrain", tile_set, terrain_name)
	urm.add_undo_method(TerrainPreset, "_undo_new_terrain", tile_set)
	return terrain

static func _do_new_terrain(tile_set: TileSet, terrain_name: String) -> void:
	tile_set.add_terrain(0)
	var terrain := tile_set.get_terrains_count(0) - 1
	tile_set.set_terrain_name(0, terrain, "FG -%s" % terrain_name)

static func _undo_new_terrain(tile_set: TileSet) -> void:
	var terrain := tile_set.get_terrains_count(0) - 1
	tile_set.remove_terrain(0, terrain)


## Takes a preset and writes it onto the given atlas, replacing the previous configuration.
## ARGUMENTS:
## - atlas: the atlas source to apply the preset to.
## - filters: the neighborhood filter
##
## NOTE: Assumes urm.create_action() was called. Does not actually do anything until urm.commit_action() is called.
## NOTE: Assumes atlas only has auto-generated tiles. Does not save peering bit information or anything else for undo/redo.
static func write_preset(
	urm: EditorUndoRedoManager,
	atlas: TileSetAtlasSource,
	neighborhood: TerrainDual.Neighborhood,
	terrain_foreground: int,
	terrain_background: int = 0,
	preset: Dictionary = neighborhood_preset(neighborhood),
) -> void:
	clear_and_divide_atlas(urm, atlas, preset.size)
	urm.add_do_method(TerrainPreset, '_do_write_preset', atlas, neighborhood, terrain_foreground, terrain_background, preset)

static func _do_write_preset(
	atlas: TileSetAtlasSource,
	neighborhood: TerrainDual.Neighborhood,
	terrain_foreground: int,
	terrain_background: int,
	preset: Dictionary,
) -> void:
	var layers: Array = TerrainDual.NEIGHBORHOOD_LAYERS[neighborhood]
	# Set peering bits
	var sequences: Array = preset.layers
	for j in layers.size():
		var terrain_neighborhood = layers[j].terrain_neighborhood
		var sequence: Array = sequences[j]
		for i in sequence.size():
			var tile: Vector2i = sequence[i]
			atlas.create_tile(tile)
			var data := atlas.get_tile_data(tile, 0)
			data.terrain_set = 0
			for neighbor in terrain_neighborhood:
				data.set_terrain_peering_bit(
					neighbor,
					[terrain_background, terrain_foreground][i & 1]
				)
				i >>= 1
	# Set terrains
	atlas.get_tile_data(preset.bg, 0).terrain = terrain_background
	atlas.get_tile_data(preset.fg, 0).terrain = terrain_foreground

## Unregisters all the tiles in an atlas and changes the size of the individual sprites.
##
## NOTE: Assumes urm.create_action() was called. Does not actually do anything until urm.commit_action() is called.
## NOTE: Assumes atlas only has auto-generated tiles. Does not save peering bit information or anything else for undo/redo.
static func clear_and_resize_atlas(urm: EditorUndoRedoManager, atlas: TileSetAtlasSource, size: Vector2) -> void:
	var atlas_data := _save_atlas_data(atlas)
	urm.add_do_method(TerrainPreset, '_do_clear_and_resize_atlas', atlas, size)
	urm.add_undo_method(TerrainPreset, '_undo_clear_and_resize_atlas', atlas, atlas_data)

static func _do_clear_and_resize_atlas(atlas: TileSetAtlasSource, size: Vector2) -> void:
	# Clear all tiles
	atlas.texture_region_size = atlas.texture.get_size() + Vector2.ONE
	atlas.clear_tiles_outside_texture()
	# Resize the tiles
	atlas.texture_region_size = size

static func _undo_clear_and_resize_atlas(atlas: TileSetAtlasSource, atlas_data: Dictionary) -> void:
	_load_atlas_data(atlas, atlas_data)
	
## NOTE: Assumes atlas only has auto-generated tiles. Does not save peering bit information or anything else.
static func _save_atlas_data(atlas: TileSetAtlasSource) -> Dictionary:
	var size_img := atlas.texture.get_size()
	var size_sprite := atlas.texture_region_size
	var size_dims := Vector2i(size_img) / size_sprite
	var tiles := []
	for y in size_dims.y:
		var row := []
		for x in size_dims.x:
			var tile := Vector2i(x, y)
			var exists := atlas.has_tile(tile)
			row.push_back(exists)
		tiles.push_back(row)
	return {
		'size_sprite': size_sprite,
		'size_dims': size_dims,
		'tiles': tiles,
	}

static func _load_atlas_data(atlas: TileSetAtlasSource, atlas_data: Dictionary) -> void:
	_do_clear_and_resize_atlas(atlas, atlas_data.size_sprite)
	for y in atlas_data.size_dims.y:
		for x in atlas_data.size_dims.x:
			if atlas_data.tiles[y][x]:
				var tile := Vector2i(x, y)
				atlas.create_tile(tile)
			

## Unregisters all the tiles in an atlas and changes the size of the
## individual sprites to accomodate a divisions.x by divisions.y grid of sprites.
##
## NOTE: Assumes urm.create_action() was called. Does not actually do anything until urm.commit_action() is called.
## NOTE: Assumes atlas only has auto-generated tiles. Does not save peering bit information or anything else for undo/redo.
static func clear_and_divide_atlas(urm: EditorUndoRedoManager, atlas: TileSetAtlasSource, divisions: Vector2i) -> void:
	clear_and_resize_atlas(urm, atlas, atlas.texture.get_size() / Vector2(divisions))
