#Requires -RunAsAdministrator
<#
.SYNOPSIS
    NeoTiny11 Gaming Builder - Bloatware Removal
.DESCRIPTION
    Removes unnecessary Windows apps from the mounted image.
    Based on tiny11builder app removal with gaming considerations.
.PARAMETER MountPath
    Path to the mounted Windows image
.PARAMETER Config
    Configuration object with removal settings
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$MountPath,

    [Parameter(Mandatory = $true)]
    [PSCustomObject]$Config
)

$ErrorActionPreference = "SilentlyContinue"

function Write-Step {
    param([string]$Message, [string]$Status = "INFO")
    $color = switch ($Status) {
        "INFO"    { "Cyan" }
        "SUCCESS" { "Green" }
        "WARNING" { "Yellow" }
        "ERROR"   { "Red" }
        default   { "White" }
    }
    $prefix = switch ($Status) {
        "INFO"    { "    [*]" }
        "SUCCESS" { "    [+]" }
        "WARNING" { "    [!]" }
        "ERROR"   { "    [X]" }
        default   { "    [-]" }
    }
    Write-Host "$prefix $Message" -ForegroundColor $color
}

# Define bloatware packages to remove
$BloatwareApps = @(
    # Microsoft Bloatware
    "Microsoft.BingNews"
    "Microsoft.BingWeather"
    "Microsoft.BingFinance"
    "Microsoft.BingSports"
    "Microsoft.BingTranslator"
    "Microsoft.BingFoodAndDrink"
    "Microsoft.BingHealthAndFitness"
    "Microsoft.BingTravel"

    # Communication & Social
    "Microsoft.People"
    "microsoft.windowscommunicationsapps"  # Mail & Calendar
    "Microsoft.SkypeApp"
    "Microsoft.YourPhone"
    "MicrosoftTeams"
    "Microsoft.Todos"

    # Entertainment (non-gaming)
    "Microsoft.ZuneMusic"
    "Microsoft.ZuneVideo"
    "Microsoft.MicrosoftSolitaireCollection"
    "Microsoft.GamingApp"  # Xbox app (optional)
    "Microsoft.MixedReality.Portal"
    "Microsoft.549981C3F5F10"  # Cortana

    # Productivity Bloat
    "Microsoft.MicrosoftOfficeHub"
    "Microsoft.Office.OneNote"
    "Microsoft.MicrosoftStickyNotes"
    "Microsoft.PowerAutomateDesktop"
    "Clipchamp.Clipchamp"
    "Microsoft.Windows.DevHome"
    "Microsoft.OutlookForWindows"

    # Media & Photos
    "Microsoft.Windows.Photos"  # Optional - some prefer it
    "Microsoft.WindowsSoundRecorder"
    "Microsoft.WindowsCamera"

    # Maps & Location
    "Microsoft.WindowsMaps"
    "Microsoft.WindowsAlarms"

    # System Utilities (bloat)
    "Microsoft.GetHelp"
    "Microsoft.Getstarted"  # Tips
    "Microsoft.WindowsFeedbackHub"
    "Microsoft.ScreenSketch"
    "Microsoft.Paint"  # New Paint 3D

    # Microsoft 365 & Store Promotions
    "Microsoft.Microsoft3DViewer"
    "Microsoft.Print3D"
    "Microsoft.OneConnect"
    "Microsoft.MicrosoftFamily"

    # Third-party Bloatware
    "Disney.37853FC22B2CE"
    "SpotifyAB.SpotifyMusic"
    "*EclipseManager*"
    "*ActiproSoftwareLLC*"
    "*AdobeSystemsIncorporated.AdobePhotoshopExpress*"
    "*Duolingo-LearnLanguagesforFree*"
    "*PandoraMediaInc*"
    "*CandyCrush*"
    "*BubbleWitch3Saga*"
    "*Wunderlist*"
    "*Flipboard*"
    "*Twitter*"
    "*Facebook*"
    "*Royal Revolt*"
    "*Sway*"
    "*Speed Test*"
    "*Dolby*"
    "*Viber*"
    "*ACGMediaPlayer*"
    "*Netflix*"
    "*OneCalendar*"
    "*LinkedInforWindows*"
    "*HiddenCityMysteryofShadows*"
    "*Hulu*"
    "*HiddenCity*"
    "*AdobePhotoshopExpress*"
    "*HotspotShieldFreeVPN*"
    "*TikTok*"
    "*AmazonPrimeVideo*"
    "*Instagram*"
    "*WhatsApp*"

    # Windows 11 Specific
    "Microsoft.Copilot"
    "Microsoft.Windows.Ai.Copilot.Provider"
    "MicrosoftCorporationII.MicrosoftFamily"
    "MicrosoftCorporationII.QuickAssist"
    "Microsoft.WindowsTerminal"  # Optional

    # Widgets
    "MicrosoftWindows.Client.WebExperience"
)

# Conditional removals based on config
$ConditionalRemovals = @{
    "RemoveEdge" = @(
        "Microsoft.MicrosoftEdge"
        "Microsoft.MicrosoftEdge.Stable"
        "Microsoft.MicrosoftEdgeDevToolsClient"
    )
    "RemoveXboxApps" = @(
        "Microsoft.XboxApp"
        "Microsoft.XboxGameOverlay"
        "Microsoft.XboxGamingOverlay"
        "Microsoft.XboxIdentityProvider"
        "Microsoft.XboxSpeechToTextOverlay"
        "Microsoft.Xbox.TCUI"
    )
}

# Keep these for gaming
$GamingEssentials = @(
    "Microsoft.DirectXRuntime"
    "Microsoft.VCLibs*"
    "Microsoft.NET*"
    "Microsoft.WindowsStore"
    "Microsoft.StorePurchaseApp"
    "Microsoft.DesktopAppInstaller"  # Winget
    "Microsoft.HEIFImageExtension"
    "Microsoft.HEVCVideoExtension"
    "Microsoft.WebMediaExtensions"
    "Microsoft.WebpImageExtension"
    "Microsoft.VP9VideoExtensions"
)

Write-Step "Starting bloatware removal process..." "INFO"

# Get installed provisioned packages
$installedPackages = dism /English /Image:"$MountPath" /Get-ProvisionedAppxPackages

# Parse package names
$packages = @()
foreach ($line in $installedPackages) {
    if ($line -match "PackageName\s*:\s*(.+)") {
        $packages += $matches[1].Trim()
    }
}

Write-Step "Found $($packages.Count) provisioned packages" "INFO"

$removedCount = 0
$skippedCount = 0

foreach ($package in $packages) {
    $shouldRemove = $false
    $isEssential = $false

    # Check if it's a gaming essential
    foreach ($essential in $GamingEssentials) {
        if ($package -like $essential) {
            $isEssential = $true
            break
        }
    }

    if ($isEssential) {
        $skippedCount++
        continue
    }

    # Check against bloatware list
    foreach ($bloat in $BloatwareApps) {
        if ($package -like "*$bloat*") {
            $shouldRemove = $true
            break
        }
    }

    # Check conditional removals
    if ($Config.Bloatware.RemoveEdge) {
        foreach ($edge in $ConditionalRemovals["RemoveEdge"]) {
            if ($package -like "*$edge*") {
                $shouldRemove = $true
                break
            }
        }
    }

    if ($Config.Bloatware.RemoveXboxApps) {
        foreach ($xbox in $ConditionalRemovals["RemoveXboxApps"]) {
            if ($package -like "*$xbox*") {
                $shouldRemove = $true
                break
            }
        }
    }

    # Remove the package
    if ($shouldRemove) {
        Write-Step "Removing: $($package.Split('_')[0])" "INFO"
        dism /English /Image:"$MountPath" /Remove-ProvisionedAppxPackage /PackageName:"$package" 2>$null
        $removedCount++
    }
}

Write-Step "Removed $removedCount packages, kept $skippedCount essential packages" "SUCCESS"

# Remove OneDrive
if ($Config.Bloatware.RemoveOneDrive) {
    Write-Step "Removing OneDrive..." "INFO"

    $onedriveSetup = "$MountPath\Windows\System32\OneDriveSetup.exe"
    $onedriveSysWow = "$MountPath\Windows\SysWOW64\OneDriveSetup.exe"

    if (Test-Path $onedriveSetup) {
        takeown /F $onedriveSetup /A 2>$null
        icacls $onedriveSetup /grant Administrators:F 2>$null
        Remove-Item $onedriveSetup -Force 2>$null
    }

    if (Test-Path $onedriveSysWow) {
        takeown /F $onedriveSysWow /A 2>$null
        icacls $onedriveSysWow /grant Administrators:F 2>$null
        Remove-Item $onedriveSysWow -Force 2>$null
    }

    Write-Step "OneDrive removed" "SUCCESS"
}

# Remove Edge components
if ($Config.Bloatware.RemoveEdge) {
    Write-Step "Removing Microsoft Edge components..." "INFO"

    $edgePaths = @(
        "$MountPath\Program Files (x86)\Microsoft\Edge"
        "$MountPath\Program Files (x86)\Microsoft\EdgeUpdate"
        "$MountPath\Program Files (x86)\Microsoft\EdgeCore"
        "$MountPath\Program Files (x86)\Microsoft\EdgeWebView"
        "$MountPath\Program Files\Microsoft\Edge"
        "$MountPath\Program Files\Microsoft\EdgeUpdate"
    )

    foreach ($path in $edgePaths) {
        if (Test-Path $path) {
            takeown /F $path /R /A 2>$null
            icacls $path /grant Administrators:F /T 2>$null
            Remove-Item $path -Recurse -Force 2>$null
        }
    }

    Write-Step "Edge components removed" "SUCCESS"
}

# Remove Windows Features (optional)
$featuresToRemove = @(
    "Microsoft-Windows-InternetExplorer-Optional-Package"
    "Microsoft-Windows-Kernel-LA57-FoD-Package"
    "Microsoft-Windows-LanguageFeatures-Handwriting*"
    "Microsoft-Windows-LanguageFeatures-OCR*"
    "Microsoft-Windows-LanguageFeatures-Speech*"
    "Microsoft-Windows-LanguageFeatures-TextToSpeech*"
    "Microsoft-Windows-MediaPlayer-Package"
    "Microsoft-Windows-TabletPCMath-Package"
    "Microsoft-Windows-Wallpaper-Content-Extended-FoD-Package"
)

Write-Step "Removing optional features..." "INFO"
$featuresRemoved = 0

foreach ($feature in $featuresToRemove) {
    $result = dism /English /Image:"$MountPath" /Remove-Package /PackageName:"$feature" 2>&1
    if ($LASTEXITCODE -eq 0) {
        $featuresRemoved++
    }
}

Write-Step "Removed $featuresRemoved optional features" "SUCCESS"

Write-Step "Bloatware removal completed" "SUCCESS"
