extends Node
## Dedicated recorder only: ignore physical input, allow tagged scripted GUI clicks.
func _input(event: InputEvent) -> void:
	if event.device != 707: get_viewport().set_input_as_handled()
