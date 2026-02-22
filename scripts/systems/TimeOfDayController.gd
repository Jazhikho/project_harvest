extends Node
## Sun directional light for day phase
@export var sun: DirectionalLight3D
## World environment for fog/ambient
@export var world_env: WorldEnvironment
## Moon directional light for night phase
@export var moon: DirectionalLight3D
## Sky shader material
@export var sky_mat: ShaderMaterial
## Duration in seconds for day-to-night transition
@export var duration_sec: float = GameConstants.TIME_OF_DAY_DURATION_DEFAULT
## Start day/night cycle automatically on _ready
@export var auto_run: bool = true

# Sun
## Sun elevation in degrees at day start
@export var sun_elevation_start: float = 25.0
## Sun elevation in degrees at night end
@export var sun_elevation_end: float = -6.0
## Sun light energy during day
@export var sun_energy_day: float = 2.0
## Sun light energy at twilight
@export var sun_energy_twilight: float = 0.0
## Sun color during day
@export var sun_color_day: Color = Color(1.0, 0.90, 0.78)
## Sun color at twilight
@export var sun_color_twilight: Color = Color(1.0, 0.55, 0.30)

# Ambient
## Ambient energy during day
@export var ambient_energy_day: float = 0.15
## Ambient energy at twilight
@export var ambient_energy_twilight: float = 0.01
## Ambient color during day
@export var ambient_color_day: Color = Color(1.0, 0.95, 0.90)
## Ambient color at twilight
@export var ambient_color_twilight: Color = Color(0.55, 0.64, 0.80)

# Fog
## Volumetric fog density during day
@export var fog_density_day: float = 0.01
## Volumetric fog density at twilight
@export var fog_density_twilight: float = 0.06
## Fog color during day
@export var fog_color_day: Color = Color(1.0, 0.95, 0.90)
## Fog color at twilight
@export var fog_color_twilight: Color = Color(0.40, 0.50, 0.70)

# Sky shader params
## Background energy during day
@export var background_energy_day: float = 1.0
## Background energy at twilight
@export var background_energy_twilight: float = 0.01
## Sky exposure during day
@export var sky_exposure_day: float = 1.0
## Sky exposure at twilight
@export var sky_exposure_twilight: float = 0.01
## Sky rotation 0..1 for horizontal wrap
@export var sky_rot: float = 0.0

var t: float = 0.0
var running: bool = false

func _ready() -> void:
	var env: Environment = world_env.environment
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.volumetric_fog_enabled = true
	_apply(0.0)
	running = auto_run

func _process(delta: float) -> void:
	if !running: return
	if duration_sec <= 0.0:
		t = 1.0
	else:
		t = clamp(t + delta / duration_sec, 0.0, 1.0)
	_apply(t)

func _apply(x: float) -> void:
	var env: Environment = world_env.environment

	# SUN
	if sun:
		var elev: float = lerp(sun_elevation_start, sun_elevation_end, x)
		var r: Vector3 = sun.rotation_degrees
		r.x = - elev
		sun.rotation_degrees = r
		sun.light_energy = lerp(sun_energy_day, sun_energy_twilight, x)
		sun.light_color = sun_color_day.lerp(sun_color_twilight, x)

	# SKY (shader uniforms + overall background multiplier)
	if sky_mat:
		var n: float = x # 0→1 night progress
		sky_mat.set_shader_parameter("blend", n)
		sky_mat.set_shader_parameter("rot", sky_rot)
		sky_mat.set_shader_parameter("exposure", lerp(1.0, 0.35, n)) # go lower if needed
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
