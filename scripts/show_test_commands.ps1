# Quick Two-Device Test (Manual Version)
# 
# Run this script when you want to manually start each device test
# in separate terminal windows for easier debugging.
#
# USAGE: Open TWO PowerShell terminals and run:
#   Terminal 1: .\scripts\run_initiator.ps1
#   Terminal 2: .\scripts\run_joiner.ps1

param(
    [switch]$ListDevices
)

# Get connected devices
$adbDevices = adb devices 2>&1
$devices = @()
$adbDevices -split "`n" | ForEach-Object {
    if ($_ -match "^(\S+)\s+device$") {
        $devices += $matches[1]
    }
}

Write-Host ""
Write-Host "Connected devices:" -ForegroundColor Cyan
for ($i = 0; $i -lt $devices.Count; $i++) {
    Write-Host "  [$i] $($devices[$i])" -ForegroundColor White
}
Write-Host ""

if ($devices.Count -lt 2) {
    Write-Host "[!] Need 2 devices for two-device test" -ForegroundColor Yellow
    Write-Host ""
    exit 0
}

Write-Host "To run the two-device test, open TWO terminals:" -ForegroundColor Yellow
Write-Host ""
Write-Host "Terminal 1 (INITIATOR):" -ForegroundColor Green
Write-Host "  flutter test integration_test/two_device_test.dart -d $($devices[0]) --dart-define=TEST_ROLE=initiator" -ForegroundColor White
Write-Host ""
Write-Host "Terminal 2 (JOINER):" -ForegroundColor Cyan
Write-Host "  flutter test integration_test/two_device_test.dart -d $($devices[1]) --dart-define=TEST_ROLE=joiner" -ForegroundColor White
Write-Host ""
Write-Host "TIP: Start the INITIATOR first, wait 5 seconds, then start the JOINER" -ForegroundColor Yellow
Write-Host ""
