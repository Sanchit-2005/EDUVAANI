@echo off
echo Starting EduVaani Translation Services...
echo.

echo [1/2] Starting Python Translation Service (port 8000)...
start "Python Translation Service" cmd /k "cd /d D:\V2 s123\EDUVAANI\palash-ai\ml_pipeline\translation_service && python app.py"

echo [2/2] Starting Node.js Backend (port 3000, all interfaces)...
start "Node.js Backend" cmd /k "cd /d D:\V2 s123\EDUVAANI\palash-ai\backend && npm start"

echo.
echo Both services are starting in separate windows...
echo - Python Translation Service: http://127.0.0.1:8000
echo - Node.js Backend: http://127.0.0.1:3000
echo - Phone health endpoint: http://^<host-lan-ip^>:3000/health
echo.
echo Find the current host address with: ipconfig
echo Then run Flutter with:
echo flutter run --dart-define=BACKEND_BASE_URL=http://^<host-lan-ip^>:3000
echo.
echo Press any key to close this window (services will continue running)...
pause >nul
