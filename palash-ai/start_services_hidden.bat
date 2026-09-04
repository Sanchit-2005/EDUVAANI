@echo off
echo Starting EduVaani Translation Services in background...
echo.

echo [1/2] Starting Python Translation Service (port 8000)...
start /MIN "Python Translation Service" cmd /c "cd /d D:\V2 s123\EDUVAANI\palash-ai\ml_pipeline\translation_service && python app.py"

echo [2/2] Starting Node.js Backend (port 3000, all interfaces)...
start /MIN "Node.js Backend" cmd /c "cd /d D:\V2 s123\EDUVAANI\palash-ai\backend && npm start"

echo.
echo Both services are starting in background...
echo Check Task Manager if you need to stop the services.
echo Check the current host LAN IP with: ipconfig
echo Phone health endpoint: http://^<host-lan-ip^>:3000/health
echo.
echo You can now run the Flutter app with the current LAN IP.
pause
