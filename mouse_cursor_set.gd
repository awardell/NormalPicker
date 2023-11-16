extends Area3D

@export var cursor_shape := Input.CURSOR_ARROW
@onready var default_cursor_shape := Input.get_current_cursor_shape()


func _process(_delta: float) -> void:
	var vp = get_viewport()
	var mp = vp.get_mouse_position()
	var cam = vp.get_camera_3d()
	var from = cam.project_ray_origin(mp)
	var to = from + cam.project_ray_normal(mp) * 40
	var sphs_rid = %sphere_smooth/StaticBody3D.get_rid()
	var sphf_rid = %sphere_flat/StaticBody3D.get_rid()
	var params := PhysicsRayQueryParameters3D.create(
		from, to, collision_layer, [sphs_rid, sphf_rid])
	params.collide_with_areas = true
	var result := get_world_3d().direct_space_state.intersect_ray(params)
	if result.has(&"collider") && result[&"collider"] == self:
		if cursor_shape != Input.get_current_cursor_shape():
			Input.set_default_cursor_shape(cursor_shape)
	else:
		if default_cursor_shape != Input.get_current_cursor_shape():
			Input.set_default_cursor_shape(default_cursor_shape)
