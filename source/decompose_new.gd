extends Node3D

@export var children_mesh: MeshInstance3D

func get_neighbor_vertices(vertex_id: int, edges: PackedInt32Array) -> PackedInt32Array:
	var near: PackedInt32Array = []
	for i in range(0, len(edges), 2):
		if vertex_id == edges[i]:
			near.append(edges[i+1])
		elif vertex_id == edges[i+1]:
			near.append(edges[i])
	
	return near

func get_edge_index(va: int, vb: int, edges: PackedInt32Array) -> int:
	for i in range(0, len(edges)/2):
		if va == edges[2*i] && vb == edges[2*i+1]\
		|| vb == edges[2*i] && va == edges[2*i+1]:
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

	print ("Actual edges: ", actual_edges)

	var new_vertices: PackedVector3Array = []
	new_vertices.resize(len(vertices) * 2)
	var new_faces: PackedInt32Array = []
	var new_custom0: PackedFloat32Array = []
	new_custom0.resize(len(vertices) * 4 * 2)
	var new_custom1: PackedFloat32Array = []
	new_custom1.resize(len(vertices) * 4 * 2)

	## Convert each vertex into two vertices
	## Assign next, previous, push
	## Connect the faces

	var new_verts: int = 0
	for i in range(len(vertices)):
		# print("Vector ", i)
		var vertex: Vector3 = vertices[i]

		### ==== COMPUTE NEXT, PREVIOUS ====
		var prev: Vector3
		var next: Vector3
		var neighboring: PackedInt32Array = get_neighbor_vertices(i, edges)
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
			for j in neighboring:
				neighboring_actual.append([j, abs(vertices[j].y - vertex.y)])
			neighboring_actual.sort_custom(func (a,b): return a[1] > b[1])
			prev = vertices[neighboring_actual[0][0]]
			next = vertices[neighboring_actual[1][0]]
			neighboring[2] = neighboring_actual[2][0]
		
		else:
			continue
		### /=== COMPUTE NEXT, PREVIOUS ===/

		### ==== CONVERT EVERY VERTEX INTO TWO ====
		## CUSTOM0: [next.x, next.y, next.z, +-1]
		## CUSTOM1: [prev.x, prev.y, prev.z, +-1] 
		
		new_vertices[2*i]   = vertex
		new_vertices[2*i+1] = vertex

		new_custom0[8*i  ] = next.x
		new_custom0[8*i+1] = next.y
		new_custom0[8*i+2] = next.z
		new_custom0[8*i+3] = +1
		new_custom0[8*i+4] = next.x
		new_custom0[8*i+5] = next.y
		new_custom0[8*i+6] = next.z
		new_custom0[8*i+7] = -1

		new_custom1[8*i  ] = prev.x
		new_custom1[8*i+1] = prev.y
		new_custom1[8*i+2] = prev.z
		new_custom1[8*i+3] = +1
		new_custom1[8*i+4] = prev.x
		new_custom1[8*i+5] = prev.y
		new_custom1[8*i+6] = prev.z
		new_custom1[8*i+7] = -1

		if len(neighboring) != 3:
			continue

		var index: int = get_edge_index(i, neighboring[2], edges)
		var edge: Vector2i = actual_edges[index]
		if edge.x != neighboring[2]:
			edge = Vector2i(edge.y, edge.x)
		actual_edges[index] = Vector2i(edge.x, len(vertices)+new_verts)
		print("Creating new vert at ", len(vertices)+new_verts)
		new_verts += 1

		prev = vertices[neighboring[2]]
		next = vertex + (vertex - prev) 

		new_vertices += PackedVector3Array([vertex, vertex])

		new_custom0  += PackedFloat32Array([next.x, next.y, next.z, +1])
		new_custom0  += PackedFloat32Array([next.x, next.y, next.z, -1])
		new_custom1  += PackedFloat32Array([prev.x, prev.y, prev.z, +1])
		new_custom1  += PackedFloat32Array([prev.x, prev.y, prev.z, -1])


		### /=== CONVERT EVERY VERTEX INTO TWO ===/
	
	print ("Actual edges: ", actual_edges)
	
	for edge in actual_edges:
		var i = edge.x
		var j = edge.y

		new_faces += get_faces(2*i, 2*j)

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
