import json
import os
import datetime
import subprocess
from collections import Counter
from typing import Any, Dict, List

import cv2
import numpy as np
from ultralytics import YOLO
import cvzone
import imageio_ffmpeg


# ── Polygon helpers ─────────────────────────────────────────────

def _load_polygons(polygons_path: str) -> List:
    if not os.path.exists(polygons_path):
        return []
    try:
        with open(polygons_path, 'r', encoding='utf-8') as f:
            data = json.load(f)
        return data.get("polygons", []) if isinstance(data, dict) else data
    except Exception as e:
        print("❌ Polygon load error:", e)
        return []


def _scale_polygons_to_frame(polygons: List, frame_w: int, frame_h: int, display_w: float = 0, display_h: float = 0) -> List:
    if not polygons:
        return polygons

    all_x = [p[0] for poly in polygons for p in poly]
    all_y = [p[1] for poly in polygons for p in poly]
    max_x = max(all_x)
    max_y = max(all_y)

    # Already normalized [0–1]
    if max_x <= 1.0 and max_y <= 1.0:
        return [
            [[int(p[0] * frame_w), int(p[1] * frame_h)] for p in poly]
            for poly in polygons
        ]

    # Display-pixel coords — scale via display dimensions if provided
    if display_w > 0 and display_h > 0:
        return [
            [[int(p[0] / display_w * frame_w), int(p[1] / display_h * frame_h)] for p in poly]
            for poly in polygons
        ]

    # Fallback: treat max coord as display size
    return [
        [[int(p[0] / max_x * frame_w), int(p[1] / max_y * frame_h)] for p in poly]
        for poly in polygons
    ]


# ── MAIN FUNCTION ─────────────────────────────────────────────

def process_video(session_id: str, input_path: str, polygons_path: str, output_dir: str, model=None) -> Dict[str, Any]:

    print("\n🚀 PROCESS VIDEO START")
    print("📌 Session:", session_id)
    print("🎥 Input:", input_path)
    print("📐 Polygons:", polygons_path)

    # ❌ Validate input
    if not os.path.exists(input_path):
        return {"success": False, "error": "Input video not found"}

    if not os.path.exists(polygons_path):
        return {"success": False, "error": "Polygons file not found"}

    # ✅ Output path (TEMP directory)
    timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
    output_filename = f"output_{session_id}_{timestamp}.mp4"
    output_path = os.path.join(output_dir, output_filename)

    print("📤 Output:", output_path)

    # ── Load YOLO ──
    if model is None:
        model_path = os.path.join(os.path.dirname(__file__), 'best.pt')
        model = YOLO(model_path)

    cap = cv2.VideoCapture(input_path)

    if not cap.isOpened():
        return {"success": False, "error": "Cannot open video"}

    frame_w = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
    frame_h = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))

    if frame_w == 0 or frame_h == 0:
        return {"success": False, "error": "Invalid video dimensions"}

    raw_polygons = []
    display_w = 0.0
    display_h = 0.0
    try:
        with open(polygons_path, 'r', encoding='utf-8') as f:
            poly_data = json.load(f)
        display_w = float(poly_data.get('display_width', 0))
        display_h = float(poly_data.get('display_height', 0))
        raw_polygons = poly_data.get('polygons', []) if isinstance(poly_data, dict) else poly_data
    except Exception as e:
        return {"success": False, "error": f"Failed to load polygons: {e}"}

    polygons = _scale_polygons_to_frame(raw_polygons, frame_w, frame_h, display_w, display_h)

    # ── Video Writer ── write temp AVI with XVID, re-encode to H.264 MP4 after
    temp_path = output_path.replace('.mp4', '_tmp.avi')
    fourcc = cv2.VideoWriter_fourcc(*'XVID')
    out = cv2.VideoWriter(temp_path, fourcc, 20.0, (frame_w, frame_h))

    if not out.isOpened():
        return {"success": False, "error": "VideoWriter failed"}

    frame_count = 0
    results = None
    occupied_counts = []

    # ── PROCESS LOOP ──
    while True:
        ret, frame = cap.read()
        if not ret:
            break

        frame_count += 1

        # YOLO every 3 frames
        if frame_count % 3 == 0:
            results = model.track(frame, persist=True)

        occupied_zones = 0

        # Draw polygons
        for poly in polygons:
            pts = np.array(poly, np.int32).reshape((-1, 1, 2))
            cv2.polylines(frame, [pts], True, (0, 255, 0), 2)

        # Detection
        if results is not None and results[0].boxes is not None:
            boxes = results[0].boxes.xyxy.cpu().numpy().astype(int)

            for box in boxes:
                x1, y1, x2, y2 = box
                cx, cy = int((x1 + x2) / 2), int((y1 + y2) / 2)

                for poly in polygons:
                    pts = np.array(poly, np.int32).reshape((-1, 1, 2))

                    if cv2.pointPolygonTest(pts, (cx, cy), False) >= 0:
                        cv2.circle(frame, (cx, cy), 4, (255, 0, 255), -1)
                        cv2.polylines(frame, [pts], True, (0, 0, 255), 2)
                        occupied_zones += 1
                        break

        occupied_counts.append(occupied_zones)

        total_zones = len(polygons)
        free_zones = total_zones - occupied_zones

        cvzone.putTextRect(frame, f'FREE:{free_zones}', (30, 40), 2, 2)
        cvzone.putTextRect(frame, f'OCC:{occupied_zones}', (30, 140), 2, 2)

        out.write(frame)

    # ── CLEANUP ──
    cap.release()
    out.release()

    if not os.path.exists(temp_path) or os.path.getsize(temp_path) == 0:
        return {"success": False, "error": "Temp video file was not created"}

    # Re-encode to H.264 MP4 for browser compatibility
    try:
        ffmpeg_exe = imageio_ffmpeg.get_ffmpeg_exe()
        subprocess.run(
            [ffmpeg_exe, '-y', '-i', temp_path,
             '-vcodec', 'libx264', '-pix_fmt', 'yuv420p',
             '-movflags', '+faststart', output_path],
            check=True, capture_output=True
        )
    except Exception as e:
        return {"success": False, "error": f"ffmpeg re-encode failed: {e}"}
    finally:
        if os.path.exists(temp_path):
            os.remove(temp_path)

    total_zones = len(polygons)

    final_occupied = (
        Counter(occupied_counts).most_common(1)[0][0]
        if occupied_counts else 0
    )

    final_free = total_zones - final_occupied

    print("✅ PROCESS COMPLETE")

    return {
        "success": True,
        "occupied": final_occupied,
        "free": final_free,
        "total": total_zones,
        "fps": 20.0,
        "frame_data": occupied_counts,
        "output_path": output_path
    }