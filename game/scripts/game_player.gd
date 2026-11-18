class_name GamePlayer
extends RefCounted
## プレイヤー:組み立て、入力、移動、姿勢、ダッシュ、被弾と回復。状態は Game が持つ。

const R := Game.R

var g: Game
var p_node: Node3D
var p_body: MeshInstance3D
var foot_l: MeshInstance3D
var foot_r: MeshInstance3D
var p_light: OmniLight3D
var p_ghost_on := false


func _init(game: Game) -> void:
	g = game


func _build_player() -> void:
	p_node = Node3D.new()
	g.add_child(p_node)
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


func _place_player() -> void:
	_pose_player(0.0, 0.0)


func _pose_player(bob: float, lean: float) -> void:
	var r := g.p_fwd.cross(g.p_dir).normalized()
	var b := Basis(r, g.p_dir, -g.p_fwd)
	if lean > 0.001:
		b = b.rotated(r, -0.16 * lean)
	p_node.transform = Transform3D(b * Basis.from_scale(Vector3(1.0, 1.0, 1.0)), g.p_dir * (R + bob))
	var sw := sin(g.walk_t)
	foot_l.position = Vector3(0.2, 0.1 + maxf(0.0, sw) * 0.14, -sw * 0.24 * lean)
	foot_r.position = Vector3(-0.2, 0.1 + maxf(0.0, -sw) * 0.14, sw * 0.24 * lean)


func move_input() -> Vector2:
	if g.bot:
		return g.bot_ai._bot_input()
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


func request_dash() -> void:
	if not g.alive or not g.running or g.dash_cd > 0.0 or g.ending:
		return
	var inp := move_input() if not g.bot else Vector2.ZERO
	var right := g.cam_fwd.cross(g.p_dir).normalized()
	var mv := right * inp.x + g.cam_fwd * inp.y
	g.dash_dir = mv.normalized() if mv.length() > 0.1 else g.p_fwd
	g.dash_t = 0.17
	g.dash_cd = Game.DASH_CD
	g.p_iframe = maxf(g.p_iframe, Game.DASH_IFRAME)
	g.p_ghost = Game.DASH_IFRAME
	Sfx.play("dash", -6.0, g.rng.randf_range(0.95, 1.08))
	# 出だしの煙。暗めの色にして、光の粒でなく煙に見せる
	g.fx.burst(g.p_dir * (R + 0.4), g.p_dir, Color(0.34, 0.38, 0.44), 9, 2.6, 0.5, 0.55)


func _update_player(dt: float) -> void:
	g.p_iframe = maxf(g.p_iframe - dt, 0.0)
	g.p_blink = maxf(g.p_blink - dt, 0.0)
	g.p_ghost = maxf(g.p_ghost - dt, 0.0)
	if (g.p_ghost > 0.0) != p_ghost_on:
		p_ghost_on = g.p_ghost > 0.0
		var m: Material = MeshKit.ghost_material() if p_ghost_on else MeshKit.material()
		p_body.material_override = m
		foot_l.material_override = m
		foot_r.material_override = m
	g.dash_cd = maxf(g.dash_cd - dt, 0.0)
	var inp := Vector2.ZERO
	if g.alive and not g.ending:
		inp = move_input()
	var right := g.cam_fwd.cross(g.p_dir).normalized()
	var mv := right * inp.x + g.cam_fwd * inp.y
	var sp := Game.BASE_SPEED * (1.0 + 0.1 * g.weapons.level("speed"))
	if g.dash_t > 0.0:
		g.dash_t -= dt
		mv = g.dash_dir
		sp *= 3.3
		if g.rng.randf() < 0.6:
			g.fx.burst(g.p_dir * (R + 0.6), -g.dash_dir, Color(0.75, 0.9, 1.0), 3, 2.0, 0.2, 0.3)
	g.moving = mv.length() > 0.05
	if g.moving:
		g.p_dir = (g.p_dir + mv * (sp * dt / R)).normalized()
		g.cam_fwd = (g.cam_fwd - g.p_dir * g.cam_fwd.dot(g.p_dir)).normalized()
		if g.dash_t > 0.0:
			g.dash_dir = (g.dash_dir - g.p_dir * g.dash_dir.dot(g.p_dir)).normalized()
		var f := mv - g.p_dir * mv.dot(g.p_dir)
		if f.length() > 0.01:
			# 向きは角度で回す。2 本の向きを混ぜる方法（lerp）だと、真後ろへ切り返した時に打ち消し合って回らず、前を向いたまま後ろへ歩く
			var turn := g.p_fwd.signed_angle_to(f.normalized(), g.p_dir)
			# 1 フレームで回る角度に上限を付ける（毎秒 18 ラジアン）。真後ろへは 0.2 秒弱かけて回る
			var step := clampf(turn * (1.0 - exp(-16.0 * dt)), -Game.TURN_MAX * dt, Game.TURN_MAX * dt)
			g.p_fwd = g.p_fwd.rotated(g.p_dir, step)
		g.walk_t += dt * 13.0
	g.p_fwd -= g.p_dir * g.p_fwd.dot(g.p_dir)
	if g.p_fwd.length_squared() < 0.0001:
		g.p_fwd = g.cam_fwd
	g.p_fwd = g.p_fwd.normalized()
	g.move_k = lerpf(g.move_k, 1.0 if g.moving else 0.0, 1.0 - exp(-14.0 * dt))
	var bob := lerpf(sin(g.elapsed * 2.5) * 0.025, absf(sin(g.walk_t)) * 0.13, g.move_k)
	_pose_player(bob, g.move_k)
	# 点滅させるのは体だけ。p_node ごと消すと、子の明かりも消えて周りの地面まで明滅する
	p_node.visible = g.alive
	var body_on := not (g.p_blink > 0.0 and fmod(g.p_blink, Game.BLINK_PERIOD) < Game.BLINK_OFF)
	p_body.visible = body_on
	foot_l.visible = body_on
	foot_r.visible = body_on
	if g.gem_combo_t > 0.0:
		g.gem_combo_t -= dt
		if g.gem_combo_t <= 0.0:
			g.gem_combo = 0


func hurt_player(amount: float, from_pos: Vector3) -> void:
	if g.p_iframe > 0.0 or not g.alive or g.ending:
		return
	g.p_iframe = 0.9
	g.p_blink = Game.BLINK_TIME
	g.fx.shake(0.55)
	Sfx.play("hurt", -3.0)
	g.main.on_player_hurt()
	if not g.god:
		g.p_hp -= amount * [0.55, 1.0, 1.3][g.difficulty]
	var ppos := g.p_dir * R
	g.fx.burst(ppos + g.p_dir * 0.8, g.p_dir, Color(1.0, 0.4, 0.4), 14, 7.0, 0.22, 0.4)
	g.fx.ring(g.p_dir, 0.5, 4.5, 0.3, Color(1.0, 0.5, 0.5, 0.8))
	for e in g.query(ppos, 4.5):
		e.kb += g.tangent_to(g.p_dir, e.dir) * 16.0
	if from_pos != Vector3.ZERO:
		pass
	if g.p_hp <= 0.0:
		g.p_hp = 0.0
		g.alive = false
		g.ending = true
		g.end_t = 0.0
		g.sim_speed = 0.3
		p_node.visible = false
		g.fx.burst(ppos + g.p_dir * 0.8, g.p_dir, Color(1.0, 0.95, 0.8), 40, 12.0, 0.3, 0.9)
		g.fx.shake(1.0)
		Sfx.music("")
		Sfx.play("gameover", -3.0)


func heal(amount: float) -> void:
	g.p_hp = minf(g.p_hp + amount, g.p_max_hp)
	g.fx.burst(g.p_dir * (R + 1.0), g.p_dir, Color(0.6, 1.0, 0.7), 12, 4.0, 0.2, 0.6)
