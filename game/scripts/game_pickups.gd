class_name GamePickups
extends RefCounted
## 星のかけら(経験値)と特別なアイテム(ハート・磁石・ばくだん)。状態は Game が持つ。

const R := Game.R

var g: Game
var gem_mm: MultiMesh


func _init(game: Game) -> void:
	g = game


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
	gem_mm.instance_count = Game.MAX_GEMS
	gem_mm.visible_instance_count = 0
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = gem_mm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.custom_aabb = AABB(Vector3(-R - 2, -R - 2, -R - 2), Vector3(R + 2, R + 2, R + 2) * 2.0)
	g.add_child(mi)


func _gem_color(v: int) -> Color:
	var c := _gem_color_base(v)
	# WebGL では頂点カラー用の補正が個体色にも掛かるので、あらかじめ打ち消しておく
	if g.world.compat:
		c = Color(pow(c.r, 2.2), pow(c.g, 2.2), pow(c.b, 2.2))
	return c


func _gem_color_base(v: int) -> Color:
	if v >= 20:
		return Color(1.0, 0.25, 0.7)
	if v >= 5:
		return Color(1.0, 0.7, 0.1)
	return Color(0.2, 0.75, 1.0)


func add_gem(dir: Vector3, value: int) -> void:
	if g.gems.size() >= Game.MAX_GEMS:
		var o := g.gems[g.rng.randi_range(0, g.gems.size() - 1)]
		o.value += value
		o.color = _gem_color(o.value)
		_write_gem(g.gems.find(o))
		return
	var gm := Game.Gem.new()
	gm.dir = dir
	gm.value = value
	gm.color = _gem_color(value)
	var s := 1.0 if value < 5 else (1.3 if value < 20 else 1.7)
	gm.xf = MeshKit.surface_xf(dir, g.rng.randf() * TAU, s, R + 0.5)
	gm.xf.basis = gm.xf.basis * Basis.from_euler(Vector3(g.rng.randf_range(0.25, 0.55), 0.0, g.rng.randf_range(-0.3, 0.3)))
	g.gems.append(gm)
	gem_mm.visible_instance_count = g.gems.size()
	_write_gem(g.gems.size() - 1)


func _write_gem(i: int) -> void:
	if i < 0 or i >= g.gems.size():
		return
	gem_mm.set_instance_transform(i, g.gems[i].xf)
	gem_mm.set_instance_color(i, g.gems[i].color)


func _update_gems(dt: float) -> void:
	var ppos := g.p_dir * R
	var mr := 3.0 * (1.0 + 0.4 * g.weapons.level("magnet"))
	var mr2 := mr * mr
	var i := 0
	while i < g.gems.size():
		var gm := g.gems[i]
		var d2 := (gm.dir * R).distance_squared_to(ppos)
		if not gm.pulled and d2 < mr2 and g.alive:
			gm.pulled = true
		if gm.pulled:
			gm.vel = minf(gm.vel + 60.0 * dt, 32.0)
			var t := g.tangent_to(gm.dir, g.p_dir)
			gm.dir = (gm.dir + t * (gm.vel * dt / R)).normalized()
			gm.xf.origin = gm.dir * (R + 0.5)
			if d2 < 1.0 or (gm.dir * R).distance_squared_to(ppos) < 1.0:
				_collect_gem(gm)
				g.gems[i] = g.gems[g.gems.size() - 1]
				g.gems.pop_back()
				gem_mm.visible_instance_count = g.gems.size()
				_write_gem(i)
				continue
			gem_mm.set_instance_transform(i, gm.xf)
		i += 1


func _collect_gem(gm: Game.Gem) -> void:
	g.gem_combo = mini(g.gem_combo + 1, 14)
	g.gem_combo_t = 0.7
	Sfx.play("gem", -9.0, 1.0 + g.gem_combo * 0.045, 30)
	g.xp += gm.value
	while g.xp >= g.xp_next:
		g.xp -= g.xp_next
		g.level += 1
		g.xp_next = g._xp_for(g.level)
		if g.alive:
			g.p_hp = minf(g.p_hp + [10.0, 6.0, 4.0][g.difficulty], g.p_max_hp)
		g.pending_levels += 1


func add_special(kind: String, dir: Vector3) -> void:
	var s := Game.Special.new()
	s.kind = kind
	s.dir = dir
	s.node = MeshInstance3D.new()
	s.node.mesh = g.meshes.special_meshes[kind]
	s.node.material_override = MeshKit.material()
	g.add_child(s.node)
	g.specials.append(s)


func _update_specials(dt: float) -> void:
	var ppos := g.p_dir * R
	var i := 0
	while i < g.specials.size():
		var s := g.specials[i]
		s.age += dt
		s.node.transform = MeshKit.surface_xf(s.dir, s.age * 2.0, 1.25, R + 0.9 + sin(s.age * 3.0) * 0.15)
		if g.alive and (s.dir * R).distance_squared_to(ppos) < 1.7 * 1.7:
			match s.kind:
				"heart":
					g.player.heal(30.0)
					Sfx.play("heal", -4.0)
					g.main.banner("HPかいふく!", Color("ffb3c1"), 1.2)
				"magnet":
					for gm in g.gems:
						gm.pulled = true
					Sfx.play("pickup_special", -4.0)
					g.main.banner("かけらを全部ひきよせた!", Color("a5d8ff"), 1.2)
				"bomb":
					Sfx.play("explosion", -2.0, 0.8)
					Sfx.play("pickup_special", -6.0)
					g.fx.shake(0.7)
					g.fx.ring(g.p_dir, 1.0, 17.0, 0.6, Color(1.0, 0.8, 0.4, 0.9))
					g.fx.pop(ppos + g.p_dir, 5.0, Color(1.0, 0.9, 0.6), 0.25)
					var dmg := 60.0 * (1.0 + g.elapsed / 60.0 * 0.6)
					for e in g.query(ppos, 17.0):
						if not e.dead:
							g.enemy_sys.damage_enemy(e, dmg if not e.boss else dmg * 2.0, g.tangent_to(g.p_dir, e.dir), 10.0)
					g.main.banner("ほしのばくだん!", Color("ffd8a8"), 1.2)
			s.node.queue_free()
			g.specials[i] = g.specials[g.specials.size() - 1]
			g.specials.pop_back()
		else:
			i += 1
