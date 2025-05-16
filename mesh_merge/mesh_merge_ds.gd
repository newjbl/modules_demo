extends Node

@export var mesh_1: MeshInstance3D
@export var mesh_2: MeshInstance3D
@export var texture_1: Texture2D
@export var texture_2: Texture2D

const SAVE_PATH = "res://mesh_merge/combined_assets/"

func _ready():
	combine_and_save()

func combine_and_save():
	if not create_save_directory():
		push_error("无法创建保存目录")
		return
	
	var combined_mesh = merge_meshes()
	var combined_texture = merge_textures()
	
	if combined_mesh and combined_texture:
		apply_material(combined_mesh, combined_texture)
		save_resources(combined_mesh, combined_texture)
	else:
		push_error("合并失败，请检查输入参数")

func create_save_directory() -> bool:
	var dir = DirAccess.open("res://")
	if dir.make_dir_recursive(SAVE_PATH) != OK:
		return DirAccess.dir_exists_absolute(SAVE_PATH)
	return true

func merge_meshes() -> ArrayMesh:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	# 处理第一个网格
	process_mesh(mesh_1, st, 0.0)
	# 处理第二个网格
	process_mesh(mesh_2, st, 0.5)
	
	var combined = ArrayMesh.new()
	st.generate_normals()  # 自动生成法线（如果原始网格没有法线数据）
	st.commit(combined)
	return combined

func process_mesh(mesh_node: MeshInstance3D, st: SurfaceTool, x_offset: float):
	if not mesh_node or not mesh_node.mesh is ArrayMesh:
		return
	
	var mesh = mesh_node.mesh as ArrayMesh
	var transform = mesh_node.global_transform
	
	for surface_idx in mesh.get_surface_count():
		var arrays = mesh.surface_get_arrays(surface_idx)
		var verts = arrays[Mesh.ARRAY_VERTEX]
		var uvs = arrays[Mesh.ARRAY_TEX_UV] if Mesh.ARRAY_TEX_UV < arrays.size() else []
		var indices = arrays[Mesh.ARRAY_INDEX] if Mesh.ARRAY_INDEX < arrays.size() else []
		
		st.set_color(Color.WHITE)  # 设置默认颜色
		
		if indices.size() > 0:
			process_indexed_geometry(verts, uvs, indices, transform, st, x_offset)
		else:
			process_non_indexed_geometry(verts, uvs, transform, st, x_offset)

func process_indexed_geometry(verts, uvs, indices, transform, st: SurfaceTool, x_offset: float):
	for idx in indices:
		var vertex = transform * verts[idx]
		var uv = adjust_uv(uvs[idx], x_offset) if uvs.size() > idx else Vector2.ZERO
		st.set_uv(uv)
		st.add_vertex(vertex)

func process_non_indexed_geometry(verts, uvs, transform, st: SurfaceTool, x_offset: float):
	for i in verts.size():
		var vertex = transform * verts[i]
		var uv = adjust_uv(uvs[i], x_offset) if uvs.size() > i else Vector2.ZERO
		st.set_uv(uv)
		st.add_vertex(vertex)

func adjust_uv(original_uv: Vector2, x_offset: float) -> Vector2:
	# 水平压缩并偏移UV坐标
	return Vector2(original_uv.x * 0.5 + x_offset, original_uv.y)

func merge_textures() -> Texture2D:
	if not texture_1 or not texture_2:
		push_error("缺少贴图资源")
		return null
	
	var img1 = texture_1.get_image()
	var img2 = texture_2.get_image()
	
	if not img1 or not img2:
		push_error("无法从贴图获取图像数据")
		return null
	
	if img1.is_compressed():
		img1.decompress()
	if img2.is_compressed():
		img2.decompress()
	# 统一图像格式
	img1.convert(Image.FORMAT_RGBA8)
	img2.convert(Image.FORMAT_RGBA8)
	
	# 创建新图像（水平合并）
	var new_width = img1.get_width() + img2.get_width()
	var new_height = max(img1.get_height(), img2.get_height())
	var combined_img = Image.create(new_width, new_height, false, Image.FORMAT_RGBA8)
	
	# 合并图像
	combined_img.blit_rect(img1, Rect2i(0, 0, img1.get_width(), img1.get_height()), Vector2i(0, 0))
	combined_img.blit_rect(img2, Rect2i(0, 0, img2.get_width(), img2.get_height()), Vector2i(img1.get_width(), 0))
	
	return ImageTexture.create_from_image(combined_img)

func apply_material(mesh: ArrayMesh, texture: Texture2D):
	var material = StandardMaterial3D.new()
	material.albedo_texture = texture
	material.metallic = 0.0
	material.roughness = 1.0
	mesh.surface_set_material(0, material)

func save_resources(mesh: ArrayMesh, texture: Texture2D):
	var mesh_path = SAVE_PATH + "combined_mesh.tres"
	var tex_path = SAVE_PATH + "combined_texture.png"
	
	# 保存网格
	var err = ResourceSaver.save(mesh, mesh_path)
	if err == OK:
		print("网格保存成功：", mesh_path)
	else:
		push_error("网格保存失败：%s" % error_string(err))
	
	# 保存贴图
	err = ResourceSaver.save(texture, tex_path)
	if err == OK:
		print("贴图保存成功：", tex_path)
	else:
		push_error("贴图保存失败：%s" % error_string(err))
