cls

Write-Host @"
   _____ _                   _                       _____                         
  / ____(_)                 | |                     |  __ \                        
 | (___  _  __ _ _ __   __ _| |_ _   _ _ __ ___  ___| |__) |_ _ _ __ ___  ___ _ __ 
  \___ \| |/ _` | '_ \ / _` | __| | | | '__/ _ \/ __|  ___/ _` | '__/ __|/ _ \ '__|
  ____) | | (_| | | | | (_| | |_| |_| | | |  __/\__ \ |  | (_| | |  \__ \  __/ |   
 |_____/|_|\__, |_| |_|\__,_|\__|\__,_|_|  \___||___/_|   \__,_|_|  |___/\___|_|   
            __/ |                                                                  
           |___/                                                                                                                                             
"@ -ForegroundColor Green
Write-Host ""
Write-Host "  Made by " -ForegroundColor Gray -NoNewline
Write-Host -ForegroundColor DarkGreen "Diff"
Write-Host ""

Start-Sleep -s 3
cls

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "This script requires administrator privileges to run properly. Please run PowerShell as an administrator." -ForegroundColor Red
    Start-Sleep -s 5
    exit
}

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
using System.Text;
public class Kernel32 {
    [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Auto)]
    public static extern uint QueryDosDevice(string lpDeviceName, StringBuilder lpTargetPath, uint ucchMax);
}
"@

function Get-DeviceMappings {
    $Max = 65536
    $StringBuilder = New-Object System.Text.StringBuilder($Max)
    $driveMappings = Get-WmiObject Win32_Volume | Where-Object { $_.DriveLetter } | ForEach-Object {
        $ReturnLength = [Kernel32]::QueryDosDevice($_.DriveLetter, $StringBuilder, $Max)
        if ($ReturnLength) {
            @{
                DriveLetter = $_.DriveLetter
                DevicePath = $StringBuilder.ToString().ToLower()
            }
        }
    }
    return $driveMappings
}

function Replace-DevicePaths($line, $driveMappings) {
    foreach ($driveMapping in $driveMappings) {
        $line = $line.Replace($driveMapping.DevicePath, $driveMapping.DriveLetter)
    }
    return $line
}

function Get-AdvancedSignatureStatus($path) {
    if (-not (Test-Path -Path $path -PathType Leaf)) {
        return "NotFound"
    }
    try {
        $cert = [System.Security.Cryptography.X509Certificates.X509Certificate2]::CreateFromSignedFile($path)
        $cert2 = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2 $cert
        $cheatSignatures = @("manthe industries, llc", "slinkware", "amstion limited", "newfakeco", "faked signatures inc")
        foreach ($cheat in $cheatSignatures) {
            if ($cert2.Subject.ToLower().Contains($cheat.ToLower())) {
                return "Cheat Signature"
            }
        }
        $chain = New-Object System.Security.Cryptography.X509Certificates.X509Chain
        $chain.ChainPolicy.RevocationMode = [System.Security.Cryptography.X509Certificates.X509RevocationMode]::NoCheck
        $chain.ChainPolicy.VerificationFlags = [System.Security.Cryptography.X509Certificates.X509VerificationFlags]::AllowUnknownCertificateAuthority -bor [System.Security.Cryptography.X509Certificates.X509VerificationFlags]::IgnoreNotTimeValid
        $isValid = $chain.Build($cert2)
        if ($isValid -and $chain.ChainElements.Count -gt 1) {
            return "Signed"
        } elseif ($cert2.Subject -eq $cert2.Issuer) {
            return "Fake Sig"
        } else {
            return "Fake Sig"
        }
    } catch {
        return "Unsigned"
    }
}

$driveMappings = Get-DeviceMappings
$possiblePathsFiles = @("Search results.txt", "paths.txt", "p.txt")
$pathsFilePath = $possiblePathsFiles | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $pathsFilePath) {
    Write-Warning "None of the files ($($possiblePathsFiles -join ', ')) exist."
    Start-Sleep 3
    Exit
}

$stopwatch = [Diagnostics.Stopwatch]::StartNew()
$foundPaths = @()
$reader = [System.IO.StreamReader]::new($pathsFilePath)
$lineCount = 0
while (($line = $reader.ReadLine()) -ne $null) {
    $lineCount++
    Write-Progress -Activity "Processing lines" -Status "$lineCount lines processed" -PercentComplete -1
    $line = Replace-DevicePaths -line $line -driveMappings $driveMappings
    $startIndex = 0
    while (($colonIndex = $line.IndexOf(":\", $startIndex)) -gt 0) {
        if ($colonIndex -gt 0) {
            $driveLetter = $line[$colonIndex - 1]
            if ([char]::IsLetter($driveLetter)) {
                $potentialPath = $line.Substring($colonIndex - 1)
                if ($potentialPath.Contains(".exe") -or $potentialPath.Contains(".dll")) {
                    $exeIndex = $potentialPath.IndexOf(".exe")
                    $dllIndex = $potentialPath.IndexOf(".dll")
                    $endIndex = -1
                    if ($exeIndex -ge 0) {
                        $endIndex = $exeIndex + 4
                    } elseif ($dllIndex -ge 0) {
                        $endIndex = $dllIndex + 4
                    }
                    if ($endIndex -gt 0) {
                        $path = $potentialPath.Substring(0, $endIndex)
                        $foundPaths += $path
                    }
                }
            }
        }
        $startIndex = $colonIndex + 2
    }
}
$reader.Close()
Write-Host "Total lines processed: $lineCount" -ForegroundColor Cyan
$uniquePaths = $foundPaths | Select-Object -Unique
Write-Host "Total unique paths found: $($uniquePaths.Count)" -ForegroundColor Green

$username = $env:USERNAME
$uniquePaths = $uniquePaths | ForEach-Object {
    $path = $_
    $usersIndex = $path.IndexOf("Users\", [System.StringComparison]::OrdinalIgnoreCase)
    if ($usersIndex -ge 0) {
        $afterUsers = $path.Substring($usersIndex + 6)
        $afterUsers = $afterUsers.Replace("#un#", $username)
        $path = $path.Substring(0, $usersIndex + 6) + $afterUsers
    }
    $path
}

$results = @()
for ($j = 0; $j -lt $uniquePaths.Count; $j++) {
    $path = $uniquePaths[$j]
    Write-Progress -Activity "Obtaining signatures" -Status "$($j + 1) of $($uniquePaths.Count)" -PercentComplete (($j / $uniquePaths.Count) * 100)
    if (-not (Test-Path -Path $path -PathType Leaf)) {
        $results += [pscustomobject]@{
            Path = $path
            SignatureStatus = "NotFound"
            SignerName = ""
            IsOSBinary = $false
        }
        continue
    }
    Try {
        $signatureStatus = Get-AdvancedSignatureStatus -path $path
        $signature = Get-AuthenticodeSignature $path 2>$null
        $authenticode = Get-AuthenticodeSignature -FilePath "$path" -ErrorAction SilentlyContinue
        if ($authenticode.SignerCertificate){
            $signerName = $authenticode.SignerCertificate.GetNameInfo([System.Security.Cryptography.X509Certificates.X509NameType]::SimpleName, $false)
        } else {
            $signerName = ""
        }
        $results += [pscustomobject]@{
            Path = $path
            SignatureStatus = $signatureStatus
            SignerName = $signerName
            IsOSBinary = $signature.IsOSBinary
        }
    } Catch {
        $results += [pscustomobject]@{
            Path = $path
            SignatureStatus = "Unsigned"
            SignerName = ""
            IsOSBinary = $false
        }
    }
}

$stopwatch.Stop()
$time = $stopwatch.Elapsed.ToString("hh\:mm\:ss\.fff")
Write-Host "`n"
Write-Host "Scanning took $time to execute." -ForegroundColor Yellow

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$form = New-Object System.Windows.Forms.Form
$form.Text = 'Signature Results - Made by Diff'
$form.WindowState = 'Maximized'
$form.BackColor = [System.Drawing.Color]::WhiteSmoke

$dataGridView = New-Object System.Windows.Forms.DataGridView
$dataGridView.Dock = 'Fill'
$dataGridView.AutoSizeColumnsMode = 'Fill'
$dataGridView.ReadOnly = $true
$dataGridView.AllowUserToAddRows = $false
$dataGridView.BackgroundColor = [System.Drawing.Color]::White
$dataGridView.GridColor = [System.Drawing.Color]::Gray
$dataGridView.ColumnHeadersDefaultCellStyle.BackColor = [System.Drawing.Color]::LightBlue
$dataGridView.ColumnHeadersDefaultCellStyle.ForeColor = [System.Drawing.Color]::Black
$dataGridView.ColumnHeadersDefaultCellStyle.Font = New-Object System.Drawing.Font("Arial", 10, [System.Drawing.FontStyle]::Bold)
$dataGridView.DefaultCellStyle.Font = New-Object System.Drawing.Font("Arial", 9)

$form.Controls.Add($dataGridView)

$bottomPanel = New-Object System.Windows.Forms.Panel
$bottomPanel.Dock = 'Bottom'
$bottomPanel.Height = 70
$bottomPanel.BackColor = [System.Drawing.Color]::WhiteSmoke
$form.Controls.Add($bottomPanel)

$searchLabel = New-Object System.Windows.Forms.Label
$searchLabel.Text = "Search in Path:"
$searchLabel.Location = New-Object System.Drawing.Point(10, 15)
$searchLabel.AutoSize = $true
$bottomPanel.Controls.Add($searchLabel)

$searchTextBox = New-Object System.Windows.Forms.TextBox
$searchTextBox.Location = New-Object System.Drawing.Point(120, 12)
$searchTextBox.Width = 200
$bottomPanel.Controls.Add($searchTextBox)

$filterLabel = New-Object System.Windows.Forms.Label
$filterLabel.Text = "Signature Filters:"
$filterLabel.Location = New-Object System.Drawing.Point(340, 15)
$filterLabel.AutoSize = $true
$bottomPanel.Controls.Add($filterLabel)

$signedCheckBox = New-Object System.Windows.Forms.CheckBox
$signedCheckBox.Text = "Signed"
$signedCheckBox.Location = New-Object System.Drawing.Point(450, 12)
$signedCheckBox.Checked = $true
$signedCheckBox.AutoSize = $true
$bottomPanel.Controls.Add($signedCheckBox)

$unsignedCheckBox = New-Object System.Windows.Forms.CheckBox
$unsignedCheckBox.Text = "Unsigned"
$unsignedCheckBox.Location = New-Object System.Drawing.Point(520, 12)
$unsignedCheckBox.Checked = $true
$unsignedCheckBox.AutoSize = $true
$bottomPanel.Controls.Add($unsignedCheckBox)

$fakeSigCheckBox = New-Object System.Windows.Forms.CheckBox
$fakeSigCheckBox.Text = "Fake Sig"
$fakeSigCheckBox.Location = New-Object System.Drawing.Point(600, 12)
$fakeSigCheckBox.Checked = $true
$fakeSigCheckBox.AutoSize = $true
$bottomPanel.Controls.Add($fakeSigCheckBox)

$cheatSigCheckBox = New-Object System.Windows.Forms.CheckBox
$cheatSigCheckBox.Text = "Cheat Sig"
$cheatSigCheckBox.Location = New-Object System.Drawing.Point(680, 12)
$cheatSigCheckBox.Checked = $true
$cheatSigCheckBox.AutoSize = $true
$bottomPanel.Controls.Add($cheatSigCheckBox)

$notFoundCheckBox = New-Object System.Windows.Forms.CheckBox
$notFoundCheckBox.Text = "NotFound"
$notFoundCheckBox.Location = New-Object System.Drawing.Point(760, 12)
$notFoundCheckBox.Checked = $true
$notFoundCheckBox.AutoSize = $true
$bottomPanel.Controls.Add($notFoundCheckBox)

$dataTable = New-Object System.Data.DataTable
[void]$dataTable.Columns.Add("Path", [string])
[void]$dataTable.Columns.Add("SignatureStatus", [string])
[void]$dataTable.Columns.Add("SignerName", [string])
[void]$dataTable.Columns.Add("IsOSBinary", [bool])

foreach ($result in $results) {
    $row = $dataTable.NewRow()
    $row["Path"] = $result.Path
    $row["SignatureStatus"] = $result.SignatureStatus
    $row["SignerName"] = $result.SignerName
    $row["IsOSBinary"] = $result.IsOSBinary
    $dataTable.Rows.Add($row)
}

$dataView = New-Object System.Data.DataView($dataTable)
$dataGridView.DataSource = $dataView

function Update-Filter {
    $filterParts = @()
    
    if ($searchTextBox.Text -ne "") {
        $filterParts += "Path LIKE '%$($searchTextBox.Text)%'"
    }
    
    $selectedStatuses = @()
    if ($signedCheckBox.Checked) { $selectedStatuses += "'Signed'" }
    if ($unsignedCheckBox.Checked) { $selectedStatuses += "'Unsigned'" }
    if ($fakeSigCheckBox.Checked) { $selectedStatuses += "'Fake Sig'" }
    if ($cheatSigCheckBox.Checked) { $selectedStatuses += "'Cheat Signature'" }
    if ($notFoundCheckBox.Checked) { $selectedStatuses += "'NotFound'" }
    
    if ($selectedStatuses.Count -gt 0) {
        $filterParts += "SignatureStatus IN ($( $selectedStatuses -join ',' ))"
    }
    
    $dataView.RowFilter = $filterParts -join ' AND '
}

$searchTextBox.Add_TextChanged({ Update-Filter })
$signedCheckBox.Add_CheckedChanged({ Update-Filter })
$unsignedCheckBox.Add_CheckedChanged({ Update-Filter })
$fakeSigCheckBox.Add_CheckedChanged({ Update-Filter })
$cheatSigCheckBox.Add_CheckedChanged({ Update-Filter })
$notFoundCheckBox.Add_CheckedChanged({ Update-Filter })

$dataGridView.add_CellFormatting({
    param($sender, $e)
    if ($e.ColumnIndex -eq 1) {
        switch ($e.Value) {
            "Signed" { $e.CellStyle.BackColor = [System.Drawing.Color]::LightGreen }
            "Unsigned" { $e.CellStyle.BackColor = [System.Drawing.Color]::LightCoral }
            "Fake Sig" { $e.CellStyle.BackColor = [System.Drawing.Color]::Orange }
            "Cheat Signature" { $e.CellStyle.BackColor = [System.Drawing.Color]::Red }
            "NotFound" { $e.CellStyle.BackColor = [System.Drawing.Color]::Gray }
        }
    }
})

$form.add_Shown({
    if ($dataGridView.Columns.Contains("Path")) {
        $dataGridView.Columns["Path"].Width = 400
    }
    if ($dataGridView.Columns.Contains("SignatureStatus")) {
        $dataGridView.Columns["SignatureStatus"].Width = 150
    }
    if ($dataGridView.Columns.Contains("SignerName")) {
        $dataGridView.Columns["SignerName"].Width = 200
    }
    if ($dataGridView.Columns.Contains("IsOSBinary")) {
        $dataGridView.Columns["IsOSBinary"].Width = 100
    }
})

[void]$form.ShowDialog()
