extends Node

# Separate players for music and SFX
var music_player: AudioStreamPlayer
var sfx_players: Array = []
var music_looping = false


func _ready():
	# Music player
	music_player = AudioStreamPlayer.new()
	add_child(music_player)

	# Pre-create multiple SFX players for overlapping sounds
	for i in range(5):
		var p = AudioStreamPlayer.new()
		add_child(p)
		sfx_players.append(p)

# Play a sound effect
func play_sfx(sound: AudioStream):
	for p in sfx_players:
		if not p.playing:
			p.stream = sound
			p.play()
			return
	# If all busy, reuse the first one
	sfx_players[0].stop()
	sfx_players[0].stream = sound
	sfx_players[0].play()

# Play music
var _last_music: AudioStream = null
var _music_looping = false
var _last_music_volume := 1.0

func play_music(sound: AudioStream, loop := true, volume := 1.0):
	_last_music = sound
	_music_looping = loop
	_last_music_volume = volume

	music_player.stream = sound

	if volume <= 0.0001:
		music_player.volume_db = -80
	else:
		music_player.volume_db = linear_to_db(volume)

	var handler = Callable(self, "_on_music_finished")
	if music_player.is_connected("finished", handler):
		music_player.disconnect("finished", handler)
	music_player.connect("finished", handler)

	music_player.play()

func _on_music_finished():
	if _music_looping:
		play_music(_last_music, true, _last_music_volume)
