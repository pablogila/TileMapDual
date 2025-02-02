@tool
@icon('TileMapDual.svg')
class_name TileMapDualLegacy
extends TileMapLayer

## Material for the display tilemap.
@export_custom(PROPERTY_HINT_RESOURCE_TYPE, "ShaderMaterial,CanvasItemMaterial")
var display_material: Material:
	get: 
		return display_material
	set(new_material): # Custom setter so that it gets copied 
		display_material = new_material
		if display_tilemap: # Copy over, only if display tilemap is initiated
			display_tilemap.material = display_material

var display_tilemap: TileMapLayer = null
var _filled_cells: Dictionary = {}
var _emptied_cells: Dictionary = {}
var _tile_shape: TileSet.TileShape = TileSet.TileShape.TILE_SHAPE_SQUARE
var _tile_size: Vector2i = Vector2i(16, 16)
## Coordinates for the fully-filled tile in the Atlas that
## will be used to sketch in the World grid.
## Only this tile will be considered for autotiling.
var full_tile: Vector2i = Vector2i(2,1)
## The opposed of full_tile. Used to erase sketched tiles.
var empty_tile: Vector2i = Vector2i(0,3)
var _should_check_cells: bool = false
## Prevents checking the cells more than once when the entire tileset
## is being updated, which is indicated by `_should_check_cells`.
var _checked_cells: Dictionary = {}
var is_isometric: bool = false
var _atlas_id: int

## We will use a bit-wise logic, so that a summation over all sketched
## neighbours provides a unique key, assigned to the corresponding
## tile from the Atlas through the NEIGHBOURS_TO_ATLAS dictionary.
enum _location {
	TOP_LEFT  = 1,
	LOW_LEFT  = 2,
	TOP_RIGHT = 4,
	LOW_RIGHT = 8
	}

enum _direction {
	TOP,
	LEFT,
	BOTTOM,
	RIGHT,
	BOTTOM_LEFT,
	BOTTOM_RIGHT,
	TOP_LEFT,
	TOP_RIGHT,
	}

## Overlapping tiles from the World grid
## that a tile from the Dual grid has.
const _NEIGHBORS := {
	_direction.TOP  : TileSet.CellNeighbor.CELL_NEIGHBOR_TOP_SIDE,
	_direction.LEFT : TileSet.CellNeighbor.CELL_NEIGHBOR_LEFT_SIDE,
	_direction.RIGHT : TileSet.CellNeighbor.CELL_NEIGHBOR_RIGHT_SIDE,
	_direction.BOTTOM  : TileSet.CellNeighbor.CELL_NEIGHBOR_BOTTOM_SIDE,
	_direction.TOP_LEFT  : TileSet.CellNeighbor.CELL_NEIGHBOR_TOP_LEFT_CORNER,
	_direction.TOP_RIGHT  : TileSet.CellNeighbor.CELL_NEIGHBOR_TOP_RIGHT_CORNER,
	_direction.BOTTOM_LEFT : TileSet.CellNeighbor.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER,
	_direction.BOTTOM_RIGHT : TileSet.CellNeighbor.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER
	}

## Overlapping tiles from the World grid
## that a tile from the Dual grid has.
## To be used ONLY with isometric tilesets.
## CellNighbors are literal, even for Isometric
const _NEIGHBORS_ISOMETRIC := {
	_direction.TOP : TileSet.CellNeighbor.CELL_NEIGHBOR_TOP_RIGHT_SIDE,
	_direction.LEFT : TileSet.CellNeighbor.CELL_NEIGHBOR_TOP_LEFT_SIDE,
	_direction.RIGHT : TileSet.CellNeighbor.CELL_NEIGHBOR_BOTTOM_RIGHT_SIDE,
	_direction.BOTTOM  : TileSet.CellNeighbor.CELL_NEIGHBOR_BOTTOM_LEFT_SIDE,
	_direction.TOP_LEFT  : TileSet.CellNeighbor.CELL_NEIGHBOR_TOP_CORNER,
	_direction.TOP_RIGHT  : TileSet.CellNeighbor.CELL_NEIGHBOR_RIGHT_CORNER,
	_direction.BOTTOM_LEFT : TileSet.CellNeighbor.CELL_NEIGHBOR_LEFT_CORNER,
	_direction.BOTTOM_RIGHT : TileSet.CellNeighbor.CELL_NEIGHBOR_BOTTOM_CORNER
	}

## Dict to assign the Atlas coordinates from the
## summation over all sketched NEIGHBOURS.
## Follows the official 2x2 template.
## Works for isometric as well.
const _NEIGHBORS_TO_ATLAS: Dictionary = {
	 0: Vector2i(0,3),
	 1: Vector2i(3,3),
	 2: Vector2i(0,0),
	 3: Vector2i(3,2),
	 4: Vector2i(0,2),
	 5: Vector2i(1,2),
	 6: Vector2i(2,3),
	 7: Vector2i(3,1),
	 8: Vector2i(1,3),
	 9: Vector2i(0,1),
	10: Vector2i(3,0),
	11: Vector2i(2,0),
	12: Vector2i(1,0),
	13: Vector2i(2,2),
	14: Vector2i(1,1),
	15: Vector2i(2,1)
	}


func _ready() -> void:
	if Engine.is_editor_hint():
		set_process(true)
	else: # Run in-game using signals for better performance
		set_process(false)
		self.changed.connect(_update_tileset, 1)
	update_full_tileset()
	# Fire copy upon any property change. More specific than _update_tileset
	self.changed.connect(copy_properties, 1) 

func _process(_delta): # Only used inside the editor
	if not self.tile_set:
		return
	call_deferred('_update_tileset')

## Copies properties from parent TileMapDual to child display tilemap
func copy_properties() -> void:
	# Both tilemaps must be the same, so we copy all relevant properties
	# Tilemap
	display_tilemap.tile_set = self.tile_set
	# Rendering
	display_tilemap.y_sort_origin = self.y_sort_origin
	display_tilemap.x_draw_order_reversed = self.x_draw_order_reversed
	display_tilemap.rendering_quadrant_size = self.rendering_quadrant_size
	# Physics
	display_tilemap.collision_enabled = self.collision_enabled
	display_tilemap.use_kinematic_bodies = self.use_kinematic_bodies
	display_tilemap.collision_visibility_mode = self.collision_visibility_mode
	# Navigation
	display_tilemap.navigation_enabled = self.navigation_enabled
	display_tilemap.navigation_visibility_mode = self.navigation_visibility_mode
	# Canvas item properties
	display_tilemap.show_behind_parent = self.show_behind_parent
	display_tilemap.top_level = self.top_level
	display_tilemap.light_mask = self.light_mask
	display_tilemap.visibility_layer = self.visibility_layer
	display_tilemap.y_sort_enabled = self.y_sort_enabled
	display_tilemap.modulate = self.modulate
	
	# If user has set a material in the original slot, copy it over for redundancy
	# Helps both migration to new version, and prevents user mistakes
	if self.material: 
		display_material = self.material
	
	# Set material for first time
	display_tilemap.material = display_material
	
	# Save any manually introduced alpha modulation:
	if self.self_modulate.a != 0.0:
		display_tilemap.self_modulate = self.self_modulate
	self.self_modulate.a = 0.0	# Override modulation to prevent render bugs with certain shaders
		
	self.material = null # Unset TileMapDual's material, to prevent render of it

## Set the dual grid as a child of TileMapDual.
func _set_display_tilemap() -> void:
	if not self.tile_set:
		return
		
	# Add the display TileMapLayer, if it doesn't already exist
	if not get_node_or_null("WorldTileMap"): 
		display_tilemap = TileMapLayer.new()
		display_tilemap.name = "WorldTileMap"
		add_child(display_tilemap)
	
	copy_properties() # Copy properties from TileMapDual to displayed tilemap
	
	update_geometry()
	display_tilemap.clear()
	
## Update the size and shape of the tileset, displacing the display TileMapLayer accordingly.
func update_geometry() -> void:
	is_isometric = self.tile_set.tile_shape == TileSet.TileShape.TILE_SHAPE_ISOMETRIC
	var offset := Vector2(self.tile_set.tile_size) * -0.5
	if is_isometric:
		offset.x = 0
	display_tilemap.position = offset
	_tile_size = self.tile_set.tile_size
	_tile_shape = self.tile_set.tile_shape


## Update the entire tileset, processing all the cells in the map.
func update_full_tileset() -> void:
	if display_tilemap == null:
		_set_display_tilemap()
	elif display_tilemap.tile_set != self.tile_set: # TO-DO: merge with the above
		_set_display_tilemap()
	_should_check_cells = true
	for _cell in self.get_used_cells():
		if _is_world_tile_sketched(_cell) == 1 or _is_world_tile_sketched(_cell) == 0:
			update_tile(_cell)
	_should_check_cells = false
	_checked_cells = {}
	# _checked_cells is only used when updating
	# the whole tilemap to avoid repeating checks.
	# This is skipped when updating tiles individually.
	
## Update only the very specific tiles that have changed.
## Much more efficient than update_full_tileset.
## Called by signals when the tileset changes,
## or by _process inside the editor.
func _update_tileset() -> void:
	if display_tilemap == null:
		update_full_tileset()
		return
	elif display_tilemap.tile_set != self.tile_set: # TO-DO: merge with the above
		update_full_tileset()
		return
	elif _tile_size != self.tile_set.tile_size or _tile_shape != self.tile_set.tile_shape:
		update_geometry()
		return

	var _new_emptied_cells: Dictionary = array_to_dict(get_used_cells_by_id(-1, empty_tile))
	var _new_filled_cells: Dictionary = array_to_dict(get_used_cells_by_id(-1, full_tile))
	var _changed_cells: Dictionary = exclude_dicts(_emptied_cells, _new_emptied_cells).merged(exclude_dicts(_filled_cells, _new_filled_cells))
	
	_emptied_cells = _new_emptied_cells
	_filled_cells = _new_filled_cells
	for _cell in _changed_cells:
		update_tile(_cell)

func array_to_dict(array: Array) -> Dictionary:
	var dict: Dictionary = {}
	for item in array:
		dict[item] = true
	return dict

## Return the values that are not shared between the arrays
func exclude_dicts(a: Dictionary, b: Dictionary) -> Dictionary:
	var result = a.duplicate()
	for item in b:
		if result.has(item):
			result.erase(item)
		else:
			result[item] = true
	return result

## Takes a cell, and updates the overlapping tiles from the dual grid accordingly.
func update_tile(world_cell: Vector2i, recurse: bool = true) -> void:
	_atlas_id = self.get_cell_source_id(world_cell)
	
	# to not fall in a recursive loop because of a large space of emptiness in the map
	if (!recurse and _atlas_id == -1):
		return
	
	var __NEIGHBORS = _NEIGHBORS_ISOMETRIC if is_isometric else _NEIGHBORS
	var _top_left = world_cell
	var _low_left = display_tilemap.get_neighbor_cell(world_cell, __NEIGHBORS[_direction.BOTTOM])
	var _top_right = display_tilemap.get_neighbor_cell(world_cell, __NEIGHBORS[_direction.RIGHT])
	var _low_right = display_tilemap.get_neighbor_cell(world_cell, __NEIGHBORS[_direction.BOTTOM_RIGHT])
	_update_displayed_tile(_top_left)
	_update_displayed_tile(_low_left)
	_update_displayed_tile(_top_right)
	_update_displayed_tile(_low_right)
	
	# if atlas id is -1 the tile is empty, so to have a good rendering we need to update surroundings
	if (_atlas_id == -1):
		update_tile(self.get_neighbor_cell(world_cell, __NEIGHBORS[_direction.LEFT]), false)
		update_tile(self.get_neighbor_cell(world_cell, __NEIGHBORS[_direction.TOP_LEFT]), false)
		update_tile(self.get_neighbor_cell(world_cell, __NEIGHBORS[_direction.TOP]), false)
		update_tile(self.get_neighbor_cell(world_cell, __NEIGHBORS[_direction.TOP_RIGHT]), false)
		update_tile(self.get_neighbor_cell(world_cell, __NEIGHBORS[_direction.RIGHT]), false)
		update_tile(self.get_neighbor_cell(world_cell, __NEIGHBORS[_direction.BOTTOM_RIGHT]), false)
		update_tile(self.get_neighbor_cell(world_cell, __NEIGHBORS[_direction.BOTTOM]), false)
		update_tile(self.get_neighbor_cell(world_cell, __NEIGHBORS[_direction.BOTTOM_LEFT]), false)


func _update_displayed_tile(_display_cell: Vector2i) -> void:
	# Avoid updating cells more than necessary
	if _should_check_cells:
		if _display_cell in _checked_cells:
			return
		_checked_cells[_display_cell] = true
	
	var __NEIGHBORS = _NEIGHBORS_ISOMETRIC if is_isometric else _NEIGHBORS
	var _top_left = display_tilemap.get_neighbor_cell(_display_cell, __NEIGHBORS[_direction.TOP_LEFT])
	var _low_left = display_tilemap.get_neighbor_cell(_display_cell, __NEIGHBORS[_direction.LEFT])
	var _top_right = display_tilemap.get_neighbor_cell(_display_cell, __NEIGHBORS[_direction.TOP])
	var _low_right = _display_cell
	
	# We perform a bitwise summation over the sketched neighbours
	var _tile_key: int = 0
	if _is_world_tile_sketched(_top_left) == 1:
		_tile_key += _location.TOP_LEFT
	if _is_world_tile_sketched(_low_left) == 1:
		_tile_key += _location.LOW_LEFT
	if _is_world_tile_sketched(_top_right) == 1:
		_tile_key += _location.TOP_RIGHT
	if _is_world_tile_sketched(_low_right) == 1:
		_tile_key += _location.LOW_RIGHT
	
	var _coords_atlas: Vector2i = _NEIGHBORS_TO_ATLAS[_tile_key]
	display_tilemap.set_cell(_display_cell, _atlas_id, _coords_atlas)


## Return -1 if the cell is empty, 0 if sketched with the empty tile,
## and 1 if it is sketched with the fully-filled tile.
func _is_world_tile_sketched(_world_cell: Vector2i):
	var _atlas_coords = get_cell_atlas_coords(_world_cell)
	if _atlas_coords == full_tile:
		return 1
	elif _atlas_coords == empty_tile:
		return 0
	return -1


## Public method to add and remove tiles, as
## TileMapDual.draw(cell, tile, atlas_id).
## 'cell' is a vector with the cell position.
## 'tile' is 1 to draw the full tile (default), 0 to draw the empty tile,
## and -1 to completely remove the tile.
## 'atlas_id' is the atlas id of the tileset to modify, 0 by default.
## This method replaces the deprecated 'fill_tile' and 'erase_tile' methods.
func draw(cell: Vector2i, tile: int = 1, atlas_id: int = 0) -> void:
	# Prevents a crash if this is called on the first frame
	if display_tilemap == null:
		update_full_tileset()
	var tile_to_use: Vector2i
	if tile == 1:
		tile_to_use = full_tile
	if tile == 0:
		tile_to_use = empty_tile
	if tile == -1:
		tile_to_use = Vector2i(-1, -1)
		atlas_id = -1
	set_cell(cell, atlas_id, tile_to_use)
	update_tile(cell)
