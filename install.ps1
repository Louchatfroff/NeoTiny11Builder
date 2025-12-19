#Requires -RunAsAdministrator
<#
.SYNOPSIS
    NeoTiny11 Gaming Builder - Web Installer
.DESCRIPTION
    One-line installer for NeoTiny11 Gaming Builder.
    Usage: irm https://neotiny11.vercel.app/install | iex
.NOTES
    Requires Administrator privileges
#>

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# Configuration
$RepoOwner = "Louchatfroff"
$RepoName = "NeoTiny11Builder"
$Branch = "main"
$InstallPath = "$env:TEMP\NeoTiny11Builder"

# Banner
function Show-Banner {
    $banner = @"

 _   _            _____  _             _ _
| \ | |          |_   _|(_)           | | |
|  \| |  ___   ___  | |   _  _ __   _ | | |
| . ` | / _ \ / _ \ | |  | || '_ \ | || | |
| |\  ||  __/| (_) || |  | || | | || ||_  |
\_| \_/ \___| \___/\_/  |_||_| |_| \__, (_)
                                    __/ |
   Gaming Builder                  |___/

"@
    Write-Host $banner -ForegroundColor Cyan
    Write-Host "  Windows 11 Gaming-Optimized Image Builder" -ForegroundColor White
    Write-Host "  Based on tiny11builder + Atlas OS optimizations" -ForegroundColor Gray
    Write-Host ""
}

# Check if running as admin
function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Download and extract repository
function Get-Repository {
    param(
        [string]$Owner,
        [string]$Repo,
        [string]$Branch,
        [string]$DestPath
    )

    Write-Host "[*] Downloading NeoTiny11 Builder..." -ForegroundColor Yellow

    $zipUrl = "https://github.com/$Owner/$Repo/archive/refs/heads/$Branch.zip"
    $zipPath = "$env:TEMP\neotiny11.zip"

    try {
        # Download
        Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath -UseBasicParsing

        # Clean previous install
        if (Test-Path $DestPath) {
            Remove-Item -Path $DestPath -Recurse -Force
        }

        # Extract
        Write-Host "[*] Extracting files..." -ForegroundColor Yellow
        Expand-Archive -Path $zipPath -DestinationPath $env:TEMP -Force

        # Rename folder
        $extractedFolder = "$env:TEMP\$Repo-$Branch"
        if (Test-Path $extractedFolder) {
            Rename-Item -Path $extractedFolder -NewName "NeoTiny11Builder" -Force
        }

        # Cleanup zip
        Remove-Item -Path $zipPath -Force

        Write-Host "[+] Download complete!" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "[!] Failed to download: $_" -ForegroundColor Red
        return $false
    }
}

# Main execution
Clear-Host
Show-Banner

# Check admin
if (-not (Test-Administrator)) {
    Write-Host "[!] This script requires Administrator privileges!" -ForegroundColor Red
    Write-Host "[*] Please run PowerShell as Administrator and try again." -ForegroundColor Yellow
    pause
    exit 1
}

Write-Host "[+] Running with Administrator privileges" -ForegroundColor Green
Write-Host ""

# Download repository
$downloaded = Get-Repository -Owner $RepoOwner -Repo $RepoName -Branch $Branch -DestPath $InstallPath

if ($downloaded -and (Test-Path "$InstallPath\scripts\Start-NeoTiny11.ps1")) {
    Write-Host ""
    Write-Host "[*] Starting NeoTiny11 Builder..." -ForegroundColor Cyan
    Write-Host ""

    # Execute main script
    Set-Location $InstallPath
    & "$InstallPath\scripts\Start-NeoTiny11.ps1"
}
else {
    Write-Host "[!] Installation failed. Please try again or download manually." -ForegroundColor Red
    Write-Host "[*] Manual download: https://github.com/$RepoOwner/$RepoName" -ForegroundColor Yellow
}
