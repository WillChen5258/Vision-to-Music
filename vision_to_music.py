"""
Vision-to-Music System

This program captures video from a webcam, detects prominent colored
regions, and sends their position, relative size, and dominant color to
Csound through Open Sound Control (OSC).

The dominant scene color selects a musical mode when it covers at least
50% of the detected color area and remains stable for 2 seconds.
Tracked objects keep their IDs across frames. When an object disappears,
a /gone message releases its Csound voice.

Before running this script:
1. Start vision_to_music.csd in Csound.
2. Run this script:
       python vision_to_music.py

OSC message formats:
    /object [object_id, x, y, size, color_id]
    /mode [color_id]
    /gone [object_id]

Color-to-mode mapping:
    Red    -> Mixolydian
    Orange -> Ionian
    Yellow -> Lydian
    Green  -> Dorian
    Blue   -> Aeolian
    Purple -> Phrygian
    White  -> Major Pentatonic
    Black  -> Locrian

Press Q to close the camera window.
"""

import cv2
import numpy as np
import time
from pythonosc.udp_client import SimpleUDPClient

# Open the default webcam using Apple's AVFoundation camera backend.
cap = cv2.VideoCapture(0, cv2.CAP_AVFOUNDATION)
# Create an OSC client that sends messages to Csound on port 7770.
client = SimpleUDPClient("127.0.0.1", 7770)

# Limit the system to the five largest detected objects.
max_objects = 5
# Require one color to cover at least 50% of the detected object area before it can change the mode.
minimum_dominant_percentage = 50.0
# Require the dominant color to remain stable for 2 seconds before changing the mode.
required_stable_time = 2.0

# Keep object IDs consistent across frames using nearest-centroid tracking.
# Maximum distance in pixels for matching an object between frames.
max_track_distance = 120.0

# Release an object after 0.5 seconds without a match.
track_timeout = 0.5

# Active tracks: track_id -> {"cx", "cy", "last_seen"}
tracks = {}

# Map each detected color to its corresponding musical mode.
color_modes = {
    "Red": "Mixolydian",
    "Orange": "Ionian",
    "Yellow": "Lydian",
    "Green": "Dorian",
    "Blue": "Aeolian",
    "Purple": "Phrygian",
    "White": "Major Pentatonic",
    "Black": "Locrian"
}

# Store the color currently being tested for stability.
candidate_color = None
# Store when the current candidate color first became dominant.
candidate_start_time = None
# Store the color that is currently controlling the Csound mode.
active_color = None
# Store the readable name of the currently active musical mode.
active_mode = "---"

# Assign each color a numerical ID that can be sent to Csound through OSC.
color_ids = {
    "Red": 0,
    "Orange": 1,
    "Yellow": 2,
    "Green": 3,
    "Blue": 4,
    "Purple": 5,
    "White": 6,
    "Black": 7
}


# Create separate masks for red, orange, yellow, green, blue, purple, white, and black.
def create_color_masks(hsv_image):
    hue = hsv_image[:, :, 0]
    saturation = hsv_image[:, :, 1]
    value = hsv_image[:, :, 2]

    chromatic = (saturation >= 45) & (value >= 45)

    masks = {
        "Red": (
            chromatic &
            ((hue <= 7) | (hue >= 173))
        ),
        "Orange": (
            chromatic &
            (hue >= 8) &
            (hue <= 19)
        ),
        "Yellow": (
            chromatic &
            (hue >= 20) &
            (hue <= 34)
        ),
        "Green": (
            chromatic &
            (hue >= 35) &
            (hue <= 84)
        ),
        "Blue": (
            chromatic &
            (hue >= 85) &
            (hue <= 139)
        ),
        "Purple": (
            chromatic &
            (hue >= 140) &
            (hue <= 172)
        ),
        "White": (
            (saturation < 35) &
            (value >= 180)
        ),
        "Black": (
            value <= 50
        )
    }

    return {
        name: mask.astype(np.uint8) * 255
        for name, mask in masks.items()
    }


# Determine the dominant color inside one detected object's contour.
def classify_object_color(color_masks, contour, image_shape):
    contour_mask = np.zeros(image_shape[:2], dtype=np.uint8)
    cv2.drawContours(contour_mask, [contour], -1, 255, -1)

    color_pixel_counts = {}

    for color_name, color_mask in color_masks.items():
        intersection = cv2.bitwise_and(color_mask, contour_mask)
        color_pixel_counts[color_name] = cv2.countNonZero(intersection)

    dominant_color = max(
        color_pixel_counts,
        key=color_pixel_counts.get
    )

    dominant_pixels = color_pixel_counts[dominant_color]
    total_classified_pixels = sum(color_pixel_counts.values())

    if total_classified_pixels > 0:
        confidence = dominant_pixels / total_classified_pixels
    else:
        confidence = 0.0

    return (
        color_ids[dominant_color],
        dominant_color,
        dominant_pixels,
        confidence
    )


# Match detected objects to existing tracks using their center positions.
def match_detections_to_tracks(tracks, detections, max_distance, max_tracks):
    candidate_pairs = []

    for track_id, track in tracks.items():
        for detection_index, detection in enumerate(detections):
            dx = detection["cx"] - track["cx"]
            dy = detection["cy"] - track["cy"]
            distance_px = (dx * dx + dy * dy) ** 0.5

            if distance_px <= max_distance:
                candidate_pairs.append((distance_px, track_id, detection_index))

    # Match the closest objects first.
    candidate_pairs.sort(key=lambda item: item[0])

    matched_track_ids = set()
    detection_track_id = {}

    for distance_px, track_id, detection_index in candidate_pairs:
        if track_id in matched_track_ids:
            continue

        if detection_index in detection_track_id:
            continue

        matched_track_ids.add(track_id)
        detection_track_id[detection_index] = track_id

    # Assign available IDs to new objects.
    free_track_ids = [
        candidate_id
        for candidate_id in range(max_tracks)
        if candidate_id not in tracks
    ]

    for detection_index in range(len(detections)):
        if detection_index in detection_track_id:
            continue

        if not free_track_ids:
            # Skip objects when all five slots are occupied.
            continue

        detection_track_id[detection_index] = free_track_ids.pop(0)

    return detection_track_id


# Continuously capture and process webcam frames.
while True:
    # Read one frame from the webcam.
    ret, frame = cap.read()

    if not ret:
        break

    current_time = time.monotonic()

    # Mirror the image so movement feels natural to the user.
    frame = cv2.flip(frame, 1)
    # Convert the camera image from BGR to HSV for easier color analysis.
    hsv = cv2.cvtColor(frame, cv2.COLOR_BGR2HSV)

    # Build the eight color masks used for object color classification.
    color_masks = create_color_masks(hsv)

    object_mask = np.zeros(hsv.shape[:2], dtype=np.uint8)

    for color_mask in color_masks.values():
        object_mask = cv2.bitwise_or(object_mask, color_mask)

    kernel = np.ones((5, 5), np.uint8)

    object_mask = cv2.morphologyEx(
        object_mask,
        cv2.MORPH_OPEN,
        kernel
    )

    object_mask = cv2.morphologyEx(
        object_mask,
        cv2.MORPH_CLOSE,
        kernel
    )

    object_mask = cv2.dilate(
        object_mask,
        kernel,
        iterations=1
    )

    contours, _ = cv2.findContours(
        object_mask,
        cv2.RETR_EXTERNAL,
        cv2.CHAIN_APPROX_SIMPLE
    )

    # Store the detected objects that are large enough to use.
    valid_objects = []

    frame_area = frame.shape[0] * frame.shape[1]

    for contour in contours:
        area = cv2.contourArea(contour)

        if area < 1500:
            continue

        if area > frame_area * 0.85:
            continue

        x, y, w, h = cv2.boundingRect(contour)

        if w < 30 or h < 30:
            continue

        valid_objects.append((area, contour))

    valid_objects = sorted(
        valid_objects,
        key=lambda item: item[0],
        reverse=True
    )

    valid_objects = valid_objects[:max_objects]

    # Extract positions, sizes, and colors from the detected objects.
    detections = []
    color_areas = {
        "Red": 0.0,
        "Orange": 0.0,
        "Yellow": 0.0,
        "Green": 0.0,
        "Blue": 0.0,
        "Purple": 0.0,
        "White": 0.0,
        "Black": 0.0
    }

    for area, contour in valid_objects:
        x, y, w, h = cv2.boundingRect(contour)

        cx = x + w // 2
        cy = y + h // 2

        (
            color_id,
            color_name,
            dominant_pixels,
            color_confidence
        ) = classify_object_color(
            color_masks,
            contour,
            frame.shape
        )

        color_areas[color_name] += dominant_pixels

        detections.append(
            {
                "area": area,
                "contour": contour,
                "x": x,
                "y": y,
                "w": w,
                "h": h,
                "cx": cx,
                "cy": cy,
                "x_norm": cx / frame.shape[1],
                "y_norm": cy / frame.shape[0],
                "size": min(area / 50000.0, 1.0),
                "color_id": color_id,
                "color_name": color_name,
                "color_pixels": dominant_pixels,
                "color_confidence": color_confidence
            }
        )

    # Match detected objects to their tracked IDs.
    detection_track_id = match_detections_to_tracks(
        tracks,
        detections,
        max_track_distance,
        max_objects
    )

    # Tell Csound when a tracked object disappears.
    matched_track_ids = set(detection_track_id.values())

    for track_id in list(tracks.keys()):
        if track_id in matched_track_ids:
            continue

        if current_time - tracks[track_id]["last_seen"] >= track_timeout:
            client.send_message("/gone", float(track_id))
            print(f"/gone {track_id}")
            del tracks[track_id]

    # Update tracked objects for OSC messages and camera display.
    detected_objects = []

    for detection_index, detection in enumerate(detections):
        if detection_index not in detection_track_id:
            continue

        track_id = detection_track_id[detection_index]

        tracks[track_id] = {
            "cx": detection["cx"],
            "cy": detection["cy"],
            "last_seen": current_time
        }

        detected_objects.append(
            {
                "object_id": track_id,
                "area": detection["area"],
                "x": detection["x"],
                "y": detection["y"],
                "w": detection["w"],
                "h": detection["h"],
                "cx": detection["cx"],
                "cy": detection["cy"],
                "x_norm": detection["x_norm"],
                "y_norm": detection["y_norm"],
                "size": detection["size"],
                "color_id": detection["color_id"],
                "color_name": detection["color_name"],
                "color_pixels": detection["color_pixels"],
                "color_confidence": detection["color_confidence"]
            }
        )

    total_color_area = sum(color_areas.values())

    if total_color_area > 0:
        dominant_color = max(
            color_areas,
            key=color_areas.get
        )

        dominant_area = color_areas[dominant_color]

        dominant_percentage = (
            dominant_area /
            total_color_area *
            100.0
        )
    else:
        dominant_color = "None"
        dominant_area = 0.0
        dominant_percentage = 0.0

    # Check whether the dominant color is strong enough to become a mode-change candidate.
    valid_candidate = (
        dominant_color != "None" and
        dominant_percentage >= minimum_dominant_percentage
    )

    if valid_candidate:
        # Restart the timer whenever a different dominant color becomes the candidate.
        if dominant_color != candidate_color:
            candidate_color = dominant_color
            candidate_start_time = current_time

        stable_elapsed = current_time - candidate_start_time

        # Change mode only after the candidate color has remained stable long enough.
        if stable_elapsed >= required_stable_time:
            # Avoid sending the same mode repeatedly when it is already active.
            if candidate_color != active_color:
                active_color = candidate_color
                active_mode = color_modes[active_color]

                client.send_message(
                    # Send the confirmed color ID to Csound so it can change musical mode.
                    "/mode",
                    color_ids[active_color]
                )

                print(
                    f'/mode {color_ids[active_color]} '
                    f'color={active_color} '
                    f'mode={active_mode}'
                )
    else:
        candidate_color = None
        candidate_start_time = None
        stable_elapsed = 0.0

    for obj in detected_objects:
        client.send_message(
            # Send each detected object's visual parameters to Csound.
            "/object",
            [
                float(obj["object_id"]),
                float(obj["x_norm"]),
                float(obj["y_norm"]),
                float(obj["size"]),
                float(obj["color_id"])
            ]
        )

        print(
            f'/object {obj["object_id"]} '
            f'x={obj["x_norm"]:.2f} '
            f'y={obj["y_norm"]:.2f} '
            f'size={obj["size"]:.2f} '
            f'color={obj["color_name"]} '
            f'confidence={obj["color_confidence"]:.2f} '
            f'area={obj["area"]:.0f}'
        )

        cv2.rectangle(
            frame,
            (obj["x"], obj["y"]),
            (
                obj["x"] + obj["w"],
                obj["y"] + obj["h"]
            ),
            (0, 255, 0),
            2
        )

        cv2.circle(
            frame,
            (obj["cx"], obj["cy"]),
            10,
            (0, 255, 0),
            -1
        )

        cv2.putText(
            frame,
            (
                f'ID:{obj["object_id"]} '
                f'{obj["color_name"]} '
                f'X:{obj["x_norm"]:.2f} '
                f'Y:{obj["y_norm"]:.2f} '
                f'S:{obj["size"]:.2f}'
            ),
            (
                obj["x"],
                max(30, obj["y"] - 10)
            ),
            cv2.FONT_HERSHEY_SIMPLEX,
            0.55,
            (0, 255, 0),
            2,
            cv2.LINE_AA
        )

    if valid_candidate:
        displayed_stable_time = min(
            stable_elapsed,
            required_stable_time
        )

        stable_text = (
            f"{displayed_stable_time:.1f} / "
            f"{required_stable_time:.1f} s"
        )
    else:
        stable_text = (
            f"0.0 / "
            f"{required_stable_time:.1f} s"
        )

    hud_lines = [
        f"Dominant: {dominant_color}",
        f"Object Area: {dominant_percentage:.1f}%",
        f"Mode: {active_mode}",
        f"Stable: {stable_text}",
        f"Active tracks: {len(tracks)}"
    ]

    font = cv2.FONT_HERSHEY_SIMPLEX
    font_scale = 0.6
    font_thickness = 2
    padding = 12
    line_height = 28

    text_widths = [
        cv2.getTextSize(
            line,
            font,
            font_scale,
            font_thickness
        )[0][0]
        for line in hud_lines
    ]

    hud_width = max(text_widths) + padding * 2
    hud_height = (
        line_height * len(hud_lines) +
        padding * 2
    )

    hud_x2 = frame.shape[1] - 15
    hud_y1 = 15
    hud_x1 = hud_x2 - hud_width
    hud_y2 = hud_y1 + hud_height

    overlay = frame.copy()

    cv2.rectangle(
        overlay,
        (hud_x1, hud_y1),
        (hud_x2, hud_y2),
        (0, 0, 0),
        -1
    )

    cv2.addWeighted(
        overlay,
        0.65,
        frame,
        0.35,
        0,
        frame
    )

    cv2.rectangle(
        frame,
        (hud_x1, hud_y1),
        (hud_x2, hud_y2),
        (255, 255, 255),
        1
    )

    for index, line in enumerate(hud_lines):
        text_x = hud_x1 + padding

        text_y = (
            hud_y1 +
            padding +
            20 +
            index * line_height
        )

        cv2.putText(
            frame,
            line,
            (text_x, text_y),
            font,
            font_scale,
            (255, 255, 255),
            font_thickness,
            cv2.LINE_AA
        )

    print(
        f"Dominant color: {dominant_color} "
        f"percentage={dominant_percentage:.1f}%"
    )

    cv2.imshow(
        "Vision to Csound OSC",
        frame
    )

    if cv2.waitKey(50) & 0xFF == ord("q"):
        break

# Release the camera when the program ends.
cap.release()
# Close all OpenCV windows.
cv2.destroyAllWindows()
