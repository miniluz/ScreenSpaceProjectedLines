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

func _ready() -> void:
	print(name)
	var raw_mesh: ArrayMesh = children_mesh.mesh
	
	var surface_number: int = raw_mesh.get_surface_count() 

	print("Surface number: ", surface_number)

	print("Type: ", raw_mesh.surface_get_primitive_type(0))
	
	var vertices: PackedVector3Array = raw_mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var edges: PackedInt32Array = raw_mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX]

	print("Edges: ", edges)
	
	var actual_edges: Array = []
	for i in range(0,len(edges),2):
		actual_edges.append(Vector2i(edges[i], edges[i+1]))

	var new_vertices: PackedVector3Array = []
	var new_faces: PackedInt32Array = []
	var new_custom0: PackedFloat32Array = []
	var new_custom1: PackedFloat32Array = []

	## Convert each vertex into two vertices
	## Assign next, previous, push
	## Connect the faces

	for i in range(len(vertices)):
		print("Vector ", i)
		var vertex: Vector3 = vertices[i]

		### ==== COMPUTE NEXT, PREVIOUS ====
		var prev: Vector3
		var next: Vector3
		var neighboring: PackedInt32Array = get_neighbor_vertices(i, actual_edges)
		print("Neighbors: ", neighboring)

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
		
		## If there are more than two:
		elif len(neighboring) == 3:
			# Get the two closest vertically
			var neighboring_array: Array = [] # [[index, y_diff]]
			for j in neighboring:
				neighboring_array.append([j, abs(vertices[j].y - vertex.y)])
			neighboring_array.sort_custom(func (a, b): return a[1] < b[1])

			prev = vertices[neighboring_array[0][0]]
			next = vertices[neighboring_array[1][0]]
		##
		else:
			continue
		### /=== COMPUTE NEXT, PREVIOUS ===/

		### ==== CONVERT EVERY VERTEX INTO TWO ====
		## CUSTOM0: [next.x, next.y, next.z, +-1]
		## CUSTOM1: [prev.x, prev.y, prev.z, +-1] 
		new_vertices.append(vertex)
		new_vertices.append(vertex)

		print("prev: ", prev)
		print("vert: ", vertex)
		print("next: ", next)

		new_custom0.append(next.x)
		new_custom0.append(next.y)
		new_custom0.append(next.z)
		new_custom0.append(+1)
		new_custom0.append(next.x)
		new_custom0.append(next.y)
		new_custom0.append(next.z)
		new_custom0.append(-1)

		new_custom1.append(prev.x)
		new_custom1.append(prev.y)
		new_custom1.append(prev.z)
		new_custom1.append(+1)
		new_custom1.append(prev.x)
		new_custom1.append(prev.y)
		new_custom1.append(prev.z)
		new_custom1.append(-1)
		### /=== CONVERT EVERY VERTEX INTO TWO ===/
	
	for edge in actual_edges:
		var i = edge.x
		var j = edge.y

		## i     2i *-* 2i+1
		## | ==>    |X|
		## j     2j *-* 2j+1

		new_faces.append(2*i)
		new_faces.append(2*j+1)
		new_faces.append(2*j)

		new_faces.append(2*i)
		new_faces.append(2*i+1)
		new_faces.append(2*j)

		new_faces.append(2*i)
		new_faces.append(2*i+1)
		new_faces.append(2*j+1)

		new_faces.append(2*i+1)
		new_faces.append(2*j+1)
		new_faces.append(2*j)

	## Generate new mesh from this data

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
