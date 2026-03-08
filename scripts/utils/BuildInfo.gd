extends RefCounted

class_name BuildInfo

const GAME_VERSION: String = "1.6"
const COPYRIGHT_YEAR: String = "2026"
const STUDIO_NAME: String = "Chosen Gaming"
const CREATOR_NAME: String = "Christopher B. Del Gesso"
const CREATOR_ALIAS: String = "jazhikho"

static func get_version_label() -> String:
	return "v%s" % GAME_VERSION

static func get_credits_text() -> String:
	return """[center][b]PROJECT HARVEST[/b]
[i]A Walking Nightmare[/i]
[b]Version %s[/b]

[b]===================================[/b]

[b]CREATED BY[/b]
%s
%s / %s

[b]===================================[/b]

[b]DEVELOPMENT[/b]

[b]Lead Developer & Designer[/b]
%s

[b]Programming[/b]
%s
with assistance from Anthropic Claude-4 Sonnet
and GPT-5.4 (Codex)

[b]3D Art & Modeling[/b]
%s

[b]Audio Design[/b]
%s

[b]Narrative Design[/b]
%s

[b]===================================[/b]

[b]TECHNOLOGY[/b]

[b]Game Engine[/b]
Godot Engine 4.4.1
MIT License
https://godotengine.org/

[b]Programming Languages[/b]
GDScript

[b]3D Software[/b]
Blender 4.5.2 - GNU GPL v3
3DS Max 2026 - Student License
Materialize v1.78 - Texture generation

[b]===================================[/b]

[b]3D MODELS & ASSETS[/b]

[b]Animpic POLY[/b]
Farm Pack & Lite Halloween Pack
Standard License (purchased 2025)
Corn stalks, well, scarecrow, environmental props

[b]Sketchfab Contributors (CC Attribution)[/b]
Samy Belaloui - Low Poly Skeleton
yomans - Key model
Bill Nguyen - Gargoyle
Cat O - Gargoyle
JacksonMGB - Photogrammetry Gargoyle Statue
BunQuest - Altar
Scary - Low Poly Brazier
ClintonAbbott Art - Low Poly Dead Tree
Sousinho - Paper debris
Kirrek - Broken Glass
AnishRoyalinc - Gate apocalyptic rusty
Psychopete696 - CORN MAZE-01
kimmy.k - Low Poly Mobile Phone
donnichols - Flashlight
mohitnuslusion - Vintage Pocket Watch
SCANIMATE_IO - PB153 Notebook Low
Aoerchemix - Pirate Coin
TwilightFox - Old Soviet Backpack
3D History - 49 Star Flag
Errlatte - Anubis bible
Arsen Ismailov - Damaged Chainlink Fence
Excessmensch - wheelbarrow prop
Ret-ouchs - Rusty Lamp
snofaeratu - old railway container, lowpoly
MrUnity - Old Soviet Transformer Low-Poly
Artyooooom - Dirty Water Closet
syedraza - Road Sign
Berk Gedik - Abandoned Toilet Cabin (Low Poly)
sergeilihandristov - Abandoned children's slide

[b]Virtual Museums of Malopolska[/b]
Pocket watch - CC0 Public Domain

[b]===================================[/b]

[b]TEXTURES & MATERIALS[/b]

[b]AmbientCG[/b]
Foliage003, Bark006, Lava002, Rock032, Wood035
CC0 License - Public Domain
https://ambientcg.com/

[b]Poly Haven[/b]
Mealie Road HDRI environment
by Greg Zaal
CC0 License - Public Domain
https://polyhaven.com/

[b]OpenAI GPT-5[/b]
Corn textures
Pumpkin, Flannel textures
Effigy concept designs

[b]IMGonline.com.ua[/b]
Seamless texture processing
https://www.imgonline.com.ua/

[b]Materialize v1.78[/b]
PBR texture generation
by Bounding Box Software
http://www.boundingboxsoftware.com/materialize/

[b]===================================[/b]

[b]AUDIO[/b]

[b]Original Compositions[/b]
%s
with assistance from ElevenLabs
- Project Harvest Main Theme
- Architect's Maze
- High Tension
- Hymn of the Echoes
- The Effigy's Theme
- Who Am I (In the Cornfield) 1, 2, 3

[b]Sound Effects[/b]
%s
- Custom environmental audio
- Gameplay sound effects

[b]===================================[/b]

[b]COPYRIGHT[/b]
[b]© %s %s[/b]
All rights reserved.[/center]""" % [
		GAME_VERSION,
		CREATOR_NAME,
		CREATOR_ALIAS,
		STUDIO_NAME,
		CREATOR_NAME,
		CREATOR_NAME,
		CREATOR_NAME,
		CREATOR_NAME,
		CREATOR_NAME,
		CREATOR_NAME,
		CREATOR_NAME,
		COPYRIGHT_YEAR,
		CREATOR_NAME,
	]
