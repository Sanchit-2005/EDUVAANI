@echo off
echo Stopping EduVaani Translation Services...
echo.

echo Stopping Python Translation Service...
taskkill /FI "WINDOWTITLE eq Python Translation Service*" /F >nul 2>&1
taskkill /IM python.exe /FI "WINDOWTITLE eq *translation_service*" /F >nul 2>&1

echo Stopping Node.js Backend...
taskkill /FI "WINDOWTITLE eq Node.js Backend*" /F >nul 2>&1
taskkill /IM node.exe /FI "WINDOWTITLE eq *backend*" /F >nul 2>&1

echo.
echo Services stopped.
pause
