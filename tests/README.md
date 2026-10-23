# Startup regression scene

From the project root, import the project and run:

```sh
godot --headless --editor --import
godot --headless --path . res://tests/startup.tscn
```

The scene packs a prepainted `TileMapDual` and repeatedly instantiates it with
square and isometric tile sets. Half of the cases call `update_internals()`
before adding the instance to the tree. This consumes the initial dirty cells
before `_ready()` creates the display, reproducing a permanently empty display
on the unfixed implementation. Each case also checks drawing and erasing a cell
after startup. A nonzero exit code indicates failure.

To test a native export, temporarily set `tests/startup.tscn` as the project's
main scene, export the project using the desired platform's debug and release
templates, and run both exported executables. Include the test scene and its
resources in the export. Restore the original main scene afterward. The tests
use explicit checks instead of `assert()`, so failures remain detectable in
release builds.

The existing scenes in `examples/` can be used for visual editor/runtime smoke
tests. In particular, `Isometric.tscn` and `Jess.tscn` cover isometric and square
maps, respectively.
