class_name MeshKit
extends RefCounted
## プリミティブを頂点カラー付きで1つのメッシュにまとめる小さなビルダー。

static var _mat: ShaderMaterial
static var _glow: ShaderMaterial

var _v := PackedVector3Array()
var _n := PackedVector3Array()
var _c := PackedColorArray()
var _i := PackedInt32Array()


static func material() -> ShaderMaterial:
	if _mat == null:
		_mat = ShaderMaterial.new()
		_mat.shader = load("res://shaders/entity.gdshader")
	return _mat


static var _flash: ShaderMaterial
static var _elite: ShaderMaterial


## 攻撃が当たった瞬間に白く光らせる用。
static func flash_material() -> ShaderMaterial:
	if _flash == null:
		_flash = ShaderMaterial.new()
		_flash.shader = load("res://shaders/entity.gdshader")
		_flash.set_shader_parameter("flash", 0.85)
	return _flash


## 強敵(赤っぽい色)用。
static func elite_material() -> ShaderMaterial:
	if _elite == null:
		_elite = ShaderMaterial.new()
		_elite.shader = load("res://shaders/entity.gdshader")
		_elite.set_shader_parameter("tint", Color(2.0, 0.7, 0.7))
	return _elite


static func glow_material() -> ShaderMaterial:
	if _glow == null:
		_glow = ShaderMaterial.new()
		_glow.shader = load("res://shaders/glow.gdshader")
	return _glow


static func new_glow(color: Color, boost := 2.2) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/glow.gdshader")
	m.set_shader_parameter("base", color)
	m.set_shader_parameter("boost", boost)
	return m


## 球面上の点 dir に立つ姿勢(Y軸が外向き)。
static func surface_xf(dir: Vector3, yaw: float, s: float, radius: float) -> Transform3D:
	var up := dir
	var ref := Vector3.UP if absf(dir.y) < 0.9 else Vector3.RIGHT
	var x := ref.cross(up).normalized()
	var z := x.cross(up)
	var b := Basis(x, up, z).rotated(up, yaw) * Basis.from_scale(Vector3(s, s, s))
	return Transform3D(b, dir * radius)


func add(mesh: PrimitiveMesh, xf: Transform3D, color: Color) -> MeshKit:
	var arr: Array = mesh.get_mesh_arrays()
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var norms: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var base := _v.size()
	var nb := xf.basis.inverse().transposed()
	var lin := color.srgb_to_linear()
	for k in verts.size():
		_v.append(xf * verts[k])
		_n.append((nb * norms[k]).normalized())
		_c.append(lin)
	for k in idx.size():
		_i.append(base + idx[k])
	return self


func sphere(pos: Vector3, radius: float, color: Color, scl := Vector3.ONE, seg := 12) -> MeshKit:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	m.radial_segments = seg
	m.rings = maxi(seg / 2, 3)
	return add(m, Transform3D(Basis.from_scale(scl), pos), color)


func cone(pos: Vector3, radius: float, height: float, color: Color, rot := Vector3.ZERO, seg := 10) -> MeshKit:
	return cyl(pos, 0.0, radius, height, color, rot, seg)


func cyl(pos: Vector3, r_top: float, r_bot: float, height: float, color: Color, rot := Vector3.ZERO, seg := 10) -> MeshKit:
	var m := CylinderMesh.new()
	m.top_radius = r_top
	m.bottom_radius = r_bot
	m.height = height
	m.radial_segments = seg
	m.rings = 1
	return add(m, Transform3D(Basis.from_euler(rot), pos), color)


func box(pos: Vector3, size: Vector3, color: Color, rot := Vector3.ZERO) -> MeshKit:
	var m := BoxMesh.new()
	m.size = size
	return add(m, Transform3D(Basis.from_euler(rot), pos), color)


func build() -> ArrayMesh:
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = _v
	arr[Mesh.ARRAY_NORMAL] = _n
	arr[Mesh.ARRAY_COLOR] = _c
	arr[Mesh.ARRAY_INDEX] = _i
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return mesh
