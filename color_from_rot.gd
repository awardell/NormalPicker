extends Node3D

var color:Color = Color(.5, .5, 1.)
@onready var pointer:ShaderMaterial = $pointer.material_override;

enum {
	SMOOTH = 1,
	FLAT = -1,
}
var state = SMOOTH


func _ready() -> void:
	update()


func update() -> void:
	var looking = $pos_marker.global_position
	var colorv = Vector3(.5, .5, .5) + looking * .5
	color = Color(colorv.x, colorv.y, colorv.z)
	pointer.set_shader_parameter(&"picked", color)

	%ColorRect.color = color
	%HexDisplay.text = color.to_html(false)
	%RGBDisplay.text = "(%1.2f,%1.2f,%1.2f)" % [color.r, color.g, color.b]
	%NormalDisplay.text = "Normal(%5.2f,%5.2f,%5.2f)" % [looking.x, looking.y, looking.z]

	var focus := get_viewport().gui_get_focus_owner()
	if focus:
		focus.release_focus()


func toggle_spheres() -> void:
	@warning_ignore("int_as_enum_without_cast")
	state = -state
	var smooth:bool = state == SMOOTH
	%sphere_flat/StaticBody3D/CollisionShape3D.disabled = smooth
	%sphere_flat.visible = !smooth
	%sphere_smooth/StaticBody3D/CollisionShape3D.disabled = !smooth
	%sphere_smooth.visible = smooth


func handle_sphere_click(_camera, event, pos, normal, _shape_idx) -> void:
	var target = -pos if state == SMOOTH else -normal
	_handle_click(event, target)


func handle_plane_click(_camera, event, pos, _normal, _shape_idx) -> void:
	#checking this here so we aren't needlessly raycasting
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_handle_click(event, -_get_plane_intersect(pos))


func _handle_click(event, target) -> void:
	var click := event as InputEventMouseButton
	if click && click.pressed && click.button_index == MOUSE_BUTTON_LEFT:
		basis = Basis.looking_at(target, %Camera3D.basis.y)
		update()
		return

	var move := event as InputEventMouseMotion
	if move && Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		basis = Basis.looking_at(target, %Camera3D.basis.y)
		update()


func _get_plane_intersect(pos:Vector3) -> Vector3:
	var from = pos
	var to = %tangent_plane.global_position
	var params := PhysicsRayQueryParameters3D.create(from, to)
	params.exclude = [%tangent_plane.get_rid()]
	params.collide_with_areas = true
	var result := get_world_3d().direct_space_state.intersect_ray(params)
	if result.has(&"position") && result.has(&"normal"):
		if state == SMOOTH:
			return result[&"position"]
		else:
			return result[&"normal"]
	else:
		push_warning("tangent plane raycast failure")
		return position
