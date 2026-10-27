class_name Bullet
extends RefCounted

const MASK_ENEMY := 1
const MASK_WALL := 2
const MASK_BUNKER := 4
const MASK_GROUND := 8

var src := ""

static func fire(_parent: Node, _from: Vector3, _angle: float, _speed: float, _damage: float, _life: float, _by_player: bool, _over_wall: bool = false, _pierce: int = 0, _explosive: float = 0.0, _sink: float = 0.0, _rise: float = 0.0, _visual_weapon: String = "") -> Bullet:
	return Bullet.new()
