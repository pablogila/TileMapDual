## Watches a TileSetAtlasSource for changes.
## Causes its 'parent' TileSetWatcher to emit terrains_changed when the atlas changes.
## Also emits parent.atlas_autotiled when it thinks the user auto-generated atlas tiles.
class_name AtlasWatcher

## Prevents the number of seen atlases from extending to infinity.
const UNDO_LIMIT = 1024
## Stores all of the atlas instance id's that have been seen before, to prevent autogen on redo.
static var _registered_atlases := []

## The TileSetWatcher that created this AtlasWatcher. Used to send signals back.
var parent: TileSetWatcher

## The Source ID of `self.atlas`.
var sid: int

## The atlas to be watched for changes.
var atlas: TileSetAtlasSource

func _init(parent: TileSetWatcher, sid: int, atlas: TileSetAtlasSource) -> void:
	self.parent = parent
	self.sid = sid
	self.atlas = atlas
	atlas.changed.connect(_atlas_changed, ConnectFlags.CONNECT_DEFERRED)
	var id := atlas.get_instance_id()
	# should not autogen if atlas was created through redo, i.e. its instance id already existed
	if _atlas_is_empty() and id not in _registered_atlases:
		_registered_atlases.push_back(id)
		if _registered_atlases.size() > UNDO_LIMIT:
			_registered_atlases.pop_front()
		atlas.changed.connect(_detect_autogen, ConnectFlags.CONNECT_DEFERRED | ConnectFlags.CONNECT_ONE_SHOT)


func _atlas_is_empty() -> bool:
	return atlas.get_tiles_count() == 0


## Returns true if the texture has any opaque pixels in the specified tile coordinates.
func _is_opaque_tile(image: Image, tile: Vector2i, p_threshold: float = 0.1) -> bool:
	# We cannot use atlas.get_tile_texture_region(tile) as it fails on unregistered tiles.
	var region := Rect2i(tile * atlas.texture_region_size, atlas.texture_region_size)
	var sprite := image.get_region(region)
	if sprite.is_invisible():
		return false
	# We're still not sure if the tile is empty or not.
	# Godot's auto-gen considers 0.1 opacity as "transparent" but not "invisible".
	for y in range(region.position.y, region.end.y):
		for x in range(region.position.x, region.end.x):
			if image.get_pixel(x, y).a > p_threshold:
				return true
	return false


## HACK: literally just tries to guess which tiles the terrain autogen system would make
## Called once, and only once, at the end of the first frame that a texture is created.
func _detect_autogen() -> void:
	var size := Vector2i(atlas.texture.get_size()) / atlas.texture_region_size
	var image := atlas.texture.get_image()
	var expected_tiles := []
	for y in size.y:
		for x in size.x:
			var tile := Vector2i(x, y)
			if atlas.has_tile(tile) != _is_opaque_tile(image, tile):
				return
	parent.atlas_autotiled.emit(sid, atlas)


## Called every time the atlas changes. Simply flags that terrains have changed.
func _atlas_changed() -> void:
	parent._flag_terrains_changed = true
