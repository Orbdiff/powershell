$usbdetector = "https://github.com/Orbdiff/USBDetector/releases/download/v0.1/USBDetector.exe"
$path = Join-Path $env:TEMP "USBDetector.exe"

try {
    (New-Object Net.WebClient).DownloadFile($usbdetector, $path)
} catch {
    
}

if (Test-Path "$path:Zone.Identifier") { Remove-Item "$path:Zone.Identifier" -Force -ErrorAction SilentlyContinue }

if (Test-Path $path) { Start-Process $path }
