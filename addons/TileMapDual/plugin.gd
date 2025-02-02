@tool
extends EditorPlugin


# TODO: create a message queue that groups warnings, errors, and messages into categories
# so that we don't get 300 lines of the same warnings pushed to console every time we undo/redo


func _enter_tree() -> void:
	add_custom_type("TileMapDual", "TileMapLayer", preload("TileMapDual.gd"), preload("TileMapDual.svg"))
	add_custom_type("CursorDual", "Sprite2D", preload("CursorDual.gd"), preload("CursorDual.svg"))
	add_custom_type("TileMapDualLegacy", "TileMapLayer", preload("TileMapDualLegacy.gd"), preload("TileMapDual.svg"))
	print("plugin TileMapDual loaded")


func _exit_tree() -> void:
	remove_custom_type("CursorDual")
	remove_custom_type("TileMapDual")
	remove_custom_type("TileMapDualLegacy")
	print("plugin TileMapDual unloaded")
