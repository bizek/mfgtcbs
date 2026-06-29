extends Node3D
## Assigns the toon/face shader materials to the mascot's mesh surfaces by name,
## so it works whether the glb has one mesh with 2 surfaces or two mesh nodes.

@export var body_material: ShaderMaterial
@export var face_material: ShaderMaterial


func _ready() -> void:
	_apply_materials(self)


func _apply_materials(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_instance: MeshInstance3D = node
		var mesh: Mesh = mesh_instance.mesh
		if mesh:
			for i in range(mesh.get_surface_count()):
				var surf_name: String = mesh.surface_get_name(i)
				if surf_name == "Mascot_Body" and body_material:
					mesh_instance.set_surface_override_material(i, body_material)
				elif surf_name == "Mascot_Face" and face_material:
					mesh_instance.set_surface_override_material(i, face_material)
				else:
					print("flame_test: unrecognized surface '%s' on %s (idx %d)" % [surf_name, mesh_instance.name, i])
	for child in node.get_children():
		_apply_materials(child)
