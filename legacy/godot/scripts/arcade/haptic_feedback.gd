class_name ArcadeHapticFeedback
extends RefCounted
var enabled=true
var backend="none"
var _native: Object
func _init() -> void:
	if Engine.has_singleton("ArcadeHaptics"):
		_native=Engine.get_singleton("ArcadeHaptics"); backend="CoreHaptics"
	elif OS.get_name() in ["iOS","Android"]: backend="platform vibration"
func pulse(intensity: float, sharpness: float, duration_ms: int=25) -> void:
	if not enabled: return
	if _native and _native.has_method("transient"): _native.call("transient",intensity,sharpness)
	elif backend=="platform vibration": Input.vibrate_handheld(duration_ms,intensity)
