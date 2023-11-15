extends LineEdit

#ctrl c bein a lil finnicky
func _gui_input(event: InputEvent) -> void:
	if has_focus() && event.is_action_pressed(&"ui_copy"):
		DisplayServer.clipboard_set(text)
