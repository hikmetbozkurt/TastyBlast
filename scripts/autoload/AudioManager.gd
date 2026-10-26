## Audio Manager — Autoload Singleton
## Handles all music and SFX playback. Supports per-cuisine-region music
## switching, fallback procedural audio generation (plays synth sound effects
## when .ogg files are not yet present), and respects mute settings from SaveManager.
class_name AudioManagerClass
extends Node


## Emitted when background music changes.
signal music_changed(track_path: String)


## Dictionary mapping track names/keys to their file paths.
const MUSIC_TRACKS: Dictionary = {
	"main_menu": "res://assets/audio/music/main_theme.ogg",
	"world_map": "res://assets/audio/music/world_map_theme.ogg",
	"italy": "res://assets/audio/music/italy_theme.ogg",
	"france": "res://assets/audio/music/france_theme.ogg",
	"mexico": "res://assets/audio/music/mexico_theme.ogg",
	"japan": "res://assets/audio/music/japan_theme.ogg",
	"india": "res://assets/audio/music/india_theme.ogg",
	"turkey": "res://assets/audio/music/turkey_theme.ogg",
}

## Dictionary mapping SFX keys to their file paths.
const SFX_TRACKS: Dictionary = {
	"fail": "res://assets/audio/sfx/fail.ogg",
	"game_over": "res://assets/audio/sfx/game_over.ogg",
	"success": "res://assets/audio/sfx/success.ogg",
	"success_combo": "res://assets/audio/sfx/success_combo.ogg",
	"ui_click": "res://assets/audio/sfx/ui_click.ogg",
	"unlock_map": "res://assets/audio/sfx/unlock_map.ogg",
}

## Currently playing music track path (empty if none).
var _current_music_track: String = ""

## Audio players.
var _music_player: AudioStreamPlayer = null
var _sfx_player: AudioStreamPlayer = null

## SFX stream cache for zero-latency playback.
var _sfx_stream_cache: Dictionary = {}

## Procedural synth sound cache.
var _synth_sfx_cache: Dictionary = {}


func _ready() -> void:
	_ensure_audio_buses()
	_setup_audio_players()
	_apply_music_volume()
	if SaveManager.has_signal("save_loaded"):
		SaveManager.save_loaded.connect(_on_save_loaded)


func _on_save_loaded() -> void:
	_apply_music_volume()


## Play a music track by name key ("main_menu", "italy", etc.) or full resource path.
## If the requested track is already playing, it will continue uninterrupted.
func play_music(track_name_or_path: String) -> void:
	var track_path: String = track_name_or_path
	if MUSIC_TRACKS.has(track_name_or_path):
		track_path = MUSIC_TRACKS[track_name_or_path]

	# Do not restart if the exact same track is already playing
	if track_path == _current_music_track and _music_player != null and _music_player.playing:
		return

	_current_music_track = track_path

	if not _is_music_enabled():
		return

	if not ResourceLoader.exists(track_path):
		push_warning("AudioManager: Music track file not found: %s" % track_path)
		return

	var stream := load(track_path) as AudioStream
	if stream == null:
		push_warning("AudioManager: Could not load music: %s" % track_path)
		return

	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true

	_apply_music_volume()
	_music_player.stream = stream
	_music_player.play()
	music_changed.emit(track_path)


## Stop the currently playing music.
func stop_music() -> void:
	if _music_player != null:
		_music_player.stop()


## Play a named SFX (e.g. "fail", "game_over", "success", "success_combo", "ui_click", "unlock_map").
func play_sfx(sfx_name: String) -> void:
	if not _is_sfx_enabled():
		return

	var sfx_path: String = sfx_name
	if SFX_TRACKS.has(sfx_name):
		sfx_path = SFX_TRACKS[sfx_name]
	else:
		# Fallback / legacy aliases
		match sfx_name:
			"button_tap", "button", "tap", "click":
				sfx_path = SFX_TRACKS["ui_click"]
			"piece_place_valid", "place_valid", "place", "snap":
				sfx_path = SFX_TRACKS["success"]
			"piece_place_invalid", "place_invalid", "invalid", "drop_invalid":
				sfx_path = SFX_TRACKS["fail"]
			"line_clear", "combo_clear", "combo", "clear":
				sfx_path = SFX_TRACKS["success_combo"]
			"game_over_sfx":
				sfx_path = SFX_TRACKS["game_over"]
			"region_unlocked", "unlock":
				sfx_path = SFX_TRACKS["unlock_map"]

	var stream: AudioStream = null
	if _sfx_stream_cache.has(sfx_path):
		stream = _sfx_stream_cache[sfx_path]
	elif ResourceLoader.exists(sfx_path):
		stream = load(sfx_path) as AudioStream
		if stream != null:
			if stream is AudioStreamOggVorbis:
				(stream as AudioStreamOggVorbis).loop = false
			_sfx_stream_cache[sfx_path] = stream

	if stream == null:
		# Procedural fallback
		var key_name: String = sfx_name.get_file().get_basename()
		stream = _get_or_create_synth_sfx(key_name)

	if stream == null or _sfx_player == null:
		return

	_sfx_player.stream = stream
	_sfx_player.play()


## Switch music to match a cuisine region.
func switch_region_music(region_id_or_track: String) -> void:
	play_music(region_id_or_track)


## Set the music volume using a 0-100 linear scale, apply to AudioServer, and persist.
func set_music_volume(value: float) -> void:
	var clamped_value: float = clampf(value, 0.0, 100.0)
	SaveManager.set_setting("music_volume", clamped_value)
	_apply_music_volume()


## Get the current music volume setting (0-100 linear scale).
func get_music_volume() -> float:
	return float(SaveManager.get_setting("music_volume", 70.0))


## Apply current volume and mute settings to the Music audio bus in Decibels (dB).
func _apply_music_volume() -> void:
	var bus_idx: int = AudioServer.get_bus_index("Music")
	if bus_idx == -1:
		return

	var volume_val: float = get_music_volume()
	var linear_volume: float = clampf(volume_val / 100.0, 0.0, 1.0)
	var db_volume: float = linear_to_db(linear_volume)
	AudioServer.set_bus_volume_db(bus_idx, db_volume)

	var is_enabled: bool = _is_music_enabled()
	AudioServer.set_bus_mute(bus_idx, not is_enabled)


## Toggle music mute and persist the setting.
func set_music_mute(muted: bool) -> void:
	SaveManager.set_setting("music_enabled", not muted)
	_apply_music_volume()
	if muted:
		stop_music()
	else:
		if not _current_music_track.is_empty():
			play_music(_current_music_track)


## Toggle SFX mute and persist the setting.
func set_sfx_mute(muted: bool) -> void:
	SaveManager.set_setting("sfx_enabled", not muted)
	var sfx_bus_idx: int = AudioServer.get_bus_index("SFX")
	if sfx_bus_idx != -1:
		AudioServer.set_bus_mute(sfx_bus_idx, muted)
	if muted and _sfx_player != null:
		_sfx_player.stop()


## Check if music is currently enabled.
func _is_music_enabled() -> bool:
	return SaveManager.get_setting("music_enabled", true)


## Check if SFX are currently enabled.
func _is_sfx_enabled() -> bool:
	return SaveManager.get_setting("sfx_enabled", true)


## Ensure dedicated Music and SFX audio buses exist in AudioServer.
func _ensure_audio_buses() -> void:
	var music_idx: int = AudioServer.get_bus_index("Music")
	if music_idx == -1:
		AudioServer.add_bus()
		music_idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(music_idx, "Music")
		AudioServer.set_bus_send(music_idx, "Master")

	var sfx_idx: int = AudioServer.get_bus_index("SFX")
	if sfx_idx == -1:
		AudioServer.add_bus()
		sfx_idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(sfx_idx, "SFX")
		AudioServer.set_bus_send(sfx_idx, "Master")


## Create the audio player nodes.
func _setup_audio_players() -> void:
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Music"
	add_child(_music_player)

	_sfx_player = AudioStreamPlayer.new()
	_sfx_player.bus = "SFX"
	_sfx_player.max_polyphony = 16
	add_child(_sfx_player)


## Procedurally generate simple audio tones for placeholder SFX.
func _get_or_create_synth_sfx(key: String) -> AudioStreamWAV:
	if _synth_sfx_cache.has(key):
		return _synth_sfx_cache[key]

	var stream: AudioStreamWAV = null

	match key:
		"piece_pickup", "pickup":
			stream = _generate_tone(440.0, 0.08, 0.4)
		"piece_place_valid", "place_valid", "place":
			stream = _generate_tone(587.33, 0.1, 0.5)
		"piece_place_invalid", "place_invalid", "invalid":
			stream = _generate_tone(150.0, 0.15, 0.5)
		"line_clear", "clear":
			stream = _generate_arpeggio([523.25, 659.25, 783.99], 0.25, 0.6)
		"combo_clear", "combo":
			stream = _generate_arpeggio([523.25, 659.25, 783.99, 1046.50], 0.35, 0.7)
		"game_over":
			stream = _generate_arpeggio([440.0, 349.23, 293.66], 0.5, 0.6)
		"button_tap", "button":
			stream = _generate_tone(800.0, 0.04, 0.3)
		_:
			stream = _generate_tone(440.0, 0.1, 0.4)

	_synth_sfx_cache[key] = stream
	return stream


## Generate a single frequency sine-wave tone byte array.
func _generate_tone(freq: float, duration: float, volume: float) -> AudioStreamWAV:
	var sample_rate: int = 22050
	var num_samples: int = int(sample_rate * duration)
	var data := PackedByteArray()
	data.resize(num_samples)

	for i in range(num_samples):
		var t: float = float(i) / float(sample_rate)
		# Apply smooth attack and decay envelope
		var envelope: float = sin(PI * (float(i) / float(num_samples)))
		var val: float = sin(2.0 * PI * freq * t) * envelope * volume
		var byte_val: int = int(clampi(int((val + 1.0) * 127.5), 0, 255))
		data[i] = byte_val

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = sample_rate
	stream.data = data
	return stream


## Generate an arpeggio chord sequence byte array.
func _generate_arpeggio(freqs: Array, duration: float, volume: float) -> AudioStreamWAV:
	var sample_rate: int = 22050
	var num_samples: int = int(sample_rate * duration)
	var data := PackedByteArray()
	data.resize(num_samples)
	var note_count: int = freqs.size()

	for i in range(num_samples):
		var t: float = float(i) / float(sample_rate)
		var note_idx: int = mini(int((float(i) / float(num_samples)) * note_count), note_count - 1)
		var freq: float = float(freqs[note_idx])
		var envelope: float = sin(PI * (float(i) / float(num_samples)))
		var val: float = sin(2.0 * PI * freq * t) * envelope * volume
		var byte_val: int = int(clampi(int((val + 1.0) * 127.5), 0, 255))
		data[i] = byte_val

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = sample_rate
	stream.data = data
	return stream
