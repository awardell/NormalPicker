# camera orbit script

extends Node3D

enum {
	PERSPECTIVE,
	ORTHOGANAL,
	TRANSITIONING
}

var state = PERSPECTIVE
@onready var start_rot := quaternion
@onready var start_zoom:float = $Camera3D.position.z


func _input(event):
	if state == PERSPECTIVE:
		if event is InputEventMouseMotion:
			if event.button_mask & MOUSE_BUTTON_MASK_MIDDLE:
				rotate_y(-.01 * event.relative.x)
				rotate_object_local(Vector3.RIGHT, -.01 * event.relative.y)

		# dolly camera
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				$Camera3D.position.z += .2;
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				$Camera3D.position.z -= .2;
			if event.button_index == MOUSE_BUTTON_WHEEL_DOWN || event.button_index == MOUSE_BUTTON_WHEEL_UP:
				$Camera3D.position.z = clampf($Camera3D.position.z, 1.0, 6.0)


func change_perspective() -> bool:
	match state:
		PERSPECTIVE:
			tween_to_orthoganal()
			return true
		ORTHOGANAL:
			tween_to_perspective()
			return true
		_:
			return false


func tween_to_orthoganal() -> void:
	if state != PERSPECTIVE:
		return

	state = TRANSITIONING
	var t := create_tween()
	var d := 0.5
	t.tween_property(self, "quaternion", Quaternion.IDENTITY, d)
	t.parallel().tween_property($Camera3D, "position", Vector3(0,0,start_zoom), d)
	t.parallel().tween_property($Camera3D/grid, "modulate", Color.TRANSPARENT, d)
	await t.finished
	$Camera3D.projection = Camera3D.PROJECTION_ORTHOGONAL
	state = ORTHOGANAL


func tween_to_perspective() -> void:
	if state != ORTHOGANAL:
		return

	state = TRANSITIONING
	var t := create_tween()
	var d := 0.2
	$Camera3D.projection = Camera3D.PROJECTION_PERSPECTIVE
	t.tween_property(self, "quaternion", start_rot, d)
	t.parallel().tween_property($Camera3D/grid, "modulate", Color.WHITE, d)
	await t.finished
	state = PERSPECTIVE
