extends Node3D

@export var children_mesh: MeshInstance3D

func get_neighbor_vertices(vertex_id: int, edges: Array) -> PackedInt32Array:
	var near: PackedInt32Array = []
	for edge in edges:
		if vertex_id == edge[0]:
			near.append(edge[1])
		elif vertex_id == edge[1]:
			near.append(edge[0])
	
	return near

func get_faces(va_matches: PackedInt32Array, vb_matches: PackedInt32Array) -> PackedInt32Array:
	var new_faces: PackedInt32Array = []
	for va in va_matches:
		for vb in vb_matches:
			## va     va *-* va+1
			## |  ==>    |X|
			## vb     vb *-* vb+1

			new_faces += PackedInt32Array([va  , va+1, vb+1]) #  \|
			new_faces += PackedInt32Array([va+1, vb+1, vb  ]) #  /|
			new_faces += PackedInt32Array([va  , vb+1, vb  ]) # |\ 
			new_faces += PackedInt32Array([va  , va+1, vb  ]) # |/

	return new_faces


func _ready() -> void:
	print(name)
	var raw_mesh: ArrayMesh = children_mesh.mesh
	
	# var surface_number: int = raw_mesh.get_surface_count() 

	# print("Surface number: ", surface_number)

	# print("Type: ", raw_mesh.surface_get_primitive_type(0))
	
	var vertices: PackedVector3Array = raw_mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var edges: PackedInt32Array = raw_mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX]

	# print("Edges: ", len(edges) / 2)
	# print("Verts: ", len(vertices))
	
	var actual_edges: Array = []
	for i in range(0,len(edges),2):
		actual_edges.append(Vector2i(edges[i], edges[i+1]))

	var vertices_map: Array = range(len(vertices)).map(func (_a): return PackedInt32Array())

	var new_vertices: PackedVector3Array = []
	var new_faces: PackedInt32Array = []
	var new_custom0: PackedFloat32Array = []
	var new_custom1: PackedFloat32Array = []

	## Convert each vertex into two vertices
	## Assign next, previous, push
	## Connect the faces

	var count: int = 0;
	for i in range(len(vertices)):
		# print("Vector ", i)
		var vertex: Vector3 = vertices[i]

		### ==== COMPUTE NEXT, PREVIOUS ====
		var prev: Vector3
		var next: Vector3
		var neighboring: PackedInt32Array = get_neighbor_vertices(i, actual_edges)
		# print("Neighbors: ", neighboring)

		## If there are no edges:
		if len(neighboring) == 0:
			continue # forget

		## If there is only one neighboring:
		elif len(neighboring) == 1:
			prev = vertices[neighboring[0]] # add the neighbor as previous
			next = vertex + vertex - prev # p -- v -- n to keep the end straight

		## If there are exactly two:
		elif len(neighboring) == 2 || len(neighboring) == 3:
			prev = vertices[neighboring[0]]
			next = vertices[neighboring[1]]
		
		else:
			continue
		### /=== COMPUTE NEXT, PREVIOUS ===/

		### ==== CONVERT EVERY VERTEX INTO TWO ====
		## CUSTOM0: [next.x, next.y, next.z, +-1]
		## CUSTOM1: [prev.x, prev.y, prev.z, +-1] 

		new_vertices += PackedVector3Array([vertex, vertex])
		vertices_map[i].append(count)
		count += 2

		new_custom0  += PackedFloat32Array([next.x, next.y, next.z, +1])
		new_custom0  += PackedFloat32Array([next.x, next.y, next.z, -1])
		new_custom1  += PackedFloat32Array([prev.x, prev.y, prev.z, +1])
		new_custom1  += PackedFloat32Array([prev.x, prev.y, prev.z, -1])

		if len(neighboring) != 3:
			continue

		prev = vertices[neighboring[1]]
		next = vertices[neighboring[2]]

		new_vertices += PackedVector3Array([vertex, vertex])
		vertices_map[i].append(count)
		count += 2

		new_custom0  += PackedFloat32Array([next.x, next.y, next.z, +1])
		new_custom0  += PackedFloat32Array([next.x, next.y, next.z, -1])
		new_custom1  += PackedFloat32Array([prev.x, prev.y, prev.z, +1])
		new_custom1  += PackedFloat32Array([prev.x, prev.y, prev.z, -1])

		prev = vertices[neighboring[0]]
		next = vertices[neighboring[2]]

		new_vertices += PackedVector3Array([vertex, vertex])
		vertices_map[i].append(count)
		count += 2

		new_custom0  += PackedFloat32Array([next.x, next.y, next.z, +1])
		new_custom0  += PackedFloat32Array([next.x, next.y, next.z, -1])
		new_custom1  += PackedFloat32Array([prev.x, prev.y, prev.z, +1])
		new_custom1  += PackedFloat32Array([prev.x, prev.y, prev.z, -1])




		### /=== CONVERT EVERY VERTEX INTO TWO ===/
	
	for edge in actual_edges:
		var i = edge.x
		var j = edge.y

		new_faces += get_faces(vertices_map[i], vertices_map[j])

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

	var child_mesh_instance = MeshInstance3D.new()
	child_mesh_instance.mesh = new_mesh
	child_mesh_instance.set_surface_override_material(0, children_mesh.get_surface_override_material(0))

	add_child(child_mesh_instance)
	children_mesh.queue_free()
