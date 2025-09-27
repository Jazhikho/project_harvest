extends Node

@export var sun: DirectionalLight3D
@export var world_env: WorldEnvironment
@export var moon: DirectionalLight3D
@export var sky_mat: ShaderMaterial         # Sky → Sky Material (shader_type sky)
@export var duration_sec := 90.0
@export var auto_run := true

# Sun
@export var sun_elevation_start := 25.0     # degrees
@export var sun_elevation_end := -6.0
@export var sun_energy_day := 2.0
@export var sun_energy_twilight := 0.0
@export var sun_color_day := Color(1.0, 0.90, 0.78)
@export var sun_color_twilight := Color(1.0, 0.55, 0.30)

# Ambient
@export var ambient_energy_day := 0.15
@export var ambient_energy_twilight := 0.01
@export var ambient_color_day := Color(1.0, 0.95, 0.90)
@export var ambient_color_twilight := Color(0.55, 0.64, 0.80)

# Fog
@export var fog_density_day := 0.01
@export var fog_density_twilight := 0.06
@export var fog_color_day := Color(1.0, 0.95, 0.90)
@export var fog_color_twilight := Color(0.40, 0.50, 0.70)

# Sky shader params
@export var background_energy_day := 1.0
@export var background_energy_twilight := 0.01
@export var sky_exposure_day := 1.0
@export var sky_exposure_twilight := 0.01
@export var sky_rot := 0.0                  # 0..1 horizontal wrap

var t := 0.0
var running := false

func _ready() -> void:
	var env := world_env.environment
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.volumetric_fog_enabled = true
	_apply(0.0)
	running = auto_run

func _process(delta: float) -> void:
	if !running: return
	t = 1.0 if duration_sec <= 0.0 else clamp(t + delta / duration_sec, 0.0, 1.0)
	_apply(t)

func _apply(x: float) -> void:
	var env := world_env.environment

	# SUN
	if sun:
		var elev : float = lerp(sun_elevation_start, sun_elevation_end, x)
		var r := sun.rotation_degrees
		r.x = -elev
		sun.rotation_degrees = r
		sun.light_energy = lerp(sun_energy_day, sun_energy_twilight, x)
		sun.light_color = sun_color_day.lerp(sun_color_twilight, x)

	# SKY (shader uniforms + overall background multiplier)
	if sky_mat:
		var n := x # 0→1 night progress
		sky_mat.set_shader_parameter("blend", n)
		sky_mat.set_shader_parameter("rot", sky_rot)
		sky_mat.set_shader_parameter("exposure", lerp(1.0, 0.35, n))  # go lower if needed
	env.background_energy_multiplier = lerp(background_energy_day, background_energy_twilight, x)

	# AMBIENT
	env.ambient_light_energy = lerp(ambient_energy_day, ambient_energy_twilight, x)
	env.ambient_light_color = ambient_color_day.lerp(ambient_color_twilight, x)

	# FOG
	env.volumetric_fog_density = lerp(fog_density_day, fog_density_twilight, x)
	env.volumetric_fog_albedo = fog_color_day.lerp(fog_color_twilight, x)

	# MOON
	if moon:
		moon.light_energy = lerp(0.0, 0.02, x)
		moon.light_color = Color(0.60, 0.70, 1.00)

# QoL
func restart() -> void: t = 0.0; running = true; _apply(t)
func pause() -> void: running = false
func resume() -> void: running = true
func jump_to(progress: float) -> void: t = clamp(progress, 0.0, 1.0); _apply(t)
