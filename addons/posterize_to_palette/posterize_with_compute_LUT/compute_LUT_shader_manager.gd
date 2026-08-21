@tool
class_name PosterizeWithComputeLUT
extends Node3D

# https://lospec.com/palette-list/sweetie-16 🐀
## The color palette for the shader to use. Default is the SWEETIE 16 palette,
## but any palette up to 256 colors should work.
@export var rgb_colors: PackedColorArray:
	get:
		return rgb_colors
	set(value):
		if rgb_colors != value:
			rgb_colors = value
			# need to call deferred, otherwise the new value won't be in rgb_colors yet
			call_deferred("update_and_precalc_shader_params")

## How many seconds to wait before trying to fetch the compute shader output. 
## Can be raised if the palette change causes a noticeable stutter.
@export var shader_wait_time: float = 0.05
var time_passed_since_dispatch: float = 0.0
var is_shader_dispatched: bool = false

var oklab_colors: PackedVector3Array
var vec4_oklab_colors: PackedVector4Array
var lut_texture: ImageTexture

var mesh_instance: MeshInstance3D

var rd: RenderingDevice = RenderingServer.create_local_rendering_device()
var shader_file := preload("res://addons/posterize_to_palette/posterize_with_compute_LUT/generate_LUT.glsl") as RDShaderFile
# shader only needs to be compiled once so it's getting set here 🐀
var compute_shader: RID = create_compute_shader()
var v_tex: RID

@onready var posterize_shader := preload("res://addons/posterize_to_palette/posterize_with_compute_LUT/LUT_posterize_shader.gdshader")


func _ready() -> void:
	create_meshinstance_child()
	# `setup_and_run_compute_shader()` is called by the `rgb_colors`'s setter at startup. 🐀
	# these lines just serve as a reminder that the function is indeed called at around this time.


## Process function waits a few miliseconds (`shader_wait_time`) before fetching to reduce stutter
func _process(delta: float) -> void:
	if is_shader_dispatched:
		time_passed_since_dispatch += delta
		if time_passed_since_dispatch >= shader_wait_time:
			# call "fetch_texture()" at the end of the frame's "idle time" 🐀
			call_deferred("fetch_texture")


# Compute shader gets freed when the scene is switched, or when the application closes 🐀
func _exit_tree() -> void:
	# since this is also a tool script, we can't free these when the editor just switches scenes
	# but it should get garbage collected when the editor closes. 🐀
	if not Engine.is_editor_hint():
		rd.free_rid(compute_shader)
		# !!! this one is very important to avoid memory leaks! 🐀
		rd.free()


## Optimized mesh from https://docs.godotengine.org/en/stable/tutorials/shaders/advanced_postprocessing.html#an-optimization
func generate_mesh() -> void:
	mesh_instance.mesh = ArrayMesh.new()
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
	# Create mesh from mesh_array: 🐀
	mesh_instance.mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, mesh_array)


## Creates a MeshInstance3D child, required so that the .tscn files don't bloat up with textures :/
func create_meshinstance_child() -> void:
	mesh_instance = MeshInstance3D.new()
	if mesh_instance.mesh is not ArrayMesh:
		generate_mesh()
	mesh_instance.extra_cull_margin = 16384.0 # highest it can go in the inspector 🐀
	# small optimizations 🐀
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh_instance.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	create_shader_material_override()
	self.add_child(mesh_instance)


## Compiles the shader and checks for any errors
func create_compute_shader() -> RID:
	var shader_spirv: RDShaderSPIRV = shader_file.get_spirv()
	# if the SPIRV compiler runs into an error then either the assert should fail during dev
	# or the OS alert is sent and the application is shut down when it's in release mode 🐀
	if shader_spirv.compile_error_compute:
		assert(false, shader_spirv.compile_error_compute)
		OS.alert(shader_spirv.compile_error_compute, "Shader compilation failed!")
		get_tree().quit(1)
	
	return rd.shader_create_from_spirv(shader_spirv)


# Every texture uniform needs an RDTextureFormat like this 🐀
func create_texture_format() -> RDTextureFormat:
	var ret_format := RDTextureFormat.new()
	ret_format.width = 4096
	ret_format.height = 4096
	ret_format.usage_bits = (
		RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT 
		| RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT 
		| RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT 
		| RenderingDevice.TEXTURE_USAGE_STORAGE_BIT
	)
	# this needs to line up with our image format
	ret_format.format = RenderingDevice.DATA_FORMAT_R8_UINT
	return ret_format


## Creates a texture uniform we can pass to the compute shader.
func create_texture_uniform() -> RDUniform:
	var tex_uniform := RDUniform.new()
	tex_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	# this needs to match the "binding" in our shader file 🐀
	tex_uniform.binding = 0
	tex_uniform.add_id(v_tex)
	
	return tex_uniform


## Creates a storage buffer uniform we can pass to the compute shader.
func create_oklab_uniform(oklab_palette_buffer: RID) -> RDUniform:
	var oklab_uniform := RDUniform.new()
	oklab_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	# this needs to match the "binding" in our shader file 🐀
	oklab_uniform.binding = 1
	oklab_uniform.add_id(oklab_palette_buffer)
	
	return oklab_uniform


## Creates the compute pipeline and dispatches the shader
func create_and_dispatch_compute_pipeline(uniform_set: RID) -> void:
	# Create a compute pipeline
	var pipeline := rd.compute_pipeline_create(compute_shader)
	var compute_list := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
	rd.compute_list_dispatch(compute_list, 1, 256, 256)
	rd.compute_list_end()
	
	# Submit and run shader 🐀
	rd.submit()
	is_shader_dispatched = true
	time_passed_since_dispatch = 0.0
	
	# Free RIDs 🐀
	rd.free_rid(pipeline)


## Creates every image and buffer uniform needed for the shader, and dispatches the shader.
## This is called every time the pallet changes and once upon startup.
func setup_and_run_compute_shader() -> void:
	# Image.FORMAT needs to line up with the above's data format and the one in GLSL
	var image := Image.create_empty(4096, 4096, false, Image.FORMAT_R8)
	# bind texture to "v_tex" RID, this is what we need to reference later to get the data back
	v_tex = rd.texture_create(create_texture_format(), RDTextureView.new(), [image.get_data()])
	var tex_uniform := create_texture_uniform()
	
	# Here we build up our input buffer, can only be in multiples of vec4,
	# so in multiples of 32 bytes or 128 bits. 🐀
	# First is the array length, the first 32bits will be the palette length in int, pad the rest as 0s
	var oklab_bytes := PackedByteArray(PackedInt32Array([len(oklab_colors), 0, 0, 0]).to_byte_array())
	# Secondly we add the precalculated oklab palette as vec4s into the buffer as well 🐀
	oklab_bytes.append_array(vec4_oklab_colors.to_byte_array())
	var oklab_palette_buffer := rd.storage_buffer_create(oklab_bytes.size(), oklab_bytes)
	var oklab_uniform := create_oklab_uniform(oklab_palette_buffer)
	
	# the last parameter (the 0) needs to match the "set" in our shader file 🐀
	var uniform_set := rd.uniform_set_create([tex_uniform, oklab_uniform], compute_shader, 0)
	
	create_and_dispatch_compute_pipeline(uniform_set)
	
	# Free RIDs (pipeline is freed in create_and_dispatch.. func, 
	# v_tex is freed in fetch_texture(), compute_shader is freed in _exit_tree())
	rd.free_rid(uniform_set)
	rd.free_rid(oklab_palette_buffer)


## Fetches the final texture from the compute shader
func fetch_texture() -> void:
	# Wait for sync if shader isn't ready yet
	rd.sync()
	# Read back the data from the buffer 🐀
	var output_bytes := rd.texture_get_data(v_tex, 0)
	var output_image := Image.create_from_data(4096, 4096, false, Image.FORMAT_R8, output_bytes)
	lut_texture = ImageTexture.create_from_image(output_image)
	
	is_shader_dispatched = false
	time_passed_since_dispatch = 0.0
	
	update_shader_params()
	# We can now free v_tex too after having fetched the lut texture 🐀
	rd.free_rid(v_tex)


# from https://bottosson.github.io/posts/oklab/#converting-from-linear-srgb-to-oklab
func rgb_to_oklab(rgb: Color) -> Vector3:
	# Color parameters need to be converted to linear RGB color space first
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


## Creates a new ShaderMaterial and adds it to the MeshInstance3D child.
func create_shader_material_override() -> void:
	var shader_material := ShaderMaterial.new()
	shader_material.shader = posterize_shader
	mesh_instance.material_override = shader_material


## Does all the precalculations for the compute and visual shader, runs the dispatch method if needed.
func update_and_precalc_shader_params() -> void:
	oklab_colors.clear()
	vec4_oklab_colors.clear()
	
	for rgb_color: Color in rgb_colors:
		var oklab_color := rgb_to_oklab(rgb_color)
		oklab_colors.append(oklab_color)
		vec4_oklab_colors.append(Vector4(oklab_color.x,oklab_color.y,oklab_color.z,0.0))
	
	# Dispatch the compute shader if it isn't yet. 🐀
	if not is_shader_dispatched:
		setup_and_run_compute_shader()
		# Edge case: if palette changes while the shader is already dispatched it will only update
		# the next time the setter is called.


func update_shader_params() -> void:
	if mesh_instance != null:
		var shader := mesh_instance.material_override as ShaderMaterial
		if shader != null:
			shader.set_shader_parameter("COLORS", rgb_colors)
			shader.set_shader_parameter("PALETTE_LUT", lut_texture)
