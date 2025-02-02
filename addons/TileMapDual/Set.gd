## Real sets don't exist yet.
## https://github.com/godotengine/godot/pull/94399
class_name Set
extends Resource


## The internal Dictionary that holds this Set's items as keys.
var data: Dictionary = {}

func _init(initial_data: Variant = []) -> void:
	union_in_place(initial_data)

## Returns true if the item exists in this Set.
func has(item: Variant) -> bool:
	return item in data


## A dummy value to put in a slot.
const DUMMY = null
## Returns true if the item was not previously in the Set.
func insert(item: Variant) -> bool:
	var out := not has(item)
	data[item] = DUMMY
	return out


## Returns true if the item was previously in the Set.
func remove(item: Variant) -> bool:
	return data.erase(item)


## Deletes all items in this Set.
func clear() -> void:
	data = {}


## Merges an Array's items or Dict's keys into the Set.
func union_in_place(other: Variant):
	for item in other:
		insert(item)


## Returns a new Set with the items of both self and other.
func union(other: Set) -> Set:
	var out = self.duplicate()
	out.union_in_place(other.data)
	return out


## Removes an Array's items or Dict's keys from the Set.
func diff_in_place(other: Variant):
	for item in other:
		remove(item)


## Returns a new Set with all items in self that are not present in other.
func diff(other: Set) -> Set:
	var out = self.duplicate()
	out.diff_in_place(other.data)
	return out


## Inserts elements that are in other but not in self, and removes elements found in both.
func xor_in_place(other: Variant):
	for item in other:
		if has(item):
			remove(item)
		else:
			insert(item)


## Returns a new Set where each item is either in self or other, but not both.
func xor(other: Set) -> Set:
	var out = self.duplicate()
	out.xor_in_place(other.data)
	return out
