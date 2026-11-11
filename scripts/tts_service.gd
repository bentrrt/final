extends Node

var voice_id := ""
var voice_name := ""
var available := false
var rate := 0.9
var last_text := ""
var utterance_id := 0


func _ready() -> void:
	_refresh_voice()


func _refresh_voice() -> void:
	var voices := DisplayServer.tts_get_voices()
	if voices.is_empty():
		available = false
		return

	var display_names: Dictionary = {}
	for voice in voices:
		if voice is Dictionary:
			display_names[String(voice.get("id", ""))] = String(voice.get("name", ""))

	var english_voices := DisplayServer.tts_get_voices_for_language("en")
	var chosen := ""

	for id in english_voices:
		var id_text := String(id)
		var display := String(display_names.get(id_text, ""))
		if display.to_lower() == "english (great britain)":
			chosen = id_text
			voice_name = display
			break

	if chosen.is_empty():
		for id in english_voices:
			var id_text := String(id)
			var display := String(display_names.get(id_text, ""))
			var lower := display.to_lower()
			if lower.contains("great britain") or lower.contains("british") or lower.contains("en-gb") or lower.contains("united kingdom"):
				chosen = id_text
				voice_name = display
				break

	if chosen.is_empty() and not english_voices.is_empty():
		chosen = String(english_voices[0])
		voice_name = String(display_names.get(chosen, ""))

	if chosen.is_empty():
		for voice in voices:
			if voice is Dictionary:
				chosen = String(voice.get("id", ""))
				voice_name = String(voice.get("name", ""))
				break

	voice_id = chosen
	available = not voice_id.is_empty()


func speak(text: String, rate_override: float = -1.0) -> void:
	last_text = text
	if not available:
		return
	var speak_rate := rate
	if rate_override > 0.0:
		speak_rate = rate_override
	utterance_id += 1
	DisplayServer.tts_speak(text, voice_id, 85, 1.0, speak_rate, utterance_id, true)


func stop() -> void:
	if available:
		DisplayServer.tts_stop()


func is_speaking() -> bool:
	return available and DisplayServer.tts_is_speaking()
