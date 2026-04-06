import json
import os
import datetime
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
        return data if isinstance(data, list) else []
    except Exception as e:
        print("❌ Polygon load error:", e)
        return []


# ── MAIN FUNCTION ─────────────────────────────────────────────

def process_video(session_id: str, model=None) -> Dict[str, Any]:
    from django.conf import settings

    session_dir = os.path.join(settings.MEDIA_ROOT, 'parking_uploads', session_id)

    print("📂 Session dir:", session_dir)

    if not os.path.exists(session_dir):
        return {"success": False, "error": "Session folder not found"}

    files = os.listdir(session_dir)
    print("📂 Files:", files)

    # ✅ Detect video file
    video_file = None
    for f in files:
        if f.lower().endswith(('.mp4', '.avi', '.mov')):
            video_file = f
            break

    if not video_file:
        return {"success": False, "error": "No video file found"}

    input_path = os.path.join(session_dir, video_file)
    polygons_path = os.path.join(session_dir, 'polygons.json')

    if not os.path.exists(polygons_path):
        return {"success": False, "error": "Polygons not found"}

    timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
    output_filename = f"output_{session_id}_{timestamp}.avi"  # Use .avi for XVID
    output_path = os.path.join(session_dir, output_filename)

    print("🎥 Input:", input_path)
    print("📐 Polygons:", polygons_path)
    print("📤 Output:", output_path)

    # ── Load YOLO ─────────────────────────
    if model is None:
        model_path = os.path.join(settings.BASE_DIR, 'parking_lot-main', 'best.pt')
        if not os.path.exists(model_path):
            return {"success": False, "error": f"Model file not found at {model_path}"}
        model = YOLO(model_path)

    cap = cv2.VideoCapture(input_path)
    if not cap.isOpened():
        return {"success": False, "error": "Cannot open video"}

    frame_w, frame_h = 1020, 500
    polygons = _load_polygons(polygons_path)

    fourcc = cv2.VideoWriter_fourcc(*'XVID')  # XVID codec for better compatibility
    out = cv2.VideoWriter(output_path, fourcc, 20.0, (frame_w, frame_h))

    if not out.isOpened():
        # Fallback to MJPG if XVID fails
        output_path = output_path.replace('.avi', '.avi')  # Keep .avi
        fourcc = cv2.VideoWriter_fourcc(*'MJPG')
        out = cv2.VideoWriter(output_path, fourcc, 20.0, (frame_w, frame_h))

    if not out.isOpened():
        # Final fallback to mp4v with .mp4 extension
        output_path = output_path.replace('.avi', '.mp4')
        output_filename = output_filename.replace('.avi', '.mp4')
        fourcc = cv2.VideoWriter_fourcc(*'mp4v')
        out = cv2.VideoWriter(output_path, fourcc, 20.0, (frame_w, frame_h))

    if not out.isOpened():
        cap.release()
        return {"success": False, "error": "VideoWriter failed"}

    frame_count = 0
    results = None

    while True:
        ret, frame = cap.read()
        if not ret:
            break

        frame_count += 1
        frame = cv2.resize(frame, (frame_w, frame_h))

        # Run YOLO every 3rd frame
        if frame_count % 3 == 0:
            results = model.track(frame, persist=True)

        # Draw polygons
        for poly in polygons:
            pts = np.array(poly, np.int32).reshape((-1, 1, 2))
            cv2.polylines(frame, [pts], True, (0, 255, 0), 2)

        occupied_zones = 0

        # Detection logic
        if results is not None and results[0].boxes is not None:
            boxes = results[0].boxes.xyxy.cpu().numpy().astype(int)

            for box in boxes:
                x1, y1, x2, y2 = box
                cx = int((x1 + x2) / 2)
                cy = int((y1 + y2) / 2)

                for poly in polygons:
                    pts = np.array(poly, np.int32).reshape((-1, 1, 2))

                    if cv2.pointPolygonTest(pts, (cx, cy), False) >= 0:
                        cv2.circle(frame, (cx, cy), 4, (255, 0, 255), -1)
                        cv2.polylines(frame, [pts], True, (0, 0, 255), 2)
                        occupied_zones += 1
                        break

        total_zones = len(polygons)
        free_zones = total_zones - occupied_zones

        cvzone.putTextRect(frame, f'FREE: {free_zones}', (30, 40), 2, 2)
        cvzone.putTextRect(frame, f'OCC: {occupied_zones}', (30, 120), 2, 2)

        # ✅ SAVE FRAME
        out.write(frame)

    # ── CLEANUP ─────────────────────────
    cap.release()
    out.release()

    # Verify output file was created
    if not os.path.exists(output_path):
        return {"success": False, "error": "Output video file was not created"}

    file_size = os.path.getsize(output_path)
    if file_size == 0:
        return {"success": False, "error": "Output video file is empty"}

    total_zones = len(polygons)
    output_url = f"{settings.MEDIA_URL}parking_uploads/{session_id}/{output_filename}"

    print(f"✅ Video processing complete: {output_path} ({file_size} bytes)")
    print(f"🌐 Output URL: {output_url}")

    return {
        "success": True,
        "occupied": occupied_zones,  # Use final frame count like main.py
        "free": free_zones,
        "total": total_zones,
        "output_path": output_path,
        "output_url": output_url,
    }
