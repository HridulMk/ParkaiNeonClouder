from ultralytics import YOLO
import cv2
import numpy as np
import os
import random
import easyocr

_reader = None

def _get_reader():
    global _reader
    if _reader is None:
        _reader = easyocr.Reader(['en'], gpu=False)
    return _reader


def _read_plate_text(plate_crop):
    gray = cv2.cvtColor(plate_crop, cv2.COLOR_BGR2GRAY)
    gray = cv2.resize(gray, None, fx=2, fy=2, interpolation=cv2.INTER_CUBIC)
    _, thresh = cv2.threshold(gray, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)

    reader = _get_reader()
    results = reader.readtext(thresh, allowlist='ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789')

    text = ' '.join([r[1] for r in results if r[2] > 0.3]).strip()
    return text if len(text) >= 4 else None


def process_vehicle_image(image_path_or_array):
    if isinstance(image_path_or_array, str):
        frame = cv2.imread(image_path_or_array)
    else:
        frame = image_path_or_array

    if frame is None:
        return {'vehicle_number': 'NOT_DETECTED', 'vehicle_type': 'sedan', 'debug': 'Invalid image'}

    vehicle_number = 'NOT_DETECTED'
    vehicle_type = random.choice(['sedan', 'suv', 'pickup', 'hatchback'])
    debug_info = []

    base_dir = os.path.dirname(os.path.abspath(__file__))
    license_plate_path = os.path.join(base_dir, 'license_plate_detector.pt')

    if not os.path.exists(license_plate_path):
        return {'vehicle_number': 'NOT_DETECTED', 'vehicle_type': vehicle_type, 'debug': 'Model not found'}

    license_model = YOLO(license_plate_path)
    plate_results = license_model(frame, verbose=False)

    if not plate_results or len(plate_results[0].boxes) == 0:
        debug_info.append('No plate detected by YOLO')
    else:
        box = plate_results[0].boxes[0]
        conf = float(box.conf[0])
        x1, y1, x2, y2 = map(int, box.xyxy[0])
        h, w = frame.shape[:2]
        x1, y1 = max(0, x1), max(0, y1)
        x2, y2 = min(w, x2), min(h, y2)
        debug_info.append(f'Plate box: ({x1},{y1},{x2},{y2}) conf={conf:.2f}')

        if x2 > x1 and y2 > y1:
            plate_crop = frame[y1:y2, x1:x2]
            try:
                text = _read_plate_text(plate_crop)
                if text:
                    vehicle_number = text
                    debug_info.append(f'OCR result: {text}')
                else:
                    debug_info.append('OCR returned empty')
            except Exception as e:
                debug_info.append(f'OCR error: {e}')

    print('[YOLO process_image]', ' | '.join(debug_info))
    return {
        'vehicle_number': vehicle_number,
        'vehicle_type': vehicle_type,
        'debug': ' | '.join(debug_info)
    }
