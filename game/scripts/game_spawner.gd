class_name GameSpawner
extends RefCounted
## 敵の出現の管理:時間に応じた出現、ハシリの群れ、決まった時刻のイベント。状態は Game が持つ。

var g: Game


func _init(game: Game) -> void:
	g = game


func _spawn_dir(dmin: float, dmax: float) -> Vector3:
	return g.dir_at(g.p_dir, g.rand_tangent(g.p_dir), g.rng.randf_range(dmin, dmax))


func _director(dt: float) -> void:
	var m := g.elapsed / 60.0
	var dmul: float = [0.9, 1.0, 1.15][g.difficulty]
	var rate := (1.5 + 1.2 * m + 0.06 * m * m) * dmul
	if m < 0.2:
		rate = 1.0
	g.spawn_acc += dt * rate
	while g.spawn_acc >= 1.0:
		g.spawn_acc -= 1.0
		if g.enemies.size() >= Game.MAX_ENEMIES:
			continue
		var roll := g.rng.randf()
		var kind := "moya"
		if m >= 3.5 and roll < 0.12:
			kind = "tsubute"
		elif m >= 2.0 and roll < 0.12 + minf(0.05 + 0.012 * m, 0.14):
			kind = "dosun"
		elif m >= 1.0 and roll < 0.55:
			kind = "hashiri"
		var elite := m >= 2.0 and g.rng.randf() < 0.02
		var e := g.enemy_sys.spawn_enemy(kind, _spawn_dir(11.0, 17.0), elite)
		if elite:
			Sfx.play("spawn_elite", -8.0)
			e.spawn_t = 0.8
	# ハシリの群れ
	if m >= 1.0:
		g.pack_t -= dt
		if g.pack_t <= 0.0:
			g.pack_t = g.rng.randf_range(16.0, 24.0)
			var center := _spawn_dir(14.0, 18.0)
			for i in int(5 + m * 1.5):
				if g.enemies.size() < Game.MAX_ENEMIES:
					g.enemy_sys.spawn_enemy("hashiri", g.dir_at(center, g.rand_tangent(center), g.rng.randf_range(0.0, 3.0)))
	_event(2.0, "intro")
	_event(180.0, "boss1")
	_event(300.0, "ring")
	_event(360.0, "boss2")
	_event(450.0, "predawn")
	_event(Game.NIGHT_LEN, "final")


func _event(t: float, id: String) -> void:
	if g.elapsed < t or g.events_done.has(id):
		return
	g.events_done[id] = true
	match id:
		"intro":
			g.main.banner("夜が来た。夜明けまで生きのびろ!", Color("cfe3ff"))
		"boss1":
			g.main.banner("大きな影が近づいてくる…", Color("ff9ecb"))
			Sfx.play("boss_warn", -4.0)
			g.enemy_sys.spawn_enemy("oomoya", _spawn_dir(16.0, 18.0))
		"ring":
			g.main.banner("影に囲まれた!", Color("ff9ecb"))
			Sfx.play("spawn_elite", -4.0)
			var t0 := g.rand_tangent(g.p_dir)
			for i in 30:
				g.enemy_sys.spawn_enemy("moya", g.dir_at(g.p_dir, t0.rotated(g.p_dir, TAU * i / 30.0), 15.0))
		"boss2":
			g.main.banner("大きな影がふたつ…!", Color("ff9ecb"))
			Sfx.play("boss_warn", -4.0)
			var t0 := g.rand_tangent(g.p_dir)
			for i in 2:
				var b := g.enemy_sys.spawn_enemy("oomoya", g.dir_at(g.p_dir, t0 * (1.0 if i == 0 else -1.0), 17.0))
				b.max_hp = 1700.0
				b.hp = b.max_hp
		"predawn":
			g.main.banner("空が白みはじめた… あと少し!", Color("ffe9a8"))
		"final":
			g.main.banner("夜の主「ヨルノヌシ」があらわれた!", Color("ff7b7b"))
			Sfx.play("boss_warn", -2.0)
			Sfx.music("boss")
			g.final_boss = g.enemy_sys.spawn_enemy("nushi", _spawn_dir(17.0, 18.0))
			g.final_boss.spawn_t = 1.2
			g.final_spawned = true
