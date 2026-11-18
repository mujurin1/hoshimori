extends Node
## 効果音とBGM。ファイルが無くても黙って動く。

const SFX_DIR := "res://audio/sfx/"
const MUSIC_DIR := "res://audio/music/"
const NAMES := ["shoot", "hit", "enemy_die", "gem", "levelup", "select", "hover", "hurt", "dash",
	"shockwave", "lightning", "explosion", "comet", "moon_hit", "heal", "pickup_special",
	"spawn_elite", "boss_warn", "boss_die", "enemy_shoot", "gameover", "victory"]

var streams := {}
var players: Array[AudioStreamPlayer] = []
var last_ms := {}
var music_players: Array[AudioStreamPlayer] = []
var music_idx := 0
var current_music := ""
var muted := false
var _pi := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for n: String in NAMES:
		var path := SFX_DIR + n + ".wav"
		if ResourceLoader.exists(path):
			streams[n] = load(path)
	for i in 20:
		var p := AudioStreamPlayer.new()
		add_child(p)
		players.append(p)
	for i in 2:
		var m := AudioStreamPlayer.new()
		m.volume_db = -60.0
		add_child(m)
		music_players.append(m)


func play(n: String, vol_db := 0.0, pitch := 1.0, min_gap_ms := 45) -> void:
	if not streams.has(n):
		return
	var now := Time.get_ticks_msec()
	if now - int(last_ms.get(n, -100000)) < min_gap_ms:
		return
	last_ms[n] = now
	var p := players[_pi]
	_pi = (_pi + 1) % players.size()
	p.stream = streams[n]
	p.volume_db = vol_db
	p.pitch_scale = pitch
	p.play()


func music(n: String, vol_db := -7.0, fade := 1.2) -> void:
	if n == current_music:
		return
	current_music = n
	var old := music_players[music_idx]
	music_idx = 1 - music_idx
	var cur := music_players[music_idx]
	if old.playing:
		var tw := create_tween()
		tw.tween_property(old, "volume_db", -60.0, fade)
		tw.tween_callback(old.stop)
	var path := MUSIC_DIR + n + ".ogg"
	if n == "" or not ResourceLoader.exists(path):
		return
	var s: AudioStream = load(path)
	if s is AudioStreamOggVorbis:
		(s as AudioStreamOggVorbis).loop = true
	cur.stream = s
	cur.volume_db = -40.0
	cur.play()
	var tw2 := create_tween()
	tw2.tween_property(cur, "volume_db", vol_db, fade)


func toggle_mute() -> bool:
	muted = not muted
	AudioServer.set_bus_mute(0, muted)
	return muted
