class_name Mumble
extends AudioStreamPlayer
## Placeholder voice: generated "mumbling" syllables, pitched per character, until real dubbing exists.

const RATE := 22050.0
const GAP := 0.035

var _playback: AudioStreamGeneratorPlayback
var _remaining := 0.0
var _pitch := 220.0
var _syllable_len := 0.1
var _syllable_t := 0.0
var _freq := 220.0
var _phase := 0.0


func _ready() -> void:
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = RATE
	gen.buffer_length = 0.2
	stream = gen
	volume_db = -10.0


## Speaks for a time based on the text length. A pitch of 0 means silent (narrator).
func speak(text: String, pitch: float) -> void:
	if pitch <= 0.0:
		return
	_pitch = pitch
	_remaining = clampf(text.length() * 0.045, 0.3, 4.0)
	_syllable_t = _syllable_len + GAP
	if not playing:
		play()
		_playback = get_stream_playback()


func silence() -> void:
	_remaining = 0.0


func _process(_delta: float) -> void:
	if not playing or _playback == null:
		return
	for i in _playback.get_frames_available():
		var sample := 0.0
		if _syllable_t >= _syllable_len + GAP and _remaining > 0.0:
			_syllable_t = 0.0
			_syllable_len = randf_range(0.07, 0.13)
			_freq = _pitch * randf_range(0.85, 1.25)
		if _syllable_t < _syllable_len:
			var env := sin(PI * _syllable_t / _syllable_len)
			_phase = fmod(_phase + _freq / RATE, 1.0)
			var square := 1.0 if _phase < 0.5 else -1.0
			sample = (sin(TAU * _phase) * 0.7 + square * 0.12) * env * 0.35
		_syllable_t += 1.0 / RATE
		_remaining -= 1.0 / RATE
		_playback.push_frame(Vector2(sample, sample))
