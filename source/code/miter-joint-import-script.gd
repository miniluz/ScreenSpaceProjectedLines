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
	
	var vertices: PackedVector3Array = raw_mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var edges: PackedInt32Array = raw_mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX]

	var nv: int = 2 # how many vertices each vertex gets turned into.
	
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
	## Create the two luz vertices
	## Assign next, previous, current
	## Create the faces based on the old vertices

	var vertices_created: int = 0
	
	for vertex_index in range(len(vertices)):

		var vertex: Vector3 = vertices[vertex_index]

		### ==== Compute next, previous ====
		var prev: Vector3
		var next: Vector3
		var neighboring: PackedInt32Array = get_neighbor_vertices(vertex_index, edges)

		if len(neighboring) == 0:
			continue # skip if it has no neighbors

		elif len(neighboring) == 1:
			prev = vertices[neighboring[0]] # add the neighbor as previous
			next = vertex + vertex - prev # p -- v -- n to keep the end straight

		elif len(neighboring) == 2:
			prev = vertices[neighboring[0]]
			next = vertices[neighboring[1]]
		
		elif len(neighboring) == 3:
			var neighboring_actual = [] # needed because you can't sort PackedInt32Arrays
			for neighbor in neighboring:
				neighboring_actual.append([neighbor, (vertices[neighbor] - vertex).length_squared()]) # Sort by distance
			neighboring_actual.sort_custom(func (a,b): return a[1] < b[1])

			prev = vertices[neighboring_actual[0][0]] # Keep the two nearest connected
			next = vertices[neighboring_actual[1][0]]
			neighboring[2] = neighboring_actual[2][0] # Later make a new connection for the furthest
		
		else:
			continue # skip if it has too many neighbors
		### /=== Compute next, previous ===/

		### ==== Convert every vertex ====
		## CUSTOM0: [next.x, next.y, next.z, +-1]
		## CUSTOM1: [prev.x, prev.y, prev.z, +-1] 

		var i = vertex_index
		
		new_vertices[nv*i]   = vertex
		new_vertices[nv*i+1] = vertex

		new_custom0[nv*4*i  ] = next.x
		new_custom0[nv*4*i+1] = next.y
		new_custom0[nv*4*i+2] = next.z
		new_custom0[nv*4*i+3] = +1
		new_custom0[nv*4*i+4] = next.x
		new_custom0[nv*4*i+5] = next.y
		new_custom0[nv*4*i+6] = next.z
		new_custom0[nv*4*i+7] = -1
		
		new_custom1[nv*4*i  ] = prev.x
		new_custom1[nv*4*i+1] = prev.y
		new_custom1[nv*4*i+2] = prev.z
		new_custom1[nv*4*i+3] = +1
		new_custom1[nv*4*i+4] = prev.x
		new_custom1[nv*4*i+5] = prev.y
		new_custom1[nv*4*i+6] = prev.z
		new_custom1[nv*4*i+7] = -1

		if len(neighboring) == 3:
			var edge_index: int = get_edge_index(vertex_index, neighboring[2], edges) # Get the index of the edge

			if new_edges[edge_index] != neighboring[2] * nv: # swap to preserve other vertex if needed
				new_edges[edge_index] = new_edges[edge_index+1]
			
			new_edges[edge_index+1] = nv*len(vertices)+vertices_created*2 # connect it to a new vertex
			vertices_created += 1

			prev = vertices[neighboring[2]]
			next = vertex + (vertex - prev) 

			new_vertices += PackedVector3Array([vertex, vertex])

			new_custom0  += PackedFloat32Array([next.x, next.y, next.z, +1])
			new_custom0  += PackedFloat32Array([next.x, next.y, next.z, -1])
			new_custom1  += PackedFloat32Array([prev.x, prev.y, prev.z, +1])
			new_custom1  += PackedFloat32Array([prev.x, prev.y, prev.z, -1])


		### /=== Convert every vertex ===/
	
	### ==== Turn each edge into a face ====

	for i in range(0, len(new_edges), 2):
		var a = new_edges[i]
		var b = new_edges[i+1]

		new_faces += get_faces(a, b)
	
	### /=== Turn each edge into a face ===/

	# Generate new mesh
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

	ResourceSaver.save(new_mesh, "res://assets/processed/"+raw_mesh.resource_name+".res")
