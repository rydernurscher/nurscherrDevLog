
***

# Project: Elden-Terraria (Working Title)

A procedurally generated 2D action-adventure sandbox built in Godot 4.6. This project aims to synthesize the sandbox depth of **Terraria**, the atmospheric weight and cinematic combat of **Elden Ring**, and the fluid, responsive movement of **Dead Cells**.

## ⚔️ The Vision
The goal is to create a 2D side-scroller that feels "Heavy" and "Cinematic." Unlike traditional 2D sandboxes that focus on bright, vibrant colors, this project utilizes high-contrast color grading, volumetric lighting, and precise combat mechanics to tell a story through the environment.

*   **Terraria:** Procedural world generation, mining, and world-layering (Background vs. Foreground).
*   **Elden Ring:** Challenging stamina-based combat, "Site of Grace" atmosphere, and oppressive environmental storytelling.
*   **Dead Cells:** Fluid character animations, high-velocity movement, and satisfying combat feedback.

## 🛠️ Technical Highlights
This repository serves as a development log for the following custom systems:

### 1. Advanced Procedural World Gen
*   **Chunk-Based Architecture:** The world is divided into manageable chunks to allow for massive map sizes without performance degradation.
*   **Bi-Layered Terrain:** A dual-layer system for foreground blocks and background walls, featuring a bitmasking algorithm that handles organic transitions.
*   **Stepped Lighting & Depth:** A custom shading system that calculates "Block Depth," naturally fading the world into darkness as the player ventures below the surface.

### 2. Cinematic Post-Processing
To achieve the "Elden" vibe, the project uses a heavy custom post-processing stack:
*   **Grace Rays:** Volumetric God-rays that simulate light piercing through canopy and ruins.
*   **Color Grading:** Luma-based split toning (Teal shadows / Tarnished Gold highlights).
*   **Lens Effects:** Subtle Chromatic Aberration and Vignetting to create a "painterly" feel.
*   **Atmospheric Embers:** A screen-space ash/ember system that adds texture to the air.

### 3. Souls-like Character Controller
*   **State-Machine Movement:** A robust state machine handling Idle, Run, Roll, Attack, and Flight.
*   **Tactical Combat:** Stamina-dependent rolls with I-frames and attack durations that punish "spamming."
*   **Physics-Based Mining:** Direct interaction with the procedural world data, updating lighting and neighbor bitmasks in real-time.

## 📁 Project Structure
*   `res://World/`: World generation logic, chunk management, and environmental structures.
*   `res://Player/`: Character framework, logic-driven animations, and UI systems.
*   `res://assets/`: Pixel art textures and Tileset resources.
*   `res://World/Effects/Shaders/`: The core GLSL code for the game's visual identity.

## 🚀 Current Status
The project is currently in the **Technical Foundation** phase. 
*   [x] Procedural terrain generation with cave systems.
*   [x] Responsive character controller with combat stats.
*   [x] Background/Foreground wall and block system.
*   [ ] High-end post-processing pipeline.
*   [ ] Procedural tree/landmark spawning (In Progress).
*   [ ] Enemy AI and Boss encounter framework (Planned).

## 🎮 How to Run
1. Click latest release in 'releases' tab
2. Download the 'example'.exe file
3. Play

   OR
   
1.  Clone this repository.
2.  Open the project in **Godot 4.4+**.
3.  Ensure the rendering backend is set to **Forward+** to support the post-processing shaders.
4.  Run `res://World/WorldTerrain/Scenes/World.tscn`.

***

*Developed with the goal of proving that 2D sandboxes can be just as atmospheric and challenging as modern 3D ARPGs.*
