class_name World
extends Node3D
## 惑星・空・光。ゲームの舞台そのもの。

const R := 20.0

var env: Environment
var sky_mat: ShaderMaterial
var light: DirectionalLight3D
var rng := RandomNumberGenerator.new()
var dawn := 0.0


var compat := false


func _ready() -> void:
	rng.seed = 20261118
	# WebGL(Compatibility)では頂点カラーの扱いが違うので補正する
	compat = RenderingServer.get_current_rendering_method() == "gl_compatibility"
	RenderingServer.global_shader_parameter_set("vcol_gamma", 0.4545 if compat else 1.0)
	_build_env()
	_build_planet()
	_build_decor()
	set_dawn(0.0)


func _build_env() -> void:
	sky_mat = ShaderMaterial.new()
	sky_mat.shader = load("res://shaders/sky.gdshader")
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_32
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_strength = 1.05
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 1.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	light = DirectionalLight3D.new()
	light.shadow_enabled = true
	light.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL if compat else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	light.directional_shadow_max_distance = 70.0
	light.shadow_opacity = 0.75
	light.shadow_blur = 1.5
	add_child(light)


## 0 = 真夜中、1 = 夜明け。
func set_dawn(t: float) -> void:
	dawn = clampf(t, 0.0, 1.0)
	var k := dawn
	light.light_color = Color(0.62, 0.72, 1.0).lerp(Color(1.0, 0.82, 0.62), k)
	light.light_energy = lerpf(1.25, 1.7, k)
	env.ambient_light_color = Color(0.30, 0.36, 0.62).lerp(Color(0.75, 0.62, 0.55), k)
	env.ambient_light_energy = lerpf(0.75, 1.0, k)
	sky_mat.set_shader_parameter("top_color", Color(0.01, 0.015, 0.06).lerp(Color(0.30, 0.58, 0.98), k))
	sky_mat.set_shader_parameter("band_color", Color(0.07, 0.06, 0.20).lerp(Color(0.62, 0.80, 1.0), k))
	sky_mat.set_shader_parameter("star_amount", 1.0 - smoothstep(0.3, 0.9, k))
	sky_mat.set_shader_parameter("glow_amount", smoothstep(0.05, 1.0, k) * 0.95)
	sky_mat.set_shader_parameter("glow_color", Color(0.85, 0.35, 0.45).lerp(Color(1.0, 0.86, 0.55), k))


## プレイヤー(カメラ)基準で光を当てる。up = 地面の外向き、fwd = 画面奥、right = 画面右。
func update_frame(up: Vector3, fwd: Vector3, right: Vector3) -> void:
	var ld := (-up * 1.0 + right * 0.5 - fwd * 0.35).normalized()
	light.global_transform = Transform3D(Basis.looking_at(ld, fwd), Vector3.ZERO)
	sky_mat.set_shader_parameter("glow_dir", (fwd * 0.9 + up * 0.15).normalized())


func rand_dir() -> Vector3:
	while true:
		var v := Vector3(rng.randfn(), rng.randfn(), rng.randfn())
		if v.length_squared() > 0.0001:
			return v.normalized()
	return Vector3.UP


func _icosphere(sub: int) -> Array:
	var t := (1.0 + sqrt(5.0)) / 2.0
	var v: Array[Vector3] = [
		Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0),
		Vector3(0, -1, t), Vector3(0, 1, t), Vector3(0, -1, -t), Vector3(0, 1, -t),
		Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1)]
	for i in v.size():
		v[i] = v[i].normalized()
	var f := PackedInt32Array([
		0, 11, 5, 0, 5, 1, 0, 1, 7, 0, 7, 10, 0, 10, 11,
		1, 5, 9, 5, 11, 4, 11, 10, 2, 10, 7, 6, 7, 1, 8,
		3, 9, 4, 3, 4, 2, 3, 2, 6, 3, 6, 8, 3, 8, 9,
		4, 9, 5, 2, 4, 11, 6, 2, 10, 8, 6, 7, 9, 8, 1])
	for s in sub:
		var cache := {}
		var nf := PackedInt32Array()
		for i in range(0, f.size(), 3):
			var a := f[i]
			var b := f[i + 1]
			var c := f[i + 2]
			var ab := _mid(v, cache, a, b)
			var bc := _mid(v, cache, b, c)
			var ca := _mid(v, cache, c, a)
			nf.append_array(PackedInt32Array([a, ab, ca, b, bc, ab, c, ca, bc, ab, bc, ca]))
		f = nf
	return [v, f]


func _mid(v: Array[Vector3], cache: Dictionary, a: int, b: int) -> int:
	var key := Vector2i(mini(a, b), maxi(a, b))
	if cache.has(key):
		return cache[key]
	v.append(((v[a] + v[b]) * 0.5).normalized())
	cache[key] = v.size() - 1
	return v.size() - 1


func _build_planet() -> void:
	var ico := _icosphere(5)
	var v: Array[Vector3] = ico[0]
	var f: PackedInt32Array = ico[1]
	var n1 := FastNoiseLite.new()
	n1.seed = 11
	n1.frequency = 2.2
	var n2 := FastNoiseLite.new()
	n2.seed = 23
	n2.frequency = 1.1
	var n3 := FastNoiseLite.new()
	n3.seed = 37
	n3.frequency = 5.0
	var g_dark := Color("2c7a52").srgb_to_linear()
	var g_mid := Color("46a862").srgb_to_linear()
	var g_light := Color("8fd06a").srgb_to_linear()
	var sand := Color("d4b578").srgb_to_linear()
	var water := Color("3f9fe0").srgb_to_linear()
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	for i in range(0, f.size(), 3):
		var a := v[f[i]]
		var b := v[f[i + 1]]
		var c := v[f[i + 2]]
		var ctr := ((a + b + c) / 3.0).normalized()
		var h := n2.get_noise_3dv(ctr) # 大きなうねり
		var d := n1.get_noise_3dv(ctr)
		var j := n3.get_noise_3dv(ctr)
		var col: Color
		if h < -0.42:
			col = water.lerp(Color("2a78c8").srgb_to_linear(), clampf((-0.42 - h) * 6.0, 0.0, 1.0))
		elif h < -0.34:
			col = sand
		else:
			col = g_dark.lerp(g_mid, clampf(d * 1.6 + 0.5, 0.0, 1.0))
			if h > 0.25:
				col = col.lerp(g_light, clampf((h - 0.25) * 4.0, 0.0, 1.0))
		col = col.lightened(j * 0.08) if j > 0.0 else col.darkened(-j * 0.12)
		# Godot は時計回りが表
		for p: Vector3 in [a, c, b]:
			verts.append(p * R)
			norms.append(ctr.lerp(p, 0.35).normalized())
			cols.append(col)
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_COLOR] = cols
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/entity.gdshader")
	mat.set_shader_parameter("rim_strength", 0.25)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _scatter(mesh: Mesh, count: int, smin: float, smax: float, shadow := true, sink := 0.0) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = count
	for i in count:
		var d := rand_dir()
		mm.set_instance_transform(i, MeshKit.surface_xf(d, rng.randf() * TAU, rng.randf_range(smin, smax), R - sink))
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = MeshKit.material()
	if not shadow:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _build_decor() -> void:
	# 草
	var grass := MeshKit.new()
	grass.cone(Vector3(0, 0.22, 0), 0.07, 0.5, Color("5fc46e"), Vector3(0.15, 0, 0.1), 4)
	grass.cone(Vector3(0.12, 0.17, 0.05), 0.06, 0.38, Color("4fb163"), Vector3(-0.2, 0, -0.25), 4)
	grass.cone(Vector3(-0.1, 0.15, -0.06), 0.06, 0.34, Color("72d47c"), Vector3(0.1, 0, 0.3), 4)
	_scatter(grass.build(), 900, 0.7, 1.5, false)
	# 花(色ちがい)
	for col: String in ["ff8fab", "ffd166", "c8b6ff", "ffffff"]:
		var fl := MeshKit.new()
		fl.cyl(Vector3(0, 0.18, 0), 0.025, 0.03, 0.36, Color("3f9a55"), Vector3.ZERO, 4)
		fl.sphere(Vector3(0, 0.4, 0), 0.11, Color(col), Vector3(1, 0.55, 1), 6)
		fl.sphere(Vector3(0, 0.43, 0), 0.05, Color("ffb703"), Vector3.ONE, 5)
		_scatter(fl.build(), 110, 0.8, 1.4, false)
	# 石
	var rock := MeshKit.new()
	rock.sphere(Vector3(0, 0.12, 0), 0.32, Color("8d99ae"), Vector3(1.2, 0.7, 0.9), 6)
	rock.sphere(Vector3(0.25, 0.06, 0.1), 0.18, Color("7a869a"), Vector3(1, 0.7, 1), 5)
	_scatter(rock.build(), 90, 0.6, 1.6, true, 0.02)
	# きのこ
	var mush := MeshKit.new()
	mush.cyl(Vector3(0, 0.16, 0), 0.07, 0.09, 0.32, Color("f8edeb"), Vector3.ZERO, 6)
	mush.sphere(Vector3(0, 0.34, 0), 0.22, Color("e63946"), Vector3(1, 0.6, 1), 8)
	mush.sphere(Vector3(0.1, 0.42, 0.08), 0.045, Color("ffffff"), Vector3.ONE, 4)
	mush.sphere(Vector3(-0.09, 0.42, -0.05), 0.04, Color("ffffff"), Vector3.ONE, 4)
	_scatter(mush.build(), 70, 0.7, 1.5, true)
	# 木(小さめ・飾り)
	var tree := MeshKit.new()
	tree.cyl(Vector3(0, 0.45, 0), 0.12, 0.17, 0.9, Color("7f5539"), Vector3.ZERO, 6)
	tree.cone(Vector3(0, 1.25, 0), 0.75, 1.2, Color("2d8a57"), Vector3.ZERO, 7)
	tree.cone(Vector3(0, 1.9, 0), 0.55, 1.0, Color("38a169"), Vector3.ZERO, 7)
	tree.cone(Vector3(0, 2.45, 0), 0.36, 0.8, Color("52b788"), Vector3.ZERO, 7)
	_scatter(tree.build(), 40, 0.5, 0.9, true)
	# 丸い木
	var bush := MeshKit.new()
	bush.cyl(Vector3(0, 0.35, 0), 0.1, 0.14, 0.7, Color("7f5539"), Vector3.ZERO, 6)
	bush.sphere(Vector3(0, 1.1, 0), 0.7, Color("40916c"), Vector3(1, 0.9, 1), 8)
	bush.sphere(Vector3(0.35, 1.35, 0.1), 0.42, Color("52b788"), Vector3.ONE, 7)
	bush.sphere(Vector3(-0.3, 1.3, -0.2), 0.38, Color("2d6a4f"), Vector3.ONE, 7)
	_scatter(bush.build(), 30, 0.5, 0.9, true)
	# 光る水晶
	var cry := MeshKit.new()
	cry.cone(Vector3(0, 0.45, 0), 0.16, 0.9, Color("9bf6ff"), Vector3.ZERO, 5)
	cry.cone(Vector3(0.18, 0.28, 0.05), 0.11, 0.56, Color("bdb2ff"), Vector3(0, 0, -0.35), 5)
	cry.cone(Vector3(-0.15, 0.24, -0.08), 0.1, 0.48, Color("a0c4ff"), Vector3(0.2, 0, 0.4), 5)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = cry.build()
	mm.instance_count = 30
	for i in 30:
		mm.set_instance_transform(i, MeshKit.surface_xf(rand_dir(), rng.randf() * TAU, rng.randf_range(0.8, 1.5), R))
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = MeshKit.new_glow(Color(0.8, 0.9, 1.0), 1.5)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
