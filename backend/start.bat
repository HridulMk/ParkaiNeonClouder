@echo off
echo Starting ParkingAI backend with Daphne (ASGI)...
cd /d "%~dp0"
daphne -b 0.0.0.0 -p 8000 parking_backend.asgi:application
