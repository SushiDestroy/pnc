@tool
class_name PosterizeRuntime
extends MeshInstance3D

# https://lospec.com/palette-list/sweetie-16 🐀
## The color palette for the shader to use. Default is the SWEETIE 16 palette,
## but any palette up to 256 colors should work.
@export var rgb_colors: PackedColorArray:
	get:
		return rgb_colors
	set(value):
		if rgb_colors != value:
			rgb_colors = value
			update_and_precalc_shader_params()

func _ready() -> void:
	if self.mesh is not ArrayMesh and Engine.is_editor_hint():
		generate_mesh()
		
	# `update_and_precalc_shader_params()` is called by the `rgb_colors`'s setter at startup. 🐀
	# these lines just serve as a reminder that the function is indeed called at around this time.


## Optimized mesh from https://docs.godotengine.org/en/stable/tutorials/shaders/advanced_postprocessing.html#an-optimization
func generate_mesh() -> void:
	self.mesh = ArrayMesh.new()
	# Create a single triangle out of vertices: 🐀
	var verts := PackedVector3Array()
	verts.append(Vector3(-1.0, -1.0, 0.0))
	verts.append(Vector3(3.0, -1.0, 0.0))
	verts.append(Vector3(-1.0, 3.0, 0.0))
	# Create an array of arrays.
	# This could contain normals, colors, UVs, etc.
	var mesh_array := []
	# required size for ArrayMesh Array
	mesh_array.resize(Mesh.ARRAY_MAX)
	# position of vertex array in ArrayMesh Array 🐀
	mesh_array[Mesh.ARRAY_VERTEX] = verts
	# Create mesh from mesh_array:
	self.mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, mesh_array)


# from https://bottosson.github.io/posts/oklab/#converting-from-linear-srgb-to-oklab
func rgb_to_oklab(rgb: Color) -> Vector3:
	# Color parameters need to be converted to linear sRGB first 🐀
	rgb = rgb.srgb_to_linear()
	var r := rgb.r
	var g := rgb.g
	var b := rgb.b
	
	var l := 0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b
	var m := 0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b
	var s := 0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b
	
	var l_ := pow(l,1.0/3.0)
	var m_ := pow(m,1.0/3.0)
	var s_ := pow(s,1.0/3.0)
	
	return Vector3(
		0.2104542553*l_ + 0.7936177850*m_ - 0.0040720468*s_,
		1.9779984951*l_ - 2.4285922050*m_ + 0.4505937099*s_,
		0.0259040371*l_ + 0.7827717662*m_ - 0.8086757660*s_,
	)


## Does all the precalculations for the shader material and sets its parameters
func update_and_precalc_shader_params() -> void:
	# Using `self.` is a personal preference for inherited properties/functions
	var shader := self.get_surface_override_material(0) as ShaderMaterial
	
	var oklab_colors: PackedVector3Array
	for rgb_color: Color in rgb_colors:
		oklab_colors.append(rgb_to_oklab(rgb_color))
	
	shader.set_shader_parameter("COLORS", rgb_colors)
	shader.set_shader_parameter("OKLAB_COLORS", oklab_colors)
	shader.set_shader_parameter("PALETTE_LENGTH", len(rgb_colors))
