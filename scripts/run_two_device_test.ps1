# Two-Device Nearby Connections Test Script
# 
# This script runs integration tests on two physical Android devices simultaneously,
# testing the nearby connections communication between an initiator and a joiner.
#
# PREREQUISITES:
#   1. Two physical Android devices connected via ADB
#   2. Both devices must have Bluetooth and WiFi enabled
#   3. Location permissions granted on both devices
#
# USAGE:
#   .\scripts\run_two_device_test.ps1
#
# Optional parameters:
#   .\scripts\run_two_device_test.ps1 -DeviceA "DEVICE_ID_1" -DeviceB "DEVICE_ID_2"

param(
    [string]$DeviceA = "",
    [string]$DeviceB = ""
)

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "         TWO-DEVICE NEARBY CONNECTIONS TEST                     " -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Get connected devices
Write-Host "[INFO] Checking connected devices..." -ForegroundColor Yellow
$adbDevices = adb devices 2>&1

$devices = @()
$adbDevices -split "`n" | ForEach-Object {
    if ($_ -match "^(\S+)\s+device$") {
        $devices += $matches[1]
    }
}

Write-Host "[INFO] Found $($devices.Count) device(s):" -ForegroundColor Yellow
$devices | ForEach-Object { Write-Host "       - $_" -ForegroundColor White }
Write-Host ""

if ($devices.Count -lt 2) {
    Write-Host "[ERROR] This test requires exactly 2 connected devices!" -ForegroundColor Red
    Write-Host ""
    Write-Host "To connect devices:" -ForegroundColor Yellow
    Write-Host "  1. Enable USB debugging on both devices"
    Write-Host "  2. Connect both devices via USB"
    Write-Host "  3. Run: adb devices"
    Write-Host ""
    Write-Host "For wireless ADB:" -ForegroundColor Yellow
    Write-Host "  1. Connect device via USB first"
    Write-Host "  2. Run: adb tcpip 5555"
    Write-Host "  3. Disconnect USB"
    Write-Host "  4. Run: adb connect <DEVICE_IP>:5555"
    Write-Host ""
    exit 1
}

# Assign devices
if ([string]::IsNullOrEmpty($DeviceA)) {
    $DeviceA = $devices[0]
}
if ([string]::IsNullOrEmpty($DeviceB)) {
    $DeviceB = $devices[1]
}

Write-Host "[INFO] Device assignments:" -ForegroundColor Yellow
Write-Host "       Device A (INITIATOR): $DeviceA" -ForegroundColor Green
Write-Host "       Device B (JOINER):    $DeviceB" -ForegroundColor Cyan
Write-Host ""

# Clear app data on both devices
Write-Host "[INFO] Clearing app data on both devices..." -ForegroundColor Yellow
$packageName = "com.example.beacon_project"

adb -s $DeviceA shell pm clear $packageName 2>&1 | Out-Null
adb -s $DeviceB shell pm clear $packageName 2>&1 | Out-Null
Write-Host "[OK] App data cleared" -ForegroundColor Green
Write-Host ""

# Grant permissions on both devices
Write-Host "[INFO] Granting permissions..." -ForegroundColor Yellow
$permissions = @(
    "android.permission.ACCESS_FINE_LOCATION",
    "android.permission.ACCESS_COARSE_LOCATION",
    "android.permission.BLUETOOTH_SCAN",
    "android.permission.BLUETOOTH_ADVERTISE",
    "android.permission.BLUETOOTH_CONNECT",
    "android.permission.NEARBY_WIFI_DEVICES"
)

foreach ($device in @($DeviceA, $DeviceB)) {
    foreach ($permission in $permissions) {
        $result = adb -s $device shell pm grant $packageName $permission 2>&1
        # Ignore errors for permissions that may not exist on older Android versions
    }
}
Write-Host "[OK] Permissions granted" -ForegroundColor Green
Write-Host ""

# Create log directories
$logDir = "test_logs\$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss')"
New-Item -ItemType Directory -Path $logDir -Force | Out-Null
Write-Host "[INFO] Logs will be saved to: $logDir" -ForegroundColor Yellow
Write-Host ""

# Function to run test on a device
function Start-DeviceTest {
    param(
        [string]$DeviceId,
        [string]$Role,
        [string]$LogFile
    )
    
    $command = "flutter test integration_test/two_device_test.dart -d $DeviceId --dart-define=TEST_ROLE=$Role"
    
    # Start as background job
    $scriptBlock = {
        param($cmd, $log)
        Invoke-Expression $cmd 2>&1 | Tee-Object -FilePath $log
    }
    
    Start-Job -ScriptBlock $scriptBlock -ArgumentList $command, $LogFile -Name "$Role-test"
}

Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "                    STARTING TESTS                              " -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Host "[INFO] Starting INITIATOR test on $DeviceA..." -ForegroundColor Green
Write-Host "[INFO] Starting JOINER test on $DeviceB..." -ForegroundColor Cyan
Write-Host ""
Write-Host "Press Ctrl+C to stop the tests" -ForegroundColor Yellow
Write-Host ""

# Start initiator test first
$initiatorLog = Join-Path $logDir "initiator.log"
$initiatorJob = Start-DeviceTest -DeviceId $DeviceA -Role "initiator" -LogFile $initiatorLog

# Wait a few seconds for initiator to start advertising
Start-Sleep -Seconds 5

# Start joiner test
$joinerLog = Join-Path $logDir "joiner.log"
$joinerJob = Start-DeviceTest -DeviceId $DeviceB -Role "joiner" -LogFile $joinerLog

# Monitor both jobs
Write-Host "[INFO] Tests running. Waiting for completion..." -ForegroundColor Yellow
Write-Host ""

# Function to print job output in real-time
function Show-JobOutput {
    param([string]$JobName, [string]$Color)
    
    $job = Get-Job -Name $JobName -ErrorAction SilentlyContinue
    if ($job) {
        $output = Receive-Job -Job $job -Keep 2>&1
        if ($output) {
            $output -split "`n" | ForEach-Object {
                if ($_ -match "\[INITIATOR\]") {
                    Write-Host $_ -ForegroundColor Green
                } elseif ($_ -match "\[JOINER\]") {
                    Write-Host $_ -ForegroundColor Cyan
                } elseif ($_ -match "✓") {
                    Write-Host $_ -ForegroundColor Green
                } elseif ($_ -match "✗") {
                    Write-Host $_ -ForegroundColor Red
                } else {
                    Write-Host $_ -ForegroundColor White
                }
            }
        }
    }
}

# Wait for both jobs to complete
while ((Get-Job -Name "initiator-test" -ErrorAction SilentlyContinue).State -eq "Running" -or 
       (Get-Job -Name "joiner-test" -ErrorAction SilentlyContinue).State -eq "Running") {
    
    Show-JobOutput -JobName "initiator-test" -Color "Green"
    Show-JobOutput -JobName "joiner-test" -Color "Cyan"
    
    Start-Sleep -Seconds 2
}

# Get final output
Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "                    TEST RESULTS                                " -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

$initiatorResult = Get-Job -Name "initiator-test" | Wait-Job | Receive-Job
$joinerResult = Get-Job -Name "joiner-test" | Wait-Job | Receive-Job

Write-Host "INITIATOR LOG:" -ForegroundColor Green
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Green
Write-Host $initiatorResult
Write-Host ""

Write-Host "JOINER LOG:" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host $joinerResult
Write-Host ""

# Check for success
$initiatorSuccess = $initiatorResult -match "TEST COMPLETE"
$joinerSuccess = $joinerResult -match "TEST COMPLETE"

Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "                    SUMMARY                                     " -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

if ($initiatorSuccess -and $joinerSuccess) {
    Write-Host "✓ BOTH TESTS PASSED!" -ForegroundColor Green
} else {
    if (!$initiatorSuccess) {
        Write-Host "✗ INITIATOR test failed or incomplete" -ForegroundColor Red
    }
    if (!$joinerSuccess) {
        Write-Host "✗ JOINER test failed or incomplete" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "Logs saved to:" -ForegroundColor Yellow
Write-Host "  Initiator: $initiatorLog" -ForegroundColor White
Write-Host "  Joiner:    $joinerLog" -ForegroundColor White
Write-Host ""

# Cleanup jobs
Get-Job | Remove-Job -Force
