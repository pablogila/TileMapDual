## Provides information about a TileSet and sends signals when it changes.
class_name TileSetWatcher
extends Resource

## Caches the previous tile_set to see when it changes.
var tile_set: TileSet
## Caches the previous tile_size to see when it changes.
var tile_size: Vector2i
## caches the previous result of display.tileset_grid_shape(tile_set) to see when it changes.
var grid_shape: Display.GridShape

func _init(tile_set: TileSet) -> void:
	# tileset_deleted.connect(func(): print('tileset_deleted'), 1)
	# tileset_created.connect(func(): print('tileset_created'), 1)
	# tileset_resized.connect(func(): print('tileset_resized'), 1)
	# tileset_reshaped.connect(func(): print('tileset_reshaped'), 1)
	atlas_added.connect(_atlas_added, 1)
	update(tile_set)


var _flag_tileset_deleted := false
## Emitted when the parent TileMapDual's tile_set is cleared or replaced.
signal tileset_deleted

var _flag_tileset_created := false
## Emitted when the parent TileMapDual's tile_set is created or replaced.
signal tileset_created

var _flag_tileset_resized := false
## Emitted when tile_set.tile_size is changed.
signal tileset_resized

var _flag_tileset_reshaped := false
## Emitted when the GridShape of the TileSet would be different.
signal tileset_reshaped

var _flag_atlas_added := false
## Emitted when a new Atlas is added to this TileSet.
## Does not react to Scenes being added to the TileSet.
signal atlas_added(source_id: int, atlas: TileSetAtlasSource)
func _atlas_added(source_id: int, atlas: TileSetAtlasSource) -> void:
	_flag_atlas_added = true
	#print('SIGNAL EMITTED: atlas_added(%s)' % {'source_id': source_id, 'atlas': atlas})


## Emitted when the watcher thinks that "Yes" was clicked for:
## 'Would you like to automatically create tiles in the atlas?'
signal atlas_autotiled(source_id: int, atlas: TileSetAtlasSource)


var _flag_terrains_changed := false
## Emitted when an atlas is added or removed,
## or when the terrains change in one of the Atlases.
## NOTE: Prefer connecting to TerrainDual.changed instead of TileSetWatcher.terrains_changed.
signal terrains_changed


## Checks if anything about the concerned TileMapDual's tile_set changed.
## Must be called by the TileMapDual every frame.
func update(tile_set: TileSet) -> void:
	check_tile_set(tile_set)
	check_flags()


## Emit update signals if the corresponding flags were set.
## Must only be run once per frame.
func check_flags() -> void:
	if _flag_tileset_changed:
		_flag_tileset_changed = false
		_update_tileset()
	if _flag_tileset_deleted:
		_flag_tileset_deleted = false
		_flag_tileset_reshaped = true
		tileset_deleted.emit()
	if _flag_tileset_created:
		_flag_tileset_created = false
		_flag_tileset_reshaped = true
		tileset_created.emit()
	if _flag_tileset_resized:
		_flag_tileset_resized = false
		tileset_resized.emit()
	if _flag_tileset_reshaped:
		_flag_tileset_reshaped = false
		_flag_terrains_changed = true
		tileset_reshaped.emit()
	if _flag_atlas_added:
		_flag_atlas_added = false
		_flag_terrains_changed = true
	if _flag_terrains_changed:
		_flag_terrains_changed = false
		terrains_changed.emit()


## Check if tile_set has been added, replaced, or deleted.
func check_tile_set(tile_set: TileSet) -> void:
	if tile_set == self.tile_set:
		return
	if self.tile_set != null:
		self.tile_set.changed.disconnect(_set_tileset_changed)
		_cached_source_count = 0
		_cached_sids.clear()
		_flag_tileset_deleted = true
	self.tile_set = tile_set
	if self.tile_set != null:
		self.tile_set.changed.connect(_set_tileset_changed, 1)
		self.tile_set.emit_changed()
		_flag_tileset_created = true
	emit_changed()


var _flag_tileset_changed := false
## Helper method to be called when the tile_set detects a change.
## Must be disconnected when the tile_set is changed.
func _set_tileset_changed() -> void:
	_flag_tileset_changed = true


## Called when _flag_tileset_changed.
## Provides more detail about what changed.
func _update_tileset() -> void:
	var tile_size = tile_set.tile_size
	if self.tile_size != tile_size:
		self.tile_size = tile_size
		_flag_tileset_resized = true
	var grid_shape = Display.tileset_gridshape(tile_set)
	if self.grid_shape != grid_shape:
		self.grid_shape = grid_shape
		_flag_tileset_reshaped = true
	_update_tileset_atlases()


# Cached variables from the previous frame
# These are used to compare what changed between frames
var _cached_source_count: int = 0
var _cached_sids := {}
# TODO: detect automatic tile creation
## Checks if new atlases have been added.
## Does not check which ones were deleted.
func _update_tileset_atlases() -> void:
	# Update all tileset sources
	var source_count := tile_set.get_source_count()

	# Only if an asset was added or removed
	# FIXME?: may break on add+remove in 1 frame
	if _cached_source_count == source_count:
		return
	_cached_source_count = source_count

	# Process the new atlases in the TileSet
	var sids := {}
	for i in source_count:
		var sid: int = tile_set.get_source_id(i)
		if sid in _cached_sids:
			sids[sid] = _cached_sids[sid]
			continue
		var source: TileSetSource = tile_set.get_source(sid)
		if source is not TileSetAtlasSource:
			push_warning(
				"Non-Atlas TileSet found at index %i, source id %i.\n" % [i, source] +
				"Dual Grids only support Atlas TileSets."
			)
			sids[sid] = null
			continue
		var atlas: TileSetAtlasSource = source
		# FIXME?: check if this needs to be disconnected
		# SETUP:
		# - add logging to check which Watcher's flag was changed
		# - add a TileSet with an atlas to 2 TileMapDuals
		# - remove the TileSet
		# - modify the terrains on one of the atlases
		# - check how many watchers were flagged:
		#   - if 2 watchers were flagged, this is bad.
		#     try to repeatedly add and remove the tileset.
		#     this could either cause the flag to happen multiple times,
		#     or it could stay at 2 watchers.
		#   - if 1 watcher was flagged, that is ok
		sids[sid] = AtlasWatcher.new(self, sid, atlas)
		atlas_added.emit(sid, atlas)
	_flag_terrains_changed = true
	# FIXME?: find which sid's were deleted
	_cached_sids = sids
