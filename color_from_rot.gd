extends Node3D

var color:Color = Color(.5, .5, 1.)
@onready var picker:ShaderMaterial = $MeshInstance3D.material_override;

func _ready() -> void:
	update()

func update() -> void:
	var looking = $pos_marker.global_position
	looking = Vector3(.5, .5, .5) + looking * .5
	color = Color(looking.x, looking.y, looking.z)
	picker.set_shader_parameter(&"picked", color);
	%ColorRect.color = color
	var disp:LineEdit = %ColorDisplay
	disp.text = color.to_html(false);
	disp.release_focus()


func handle_click(_camera, event, pos, _normal, _shape_idx) -> void:
	var click := event as InputEventMouseButton
	if click && click.pressed && click.button_index == MOUSE_BUTTON_LEFT:
		basis = Basis.looking_at(-pos, %Camera3D.basis.y)
		update()
		return

	var move := event as InputEventMouseMotion
	if move && Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		basis = Basis.looking_at(-pos, %Camera3D.basis.y)
		update()
