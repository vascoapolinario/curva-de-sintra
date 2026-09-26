extends RefCounted
const G=preload("res://scripts/geometry.gd")

static func build(forest: Node3D) -> void:
	var stone=G.material(Color("a1a190"),load("res://assets/weathered_stone.png"))
	var moss=G.material(Color("414a33"),load("res://assets/ground.png"))
	var wood=G.material(Color("77654b"),load("res://assets/bark.png"))
	var cut=G.material(Color("ae9570"))
	var dark=G.material(Color("1b231f"))
	var plaster=G.material(Color("c3c0ac"),load("res://assets/weathered_stone.png"))
	# Compatibility rendering produces self-shadow bands on these small distant
	# props. They still cast onto the ground and receive the actual light falloff.
	for material in [stone,moss,wood,cut,dark,plaster]: material.disable_receive_shadows=true
	for feature in forest.region.landmarks:
		var n=Node3D.new()
		n.name=feature.kind.capitalize()
		n.position=Vector3(feature.position[0],0,feature.position[1])
		n.rotation.y=feature.yaw
		forest.add_child(n)
		# A soft patch of moonlight gives each clearing a readable silhouette.
		# It is confined to the landmark; the surrounding woods stay dark.
		var moon_bounce=OmniLight3D.new()
		moon_bounce.position=Vector3(0,5,4)
		moon_bounce.light_color=Color("8b9d9b")
		moon_bounce.light_energy=0.65
		moon_bounce.omni_range=16
		n.add_child(moon_bounce)
		match feature.kind:
			"pond":
				var water=G.material(Color("566c63"),null,0.06)
				water.disable_receive_shadows=true
				water.roughness=0.23
				G.cylinder(n,Vector3(0,0.015,0),6.5,0.04,moss)
				var pool=G.cylinder(n,Vector3(0,0.035,0),5.9,0.035,water)
				pool.scale.z=0.72
				for i in 29:
					var a=i*2.4
					var p=Vector3(cos(a)*6.1,0,sin(a)*4.5)
					G.rod(n,p,p+Vector3(0.12,0.8+0.3*sin(i),0.13),0.025,moss)
				# A small weathered jetty makes the water legible in headlights.
				for i in 8: G.box(n,Vector3(0,0.3,4.5-i*0.32),Vector3(1.7,0.09,0.28),wood)
				for x in [-0.76,0.76]: G.rod(n,Vector3(x,0,4.4),Vector3(x,1.1,4.4),0.09,wood)
				for x in [-0.76,0.76]:
					G.rod(n,Vector3(x,0,2.2),Vector3(x,1.1,2.2),0.09,wood)
					G.rod(n,Vector3(x,1.05,2.2),Vector3(x,1.05,4.4),0.055,wood)
			"cross":
				for i in 3: G.box(n,Vector3(0,0.13+i*0.23,0),Vector3(2.7-i*0.6,0.26,2.7-i*0.6),stone)
				G.box(n,Vector3(0,2.25,0),Vector3(0.43,3.2,0.43),stone)
				G.box(n,Vector3(0,3.15,0),Vector3(1.85,0.43,0.43),stone)
				G.box(n,Vector3(0,0.68,0.66),Vector3(0.65,0.33,0.06),dark)
				G.label(n,"CRUZ ALTA",Vector3(0,0.68,0.70),32,Color("bab79e")).pixel_size=0.0017
			"quarry":
				for row in 3:
					for i in 7-row:
						var rock=G.sphere(n,Vector3(-5+i*1.65+row*0.45,0.6+row*1.3,-row*1.2),Vector3(3.0,2.7,3.1),stone)
						rock.rotation=Vector3(i*0.14,row*0.5+i*0.3,0.12)
				for x in [-3,3]: G.rod(n,Vector3(x,0,4),Vector3(x,1.2,4),0.08,wood)
				G.rod(n,Vector3(-3,0.85,4),Vector3(3,0.85,4),0.06,wood)
			"fountain":
				G.box(n,Vector3(0,1.4,0),Vector3(3.6,2.8,0.8),stone)
				G.box(n,Vector3(0,2.85,0),Vector3(4.0,0.24,1.0),stone)
				G.box(n,Vector3(0,1.9,0.45),Vector3(1.6,0.62,0.09),plaster)
				G.label(n,"FONTE FRIA",Vector3(0,1.9,0.51),40,Color("334047")).pixel_size=0.003
				G.box(n,Vector3(0,0.3,1.0),Vector3(2.9,0.6,1.5),stone)
				G.box(n,Vector3(0,0.62,1.0),Vector3(2.5,0.04,1.13),dark)
				G.rod(n,Vector3(0,1.25,0.4),Vector3(0,1.25,0.95),0.055,dark)
				G.rod(n,Vector3(0,1.23,0.94),Vector3(0,0.63,0.94),0.018,G.material(Color("a3b5ac")))
			"chapel":
				G.box(n,Vector3(0,0.18,0),Vector3(6.4,0.36,7.0),stone)
				G.box(n,Vector3(0,2.1,0),Vector3(5.6,3.9,6.2),plaster)
				var tiles=G.material(Color("644b3c"),load("res://assets/bark.png"))
				for side in [-1,1]:
					var roof=G.box(n,Vector3(side*1.5,4.42,0),Vector3(3.5,0.18,7),tiles)
					roof.rotation.z=-side*0.36
				G.box(n,Vector3(0,1.53,3.16),Vector3(1.65,2.65,0.12),wood)
				G.box(n,Vector3(0,1.57,3.24),Vector3(0.045,2.6,0.035),dark)
				G.box(n,Vector3(0,4.9,2.1),Vector3(1.3,1.7,0.6),stone)
				G.box(n,Vector3(0,5.1,2.42),Vector3(0.61,0.8,0.035),dark)
				G.cylinder(n,Vector3(0,5.06,2.49),0.20,0.35,wood,0.11)
				G.box(n,Vector3(0,6.15,2.1),Vector3(0.13,0.95,0.13),stone)
				G.box(n,Vector3(0,6.34,2.1),Vector3(0.6,0.13,0.13),stone)
				for x in [-1.9,1.9]:
					G.box(n,Vector3(x,2.55,3.14),Vector3(0.48,0.95,0.08),dark)
					G.box(n,Vector3(x,2.55,3.20),Vector3(0.06,0.95,0.04),stone)
				G.box(n,Vector3(0,3.26,3.16),Vector3(1.4,0.4,0.05),stone)
				G.label(n,"ERMIDA",Vector3(0,3.26,3.20),42,Color("353c34")).pixel_size=0.003
				var candle=OmniLight3D.new()
				candle.position=Vector3(1.1,0.55,3.5)
				candle.light_color=Color("e4aa64")
				candle.light_energy=0.55
				candle.omni_range=5
				n.add_child(candle)
				G.cylinder(n,Vector3(1.1,0.42,3.5),0.10,0.22,G.material(Color("ba6a31"),null,0.5))
		var points: PackedVector3Array=forest.roads[int(feature.road)]
		var at: int=maxi(1,int(feature.sample)-12)
		forest._place_sign(points[at],(points[at+1]-points[at]).normalized(),feature.label)
	for feature in forest.region.obstacles:
		var n=Node3D.new()
		n.name="RoadHazard"
		n.position=Vector3(feature.position[0],0,feature.position[1])
		n.rotation.y=feature.yaw
		forest.add_child(n)
		if feature.kind=="log":
			G.rod(n,Vector3(-1.75,0.34,0),Vector3(1.75,0.34,0),0.32,wood)
			for side in [-1,1]:
				G.rod(n,Vector3(side*1.75,0.34,0),Vector3(side*1.77,0.34,0),0.27,cut)
				G.rod(n,Vector3(side*0.6,0.43,0),Vector3(side*1.1,0.85,0.4),0.07,wood)
		else:
			for i in 9:
				var x=sin(i*2.4)*1.02
				var z=cos(i*2.4)*1.38
				var rock=G.sphere(n,Vector3(x,0.25+0.11*(i%3),z),Vector3(1.30,0.8+0.18*(i%3),1.4),stone)
				rock.rotation=Vector3(i*0.15,i*0.73,i*0.12)
		# Reflectors on the verge catch the beams before the obstruction does.
		var side: float=feature.side
		for z in [-9,9]:
			G.rod(n,Vector3(side*1.9,0,z),Vector3(side*1.9,0.85,z),0.034,wood)
			G.box(n,Vector3(side*1.9,0.7,z),Vector3(0.16,0.15,0.1),G.material(Color("b99a58"),null,0.12))
