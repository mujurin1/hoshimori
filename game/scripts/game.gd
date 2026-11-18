class_name Game
extends Node3D
## ゲーム本体:プレイヤー、敵、かけら、出現管理、カメラ。

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

var running := false
var alive := false
var bot := false
var difficulty := 1 # 0 やさしい / 1 ふつう / 2 むずかしい
var god := false
var sim_speed := 1.0
var slow_t := 0.0

var p_node: Node3D
var p_body: MeshInstance3D
var foot_l: MeshInstance3D
var foot_r: MeshInstance3D
var p_light: OmniLight3D
var p_dir := Vector3.UP
var p_fwd := Vector3.FORWARD
var cam_fwd := Vector3.FORWARD
var p_hp := 100.0
var p_max_hp := 100.0
var p_iframe := 0.0
var p_blink := 0.0
var p_ghost := 0.0
var p_ghost_on := false
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
var gem_mm: MultiMesh
var specials: Array[Special] = []
var ebullets: Array[EBullet] = []
var enemy_meshes := {}
var special_meshes := {}
var ebullet_mesh: Mesh
var mat_ebullet: ShaderMaterial

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
	_build_player()
	_build_enemy_meshes()
	_build_gems()
	weapons.reset()
	_place_player()


# ================================================================ 構築
func _build_player() -> void:
	p_node = Node3D.new()
	add_child(p_node)
	var mk := MeshKit.new()
	var cream := Color("fff1d0")
	var navy := Color("4457d6")
	mk.sphere(Vector3(0, 0.5, 0), 0.42, cream, Vector3(1, 1.08, 1), 14)
	mk.sphere(Vector3(0, 0.84, 0), 0.34, Color("ef5350"), Vector3(1.12, 0.36, 1.12), 12)
	mk.box(Vector3(0.1, 0.72, 0.36), Vector3(0.16, 0.34, 0.07), Color("ef5350"), Vector3(0.5, 0, 0.2))
	mk.sphere(Vector3(0, 1.12, 0), 0.42, cream, Vector3.ONE, 14)
	mk.sphere(Vector3(0, 1.36, 0.02), 0.5, navy, Vector3(1.05, 0.2, 1.05), 14)
	mk.cone(Vector3(0, 1.72, 0.1), 0.4, 0.8, navy, Vector3(0.28, 0, 0), 12)
	mk.sphere(Vector3(0, 2.1, 0.24), 0.13, Color("ffe066"), Vector3.ONE, 8)
	mk.sphere(Vector3(0.16, 1.14, -0.36), 0.075, Color("23233f"), Vector3(1, 1.3, 0.6), 8)
	mk.sphere(Vector3(-0.16, 1.14, -0.36), 0.075, Color("23233f"), Vector3(1, 1.3, 0.6), 8)
	mk.sphere(Vector3(0.28, 1.02, -0.29), 0.07, Color("ff9aa2"), Vector3(1, 0.7, 0.5), 6)
	mk.sphere(Vector3(-0.28, 1.02, -0.29), 0.07, Color("ff9aa2"), Vector3(1, 0.7, 0.5), 6)
	mk.sphere(Vector3(0.44, 0.55, -0.05), 0.12, cream, Vector3.ONE, 8)
	mk.sphere(Vector3(-0.44, 0.55, -0.05), 0.12, cream, Vector3.ONE, 8)
	p_body = MeshInstance3D.new()
	p_body.mesh = mk.build()
	p_body.material_override = MeshKit.material()
	p_node.add_child(p_body)
	var fk := MeshKit.new()
	fk.sphere(Vector3.ZERO, 0.16, Color("6b4f3a"), Vector3(1, 0.75, 1.45), 8)
	var fm := fk.build()
	foot_l = MeshInstance3D.new()
	foot_l.mesh = fm
	foot_l.material_override = MeshKit.material()
	p_node.add_child(foot_l)
	foot_r = MeshInstance3D.new()
	foot_r.mesh = fm
	foot_r.material_override = MeshKit.material()
	p_node.add_child(foot_r)
	# 網点のシェーダを起動時に 1 度描かせておく。初めて描く瞬間に GPU 向けの準備が走り、最初のダッシュで一瞬固まるため。
	# 体の中に埋めた小さな部品なので見えない。足と同じメッシュを使うのは、頂点の形式が違うと準備が別になるため
	var warm := MeshInstance3D.new()
	warm.mesh = fm
	warm.material_override = MeshKit.ghost_material()
	warm.position = Vector3(0, 0.5, 0)
	warm.scale = Vector3.ONE * 0.05
	warm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p_node.add_child(warm)
	p_light = OmniLight3D.new()
	p_light.light_color = Color(1.0, 0.86, 0.6)
	p_light.light_energy = 2.2
	p_light.omni_range = 11.0
	p_light.omni_attenuation = 1.3
	p_light.position = Vector3(0, 2.6, 0)
	p_node.add_child(p_light)


func _eyes(mk: MeshKit, x: float, y: float, z: float, r: float, col := Color.WHITE) -> void:
	for sx: float in [-1.0, 1.0]:
		mk.sphere(Vector3(x * sx, y, z), r, col, Vector3.ONE, 8)
		mk.sphere(Vector3(x * sx * 0.95, y - r * 0.1, z - r * 0.72), r * 0.5, Color("1b1b2f"), Vector3.ONE, 6)


func _build_enemy_meshes() -> void:
	# モヤ:ぷにっとした影
	var c: Color = ETYPES.moya.color
	var mk := MeshKit.new()
	mk.sphere(Vector3(0, 0.5, 0), 0.6, c, Vector3(1, 0.86, 1), 12)
	mk.cone(Vector3(0, 1.08, 0.05), 0.16, 0.36, c.darkened(0.15), Vector3(0.3, 0, 0), 6)
	_eyes(mk, 0.23, 0.62, -0.47, 0.15)
	enemy_meshes["moya"] = mk.build()
	# ハシリ:小さくて速い
	c = ETYPES.hashiri.color
	mk = MeshKit.new()
	mk.sphere(Vector3(0, 0.4, 0), 0.42, c, Vector3(0.9, 0.85, 1.3), 10)
	mk.cone(Vector3(0.2, 0.82, 0.1), 0.12, 0.42, c.lightened(0.2), Vector3(0.5, 0, -0.3), 5)
	mk.cone(Vector3(-0.2, 0.82, 0.1), 0.12, 0.42, c.lightened(0.2), Vector3(0.5, 0, 0.3), 5)
	mk.cone(Vector3(0, 0.45, 0.62), 0.14, 0.4, c.darkened(0.2), Vector3(1.57, 0, 0), 5)
	_eyes(mk, 0.17, 0.5, -0.43, 0.11, Color("fff3b0"))
	enemy_meshes["hashiri"] = mk.build()
	# ドスン:大きくて硬い
	c = ETYPES.dosun.color
	mk = MeshKit.new()
	mk.sphere(Vector3(0, 0.85, 0), 1.0, c, Vector3(1, 0.88, 1), 14)
	mk.cone(Vector3(0.55, 1.7, 0), 0.22, 0.6, Color("f1e3c8"), Vector3(0, 0, -0.5), 6)
	mk.cone(Vector3(-0.55, 1.7, 0), 0.22, 0.6, Color("f1e3c8"), Vector3(0, 0, 0.5), 6)
	mk.box(Vector3(0, 0.55, -0.92), Vector3(0.7, 0.14, 0.1), Color("1b1b2f"))
	_eyes(mk, 0.36, 1.05, -0.8, 0.2, Color("ffe066"))
	enemy_meshes["dosun"] = mk.build()
	# ツブテ:ひとつ目、弾を撃つ
	c = ETYPES.tsubute.color
	mk = MeshKit.new()
	mk.sphere(Vector3(0, 0.6, 0), 0.55, c, Vector3.ONE, 12)
	for a: float in [-0.5, 0.0, 0.5]:
		mk.cone(Vector3(a * 0.6, 1.2, 0.0), 0.11, 0.36, c.lightened(0.25), Vector3(0, 0, -a), 5)
	mk.sphere(Vector3(0, 0.66, -0.4), 0.27, Color.WHITE, Vector3.ONE, 10)
	mk.sphere(Vector3(0, 0.66, -0.62), 0.13, Color("d00000"), Vector3.ONE, 8)
	enemy_meshes["tsubute"] = mk.build()
	# オオモヤ:中ボス
	c = ETYPES.oomoya.color
	mk = MeshKit.new()
	mk.sphere(Vector3(0, 0.5, 0), 0.6, c, Vector3(1, 0.9, 1), 16)
	for i in 5:
		var a := -0.8 + 0.4 * i
		mk.cone(Vector3(sin(a) * 0.42, 1.02 + cos(a) * 0.08, 0.0), 0.09, 0.3, Color("ffd166"), Vector3(0, 0, -a * 0.7), 5)
	_eyes(mk, 0.24, 0.62, -0.46, 0.16, Color("ffe066"))
	mk.box(Vector3(0, 0.36, -0.57), Vector3(0.34, 0.07, 0.06), Color("1b1b2f"))
	enemy_meshes["oomoya"] = mk.build()
	# ヨルノヌシ:ラスボス
	c = ETYPES.nushi.color
	mk = MeshKit.new()
	mk.sphere(Vector3(0, 0.55, 0), 0.62, c, Vector3(1.05, 0.95, 1.05), 18)
	for i in 8:
		var a := TAU * i / 8.0
		mk.cone(Vector3(sin(a) * 0.5, 0.95, cos(a) * 0.5), 0.1, 0.42, c.darkened(0.35), Vector3(cos(a) * 0.7, 0, -sin(a) * 0.7), 5)
	mk.cone(Vector3(0.3, 1.25, 0), 0.12, 0.5, Color("f1e3c8"), Vector3(0, 0, -0.45), 6)
	mk.cone(Vector3(-0.3, 1.25, 0), 0.12, 0.5, Color("f1e3c8"), Vector3(0, 0, 0.45), 6)
	_eyes(mk, 0.25, 0.66, -0.5, 0.13, Color("ff5d5d"))
	mk.sphere(Vector3(0, 0.9, -0.5), 0.12, Color("ffe066"), Vector3.ONE, 8)
	mk.box(Vector3(0, 0.34, -0.61), Vector3(0.44, 0.08, 0.06), Color("1b1b2f"))
	enemy_meshes["nushi"] = mk.build()

	var eb := SphereMesh.new()
	eb.radius = 0.32
	eb.height = 0.64
	eb.radial_segments = 8
	eb.rings = 4
	ebullet_mesh = eb
	mat_ebullet = MeshKit.new_glow(Color(1.0, 0.25, 0.5), 2.6)

	# 特別なアイテム
	mk = MeshKit.new()
	mk.sphere(Vector3(0.17, 0.12, 0), 0.24, Color("ff4d6d"), Vector3.ONE, 10)
	mk.sphere(Vector3(-0.17, 0.12, 0), 0.24, Color("ff4d6d"), Vector3.ONE, 10)
	mk.cone(Vector3(0, -0.17, 0), 0.36, 0.5, Color("ff4d6d"), Vector3(PI, 0, 0), 10)
	special_meshes["heart"] = mk.build()
	mk = MeshKit.new()
	for i in 5:
		var a := TAU * i / 5.0
		mk.cone(Vector3(sin(a) * 0.3, cos(a) * 0.3, 0), 0.16, 0.42, Color("74c0fc"), Vector3(0, 0, -a), 4)
	mk.sphere(Vector3.ZERO, 0.24, Color("d0ebff"), Vector3(1, 1, 0.6), 8)
	special_meshes["magnet"] = mk.build()
	mk = MeshKit.new()
	mk.sphere(Vector3.ZERO, 0.34, Color("ffa94d"), Vector3.ONE, 10)
	for i in 6:
		var a := TAU * i / 6.0
		mk.cone(Vector3(sin(a) * 0.4, cos(a) * 0.4, 0), 0.1, 0.3, Color("ffe066"), Vector3(0, 0, -a), 4)
	special_meshes["bomb"] = mk.build()


func _build_gems() -> void:
	var m := SphereMesh.new()
	m.radius = 0.2
	m.height = 0.78
	m.radial_segments = 5
	m.rings = 1
	var gmat := ShaderMaterial.new()
	gmat.shader = load("res://shaders/entity.gdshader")
	gmat.set_shader_parameter("glow", 0.9)
	gmat.set_shader_parameter("rim_strength", 1.2)
	m.material = gmat
	gem_mm = MultiMesh.new()
	gem_mm.transform_format = MultiMesh.TRANSFORM_3D
	gem_mm.use_colors = true
	gem_mm.mesh = m
	gem_mm.instance_count = MAX_GEMS
	gem_mm.visible_instance_count = 0
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = gem_mm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.custom_aabb = AABB(Vector3(-R - 2, -R - 2, -R - 2), Vector3(R + 2, R + 2, R + 2) * 2.0)
	add_child(mi)


# ================================================================ 開始・リセット
func reset() -> void:
	for e in enemies:
		e.node.queue_free()
	enemies.clear()
	bosses.clear()
	grid.clear()
	gems.clear()
	gem_mm.visible_instance_count = 0
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
	p_node.visible = true
	world.set_dawn(0.0)
	_place_player()


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
	_update_player(dt)
	if alive and not ending:
		_director(dt)
	_update_enemies(dt)
	if alive:
		weapons.update(dt)
	_update_ebullets(dt)
	_update_gems(dt)
	_update_specials(dt)
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
	_pose_player(sin(walk_t) * 0.04, 0.0)


func _place_player() -> void:
	_pose_player(0.0, 0.0)


func _pose_player(bob: float, lean: float) -> void:
	var r := p_fwd.cross(p_dir).normalized()
	var b := Basis(r, p_dir, -p_fwd)
	if lean > 0.001:
		b = b.rotated(r, -0.16 * lean)
	p_node.transform = Transform3D(b * Basis.from_scale(Vector3(1.0, 1.0, 1.0)), p_dir * (R + bob))
	var sw := sin(walk_t)
	foot_l.position = Vector3(0.2, 0.1 + maxf(0.0, sw) * 0.14, -sw * 0.24 * lean)
	foot_r.position = Vector3(-0.2, 0.1 + maxf(0.0, -sw) * 0.14, sw * 0.24 * lean)


func move_input() -> Vector2:
	if bot:
		return _bot_input()
	var v := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		v.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		v.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		v.y += 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		v.y -= 1.0
	var js := Vector2(Input.get_joy_axis(0, JOY_AXIS_LEFT_X), -Input.get_joy_axis(0, JOY_AXIS_LEFT_Y))
	if js.length() > 0.25:
		v = js
	return v.limit_length(1.0)


var bot_lag := 18
var _bot_n := 0
var _bot_v := Vector2.ZERO


func _bot_input() -> Vector2:
	# 人間っぽく、0.3秒に1回しか判断しない
	_bot_n += 1
	if bot_lag > 1 and _bot_n % bot_lag != 1:
		return _bot_v
	_bot_v = _bot_think()
	return _bot_v


func _bot_think() -> Vector2:
	var ppos := p_dir * R
	var push := Vector3.ZERO
	var close := 1e9
	for e in enemies:
		var d := e.pos.distance_to(ppos) - e.radius
		if d < 9.0:
			var away := -tangent_to(p_dir, e.dir)
			push += away * (1.0 / maxf(d * d, 0.2)) * (3.0 if e.boss else 1.0)
			close = minf(close, d)
	for b in ebullets:
		var d := (b.dir * R).distance_to(ppos)
		if d < 4.0:
			push += -tangent_to(p_dir, b.dir) * (1.0 / maxf(d * d, 0.2))
	if close > 3.0:
		var best := 1e9
		var bd := Vector3.ZERO
		for gm in gems:
			var d := (gm.dir * R).distance_squared_to(ppos)
			if d < best:
				best = d
				bd = gm.dir
		if best < 400.0:
			push += tangent_to(p_dir, bd) * (0.5 if close < 6.0 else 2.0)
	if push.length() < 0.05:
		push = cam_fwd.rotated(p_dir, sin(elapsed * 0.3) * 1.5)
	push = push.normalized()
	if close < 1.2 and dash_cd <= 0.0:
		request_dash()
	var right := cam_fwd.cross(p_dir).normalized()
	return Vector2(push.dot(right), push.dot(cam_fwd))


func request_dash() -> void:
	if not alive or not running or dash_cd > 0.0 or ending:
		return
	var inp := move_input() if not bot else Vector2.ZERO
	var right := cam_fwd.cross(p_dir).normalized()
	var mv := right * inp.x + cam_fwd * inp.y
	dash_dir = mv.normalized() if mv.length() > 0.1 else p_fwd
	dash_t = 0.17
	dash_cd = DASH_CD
	p_iframe = maxf(p_iframe, DASH_IFRAME)
	p_ghost = DASH_IFRAME
	Sfx.play("dash", -6.0, rng.randf_range(0.95, 1.08))
	# 出だしの煙。暗めの色にして、光の粒でなく煙に見せる
	fx.burst(p_dir * (R + 0.4), p_dir, Color(0.34, 0.38, 0.44), 9, 2.6, 0.5, 0.55)


func _update_player(dt: float) -> void:
	p_iframe = maxf(p_iframe - dt, 0.0)
	p_blink = maxf(p_blink - dt, 0.0)
	p_ghost = maxf(p_ghost - dt, 0.0)
	if (p_ghost > 0.0) != p_ghost_on:
		p_ghost_on = p_ghost > 0.0
		var m: Material = MeshKit.ghost_material() if p_ghost_on else MeshKit.material()
		p_body.material_override = m
		foot_l.material_override = m
		foot_r.material_override = m
	dash_cd = maxf(dash_cd - dt, 0.0)
	var inp := Vector2.ZERO
	if alive and not ending:
		inp = move_input()
	var right := cam_fwd.cross(p_dir).normalized()
	var mv := right * inp.x + cam_fwd * inp.y
	var sp := BASE_SPEED * (1.0 + 0.1 * weapons.level("speed"))
	if dash_t > 0.0:
		dash_t -= dt
		mv = dash_dir
		sp *= 3.3
		if rng.randf() < 0.6:
			fx.burst(p_dir * (R + 0.6), -dash_dir, Color(0.75, 0.9, 1.0), 3, 2.0, 0.2, 0.3)
	moving = mv.length() > 0.05
	if moving:
		p_dir = (p_dir + mv * (sp * dt / R)).normalized()
		cam_fwd = (cam_fwd - p_dir * cam_fwd.dot(p_dir)).normalized()
		if dash_t > 0.0:
			dash_dir = (dash_dir - p_dir * dash_dir.dot(p_dir)).normalized()
		var f := mv - p_dir * mv.dot(p_dir)
		if f.length() > 0.01:
			# 向きは角度で回す。2 本の向きを混ぜる方法（lerp）だと、真後ろへ切り返した時に打ち消し合って回らず、前を向いたまま後ろへ歩く
			var turn := p_fwd.signed_angle_to(f.normalized(), p_dir)
			# 1 フレームで回る角度に上限を付ける（毎秒 18 ラジアン）。真後ろへは 0.2 秒弱かけて回る
			var step := clampf(turn * (1.0 - exp(-16.0 * dt)), -TURN_MAX * dt, TURN_MAX * dt)
			p_fwd = p_fwd.rotated(p_dir, step)
		walk_t += dt * 13.0
	p_fwd -= p_dir * p_fwd.dot(p_dir)
	if p_fwd.length_squared() < 0.0001:
		p_fwd = cam_fwd
	p_fwd = p_fwd.normalized()
	move_k = lerpf(move_k, 1.0 if moving else 0.0, 1.0 - exp(-14.0 * dt))
	var bob := lerpf(sin(elapsed * 2.5) * 0.025, absf(sin(walk_t)) * 0.13, move_k)
	_pose_player(bob, move_k)
	# 点滅させるのは体だけ。p_node ごと消すと、子の明かりも消えて周りの地面まで明滅する
	p_node.visible = alive
	var body_on := not (p_blink > 0.0 and fmod(p_blink, BLINK_PERIOD) < BLINK_OFF)
	p_body.visible = body_on
	foot_l.visible = body_on
	foot_r.visible = body_on
	if gem_combo_t > 0.0:
		gem_combo_t -= dt
		if gem_combo_t <= 0.0:
			gem_combo = 0


func _update_camera() -> void:
	var ppos := p_dir * R
	var right := cam_fwd.cross(p_dir).normalized()
	var target := ppos + cam_fwd * 1.0
	var cpos := ppos + p_dir * CAM_H - cam_fwd * CAM_B + fx.shake_vec()
	cam.global_transform = Transform3D(Basis.looking_at(target - cpos, p_dir), cpos)
	world.update_frame(p_dir, cam_fwd, right)


# ================================================================ 敵
func spawn_enemy(kind: String, dir: Vector3, elite := false) -> Enemy:
	var d: Dictionary = ETYPES[kind]
	var e := Enemy.new()
	e.kind = kind
	e.dir = dir
	e.pos = dir * R
	e.boss = d.get("boss", false)
	e.ranged = d.get("ranged", false)
	var m := elapsed / 60.0
	var hp_scale := 1.0 if e.boss else 1.0 + 0.38 * m + 0.1 * m * m
	e.max_hp = float(d.hp) * hp_scale * [0.85, 1.0, 1.25][difficulty]
	e.speed = float(d.speed) * rng.randf_range(0.92, 1.08) * [0.95, 1.0, 1.1][difficulty]
	e.radius = d.radius
	e.dmg = float(d.dmg) * (1.0 if e.boss else 1.0 + 0.02 * m + 0.014 * m * m)
	e.xp = d.xp
	e.hop = d.hop
	e.color = d.color
	e.elite = elite
	if e.boss:
		e.scale = float(d.radius) / 0.6
	if elite:
		e.max_hp *= 5.0
		e.scale = 1.4
		e.radius *= 1.35
		e.xp = e.xp * 5 + 5
	e.hp = e.max_hp
	e.phase = rng.randf() * TAU
	e.spawn_t = 0.55
	e.strafe = 1.0 if rng.randf() < 0.5 else -1.0
	e.shoot_cd = rng.randf_range(1.5, 3.0)
	e.face = tangent_to(dir, p_dir)
	e.node = MeshInstance3D.new()
	e.node.mesh = enemy_meshes[kind]
	e.mat = MeshKit.elite_material() if elite else MeshKit.material()
	e.node.material_override = e.mat
	e.node.transform = Transform3D(Basis.from_scale(Vector3.ONE * 0.01), e.pos)
	add_child(e.node)
	enemies.append(e)
	if e.boss:
		bosses.append(e)
	fx.burst(e.pos + dir * 0.2, dir, e.color.darkened(0.2), 6 if not e.boss else 30, 4.0, 0.22 * e.scale, 0.45)
	return e


func _spawn_dir(dmin: float, dmax: float) -> Vector3:
	return dir_at(p_dir, rand_tangent(p_dir), rng.randf_range(dmin, dmax))


func _director(dt: float) -> void:
	var m := elapsed / 60.0
	var dmul: float = [0.9, 1.0, 1.15][difficulty]
	var rate := (1.5 + 1.2 * m + 0.06 * m * m) * dmul
	if m < 0.2:
		rate = 1.0
	spawn_acc += dt * rate
	while spawn_acc >= 1.0:
		spawn_acc -= 1.0
		if enemies.size() >= MAX_ENEMIES:
			continue
		var roll := rng.randf()
		var kind := "moya"
		if m >= 3.5 and roll < 0.12:
			kind = "tsubute"
		elif m >= 2.0 and roll < 0.12 + minf(0.05 + 0.012 * m, 0.14):
			kind = "dosun"
		elif m >= 1.0 and roll < 0.55:
			kind = "hashiri"
		var elite := m >= 2.0 and rng.randf() < 0.02
		var e := spawn_enemy(kind, _spawn_dir(11.0, 17.0), elite)
		if elite:
			Sfx.play("spawn_elite", -8.0)
			e.spawn_t = 0.8
	# ハシリの群れ
	if m >= 1.0:
		pack_t -= dt
		if pack_t <= 0.0:
			pack_t = rng.randf_range(16.0, 24.0)
			var center := _spawn_dir(14.0, 18.0)
			for i in int(5 + m * 1.5):
				if enemies.size() < MAX_ENEMIES:
					spawn_enemy("hashiri", dir_at(center, rand_tangent(center), rng.randf_range(0.0, 3.0)))
	_event(2.0, "intro")
	_event(180.0, "boss1")
	_event(300.0, "ring")
	_event(360.0, "boss2")
	_event(450.0, "predawn")
	_event(NIGHT_LEN, "final")


func _event(t: float, id: String) -> void:
	if elapsed < t or events_done.has(id):
		return
	events_done[id] = true
	match id:
		"intro":
			main.banner("夜が来た。夜明けまで生きのびろ!", Color("cfe3ff"))
		"boss1":
			main.banner("大きな影が近づいてくる…", Color("ff9ecb"))
			Sfx.play("boss_warn", -4.0)
			spawn_enemy("oomoya", _spawn_dir(16.0, 18.0))
		"ring":
			main.banner("影に囲まれた!", Color("ff9ecb"))
			Sfx.play("spawn_elite", -4.0)
			var t0 := rand_tangent(p_dir)
			for i in 30:
				spawn_enemy("moya", dir_at(p_dir, t0.rotated(p_dir, TAU * i / 30.0), 15.0))
		"boss2":
			main.banner("大きな影がふたつ…!", Color("ff9ecb"))
			Sfx.play("boss_warn", -4.0)
			var t0 := rand_tangent(p_dir)
			for i in 2:
				var b := spawn_enemy("oomoya", dir_at(p_dir, t0 * (1.0 if i == 0 else -1.0), 17.0))
				b.max_hp = 1700.0
				b.hp = b.max_hp
		"predawn":
			main.banner("空が白みはじめた… あと少し!", Color("ffe9a8"))
		"final":
			main.banner("夜の主「ヨルノヌシ」があらわれた!", Color("ff7b7b"))
			Sfx.play("boss_warn", -2.0)
			Sfx.music("boss")
			final_boss = spawn_enemy("nushi", _spawn_dir(17.0, 18.0))
			final_boss.spawn_t = 1.2
			final_spawned = true


func _update_enemies(dt: float) -> void:
	# 死んだ敵を取り除く
	var w := 0
	for i in enemies.size():
		var e := enemies[i]
		if not e.dead:
			enemies[w] = e
			w += 1
	enemies.resize(w)
	w = 0
	for i in bosses.size():
		if not bosses[i].dead:
			bosses[w] = bosses[i]
			w += 1
	bosses.resize(w)

	grid.clear()
	var ppos := p_dir * R
	var decay := maxf(0.0, 1.0 - 7.0 * dt)
	for e in enemies:
		if e.moon_cd > 0.0:
			e.moon_cd -= dt
		if e.comet_cd > 0.0:
			e.comet_cd -= dt
		if e.spawn_t > 0.0:
			e.spawn_t -= dt
		else:
			var t := tangent_to(e.dir, p_dir)
			var mv := t * e.speed
			var dist := e.pos.distance_to(ppos)
			if e.ranged:
				if dist < 6.0:
					mv = -t * e.speed * 0.7
				elif dist < 10.0:
					mv = t.cross(e.dir) * e.speed * 0.6 * e.strafe
				e.shoot_cd -= dt
				if e.shoot_cd <= 0.0 and dist < 14.0 and alive:
					e.shoot_cd = rng.randf_range(2.6, 3.4)
					_enemy_shoot(e.dir, t, 7.5, e.dmg)
					Sfx.play("enemy_shoot", -10.0, rng.randf_range(0.9, 1.1), 120)
			elif e.boss:
				_boss_ai(e, t, dt)
			if not alive:
				mv = -mv * 0.4
			if t != Vector3.ZERO:
				e.face = t
			e.dir = (e.dir + (mv + e.kb) * (dt / R)).normalized()
			e.kb *= decay
		e.pos = e.dir * R
		if not e.boss:
			var key := Vector3i(int(floor(e.pos.x / CELL)), int(floor(e.pos.y / CELL)), int(floor(e.pos.z / CELL)))
			var cell: Variant = grid.get(key)
			if cell == null:
				grid[key] = [e]
			else:
				cell.append(e)
	# 押し合い
	for cell: Array in grid.values():
		var n := cell.size()
		if n < 2:
			continue
		for i in n:
			var a: Enemy = cell[i]
			for j in range(i + 1, n):
				var b: Enemy = cell[j]
				var dv := b.pos - a.pos
				var rr := (a.radius + b.radius) * 0.9
				var d2 := dv.length_squared()
				if d2 < rr * rr and d2 > 0.00001:
					var d := sqrt(d2)
					var push := dv * ((rr - d) / d * 0.5 / R)
					a.dir = (a.dir - push).normalized()
					b.dir = (b.dir + push).normalized()
					a.pos = a.dir * R
					b.pos = b.dir * R
	# 見た目と接触
	for e in enemies:
		if alive and not ending and e.spawn_t <= 0.0:
			var rr := e.radius + 0.42
			if e.pos.distance_squared_to(ppos) < rr * rr:
				hurt_player(e.dmg, e.pos)
		var up := e.dir
		var f := e.face - up * e.face.dot(up)
		if f.length_squared() < 0.0001:
			f = up.cross(Vector3.RIGHT)
		f = f.normalized()
		var right := f.cross(up)
		var hop := absf(sin(e.phase + elapsed * e.hop))
		var s := e.scale
		if e.spawn_t > 0.0:
			s *= clampf(1.0 - e.spawn_t / 0.55, 0.02, 1.0)
		var sy := s * (0.88 + 0.24 * hop)
		var sxz := s * (1.08 - 0.12 * hop)
		e.node.transform = Transform3D(Basis(right * sxz, up * sy, -f * sxz), up * (R + hop * 0.22 * e.scale))
		if e.flash > 0.0:
			e.flash = maxf(e.flash - dt * 11.0, 0.0)
			if e.flash <= 0.0:
				e.node.material_override = e.mat


func _boss_ai(e: Enemy, t: Vector3, dt: float) -> void:
	e.shoot_cd -= dt
	if e.shoot_cd > 0.0 or not alive:
		return
	if e.kind == "nushi":
		e.shoot_cd = 3.0 if e.hp > e.max_hp * 0.5 else 2.2
		var n := 12
		var off := rng.randf() * TAU
		for i in n:
			_enemy_shoot(e.dir, t.rotated(e.dir, off + TAU * i / n), 6.5, 12.0)
		Sfx.play("enemy_shoot", -4.0, 0.7)
		fx.ring(e.dir, 1.0, 5.0, 0.4, Color(1.0, 0.3, 0.5, 0.8))
		if rng.randf() < 0.5:
			for i in 6:
				if enemies.size() < MAX_ENEMIES:
					spawn_enemy("hashiri", dir_at(e.dir, rand_tangent(e.dir), rng.randf_range(3.0, 5.0)))
	else:
		e.shoot_cd = 5.0
		for i in 4:
			if enemies.size() < MAX_ENEMIES:
				spawn_enemy("moya", dir_at(e.dir, rand_tangent(e.dir), rng.randf_range(2.5, 4.0)))


func _enemy_shoot(dir: Vector3, t: Vector3, _speed: float, dmg: float) -> void:
	if t == Vector3.ZERO:
		return
	var b := EBullet.new()
	b.dir = dir
	b.tan = t
	b.dmg = dmg
	b.node = MeshInstance3D.new()
	b.node.mesh = ebullet_mesh
	b.node.material_override = mat_ebullet
	b.node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	b.node.position = dir * (R + 0.7)
	add_child(b.node)
	ebullets.append(b)


func _update_ebullets(dt: float) -> void:
	var ppos := p_dir * R
	var i := 0
	while i < ebullets.size():
		var b := ebullets[i]
		b.life -= dt
		b.dir = (b.dir + b.tan * (7.0 * dt / R)).normalized()
		b.tan = (b.tan - b.dir * b.tan.dot(b.dir)).normalized()
		b.node.position = b.dir * (R + 0.7)
		var hit := false
		if alive and (b.dir * R).distance_squared_to(ppos) < 0.6 * 0.6:
			if p_iframe <= 0.0:
				hurt_player(b.dmg, b.dir * R)
				hit = true
		if hit or b.life <= 0.0:
			fx.burst(b.node.position, b.dir, Color(1.0, 0.3, 0.5), 5, 4.0, 0.16, 0.3)
			b.node.queue_free()
			ebullets[i] = ebullets[ebullets.size() - 1]
			ebullets.pop_back()
		else:
			i += 1


func damage_enemy(e: Enemy, amount: float, kb_dir := Vector3.ZERO, kb := 0.0) -> void:
	if e.dead:
		return
	e.hp -= amount
	e.flash = 1.0
	e.node.material_override = MeshKit.flash_material()
	fx.number(e.pos, e.dir, amount, Color(1.0, 0.95, 0.7) if amount < 20.0 else Color(1.0, 0.75, 0.3), 1.0 if amount < 20.0 else 1.3)
	if kb > 0.0 and not e.boss:
		e.kb += kb_dir * (kb / maxf(e.scale, 1.0))
	if e.hp <= 0.0:
		_kill(e)
	else:
		Sfx.play("hit", -6.0, rng.randf_range(0.9, 1.15), 55)


func _kill(e: Enemy) -> void:
	e.dead = true
	kills += 1
	var c := e.color
	fx.burst(e.pos + e.dir * 0.5, e.dir, c, 12 if not e.boss else 48, 8.0 if not e.boss else 16.0, 0.26 * maxf(e.scale, 1.0), 0.5)
	fx.pop(e.pos + e.dir * 0.5, e.radius * 1.5, c.lightened(0.4), 0.16)
	Sfx.play("enemy_die", -6.0, rng.randf_range(0.88, 1.18), 40)
	e.node.queue_free()
	if e.boss:
		fx.shake(0.8)
		fx.ring(e.dir, 1.0, 12.0, 0.7, Color(1.0, 0.9, 0.6, 0.9))
		Sfx.play("boss_die", -2.0)
		sim_speed = 0.25
		slow_t = 0.5
		for i in 26:
			add_gem(dir_at(e.dir, rand_tangent(e.dir), rng.randf_range(0.3, 4.0)), 5 if i % 3 > 0 else 20)
		add_special("heart", dir_at(e.dir, rand_tangent(e.dir), 1.5))
		if e == final_boss:
			_win()
		return
	if e.xp > 0:
		add_gem(e.dir, e.xp)
	var roll := rng.randf()
	if roll < 0.011 and p_hp < p_max_hp:
		add_special("heart", e.dir)
	elif roll < 0.016:
		add_special("magnet", e.dir)
	elif roll < 0.020:
		add_special("bomb", e.dir)


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


func hurt_player(amount: float, from_pos: Vector3) -> void:
	if p_iframe > 0.0 or not alive or ending:
		return
	p_iframe = 0.9
	p_blink = BLINK_TIME
	fx.shake(0.55)
	Sfx.play("hurt", -3.0)
	main.on_player_hurt()
	if not god:
		p_hp -= amount * [0.55, 1.0, 1.3][difficulty]
	var ppos := p_dir * R
	fx.burst(ppos + p_dir * 0.8, p_dir, Color(1.0, 0.4, 0.4), 14, 7.0, 0.22, 0.4)
	fx.ring(p_dir, 0.5, 4.5, 0.3, Color(1.0, 0.5, 0.5, 0.8))
	for e in query(ppos, 4.5):
		e.kb += tangent_to(p_dir, e.dir) * 16.0
	if from_pos != Vector3.ZERO:
		pass
	if p_hp <= 0.0:
		p_hp = 0.0
		alive = false
		ending = true
		end_t = 0.0
		sim_speed = 0.3
		p_node.visible = false
		fx.burst(ppos + p_dir * 0.8, p_dir, Color(1.0, 0.95, 0.8), 40, 12.0, 0.3, 0.9)
		fx.shake(1.0)
		Sfx.music("")
		Sfx.play("gameover", -3.0)


func heal(amount: float) -> void:
	p_hp = minf(p_hp + amount, p_max_hp)
	fx.burst(p_dir * (R + 1.0), p_dir, Color(0.6, 1.0, 0.7), 12, 4.0, 0.2, 0.6)


# ================================================================ かけら・アイテム
func _gem_color(v: int) -> Color:
	var c := _gem_color_base(v)
	# WebGL では頂点カラー用の補正が個体色にも掛かるので、あらかじめ打ち消しておく
	if world.compat:
		c = Color(pow(c.r, 2.2), pow(c.g, 2.2), pow(c.b, 2.2))
	return c


func _gem_color_base(v: int) -> Color:
	if v >= 20:
		return Color(1.0, 0.25, 0.7)
	if v >= 5:
		return Color(1.0, 0.7, 0.1)
	return Color(0.2, 0.75, 1.0)


func add_gem(dir: Vector3, value: int) -> void:
	if gems.size() >= MAX_GEMS:
		var o := gems[rng.randi_range(0, gems.size() - 1)]
		o.value += value
		o.color = _gem_color(o.value)
		_write_gem(gems.find(o))
		return
	var gm := Gem.new()
	gm.dir = dir
	gm.value = value
	gm.color = _gem_color(value)
	var s := 1.0 if value < 5 else (1.3 if value < 20 else 1.7)
	gm.xf = MeshKit.surface_xf(dir, rng.randf() * TAU, s, R + 0.5)
	gm.xf.basis = gm.xf.basis * Basis.from_euler(Vector3(rng.randf_range(0.25, 0.55), 0.0, rng.randf_range(-0.3, 0.3)))
	gems.append(gm)
	gem_mm.visible_instance_count = gems.size()
	_write_gem(gems.size() - 1)


func _write_gem(i: int) -> void:
	if i < 0 or i >= gems.size():
		return
	gem_mm.set_instance_transform(i, gems[i].xf)
	gem_mm.set_instance_color(i, gems[i].color)


func _update_gems(dt: float) -> void:
	var ppos := p_dir * R
	var mr := 3.0 * (1.0 + 0.4 * weapons.level("magnet"))
	var mr2 := mr * mr
	var i := 0
	while i < gems.size():
		var gm := gems[i]
		var d2 := (gm.dir * R).distance_squared_to(ppos)
		if not gm.pulled and d2 < mr2 and alive:
			gm.pulled = true
		if gm.pulled:
			gm.vel = minf(gm.vel + 60.0 * dt, 32.0)
			var t := tangent_to(gm.dir, p_dir)
			gm.dir = (gm.dir + t * (gm.vel * dt / R)).normalized()
			gm.xf.origin = gm.dir * (R + 0.5)
			if d2 < 1.0 or (gm.dir * R).distance_squared_to(ppos) < 1.0:
				_collect_gem(gm)
				gems[i] = gems[gems.size() - 1]
				gems.pop_back()
				gem_mm.visible_instance_count = gems.size()
				_write_gem(i)
				continue
			gem_mm.set_instance_transform(i, gm.xf)
		i += 1


func _collect_gem(gm: Gem) -> void:
	gem_combo = mini(gem_combo + 1, 14)
	gem_combo_t = 0.7
	Sfx.play("gem", -9.0, 1.0 + gem_combo * 0.045, 30)
	xp += gm.value
	while xp >= xp_next:
		xp -= xp_next
		level += 1
		xp_next = _xp_for(level)
		if alive:
			p_hp = minf(p_hp + [10.0, 6.0, 4.0][difficulty], p_max_hp)
		pending_levels += 1


func add_special(kind: String, dir: Vector3) -> void:
	var s := Special.new()
	s.kind = kind
	s.dir = dir
	s.node = MeshInstance3D.new()
	s.node.mesh = special_meshes[kind]
	s.node.material_override = MeshKit.material()
	add_child(s.node)
	specials.append(s)


func _update_specials(dt: float) -> void:
	var ppos := p_dir * R
	var i := 0
	while i < specials.size():
		var s := specials[i]
		s.age += dt
		s.node.transform = MeshKit.surface_xf(s.dir, s.age * 2.0, 1.25, R + 0.9 + sin(s.age * 3.0) * 0.15)
		if alive and (s.dir * R).distance_squared_to(ppos) < 1.7 * 1.7:
			match s.kind:
				"heart":
					heal(30.0)
					Sfx.play("heal", -4.0)
					main.banner("HPかいふく!", Color("ffb3c1"), 1.2)
				"magnet":
					for gm in gems:
						gm.pulled = true
					Sfx.play("pickup_special", -4.0)
					main.banner("かけらを全部ひきよせた!", Color("a5d8ff"), 1.2)
				"bomb":
					Sfx.play("explosion", -2.0, 0.8)
					Sfx.play("pickup_special", -6.0)
					fx.shake(0.7)
					fx.ring(p_dir, 1.0, 17.0, 0.6, Color(1.0, 0.8, 0.4, 0.9))
					fx.pop(ppos + p_dir, 5.0, Color(1.0, 0.9, 0.6), 0.25)
					var dmg := 60.0 * (1.0 + elapsed / 60.0 * 0.6)
					for e in query(ppos, 17.0):
						if not e.dead:
							damage_enemy(e, dmg if not e.boss else dmg * 2.0, tangent_to(p_dir, e.dir), 10.0)
					main.banner("ほしのばくだん!", Color("ffd8a8"), 1.2)
			s.node.queue_free()
			specials[i] = specials[specials.size() - 1]
			specials.pop_back()
		else:
			i += 1
