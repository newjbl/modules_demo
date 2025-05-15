extends Node3D

@export var mesh_1: MeshInstance3D
@export var mesh_2: MeshInstance3D
@export var tex_1: Texture2D
@export var tex_2: Texture2D

const ATLAS_SIZE = 2048
const SAVE_PATH = "user://mesh_merge/combined_assets/"

func _ready():
	var combined_data = combine_meshes()
	if combined_data:
		save_resources(combined_data)

func combine_meshes() -> Dictionary:
	# 输入验证
	assert(mesh_1 != null && mesh_2 != null, "必须设置两个MeshInstance3D")
	assert(tex_1 != null && tex_2 != null, "必须设置两个贴图")

	# 转换原始网格为可处理的ArrayMesh
	var array_mesh_1 = convert_to_array_mesh(mesh_1.mesh)
	var array_mesh_2 = convert_to_array_mesh(mesh_2.mesh)

	# 创建合并材质系统
	var combined_texture = create_combined_texture(tex_1, tex_2)
	var combined_mat = StandardMaterial3D.new()
	combined_mat.albedo_texture = combined_texture

	# 初始化SurfaceTool
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_material(combined_mat)

	# 处理第一个网格（左半UV）
	process_converted_mesh(st, array_mesh_1, 0.5, Vector2(0, 0))
	# 处理第二个网格（右半UV）
	process_converted_mesh(st, array_mesh_2, 0.5, Vector2(0.5, 0))

	# 生成最终网格
	var combined_mesh = st.commit()
	return {
		"mesh": combined_mesh,
		"texture": combined_texture,
		"material": combined_mat
	}

func convert_to_array_mesh(original_mesh: Mesh) -> ArrayMesh:
	var array_mesh = ArrayMesh.new()
	var st = SurfaceTool.new()
	
	for surface_idx in original_mesh.get_surface_count():
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		
		# 复制表面材质
		var mat = original_mesh.surface_get_material(surface_idx)
		if mat:
			st.set_material(mat)
		
		# 复制网格数据
		st.append_from(original_mesh, surface_idx, Transform3D.IDENTITY)
		st.generate_normals()  # 确保法线存在
		st.commit(array_mesh)
	
	return array_mesh

func process_converted_mesh(st: SurfaceTool, array_mesh: ArrayMesh, uv_scale: float, uv_offset: Vector2):
	var mdt = MeshDataTool.new()
	for surface_idx in array_mesh.get_surface_count():
		mdt.create_from_surface(array_mesh, surface_idx)
		
		# 调整UV坐标
		for i in range(mdt.get_vertex_count()):
			var uv = mdt.get_vertex_uv(i)
			uv.x = uv.x * uv_scale + uv_offset.x
			uv.y = uv.y * uv_scale + uv_offset.y
			mdt.set_vertex_uv(i, uv)
		
		# 写入顶点数据
		for face_idx in range(mdt.get_face_count()):
			for vertex_idx in 3:
				var vidx = mdt.get_face_vertex(face_idx, vertex_idx)
				st.add_vertex(mdt.get_vertex(vidx))
				st.set_normal(mdt.get_vertex_normal(vidx))
				st.set_uv(mdt.get_vertex_uv(vidx))
				if mdt.get_vertex_color(vidx) != Color.WHITE:
					st.set_color(mdt.get_vertex_color(vidx))

func create_combined_texture(t1: Texture2D, t2: Texture2D) -> ImageTexture:
	var image = Image.create(ATLAS_SIZE, ATLAS_SIZE, false, Image.FORMAT_RGBA8)
	
	# 处理第一个贴图
	var img1 = t1.get_image()
	image.blit_rect(img1, Rect2i(0, 0, ATLAS_SIZE, ATLAS_SIZE), Vector2i.ZERO)
	
	# 处理第二个贴图
	var img2 = t2.get_image()
	image.blit_rect(img2, Rect2i(0, 0, ATLAS_SIZE, ATLAS_SIZE), Vector2i(ATLAS_SIZE, 0))
	
	return ImageTexture.create_from_image(image)

func save_resources(data: Dictionary):
	# 创建保存目录
	if not DirAccess.dir_exists_absolute(SAVE_PATH):
		DirAccess.make_dir_absolute(SAVE_PATH)
	
	# 保存贴图
	var tex_path = SAVE_PATH + "combined_texture_%s.png" % Time.get_unix_time_from_system()
	data.texture.get_image().save_png(tex_path)
	
	# 保存材质
	var mat = data.material
	mat.resource_name = "CombinedMaterial"
	var mat_path = SAVE_PATH + "combined_material_%s.tres" % Time.get_unix_time_from_system()
	ResourceSaver.save(mat, mat_path)
	
	# 保存网格
	var mesh = data.mesh
	mesh.resource_name = "CombinedMesh"
	var mesh_path = SAVE_PATH + "combined_mesh_%s.res" % Time.get_unix_time_from_system()
	ResourceSaver.save(mesh, mesh_path)
	
	print("资源保存成功！")
	print("贴图路径：", tex_path)
	print("材质路径：", mat_path)
	print("网格路径：", mesh_path)
