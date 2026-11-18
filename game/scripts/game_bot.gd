class_name GameBot
extends RefCounted
## 試験用の自動操作(--bot)。敵と弾から逃げ、かけらを拾いに行く。

const R := Game.R

var g: Game
var bot_lag := 18
var _bot_n := 0
var _bot_v := Vector2.ZERO


func _init(game: Game) -> void:
	g = game


func _bot_input() -> Vector2:
	# 人間っぽく、0.3秒に1回しか判断しない
	_bot_n += 1
	if bot_lag > 1 and _bot_n % bot_lag != 1:
		return _bot_v
	_bot_v = _bot_think()
	return _bot_v


func _bot_think() -> Vector2:
	var ppos := g.p_dir * R
	var push := Vector3.ZERO
	var close := 1e9
	for e in g.enemies:
		var d := e.pos.distance_to(ppos) - e.radius
		if d < 9.0:
			var away := -g.tangent_to(g.p_dir, e.dir)
			push += away * (1.0 / maxf(d * d, 0.2)) * (3.0 if e.boss else 1.0)
			close = minf(close, d)
	for b in g.ebullets:
		var d := (b.dir * R).distance_to(ppos)
		if d < 4.0:
			push += -g.tangent_to(g.p_dir, b.dir) * (1.0 / maxf(d * d, 0.2))
	if close > 3.0:
		var best := 1e9
		var bd := Vector3.ZERO
		for gm in g.gems:
			var d := (gm.dir * R).distance_squared_to(ppos)
			if d < best:
				best = d
				bd = gm.dir
		if best < 400.0:
			push += g.tangent_to(g.p_dir, bd) * (0.5 if close < 6.0 else 2.0)
	if push.length() < 0.05:
		push = g.cam_fwd.rotated(g.p_dir, sin(g.elapsed * 0.3) * 1.5)
	push = push.normalized()
	if close < 1.2 and g.dash_cd <= 0.0:
		g.player.request_dash()
	var right := g.cam_fwd.cross(g.p_dir).normalized()
	return Vector2(push.dot(right), push.dot(g.cam_fwd))
