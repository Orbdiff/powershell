# Script made by diff

Clear-Host

$forbiddenProcesses = @(
    "chrome","firefox","msedge","opera","opera_gx","brave","vivaldi",
    "browser","waterfox","librewolf","palemoon","tor","torbrowser",
    "chromium","ungoogled-chromium","epicbrowser","slimjet","comodo",

    "obs","obs32","obs64","streamlabs","camtasia","bandicam","xsplit",
    "fraps","action","dxtory","sharex","screenrec","flashback", "bdcam",

    "gamebar","xboxgamebar","gamebarpresencewriter","broadcastdvr",
    "discord","discordcanary","discordptb","steam","steamwebhelper",
    "overwolf","teams","riotclientservices","epicgameslauncher",

    "nvcontainer","nvdisplay.container","nvidiashare","nvbackend",
    "nvsphelper64","nvstreamer","nvtray","nvtelemetry","nvfbc","nvifrex",

    "amdsoftware","radeonsoftware","amdxcapture","amdenc","amddvr"
)

Write-Host "======================================================" -ForegroundColor Green
Write-Host "   Killer Capture Screen Processes made by Diff" -ForegroundColor Green
Write-Host "======================================================" -ForegroundColor Green
Write-Host ""

$detected = @{}
$allProcs = Get-Process -ErrorAction SilentlyContinue

foreach ($proc in $allProcs) {
    try {
        $name = $proc.Name.ToLower()
        $isForbidden = $forbiddenProcesses -contains $name
        $isCapture = $false

        $modules = $proc.Modules.ModuleName
        if (
            $modules -contains "Windows.Graphics.Capture.dll" -or
            $modules -match "graphicscapture" -or
            $modules -match "nvencodeapi" -or
            $modules -match "amdenc|amf"
        ) {
            $isCapture = $true
        }

        if (($isForbidden -or $isCapture) -and -not $detected.ContainsKey($name)) {
            $detected[$name] = @{
                Name = $proc.Name
                Type = if ($isForbidden -and $isCapture) {
                    "Capture + Forbidden"
                } elseif ($isCapture) {
                    "Screen Capture"
                } else {
                    "Forbidden Process"
                }
            }
        }
    } catch {}
}

if ($detected.Count -eq 0) {
    Write-Host "[+] No forbidden or capture processes detected." -ForegroundColor Green
    exit
}

Write-Host "[!] Detected processes:" -ForegroundColor Yellow
Write-Host ""

foreach ($item in $detected.Values) {
    Write-Host ("  - {0}.exe [{1}]" -f $item.Name, $item.Type) -ForegroundColor Cyan
}

Write-Host ""
Write-Host "[A] Kill all detected processes."
Write-Host "[B] Kill 1 specific process."
Write-Host "[C] Kill all except 1 process."
Write-Host ""

$choice = Read-Host "Select option (A / B / C)"

switch ($choice.ToUpper()) {

    "A" {
        foreach ($item in $detected.Values) {
            Get-Process -Name $item.Name -ErrorAction SilentlyContinue |
                Stop-Process -Force
            Write-Host "[Terminated] $($item.Name).exe" -ForegroundColor Red
        }
    }

    "B" {
        $target = Read-Host "Enter process name (example: chrome or chrome.exe)"
        $target = $target.ToLower().Replace(".exe","")

        if ($detected.ContainsKey($target)) {
            Get-Process -Name $target -ErrorAction SilentlyContinue |
                Stop-Process -Force
            Write-Host "[Terminated] $target.exe" -ForegroundColor Red
        } else {
            Write-Host "[Error] Process not found." -ForegroundColor Red
        }
    }

    "C" {
        $exclude = Read-Host "Enter process name to keep alive (example: chrome or chrome.exe)"
        $exclude = $exclude.ToLower().Replace(".exe","")

        if (-not $detected.ContainsKey($exclude)) {
            Write-Host "[Error] Process not found." -ForegroundColor Red
            exit
        }

        foreach ($key in $detected.Keys) {
            if ($key -ne $exclude) {
                Get-Process -Name $key -ErrorAction SilentlyContinue |
                    Stop-Process -Force
                Write-Host "[Terminated] $key.exe" -ForegroundColor Red
            }
        }

        Write-Host "[+] Kept alive: $exclude.exe" -ForegroundColor Green
    }
}
