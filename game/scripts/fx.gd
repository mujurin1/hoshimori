class_name Fx
extends Node3D
## 見た目の気持ちよさ担当:破片、ダメージ数字、輪、稲妻、画面ゆれ。

const R := 20.0

var _bursts: Array[CPUParticles3D] = []
var _bi := 0
var _nums: Array[Dictionary] = []
var _ni := 0
var _rings: Array[Dictionary] = []
var _ri := 0
var _lines: Array[Dictionary] = []
var _li := 0
var _pops: Array[Dictionary] = []
var _po := 0
var trauma := 0.0
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	var pm := SphereMesh.new()
	pm.radius = 0.5
	pm.height = 1.0
	pm.radial_segments = 6
	pm.rings = 3
	pm.material = MeshKit.glow_material()
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	for i in 32:
		var p := CPUParticles3D.new()
		p.mesh = pm
		p.emitting = false
		p.one_shot = true
		p.explosiveness = 0.95
		p.local_coords = false
		p.spread = 180.0
		p.gravity = Vector3.ZERO
		p.damping_min = 3.0
		p.damping_max = 6.0
		p.scale_amount_curve = curve
		p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(p)
		_bursts.append(p)

	var font: Font = load("res://fonts/MPLUSRounded1c-ExtraBold.ttf")
	for i in 56:
		var l := Label3D.new()
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
		l.font = font
		l.font_size = 64
		l.outline_size = 18
		l.outline_modulate = Color(0.05, 0.05, 0.15, 0.9)
		l.pixel_size = 0.009
		l.render_priority = 5
		l.visible = false
		add_child(l)
		_nums.append({"l": l, "t": 1.0, "dur": 0.0, "base": Vector3.ZERO, "up": Vector3.UP, "s": 1.0})

	var tor := TorusMesh.new()
	tor.inner_radius = 0.9
	tor.outer_radius = 1.0
	tor.rings = 48
	tor.ring_segments = 6
	for i in 18:
		var mi := MeshInstance3D.new()
		mi.mesh = tor
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visible = false
		add_child(mi)
		_rings.append({"n": mi, "m": m, "t": 1.0, "dur": 0.0, "dir": Vector3.UP, "r0": 0.0, "r1": 1.0, "c": Color.WHITE})

	var bm := BoxMesh.new()
	bm.size = Vector3.ONE
	for i in 40:
		var mi := MeshInstance3D.new()
		mi.mesh = bm
		mi.material_override = MeshKit.new_glow(Color(0.75, 0.95, 1.0), 3.0)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visible = false
		add_child(mi)
		_lines.append({"n": mi, "t": 0.0})

	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	sm.radial_segments = 12
	sm.rings = 6
	for i in 14:
		var mi := MeshInstance3D.new()
		mi.mesh = sm
		var gm := MeshKit.new_glow(Color.WHITE, 2.0)
		mi.material_override = gm
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visible = false
		add_child(mi)
		_pops.append({"n": mi, "m": gm, "t": 1.0, "dur": 0.0, "size": 1.0})


func clear() -> void:
	for d in _nums:
		d.l.visible = false
		d.t = d.dur
	for d in _rings:
		d.n.visible = false
		d.t = d.dur
	for d in _lines:
		d.n.visible = false
	for d in _pops:
		d.n.visible = false
		d.t = d.dur
	trauma = 0.0


func burst(pos: Vector3, normal: Vector3, color: Color, amount := 10, speed := 6.0, size := 0.2, life := 0.45) -> void:
	var p := _bursts[_bi]
	_bi = (_bi + 1) % _bursts.size()
	p.emitting = false
	p.global_position = pos
	p.amount = amount
	p.color = color
	p.direction = normal
	p.spread = 85.0
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.scale_amount_min = size * 0.5
	p.scale_amount_max = size
	p.lifetime = life
	p.gravity = -normal * 10.0
	p.restart()
	p.emitting = true


func number(pos: Vector3, up: Vector3, value: float, color := Color.WHITE, s := 1.0) -> void:
	var d := _nums[_ni]
	_ni = (_ni + 1) % _nums.size()
	var l: Label3D = d.l
	l.text = str(int(round(value)))
	l.modulate = color
	l.visible = true
	d.t = 0.0
	d.dur = 0.55
	d.base = pos + up * 1.3 + Vector3(rng.randf_range(-0.3, 0.3), rng.randf_range(-0.3, 0.3), rng.randf_range(-0.3, 0.3))
	d.up = up
	d.s = s


func ring(dir: Vector3, r0: float, r1: float, dur: float, color: Color) -> void:
	var d := _rings[_ri]
	_ri = (_ri + 1) % _rings.size()
	d.t = 0.0
	d.dur = dur
	d.dir = dir
	d.r0 = r0
	d.r1 = r1
	d.c = color
	d.n.visible = true
	_place_ring(d, 0.0)


func _place_ring(d: Dictionary, k: float) -> void:
	var e := 1.0 - (1.0 - k) * (1.0 - k)
	var r: float = lerpf(d.r0, d.r1, e)
	var th := r / R
	var s := maxf(R * sin(th), 0.01)
	var dir: Vector3 = d.dir
	var xf := MeshKit.surface_xf(dir, 0.0, 1.0, R * cos(th) + 0.18)
	xf.basis = xf.basis * Basis.from_scale(Vector3(s, minf(s, 2.5) * 0.6, s))
	var n: MeshInstance3D = d.n
	n.transform = xf
	var c: Color = d.c
	var m: StandardMaterial3D = d.m
	m.albedo_color = Color(c.r, c.g, c.b, c.a * pow(1.0 - k, 1.3))


## a から b への稲妻(ギザギザ)。
func zap(a: Vector3, b: Vector3, width := 0.14) -> void:
	var segs := 4
	var prev := a
	var axis := (b - a)
	var side := axis.cross(a.normalized()).normalized()
	var upv := a.normalized()
	for i in range(1, segs + 1):
		var p := a.lerp(b, float(i) / segs)
		if i < segs:
			p += side * rng.randf_range(-0.6, 0.6) + upv * rng.randf_range(-0.2, 0.5)
		line(prev, p, width, 0.13)
		prev = p


func line(a: Vector3, b: Vector3, width: float, dur: float) -> void:
	var d := _lines[_li]
	_li = (_li + 1) % _lines.size()
	var n: MeshInstance3D = d.n
	var v := b - a
	var len := v.length()
	if len < 0.01:
		return
	var mid := (a + b) * 0.5
	var up := mid.normalized()
	if absf(up.dot(v / len)) > 0.98:
		up = up.cross(Vector3.RIGHT).normalized()
	n.transform = Transform3D(Basis.looking_at(v, up) * Basis.from_scale(Vector3(width, width, len)), mid)
	n.visible = true
	d.t = dur


func pop(pos: Vector3, size: float, color: Color, dur := 0.18) -> void:
	var d := _pops[_po]
	_po = (_po + 1) % _pops.size()
	var n: MeshInstance3D = d.n
	n.position = pos
	n.scale = Vector3.ONE * 0.01
	n.visible = true
	var m: ShaderMaterial = d.m
	m.set_shader_parameter("base", color)
	d.t = 0.0
	d.dur = dur
	d.size = size


func shake(amount: float) -> void:
	trauma = minf(trauma + amount, 1.0)


func shake_vec() -> Vector3:
	var s := trauma * trauma * 0.9
	return Vector3(rng.randf_range(-s, s), rng.randf_range(-s, s), rng.randf_range(-s, s))


func _process(dt: float) -> void:
	trauma = maxf(trauma - dt * 1.7, 0.0)
	for d in _nums:
		if d.t >= d.dur:
			continue
		d.t += dt
		var l: Label3D = d.l
		if d.t >= d.dur:
			l.visible = false
			continue
		var k: float = d.t / d.dur
		var up: Vector3 = d.up
		var base: Vector3 = d.base
		l.position = base + up * (k * 1.6)
		var sc: float = d.s * (1.0 + 0.5 * maxf(0.0, 1.0 - k * 5.0))
		l.scale = Vector3.ONE * sc
		l.modulate.a = 1.0 - maxf(0.0, (k - 0.6) / 0.4)
	for d in _rings:
		if d.t >= d.dur:
			continue
		d.t += dt
		if d.t >= d.dur:
			d.n.visible = false
			continue
		_place_ring(d, d.t / d.dur)
	for d in _lines:
		if d.t > 0.0:
			d.t -= dt
			if d.t <= 0.0:
				d.n.visible = false
	for d in _pops:
		if d.t >= d.dur:
			continue
		d.t += dt
		var n: MeshInstance3D = d.n
		if d.t >= d.dur:
			n.visible = false
			continue
		var k: float = d.t / d.dur
		var s: float = d.size * (sin(k * PI) * 0.6 + k * 0.4) * (1.0 - k * k)
		n.scale = Vector3.ONE * maxf(s, 0.01)
