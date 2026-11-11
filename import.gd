@tool
extends EditorScript

const SOURCE := "res://models/MuseumAsset/MuseumAsset.fbx"
const OUT_DIR := "res://models/split/"

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var root: Node = (load(SOURCE) as PackedScene).instantiate()
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		var obj_name := String(mi.name)
		

		# Save the mesh (and its materials) as its own resource
		var mesh_path := OUT_DIR + obj_name + ".res"
		ResourceSaver.save(mi.mesh, mesh_path)

		# Build a small scene: Node3D root with the mesh as a child
		var holder := Node3D.new()
		holder.name = obj_name
		var piece := MeshInstance3D.new()
		piece.name = "Mesh"
		piece.mesh = load(mesh_path)
		holder.add_child(piece)
		piece.owner = holder

		var scene := PackedScene.new()
		scene.pack(holder)
		ResourceSaver.save(scene, OUT_DIR + obj_name + ".tscn")
		holder.free()

	root.free()
	EditorInterface.get_resource_filesystem().scan()
