# Project Harvest - Asset Attribution Tracker

This document provides complete attribution for all assets used in Project Harvest, ensuring proper credit is given to all creators and sources.

## Table of Contents
- [Textures](#textures)
- [Audio](#audio)
- [Code & Development](#code--development)
- [License Information](#license-information)

---

## Textures

### Foliage Assets
**Source:** AmbientCG (https://ambientcg.com/)  
**License:** CC0 (Creative Commons Zero) - Public Domain  
**Assets Used:**
- `resources/Foliage003_4K-PNG/` - Complete foliage texture set including:
  - `Foliage003_4K-PNG_Color.png` - Diffuse/Albedo map
  - `Foliage003_4K-PNG_Displacement.png` - Height/Displacement map
  - `Foliage003_4K-PNG_NormalDX.png` - Normal map (DirectX format)
  - `Foliage003_4K-PNG_NormalGL.png` - Normal map (OpenGL format)
  - `Foliage003_4K-PNG_Opacity.png` - Alpha/Opacity map
  - `Foliage003_4K-PNG_Roughness.png` - Roughness map
  - `Foliage003_4K-PNG.mtlx` - MaterialX definition
  - `Foliage003_4K-PNG.usdc` - USD material file

**Attribution:** "Foliage003 texture by AmbientCG, licensed under CC0. Available at https://ambientcg.com/"

### Corn Textures
**Source:** Generated with GPT-5  
**Creator:** OpenAI GPT-5  
**License:** Generated content (check OpenAI terms for commercial use)  
**Assets Used:**
- `assets/textures/cornleaf.png` - Corn leaf texture
- `assets/textures/cornleaf_sRGB_ACEScg.png.tx` - Processed corn leaf texture
- `assets/textures/cornstalk.png` - Corn stalk diffuse texture
- `assets/textures/cornstalkao.png` - Corn stalk ambient occlusion map
- `assets/textures/cornstalknormal.png` - Corn stalk normal map
- `assets/textures/cornstalkrough.png` - Corn stalk roughness map

**Attribution:** "Corn textures generated using OpenAI GPT-5"

### Environment Textures
**Source:** Poly Haven (https://polyhaven.com/)  
**License:** CC0 (Creative Commons Zero) - Public Domain  
**Assets Used:**
- `assets/textures/mealie_road_4k.exr` - Mealie Road HDRI environment map

**Attribution:** "Mealie Road HDRI by Greg Zaal, available at Poly Haven (https://polyhaven.com/), licensed under CC0"

---

## Audio

### Sound Effects
**Source:** Stability AI - Stable Audio 1.0  
**License:** Stable Audio Community License  
**Creator:** Generated using Stability AI's Stable Audio 1.0 model  
**Website:** https://stability.ai/

**Assets Used:**
- `resources/audio/cawing cros.mp3` - Crow cawing sound effect
- `resources/audio/ComfyUI_00006_.mp3` - Generated ambient sound
- `resources/audio/ComfyUI_00012_.mp3` - Generated ambient sound  
- `resources/audio/cornrustle.mp3` - Corn rustling sound effect
- `resources/audio/is that the wind.mp3` - Wind ambient sound

**Attribution:** "Audio generated using Stability AI's Stable Audio 1.0 under the Stable Audio Community License"

**License Details:** The Stable Audio Community License allows for non-commercial use. For commercial distribution, verify current licensing terms at https://stability.ai/

---

## Code & Development

### Programming & Scripts
**Primary Developer:** [Your Name/Studio]  
**AI Assistant:** Anthropic Claude-4 Sonnet  
**Development Support:** Code written with assistance from Claude-4 Sonnet

**Key Scripts & Systems:**
- `scripts/autoloads/` - Core game management systems
  - `GameDirector.gd` - Main game flow controller
  - `MazeManager.gd` - Procedural maze generation system
  - `SanityManager.gd` - Player sanity mechanics
  - `WeirdThingsManager.gd` - Horror event system
  - `TileManager.gd` - Tile-based world management
  - `HarvestLogger.gd` - Game logging system

- `scripts/entities/` - Game entity behaviors
  - `Player.gd` - Player controller and mechanics
  - `Watcher.gd` - AI behavior for watcher entities
  - `Stalker.gd` - AI behavior for stalker entities

- `scripts/systems/` - Core systems
  - `InputManager.gd` - Input handling and processing

- `scripts/ui/` - User interface
  - `HUD.gd` - Heads-up display controller

**Attribution:** "Game code developed with assistance from Anthropic Claude-4 Sonnet AI"

### Game Engine
**Engine:** Godot Engine  
**Version:** [Current Godot version used]  
**License:** MIT License  
**Website:** https://godotengine.org/

---

## License Information

### CC0 (Creative Commons Zero)
Assets under CC0 are released into the public domain and can be used for any purpose without attribution required (though attribution is appreciated).

**Applicable Assets:**
- AmbientCG foliage textures
- Poly Haven HDRI environments

### Stable Audio Community License
Audio assets generated with Stability AI's Stable Audio are subject to their community license terms.

**Applicable Assets:**
- All audio files in `resources/audio/`

**Important:** Verify current license terms at https://stability.ai/ before commercial use.

### Generated Content
AI-generated assets (textures, code assistance) should comply with the respective AI service terms of use.

**Applicable Assets:**
- GPT-5 generated corn textures
- Claude-4 Sonnet assisted code

---

## Updates & Maintenance

**Last Updated:** [Current Date]  
**Maintainer:** [Your Name]  

### Notes for Future Asset Additions
1. Always verify license compatibility before adding new assets
2. Update this tracker immediately when adding new assets
3. Keep source URLs and download dates for reference
4. Maintain local copies of license texts for critical assets
5. Review AI service terms regularly as they may change

---

## Contact & Legal

For questions about asset usage or licensing, contact: [Your Contact Information]

**Disclaimer:** This attribution tracker is maintained to the best of our knowledge. Always verify license terms directly with asset creators for commercial or sensitive applications.
