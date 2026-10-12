extends Node3D
const G=preload("res://scripts/geometry.gd")
var face_material: StandardMaterial3D
var speed_needle: Node3D
var rpm_needle: Node3D
var trip: Label3D
var headlight_indicator: Node3D
var shown_speed=0.0
var shown_rpm=850.0

func _ready() -> void:
	position=Vector3(-0.49,1.067,-0.535)
	scale=Vector3.ONE*0.84
	var vinyl=G.material(Color("232823"),load("res://assets/vinyl.png"))
	var recess=G.material(Color("0b100e"))
	var rim=G.material(Color("333a33"))
	rim.metallic=0.45
	rim.roughness=0.64
	face_material=G.material(Color("101813"))
	face_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	# A moulded, round-cornered binnacle instead of a rectangular image panel.
	_shell(Vector2(0.716,0.364),0.082,0.14,vinyl)
	var insert=_shell(Vector2(0.678,0.328),0.073,0.008,recess)
	insert.position.z=0.076
	speed_needle=_dial(Vector3(-0.169,0.018,0.087),80,8,"km/h",rim)
	rpm_needle=_dial(Vector3(0.169,0.018,0.087),6,6,"rpm × 1000",rim)
	trip=_text("000.0",Vector3(-0.169,-0.047,0.094),0.00044,Color("b2b796"))
	trip.font_size=29
	_text("km",Vector3(-0.169,-0.068,0.094),0.00033,Color("858f75"))
	# Only a real headlamp telltale, with its state tied to the physical switch.
	headlight_indicator=Node3D.new()
	headlight_indicator.position=Vector3(0,0.048,0.096)
	add_child(headlight_indicator)
	var green=G.material(Color("729a68"),null,0.2)
	green.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	G.box(headlight_indicator,Vector3(0.004,0,0),Vector3(0.008,0.012,0.002),green)
	for y in [-0.004,0.0,0.004]:
		G.box(headlight_indicator,Vector3(-0.007,y,0),Vector3(0.008,0.0014,0.002),green)
	reset()

func _shell(size: Vector2, radius: float, depth: float, material: Material) -> MeshInstance3D:
	var outline: Array[Vector2]=[]
	for corner in 4:
		var center=Vector2(1 if corner in [0,3] else -1,1 if corner<2 else -1)*(size*0.5-Vector2.ONE*radius)
		for step in 9:
			var angle=deg_to_rad(corner*90+step*90.0/8)
			outline.append(center+Vector2(cos(angle),sin(angle))*radius)
	var surface=SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in outline.size():
		var a=Vector3(outline[i].x,outline[i].y,depth*0.5)
		var p=outline[(i+1)%outline.size()]
		var b=Vector3(p.x,p.y,depth*0.5)
		var c=Vector3(p.x,p.y,-depth*0.5)
		var d=Vector3(a.x,a.y,-depth*0.5)
		for vertex in [Vector3(0,0,depth*0.5),b,a,a,b,c,a,c,d]:
			surface.set_uv(Vector2(vertex.x/size.x+0.5,vertex.y/size.y+0.5))
			surface.add_vertex(vertex)
	surface.generate_normals()
	return G.mesh(self,surface.commit(),Vector3.ZERO,material)

func _dial(at: Vector3, maximum: float, divisions: int, unit: String, rim: Material) -> Node3D:
	var dial=Node3D.new()
	dial.position=at
	add_child(dial)
	var disc=CylinderMesh.new()
	disc.top_radius=0.133
	disc.bottom_radius=0.133
	disc.height=0.012
	disc.radial_segments=64
	var face=G.mesh(dial,disc,Vector3(0,0,-0.009),face_material)
	face.rotation.x=PI/2
	var ring=TorusMesh.new()
	ring.inner_radius=0.131
	ring.outer_radius=0.137
	ring.rings=64
	ring.ring_segments=6
	var bezel=G.mesh(dial,ring,Vector3.ZERO,rim)
	bezel.rotation.x=PI/2
	var ink=G.material(Color("818d70"))
	ink.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	var red=G.material(Color("a65f49"))
	red.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	for tick in divisions*5+1:
		var fraction=float(tick)/(divisions*5)
		var angle=deg_to_rad(140-fraction*280)
		var major=tick%5==0
		var length=0.013 if major else 0.006
		var radial=Vector3(-sin(angle),cos(angle),0)
		var mark=G.box(dial,radial*(0.121-length/2)+Vector3(0,0,0.004),Vector3(0.002 if major else 0.001,length,0.001),red if maximum==6 and fraction>=0.83 else ink)
		mark.rotation.z=angle
		if major:
			_text(str(roundi(fraction*maximum)),at+radial*0.094+Vector3(0,0,0.005),0.00048,Color("8b9679"))
	_text(unit,at+Vector3(0,-0.034,0.005),0.00032,Color("7b876b"))
	var pivot=Node3D.new()
	pivot.position.z=0.013
	dial.add_child(pivot)
	var needle=SurfaceTool.new()
	needle.begin(Mesh.PRIMITIVE_TRIANGLES)
	for vertex in [Vector3(-0.003,-0.019,0),Vector3(0,0.109,0),Vector3(0.003,-0.019,0)]: needle.add_vertex(vertex)
	needle.generate_normals()
	var paint=G.material(Color("b99a6b"))
	paint.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	paint.cull_mode=BaseMaterial3D.CULL_DISABLED
	G.mesh(pivot,needle.commit(),Vector3.ZERO,paint)
	var cap=G.cylinder(dial,Vector3(0,0,0.018),0.010,0.008,G.material(Color("292f29")))
	cap.rotation.x=PI/2
	return pivot

func _text(text: String, at: Vector3, pixel: float, color: Color) -> Label3D:
	var label=G.label(self,text,at,32,color)
	label.pixel_size=pixel
	var font=SystemFont.new()
	font.font_names=PackedStringArray(["Consolas","Courier New"])
	label.font=font
	return label

func reset() -> void:
	shown_speed=0
	shown_rpm=850
	update_readings(1,0,850,0,true)

func update_readings(delta: float, speed: float, rpm: float, distance: float, headlights: bool) -> void:
	shown_speed=lerpf(shown_speed,absf(speed)*3.6,1.0-exp(-delta*8))
	shown_rpm=lerpf(shown_rpm,rpm,1.0-exp(-delta*10))
	speed_needle.rotation.z=deg_to_rad(140-clampf(shown_speed/80,0,1)*280)
	rpm_needle.rotation.z=deg_to_rad(140-clampf(shown_rpm/6000,0,1)*280)
	trip.text="%05.1f" % (distance/1000)
	headlight_indicator.visible=headlights
