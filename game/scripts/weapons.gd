class_name Weapons
extends WeaponAttacks
## 自動で発動する星の魔法の定義と、レベルアップの選択肢。
## 各武器の動きは WeaponAttacks、状態と見た目の素材は WeaponBase にある。

const DEFS := {
	"bolt": {"name": "スターショット", "icon": "星", "color": Color("ffe066"), "max": 6, "desc": [
		"いちばん近い敵に星の弾を撃つ", "ダメージアップ", "弾が2発になる",
		"敵を1体つらぬく", "弾が3発になる", "弾が4発、連射もはやくなる"]},
	"moon": {"name": "ツキノワ", "icon": "月", "color": Color("cfd8ff"), "max": 6, "desc": [
		"小さな月が2つ、まわりを回って敵をはじく", "月が3つになる", "ダメージアップ、回転がはやくなる",
		"月が4つになる", "ダメージアップ、軌道が広がる", "月が5つになる"]},
	"pulse": {"name": "ホシナミ", "icon": "波", "color": Color("7ae7c7"), "max": 6, "desc": [
		"まわりに星の波を放ち、敵を押しかえす", "威力と範囲アップ", "波の間隔がみじかくなる",
		"威力と範囲アップ", "波の間隔がみじかくなる", "威力・範囲ともに最大"]},
	"zap": {"name": "イナズマ", "icon": "雷", "color": Color("8ecbff"), "max": 6, "desc": [
		"近くの敵に雷が落ち、となりの敵へ連鎖する", "連鎖が増え、ダメージアップ", "雷の間隔がみじかくなる",
		"連鎖が増え、ダメージアップ", "雷の間隔がみじかくなる", "連鎖・威力ともに最大"]},
	"comet": {"name": "ホウキボシ", "icon": "彗", "color": Color("9bf6ff"), "max": 6, "desc": [
		"彗星が星をぐるりと一周して、敵をなぎ払う", "ダメージアップ、彗星が大きくなる", "彗星が2つになる",
		"ダメージアップ、彗星が大きくなる", "彗星が3つになる", "ダメージ大幅アップ"]},
	"meteor": {"name": "ナガレボシ", "icon": "流", "color": Color("ffa94d"), "max": 6, "desc": [
		"敵の群れに流れ星が落ちて爆発する", "ダメージと爆発範囲アップ", "流れ星が2つになる",
		"ダメージと爆発範囲アップ", "流れ星が3つになる", "流れ星が4つ、威力も最大"]},
	"speed": {"name": "かぜのくつ", "icon": "速", "color": Color("b9fbc0"), "max": 5, "passive": true, "desc": ["移動速度 +10%"]},
	"magnet": {"name": "ほしよせ", "icon": "寄", "color": Color("a0c4ff"), "max": 5, "passive": true, "desc": ["星のかけらを引きよせる範囲 +40%"]},
	"heart": {"name": "いのちの実", "icon": "命", "color": Color("ff8fa3"), "max": 5, "passive": true, "desc": ["最大HP +25、HPも25回復"]},
	"haste": {"name": "せっかち時計", "icon": "早", "color": Color("ffd6a5"), "max": 5, "passive": true, "desc": ["すべての攻撃の間隔 -8%"]},
	"power": {"name": "ちからの石", "icon": "力", "color": Color("ffadad"), "max": 5, "passive": true, "desc": ["すべてのダメージ +15%"]},
	"feast": {"name": "星のごちそう", "icon": "食", "color": Color("fdffb6"), "max": 99999, "passive": true, "desc": ["HPを40回復する"]},
}
const ORDER := ["bolt", "moon", "pulse", "zap", "comet", "meteor", "speed", "magnet", "heart", "haste", "power"]


func reset() -> void:
	for b in bolts:
		b.node.visible = false
		bolt_pool.append(b.node)
	bolts.clear()
	for m in moons:
		m.queue_free()
	moons.clear()
	for c in comets:
		c.node.queue_free()
	comets.clear()
	for s in strikes:
		s.node.queue_free()
	strikes.clear()
	lv = {"bolt": 1}
	cd = {"bolt": 0.5, "pulse": 2.0, "zap": 1.0, "meteor": 1.5}
	dealt = {}
	moon_ang = 0.0


func card_info(id: String) -> Dictionary:
	var d: Dictionary = DEFS[id]
	var cur := level(id)
	var descs: Array = d.desc
	var passive: bool = d.get("passive", false)
	return {
		"id": id, "name": d.name, "icon": d.icon, "color": d.color,
		"from": cur, "to": cur + 1, "max": d.max, "passive": passive,
		"desc": descs[mini(cur, descs.size() - 1)], "is_new": cur == 0 and id != "feast",
	}


func roll_choices(n: int) -> Array[String]:
	var pool: Array[String] = []
	for id: String in ORDER:
		if level(id) < int(DEFS[id].max):
			pool.append(id)
	for i in range(pool.size() - 1, 0, -1):
		var j := g.rng.randi_range(0, i)
		var tmp := pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	var res: Array[String] = pool.slice(0, n)
	if res.is_empty():
		res.append("feast")
	return res


func apply(id: String) -> void:
	lv[id] = level(id) + 1
	match id:
		"heart":
			g.p_max_hp += 25.0
			g.player.heal(25.0)
		"feast":
			g.player.heal(40.0)
		"comet":
			_sync_comets()


func owned() -> Array[String]:
	var res: Array[String] = []
	for id: String in ORDER:
		if level(id) > 0:
			res.append(id)
	return res


func update(dt: float) -> void:
	_bolt(dt)
	_moon(dt)
	_pulse(dt)
	_zap(dt)
	_comet(dt)
	_meteor(dt)
