# Vision-to-Music System

This repository contains the source code for a real-time vision-to-music system using Python, OpenCV, Open Sound Control (OSC), and Csound.

The system uses a camera to analyze visual information and transform it into an interactive musical soundscape.

## Overview

The system detects up to five prominent colored objects in real time. Python and OpenCV analyze each detected object's:

- Horizontal position
- Vertical position
- Relative size
- Dominant color

This information is sent to Csound through OSC, where five continuously running synthesis voices respond to the visual parameters.

Horizontal position controls stereo panning, vertical position controls pitch, chord voicing, or rhythmic patterns depending on the synthesis voice, and relative object size controls parameters including amplitude, filtering, reverb, delay, and modulation.

The dominant color of the scene controls the overall musical mode.

You can also connect a phone camera to the system and move around with your phone to "see" the music and your surroundings through sound. As the camera view changes, the detected objects, positions, sizes, and colors continuously reshape the soundscape.

## Color-to-Mode Mapping

| Color | Musical Mode |
| --- | --- |
| Red | Mixolydian |
| Orange | Ionian |
| Yellow | Lydian |
| Green | Dorian |
| Blue | Aeolian |
| Purple | Phrygian |
| White | Major Pentatonic |
| Black | Locrian |

A dominant color must account for at least 50% of the detected color information and remain stable for 2 seconds before the musical mode changes.

## System Structure

The project consists of three main components:

### Python / OpenCV

Captures the camera image, performs color and contour analysis, identifies up to five object candidates, and extracts their visual parameters.

### Open Sound Control (OSC)

Transfers the detected object information from Python to Csound through UDP on port `7770`.

The system uses two OSC message types:

```text
/object [object_id, x, y, relative_size, color_id]
/mode [color_id]
```

### Csound

Receives the OSC data and maps it to five synthesis voices:

- Harmonic Pad
- Reverse FX
- Bass Drone
- FM Texture Lead
- Harmonic Bell

The Csound system also includes autonomous chord progression and modulation processes that allow the soundscape to continue evolving even when the visual scene remains still.

## Requirements

### Python

- Python 3
- OpenCV
- NumPy
- python-osc

Install the required Python packages with:

```bash
pip install opencv-python numpy python-osc
```

### Csound

Install Csound and make sure your audio output is configured correctly.

The system uses OSC port `7770` for communication between Python and Csound.

## Running the Project

1. Connect or enable your camera.
2. Open the Csound `.csd` file.
3. Start the Csound performance.
4. Open a terminal in the project directory.
5. Run the Python script:

```bash
python src/vision_to_music.py
```

6. Move the camera or place different colored objects in front of it to interact with the soundscape.
7. Click the OpenCV camera window and press `q` to stop the Python program.

## Repository Contents

```text
vision-to-music-system/
├── README.md
└── src/
    ├── vision_to_music.py
    └── vision_to_music.csd
```

## Current Limitations

The current prototype does not maintain persistent object identities across frames. Object IDs are reassigned according to contour-area ranking, and the Python system does not currently send an explicit disappearance message when an object leaves the frame.

Future development will explore persistent object tracking, explicit voice-release handling, performance improvements, additional sound mappings, and mobile or browser-based implementations.