# EduVaani Translation Services Startup Script
# Run this PowerShell script to start both backend services.

Write-Host "Starting EduVaani Translation Services..." -ForegroundColor Green
Write-Host ""

# Function to start a service in a new window
function Start-Service {
    param(
        [string]$Name,
        [string]$Path,
        [string]$Command
    )

    Write-Host "[$Name] Starting..." -ForegroundColor Yellow
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "cmd.exe"
    $psi.Arguments = "/k $Command"
    $psi.WorkingDirectory = $Path
    $psi.WindowStyle = "Normal"
    $psi.CreateNoWindow = $false
    $process = [System.Diagnostics.Process]::Start($psi)
    Start-Sleep -Seconds 2
    Write-Host "[$Name] Started successfully" -ForegroundColor Green
}

# Prefer the active Wi-Fi IPv4 address so the Flutter device configuration is
# not tied to a stale DHCP lease. BACKEND_LAN_IP can be supplied explicitly.
$lanIp = $env:BACKEND_LAN_IP
if ([string]::IsNullOrWhiteSpace($lanIp)) {
    $lanIp = (Get-NetIPAddress -AddressFamily IPv4 |
        Where-Object {
            $_.InterfaceAlias -match 'Wi-Fi|Wireless' -and
            $_.IPAddress -notlike '127.*' -and
            $_.IPAddress -notlike '169.254.*'
        } |
        Select-Object -First 1 -ExpandProperty IPAddress)
}
if ([string]::IsNullOrWhiteSpace($lanIp)) {
    $lanIp = '<host-lan-ip>'
}

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$pythonPath = Join-Path $projectRoot 'ml_pipeline\translation_service'
$backendPath = Join-Path $projectRoot 'backend'

# Start Python Translation Service
Start-Service -Name "Python Translation Service" -Path $pythonPath -Command "python app.py"

# Start Node.js Backend (server.js binds to 0.0.0.0)
Start-Service -Name "Node.js Backend" -Path $backendPath -Command "npm start"

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "All services are now running!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Services:" -ForegroundColor White
Write-Host "  - Python Translation Service: http://127.0.0.1:8000" -ForegroundColor Gray
Write-Host "  - Node.js Backend (local): http://127.0.0.1:3000" -ForegroundColor Gray
Write-Host "  - Node.js Backend (phone): http://${lanIp}:3000" -ForegroundColor Gray
Write-Host "  - Phone health check: http://${lanIp}:3000/health" -ForegroundColor Gray
Write-Host ""
Write-Host "Run Flutter for a physical phone with:" -ForegroundColor Yellow
Write-Host "  flutter run --dart-define=BACKEND_BASE_URL=http://${lanIp}:3000" -ForegroundColor Yellow
Write-Host ""
Write-Host "Note: Windows Firewall must allow inbound TCP port 3000 on the active network profile (currently Public on this host)." -ForegroundColor Yellow
Write-Host "Close the service windows to stop the services." -ForegroundColor Yellow
Write-Host ""
