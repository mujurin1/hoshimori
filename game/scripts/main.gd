extends Node3D
## 全体の進行役:タイトル → プレイ → レベルアップ → 結果。

enum St { TITLE, PLAY, LEVELUP, PAUSE, OVER }

const SAVE_PATH := "user://hoshimori_save.json"

var st := St.TITLE
var world: World
var game: Game
var hud: Hud
var best := {}
var lock_until := 0
var choices: Array[String] = []

# 自動テスト用(コマンドライン引数)
var a_bot := false
var a_shots := ""
var a_shot_every := 20.0
var a_until := 0.0
var a_log := false
var a_next_shot := 0.0
var a_next_log := 0.0
var a_pick_at := 0
var a_quit := false
var a_lvl_shots := 0
var a_start_at := 0


func _ready() -> void:
	world = World.new()
	add_child(world)
	game = Game.new()
	game.main = self
	game.world = world
	add_child(game)
	hud = Hud.new()
	hud.main = self
	add_child(hud)
	_load_best()
	_parse_args()
	goto_title()
	if a_bot:
		a_start_at = Time.get_ticks_msec() + (1800 if a_shots != "" else 100)
		if a_shots != "":
			_shot_later("title", 1.0)


func _parse_args() -> void:
	for a in OS.get_cmdline_user_args():
		if a == "--bot":
			a_bot = true
		elif a == "--god":
			game.god = true
		elif a == "--log":
			a_log = true
		elif a == "--quit":
			a_quit = true
		elif a.begins_with("--shots="):
			a_shots = a.substr(8)
			DirAccess.make_dir_recursive_absolute(a_shots)
		elif a.begins_with("--every="):
			a_shot_every = float(a.substr(8))
		elif a.begins_with("--until="):
			a_until = float(a.substr(8))
		elif a.begins_with("--speed="):
			Engine.time_scale = float(a.substr(8))
		elif a.begins_with("--diff="):
			game.difficulty = int(a.substr(7))
		elif a.begins_with("--botlag="):
			game.bot_lag = int(a.substr(9))
		elif a.begins_with("--seed="):
			game.rng.seed = int(a.substr(7))
	game.bot = a_bot


func is_title() -> bool:
	return st == St.TITLE


# ---------------------------------------------------------------- 状態の切り替え
func goto_title() -> void:
	st = St.TITLE
	game.reset()
	game.running = false
	hud.set_best(best)
	hud.set_diff(game.difficulty)
	hud.show_state(true, false, false, false, false)
	Sfx.music("title", -6.0)


func start_game() -> void:
	st = St.PLAY
	game.reset()
	hud.chips_sig = ""
	hud.show_state(false, true, false, false, false)
	Sfx.play("select", -4.0)
	Sfx.music("game", -8.0)
	a_next_shot = 5.0
	a_next_log = 30.0


func _open_levelup() -> void:
	st = St.LEVELUP
	game.running = false
	game.pending_levels -= 1
	choices = game.weapons.roll_choices(3)
	var infos := []
	for id in choices:
		infos.append(game.weapons.card_info(id))
	hud.update_play(game)
	hud.show_state(false, true, true, false, false)
	hud.show_levelup(infos)
	Sfx.play("levelup", -4.0)
	lock_until = Time.get_ticks_msec() + 450
	a_pick_at = Time.get_ticks_msec() + (900 if a_shots != "" and a_lvl_shots < 3 else 30)
	if a_shots != "" and a_lvl_shots < 3:
		a_lvl_shots += 1
		_shot_later("levelup_%d" % a_lvl_shots, 0.6)


func pick(i: int) -> void:
	if st != St.LEVELUP or Time.get_ticks_msec() < lock_until:
		return
	if i < 0 or i >= choices.size():
		return
	game.weapons.apply(choices[i])
	Sfx.play("select", -4.0)
	if game.pending_levels > 0:
		_open_levelup()
		return
	st = St.PLAY
	game.running = true
	game.p_iframe = maxf(game.p_iframe, 0.6)
	hud.show_state(false, true, false, false, false)


func toggle_pause() -> void:
	if st == St.PLAY:
		st = St.PAUSE
		game.running = false
		hud.show_state(false, true, false, true, false)
	elif st == St.PAUSE:
		st = St.PLAY
		game.running = true
		hud.show_state(false, true, false, false, false)


func on_game_over(victory: bool) -> void:
	st = St.OVER
	var new_record := false
	var tm := int(game.elapsed)
	if int(best.get("runs", 0)) > 0 and (tm > int(best.get("time", 0)) or (victory and int(best.get("wins", 0)) == 0)):
		new_record = true
	best["runs"] = int(best.get("runs", 0)) + 1
	best["time"] = maxi(int(best.get("time", 0)), tm)
	best["kills"] = maxi(int(best.get("kills", 0)), game.kills)
	if victory:
		best["wins"] = int(best.get("wins", 0)) + 1
		Sfx.play("victory", -2.0)
	_save_best()
	hud.update_play(game)
	hud.show_state(false, true, false, false, true)
	hud.show_over(victory, game, new_record)
	lock_until = Time.get_ticks_msec() + 900
	if a_log:
		_log_line("END victory=%s" % str(victory))
	if a_shots != "":
		_shot_later("over", 1.0)
	if a_quit:
		get_tree().create_timer(1.6, true, false, true).timeout.connect(get_tree().quit)


func on_player_hurt() -> void:
	hud.flash_hurt()


func banner(text: String, color: Color, dur := 2.6) -> void:
	hud.banner(text, color, dur)


# ---------------------------------------------------------------- 入力
func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and not ev.echo:
		_key((ev as InputEventKey).keycode)
	elif ev is InputEventJoypadButton and ev.pressed:
		match (ev as InputEventJoypadButton).button_index:
			JOY_BUTTON_A:
				_key(KEY_SPACE)
			JOY_BUTTON_START:
				_key(KEY_ESCAPE if st != St.TITLE and st != St.OVER else KEY_SPACE)
			JOY_BUTTON_DPAD_LEFT:
				_key(KEY_LEFT)
			JOY_BUTTON_DPAD_RIGHT:
				_key(KEY_RIGHT)
			JOY_BUTTON_B:
				if st == St.PLAY:
					game.request_dash()


func _key(k: Key) -> void:
	if k == KEY_F11:
		var w := get_window()
		w.mode = Window.MODE_MAXIMIZED if w.mode == Window.MODE_FULLSCREEN else Window.MODE_FULLSCREEN
		return
	if k == KEY_M:
		Sfx.toggle_mute()
		return
	var confirm := k == KEY_SPACE or k == KEY_ENTER or k == KEY_KP_ENTER
	match st:
		St.TITLE:
			if confirm:
				start_game()
			elif k == KEY_ESCAPE and not OS.has_feature("web"):
				get_tree().quit()
			elif k == KEY_LEFT or k == KEY_A or k == KEY_RIGHT or k == KEY_D:
				game.difficulty = clampi(game.difficulty + (-1 if k == KEY_LEFT or k == KEY_A else 1), 0, 2)
				best["diff"] = game.difficulty
				hud.set_diff(game.difficulty)
				Sfx.play("hover", -6.0)
				_save_best()
		St.PLAY:
			if k == KEY_ESCAPE or k == KEY_P:
				toggle_pause()
			elif k == KEY_SPACE or k == KEY_SHIFT:
				game.request_dash()
		St.LEVELUP:
			if k == KEY_LEFT or k == KEY_A:
				hud.move_sel(-1)
			elif k == KEY_RIGHT or k == KEY_D:
				hud.move_sel(1)
			elif confirm:
				pick(hud.sel)
			elif k == KEY_1 or k == KEY_KP_1:
				pick(0)
			elif k == KEY_2 or k == KEY_KP_2:
				pick(1)
			elif k == KEY_3 or k == KEY_KP_3:
				pick(2)
		St.PAUSE:
			if k == KEY_ESCAPE or k == KEY_P:
				toggle_pause()
			elif k == KEY_R:
				start_game()
			elif k == KEY_T:
				goto_title()
		St.OVER:
			if Time.get_ticks_msec() < lock_until:
				return
			if confirm:
				start_game()
			elif k == KEY_ESCAPE:
				goto_title()


var _stick_x := 0


func _process(_dt: float) -> void:
	if st == St.PLAY:
		hud.update_play(game)
		if game.pending_levels > 0 and game.alive and not game.ending:
			_open_levelup()
	elif st == St.LEVELUP:
		# スティックでカード選択
		var x := Input.get_joy_axis(0, JOY_AXIS_LEFT_X)
		var sx := 1 if x > 0.6 else (-1 if x < -0.6 else 0)
		if sx != _stick_x:
			_stick_x = sx
			if sx != 0:
				hud.move_sel(sx)
	_auto()


# ---------------------------------------------------------------- 記録
func _load_best() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var d: Variant = JSON.parse_string(f.get_as_text())
	if d is Dictionary:
		best = d
		game.difficulty = clampi(int(best.get("diff", 1)), 0, 2)


func _save_best() -> void:
	if a_bot:
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(best))


# ---------------------------------------------------------------- 自動テスト
func _auto() -> void:
	if not a_bot:
		return
	var now := Time.get_ticks_msec()
	if st == St.TITLE and now >= a_start_at:
		start_game()
	elif st == St.LEVELUP and now >= a_pick_at:
		lock_until = 0
		# 武器を優先して取る、ほどほどに賢いボット
		var bi := 0
		var bs := -1.0
		for i in choices.size():
			var id := choices[i]
			var sc := game.rng.randf()
			if not Weapons.DEFS[id].get("passive", false):
				sc += 0.6
			if sc > bs:
				bs = sc
				bi = i
		pick(bi)
	elif st == St.PLAY:
		if a_shots != "" and game.elapsed >= a_next_shot:
			a_next_shot += a_shot_every
			_shot("play_%04d" % int(game.elapsed))
		if a_log and game.elapsed >= a_next_log:
			a_next_log += 30.0
			_log_line("")
		if a_until > 0.0 and game.elapsed >= a_until:
			_log_line("UNTIL")
			get_tree().quit()


func _log_line(tag: String) -> void:
	var w := ""
	for id in game.weapons.owned():
		w += "%s%d " % [id, game.weapons.level(id)]
	var dd := ""
	for k: String in game.weapons.dealt:
		dd += "%s=%d " % [k, int(game.weapons.dealt[k])]
	print("[%s] t=%d lv=%d kills=%d alive=%d gems=%d hp=%d/%d fps=%d | %s| dealt: %s" % [
		tag, int(game.elapsed), game.level, game.kills, game.enemies.size(), game.gems.size(),
		int(game.p_hp), int(game.p_max_hp), int(Engine.get_frames_per_second()), w, dd])


func _shot_later(shot_name: String, delay: float) -> void:
	get_tree().create_timer(delay, true, false, true).timeout.connect(_shot.bind(shot_name))


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(a_shots.path_join(shot_name + ".png"))
