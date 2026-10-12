extends RefCounted
const G=preload("res://scripts/geometry.gd")
static func build(parent: Node3D) -> void:
	var cord=G.material(Color("554932"))
	G.rod(parent,Vector3(-0.018,0,0),Vector3(0,-0.16,0.003),0.003,cord)
	G.rod(parent,Vector3(0.018,0,0),Vector3(0,-0.16,0.003),0.003,cord)
	var wood=G.material(Color("715034"))
	# A thick shield plaque, rather than a floating square image.
	var outline=PackedVector2Array([Vector2(-0.080,0.094),Vector2(0.080,0.094),Vector2(0.080,0.010),Vector2(0.072,-0.024),Vector2(0.051,-0.058),Vector2(0.027,-0.083),Vector2(0,-0.102),Vector2(-0.027,-0.083),Vector2(-0.051,-0.058),Vector2(-0.072,-0.024),Vector2(-0.080,0.010)])
	var st=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in outline.size():
		var a=outline[i];var b=outline[(i+1)%outline.size()]
		for v in [Vector3(a.x,a.y,-0.007),Vector3(b.x,b.y,-0.007),Vector3(a.x,a.y,0.007),Vector3(a.x,a.y,0.007),Vector3(b.x,b.y,-0.007),Vector3(b.x,b.y,0.007)]:st.add_vertex(v)
	st.generate_normals()
	wood.cull_mode=BaseMaterial3D.CULL_DISABLED
	G.mesh(parent,st.commit(),Vector3(0,-0.255,0),wood)
	var face=QuadMesh.new();face.size=Vector2(0.169,0.201)
	var engraving=G.material(Color.WHITE,load("res://assets/ist_wood.svg"))
	engraving.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	engraving.alpha_scissor_threshold=0.5
	for side in [-1,1]:
		var surface=G.mesh(parent,face,Vector3(0,-0.257,side*0.0075),engraving)
		if side<0:surface.rotation.y=PI
	G.sphere(parent,Vector3(0,-0.160,0.009),Vector3(0.008,0.008,0.008),cord)
