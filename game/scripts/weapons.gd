class_name Weapons
extends Node3D
## 自動で発動する星の魔法と、レベルアップの選択肢。

const R := 20.0

const DEFS := {
	"bolt": {"name": "スターショット", "icon": "星", "color": Color("ffe066"), "max": 6, "desc": [
		"いちばん近い敵に星の弾を撃つ", "ダメージアップ", "弾が2発になる",
		"敵を1体つらぬく", "弾が3発になる", "弾が4発、連射もはやくなる"]},
	"moon": {"name": "ツキノワ", "icon": "月", "color": Color("cfd8ff"), "max": 6, "desc": [
		"小さな月が2つ、まわりを回って敵をはじく", "月が3つになる", "ダメージアップ、回転がはやくなる",
		"月が4つになる", "ダメージアップ、軌道が広がる", "月が5つになる"]},
	"pulse": {"name": "ホシナミ", "icon": "波", "color": Color("7ae7c7"), "max": 6, "desc": [
		"まわりに星の波を放ち、敵を押しかえす", "威力と範囲アップ", "波の間隔がみじかくなる",
		"威力と範囲アップ", "波の間隔がみじかくなる", "威力・範囲ともに最大"]},
	"zap": {"name": "イナズマ", "icon": "雷", "color": Color("8ecbff"), "max": 6, "desc": [
		"近くの敵に雷が落ち、となりの敵へ連鎖する", "連鎖が増え、ダメージアップ", "雷の間隔がみじかくなる",
		"連鎖が増え、ダメージアップ", "雷の間隔がみじかくなる", "連鎖・威力ともに最大"]},
	"comet": {"name": "ホウキボシ", "icon": "彗", "color": Color("9bf6ff"), "max": 6, "desc": [
		"彗星が星をぐるりと一周して、敵をなぎ払う", "ダメージアップ、彗星が大きくなる", "彗星が2つになる",
		"ダメージアップ、彗星が大きくなる", "彗星が3つになる", "ダメージ大幅アップ"]},
	"meteor": {"name": "ナガレボシ", "icon": "流", "color": Color("ffa94d"), "max": 6, "desc": [
		"敵の群れに流れ星が落ちて爆発する", "ダメージと爆発範囲アップ", "流れ星が2つになる",
		"ダメージと爆発範囲アップ", "流れ星が3つになる", "流れ星が4つ、威力も最大"]},
	"speed": {"name": "かぜのくつ", "icon": "速", "color": Color("b9fbc0"), "max": 5, "passive": true, "desc": ["移動速度 +10%"]},
	"magnet": {"name": "ほしよせ", "icon": "寄", "color": Color("a0c4ff"), "max": 5, "passive": true, "desc": ["星のかけらを引きよせる範囲 +40%"]},
	"heart": {"name": "いのちの実", "icon": "命", "color": Color("ff8fa3"), "max": 5, "passive": true, "desc": ["最大HP +25、HPも25回復"]},
	"haste": {"name": "せっかち時計", "icon": "早", "color": Color("ffd6a5"), "max": 5, "passive": true, "desc": ["すべての攻撃の間隔 -8%"]},
	"power": {"name": "ちからの石", "icon": "力", "color": Color("ffadad"), "max": 5, "passive": true, "desc": ["すべてのダメージ +15%"]},
	"feast": {"name": "星のごちそう", "icon": "食", "color": Color("fdffb6"), "max": 99999, "passive": true, "desc": ["HPを40回復する"]},
}
const ORDER := ["bolt", "moon", "pulse", "zap", "comet", "meteor", "speed", "magnet", "heart", "haste", "power"]

const BOLT_COUNT := [1, 1, 2, 2, 3, 4]
const BOLT_DMG := [6.0, 9.0, 9.0, 12.0, 12.0, 16.0]
const BOLT_PIERCE := [0, 0, 0, 1, 1, 2]
const BOLT_CD := [0.7, 0.65, 0.65, 0.6, 0.55, 0.42]
const MOON_COUNT := [2, 3, 3, 4, 4, 5]
const MOON_DMG := [6.0, 7.0, 9.5, 10.5, 13.5, 17.0]
const MOON_RAD := [3.0, 3.0, 3.2, 3.2, 3.7, 3.9]
const MOON_SPD := [2.6, 2.6, 3.1, 3.1, 3.4, 3.6]
const PULSE_CD := [4.4, 4.4, 3.7, 3.7, 3.0, 2.7]
const PULSE_DMG := [8.0, 12.0, 13.0, 18.0, 19.0, 28.0]
const PULSE_RAD := [5.5, 6.3, 6.3, 7.2, 7.2, 8.5]
const ZAP_CD := [2.3, 2.3, 1.9, 1.9, 1.5, 1.3]
const ZAP_DMG := [12.0, 16.0, 18.0, 23.0, 25.0, 34.0]
const ZAP_CHAIN := [3, 4, 4, 5, 6, 8]
const COMET_COUNT := [1, 1, 2, 2, 3, 3]
const COMET_DMG := [12.0, 16.0, 16.0, 21.0, 21.0, 28.0]
const COMET_RAD := [1.6, 1.9, 1.9, 2.2, 2.2, 2.4]
const METEOR_CD := [3.4, 3.2, 3.0, 2.8, 2.6, 2.2]
const METEOR_COUNT := [1, 1, 2, 2, 3, 4]
const METEOR_DMG := [14.0, 18.0, 18.0, 24.0, 24.0, 32.0]
const METEOR_RAD := [2.4, 2.7, 2.7, 3.0, 3.0, 3.3]


class Bolt:
	var node: MeshInstance3D
	var dir: Vector3
	var tan: Vector3
	var life: float
	var dmg: float
	var pierce: int
	var hit: Array = []


class Comet:
	var node: MeshInstance3D
	var dir: Vector3
	var axis: Vector3


class Strike:
	var node: MeshInstance3D
	var dir: Vector3
	var from: Vector3
	var t: float
	var dur: float
	var dmg: float
	var radius: float


var g: Game
var lv := {}
var cd := {}
var dealt := {}
var bolts: Array[Bolt] = []
var bolt_pool: Array[MeshInstance3D] = []
var moons: Array[MeshInstance3D] = []
var moon_ang := 0.0
var comets: Array[Comet] = []
var strikes: Array[Strike] = []
var bolt_mesh: Mesh
var moon_mesh: Mesh
var comet_mesh: Mesh
var meteor_mesh: Mesh
var mat_bolt: ShaderMaterial
var mat_comet: ShaderMaterial
var mat_meteor: ShaderMaterial
var trail_mesh: SphereMesh
var trail_curve: Curve


func _ready() -> void:
	var s := SphereMesh.new()
	s.radius = 0.5
	s.height = 1.0
	s.radial_segments = 8
	s.rings = 4
	bolt_mesh = s
	mat_bolt = MeshKit.new_glow(Color(1.0, 0.9, 0.45), 2.6)
	var mk := MeshKit.new()
	mk.sphere(Vector3.ZERO, 0.42, Color("e8ecff"), Vector3.ONE, 10)
	mk.sphere(Vector3(0.15, 0.12, -0.3), 0.12, Color("b8c0e8"), Vector3(1, 1, 0.5), 6)
	mk.sphere(Vector3(-0.2, -0.1, -0.28), 0.09, Color("b8c0e8"), Vector3(1, 1, 0.5), 6)
	mk.sphere(Vector3(0.05, -0.2, 0.3), 0.1, Color("b8c0e8"), Vector3(1, 1, 0.5), 6)
	moon_mesh = mk.build()
	var cs := SphereMesh.new()
	cs.radius = 1.0
	cs.height = 2.0
	cs.radial_segments = 12
	cs.rings = 6
	comet_mesh = cs
	meteor_mesh = cs
	mat_comet = MeshKit.new_glow(Color(0.5, 0.85, 1.0), 1.7)
	mat_meteor = MeshKit.new_glow(Color(1.0, 0.6, 0.25), 2.8)
	trail_mesh = SphereMesh.new()
	trail_mesh.radius = 0.5
	trail_mesh.height = 1.0
	trail_mesh.radial_segments = 6
	trail_mesh.rings = 3
	trail_mesh.material = MeshKit.glow_material()
	trail_curve = Curve.new()
	trail_curve.add_point(Vector2(0.0, 1.0))
	trail_curve.add_point(Vector2(1.0, 0.0))


func reset() -> void:
	for b in bolts:
		b.node.visible = false
		bolt_pool.append(b.node)
	bolts.clear()
	for m in moons:
		m.queue_free()
	moons.clear()
	for c in comets:
		c.node.queue_free()
	comets.clear()
	for s in strikes:
		s.node.queue_free()
	strikes.clear()
	lv = {"bolt": 1}
	cd = {"bolt": 0.5, "pulse": 2.0, "zap": 1.0, "meteor": 1.5}
	dealt = {}
	moon_ang = 0.0


func level(id: String) -> int:
	return int(lv.get(id, 0))


func power() -> float:
	return 1.0 + 0.15 * level("power")


func haste() -> float:
	return pow(0.92, level("haste"))


func card_info(id: String) -> Dictionary:
	var d: Dictionary = DEFS[id]
	var cur := level(id)
	var descs: Array = d.desc
	var passive: bool = d.get("passive", false)
	return {
		"id": id, "name": d.name, "icon": d.icon, "color": d.color,
		"from": cur, "to": cur + 1, "max": d.max, "passive": passive,
		"desc": descs[mini(cur, descs.size() - 1)], "is_new": cur == 0 and id != "feast",
	}


func roll_choices(n: int) -> Array[String]:
	var pool: Array[String] = []
	for id: String in ORDER:
		if level(id) < int(DEFS[id].max):
			pool.append(id)
	for i in range(pool.size() - 1, 0, -1):
		var j := g.rng.randi_range(0, i)
		var tmp := pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	var res: Array[String] = pool.slice(0, n)
	if res.is_empty():
		res.append("feast")
	return res


func apply(id: String) -> void:
	lv[id] = level(id) + 1
	match id:
		"heart":
			g.p_max_hp += 25.0
			g.heal(25.0)
		"feast":
			g.heal(40.0)
		"comet":
			_sync_comets()


func owned() -> Array[String]:
	var res: Array[String] = []
	for id: String in ORDER:
		if level(id) > 0:
			res.append(id)
	return res


func _hit(e: Game.Enemy, src: String, amount: float, kb_dir := Vector3.ZERO, kb := 0.0) -> void:
	var a := amount * power()
	dealt[src] = float(dealt.get(src, 0.0)) + minf(a, e.hp)
	g.damage_enemy(e, a, kb_dir, kb)


func update(dt: float) -> void:
	_bolt(dt)
	_moon(dt)
	_pulse(dt)
	_zap(dt)
	_comet(dt)
	_meteor(dt)


# ---------------------------------------------------------------- スターショット
func _bolt(dt: float) -> void:
	var l := level("bolt")
	if l > 0:
		cd.bolt -= dt
		if cd.bolt <= 0.0:
			var n: int = BOLT_COUNT[l - 1]
			var targets := g.nearest_enemies(g.p_dir * R, 15.0, n)
			if targets.is_empty():
				cd.bolt = 0.08
			else:
				cd.bolt = BOLT_CD[l - 1] * haste()
				for i in n:
					var e := targets[i % targets.size()]
					var t := g.tangent_to(g.p_dir, e.dir)
					if t == Vector3.ZERO:
						t = g.p_fwd
					if i >= targets.size():
						var k := i - targets.size() + 1
						t = t.rotated(g.p_dir, 0.22 * k * (1.0 if k % 2 == 0 else -1.0))
					_fire_bolt(t, BOLT_DMG[l - 1], BOLT_PIERCE[l - 1])
				Sfx.play("shoot", -11.0, g.rng.randf_range(0.94, 1.08), 60)
	var i := 0
	while i < bolts.size():
		var b := bolts[i]
		b.life -= dt
		b.dir = (b.dir + b.tan * (24.0 * dt / R)).normalized()
		b.tan = (b.tan - b.dir * b.tan.dot(b.dir)).normalized()
		var done := b.life <= 0.0
		if not done:
			for e in g.query(b.dir * R, 0.4):
				if e.dead or b.hit.has(e):
					continue
				b.hit.append(e)
				_hit(e, "bolt", b.dmg, b.tan, 3.0)
				g.fx.burst(e.pos + e.dir * 0.6, -b.tan, Color(1.0, 0.9, 0.5), 5, 5.0, 0.16, 0.3)
				if b.pierce <= 0:
					done = true
					break
				b.pierce -= 1
		if done:
			b.node.visible = false
			bolt_pool.append(b.node)
			bolts[i] = bolts[bolts.size() - 1]
			bolts.pop_back()
		else:
			var right := b.tan.cross(b.dir)
			b.node.transform = Transform3D(Basis(right * 0.3, b.dir * 0.3, -b.tan * 0.85), b.dir * (R + 0.75))
			i += 1


func _fire_bolt(t: Vector3, dmg: float, pierce: int) -> void:
	var b := Bolt.new()
	if bolt_pool.is_empty():
		b.node = MeshInstance3D.new()
		b.node.mesh = bolt_mesh
		b.node.material_override = mat_bolt
		b.node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(b.node)
	else:
		b.node = bolt_pool.pop_back()
	b.dir = g.p_dir
	b.tan = t
	b.life = 0.75
	b.dmg = dmg
	b.pierce = pierce
	var right := t.cross(b.dir)
	b.node.transform = Transform3D(Basis(right * 0.3, b.dir * 0.3, -t * 0.85), b.dir * (R + 0.75))
	b.node.visible = true
	bolts.append(b)


# ---------------------------------------------------------------- ツキノワ
func _moon(dt: float) -> void:
	var l := level("moon")
	if l <= 0:
		return
	var n: int = MOON_COUNT[l - 1]
	while moons.size() < n:
		var m := MeshInstance3D.new()
		m.mesh = moon_mesh
		m.material_override = MeshKit.material()
		add_child(m)
		moons.append(m)
	moon_ang += MOON_SPD[l - 1] * dt
	var rad: float = MOON_RAD[l - 1]
	var right := g.cam_fwd.cross(g.p_dir).normalized()
	for i in n:
		var a := moon_ang + TAU * i / n
		var off := (g.cam_fwd * cos(a) + right * sin(a)) * rad
		var d := (g.p_dir + off / R).normalized()
		var m := moons[i]
		m.transform = Transform3D(Basis(right, d, right.cross(d)).orthonormalized().rotated(d, moon_ang * 1.5), d * (R + 0.8))
		for e in g.query(d * R, 0.6):
			if e.dead or e.moon_cd > 0.0:
				continue
			e.moon_cd = 0.4
			_hit(e, "moon", MOON_DMG[l - 1], g.tangent_to(g.p_dir, e.dir), 7.0)
			g.fx.burst(e.pos + e.dir * 0.6, e.dir, Color(0.85, 0.9, 1.0), 5, 5.0, 0.16, 0.3)
			Sfx.play("moon_hit", -4.0, g.rng.randf_range(0.9, 1.15), 70)


# ---------------------------------------------------------------- ホシナミ
func _pulse(dt: float) -> void:
	var l := level("pulse")
	if l <= 0:
		return
	cd.pulse -= dt
	if cd.pulse > 0.0:
		return
	var rad: float = PULSE_RAD[l - 1]
	var hits := g.query(g.p_dir * R, rad)
	if hits.is_empty():
		cd.pulse = 0.15
		return
	cd.pulse = PULSE_CD[l - 1] * haste()
	for e in hits:
		if not e.dead:
			_hit(e, "pulse", PULSE_DMG[l - 1], g.tangent_to(g.p_dir, e.dir), 13.0)
	g.fx.ring(g.p_dir, 0.6, rad, 0.38, Color(0.5, 1.0, 0.85, 0.9))
	g.fx.ring(g.p_dir, 0.2, rad * 0.75, 0.42, Color(0.8, 1.0, 0.95, 0.5))
	g.fx.shake(0.12)
	Sfx.play("shockwave", -6.0, g.rng.randf_range(0.95, 1.05))


# ---------------------------------------------------------------- イナズマ
func _zap(dt: float) -> void:
	var l := level("zap")
	if l <= 0:
		return
	cd.zap -= dt
	if cd.zap > 0.0:
		return
	var cands := g.query(g.p_dir * R, 11.0)
	if cands.is_empty():
		cd.zap = 0.15
		return
	cd.zap = ZAP_CD[l - 1] * haste()
	var cur: Game.Enemy = cands[g.rng.randi_range(0, cands.size() - 1)]
	var from := g.p_dir * (R + 1.6)
	var visited: Array = []
	var chains: int = ZAP_CHAIN[l - 1]
	for k in chains + 1:
		visited.append(cur)
		var hp := cur.pos + cur.dir * 0.7
		g.fx.zap(from, hp)
		g.fx.pop(hp, 0.9, Color(0.7, 0.9, 1.0), 0.15)
		_hit(cur, "zap", ZAP_DMG[l - 1])
		from = hp
		var best: Game.Enemy = null
		var bd := 1e9
		for e in g.query(cur.pos, 6.5):
			if e.dead or visited.has(e):
				continue
			var d2 := e.pos.distance_squared_to(cur.pos)
			if d2 < bd:
				bd = d2
				best = e
		if best == null:
			break
		cur = best
	Sfx.play("lightning", -7.0, g.rng.randf_range(0.92, 1.1))


# ---------------------------------------------------------------- ホウキボシ
func _sync_comets() -> void:
	var l := level("comet")
	if l <= 0:
		return
	var n: int = COMET_COUNT[l - 1]
	while comets.size() < n:
		var c := Comet.new()
		c.node = MeshInstance3D.new()
		c.node.mesh = comet_mesh
		c.node.material_override = mat_comet
		c.node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var tr := CPUParticles3D.new()
		tr.mesh = trail_mesh
		tr.amount = 40
		tr.lifetime = 0.55
		tr.local_coords = false
		tr.spread = 180.0
		tr.gravity = Vector3.ZERO
		tr.initial_velocity_min = 0.2
		tr.initial_velocity_max = 1.2
		tr.scale_amount_min = 0.25
		tr.scale_amount_max = 0.55
		tr.scale_amount_curve = trail_curve
		tr.color = Color(0.3, 0.55, 0.75)
		tr.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		c.node.add_child(tr)
		add_child(c.node)
		c.dir = g.p_dir
		c.axis = g.p_dir.cross(g.cam_fwd.rotated(g.p_dir, comets.size() * 2.1 + 0.5)).normalized()
		comets.append(c)


func _comet(dt: float) -> void:
	var l := level("comet")
	if l <= 0:
		return
	var rad: float = COMET_RAD[l - 1]
	for c in comets:
		c.dir = c.dir.rotated(c.axis, 1.25 * dt).normalized()
		var want := c.dir.cross(g.p_dir)
		if want.length() > 0.3:
			want = want.normalized()
			if want.dot(c.axis) < 0.0:
				want = -want
			c.axis = c.axis.slerp(want, minf(1.0, 2.5 * dt))
		c.axis = (c.axis - c.dir * c.axis.dot(c.dir)).normalized()
		var vis := rad * 0.34
		c.node.transform = Transform3D(Basis.from_scale(Vector3(vis, vis, vis)), c.dir * (R + 1.0))
		var travel := c.axis.cross(c.dir)
		for e in g.query(c.dir * R, rad):
			if e.dead or e.comet_cd > 0.0:
				continue
			e.comet_cd = 0.5
			_hit(e, "comet", COMET_DMG[l - 1], travel, 9.0)
			g.fx.burst(e.pos + e.dir * 0.6, e.dir, Color(0.6, 0.95, 1.0), 6, 7.0, 0.2, 0.35)
			Sfx.play("comet", -9.0, g.rng.randf_range(0.95, 1.08), 300)


# ---------------------------------------------------------------- ナガレボシ
func _meteor(dt: float) -> void:
	var l := level("meteor")
	if l > 0:
		cd.meteor -= dt
		if cd.meteor <= 0.0:
			var cands := g.query(g.p_dir * R, 12.0)
			if cands.is_empty():
				cd.meteor = 0.2
			else:
				cd.meteor = METEOR_CD[l - 1] * haste()
				var n: int = METEOR_COUNT[l - 1]
				for i in n:
					var e: Game.Enemy = cands[g.rng.randi_range(0, cands.size() - 1)]
					var s := Strike.new()
					s.dir = e.dir
					s.t = -0.12 * i
					s.dur = 0.5
					s.dmg = METEOR_DMG[l - 1]
					s.radius = METEOR_RAD[l - 1]
					var right := g.cam_fwd.cross(g.p_dir).normalized()
					s.from = e.dir * (R + 16.0) + right * 7.0 + g.cam_fwd * 3.0
					s.node = MeshInstance3D.new()
					s.node.mesh = meteor_mesh
					s.node.material_override = mat_meteor
					s.node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
					s.node.visible = false
					add_child(s.node)
					strikes.append(s)
	var i := 0
	while i < strikes.size():
		var s := strikes[i]
		var before := s.t
		s.t += dt
		if before < 0.0 and s.t >= 0.0:
			g.fx.ring(s.dir, s.radius, s.radius * 0.85, s.dur, Color(1.0, 0.6, 0.2, 0.7))
		if s.t >= s.dur:
			var p := s.dir * R
			for e in g.query(p, s.radius):
				if not e.dead:
					_hit(e, "meteor", s.dmg, g.tangent_to(s.dir, e.dir), 7.0)
			g.fx.burst(p + s.dir * 0.4, s.dir, Color(1.0, 0.65, 0.25), 26, 11.0, 0.3, 0.5)
			g.fx.pop(p + s.dir * 0.5, s.radius * 0.9, Color(1.0, 0.8, 0.5), 0.2)
			g.fx.ring(s.dir, 0.4, s.radius * 1.25, 0.3, Color(1.0, 0.85, 0.5, 0.9))
			g.fx.shake(0.22)
			Sfx.play("explosion", -6.0, g.rng.randf_range(0.9, 1.1), 90)
			s.node.queue_free()
			strikes[i] = strikes[strikes.size() - 1]
			strikes.pop_back()
			continue
		if s.t >= 0.0:
			var k := s.t / s.dur
			s.node.visible = true
			s.node.position = s.from.lerp(s.dir * (R + 0.4), k * k)
			s.node.scale = Vector3.ONE * 0.55
		i += 1
