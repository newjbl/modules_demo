@tool
extends Node3D

@export var mesh_1_path: NodePath
@export var mesh_2_path: NodePath
# 将输出目录设为 res://mesh_merge/combined_assets
@export var output_dir: String = "res://mesh_merge/combined_assets"
@export var atlas_filename: String = "combined_texture.png"
@export var mesh_filename: String = "combined_mesh.tres"
@export var atlas_size: Vector2 = Vector2(2048, 1024)

func _ready():
	if Engine.is_editor_hint():
		_save_merged()

func _ensure_output_dir():
	var dir = Directory.new()
	if not dir.dir_exists(output_dir):
		var err = dir.make_dir_recursive(output_dir)
		if err != OK:
			push_error("无法创建目录：%s (错误码 %d)" % [output_dir, err])

func _merge_textures() -> Dictionary:
	var mi1 = get_node(mesh_1_path) as MeshInstance3D
	var mi2 = get_node(mesh_2_path) as MeshInstance3D
	var mat1 = mi1.get_active_material(0) as StandardMaterial3D
	var mat2 = mi2.get_active_material(0) as StandardMaterial3D
	var tex1 = mat1.albedo_texture as Texture2D
	var tex2 = mat2.albedo_texture as Texture2D

	var img1 = tex1.get_image()
	var img2 = tex2.get_image()

	var atlas = Image.create_empty(atlas_size.x, atlas_size.y, false, img1.get_format())
	atlas.fill(Color(0, 0, 0, 1))
	atlas.blit_rect(img1, Rect2(Vector2.ZERO, img1.get_size()), Vector2.ZERO)
	atlas.blit_rect(img2, Rect2(Vector2.ZERO, img2.get_size()), Vector2(img1.get_width(), 0))

	var uv_scale = Vector2(img1.get_width(), img1.get_height()) / atlas_size
	var uv_offsets = [
		Vector2(0, 0),
		Vector2(img1.get_width(), 0) / atlas_size
	]
	return {
		"atlas_image": atlas,
		"uv_scale": uv_scale,
		"uv_offsets": uv_offsets
	}

func _merge_meshes(atlas_data: Dictionary) -> ArrayMesh:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var remap_uv := func (uv: Vector2, idx: int) -> Vector2:
		return uv * atlas_data["uv_scale"] + atlas_data["uv_offsets"][idx]

	for i in [0, 1]:
		var mi = (get_node(mesh_1_path) if i == 0 else get_node(mesh_2_path)) as MeshInstance3D
		var mesh = mi.mesh as ArrayMesh
		var xform = mi.global_transform

		for s in range(mesh.get_surface_count()):
			var arr = mesh.surface_get_arrays(s)
			var uvs = arr[Mesh.ARRAY_TEX_UV]
			for j in range(uvs.size()):
				uvs[j] = remap_uv(uvs[j], i)
			arr[Mesh.ARRAY_TEX_UV] = uvs
			st.append_from(mesh, s, xform)

	st.generate_normals()
	return st.commit()

func _save_merged():
	# 确保输出目录存在
	_ensure_output_dir()

	# 合并贴图和网格
	var atlas_data = _merge_textures()
	var merged_mesh = _merge_meshes(atlas_data)

	# 保存贴图到 res://mesh_merge/combined_assets/combined_texture.png
	var full_tex_path = "%s/%s" % [output_dir, atlas_filename]
	atlas_data["atlas_image"].save_png(full_tex_path)
	var tex = ImageTexture.create_from_image(atlas_data["atlas_image"], 0)

	# 创建材质
	var mat = StandardMaterial3D.new()
	mat.albedo_texture = tex

	# 可选：在场景中创建一个预览用的 MeshInstance3D
	var preview = MeshInstance3D.new()
	preview.mesh = merged_mesh
	preview.material_override = mat
	add_child(preview)

	# 保存网格资源到 res://mesh_merge/combined_assets/combined_mesh.tres
	var full_mesh_path = "%s/%s" % [output_dir, mesh_filename]
	ResourceSaver.save(merged_mesh, full_mesh_path)

	push_warning("已保存合并网格到：%s\n已保存合并贴图到：%s" % [full_mesh_path, full_tex_path])
