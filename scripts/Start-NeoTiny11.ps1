#Requires -RunAsAdministrator
<#
.SYNOPSIS
    NeoTiny11 Gaming Builder - Main Orchestrator
.DESCRIPTION
    Main script that coordinates all NeoTiny11 building phases.
    Allows selecting an extracted ISO folder (no mounting required).
.NOTES
    Run as Administrator
#>

param(
    [string]$SourcePath,
    [string]$ConfigPath = "$PSScriptRoot\..\config\settings.json"
)

$ErrorActionPreference = "Stop"
$Host.UI.RawUI.WindowTitle = "NeoTiny11 Gaming Builder"

#region Variables
$Script:ScriptsPath = $PSScriptRoot
$Script:RootPath = Split-Path $PSScriptRoot -Parent
$Script:OutputPath = "$Script:RootPath\output"
$Script:ScratchPath = "$Script:RootPath\scratch"
$Script:TempPath = "$Script:RootPath\temp"
$Script:ToolsPath = "$Script:RootPath\tools"
#endregion

#region Functions
function Show-Banner {
    Clear-Host
    $banner = @"

 _   _            _____  _             _ _
| \ | |          |_   _|(_)           | | |
|  \| |  ___   ___  | |   _  _ __   _ | | |
| . ` | / _ \ / _ \ | |  | || '_ \ | || | |
| |\  ||  __/| (_) || |  | || | | || ||_  |
\_| \_/ \___| \___/\_/  |_||_| |_| \__, (_)
                                    __/ |
   Gaming Builder v1.0             |___/

"@
    Write-Host $banner -ForegroundColor Cyan
    Write-Host "===============================================================" -ForegroundColor DarkGray
    Write-Host "  Windows 11 Gaming-Optimized Image Builder" -ForegroundColor White
    Write-Host "  Based on tiny11builder + Atlas OS optimizations" -ForegroundColor Gray
    Write-Host "===============================================================" -ForegroundColor DarkGray
    Write-Host ""
}

function Write-Step {
    param([string]$Message, [string]$Status = "INFO")
    $color = switch ($Status) {
        "INFO"    { "Cyan" }
        "SUCCESS" { "Green" }
        "WARNING" { "Yellow" }
        "ERROR"   { "Red" }
        "STEP"    { "Magenta" }
        default   { "White" }
    }
    $prefix = switch ($Status) {
        "INFO"    { "[*]" }
        "SUCCESS" { "[+]" }
        "WARNING" { "[!]" }
        "ERROR"   { "[X]" }
        "STEP"    { "[>]" }
        default   { "[-]" }
    }
    Write-Host "$prefix $Message" -ForegroundColor $color
}

function Get-IsoSourcePath {
    Write-Host ""
    Write-Step "SELECT WINDOWS 11 SOURCE" "STEP"
    Write-Host ""
    Write-Host "  You can use an extracted ISO folder - no mounting required!" -ForegroundColor Gray
    Write-Host "  Just extract the ISO with 7-Zip or similar and point to the folder." -ForegroundColor Gray
    Write-Host ""

    Add-Type -AssemblyName System.Windows.Forms

    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.Description = "Select the Windows 11 ISO extracted folder (should contain 'sources' folder)"
    $dialog.ShowNewFolderButton = $false
    $dialog.RootFolder = [System.Environment+SpecialFolder]::MyComputer

    Write-Step "Opening folder selection dialog..." "INFO"

    $result = $dialog.ShowDialog()

    if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
        $selectedPath = $dialog.SelectedPath

        # Validate the selected folder
        if (Test-Path "$selectedPath\sources\install.wim" -or Test-Path "$selectedPath\sources\install.esd") {
            Write-Step "Valid Windows source detected: $selectedPath" "SUCCESS"
            return $selectedPath
        }
        else {
            Write-Step "Invalid folder: 'sources\install.wim' or 'install.esd' not found!" "ERROR"
            Write-Step "Please select a valid extracted Windows 11 ISO folder." "WARNING"
            return $null
        }
    }
    else {
        Write-Step "No folder selected. Exiting." "WARNING"
        return $null
    }
}

function Get-WindowsEdition {
    param([string]$SourcePath)

    Write-Host ""
    Write-Step "AVAILABLE WINDOWS EDITIONS" "STEP"
    Write-Host ""

    # Detect WIM or ESD
    $installFile = if (Test-Path "$SourcePath\sources\install.wim") {
        "$SourcePath\sources\install.wim"
    } else {
        "$SourcePath\sources\install.esd"
    }

    # Get available editions
    $wimInfo = dism /English /Get-WimInfo /WimFile:"$installFile"

    # Parse editions
    $editions = @()
    $currentIndex = $null
    $currentName = $null

    foreach ($line in $wimInfo) {
        if ($line -match "^Index\s*:\s*(\d+)") {
            $currentIndex = $matches[1]
        }
        if ($line -match "^Name\s*:\s*(.+)") {
            $currentName = $matches[1].Trim()
            if ($currentIndex -and $currentName) {
                $editions += [PSCustomObject]@{
                    Index = $currentIndex
                    Name = $currentName
                }
            }
        }
    }

    # Display editions
    Write-Host "  Available editions:" -ForegroundColor White
    Write-Host ""
    foreach ($edition in $editions) {
        $recommended = if ($edition.Name -match "Pro") { " (Recommended for Gaming)" } else { "" }
        Write-Host "    [$($edition.Index)] $($edition.Name)$recommended" -ForegroundColor Gray
    }
    Write-Host ""

    # Get user selection
    do {
        $selection = Read-Host "  Select edition index"
    } while ($selection -notin $editions.Index)

    $selectedEdition = $editions | Where-Object { $_.Index -eq $selection }
    Write-Step "Selected: $($selectedEdition.Name)" "SUCCESS"

    return @{
        Index = $selection
        Name = $selectedEdition.Name
        File = $installFile
    }
}

function Initialize-Environment {
    Write-Host ""
    Write-Step "INITIALIZING ENVIRONMENT" "STEP"
    Write-Host ""

    # Create directories
    $dirs = @($Script:OutputPath, $Script:ScratchPath, $Script:TempPath, $Script:ToolsPath)
    foreach ($dir in $dirs) {
        if (-not (Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
            Write-Step "Created: $dir" "INFO"
        }
    }

    # Download oscdimg if not present
    $oscdimgPath = "$Script:ToolsPath\oscdimg.exe"
    if (-not (Test-Path $oscdimgPath)) {
        Write-Step "Downloading oscdimg.exe..." "INFO"
        try {
            $oscdimgUrl = "https://msdl.microsoft.com/download/symbols/oscdimg.exe/3D44737265000/oscdimg.exe"
            Invoke-WebRequest -Uri $oscdimgUrl -OutFile $oscdimgPath -UseBasicParsing
            Write-Step "oscdimg.exe downloaded successfully" "SUCCESS"
        }
        catch {
            Write-Step "Failed to download oscdimg.exe. Please install Windows ADK." "WARNING"
        }
    }

    Write-Step "Environment initialized" "SUCCESS"
}

function Start-BuildProcess {
    param(
        [string]$SourcePath,
        [hashtable]$Edition,
        [PSCustomObject]$Config
    )

    $startTime = Get-Date
    Write-Host ""
    Write-Step "STARTING BUILD PROCESS" "STEP"
    Write-Host ""
    Write-Step "Source: $SourcePath" "INFO"
    Write-Step "Edition: $($Edition.Name)" "INFO"
    Write-Host ""

    # Phase 1: Copy source files
    Write-Step "Phase 1/6: Copying source files..." "STEP"
    $destPath = "$Script:ScratchPath\iso"
    if (Test-Path $destPath) {
        Remove-Item -Path $destPath -Recurse -Force
    }
    Copy-Item -Path $SourcePath -Destination $destPath -Recurse -Force
    Write-Step "Source files copied" "SUCCESS"

    # Phase 2: Extract WIM/ESD
    Write-Step "Phase 2/6: Extracting Windows image..." "STEP"
    $mountPath = "$Script:ScratchPath\mount"
    if (-not (Test-Path $mountPath)) {
        New-Item -ItemType Directory -Path $mountPath -Force | Out-Null
    }

    $installFile = if (Test-Path "$destPath\sources\install.wim") {
        "$destPath\sources\install.wim"
    } else {
        "$destPath\sources\install.esd"
    }

    # Export selected edition to new WIM
    $newWim = "$Script:ScratchPath\install.wim"
    Write-Step "Exporting edition $($Edition.Index)..." "INFO"
    dism /English /Export-Image /SourceImageFile:"$installFile" /SourceIndex:$($Edition.Index) /DestinationImageFile:"$newWim" /Compress:max /CheckIntegrity

    # Mount the WIM
    Write-Step "Mounting Windows image..." "INFO"
    dism /English /Mount-Wim /WimFile:"$newWim" /Index:1 /MountDir:"$mountPath"
    Write-Step "Image mounted" "SUCCESS"

    # Phase 3: Remove Bloatware
    Write-Step "Phase 3/6: Removing bloatware..." "STEP"
    & "$Script:ScriptsPath\Remove-Bloatware.ps1" -MountPath $mountPath -Config $Config
    Write-Step "Bloatware removed" "SUCCESS"

    # Phase 4: Apply Gaming Optimizations
    Write-Step "Phase 4/6: Applying gaming optimizations..." "STEP"
    & "$Script:ScriptsPath\Set-GamingOptimizations.ps1" -MountPath $mountPath -Config $Config
    Write-Step "Gaming optimizations applied" "SUCCESS"

    # Phase 5: Apply Service & Registry Tweaks
    Write-Step "Phase 5/6: Optimizing services and registry..." "STEP"
    & "$Script:ScriptsPath\Set-ServiceOptimizations.ps1" -MountPath $mountPath -Config $Config
    & "$Script:ScriptsPath\Set-RegistryTweaks.ps1" -MountPath $mountPath -Config $Config
    Write-Step "Services and registry optimized" "SUCCESS"

    # Phase 6: Build ISO
    Write-Step "Phase 6/6: Building ISO..." "STEP"
    & "$Script:ScriptsPath\Build-ISO.ps1" -ScratchPath $Script:ScratchPath -OutputPath $Script:OutputPath -Config $Config -ToolsPath $Script:ToolsPath
    Write-Step "ISO built successfully" "SUCCESS"

    $endTime = Get-Date
    $duration = $endTime - $startTime

    Write-Host ""
    Write-Host "===============================================================" -ForegroundColor Green
    Write-Host "  BUILD COMPLETED SUCCESSFULLY!" -ForegroundColor Green
    Write-Host "===============================================================" -ForegroundColor Green
    Write-Host ""
    Write-Step "Duration: $($duration.ToString('hh\:mm\:ss'))" "INFO"
    Write-Step "Output: $Script:OutputPath\$($Config.General.IsoFileName)" "INFO"
    Write-Host ""
}

function Start-Cleanup {
    param([PSCustomObject]$Config)

    if (-not $Config.General.KeepScratchFiles) {
        Write-Step "Cleaning up temporary files..." "INFO"

        # Unmount any mounted images
        dism /English /Unmount-Wim /MountDir:"$Script:ScratchPath\mount" /Discard 2>$null

        # Remove scratch directory
        if (Test-Path $Script:ScratchPath) {
            Remove-Item -Path $Script:ScratchPath -Recurse -Force -ErrorAction SilentlyContinue
        }
        if (Test-Path $Script:TempPath) {
            Remove-Item -Path $Script:TempPath -Recurse -Force -ErrorAction SilentlyContinue
        }

        Write-Step "Cleanup complete" "SUCCESS"
    }
}
#endregion

#region Main Execution
Show-Banner

# Load configuration
if (Test-Path $ConfigPath) {
    $Config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
    Write-Step "Configuration loaded from: $ConfigPath" "SUCCESS"
} else {
    Write-Step "Configuration file not found: $ConfigPath" "ERROR"
    exit 1
}

# Get source path
if (-not $SourcePath) {
    $SourcePath = Get-IsoSourcePath
}

if (-not $SourcePath) {
    Write-Step "No source selected. Exiting." "ERROR"
    exit 1
}

# Get Windows edition
$Edition = Get-WindowsEdition -SourcePath $SourcePath

# Initialize environment
Initialize-Environment

# Confirm build
Write-Host ""
Write-Host "===============================================================" -ForegroundColor Yellow
Write-Host "  READY TO BUILD" -ForegroundColor Yellow
Write-Host "===============================================================" -ForegroundColor Yellow
Write-Host ""
Write-Host "  Source:  $SourcePath" -ForegroundColor White
Write-Host "  Edition: $($Edition.Name)" -ForegroundColor White
Write-Host "  Output:  $Script:OutputPath\$($Config.General.IsoFileName)" -ForegroundColor White
Write-Host ""
Write-Host "  This will create a gaming-optimized Windows 11 image." -ForegroundColor Gray
Write-Host ""

$confirm = Read-Host "  Proceed with build? (Y/N)"

if ($confirm -match "^[Yy]") {
    try {
        Start-BuildProcess -SourcePath $SourcePath -Edition $Edition -Config $Config
    }
    catch {
        Write-Step "Build failed: $_" "ERROR"
        Write-Step "Stack trace: $($_.ScriptStackTrace)" "ERROR"
    }
    finally {
        Start-Cleanup -Config $Config
    }
}
else {
    Write-Step "Build cancelled by user." "WARNING"
}

Write-Host ""
Write-Host "Press any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
#endregion
