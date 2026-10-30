# Vision-to-Music

## Description

Vision-to-Music is a real-time interactive music system developed using Python, OpenCV, and Csound. It translates visual information captured by a camera into an evolving musical soundscape, exploring how sound can provide an alternative way of experiencing visual environments.

The system detects up to five prominent colored regions and uses their positions, relative sizes, and dominant colors to control musical parameters, with potential applications in accessibility and interactive sound design.

## Requirements

Before using Vision-to-Music, make sure you have:

- Python 3 installed: https://www.python.org/
- OpenCV, NumPy, and python-osc installed.
- Csound 6.18 installed: https://csound.com/
- CsoundQt installed: https://csoundqt.github.io/
- A webcam or compatible camera input.

Install the required Python packages using:

```bash
pip install opencv-python numpy python-osc
```

## Features

### 1. Computer Vision

Vision-to-Music uses Python and OpenCV to detect and track up to five prominent colored regions in real time. Each detected region is assigned an object ID and tracked across frames to maintain continuity.

The system extracts each region's normalized horizontal and vertical positions, relative size, and dominant color for musical mapping.

### 2. Open Sound Control (OSC)

Python communicates with Csound through OSC using UDP port `7770` and three message types:

- **`/object`:** Sends object ID, horizontal position, vertical position, relative size, and color ID.
- **`/mode`:** Sends the confirmed dominant color ID.
- **`/gone`:** Notifies Csound when a tracked object disappears.

### 3. Visual-to-Sound Mapping

The detected visual information controls different synthesis parameters in Csound:

- **Horizontal Position (X):** Controls stereo panning across all five instruments, with additional modulation creating movement within the stereo field.
- **Vertical Position (Y):** Controls chord voicing in the Harmonic Pad, rhythmic patterns in the Reverse FX, melodic pitch in the FM Texture Lead, and rhythmic and melodic variations in the Harmonic Bell.
- **Relative Size:** Controls amplitude and filter cutoff across all five instruments, rhythmic speed in the Reverse FX and Harmonic Bell, FM modulation depth in the FM Texture Lead, and the amount of reverb and delay.
- **Dominant Color:** Selects one of eight musical modes, determining the shared harmonic structure and chord progressions.

### 4. Color-to-Mode Mapping and Chord Progressions

Vision-to-Music maps eight colors to eight musical modes, each with its own four-chord progression:

| Color | Musical Mode | Chord Progression (Scale Degrees) |
| --- | --- | --- |
| Red | Mixolydian | 0 – 0 – 6 – 3 |
| Orange | Ionian | 0 – 4 – 5 – 3 |
| Yellow | Lydian | 0 – 0 – 1 – 4 |
| Green | Dorian | 0 – 3 – 0 – 6 |
| Blue | Aeolian | 0 – 0 – 5 – 2 |
| Purple | Phrygian | 0 – 1 – 0 – 6 |
| White | Major Pentatonic | 0 – 3 – 0 – 4 |
| Black | Locrian | 0 – 1 – 0 – 6 |

Scale degrees are zero-indexed, with `0` representing the first degree of the active musical mode.

The dominant scene color must remain stable for 2 seconds and account for at least 50% of the detected color information. Chord progressions advance every 5 seconds.

### 5. Sound Synthesis

The Csound synthesis engine contains five continuously running instruments:

- **Harmonic Pad:** Creates evolving harmonic textures using layered oscillators, filtering, and modulation.
- **Reverse FX:** Generates rhythmic melodic patterns and filtered noise textures.
- **Bass Drone:** Provides low-frequency harmonic support through sustained bass tones.
- **FM Texture Lead:** Creates evolving melodic textures using frequency modulation.
- **Harmonic Bell:** Produces rhythmic, bell-like tones with harmonic overtones.

Each instrument responds independently to a tracked object, while slow modulation keeps the soundscape evolving even when the camera view remains unchanged.

## Installation

1. Install the required software listed above.
2. Download the Vision-to-Music project folder.
3. Keep `vision_to_music.py` and `vision_to_music.csd` in the project directory.
4. Connect a webcam or enable a compatible camera input.

**Note:** The Python script uses the AVFoundation camera backend on macOS. Other operating systems may require a different OpenCV camera configuration.

## How to Use

### 1. Launching Vision-to-Music

1. Open `vision_to_music.csd` in CsoundQt.
2. Click **Run** to start the Csound performance.
3. Open a terminal in the project directory and run:

   ```bash
   python vision_to_music.py
   ```

4. The camera window will open and begin detecting colored regions.

### 2. Interacting with the Soundscape

Move the camera or place colored objects in front of it. Experiment with their positions, apparent sizes, and colors to explore different musical textures and harmonies.

### 3. Stopping Vision-to-Music

1. Select the OpenCV camera window and press `Q` to stop the Python program.
2. Click **Stop** in CsoundQt to end audio synthesis.