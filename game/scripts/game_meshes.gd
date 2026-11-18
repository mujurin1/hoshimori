class_name GameMeshes
extends RefCounted
## 敵・敵の弾・特別なアイテムの形。起動時に 1 度だけ作る。

var enemy_meshes := {}
var special_meshes := {}
var ebullet_mesh: Mesh
var mat_ebullet: ShaderMaterial


func _eyes(mk: MeshKit, x: float, y: float, z: float, r: float, col := Color.WHITE) -> void:
	for sx: float in [-1.0, 1.0]:
		mk.sphere(Vector3(x * sx, y, z), r, col, Vector3.ONE, 8)
		mk.sphere(Vector3(x * sx * 0.95, y - r * 0.1, z - r * 0.72), r * 0.5, Color("1b1b2f"), Vector3.ONE, 6)


## ハートの形。輪郭を数式で描き、中心へ縮めながら前後へ押し出して丸く膨らませる。
## 玉と円すいを組み合わせる作り方だと、継ぎ目に段差ができてハートに見えない
func _heart_mesh(color: Color) -> ArrayMesh:
	const N := 36 # 輪郭の点の数
	const M := 10 # 前後方向の分割
	const SIZE := 0.45 / 16.0
	const THICK := 0.2
	var outline: Array[Vector2] = []
	for i in N:
		var t := TAU * i / N
		var x := 16.0 * pow(sin(t), 3.0)
		var y := 13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t)
		outline.append(Vector2(x, y) * SIZE)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(0)
	var lin := color.srgb_to_linear()
	for i in N:
		for j in M + 1:
			var phi := -PI * 0.5 + PI * j / M
			var o := outline[i] * cos(phi)
			st.set_color(lin)
			st.add_vertex(Vector3(o.x, o.y + 0.07, THICK * sin(phi)))
	for i in N:
		var i2 := (i + 1) % N
		for j in M:
			var a := i * (M + 1) + j
			var b := i2 * (M + 1) + j
			var c := i2 * (M + 1) + j + 1
			var d := i * (M + 1) + j + 1
			st.add_index(a)
			st.add_index(b)
			st.add_index(c)
			st.add_index(a)
			st.add_index(c)
			st.add_index(d)
	st.generate_normals()
	return st.commit()


func _build_enemy_meshes() -> void:
	# モヤ:ぷにっとした影
	var c: Color = Game.ETYPES.moya.color
	var mk := MeshKit.new()
	mk.sphere(Vector3(0, 0.5, 0), 0.6, c, Vector3(1, 0.86, 1), 12)
	mk.cone(Vector3(0, 1.08, 0.05), 0.16, 0.36, c.darkened(0.15), Vector3(0.3, 0, 0), 6)
	_eyes(mk, 0.23, 0.62, -0.47, 0.15)
	enemy_meshes["moya"] = mk.build()
	# ハシリ:小さくて速い
	c = Game.ETYPES.hashiri.color
	mk = MeshKit.new()
	mk.sphere(Vector3(0, 0.4, 0), 0.42, c, Vector3(0.9, 0.85, 1.3), 10)
	mk.cone(Vector3(0.2, 0.82, 0.1), 0.12, 0.42, c.lightened(0.2), Vector3(0.5, 0, -0.3), 5)
	mk.cone(Vector3(-0.2, 0.82, 0.1), 0.12, 0.42, c.lightened(0.2), Vector3(0.5, 0, 0.3), 5)
	mk.cone(Vector3(0, 0.45, 0.62), 0.14, 0.4, c.darkened(0.2), Vector3(1.57, 0, 0), 5)
	_eyes(mk, 0.17, 0.5, -0.43, 0.11, Color("fff3b0"))
	enemy_meshes["hashiri"] = mk.build()
	# ドスン:大きくて硬い
	c = Game.ETYPES.dosun.color
	mk = MeshKit.new()
	mk.sphere(Vector3(0, 0.85, 0), 1.0, c, Vector3(1, 0.88, 1), 14)
	mk.cone(Vector3(0.55, 1.7, 0), 0.22, 0.6, Color("f1e3c8"), Vector3(0, 0, -0.5), 6)
	mk.cone(Vector3(-0.55, 1.7, 0), 0.22, 0.6, Color("f1e3c8"), Vector3(0, 0, 0.5), 6)
	mk.box(Vector3(0, 0.55, -0.92), Vector3(0.7, 0.14, 0.1), Color("1b1b2f"))
	_eyes(mk, 0.36, 1.05, -0.8, 0.2, Color("ffe066"))
	enemy_meshes["dosun"] = mk.build()
	# ツブテ:ひとつ目、弾を撃つ
	c = Game.ETYPES.tsubute.color
	mk = MeshKit.new()
	mk.sphere(Vector3(0, 0.6, 0), 0.55, c, Vector3.ONE, 12)
	for a: float in [-0.5, 0.0, 0.5]:
		mk.cone(Vector3(a * 0.6, 1.2, 0.0), 0.11, 0.36, c.lightened(0.25), Vector3(0, 0, -a), 5)
	mk.sphere(Vector3(0, 0.66, -0.4), 0.27, Color.WHITE, Vector3.ONE, 10)
	mk.sphere(Vector3(0, 0.66, -0.62), 0.13, Color("d00000"), Vector3.ONE, 8)
	enemy_meshes["tsubute"] = mk.build()
	# オオモヤ:中ボス
	c = Game.ETYPES.oomoya.color
	mk = MeshKit.new()
	mk.sphere(Vector3(0, 0.5, 0), 0.6, c, Vector3(1, 0.9, 1), 16)
	for i in 5:
		var a := -0.8 + 0.4 * i
		mk.cone(Vector3(sin(a) * 0.42, 1.02 + cos(a) * 0.08, 0.0), 0.09, 0.3, Color("ffd166"), Vector3(0, 0, -a * 0.7), 5)
	_eyes(mk, 0.24, 0.62, -0.46, 0.16, Color("ffe066"))
	mk.box(Vector3(0, 0.36, -0.57), Vector3(0.34, 0.07, 0.06), Color("1b1b2f"))
	enemy_meshes["oomoya"] = mk.build()
	# ヨルノヌシ:ラスボス
	c = Game.ETYPES.nushi.color
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
	special_meshes["heart"] = _heart_mesh(Color("ff4d6d"))
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
