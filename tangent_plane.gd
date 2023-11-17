extends Area3D


func _process(_delta: float) -> void:
	var r:float = %Camera3D.position.z
	var R := .5
	var x := (R * R) / (r + r)
	position.z = x
