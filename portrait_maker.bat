@echo off
cd /d "%~dp0"
echo Starting Portrait Maker...
start "" http://localhost:8000/tools/portrait_maker.html
python -m http.server 8000
pause
