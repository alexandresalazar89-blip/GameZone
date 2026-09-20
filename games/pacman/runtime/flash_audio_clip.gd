extends RefCounted
class_name PacmanFlashAudioClip

var clip: PacmanFlashMovieClip
var audio_scope: GameAudioScope
var streams_by_label: Dictionary = {}
var last_player: AudioStreamPlayer


func configure(
	movie_clip: PacmanFlashMovieClip,
	scope: GameAudioScope,
	label_streams: Dictionary
) -> void:
	clip = movie_clip
	audio_scope = scope
	streams_by_label = label_streams.duplicate()


func gotoAndPlay(label: StringName) -> AudioStreamPlayer:
	if clip == null or not clip.gotoAndPlay(label):
		return null
	var stream: AudioStream = streams_by_label.get(str(label)) as AudioStream
	if stream == null or audio_scope == null:
		return null
	last_player = audio_scope.play_stream(stream)
	return last_player


func gotoAndStop(label: StringName) -> bool:
	return clip != null and clip.gotoAndStop(label)
