class_name RangKeuze
extends Control
## Fixture stub voor scripts/rang_keuze.gd: het kiesscherm komt in deze tests niet open.
static func open(parent: Control) -> RangKeuze:
	var k := RangKeuze.new()
	parent.add_child(k)
	return k
