@tool
extends EditorScenePostImport

func _post_import(scene):
	iterate(scene)
	return scene

func get_neighbor_vertices(vertex_id: int, edges: PackedInt32Array) -> PackedInt32Array:
	# Gets a vertex id and the edges and returns all neighbors
	var near: PackedInt32Array = []
	for i in range(0, len(edges), 2): # For every edge (pair of vertices)
		if vertex_id == edges[i]:
			near.append(edges[i+1])
		elif vertex_id == edges[i+1]:
			near.append(edges[i])
	
	return near

func get_edge_index(va: int, vb: int, edges: PackedInt32Array) -> int:
	# Get half of an edge's index based on it's component vertices
	for i in range(0, len(edges), 2):
		if va == edges[i] && vb == edges[i+1]\
		|| vb == edges[i] && va == edges[i+1]:
			return i
	push_error("Not found!")
	return 0

func get_faces(va: int, vb: int) -> PackedInt32Array:
	## va     va *-* va+1
	## |  ==>    |X|
	## vb     vb *-* vb+1

	return PackedInt32Array([va  , va+1, vb+1,\
	va+1, vb+1, vb,\
	va  , vb+1, vb,\
	va  , va+1, vb])

func iterate(node) -> void:
	if not (node is MeshInstance3D):
		for child in node.get_children():
			iterate(child)
	else:
		process_mesh(node)
	

func process_mesh(node):	
	var raw_mesh: ArrayMesh = node.mesh
	
	# var surface_number: int = raw_mesh.get_surface_count() 

	# print("Surface number: ", surface_number)

	# print("Type: ", raw_mesh.surface_get_primitive_type(0))
	
	var vertices: PackedVector3Array = raw_mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var edges: PackedInt32Array = raw_mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX]

	# print("Edges: ", len(edges) / 2)
	# print("Verts: ", len(vertices))
	
	var nv: int = 4 # new verts per vert
	
	var new_edges: PackedInt32Array = []
	for vertex in edges:
		new_edges.append(nv * vertex)
	
	var new_vertices: PackedVector3Array = []
	new_vertices.resize(len(vertices) * nv)
	var new_faces: PackedInt32Array = []
	var new_custom0: PackedFloat32Array = []
	new_custom0.resize(len(vertices) * 4 * nv)
	var new_custom1: PackedFloat32Array = []
	new_custom1.resize(len(vertices) * 4 * nv)

	## Convert each vertex into two vertices
	## Assign next, previous, push
	## Connect the faces

	var new_verts: int = 0
	
	for vertex_index in range(len(vertices)):
		# print(vertex_index * nv, ", ", new_edges)

		var vertex: Vector3 = vertices[vertex_index]

		### ==== COMPUTE NEXT, PREVIOUS ====
		var prev: Vector3
		var next: Vector3
		var neighboring: PackedInt32Array = get_neighbor_vertices(vertex_index, edges)
		# print("Neighbors: ", neighboring)

		## If there are no edges:
		if len(neighboring) == 0:
			continue # forget

		## If there is only one neighboring:
		elif len(neighboring) == 1:
			prev = vertices[neighboring[0]] # add the neighbor as previous
			next = vertex + vertex - prev # p -- v -- n to keep the end straight

		## If there are exactly two:
		elif len(neighboring) == 2:
			prev = vertices[neighboring[0]]
			next = vertices[neighboring[1]]
		
		elif len(neighboring) == 3:
			var neighboring_actual = []
			for neighbor in neighboring:
				neighboring_actual.append([neighbor, (vertices[neighbor] - vertex).length_squared()])
			neighboring_actual.sort_custom(func (a,b): return a[1] < b[1])
			prev = vertices[neighboring_actual[0][0]]
			next = vertices[neighboring_actual[1][0]]
			neighboring[2] = neighboring_actual[2][0]
		
		else:
			continue
		### /=== COMPUTE NEXT, PREVIOUS ===/

		### ==== CONVERT EVERY VERTEX INTO TWO ====
		## CUSTOM0: [next.x, next.y, next.z, +-1]
		## CUSTOM1: [prev.x, prev.y, prev.z, +-1] 

		var i = vertex_index
		
		new_vertices[nv*i]   = vertex
		new_vertices[nv*i+1] = vertex
		new_vertices[nv*i+2] = vertex
		new_vertices[nv*i+3] = vertex

		# Luz joint!
		new_faces += PackedInt32Array([nv*i, nv*i+1, nv*i+2])
		new_faces += PackedInt32Array([nv*i, nv*i+1, nv*i+3])

		new_custom0[nv*4*i  ] = next.x
		new_custom0[nv*4*i+1] = next.y
		new_custom0[nv*4*i+2] = next.z
		new_custom0[nv*4*i+3] = +1
		new_custom0[nv*4*i+4] = next.x
		new_custom0[nv*4*i+5] = next.y
		new_custom0[nv*4*i+6] = next.z
		new_custom0[nv*4*i+7] = -1
		new_custom0[nv*4*i+ 8] = next.x
		new_custom0[nv*4*i+ 9] = next.y
		new_custom0[nv*4*i+10] = next.z
		new_custom0[nv*4*i+11] = +1
		new_custom0[nv*4*i+12] = next.x
		new_custom0[nv*4*i+13] = next.y
		new_custom0[nv*4*i+14] = next.z
		new_custom0[nv*4*i+15] = -1

		new_custom1[nv*4*i  ] = prev.x
		new_custom1[nv*4*i+1] = prev.y
		new_custom1[nv*4*i+2] = prev.z
		new_custom1[nv*4*i+3] = +1
		new_custom1[nv*4*i+4] = prev.x
		new_custom1[nv*4*i+5] = prev.y
		new_custom1[nv*4*i+6] = prev.z
		new_custom1[nv*4*i+7] = -1
		new_custom1[nv*4*i+ 8] = prev.x
		new_custom1[nv*4*i+ 9] = prev.y
		new_custom1[nv*4*i+10] = prev.z
		new_custom1[nv*4*i+11] = -1
		new_custom1[nv*4*i+12] = prev.x
		new_custom1[nv*4*i+13] = prev.y
		new_custom1[nv*4*i+14] = prev.z
		new_custom1[nv*4*i+15] = +1


		if len(neighboring) == 3:
			var edge_index: int = get_edge_index(vertex_index, neighboring[2], edges)
			# print("index: ", edge_index)
			# print("(", new_edges[edge_index], ", ", new_edges[edge_index+1], ") ", neighboring[2])

			if new_edges[edge_index] != neighboring[2] * nv:
				new_edges[edge_index] = new_edges[edge_index+1]
			
			new_edges[edge_index+1] = nv*len(vertices)+new_verts*2
			# print("Creating new vert at ", nv*len(vertices)+new_verts*2)
			new_verts += 1

			prev = vertices[neighboring[2]]
			next = vertex + (vertex - prev) 

			new_vertices += PackedVector3Array([vertex, vertex])

			new_custom0  += PackedFloat32Array([next.x, next.y, next.z, +1])
			new_custom0  += PackedFloat32Array([next.x, next.y, next.z, -1])
			new_custom1  += PackedFloat32Array([prev.x, prev.y, prev.z, +1])
			new_custom1  += PackedFloat32Array([prev.x, prev.y, prev.z, -1])


		### /=== CONVERT EVERY VERTEX INTO TWO ===/
	
	# print ("New edges: ", new_edges)
	
	for i in range(0, len(new_edges), 2):
		var a = new_edges[i]
		var b = new_edges[i+1]

		new_faces += get_faces(a, b)
	
	# for i in range(len(new_vertices)):
	# 	print(i, ": ", new_vertices[i])

	var new_mesh = ArrayMesh.new()

	var new_arrays: Array = []
	new_arrays.resize(Mesh.ARRAY_MAX)
	new_arrays[Mesh.ARRAY_VERTEX ] = new_vertices
	new_arrays[Mesh.ARRAY_INDEX  ] = new_faces
	new_arrays[Mesh.ARRAY_CUSTOM0] = new_custom0
	new_arrays[Mesh.ARRAY_CUSTOM1] = new_custom1

	var flags: int = 0;
	flags = flags | Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT
	flags = flags | Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT
	
	new_mesh.add_surface_from_arrays(Mesh.PrimitiveType.PRIMITIVE_TRIANGLES, new_arrays, [], {}, flags)
	new_mesh.surface_set_material(0, raw_mesh.surface_get_material(0))

	var child_mesh_instance: MeshInstance3D = MeshInstance3D.new()
	child_mesh_instance.mesh = new_mesh

	var packed_scene = PackedScene.new()
	packed_scene.pack(child_mesh_instance)

	ResourceSaver.save(new_mesh, "res://assets/processed/hey.res")
