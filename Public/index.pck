GDPC                 @                                                                         P   res://.godot/exported/133200997/export-2718e735a3102491aa80c1735a695f24-grid.res�      �      2?��V�y�d��w    T   res://.godot/exported/133200997/export-9cda2de8c77641ba351c421a78aee413-grid_web.res�      w      -tQȯt�,���Ě�    X   res://.godot/exported/133200997/export-9f422a5bf1f30c049bb726456421f3f4-normal_color.scnPx      �C      *7�jy ��}\���.    `   res://.godot/exported/133200997/export-d23b21abe6ff1584b61f34c7d5c498df-normal_color_flat.res    �            ��ԏ������q��53Y    ,   res://.godot/global_script_class_cache.cfg   �             ��Р�8���8~$}P�    L   res://.godot/imported/icon.png-487276ed1e3a0c39cad0279d744ee560.s3tc.ctex   !      �U      0��tS��5	&~�       res://.godot/uid_cache.bin  ��            �����C8�`W�ß       res://camera_pivot.gd                 ���? �Z4��U��D�       res://color_from_rot.gd        �      �@���R�΍)z�t�       res://grid.tres.remap   `�      a       j}�
�w��eHk       res://grid_web.tres.remap   п      e       ������n�7?9       res://icon.png  @�      �       ����v-�*�*�       res://icon.png.import   �v      �       ��9}C`Cr�3�%�o�9       res://normal_color.gdshader �w      �       X��HD�5ǜ�N|�        res://normal_color.tscn.remap   @�      i       N�K����y��)��    $   res://normal_color_flat.tres.remap  ��      n       "@Z8����po9��}       res://picked_color.gdshader 0�      $      Yk?>]����˃Wg�p       res://project.binary��      a      ��)>�ouq�Ob��`A    # camera orbit script

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
	await t.finished
	state = PERSPECTIVE
      extends Node3D

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
	looking = Vector3(.5, .5, .5) + looking * .5
	color = Color(looking.x, looking.y, looking.z)
	pointer.set_shader_parameter(&"picked", color)

	%ColorRect.color = color
	%HexDisplay.text = color.to_html(false)
	%RGBDisplay.text = "(%1.2f,%1.2f,%1.2f)" % [color.r, color.g, color.b]

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


func handle_click(_camera, event, pos, normal, _shape_idx) -> void:
	var target = -pos if state == SMOOTH else -normal

	var click := event as InputEventMouseButton
	if click && click.pressed && click.button_index == MOUSE_BUTTON_LEFT:
		basis = Basis.looking_at(target, %Camera3D.basis.y)
		update()
		return

	var move := event as InputEventMouseMotion
	if move && Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		basis = Basis.looking_at(target, %Camera3D.basis.y)
		update()
       RSRC                    Shader            ��������                                                  resource_local_to_scene    resource_name    code    script           local://Shader_vn1pe �          Shader          �
  shader_type spatial;
render_mode blend_mix,depth_draw_opaque, unshaded;

uniform vec4 gridColor: source_color;
uniform vec4 checkerColor: source_color;
uniform float fadeStart = 0.0;
uniform float fadeEnd = 10.0;
uniform float unitSize = 1.0;
uniform int subdivisions: hint_range(1, 10) = 5;
uniform float majorLineThickness = 2.0;
uniform float minorLineThickness = 1.0;
uniform float minorLineAlpha: hint_range(0.0, 1.0) = .3;

// calculate line mask, usning a bit of fwidth() magic to make line width not affected by perspective
float grid(vec2 pos, float unit, float thickness){
	vec2 threshold = fwidth(pos) * thickness * .5 / unit;
	vec2 posWrapped = pos / unit;
	vec2 line = step(fract(-posWrapped), threshold) + step(fract(posWrapped), threshold);
	return max(line.x, line.y);
}

vec3 paint_axis(vec3 col, vec2 f){
	vec3 sub =
		step(abs(f.y), 0.015) *
			(step(0., f.x) * vec3(0.,1.,1.) +
			 step(f.x, 0.) * vec3(1.,0.,0.)) +
		step(abs(f.x), 0.015) *
			(step(0., f.y) * vec3(1.,1.,0.) +
			 step(f.y, 0.) * vec3(0.,0.,1.));
	return col - sub;
}

// calculate checkerboard mask
float checker(vec2 pos, float unit){
	float square1 = step(.5, fract(pos.x / unit *.5));
	float square2 = step(.5, fract(pos.y / unit *.5));
	return max(square1,square2) - square1 * square2;
}

void fragment() {
	// ray from camera to fragemnt in wrold space
	vec3 rayWorld = normalize(mat3(INV_VIEW_MATRIX) * VIEW);

	// calculate fragment position in world space
	vec3 posWorld;
	float t = -CAMERA_POSITION_WORLD.y / rayWorld.y;
	posWorld.y = 0.0;
	posWorld.xz = CAMERA_POSITION_WORLD.xz + t * rayWorld.xz;

	// calculate planar distance from camera to fragment (used for fading)
	float distPlanar = distance(posWorld.xz, vec2(0.));

	// grid
	float line = grid(posWorld.xz, unitSize, majorLineThickness);
	line += grid(posWorld.xz, unitSize / float(subdivisions), minorLineThickness) * minorLineAlpha;
	line = clamp(line, 0.0, 1.0);

	// checkerboard
	float chec = checker(posWorld.xz, unitSize);

	// distance fade factor
	float fadeFactor = 1.0 - clamp((distPlanar - fadeStart) / (fadeEnd - fadeStart), 0.0, 1.0);
	fadeFactor = fadeFactor * fadeFactor * fadeFactor * fadeFactor * fadeFactor;

	// write ground plane depth into z buffer
	vec4 pp = (PROJECTION_MATRIX * (VIEW_MATRIX * vec4(posWorld, 1.0)));
	DEPTH = pp.z / pp.w;

	// final alpha
	float alphaGrid = line * gridColor.a;
	float alphaChec = chec * checkerColor.a;
	ALPHA = clamp(alphaGrid + alphaChec, 0.0, 1.0) * fadeFactor * COLOR.a;
	// eliminate grid above the horizon
	ALPHA *= step(t, 0.0);

	vec3 color = (checkerColor.rgb * alphaChec) * (1.0 - alphaGrid) + (gridColor.rgb * alphaGrid);
	color = paint_axis(color, posWorld.xz);

	// final color (premultiplied alpha blend)
	ALBEDO = color;

}
       RSRC  RSRC                    Shader            ��������                                                  resource_local_to_scene    resource_name    code    script           local://Shader_2hl6s �          Shader          ~  shader_type spatial;
render_mode blend_mix, unshaded, cull_disabled;

uniform vec4 gridColor: source_color;
uniform float fadeStart = 0.0;
uniform float fadeEnd = 10.0;
uniform float unitSize = 1.0;
uniform int subdivisions: hint_range(1, 10) = 5;
uniform float majorLineThickness = 2.0;
uniform float minorLineThickness = 1.0;
uniform float minorLineAlpha: hint_range(0.0, 1.0) = .3;

// calculate line mask, usning a bit of fwidth() magic to make line width not affected by perspective
float grid(vec2 pos, float unit, float thickness){
	vec2 threshold = fwidth(pos) * thickness * .5 / unit;
	vec2 posWrapped = pos / unit;
	vec2 line = step(fract(-posWrapped), threshold) + step(fract(posWrapped), threshold);
	return max(line.x, line.y);
}

vec3 paint_axis(vec3 col, vec2 f){
	vec3 sub =
		step(abs(f.y), 0.025) *
			(step(0., f.x) * vec3(0.,1.,1.) +
			 step(f.x, 0.) * vec3(1.,0.,0.)) +
		step(abs(f.x), 0.025) *
			(step(0., f.y) * vec3(1.,1.,0.) +
			 step(f.y, 0.) * vec3(0.,0.,1.));
	return col - sub;
}

varying vec3 posWorld;
void vertex() {
	posWorld = (vec4(VERTEX, 1.) * MODEL_MATRIX).rgb;
}

void fragment() {
	// grid
	float line = grid(posWorld.xz, unitSize, majorLineThickness);
	line += grid(posWorld.xz, unitSize / float(subdivisions), minorLineThickness) * minorLineAlpha;
	line = clamp(line, 0.0, 1.0);

	// distance fade factor
	float fadeFactor = 1.0 - clamp((distance(posWorld.xz, vec2(.0)) - fadeStart) / (fadeEnd - fadeStart), 0.0, 1.0);
	fadeFactor = fadeFactor * fadeFactor * fadeFactor * fadeFactor * fadeFactor;

	// final alpha
	float alphaGrid = line * gridColor.a;
	ALPHA = clamp(alphaGrid, 0.0, 1.0) * fadeFactor * COLOR.a;
	// eliminate grid above the horizon
	//ALPHA *= step(t, 0.0);

	vec3 color = gridColor.rgb;
	color = paint_axis(color, posWorld.xz);

	// final color (premultiplied alpha blend)
	ALBEDO = color;

}
       RSRC         GST2   �   �     �����                � �        I�$	�$��_� TTT          |UUUU� I�$I� ?||����� I�$  ||���� I�$   ��?|UUU � I�$   ��?�UUU � I�$   ��?�UUU � I�$   ��?�UUU � I�$   ��?�UUU � I�$   ��?�UUU � I�$   ��?�UUU � I�$   ��?�UUU � I�$   ��?�UUU � I�$   ��?�UUU � I�$   ��?�UUU � I�$   ��?�UUU � I�$   ��?�UUU � I�$   ��?�UUU � I�$   ��?�UUU � I�$   ��?�UUU � I�$   ��?�UUU � I�$   ��?�UUU � I�$   ��?�UUU � I�$   ��?�UUU � I�$   ��?�UUU � I�$   ��?�UUU � I�$   ��?�UUU � I�$   ��?�UUU � I�$@ �?�U���� I�$I�$  ?�UUUU        ��_�UUU I�$!�$��_k         ��_�TUUU� I�	 _|t������ٶm۶m|t�����       �|
�_��       �| �UU�       �� �UU�       �� �UU�       �� �UU�       �� �UU�       �� �UU�       �� �UU�       �� �UU�       �� �UU�       �� �UU�       �� �UU�       �� �UU�       �� �UU�       �� �UU�       �� �UU�       �� �UU�       �� �UU�       �� �UU�       �� �UU�       �� �UU�       �� �UU�       �� �UU�       �� �UU�       �� �UU�       �� /UU�      ��^��%� I�$H$_�?����|        ��_�UUU� I�$I�  |UUUU�      _|t�����       ?�t�����         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�       ?��5�UU�      _���bɍ� I�$I�$?��UUTU� I� 	� |t��jj�       ?|t�����         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�       ?��%55� H�$@$��ZVV� 	� 	� |l@@@@�       |t				�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�       �|�����       ��tUUկ�       �|UU}��       ?��UUUT�         �UUUU�         �UUUU�       �|�����       �tUU��       ���UUUx�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�       ��5555� @$@$��TTTT� 	� 	� |l@@@@�       |t				�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�       _}d�����       }l�����       }t
 ��       �|�+-��       ���WV\p�         �UUUU�         �UUUU�       �|T�����       �T/���       ��� ��       ��_� �       _��UU^`�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�       ��5555� @$@$��TTTT� 	� 	� |l@@@@�       |t				�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�       m�K.��W�       }t�����       �|UUUU�       ���UU�       ���pb��       �|UUU(�       �|UUU��       �|T�����       |d�����         �UUUU�       �|-�UU�       ���j{}}�       ���UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�       ��5555� @$@$��TTTT� 	� 	� |l@@@@�       |t				�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�       �s�K�����       ��s�         �UUUU�         �UUUU�       _��	��U�       ��|  �U�       ��|  �U�       _}\�����       �|UUUU�         �UUUU�       ���UՕ�       ��ߓ�Cbb�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�       ��5555� @$@$��TTTT� 	� 	� |l@@@@�       |t				�         �UUUU�         �UUUU�         �UUUU�       ?�|�����       ߄tUUu�       _��UUUT�       �|UUUU�       �|l�����       ?u�SWV���       |�s�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�       �������       ?���{��       ���UUWX�         �UUUU�       _�|�����       ߌ|UUu��       ?��UUUT�         �UUUU�         �UUUU�         �UUUU�       ��5555� @$@$��TTTT� 	� 	� |l@@@@�       |t				�         �UUUU�         �UUUU�       �|���z�       �|\�����       �?d/��       ��^� �       _�d�����       _}?d�����       _}d�����       �|�����         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�       _��	�UU�       _�?�`�-�       _�lW^���       }d�����       �?l�/��       ���W\p��         �UUUU�         �UUUU�         �UUUU�       ��5555� @$@$��TTTT� 	� 	� |l@@@@�       |t				�         �UUUU�         �UUUU�       �|T�����       �|T�����       _�t�����       ?��-�UU�       �l�����       �|l�����         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�       ߔ�5�UU�       �l���U�       ?}l�����       _�|UUU�       ����5�       ߬�WV\p�         �UUUU�         �UUUU�       ��5555� @$@$��TTTT� 	� 	� |l@@@@�       |t				�         �UUUU�       ��{��@@�       �t�S����       �|d�����         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�       ���5�UU�       ߬��`����       ���UVVV�         �UUUU�       ��5555� @$@$��TTTT� 	� 	� |l@@@@�       |t				�         �UUUU�       ��{@�� �       �{?S�VXp�       �{S 	-�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�       ��������       ��������       ��������         �UUUU�       ��5555� @$@$��TTTT� 	� 	� |l@@@@�       |t				�         �UUUU�         �UUUU�       �{_c`�  �       �sK%����       |�k �         �UUUU�       �|UUUU�       ��t�����       _�tUU��       ?��UUW��         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�       �|�����       ?�tUU�/�       _�|UU��       ��UUUx�         �UUUU�         �UUUU�       ���UU��       ߳������       ��_������         �UUUU�         �UUUU�       ��5555� @$@$��TTTT� 	� 	� |l@@@@�       |t				�         �UUUU�         �UUUU�       ��{����       |�K\\\\�       |�c�         �UUUU�       �|\�����       _�c�����       _�?r 
�_�       _�_j  ��       ��WX`��         �UUUU�         �UUUU�       ?�|���5�       ?��UUUZ�         �UUUU�       �|���j�       }\�����       _�_b

���       _�?j  �U�       _�_s� 
-�       ���UVXp�         �UUUU�       ����       �߃````�       ���UUUU�         �UUUU�         �UUUU�       ��5555� @$@$��TTTT� 	� 	� |l@@@@�       |t				�         �UUUU�         �UUUU�         �UUUU�       |L\\\\�       |d�       �t ��@�       �tT�����       �j�����       ���y_���       �{J�_x��       ���J	%�       _��WVT\�       ?|l ��@�       }?T++/��       �?�_j��       ?��UUVT�       _|\���`�       ��[�����       ߳�~���       ���YW^���       �B-����       ߬�`��       ��UUVT�       ���       ��````�         �UUUU�         �UUUU�         �UUUU�       ��5555� @$@$��TTTT� 	� 	� |l@@@@�       |t				�         �UUUU�         �UUUU�         �UUUU�       |L\\\\�       |d�       |�k�@@��       ?��S75��       ğ�k���       ��������       |�S`@���       ��C%%%-�       ?���XX\^�       |d@@@@�       ?|L5555�       ?��		�       ��TTTT�       ?|�[�```�       ��[��       ���^VT\�       ��{j����       d;�����       ?��s	��       ���TTVW�       ���       ��````�         �UUUU�         �UUUU�         �UUUU�       ��5555� @$@$��TTTT� 	� 	� |l@@@@�       |t				�         �UUUU�         �UUUU�         �UUUU�       |L\\\\�       |d�       ��{@�� �       �{S��\x�       �?c	%�       ��?|W^���       �}?L����       ��?K�����       ��������       |�c@@@@�       |�K5555�       ���				�       ���TTTT�       |�c@�� �       ��?[5�W�       ��?�^x���       ��?\�����       �?C�����       ��������       ��������       ���       ��````�         �UUUU�         �UUUU�         �UUUU�       ��5555� @$@$��TTTT� 	� 	� |l@@@@�       |t				�         �UUUU�         �UUUU�         �UUUU�       |L\\\\�       |d�         �UUUU�       �{cp�  �       ���b5�^��       ���r �UU�       _��r�����       ��������       ���UUUU�       |�c@@���       �{�J/����       ߳�����       �߃TVWU�       ��{����       �{c\p� �       _��j	�U_�       ���j��U��       ���z�����       ���뿯��         �UUUU�       ���       ��````�         �UUUU�         �UUUU�         �UUUU�       ��5555� @$@$��TTTT� 	� 	� |l@@@@�       |t				�         �UUUU�         �UUUU�         �UUUU�       �|D^^^��       �d����       ?��UUU��       ߄�UUU��       ���{W����       ��{�   �       ����   �         �UUUU�         �UUUU�       ��{����       ���r\�  �       ��߂�����       ���UUUU�         �UUUU�         �UUUU�       ��{p   �       ��{�   �       ���{���/�       ߄|UUU
�       ?�|UUU�       �|�Օ*�       ���zzzp�         �UUUU�         �UUUU�         �UUUU�       ��5555� @$@$��TTTT� 	� 	� |l@@@@�       |t				�         �UUUU�         �UUUU�         �UUUU�       }�2��^^�       ��?R ���       ���z  �U�       ��z  
U�       ��{ꪫ��       ���UV\\�         �UUUU�         �UUUU�       _}\�����       ��tU�  �       ���U�  �       ���U�  �       ���U�  �       _��UWz`�         �UUUU�         �UUUU�       �|T���z�       ��S

��       ��z  �W�       ���z  �U�       ��?z**���       ������{�         �UUUU�         �UUUU�         �UUUU�       ��5555� @$@$��TTTT� 	� 	� |l@@@@�       |t				�         �UUUU�         �UUUU�         �UUUU�       �{�:X����       �{b���       ��?zUW� �       �{�Z�����       �?S-%%�       ��XXXX�         �UUUU�       �|���j�       �tL��ח�       ���r�_z�       ���� UUU�       ���� UUU�       ���Z ��W�       ���`����         �UUUU�         �UUUU�       |Tpppp�       �?S���       ����WW���       ��_�U�
 �       ���տ**�       ��߂�����         �UUUU�         �UUUU�         �UUUU�       ��5555� @$@$��TTTT� 	� 	� |l@@@@�       |t				�         �UUUU�         �UUUU�         �UUUU�       �{�KXXXp�       |�S	�         �UUUU�       |�[@@@@�       �_K%%5��       ������U�       ����U  ��       �|W� �       ?��S�߾��       ��_�z����       ��_�U   �       ��_�U   �       �{_K��XX�       ?��c�		��       �|U� ��       �}�|�  �       }Tp����       ��_[��       �߃\TTV�         �UUUU�       ��������       ����`pxz�         �UUUU�         �UUUU�         �UUUU�       ��5555� @$@$��TTTT� 	� 	� |l@@@@�       |t				�         �UUUU�         �UUUU�         �UUUU�       �{Sp`���       �{S%5��       ��{  	�       |�k@�  �       �{Z��� �       �{z�UW �       _{z+UU �       ��zUU��       ��z>����       ��������         �UUUU�         �UUUU�       �{Sxp���       ��Z����       ��z�UU��       _���UU�       ���_U��       ���-����       �߃VWUU�       �߃�����       ��������       ��������         �UUUU�         �UUUU�         �UUUU�       ��5555� @$@$��TTTT� 	� 	� |l@@@@�       |t				�         �UUUU�         �UUUU�         �UUUU�       ��{`�  �       �{�RV\p��       �{�Z	5��       ���s   	�         �UUUU�         �UUUU�         �UUUU�       ��{W����       ��{�   �       ���UUUU�         �UUUU�         �UUUU�       ��{_����       ��{�   �       ���UUUU�         �UUUU�         �UUUU�         �UUUU�       ��������       ���������       ��߂�����       ��������         �UUUU�         �UUUU�         �UUUU�       ��5555� @$@$��TTTT� 	� 	� |l@@@@�       |t				�         �UUUU�         �UUUU�         �UUUU�         �UUUU�       ��{`   �       �{�bWX� �       �{�b�U^�       �{�j �U�       ��s   -�       ��{�����         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�       ������_�       ��������       ���������       ߛ�������       ���������       ��������         �UUUU�         �UUUU�         �UUUU�         �UUUU�       ��5555� @$@$��TTTT� 	� 	� |l@@@@�       |t				�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�       ��{����       ��sx   �       �{�jU~� �       �{j�U_��       �{r
�U_�       ��r �UU�       ��z  �U�       ��z  �U�       ���z  �U�       ����  �U�       ��z  �U�       ��� ��U�       ��z �WU�       ߋ��_U��       ߓ����+�       ���������       ��������       ���UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�       ��5555� @$@$��TTTT� 	� 	� |�k@@@@�       |�s				�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�       ��{Z����       ��_{z   �       ���zU�  �       ��zU�  �       ��zU�  �       ��zUW  �       ���U�  �       ���U�  �       ���U�  �       ��߂�
  �       ��_��   �       ��������         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�       ���5555� @$@$���TTTT� 	� 	��{�s@@���       |�s	%�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU��$I�$I2�߃77��� @$H�$��{���� I�I�$  �{UUUU�      �{�s'��X�       ��s  	�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�       ��������       ��������� H�4I�$��{����        ��?�UUUT� � I�$�{�sp�  �      �{�s-�^��       ���{ �U�       ���{  �U�       ����  �U�       ����  �U�       ����  �U�       ����  �U�       ����  �U�       ����  �U�       ����  �U�       ����  �U�       ����  �U�       ����  �U�       ����  �U�       ����  �U�       ����  �U�       ����  �U�       ����  �U�       ����  �U�       ����  �U�       ����  �U�       ����  �U�       ����  �U�       ����  �U�       ����  �U�       ����  �U�       �������U�       ��������� @$H�$��������        ���UUU I�0I�$��?�TT@         ���UUUT� 	�$I�$�{�{eij��   I�$�{�{_  �    I�$߃{U   �    I�$߃�U   �    I�$߃�U   �    I�$߃�U   �    I�$߃�U   �    I�$߃�U   �    I�$߃�U   �    I�$߃�U   �    I�$߃�U   �    I�$߃�U   �    I�$߃�U   �    I�$߃�U   �    I�$߃�U   �    I�$߃�U   �    I�$߃�U   �    I�$߃�U   �    I�$߃�U   �    I�$߃�U   �    I�$߃�U   �    I�$߃�U   �    I�$߃�U   �    I�$߃�U   �    I�$߃�U   �    I�$߃�U   �    I�$������

� @�$I�$��߃�뫫        ���UUU        ��?| � I�$I���?|XVWU� I   �t���� I    _�|�  U� I    _���  U� I    _���  U� I    _���  U� I    _���  U� I    _���  U� I    _���  U� I    _���  U� I    _���  U� I    _���  U� I    _���  U� I    _���  U� I:  ����5� I�$I�$��?�-��U� � _|t�����       �|�����         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU� X8  _����iy�   �t�         �UUUU�         �UUUU�         �UUUU�         �UUUU�       _}l�����       �tU�+��       ���UUWT�       �|\�����       �d��-�       _��UU^��         �UUUU�         �UUUU�         �UUUU�         �UUUU�     �������   �t�         �UUUU�         �UUUU�         �UUUU�         �UUUU�       �|�S�����       _��UUU�       ��^Z�U�       }T����       _|t�����       ���������         �UUUU�         �UUUU�         �UUUU�         �UUUU�     �������   �t�         �UUUU�       �|\�����       _�lU�	�       ?�d�����       �|T�����         �UUUU�         �UUUU�         �UUUU�         �UUUU�       ����%�U�       ?�tUWX��       _�l��/��       ���UUW\�         �UUUU�     �������   �t�       �|���       �|\�����       ��|5UUU�       ?�tx_UU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�       ?�t�UUU�       ��t�����       ߤ�RAͥ�         �UUUU�     �������   �t�       ��{����       �{S4�p�       ��{  �       �|�����       ��|UUU��         �UUUU�         �UUUU�         �UUUU�       �|UUUU�       ��|UUU	�       ���UUUT�       ���UUU��       ��?������       ���UUUU�     �������   �t�         �UUUU�       |�K````�       ��s��       ?��Z�����       ?�_Z �_z�       ��_[�����       }\��*��       ��UU^R�       ��_[�����       ?�_j*�_��       ?��R��%�       ����       ���\\\\�         �UUUU�     �������   �t�         �UUUU�       |L````�       ��s���       �?S�7�       ���[���       ��C�����       |�K�����       ���ssss�       ��[_�       ���c�����       ?�_K%����       ����       ��\\\\�         �UUUU�     �������   �t�         �UUUU�       |D````�       ��t�����       _��b�p  �       ���z�����       ��?������       �{�R��� �       ���������       �{?k`   �       ���r�ת��       _��������       ��|���/�       ��VV^\�         �UUUU�     �������   �t�         �UUUU�       �|3�``��       ���j �U��       _��Z +���       _��WTTT�       }\��ZZ�       ��z��W�       ��b� �U�       ��U\Z[�       _|\ �@@�       _��Z��{��       ���z �U��       ���\^_^�         �UUUU�     �������   �t�         �UUUU�       |�K`@���       �{?S�       ?��J8����       ��z�*UU�       ?��Z�����       ���\����       �{S`@@��       ?��j��UU�       ��b�����       ?�r�����       ��?������       ���\^WW�         �UUUU�     �������   �t�         �UUUU�       ��{j����       �{�Z'�`��       �{�j  	��       ��{   	�       ���_����         �UUUU�         �UUUU�       ��������       ������j�       ���������       ��߂�����       ���UUUU�         �UUUU�     �������   ��s�         �UUUU�         �UUUU�         �UUUU�       �{�rx   �       �{�r�^  �       ��zU~ �       ���z �U �       ���� _U �       ����U� �       ����_�* �       ���������         �UUUU�         �UUUU�         �UUUU�     �������� �!�|�s8�`�       ��{  	�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�         �UUUU�       ��������  4@�%��{����� ���I�$���UWVp�  0 �$���s	ע �     �$��{ UU��     �$��� UU��     �$��� UU��     �$��� UU��     �$��� UU��     �$��� UU��     �$��� UU��     �$��� UU��     �$��� UU��     �$��� UU��     �$��� UU��     �$��� UU��   `�$��������� H�$I�$���UՕ� ɛP ��|TUUU��I    _�� �UU��I    _�� �UU��I    _�� �UU��I    _�� �UU��I    _�� �UU��I    _�� �UU� M< ����UUU��  �t�         �UUUU�       �|�[�*���       �|]{E��       �d�/���       ����U^Y]�         �UUUU��    ��%%%%��  �t�       ��d�/���       �|dڪ���         �UUUU�         �UUUU�       ���Y��U�       ��t]kŵ��    ��%%%%��  �t�       �{[	�       ߜ�b���{�       ߌl�����       ߔt���\�       ߜ�b����       ���������    ��%%%%��  �t�       |\����       �?c�����       �_c��`��       �_s����       �?K�����       ��eeeM��    ��%%%%��  �t�       |?K�,8�       ��j��V�       ���Z����       ���b�ϧ_�       ��j�����       �?�������    ��%%%%��  �t�       �{_kP�  �       �{�j \ �       ��{  �~�       ���  ��       ���������       ��_�������    ��%%%%� p )����{UUUT��    �$���  �U��    �$���  �U��    �$���  �U��    �$���  �U��    �$���  �U��    �$���  �U�  ���'�߃UUU��F 0 �|�UUU��I    ��l���7��I    ��t�Uig�� `����UU��  ���k+����       ��s�����       ��{����    ���{������  ?|�k�2���       ���kz���       ���s������    ?�߃�����0 n���s�����    �$��{V ���    �$���ꕪ�� ` �1����������6 0 _��s�?����` `_��{?�����0 �m��s�&���� ` �-������?���2`�-?��{�����       ��{����         �UUUU            [remap]

importer="texture"
type="CompressedTexture2D"
uid="uid://c8haskaycwcva"
path.s3tc="res://.godot/imported/icon.png-487276ed1e3a0c39cad0279d744ee560.s3tc.ctex"
metadata={
"imported_formats": ["s3tc_bptc"],
"vram_texture": true
}
    shader_type spatial;
render_mode unshaded, ambient_light_disabled;

varying vec3 n;
void vertex() {
	n = 0.5 + VERTEX;
}

void fragment() {
	ALBEDO = n;
}
     RSRC                    PackedScene            ��������                                            �      ..    color_control    resource_local_to_scene    resource_name    render_priority 
   next_pass    shader    shader_parameter/gridColor    shader_parameter/fadeStart    shader_parameter/fadeEnd    shader_parameter/unitSize    shader_parameter/subdivisions $   shader_parameter/majorLineThickness $   shader_parameter/minorLineThickness     shader_parameter/minorLineAlpha    script    lightmap_size_hint 	   material    custom_aabb    flip_faces    add_uv2    uv2_padding    size    subdivide_width    subdivide_depth    center_offset    orientation    radius    height    radial_segments    rings    is_hemisphere    custom_solver_bias    margin    data    backface_collision    shader_parameter/picked    shader_parameter/n_amt    top_radius    bottom_radius    cap_top    cap_bottom    sky_top_color    sky_horizon_color 
   sky_curve    sky_energy_multiplier 
   sky_cover    sky_cover_modulate    ground_bottom_color    ground_horizon_color    ground_curve    ground_energy_multiplier    sun_angle_max 
   sun_curve    use_debanding    sky_material    process_mode    radiance_size    background_mode    background_color    background_energy_multiplier    background_intensity    background_canvas_max_layer    background_camera_feed_id    sky    sky_custom_fov    sky_rotation    ambient_light_source    ambient_light_color    ambient_light_sky_contribution    ambient_light_energy    reflected_light_source    tonemap_mode    tonemap_exposure    tonemap_white    ssr_enabled    ssr_max_steps    ssr_fade_in    ssr_fade_out    ssr_depth_tolerance    ssao_enabled    ssao_radius    ssao_intensity    ssao_power    ssao_detail    ssao_horizon    ssao_sharpness    ssao_light_affect    ssao_ao_channel_affect    ssil_enabled    ssil_radius    ssil_intensity    ssil_sharpness    ssil_normal_rejection    sdfgi_enabled    sdfgi_use_occlusion    sdfgi_read_sky_light    sdfgi_bounce_feedback    sdfgi_cascades    sdfgi_min_cell_size    sdfgi_cascade0_distance    sdfgi_max_distance    sdfgi_y_scale    sdfgi_energy    sdfgi_normal_bias    sdfgi_probe_bias    glow_enabled    glow_levels/1    glow_levels/2    glow_levels/3    glow_levels/4    glow_levels/5    glow_levels/6    glow_levels/7    glow_normalized    glow_intensity    glow_strength 	   glow_mix    glow_bloom    glow_blend_mode    glow_hdr_threshold    glow_hdr_scale    glow_hdr_luminance_cap    glow_map_strength 	   glow_map    fog_enabled    fog_light_color    fog_light_energy    fog_sun_scatter    fog_density    fog_aerial_perspective    fog_sky_affect    fog_height    fog_height_density    volumetric_fog_enabled    volumetric_fog_density    volumetric_fog_albedo    volumetric_fog_emission    volumetric_fog_emission_energy    volumetric_fog_gi_inject    volumetric_fog_anisotropy    volumetric_fog_length    volumetric_fog_detail_spread    volumetric_fog_ambient_inject    volumetric_fog_sky_affect -   volumetric_fog_temporal_reprojection_enabled ,   volumetric_fog_temporal_reprojection_amount    adjustment_enabled    adjustment_brightness    adjustment_contrast    adjustment_saturation    adjustment_color_correction 	   _bundled       Shader    res://grid_web.tres -$i�   Shader    res://normal_color_flat.tres _�Pu���Y   Shader    res://normal_color.gdshader ��������   Script    res://color_from_rot.gd ��������   Shader    res://picked_color.gdshader ��������   Script    res://camera_pivot.gd ��������      local://ShaderMaterial_dcu7g v         local://PlaneMesh_3i05p -         local://ShaderMaterial_6hfka W         local://SphereMesh_125c5 �      $   local://ConcavePolygonShape3D_06swg �         local://ShaderMaterial_yhfrj �3         local://SphereMesh_r4iqt 4         local://SphereShape3D_op1t5 M4         local://ShaderMaterial_4yhut k4         local://CylinderMesh_ls1t1 �4      $   local://ProceduralSkyMaterial_8y3ci 5         local://Sky_v6dyt �5         local://Environment_7dob8 �5         local://PackedScene_h6ajg -6         ShaderMaterial                                             �?  �?  �?��?        �?	         A
        �?                  @        �?   )   333333�?      
   PlaneMesh       
     �B  �B         ShaderMaterial                                             SphereMesh                               	            ConcavePolygonShape3D    "   #   �         ?           ?        �t�>?5>       ?    vO�=�t�>�	>    �t�>?5>       ?           ?    vO�=�t�>�	>       ?    �	>�t�>vO�=vO�=�t�>�	>       ?           ?    �	>�t�>vO�=       ?    ?5>�t�>    �	>�t�>vO�=       ?           ?    ?5>�t�>           ?    �	>�t�>vO��?5>�t�>           ?           ?    �	>�t�>vO��       ?    vO�=�t�>�	��	>�t�>vO��       ?           ?    vO�=�t�>�	�       ?        �t�>?5�vO�=�t�>�	�       ?           ?        �t�>?5�       ?    vO���t�>�	�    �t�>?5�       ?           ?    vO���t�>�	�       ?    �	��t�>vO��vO���t�>�	�       ?           ?    �	��t�>vO��       ?    ?5��t�>    �	��t�>vO��       ?           ?    ?5��t�>           ?    �	��t�>vO�=?5��t�>           ?           ?    �	��t�>vO�=       ?    vO���t�>�	>�	��t�>vO�=       ?           ?    vO���t�>�	>       ?        �t�>?5>vO���t�>�	>    �t�>?5>vO�=�t�>�	>    ��>z�>vO�=�t�>�	>�l>��>�M�>    ��>z�>vO�=�t�>�	>�	>�t�>vO�=�l>��>�M�>�	>�t�>vO�=�M�>��>�l>�l>��>�M�>�	>�t�>vO�=?5>�t�>    �M�>��>�l>?5>�t�>    z�>��>    �M�>��>�l>?5>�t�>    �	>�t�>vO��z�>��>    �	>�t�>vO���M�>��>�l�z�>��>    �	>�t�>vO��vO�=�t�>�	��M�>��>�l�vO�=�t�>�	��l>��>�M���M�>��>�l�vO�=�t�>�	�    �t�>?5��l>��>�M��    �t�>?5�    ��>z���l>��>�M��    �t�>?5�vO���t�>�	�    ��>z��vO���t�>�	��l���>�M��    ��>z��vO���t�>�	��	��t�>vO���l���>�M���	��t�>vO���M����>�l��l���>�M���	��t�>vO��?5��t�>    �M����>�l�?5��t�>    z����>    �M����>�l�?5��t�>    �	��t�>vO�=z����>    �	��t�>vO�=�M����>�l>z����>    �	��t�>vO�=vO���t�>�	>�M����>�l>vO���t�>�	>�l���>�M�>�M����>�l>vO���t�>�	>    �t�>?5>�l���>�M�>    �t�>?5>    ��>z�>�l���>�M�>    ��>z�>�l>��>�M�>    z�>��>�l>��>�M�>�'O>z�>�Z�>    z�>��>�l>��>�M�>�M�>��>�l>�'O>z�>�Z�>�M�>��>�l>�Z�>z�>�'O>�'O>z�>�Z�>�M�>��>�l>z�>��>    �Z�>z�>�'O>z�>��>    ��>z�>    �Z�>z�>�'O>z�>��>    �M�>��>�l���>z�>    �M�>��>�l��Z�>z�>�'O���>z�>    �M�>��>�l��l>��>�M���Z�>z�>�'O��l>��>�M���'O>z�>�Z���Z�>z�>�'O��l>��>�M��    ��>z���'O>z�>�Z��    ��>z��    z�>�Ͼ�'O>z�>�Z��    ��>z���l���>�M��    z�>�Ͼ�l���>�M���'O�z�>�Z��    z�>�Ͼ�l���>�M���M����>�l��'O�z�>�Z���M����>�l��Z��z�>�'O��'O�z�>�Z���M����>�l�z����>    �Z��z�>�'O�z����>    �Ͼz�>    �Z��z�>�'O�z����>    �M����>�l>�Ͼz�>    �M����>�l>�Z��z�>�'O>�Ͼz�>    �M����>�l>�l���>�M�>�Z��z�>�'O>�l���>�M�>�'O�z�>�Z�>�Z��z�>�'O>�l���>�M�>    ��>z�>�'O�z�>�Z�>    ��>z�>    z�>��>�'O�z�>�Z�>    z�>��>�'O>z�>�Z�>    ?5>�t�>�'O>z�>�Z�>؁s>?5>s��>    ?5>�t�>�'O>z�>�Z�>�Z�>z�>�'O>؁s>?5>s��>�Z�>z�>�'O>s��>?5>؁s>؁s>?5>s��>�Z�>z�>�'O>��>z�>    s��>?5>؁s>��>z�>    �t�>?5>    s��>?5>؁s>��>z�>    �Z�>z�>�'O��t�>?5>    �Z�>z�>�'O�s��>?5>؁s��t�>?5>    �Z�>z�>�'O��'O>z�>�Z��s��>?5>؁s��'O>z�>�Z��؁s>?5>s�Ҿs��>?5>؁s��'O>z�>�Z��    z�>�Ͼ؁s>?5>s�Ҿ    z�>�Ͼ    ?5>�t�؁s>?5>s�Ҿ    z�>�Ͼ�'O�z�>�Z��    ?5>�t�'O�z�>�Z��؁s�?5>s�Ҿ    ?5>�t�'O�z�>�Z���Z��z�>�'O�؁s�?5>s�Ҿ�Z��z�>�'O�s�Ҿ?5>؁s�؁s�?5>s�Ҿ�Z��z�>�'O��Ͼz�>    s�Ҿ?5>؁s��Ͼz�>    �t�?5>    s�Ҿ?5>؁s��Ͼz�>    �Z��z�>�'O>�t�?5>    �Z��z�>�'O>s�Ҿ?5>؁s>�t�?5>    �Z��z�>�'O>�'O�z�>�Z�>s�Ҿ?5>؁s>�'O�z�>�Z�>؁s�?5>s��>s�Ҿ?5>؁s>�'O�z�>�Z�>    z�>��>؁s�?5>s��>    z�>��>    ?5>�t�>؁s�?5>s��>    ?5>�t�>؁s>?5>s��>           ?؁s>?5>s��>  �>    -��>           ?؁s>?5>s��>s��>?5>؁s>  �>    -��>s��>?5>؁s>-��>      �>  �>    -��>s��>?5>؁s>�t�>?5>    -��>      �>�t�>?5>       ?        -��>      �>�t�>?5>    s��>?5>؁s�   ?        s��>?5>؁s�-��>      ��   ?        s��>?5>؁s�؁s>?5>s�Ҿ-��>      ��؁s>?5>s�Ҿ  �>    -�ݾ-��>      ��؁s>?5>s�Ҿ    ?5>�t�  �>    -�ݾ    ?5>�t�           �  �>    -�ݾ    ?5>�t�؁s�?5>s�Ҿ           �؁s�?5>s�Ҿ  ��    -�ݾ           �؁s�?5>s�Ҿs�Ҿ?5>؁s�  ��    -�ݾs�Ҿ?5>؁s�-�ݾ      ��  ��    -�ݾs�Ҿ?5>؁s��t�?5>    -�ݾ      ���t�?5>       �        -�ݾ      ���t�?5>    s�Ҿ?5>؁s>   �        s�Ҿ?5>؁s>-�ݾ      �>   �        s�Ҿ?5>؁s>؁s�?5>s��>-�ݾ      �>؁s�?5>s��>  ��    -��>-�ݾ      �>؁s�?5>s��>    ?5>�t�>  ��    -��>    ?5>�t�>           ?  ��    -��>           ?  �>    -��>    ?5��t�>  �>    -��>؁s>?5�s��>    ?5��t�>  �>    -��>-��>      �>؁s>?5�s��>-��>      �>s��>?5�؁s>؁s>?5�s��>-��>      �>   ?        s��>?5�؁s>   ?        �t�>?5�    s��>?5�؁s>   ?        -��>      ���t�>?5�    -��>      ��s��>?5�؁s��t�>?5�    -��>      ��  �>    -�ݾs��>?5�؁s�  �>    -�ݾ؁s>?5�s�Ҿs��>?5�؁s�  �>    -�ݾ           �؁s>?5�s�Ҿ           �    ?5��t�؁s>?5�s�Ҿ           �  ��    -�ݾ    ?5��t�  ��    -�ݾ؁s�?5�s�Ҿ    ?5��t�  ��    -�ݾ-�ݾ      ��؁s�?5�s�Ҿ-�ݾ      ��s�Ҿ?5�؁s�؁s�?5�s�Ҿ-�ݾ      ��   �        s�Ҿ?5�؁s�   �        �t�?5�    s�Ҿ?5�؁s�   �        -�ݾ      �>�t�?5�    -�ݾ      �>s�Ҿ?5�؁s>�t�?5�    -�ݾ      �>  ��    -��>s�Ҿ?5�؁s>  ��    -��>؁s�?5�s��>s�Ҿ?5�؁s>  ��    -��>           ?؁s�?5�s��>           ?    ?5��t�>؁s�?5�s��>    ?5��t�>؁s>?5�s��>    z����>؁s>?5�s��>�'O>z���Z�>    z����>؁s>?5�s��>s��>?5�؁s>�'O>z���Z�>s��>?5�؁s>�Z�>z���'O>�'O>z���Z�>s��>?5�؁s>�t�>?5�    �Z�>z���'O>�t�>?5�    ��>z��    �Z�>z���'O>�t�>?5�    s��>?5�؁s���>z��    s��>?5�؁s��Z�>z���'O���>z��    s��>?5�؁s�؁s>?5�s�Ҿ�Z�>z���'O�؁s>?5�s�Ҿ�'O>z���Z���Z�>z���'O�؁s>?5�s�Ҿ    ?5��t�'O>z���Z��    ?5��t�    z���Ͼ�'O>z���Z��    ?5��t�؁s�?5�s�Ҿ    z���Ͼ؁s�?5�s�Ҿ�'O�z���Z��    z���Ͼ؁s�?5�s�Ҿs�Ҿ?5�؁s��'O�z���Z��s�Ҿ?5�؁s��Z��z���'O��'O�z���Z��s�Ҿ?5�؁s��t�?5�    �Z��z���'O��t�?5�    �Ͼz��    �Z��z���'O��t�?5�    s�Ҿ?5�؁s>�Ͼz��    s�Ҿ?5�؁s>�Z��z���'O>�Ͼz��    s�Ҿ?5�؁s>؁s�?5�s��>�Z��z���'O>؁s�?5�s��>�'O�z���Z�>�Z��z���'O>؁s�?5�s��>    ?5��t�>�'O�z���Z�>    ?5��t�>    z����>�'O�z���Z�>    z����>�'O>z���Z�>    �Ͼz�>�'O>z���Z�>�l>�Ͼ�M�>    �Ͼz�>�'O>z���Z�>�Z�>z���'O>�l>�Ͼ�M�>�Z�>z���'O>�M�>�Ͼ�l>�l>�Ͼ�M�>�Z�>z���'O>��>z��    �M�>�Ͼ�l>��>z��    z�>�Ͼ    �M�>�Ͼ�l>��>z��    �Z�>z���'O�z�>�Ͼ    �Z�>z���'O��M�>�Ͼ�l�z�>�Ͼ    �Z�>z���'O��'O>z���Z���M�>�Ͼ�l��'O>z���Z���l>�Ͼ�M���M�>�Ͼ�l��'O>z���Z��    z���Ͼ�l>�Ͼ�M��    z���Ͼ    �Ͼz���l>�Ͼ�M��    z���Ͼ�'O�z���Z��    �Ͼz���'O�z���Z���l��Ͼ�M��    �Ͼz���'O�z���Z���Z��z���'O��l��Ͼ�M���Z��z���'O��M���Ͼ�l��l��Ͼ�M���Z��z���'O��Ͼz��    �M���Ͼ�l��Ͼz��    z���Ͼ    �M���Ͼ�l��Ͼz��    �Z��z���'O>z���Ͼ    �Z��z���'O>�M���Ͼ�l>z���Ͼ    �Z��z���'O>�'O�z���Z�>�M���Ͼ�l>�'O�z���Z�>�l��Ͼ�M�>�M���Ͼ�l>�'O�z���Z�>    z����>�l��Ͼ�M�>    z����>    �Ͼz�>�l��Ͼ�M�>    �Ͼz�>�l>�Ͼ�M�>    �t�?5>�l>�Ͼ�M�>vO�=�t��	>    �t�?5>�l>�Ͼ�M�>�M�>�Ͼ�l>vO�=�t��	>�M�>�Ͼ�l>�	>�t�vO�=vO�=�t��	>�M�>�Ͼ�l>z�>�Ͼ    �	>�t�vO�=z�>�Ͼ    ?5>�t�    �	>�t�vO�=z�>�Ͼ    �M�>�Ͼ�l�?5>�t�    �M�>�Ͼ�l��	>�t�vO��?5>�t�    �M�>�Ͼ�l��l>�Ͼ�M���	>�t�vO���l>�Ͼ�M��vO�=�t��	��	>�t�vO���l>�Ͼ�M��    �Ͼz��vO�=�t��	�    �Ͼz��    �t�?5�vO�=�t��	�    �Ͼz���l��Ͼ�M��    �t�?5��l��Ͼ�M��vO���t��	�    �t�?5��l��Ͼ�M���M���Ͼ�l�vO���t��	��M���Ͼ�l��	��t�vO��vO���t��	��M���Ͼ�l�z���Ͼ    �	��t�vO��z���Ͼ    ?5��t�    �	��t�vO��z���Ͼ    �M���Ͼ�l>?5��t�    �M���Ͼ�l>�	��t�vO�=?5��t�    �M���Ͼ�l>�l��Ͼ�M�>�	��t�vO�=�l��Ͼ�M�>vO���t��	>�	��t�vO�=�l��Ͼ�M�>    �Ͼz�>vO���t��	>    �Ͼz�>    �t�?5>vO���t��	>    �t�?5>vO�=�t��	>       �    vO�=�t��	>       �           �    vO�=�t��	>�	>�t�vO�=       �    �	>�t�vO�=       �           �    �	>�t�vO�=?5>�t�           �    ?5>�t�           �           �    ?5>�t�    �	>�t�vO��       �    �	>�t�vO��       �           �    �	>�t�vO��vO�=�t��	�       �    vO�=�t��	�       �           �    vO�=�t��	�    �t�?5�       �        �t�?5�       �           �        �t�?5�vO���t��	�       �    vO���t��	�       �           �    vO���t��	��	��t�vO��       �    �	��t�vO��       �           �    �	��t�vO��?5��t�           �    ?5��t�           �           �    ?5��t�    �	��t�vO�=       �    �	��t�vO�=       �           �    �	��t�vO�=vO���t��	>       �    vO���t��	>       �           �    vO���t��	>    �t�?5>       �        �t�?5>       �           �             ShaderMaterial                                             SphereMesh          �         @            SphereShape3D             ShaderMaterial                                    $        �?  �?  �?  �?%   )   \���(\�?         CylinderMesh    &          '      ��L=      ��>         ProceduralSkyMaterial    *      ��=��0=��p=  �?+      r�>��>q�>  �?,      n�h=0                    �?1      r�>��>q�>  �?4                   Sky    7         
            Environment    :         @            C         G                  PackedScene    �      	         names "   =      root    Node3D 	   grid_web    material_override    mesh    MeshInstance3D    sphere_flat    unique_name_in_owner 
   transform    visible 	   skeleton    StaticBody3D    CollisionShape3D    shape 	   disabled    sphere_smooth    gi_mode    color_control    script    pointer    pos_marker    WorldEnvironment    environment    camera_pivot 	   Camera3D    current    size    CanvasLayer 
   ColorRect    offset_right    offset_bottom 	   HexLabel    offset_top $   theme_override_font_sizes/font_size    text    Label    HexDisplay    layout_mode    offset_left 	   editable    expand_to_text_length    shortcut_keys_enabled    middle_mouse_paste_enabled     drag_and_drop_selection_enabled    flat    select_all_on_focus 	   LineEdit 	   RGBLabel    RGBDisplay    projection-Button    anchors_preset    anchor_left    anchor_right    grow_horizontal    Button    sphere-Button    handle_click    input_event    change_perspective    pressed    toggle_spheres    	   variants    2                               탄>&��Fw��Fw��W5�탄��%�  �?�W5�                                              �?    �j�#���$  �?��&�j�#      �?                                                                     �?            1�;�  �?      ��1�;�    C�.��G?               	        �?              �?              �?          �?              �?            �Sq?�٪>    �٪��Sq?                          �?              �?              �?        d��?   ���?     =C      B     B     �B     �B   #         HEX      �B     ��     KC     TB     �?     @B     �B            RGB      0B     C      R G B             �      A      Switch Camera Projection      N�     B     �B      Switch Smooth/Flat       node_count             nodes     F  ��������       ����                      ����                                  ����               	            
                       ����                     ����                                       ����            	      
                          ����                     ����                           ����                          ����                                      ����                           ����                           ����                                ����                                             ����                     ����                                #      ����                      !      "                 .   $   ����         %   
   &                       !   !      "      '      (      )      *      +      ,      -                 #   /   ����   &   "             #      $   !   %   "   &              .   0   ����         %   
   &   '             (         !   %   "   )   '      (      )      *      +      ,      -                 6   1   ����   2   *   3   "   4   "   &   +      ,   5   
   "   -              6   7   ����   2   *   3   "   4   "   &   .       /      0   5   
   "   1             conn_count             conns              9   8                    9   8                    ;   :                    ;   <                    node_paths              editable_instances              version             RSRC         RSRC                    Shader            ��������                                                  resource_local_to_scene    resource_name    code    script           local://Shader_58rkx �          Shader            shader_type spatial;
render_mode unshaded;

varying vec3 pos;

void vertex(){
	pos = (vec4(VERTEX, 1.) * inverse(MODEL_MATRIX)).xyz;
}

void fragment(){
	vec3 dpdx = dFdx(pos);
	vec3 dpdy = dFdy(pos);
	vec3 color = normalize(cross(dpdy, dpdx));
	ALBEDO = .5 + .5 * color;
}       RSRC     shader_type spatial;
render_mode unshaded, ambient_light_disabled;

uniform vec4 picked: source_color;
uniform float n_amt: hint_range(0.0, 1.0, 0.01) = .25;

varying vec3 n;

void vertex() {
	n = NORMAL;
}

void fragment() {
	ALBEDO = picked.rgb * (1. - n_amt + n_amt * step(0.001, n.g));
}
            [remap]

path="res://.godot/exported/133200997/export-2718e735a3102491aa80c1735a695f24-grid.res"
               [remap]

path="res://.godot/exported/133200997/export-9cda2de8c77641ba351c421a78aee413-grid_web.res"
           [remap]

path="res://.godot/exported/133200997/export-9f422a5bf1f30c049bb726456421f3f4-normal_color.scn"
       [remap]

path="res://.godot/exported/133200997/export-d23b21abe6ff1584b61f34c7d5c498df-normal_color_flat.res"
  list=Array[Dictionary]([])
     �PNG

   IHDR   �   �   �>a�   	pHYs  �  ��+   8IDATx���v#Kr��̬
�{�Lk4^�����s�� ~��|�[��Y�f��3�ıN��?(��&�4��Z� ��DEdDd��&��+��R�_�#�~���[�`�7�>�W�8�9w���1{����O�������)��s�&�7D��+�����[4`�z��xx1#-rLu��2��;"P��nFo��h��At`�tQs�˯�M)��D0�h<D&��q���� �?��l��1�����6�c�={ٟ�J�P��ƀ�`2  =�w� �H�&k��G�|�s����7`�nG�+}{2�-�$6׫��x���� 6�@��>_��.�����%�+=�"୴3�4�s��b�cB���--���0\�@0�.�>O_�tX/{�f��Q��{�=�C���u�uIc���D�wй�0t���>e������d�Į�n��[xK�4|��xe��#?�Y�Vm!c���[�����י���{� 8#A|<X��j.�z� ��,9z�����L�lw�8
 �|���,9|���� 1�����^ D�<D��W�>(Di!;�Է4@PLnK�+�l
xk�b�g{'0rX����������(xe��Gw%�` ����i��0����'�@���h��vs�.�+����LJ��_w��F�
�s�=íR�qa�
�,T�4+h��ah4s�W0-�
`:�5�b�S��ҋ�`4+}~
��X�¢�?7Pv�n�:��6.ؖ���(���T+�Oa~�������g/ ���K1���� P1$�����&�%�-��ݳ�`Y��@��7	?�랶S������$ah^�Vx�`�/��C��X%��PIփ��6�p�J�V,Jh��!����l�t�h��Jp	� �0%���L�_A������\��@k������j�f��A��l���7Q!���S�,,
ض2�P�����*$>�B�U��Ym��|
Y%a0L*%_z�j�������>��ie�|�F`����a��<�'��=�ho`���j�N:�����{�|~#Ќ�@>�lS��Ǡ�Z}��yn�����	�PZ�z�5��϶�j�rPXX��>�"i���"��Ee�}|+��7�J��`��x~����a����fT��iaW@�C�v=�ì`�)	�l�����Y����P���������x���`��sX�JmЌ���
�k�ځ�I l�6B�C����~�a��PՏ�S�� ��5�l�ύ6�<��:��u�3?�d`^��t-����Xӽ�3g>� �q����荇�Ɏ�A&e���=���(Ͽh�|���o�:�|z�B���qx����#j��m�� q>O3u(l!����P��֏Ÿ�	�Xw������B��=����������]���c'� ���%�^� �ĉ/��Na��hl����ڱ~+z�����[O��gcO�Y�&G3����E`�2w8^����
��-�[�}��q��
�B�^�v'3��z^�C��b�.�~��we��g���a�|�����+!�P�
..5�3Pk`��O�T�\�)�K��е���H��(�O��*���t��d>�." �3Xϡ���f��<�v	�Fa�A"R����Z��Bjt�@� {���gX5��`�r����7I�j��Qv;�va��U长�,W�_Ȕ�] "����LL,Hv6���r��۔XqPOa�کF����ՍԿ��L8�M*��`re�l�Ҭ��6��L����)c~-�@��d&�g�>�����* 6�̡��D�J�(w�rȮ4+��k�9X-�-y�T+�IPu��n	]#�l�H�d��}
�����T�q�6d�L%)�\�p5��Xm��\t6�$�n�
�T;�,���%L�P. + +��a����gK�� �"j�#t��D������{1��XaLޠ\C���QVr�0e`�}<��stV�p3S���j%#t�2{�&(��>���l�%L���8����]�u~-�@��%��B��j)sg��o<,�G�	T��V��sw|�E "�f��`SH�������^j�o��	qJ���
�%�/L�?D!@��o/(�8M���Z�p�L��
,eF��Y!,d���.�jT�f��TZ�����ƽ㼾լ0;�|� ���Ϻ�������,�z�i�;��ւ���h;�ٞ�q|��" �B��uj(���|w(2��� 1=�'�)t�k������`���A6���U%���>N�U���`Ϫ�]j(U��ت�̣�|���c~s�a��5�â����`�C�ӯvR���(F�;X���Ί���}�y`�n�.a�����+}\7̌j�s�/ Ɍ��HTl?����(�a^�v��
���!-�Q����W	���l�443�Y_��d"�����S�&�F~� |�`MRIL�u�j'�幗D�(��[���]���z��W	�A��j��I��lj�+_���p��Fv�5��U��~���:0
h�'0+�A���:�Wz�&-\oE�V9�u��O*  !(2���>P�7+^��WP������ u˩B��Xj�e�c�*�z*a�=,k�y���s%����9o3���m砳$��� �(;�1p��$>�&R&@j�`m����3j�2�5�:�5��E�K�Z��P�K��'�\�+�r�t�`
��Jc�6�ʻg'^c ��
���Q�T�sk4�^� �Fx9_��<7��:��O;�k5�n�Dp�@%0� ����r���9�lg�����W}�<�B����Ҧ*�a[5���D��6.�o�t3��
\b�P�i�����j�R�݉c-�PS���� ��6�2y�!���@S��J�8S*��<����@]�p�8�����z	�7�����,�R]K\T�z��Mje�4B1��QVo}M���r�6
p���e�h�-"���n��<_��d��} Vɷ�C�����p��� ��������`9�m%P�����gk>�doa��(
ͧ� �I���|���<@�
H��XR�Pm����P�~��S`�B�������_
(�J�c� Pb_q�G
E�	�9����Aeo���-��y�Cm`�|��4���C1��@6N�?�q�%颅!�|g�ঀ&������O���B�A}x�Vx�5����M|����P�u.P�枇:@ֻ)��L�(��m�~;��[;X�Фs~�#��?A�� �Uu;��6֝����?P��5��W8�"Z)l��2�����?	RF��D�j���k�O����_.��:�vw����}n��1us�"l6w��l���^������q%��]m�����ys���(sB��f�I���M9�ô��kx�ȹkKa���2��!��7�8���#����fj��h�`bm�C��I�����+�H��wk��J[�Aп����SeAw���� �u�IZ+ϿZ��Ra�����$4O-}Rh�F[��E�޶0��NeK?^�z���5�+pW�|V�u�o�$kj�..H�~���R�~���hVek��M���i���y��+6�1�ys(j)���,%�}Z�i�'(���	����j�}Xmer�UC�W���r=�0��`�����1k���~��:�=3�	�����Ӫ-fi��o���T�g຃�R��>L��9����[�l3���7�Ϗ�[ѓ
@���B�e�#�R�눌���3��5�6 	[o��/�i��%U`w���[��Z�ӕ�����9��PR�Dc$0�=�������I��C�'�c�)�=�.'�JB� m��M%�p�c4n<��.r����g	i��Rg2b�{�I���?�oEO* ET�_��
�'��HE�Q9�@C-��h����؉9�#s��h��X�ԥV0�����[5���:�*��S[����Kѓ޾4Z��^؟XY�&0}��m|��{�f�5���ߤ0l�j�MB����sȯ�핖xc
F%��B~�������c}=�Ȭ��M� �M�o�k�N�Û��J�4�l�a�HCl�o�
 �F���3u����2�æQ���@�Fջ�����E�L9���jKWv�r��-�]}j��RE�ғ
�A��9
��-���aq���D�fo��.�Aк�����`[��͒�����'��h���6���ۅ�gP-�����8�t&�������'u �~��sc�F��`������(�{���ʎ/r9���C6H�����?TV]gR��=�1�e����W�6��������U~�ʾS
�z��]������|�j�+��O�N�B�(2*��,����w?��!�HĢ�]��������ީ1Ŧ�|^�lx��w�8x�Ѥ��=װF���W�^�o�+��GX��k9�	�� ��_��BƠ��v2B�<1=� ���b&��@͟�O7��ߐ_��A�C��±9r�lg�e
/���e�=�ԯǗ��}��1���S��^*����� �+�[���;�@&��3؜0�oE�6>"c�E/R#��؈I�⍾�6�YyB�\)=�s|��m��7�f�w���7�MN�|�rK���M_k�B}&�X{�1�2�oEO�2F^�t!X��)�?�DH*:WG�0�C���B�<���۔}t^�͈�1>(ٳ;�:�V-���~���c��4�G���׎W礋��6F�5��)�k�KH����w�#�Lfa1�)	.5�D69\i)ן�ۏu"�G�J!�3�u�/;�dz&�����ˑN�޾1��7iU�+��3���f��X͙Ǻ�>/PD+�9�)�? &����1�ie:�n(�$e��END�>c/0г� ��ʉ�k	�����|��@�3��<�|)E�9i��'��lã�A:b��&����J�� .�j����@���p�q`�����?�e�v��1�8�x���S� 6i!{�؛ ''�t�$Nvʛ8ο�E4@�x���> �pp������[X��^�<���>�[��/��6�Y�S��1ڨs���JP���o�b�&��`�eu�R���M�C�� ������P�7�uM�ʠs��sz%KG�e�y/Gg�x�E�h-_�U?�*�.�?��<��S�Bچ~	��=�M���d��6�4�=OKP3�Z���k��U!UA�\ xtv0�.�+��	&?&�K�v:�X�>3u�o���N�V)�S���a���	t�-rx���4���Vרr��C��BuT�(F�l��,?����MK��'J~O�^���/ �U�����_J�&F(�ʪr�$��ȑM`PR��P'l~^ï����q{�F��]B��\���m6�!��h/8���qtA������Ju]*r铚��?I;�������_�3�ك�"�p��%�>8���яO�m���:&�B��ka�f��x��"u}7R��M��F�?���<���O�D��Ę�G�+���δ�@��0��`���E�R�s�؈�"�9m�n*�큉v���GG���B���}l�ć�G-�@{ �[��h��M��u��c�|��L5��?��w��$�r&{�J�������Fq��~��t0���?���Z�c��%gz�v����y5�a�L�y����3U���L �ӯ3�y5&g�4|���=@��7���4vi�?0�aO��HC��.�F�i]{�@,��X�/���W��~dB�1��!���0�+�;3r��L����{�D��Bu�3B�Z���u����I�g�2�����ۛJ>DM�a���ܾ�." �A�(|��J�~��i�o�+^i��)���18RE�l�R�|IO�k�	�4ɖ�����X�:C���5Z��:��!,��̢&F4��s%�1=��%i�2B��8�&=����l��>1v�&i��L��s�O��ь�:i��<��iN�A�>��u��M������w�иJWɞ/�H 8!����z=�Ξ�+�1��0)���),\=`BκZ�M���
q��7$�?7�=����,.:����t'�Rc�9JQ�]�?vZ��6p�ޑ̏
\�z�t���-ؕB�!S0�{ �6P���1��=m����h #��.9u�����S��67�m��w�����Wpr�����Q��i#��s���GQ�(Sҧ��򣢚$$�����!c�Oh���y���L����g6�|�R�@0Z_���e| s'���*��f�(� c䴽CM�^K��9��f7R�gx���%j�mb����S8��c=4[�oZi��
gpDӽ��������e�L�>��0k5���L��K�E�����^p�������	k߃9������~�����ɚ`���Q����)-�I����?qki;����'w�!�g��O�:��EB�7�d��R�zoa�4y.E�����R;i֩���ʦg��B`�ڶ�%��C�?�b8��� ��� sa�2���Q�����/�11���{�3D�F!���)���h}��y��(���Wg�,S��KZBR�e*��T��\�,>#�F{���h0�B���3�cp�k`�>s�z�\�y�['e,V:l��`�h�KV]T r�Ρ�Sg���CEH��3m,q�g*��_��IZ�F��Z�䴹��.�L�袰pcd����4�Z�����Z��8�?'JbQ��f��@�x�ǹ�^�t�������ޠ@�n���U�̮�$q����5�Y�Z��7�� �n�kU}��o"  !�o�D�-��f	a'���J5�6�}�wC���C��^��Z��1J�n�as5�7�= �Y��Y��L�F�5�m(�U
�|�!�Pl�~��b��a!l�j1�[���7��߬4l`d^�0�(R���V�N��F� �A6UW��F��֊jfe�N��P�W��R�������#-0�CVj��,ջ/�����~)D���)����5�!=;a"^,���w��J�`R��ϡ����� O𛞤8tX�g���|����ıU�o�#��j��Jv&��aR��[
��&��O&%��p�J�Q���@�����#[=iu�`�M��s�[�݇a��N�x�)�����y6��=�<%��2��3nU-��@.u 1	�mR��9�'!u�gjt���3�bϢ<|����-�p��0��L|(��k�]z�GaX���p��7pe�^MR�CKs�6�f��=#cTX8�bz�R�x%A����Kӳ��������MԆ-�k����S�k�T�K,��#�������ƙ<8t�4�{�!��"��Ȑ	t"�ό�=+Ӟ9�fr����c�C��i�F3t�<%�n�*�=���oe�F�����X���,�?�g+ �t�*�U� $�@�03��;�Pw����G��# ����i_�6�$���(�y�K���5&�$c��'�Q
F�a4{�0��1���R��dGd^:�.@{sv�z��8���"s��co0���H�����	�����_���SL�����H#�����#D>���J/�lHE)��G���Ȍ����c|�/���7`=1D�7�m`���a������H�G!�"�7��'D�OpT*i&O��!��}*e}�D�}�k�Do�;�M0��TJ�!-��brG��P%*����i��.��YB稽寎!柄���L`� H�	@~@��� <;J�7Q�ˬ�!v��9�3���5�<x�l��M��N�z��6S�qǊW����ާ����	����F��� �8�����O�\��p��� m�t2�>��S��RetF��ɠ��h� �f�2a�S.+!2o���{���8�݁��a>if��(�-��	La�%�LB`RS�OҪ���iP�!i�:�E�;|�h�q6�z�
�v#v��H=|M
6��_��ih���k�٧�9������w�C7O����5]���+���FNS�K��    IEND�B`�             ����AI   res://grid.tres-$i�   res://grid_web.tres���S�b   res://icon.pngV����[   res://normal_color.tscn_�Pu���Y   res://normal_color_flat.tres���~k�}   res://Public/Index.icon.pngY$rE��X'   res://Public/Index.apple-touch-icon.png�2�Ή�B   res://Public/Index.png ECFG      application/config/name         NormalPicker   application/run/main_scene          res://normal_color.tscn    application/config/features   "         4.2    application/config/icon         res://icon.png  #   rendering/renderer/rendering_method         gl_compatibility'   rendering/anti_aliasing/quality/msaa_3d                        