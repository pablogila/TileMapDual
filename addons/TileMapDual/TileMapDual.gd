@tool
@icon('TileMapDual.svg')
class_name TileMapDual
extends TileMapLayer


var _tileset_watcher: TileSetWatcher
var _display: Display
func _ready() -> void:
	_tileset_watcher = TileSetWatcher.new(tile_set)
	_display = Display.new(self, _tileset_watcher)
	add_child(_display)
	_make_self_invisible()
	if Engine.is_editor_hint():
		_tileset_watcher.atlas_autotiled.connect(_atlas_autotiled, 1)
		set_process(true)
	else: # Run in-game using signals for better performance
		set_process(false)
		changed.connect(_changed, 1)
	# Update full tileset on first instance
	_changed()


## Automatically generate terrains when the atlas is initialized.
func _atlas_autotiled(source_id: int, atlas: TileSetAtlasSource):
	var urm := EditorPlugin.new().get_undo_redo()
	urm.create_action("Create tiles in non-transparent texture regions", UndoRedo.MergeMode.MERGE_ALL, self, true)
	# NOTE: commit_action() is called immediately after.
	# NOTE: Atlas is guaranteed to have only been auto-generated with no extra peering bit information.
	TerrainPreset.write_default_preset(urm, tile_set, atlas)
	urm.commit_action()


## Makes the main world grid invisible.
## The main tiles don't need to be seen. Only the DisplayLayers should be visible.
## Called on ready.
func _make_self_invisible() -> void:
	if material != null:
		return
	material = CanvasItemMaterial.new()
	material.light_mode = CanvasItemMaterial.LightMode.LIGHT_MODE_LIGHT_ONLY


## HACK: How long to wait before processing another "frame"
@export_range(0.0, 0.1) var refresh_time: float = 0.02
var _timer: float = 0.0
func _process(delta: float) -> void: # Only used inside the editor
	if refresh_time < 0.0:
		return
	if _timer > 0:
		_timer -= delta
		return
	_timer = refresh_time
	call_deferred('_changed')


## Called by signals when the tileset changes,
## or by _process inside the editor.
func _changed() -> void:
	_tileset_watcher.update(tile_set)
	_display.update(self)


## Public method to add and remove tiles.
##
## 'cell' is a vector with the cell position.
## 'terrain' is which terrain type to draw.
## terrain -1 completely removes the tile,
## and by default, terrain 0 is the empty tile.
func draw_cell(cell: Vector2i, terrain: int = 1) -> void:
	var terrains := _display.terrain.terrains
	if terrain not in terrains:
		erase_cell(cell)
		changed.emit()
		return
	var tile_to_use: Dictionary = terrains[terrain]
	var sid: int = tile_to_use.sid
	var tile: Vector2i = tile_to_use.tile
	set_cell(cell, sid, tile)
	changed.emit()
