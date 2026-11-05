extends SceneTree
var frame := 0
var fails := 0
var main: Node
var takeover_tower: Node3D
func _initialize() -> void:
 main = load('res://scenes/main.tscn').instantiate()
 root.add_child(main)
func check(label: String, yes: bool) -> void:
 print(('OK ' if yes else 'FOUT ') + label)
 if not yes: fails += 1
func _process(_delta: float) -> bool:
 frame += 1
 var game = root.get_node('Game')
 if frame == 2:
  for menu in get_nodes_in_group('menus'):
   menu._show('')
 if frame == 4:
  main.begin()
 if frame > 4 and game.state == 'prep': game.prep_t = 1e9
 if frame == 40:
  var towers := get_nodes_in_group('vijand_toren')
  var defenders := get_nodes_in_group('vijand_verdediger')
  check('vier torens', towers.size() == 4)
  check('twaalf verdedigers', defenders.size() == 12)
  var counts := {'schutter':0,'poort':0,'hk':0,'reserve':0}
  for soldier in defenders: counts[soldier.post] += 1
  check('rollen 4/4/2/2', counts == {'schutter':4,'poort':4,'hk':2,'reserve':2})
  var t = towers[0]
  check('650 HP en 36 m', t.hp == 650.0 and t.RANGE == 36.0)
  check('toren bemand', t.operational())
  t.shooter.hit(999.0, Vector3.UP, true)
  check('schutter apart uitgeschakeld, MG stil', not t.operational() and not t.destroyed)
  t.damage(650.0)
  check('toren definitief vernietigd', t.destroyed and t.hp <= 0.0)
  var body := t.get_child(1) as StaticBody3D
  check('ruïne heeft botslichaam', body != null and body.collision_layer != 0)
  takeover_tower = towers[1]
  takeover_tower.shooter.hit(999.0, Vector3.UP, true)
 if frame == 45:
  check('reserve toegewezen na schutterverlies', takeover_tower.reserved_by != null and not takeover_tower.operational())
  var reserve = takeover_tower.reserved_by
  reserve.hit(999.0, Vector3.UP, true)
  check('reserve onderweg kan sterven', reserve.dead and not takeover_tower.operational())
 if frame == 50:
  check('tweede reserve wordt toegewezen', takeover_tower.reserved_by != null and not takeover_tower.reserved_by.dead)
 if frame == 900:
  check('reserve bereikt platform en bemant MG', takeover_tower.operational())
  print('klaar, fouten: ', fails)
  quit(1 if fails else 0)
 return false
