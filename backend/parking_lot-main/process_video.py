import json
import os
import datetime
from collections import Counter
from typing import Any, Dict, List

import cv2
import numpy as np
from ultralytics import YOLO
import cvzone


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


def _scale_polygons_to_frame(polygons: List, frame_w: int, frame_h: int) -> List:
    if not polygons:
        return polygons

    all_x = [p[0] for poly in polygons for p in poly]
    all_y = [p[1] for poly in polygons for p in poly]

    max_x = max(all_x)
    max_y = max(all_y)

    # Normalize [0–1] → scale to frame
    if max_x <= 1.0 and max_y <= 1.0:
        return [
            [[int(p[0] * frame_w), int(p[1] * frame_h)] for p in poly]
            for poly in polygons
        ]

    # Already correct scale
    if max_x >= frame_w and max_y >= frame_h:
        return [[[int(p[0]), int(p[1])] for p in poly] for poly in polygons]

    sx = frame_w / max_x if max_x > 0 else 1.0
    sy = frame_h / max_y if max_y > 0 else 1.0

    return [
        [[int(p[0] * sx), int(p[1] * sy)] for p in poly]
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

    raw_polygons = _load_polygons(polygons_path)
    polygons = _scale_polygons_to_frame(raw_polygons, frame_w, frame_h)

    # ── Video Writer ──
    fourcc = cv2.VideoWriter_fourcc(*'mp4v')
    out = cv2.VideoWriter(output_path, fourcc, 20.0, (frame_w, frame_h))

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
        "output_path": output_path  # 🔥 IMPORTANT (used for Cloudinary upload)
    }