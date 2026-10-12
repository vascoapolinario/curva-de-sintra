extends Node3D
const G=preload("res://scripts/geometry.gd")
var spans: Array[Dictionary]=[]
var cells: Dictionary={}
var forest: Node3D
var rail_transforms: Array[Transform3D]=[]

func setup(world: Node3D, runs: Array) -> void:
	forest=world
	var rails: Array[Transform3D]=[]
	var posts: Array[Transform3D]=[]
	var caps: Array[Transform3D]=[]
	var reflectors: Array[Transform3D]=[]
	for run in runs:
		for i in run.size():
			var p=Vector3(run[i][0],0,run[i][1])
			posts.append(Transform3D(Basis.IDENTITY,p+Vector3.UP*0.42))
			caps.append(Transform3D(Basis.IDENTITY,p+Vector3.UP*0.845))
			if i==run.size()-1: continue
			var next=Vector3(run[i+1][0],0,run[i+1][1])
			var direction=next-p
			var length=direction.length()
			if length<0.01: continue
			var frame=Basis(Vector3.UP,atan2(direction.x,direction.z))
			var center=(p+next)*0.5
			for height in [0.36,0.68]:
				rails.append(Transform3D(frame*Basis.from_scale(Vector3(1,1,length+0.045)),center+Vector3.UP*height))
			var id=spans.size()
			spans.append({"position":center,"basis":frame,"half":Vector2(0.075,length*0.5+0.075)})
			var key=Vector2i(floori(center.x/32),floori(center.z/32))
			if not cells.has(key): cells[key]=[]
			cells[key].append(id)
			if i%6==0: reflectors.append(Transform3D(frame,p+Vector3.UP*0.77))
	rail_transforms=rails
	var metal=G.material(Color("3d4447"))
	metal.metallic=0.55
	metal.roughness=0.68
	metal.metallic_specular=0.28
	var edge=G.material(Color("353b3e"))
	edge.metallic=0.5
	edge.roughness=0.72
	var paint=G.material(Color("8e8876"))
	_batch(Vector3(0.075,0.095,1),metal,rails)
	_batch(Vector3(0.115,0.84,0.115),metal,posts)
	_batch(Vector3(0.14,0.035,0.14),edge,caps)
	_batch(Vector3(0.125,0.035,0.045),paint,reflectors)

func _batch(size: Vector3, material: Material, transforms: Array[Transform3D]) -> void:
	var shape=BoxMesh.new()
	shape.size=size
	forest._multimesh(shape,material,transforms)

func blocked(p: Vector3, yaw: float) -> bool:
	var car_basis=Basis(Vector3.UP,yaw)
	var key=Vector2i(floori(p.x/32),floori(p.z/32))
	for x in range(-1,2):
		for z in range(-1,2):
			for id in cells.get(key+Vector2i(x,z),[]):
				var rail=spans[id]
				var separation: Vector3=p-rail.position
				if separation.length_squared()>36: continue
				var frame: Basis=rail.basis
				var half: Vector2=rail.half
				var overlap=true
				for axis in [frame.x,frame.z,car_basis.x,car_basis.z]:
					var radius=absf(axis.dot(frame.x))*half.x+absf(axis.dot(frame.z))*half.y
					radius+=absf(axis.dot(car_basis.x))*1.11+absf(axis.dot(car_basis.z))*1.98
					if absf(separation.dot(axis))>=radius:
						overlap=false
						break
				if overlap: return true
	return false
