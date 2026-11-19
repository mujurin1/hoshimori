extends Node
## OGP 用の 1 枚を描く。ゲームの World / Game をそのまま建て、配置だけ ogp_scene.json から読んで固定の構図を作る。
## 方角 az は度。主人公（星のてっぺん）から見て 0 = +X、90 = +Z、180 = -X、270 = -Z。dist は地表に沿った距離

const R := Game.R

var cfg: Dictionary
var vp: SubViewport
var world: World
var game: Game
var frame := 0
var out_path := ""


func _ready() -> void:
	cfg = JSON.parse_string(FileAccess.get_file_as_string("res://ogp_scene.json"))
	out_path = ProjectSettings.globalize_path("res://").path_join("../render.png")
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_path = a.substr(6)
	vp = SubViewport.new()
	vp.size = Vector2i(int(cfg.width), int(cfg.height))
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	world = World.new()
	vp.add_child(world)
	game = Game.new()
	game.world = world
	vp.add_child(game)
	game.rng.seed = int(cfg.seed)
	game.fx.rng.seed = int(cfg.seed)
	_build()


func _tan(az_deg: float) -> Vector3:
	var a := deg_to_rad(az_deg)
	return Vector3(cos(a), 0.0, sin(a))


func _dir(az_deg: float, dist: float) -> Vector3:
	return game.dir_at(Vector3.UP, _tan(az_deg), dist)


func _v3(a: Array) -> Vector3:
	return Vector3(a[0], a[1], a[2])


func _build() -> void:
	# 飾り（木・花・水晶）の当たり場所を選ぶために、星ごと回す
	var wr: Array = cfg.world_rot
	world.basis = Basis.from_euler(Vector3(deg_to_rad(wr[0]), deg_to_rad(wr[1]), deg_to_rad(wr[2])))

	var c: Dictionary = cfg.camera
	var cpos := _v3(c.pos) + Vector3.UP * R
	var ctgt := _v3(c.target) + Vector3.UP * R
	var cb := Basis.looking_at(ctgt - cpos, Vector3.UP)
	cb = cb.rotated(cb.z, deg_to_rad(c.roll))
	game.cam.fov = c.fov
	game.cam.global_transform = Transform3D(cb, cpos)
	var fwd := -cb.z
	var fwd_flat := (fwd - Vector3.UP * fwd.y).normalized()
	world.set_dawn(cfg.dawn)
	world.update_frame(Vector3.UP, fwd_flat, cb.x)
	var s: Dictionary = cfg.sky
	world.sky_mat.set_shader_parameter("glow_dir", _v3(s.glow_dir).normalized())
	world.sky_mat.set_shader_parameter("glow_amount", s.glow_amount)
	world.sky_mat.set_shader_parameter("star_amount", s.star_amount)
	world.sky_mat.set_shader_parameter("glow_color", Color(s.glow_color[0], s.glow_color[1], s.glow_color[2]))
	world.sky_mat.set_shader_parameter("sky_rot", Basis.from_euler(Vector3(deg_to_rad(s.rot[0]), deg_to_rad(s.rot[1]), deg_to_rad(s.rot[2]))))
	var l: Dictionary = cfg.light
	world.light.global_transform = Transform3D(Basis.looking_at(_v3(l.dir).normalized(), Vector3.UP), Vector3.ZERO)
	world.light.light_energy *= l.energy_mul
	world.env.ambient_light_energy *= l.ambient_mul

	var h: Dictionary = cfg.hero
	game.p_dir = Vector3.UP
	game.p_fwd = _tan(h.face_az)
	game.walk_t = h.walk_t
	game.player._pose_player(h.bob, h.lean)
	game.player.p_light.light_energy *= h.light_mul

	for e: Dictionary in cfg.enemies:
		_enemy(e)
	for gm: Dictionary in cfg.gems:
		game.pickups.add_gem(_dir(gm.az, gm.dist), int(gm.value))
	for m: Dictionary in cfg.moons:
		_moon(m)
	for b: Dictionary in cfg.bolts:
		_bolt(b)
	for sp: Dictionary in cfg.specials:
		var n := MeshInstance3D.new()
		n.mesh = game.meshes.special_meshes[sp.kind]
		n.material_override = MeshKit.material()
		n.transform = MeshKit.surface_xf(_dir(sp.az, sp.dist), deg_to_rad(sp.yaw), 1.25, R + 1.0)
		game.add_child(n)


func _enemy(e: Dictionary) -> void:
	var up := _dir(e.az, e.dist)
	var f := game.tangent_to(up, Vector3.UP).rotated(up, deg_to_rad(e.get("yaw", 0.0)))
	var right := f.cross(up)
	var sc: float = float(Game.ETYPES[e.kind].radius) / 0.6 if Game.ETYPES[e.kind].get("boss", false) else 1.0
	sc *= e.get("scale", 1.0)
	var hop: float = e.get("hop", 0.0)
	var sy := sc * (0.88 + 0.24 * hop)
	var sxz := sc * (1.08 - 0.12 * hop)
	var n := MeshInstance3D.new()
	n.mesh = game.meshes.enemy_meshes[e.kind]
	n.material_override = MeshKit.flash_material() if e.get("flash", false) else (MeshKit.elite_material() if e.get("elite", false) else MeshKit.material())
	n.transform = Transform3D(Basis(right * sxz, up * sy, -f * sxz), up * (R + hop * 0.22 * sc))
	game.add_child(n)


func _moon(m: Dictionary) -> void:
	var d := _dir(m.az, m.dist)
	var n := MeshInstance3D.new()
	n.mesh = game.weapons.moon_mesh
	n.material_override = MeshKit.material()
	n.transform = Transform3D(Basis.from_euler(Vector3(0.3, deg_to_rad(m.spin), 0.2)), d * (R + 0.8))
	game.add_child(n)


func _bolt(b: Dictionary) -> void:
	var d := _dir(b.az, b.dist)
	var t := -game.tangent_to(d, Vector3.UP)
	var right := t.cross(d)
	var n := MeshInstance3D.new()
	n.mesh = game.weapons.bolt_mesh
	n.material_override = game.weapons.mat_bolt
	n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.transform = Transform3D(Basis(right * 0.3, d * 0.3, -t * 0.85), d * (R + 0.75))
	game.add_child(n)


func _process(_dt: float) -> void:
	frame += 1
	if frame == int(cfg.burst_frame):
		for b: Dictionary in cfg.bursts:
			var d := _dir(b.az, b.dist)
			var col: Array = b.color
			game.fx.burst(d * (R + b.height), d, Color(col[0], col[1], col[2]), int(b.amount), b.speed, b.size, b.life)
	if frame == int(cfg.shot_frame):
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute(out_path.get_base_dir())
		vp.get_texture().get_image().save_png(out_path)
		print("saved ", vp.size)
		get_tree().quit()
	# 撮影に失敗しても必ず終わらせる
	if frame > 600:
		get_tree().quit(1)
