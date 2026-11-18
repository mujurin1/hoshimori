class_name Game
extends Node3D
## ゲーム本体:状態、全体の進行、共通の計算、カメラ。
## プレイヤー・敵・出現・かけら・ボット・メッシュの処理は、それぞれ GamePlayer などの部品が持つ。

const R := 20.0
const NIGHT_LEN := 480.0
const CELL := 3.0
const MAX_ENEMIES := 240
const MAX_GEMS := 420
const CAM_H := 14.5
const CAM_B := 10.5
const BASE_SPEED := 7.2
const DASH_CD := 1.8
# 被弾した時の点滅。BLINK_TIME 秒のあいだ、BLINK_PERIOD 秒ごとに BLINK_OFF 秒だけ体を消す
const BLINK_TIME := 0.9
const BLINK_PERIOD := 0.2
const BLINK_OFF := 0.07
# ダッシュの無敵時間。この間は体を網点で薄くして、無敵だと分かるようにする
const DASH_IFRAME := 0.32
# 向きを変える速さの上限（ラジアン毎秒）
const TURN_MAX := 18.0

const ETYPES := {
	"moya": {"hp": 6.0, "speed": 2.7, "radius": 0.6, "dmg": 8.0, "xp": 1, "hop": 7.0, "color": Color("b07cf7")},
	"hashiri": {"hp": 4.0, "speed": 5.0, "radius": 0.45, "dmg": 7.0, "xp": 1, "hop": 13.0, "color": Color("ff7a59")},
	"dosun": {"hp": 42.0, "speed": 1.9, "radius": 1.0, "dmg": 15.0, "xp": 6, "hop": 4.0, "color": Color("5b7fd6")},
	"tsubute": {"hp": 13.0, "speed": 2.5, "radius": 0.6, "dmg": 8.0, "xp": 3, "hop": 6.0, "color": Color("35d0ba"), "ranged": true},
	"oomoya": {"hp": 700.0, "speed": 2.6, "radius": 2.0, "dmg": 24.0, "xp": 0, "hop": 3.5, "color": Color("d16bff"), "boss": true},
	"nushi": {"hp": 9000.0, "speed": 3.3, "radius": 2.6, "dmg": 30.0, "xp": 0, "hop": 3.0, "color": Color("7b3fc4"), "boss": true},
}


class Enemy:
	var node: MeshInstance3D
	var kind: String
	var dir: Vector3
	var pos: Vector3
	var face := Vector3.ZERO
	var hp := 1.0
	var max_hp := 1.0
	var speed := 1.0
	var radius := 0.5
	var dmg := 1.0
	var xp := 1
	var hop := 6.0
	var scale := 1.0
	var color := Color.WHITE
	var flash := 0.0
	var mat: Material
	var kb := Vector3.ZERO
	var phase := 0.0
	var spawn_t := 0.0
	var dead := false
	var boss := false
	var elite := false
	var ranged := false
	var shoot_cd := 2.0
	var moon_cd := 0.0
	var comet_cd := 0.0
	var tmp := 0.0
	var strafe := 1.0


class Gem:
	var dir: Vector3
	var value := 1
	var vel := 0.0
	var pulled := false
	var xf: Transform3D
	var color: Color


class Special:
	var node: MeshInstance3D
	var dir: Vector3
	var kind: String
	var age := 0.0


class EBullet:
	var node: MeshInstance3D
	var dir: Vector3
	var tan: Vector3
	var life := 4.0
	var dmg := 8.0


var main: Node
var world: World
var fx: Fx
var weapons: Weapons
var cam: Camera3D
var rng := RandomNumberGenerator.new()

var player: GamePlayer
var meshes: GameMeshes
var enemy_sys: GameEnemies
var spawner: GameSpawner
var pickups: GamePickups
var bot_ai: GameBot

var running := false
var alive := false
var bot := false
var difficulty := 1 # 0 やさしい / 1 ふつう / 2 むずかしい
var god := false
var sim_speed := 1.0
var slow_t := 0.0

var p_dir := Vector3.UP
var p_fwd := Vector3.FORWARD
var cam_fwd := Vector3.FORWARD
var p_hp := 100.0
var p_max_hp := 100.0
var p_iframe := 0.0
var p_blink := 0.0
var p_ghost := 0.0
var dash_t := 0.0
var dash_cd := 0.0
var dash_dir := Vector3.ZERO
var walk_t := 0.0
var moving := false
# 走る姿（1）と立ち姿（0）の混ぜ具合。入力が 1〜2 フレーム途切れただけで姿勢がガクッと切り替わらないよう、少しずつ移す
var move_k := 0.0

var level := 1
var xp := 0.0
var xp_next := 4.0
var pending_levels := 0
var elapsed := 0.0
var kills := 0
var gem_combo := 0
var gem_combo_t := 0.0

var enemies: Array[Enemy] = []
var bosses: Array[Enemy] = []
var grid := {}
var gems: Array[Gem] = []
var specials: Array[Special] = []
var ebullets: Array[EBullet] = []

var spawn_acc := 0.0
var pack_t := 60.0
var events_done := {}
var final_spawned := false
var final_boss: Enemy = null
var ending := false
var end_t := 0.0
var victory := false
var title_ang := 0.0


func _ready() -> void:
	rng.randomize()
	cam = Camera3D.new()
	cam.fov = 52.0
	cam.near = 0.5
	cam.far = 400.0
	add_child(cam)
	cam.make_current()
	fx = Fx.new()
	add_child(fx)
	weapons = Weapons.new()
	weapons.g = self
	add_child(weapons)
	player = GamePlayer.new(self)
	meshes = GameMeshes.new()
	enemy_sys = GameEnemies.new(self)
	spawner = GameSpawner.new(self)
	pickups = GamePickups.new(self)
	bot_ai = GameBot.new(self)
	player._build_player()
	meshes._build_enemy_meshes()
	pickups._build_gems()
	weapons.reset()
	player._place_player()


# ================================================================ 開始・リセット
func reset() -> void:
	for e in enemies:
		e.node.queue_free()
	enemies.clear()
	bosses.clear()
	grid.clear()
	gems.clear()
	pickups.gem_mm.visible_instance_count = 0
	for s in specials:
		s.node.queue_free()
	specials.clear()
	for b in ebullets:
		b.node.queue_free()
	ebullets.clear()
	fx.clear()
	weapons.reset()
	p_dir = Vector3.UP
	p_fwd = Vector3.FORWARD
	cam_fwd = Vector3.FORWARD
	p_max_hp = 100.0
	p_hp = p_max_hp
	p_iframe = 1.0
	p_blink = 0.0
	p_ghost = 0.0
	move_k = 0.0
	dash_t = 0.0
	dash_cd = 0.0
	level = 1
	xp = 0.0
	xp_next = _xp_for(1)
	pending_levels = 0
	elapsed = 0.0
	kills = 0
	spawn_acc = 0.0
	pack_t = 60.0
	events_done = {}
	final_spawned = false
	final_boss = null
	ending = false
	victory = false
	end_t = 0.0
	sim_speed = 1.0
	slow_t = 0.0
	alive = true
	running = true
	player.p_node.visible = true
	world.set_dawn(0.0)
	player._place_player()


func _xp_for(l: int) -> float:
	var n := float(l - 1)
	return 5.0 + 5.0 * n + 0.55 * n * n


# ================================================================ 共通の計算
func tangent_to(from: Vector3, to: Vector3) -> Vector3:
	var t := to - from * from.dot(to)
	var l := t.length()
	if l < 0.00001:
		return Vector3.ZERO
	return t / l


func rand_tangent(d: Vector3) -> Vector3:
	while true:
		var v := Vector3(rng.randfn(), rng.randfn(), rng.randfn())
		v -= d * v.dot(d)
		if v.length_squared() > 0.001:
			return v.normalized()
	return Vector3.ZERO


func dir_at(from: Vector3, tangent: Vector3, dist: float) -> Vector3:
	var a := dist / R
	return (from * cos(a) + tangent * sin(a)).normalized()


func query(pos: Vector3, radius: float) -> Array[Enemy]:
	var out: Array[Enemy] = []
	var r := radius + 1.1
	var x0 := int(floor((pos.x - r) / CELL))
	var x1 := int(floor((pos.x + r) / CELL))
	var y0 := int(floor((pos.y - r) / CELL))
	var y1 := int(floor((pos.y + r) / CELL))
	var z0 := int(floor((pos.z - r) / CELL))
	var z1 := int(floor((pos.z + r) / CELL))
	for x in range(x0, x1 + 1):
		for y in range(y0, y1 + 1):
			for z in range(z0, z1 + 1):
				var cell: Variant = grid.get(Vector3i(x, y, z))
				if cell == null:
					continue
				for e: Enemy in cell:
					var rr := radius + e.radius
					if not e.dead and e.pos.distance_squared_to(pos) < rr * rr:
						out.append(e)
	for e in bosses:
		var rr := radius + e.radius
		if not e.dead and e.pos.distance_squared_to(pos) < rr * rr:
			out.append(e)
	return out


func nearest_enemies(pos: Vector3, max_dist: float, n: int) -> Array[Enemy]:
	var cands: Array[Enemy] = []
	var md2 := max_dist * max_dist
	for e in enemies:
		if e.dead or e.spawn_t > 0.25:
			continue
		var d2 := e.pos.distance_squared_to(pos) - e.radius
		if d2 < md2:
			e.tmp = d2
			cands.append(e)
	if cands.size() > 1:
		cands.sort_custom(func(a: Enemy, b: Enemy) -> bool: return a.tmp < b.tmp)
	if cands.size() > n:
		cands.resize(n)
	return cands


# ================================================================ 毎フレーム
func _process(delta: float) -> void:
	if main == null:
		return
	if main.is_title():
		_title_camera(delta)
		return
	if not running:
		_update_camera()
		return
	if slow_t > 0.0:
		slow_t -= delta
		if slow_t <= 0.0 and not ending:
			sim_speed = 1.0
	var dt := minf(delta, 0.05) * sim_speed
	if alive and not ending:
		elapsed += dt
	player._update_player(dt)
	if alive and not ending:
		spawner._director(dt)
	enemy_sys._update_enemies(dt)
	if alive:
		weapons.update(dt)
	enemy_sys._update_ebullets(dt)
	pickups._update_gems(dt)
	pickups._update_specials(dt)
	_update_camera()
	if not victory:
		var k := clampf(elapsed / NIGHT_LEN, 0.0, 1.0)
		world.set_dawn(k * k * k * 0.42)
	if ending:
		end_t += delta
		if victory:
			world.set_dawn(lerpf(0.42, 1.0, clampf(end_t / 3.5, 0.0, 1.0)))
		if end_t > (4.2 if victory else 1.8):
			running = false
			main.on_game_over(victory)


func _title_camera(dt: float) -> void:
	title_ang += dt * 0.12
	var d := Vector3(sin(title_ang), 0.42, cos(title_ang)).normalized()
	var cpos := d * 62.0
	var right := Vector3.UP.cross(d).normalized()
	var target := Vector3(0, 9.0, 0) + right * 0.0
	cam.global_transform = Transform3D(Basis.looking_at(target - cpos, Vector3.UP), cpos)
	world.update_frame(d, Vector3.UP, right)
	walk_t += dt * 3.0
	player._pose_player(sin(walk_t) * 0.04, 0.0)


func _update_camera() -> void:
	var ppos := p_dir * R
	var right := cam_fwd.cross(p_dir).normalized()
	var target := ppos + cam_fwd * 1.0
	var cpos := ppos + p_dir * CAM_H - cam_fwd * CAM_B + fx.shake_vec()
	cam.global_transform = Transform3D(Basis.looking_at(target - cpos, p_dir), cpos)
	world.update_frame(p_dir, cam_fwd, right)


func _win() -> void:
	victory = true
	ending = true
	end_t = 0.0
	sim_speed = 0.35
	main.banner("夜が明ける…!", Color("fff1b8"))
	Sfx.music("")
	for e in enemies:
		if not e.dead:
			e.dead = true
			kills += 1
			fx.burst(e.pos + e.dir * 0.5, e.dir, e.color, 8, 7.0, 0.24, 0.5)
			e.node.queue_free()
	for b in ebullets:
		b.node.queue_free()
	ebullets.clear()
	for gm in gems:
		gm.pulled = true
