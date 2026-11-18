class_name WeaponBase
extends Node3D
## 武器の土台:持っている力のレベル、出ている弾などの状態、見た目の素材、ダメージの与え方。
## WeaponAttacks(各武器の動き)が継ぎ、それを Weapons(定義と選択肢)が継ぐ。ゲームが作るのは Weapons。

const R := 20.0


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


func level(id: String) -> int:
	return int(lv.get(id, 0))


func power() -> float:
	return 1.0 + 0.15 * level("power")


func haste() -> float:
	return pow(0.92, level("haste"))


func _hit(e: Game.Enemy, src: String, amount: float, kb_dir := Vector3.ZERO, kb := 0.0) -> void:
	var a := amount * power()
	dealt[src] = float(dealt.get(src, 0.0)) + minf(a, e.hp)
	g.enemy_sys.damage_enemy(e, a, kb_dir, kb)
