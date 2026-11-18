class_name GameEnemies
extends RefCounted
## 敵:生成、動き、押し合い、接触、ボスの攻撃、敵の弾、ダメージ、撃破。状態は Game が持つ。

const R := Game.R
const CELL := Game.CELL

var g: Game


func _init(game: Game) -> void:
	g = game


func spawn_enemy(kind: String, dir: Vector3, elite := false) -> Game.Enemy:
	var d: Dictionary = Game.ETYPES[kind]
	var e := Game.Enemy.new()
	e.kind = kind
	e.dir = dir
	e.pos = dir * R
	e.boss = d.get("boss", false)
	e.ranged = d.get("ranged", false)
	var m := g.elapsed / 60.0
	var hp_scale := 1.0 if e.boss else 1.0 + 0.38 * m + 0.1 * m * m
	e.max_hp = float(d.hp) * hp_scale * [0.85, 1.0, 1.25][g.difficulty]
	e.speed = float(d.speed) * g.rng.randf_range(0.92, 1.08) * [0.95, 1.0, 1.1][g.difficulty]
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
	e.phase = g.rng.randf() * TAU
	e.spawn_t = 0.55
	e.strafe = 1.0 if g.rng.randf() < 0.5 else -1.0
	e.shoot_cd = g.rng.randf_range(1.5, 3.0)
	e.face = g.tangent_to(dir, g.p_dir)
	e.node = MeshInstance3D.new()
	e.node.mesh = g.meshes.enemy_meshes[kind]
	e.mat = MeshKit.elite_material() if elite else MeshKit.material()
	e.node.material_override = e.mat
	e.node.transform = Transform3D(Basis.from_scale(Vector3.ONE * 0.01), e.pos)
	g.add_child(e.node)
	g.enemies.append(e)
	if e.boss:
		g.bosses.append(e)
	g.fx.burst(e.pos + dir * 0.2, dir, e.color.darkened(0.2), 6 if not e.boss else 30, 4.0, 0.22 * e.scale, 0.45)
	return e


func _update_enemies(dt: float) -> void:
	# 死んだ敵を取り除く
	var w := 0
	for i in g.enemies.size():
		var e := g.enemies[i]
		if not e.dead:
			g.enemies[w] = e
			w += 1
	g.enemies.resize(w)
	w = 0
	for i in g.bosses.size():
		if not g.bosses[i].dead:
			g.bosses[w] = g.bosses[i]
			w += 1
	g.bosses.resize(w)

	g.grid.clear()
	var ppos := g.p_dir * R
	var decay := maxf(0.0, 1.0 - 7.0 * dt)
	for e in g.enemies:
		if e.moon_cd > 0.0:
			e.moon_cd -= dt
		if e.comet_cd > 0.0:
			e.comet_cd -= dt
		if e.spawn_t > 0.0:
			e.spawn_t -= dt
		else:
			var t := g.tangent_to(e.dir, g.p_dir)
			var mv := t * e.speed
			var dist := e.pos.distance_to(ppos)
			if e.ranged:
				if dist < 6.0:
					mv = -t * e.speed * 0.7
				elif dist < 10.0:
					mv = t.cross(e.dir) * e.speed * 0.6 * e.strafe
				e.shoot_cd -= dt
				if e.shoot_cd <= 0.0 and dist < 14.0 and g.alive:
					e.shoot_cd = g.rng.randf_range(2.6, 3.4)
					_enemy_shoot(e.dir, t, 7.5, e.dmg)
					Sfx.play("enemy_shoot", -10.0, g.rng.randf_range(0.9, 1.1), 120)
			elif e.boss:
				_boss_ai(e, t, dt)
			if not g.alive:
				mv = -mv * 0.4
			if t != Vector3.ZERO:
				e.face = t
			e.dir = (e.dir + (mv + e.kb) * (dt / R)).normalized()
			e.kb *= decay
		e.pos = e.dir * R
		if not e.boss:
			var key := Vector3i(int(floor(e.pos.x / CELL)), int(floor(e.pos.y / CELL)), int(floor(e.pos.z / CELL)))
			var cell: Variant = g.grid.get(key)
			if cell == null:
				g.grid[key] = [e]
			else:
				cell.append(e)
	# 押し合い
	for cell: Array in g.grid.values():
		var n := cell.size()
		if n < 2:
			continue
		for i in n:
			var a: Game.Enemy = cell[i]
			for j in range(i + 1, n):
				var b: Game.Enemy = cell[j]
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
	for e in g.enemies:
		if g.alive and not g.ending and e.spawn_t <= 0.0:
			var rr := e.radius + 0.42
			if e.pos.distance_squared_to(ppos) < rr * rr:
				g.player.hurt_player(e.dmg, e.pos)
		var up := e.dir
		var f := e.face - up * e.face.dot(up)
		if f.length_squared() < 0.0001:
			f = up.cross(Vector3.RIGHT)
		f = f.normalized()
		var right := f.cross(up)
		var hop := absf(sin(e.phase + g.elapsed * e.hop))
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


func _boss_ai(e: Game.Enemy, t: Vector3, dt: float) -> void:
	e.shoot_cd -= dt
	if e.shoot_cd > 0.0 or not g.alive:
		return
	if e.kind == "nushi":
		e.shoot_cd = 3.0 if e.hp > e.max_hp * 0.5 else 2.2
		var n := 12
		var off := g.rng.randf() * TAU
		for i in n:
			_enemy_shoot(e.dir, t.rotated(e.dir, off + TAU * i / n), 6.5, 12.0)
		Sfx.play("enemy_shoot", -4.0, 0.7)
		g.fx.ring(e.dir, 1.0, 5.0, 0.4, Color(1.0, 0.3, 0.5, 0.8))
		if g.rng.randf() < 0.5:
			for i in 6:
				if g.enemies.size() < Game.MAX_ENEMIES:
					spawn_enemy("hashiri", g.dir_at(e.dir, g.rand_tangent(e.dir), g.rng.randf_range(3.0, 5.0)))
	else:
		e.shoot_cd = 5.0
		for i in 4:
			if g.enemies.size() < Game.MAX_ENEMIES:
				spawn_enemy("moya", g.dir_at(e.dir, g.rand_tangent(e.dir), g.rng.randf_range(2.5, 4.0)))


func _enemy_shoot(dir: Vector3, t: Vector3, _speed: float, dmg: float) -> void:
	if t == Vector3.ZERO:
		return
	var b := Game.EBullet.new()
	b.dir = dir
	b.tan = t
	b.dmg = dmg
	b.node = MeshInstance3D.new()
	b.node.mesh = g.meshes.ebullet_mesh
	b.node.material_override = g.meshes.mat_ebullet
	b.node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	b.node.position = dir * (R + 0.7)
	g.add_child(b.node)
	g.ebullets.append(b)


func _update_ebullets(dt: float) -> void:
	var ppos := g.p_dir * R
	var i := 0
	while i < g.ebullets.size():
		var b := g.ebullets[i]
		b.life -= dt
		b.dir = (b.dir + b.tan * (7.0 * dt / R)).normalized()
		b.tan = (b.tan - b.dir * b.tan.dot(b.dir)).normalized()
		b.node.position = b.dir * (R + 0.7)
		var hit := false
		if g.alive and (b.dir * R).distance_squared_to(ppos) < 0.6 * 0.6:
			if g.p_iframe <= 0.0:
				g.player.hurt_player(b.dmg, b.dir * R)
				hit = true
		if hit or b.life <= 0.0:
			g.fx.burst(b.node.position, b.dir, Color(1.0, 0.3, 0.5), 5, 4.0, 0.16, 0.3)
			b.node.queue_free()
			g.ebullets[i] = g.ebullets[g.ebullets.size() - 1]
			g.ebullets.pop_back()
		else:
			i += 1


func damage_enemy(e: Game.Enemy, amount: float, kb_dir := Vector3.ZERO, kb := 0.0) -> void:
	if e.dead:
		return
	e.hp -= amount
	e.flash = 1.0
	e.node.material_override = MeshKit.flash_material()
	g.fx.number(e.pos, e.dir, amount, Color(1.0, 0.95, 0.7) if amount < 20.0 else Color(1.0, 0.75, 0.3), 1.0 if amount < 20.0 else 1.3)
	if kb > 0.0 and not e.boss:
		e.kb += kb_dir * (kb / maxf(e.scale, 1.0))
	if e.hp <= 0.0:
		_kill(e)
	else:
		Sfx.play("hit", -6.0, g.rng.randf_range(0.9, 1.15), 55)


func _kill(e: Game.Enemy) -> void:
	e.dead = true
	g.kills += 1
	var c := e.color
	g.fx.burst(e.pos + e.dir * 0.5, e.dir, c, 12 if not e.boss else 48, 8.0 if not e.boss else 16.0, 0.26 * maxf(e.scale, 1.0), 0.5)
	g.fx.pop(e.pos + e.dir * 0.5, e.radius * 1.5, c.lightened(0.4), 0.16)
	Sfx.play("enemy_die", -6.0, g.rng.randf_range(0.88, 1.18), 40)
	e.node.queue_free()
	if e.boss:
		g.fx.shake(0.8)
		g.fx.ring(e.dir, 1.0, 12.0, 0.7, Color(1.0, 0.9, 0.6, 0.9))
		Sfx.play("boss_die", -2.0)
		g.sim_speed = 0.25
		g.slow_t = 0.5
		for i in 26:
			g.pickups.add_gem(g.dir_at(e.dir, g.rand_tangent(e.dir), g.rng.randf_range(0.3, 4.0)), 5 if i % 3 > 0 else 20)
		g.pickups.add_special("heart", g.dir_at(e.dir, g.rand_tangent(e.dir), 1.5))
		if e == g.final_boss:
			g._win()
		return
	if e.xp > 0:
		g.pickups.add_gem(e.dir, e.xp)
	var roll := g.rng.randf()
	if roll < 0.011 and g.p_hp < g.p_max_hp:
		g.pickups.add_special("heart", e.dir)
	elif roll < 0.016:
		g.pickups.add_special("magnet", e.dir)
	elif roll < 0.020:
		g.pickups.add_special("bomb", e.dir)
