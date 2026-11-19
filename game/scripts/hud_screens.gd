class_name HudScreens
extends HudPlay
## タイトル、レベルアップのカード、ポーズ、結果の画面。

var title_box: Control
var title_prompt: Label
var title_best: Label
var title_diff: Label
var lvl_box: Control
var lvl_cards: HBoxContainer
var cards: Array[Panel] = []
var card_ids: Array[String] = []
var sel := 0
var pause_box: Control
var over_box: Control
var over_title: Label
var over_stats: Label
var over_note: Label
var over_diff: Label
var over_share: Button
var over_toast: Label
var share: Share
var share_text := ""
var _toast_tw: Tween

const DIFF_NAMES := ["やさしい", "ふつう", "むずかしい"]
const DIFF_COLORS := [Color("b9fbc0"), Color("ffe89a"), Color("ff9e9e")]


# ---------------------------------------------------------------- タイトル
func _build_title() -> void:
	title_box = _full(Control.new())
	root.add_child(title_box)
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.05, 0.0)
	_full(shade)
	title_box.add_child(shade)

	var logo := _centered(_label("ほしもり", 170, Color("ffe89a"), font_x, 28))
	logo.add_theme_color_override("font_outline_color", Color("2b2f77"))
	logo.add_theme_constant_override("shadow_offset_y", 8)
	logo.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.1, 0.6))
	logo.anchor_right = 1.0
	logo.anchor_top = 0.06
	logo.anchor_bottom = 0.06
	logo.offset_bottom = 230.0
	title_box.add_child(logo)
	var sub := _centered(_label("小さな星で、夜明けまで生きのびろ", 34, Color("dbe7ff"), font_b, 10))
	sub.anchor_right = 1.0
	sub.anchor_top = 0.06
	sub.anchor_bottom = 0.06
	sub.offset_top = 232.0
	sub.offset_bottom = 290.0
	title_box.add_child(sub)

	title_prompt = _centered(_label("スペース / Enter でスタート", 44, Color.WHITE, font_x, 12))
	title_prompt.anchor_right = 1.0
	title_prompt.anchor_top = 0.74
	title_prompt.anchor_bottom = 0.74
	title_prompt.offset_bottom = 60.0
	title_box.add_child(title_prompt)
	var help := _centered(_label("移動: WASD / 矢印キー     ダッシュ: スペース     攻撃は自動\nポーズ: Esc     全画面切替: F11     音を消す: M     ゲームパッド対応", 22, Color(0.85, 0.9, 1.0, 0.9), font_m, 6))
	help.anchor_right = 1.0
	help.anchor_top = 0.74
	help.anchor_bottom = 0.74
	help.offset_top = 74.0
	help.offset_bottom = 150.0
	title_box.add_child(help)
	title_diff = _centered(_label("", 30, Color("ffe89a"), font_x, 8))
	title_diff.anchor_right = 1.0
	title_diff.anchor_top = 0.74
	title_diff.anchor_bottom = 0.74
	title_diff.offset_top = -62.0
	title_diff.offset_bottom = -14.0
	title_box.add_child(title_diff)
	title_best = _centered(_label("", 24, Color("ffe89a"), font_b, 6))
	title_best.anchor_right = 1.0
	title_best.anchor_top = 1.0
	title_best.anchor_bottom = 1.0
	title_best.offset_top = -60.0
	title_best.offset_bottom = -20.0
	title_box.add_child(title_best)


func set_diff(d: int) -> void:
	title_diff.text = "むずかしさ   ←  %s  →" % DIFF_NAMES[d]
	title_diff.add_theme_color_override("font_color", DIFF_COLORS[d])


func set_best(best: Dictionary) -> void:
	if best.is_empty() or int(best.get("runs", 0)) == 0:
		title_best.text = ""
		return
	var tm := int(best.get("time", 0))
	var s := "これまでの記録   いちばん長く生きた時間 %d:%02d   たおした数 %d" % [tm / 60, tm % 60, int(best.get("kills", 0))]
	if int(best.get("wins", 0)) > 0:
		s += "   夜明けを見た回数 %d" % int(best.get("wins", 0))
	title_best.text = s


# ---------------------------------------------------------------- レベルアップ
func _build_levelup() -> void:
	lvl_box = _full(Control.new())
	root.add_child(lvl_box)
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.01, 0.08, 0.6)
	_full(shade)
	lvl_box.add_child(shade)
	var v := _center_col(lvl_box, 26)
	var head := _centered(_label("レベルアップ!", 70, Color("ffe89a"), font_x, 16))
	v.add_child(head)
	var sub := _centered(_label("あたらしい力をひとつ選ぼう", 28, Color("dbe7ff"), font_b, 8))
	v.add_child(sub)
	lvl_cards = HBoxContainer.new()
	lvl_cards.alignment = BoxContainer.ALIGNMENT_CENTER
	lvl_cards.add_theme_constant_override("separation", 34)
	v.add_child(lvl_cards)
	var hint := _centered(_label("← → でえらぶ   スペース / Enter で決定   1 2 3 キーやクリックでも選べる", 22, Color(0.85, 0.9, 1.0, 0.9), font_m, 6))
	v.add_child(hint)


func show_levelup(infos: Array) -> void:
	for c in lvl_cards.get_children():
		c.queue_free()
	cards.clear()
	card_ids.clear()
	for i in infos.size():
		var info: Dictionary = infos[i]
		var col: Color = info.color
		var card := Panel.new()
		card.custom_minimum_size = Vector2(340, 440)
		card.pivot_offset = Vector2(170, 220)
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		card.mouse_entered.connect(_on_card_hover.bind(i))
		card.gui_input.connect(_on_card_input.bind(i))
		var key := _centered(_label(str(i + 1), 22, Color(0.8, 0.85, 1.0, 0.8), font_b, 4))
		key.position = Vector2(16, 10)
		card.add_child(key)
		var icon := Panel.new()
		icon.add_theme_stylebox_override("panel", _box(col, 65))
		icon.position = Vector2(105, 34)
		icon.size = Vector2(130, 130)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(icon)
		var ch := _centered(_label(info.icon, 76, Color("1c2148"), font_x, 0))
		ch.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		ch.size = Vector2(130, 130)
		icon.add_child(ch)
		var nm := _centered(_label(info.name, 36, Color.WHITE, font_x, 8))
		nm.position = Vector2(0, 178)
		nm.size = Vector2(340, 50)
		card.add_child(nm)
		var lt := ""
		var lc := Color("ffe066")
		if info.id == "feast":
			lt = "おやつ"
		elif info.is_new:
			lt = "NEW!"
		elif int(info.to) >= int(info.max):
			lt = "Lv %d → MAX" % int(info.from)
			lc = Color("ffb3c1")
		else:
			lt = "Lv %d → %d" % [int(info.from), int(info.to)]
			lc = Color("a5d8ff")
		var ll := _centered(_label(lt, 26, lc, font_x, 6))
		ll.position = Vector2(0, 230)
		ll.size = Vector2(340, 38)
		card.add_child(ll)
		var ds := _centered(_label(info.desc, 24, Color("e3ebff"), font_b, 4))
		ds.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
		ds.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		ds.position = Vector2(26, 276)
		ds.size = Vector2(288, 140)
		card.add_child(ds)
		lvl_cards.add_child(card)
		cards.append(card)
		card_ids.append(info.id)
		card.scale = Vector2(0.6, 0.6)
		card.modulate.a = 0.0
		var tw := create_tween().set_parallel(true)
		tw.tween_property(card, "scale", Vector2.ONE, 0.28).set_delay(0.06 * i).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(card, "modulate:a", 1.0, 0.18).set_delay(0.06 * i)
	sel = mini(1, infos.size() - 1)
	_style_cards()
	lvl_box.visible = true


func _style_cards() -> void:
	for i in cards.size():
		var on := i == sel
		var col: Color = Weapons.DEFS[card_ids[i]].color
		cards[i].add_theme_stylebox_override("panel", _box(
			Color(0.13, 0.16, 0.36, 0.97) if on else Color(0.07, 0.09, 0.22, 0.94), 26,
			6 if on else 3, col if on else Color(col.r, col.g, col.b, 0.35)))
		cards[i].z_index = 1 if on else 0


func move_sel(d: int) -> void:
	if cards.is_empty():
		return
	sel = posmod(sel + d, cards.size())
	_style_cards()
	Sfx.play("hover", -3.0)
	var tw := create_tween()
	tw.tween_property(cards[sel], "scale", Vector2(1.06, 1.06), 0.07)
	tw.tween_property(cards[sel], "scale", Vector2.ONE, 0.1)


func _on_card_hover(i: int) -> void:
	if i != sel and i < cards.size():
		sel = i
		_style_cards()
		Sfx.play("hover", -8.0)


func _on_card_input(ev: InputEvent, i: int) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		main.pick(i)


# ---------------------------------------------------------------- ポーズ
func _build_pause() -> void:
	pause_box = _full(Control.new())
	root.add_child(pause_box)
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.01, 0.08, 0.65)
	_full(shade)
	pause_box.add_child(shade)
	var v := _center_col(pause_box, 22)
	v.add_child(_centered(_label("ひとやすみ", 80, Color("ffe89a"), font_x, 16)))
	v.add_child(_centered(_label("Esc / P : つづける\nR : はじめからやりなおす\nT : タイトルにもどる", 30, Color("e3ebff"), font_b, 8)))


# ---------------------------------------------------------------- 結果
func _build_over() -> void:
	share = Share.new()
	add_child(share)
	share.finished.connect(_on_share_finished)
	over_box = _full(Control.new())
	root.add_child(over_box)
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.01, 0.08, 0.55)
	_full(shade)
	over_box.add_child(shade)
	var v := _center_col(over_box, 20)
	over_title = _centered(_label("", 96, Color("ffe89a"), font_x, 20))
	v.add_child(over_title)
	over_note = _centered(_label("", 30, Color("ffd6a5"), font_b, 8))
	v.add_child(over_note)
	over_diff = _centered(_label("", 32, Color("ffe89a"), font_x, 8))
	v.add_child(over_diff)
	over_stats = _centered(_label("", 36, Color("e3ebff"), font_b, 8))
	v.add_child(over_stats)
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 16)
	v.add_child(sp)
	v.add_child(_centered(_label("スペース / Enter : もういちど     Esc : タイトルへ", 30, Color.WHITE, font_x, 8)))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 24)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(row)
	row.add_child(_share_button("X で共有   [X]", "x"))
	over_share = _share_button("", "share")
	row.add_child(over_share)
	over_toast = _centered(_label("", 24, Color("b9fbc0"), font_b, 6))
	over_toast.custom_minimum_size = Vector2(0, 34)
	v.add_child(over_toast)


func _share_button(text: String, kind: String) -> Button:
	var b := Button.new()
	b.text = text
	# フォーカスを持たせない。持つと スペース / Enter をボタンが取り、「もういちど」が効かなくなる
	b.focus_mode = Control.FOCUS_NONE
	# 押した瞬間に予約し、離した時の DOM イベントの中で開く(Share の説明)
	b.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	b.custom_minimum_size = Vector2(220, 52)
	b.add_theme_font_override("font", font_b)
	b.add_theme_font_size_override("font_size", 24)
	b.add_theme_color_override("font_color", Color("e3ebff"))
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color("ffe89a"))
	b.add_theme_stylebox_override("normal", _box(Color(0.07, 0.09, 0.22, 0.85), 14, 2, Color(0.75, 0.82, 1.0, 0.45)))
	b.add_theme_stylebox_override("hover", _box(Color(0.13, 0.16, 0.36, 0.95), 14, 2, Color(0.85, 0.9, 1.0, 0.85)))
	b.add_theme_stylebox_override("pressed", _box(Color(0.18, 0.2, 0.42, 0.95), 14, 2, Color("ffe89a")))
	b.pressed.connect(func() -> void: main.share_result(kind, true))
	return b


func show_over(victory: bool, g: Game, new_record: bool) -> void:
	var tm := int(g.elapsed)
	var dname: String = DIFF_NAMES[g.difficulty]
	if victory:
		over_title.text = "夜が明けた!"
		over_title.add_theme_color_override("font_color", Color("ffe89a"))
		over_note.text = "星は守られた。おつかれさま!"
		share_text = "ほしもり「%s」で夜明けを迎えた！ %d:%02d / Lv.%d / 撃破 %d" % [dname, tm / 60, tm % 60, g.level, g.kills]
	else:
		over_title.text = "力つきた…"
		over_title.add_theme_color_override("font_color", Color("b9c6ff"))
		var remain := maxf(Game.NIGHT_LEN - g.elapsed, 0.0)
		if remain <= 0.0:
			over_note.text = "夜明けは目の前だった…!"
		else:
			over_note.text = "夜明けまで、あと %d:%02d" % [int(remain) / 60, int(remain) % 60]
		share_text = "ほしもり「%s」%d:%02d で力尽きた… / Lv.%d / 撃破 %d" % [dname, tm / 60, tm % 60, g.level, g.kills]
	if new_record:
		over_note.text += "   ★ 新記録!"
	over_diff.text = "むずかしさ   %s" % dname
	over_diff.add_theme_color_override("font_color", DIFF_COLORS[g.difficulty])
	over_stats.text = "%s   %d:%02d\nたおした数   %d\nレベル   %d" % ["プレイ時間" if victory else "生きのびた時間", tm / 60, tm % 60, g.kills, g.level]
	over_share.text = "共有   [C]" if share.can_share() else "コピー   [C]"
	over_toast.text = ""
	over_box.visible = true
	over_box.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(over_box, "modulate:a", 1.0, 0.5)


func run_share(kind: String, wait: bool) -> void:
	share.run(kind, share_text, wait)


func _on_share_finished(result: String) -> void:
	var msg: String = {
		"opened": "X の投稿画面を開いた",
		"shared": "共有した",
		"copied": "文面をコピーした",
		"blocked": "新しいタブを開けなかった(ポップアップが止められた)",
		"failed": "共有できなかった",
	}.get(result, "")
	if msg == "":
		return
	Sfx.play("select", -6.0)
	over_toast.text = msg
	over_toast.modulate.a = 1.0
	if _toast_tw != null:
		_toast_tw.kill()
	_toast_tw = create_tween()
	_toast_tw.tween_interval(2.0)
	_toast_tw.tween_property(over_toast, "modulate:a", 0.0, 0.6)
