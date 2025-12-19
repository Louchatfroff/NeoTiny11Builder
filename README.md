# NeoTiny11 Gaming Builder

A modular PowerShell-based Windows 11 image builder optimized for gaming performance. Combines the lightweight approach of [tiny11builder](https://github.com/ntdevlabs/tiny11builder) with gaming optimizations inspired by [Atlas OS](https://github.com/Atlas-OS/Atlas).

## Features

- **No ISO Mounting Required**: Simply extract the ISO and point to the folder
- **Gaming Optimizations**: CPU mitigations, timer resolution, GPU scheduling tweaks
- **Bloatware Removal**: Removes 50+ unnecessary Windows apps
- **Service Optimization**: Disables unnecessary services for better performance
- **Privacy Focused**: Disables telemetry, advertising, and data collection
- **Modular Scripts**: Easy to understand, modify, and maintain
- **One-Line Install**: Execute directly from the web via PowerShell

## Quick Start

### Option 1: One-Line Web Install

```powershell
irm https://neotiny11.vercel.app/install | iex
```

### Option 2: Clone and Run

```powershell
git clone https://github.com/Louchatfroff/NeoTiny11Builder.git
cd NeoTiny11Builder
.\public\scripts\Start-NeoTiny11.ps1
```

## Requirements

- Windows 10/11 (64-bit)
- PowerShell 5.1 or higher
- Administrator privileges
- Windows 11 ISO (extracted to a folder)
- ~15GB free disk space

## How to Use

1. **Download Windows 11 ISO** from Microsoft
2. **Extract the ISO** using 7-Zip, WinRAR, or similar tool
3. **Run the builder** using one of the methods above
4. **Select the extracted ISO folder** when prompted
5. **Choose Windows edition** (Pro recommended for gaming)
6. **Wait for build completion** (~10-20 minutes)
7. **Find your optimized ISO** in the output folder

## Scripts Overview

| Script | Purpose |
|--------|---------|
| `Start-NeoTiny11.ps1` | Main entry point and orchestrator |
| `Remove-Bloatware.ps1` | Removes unnecessary Windows apps |
| `Set-GamingOptimizations.ps1` | Applies gaming-specific tweaks |
| `Set-ServiceOptimizations.ps1` | Optimizes Windows services |
| `Set-RegistryTweaks.ps1` | Applies registry modifications |
| `Build-ISO.ps1` | Creates the final bootable ISO |

## Gaming Optimizations Applied

### CPU & Power
- Disable CPU mitigations (Spectre/Meltdown) for performance
- High performance power plan
- Disable core parking
- Processor scheduling optimized for programs

### GPU & Display
- Hardware-accelerated GPU scheduling
- Disable fullscreen optimizations
- Game Mode enabled
- Variable refresh rate support

### Network
- Nagle's algorithm disabled
- Network throttling disabled
- TCP optimizations for gaming

### Input
- Keyboard/mouse latency optimizations
- USB polling rate improvements
- Raw input enabled

### System
- Disable background apps
- Disable Game DVR/Game Bar recording overhead
- Memory management optimizations
- SysMain (Superfetch) configurable

## Removed Applications

<details>
<summary>Click to see full list</summary>

- Microsoft Edge
- OneDrive
- Xbox apps (except core gaming services)
- Mail and Calendar
- Microsoft Teams
- Cortana
- News, Weather, Maps
- Solitaire Collection
- Clipchamp
- Microsoft 365 hub
- Get Help, Tips
- And 40+ more...

</details>

## Configuration

Edit `config\settings.json` to customize:

```json
{
  "RemoveEdge": true,
  "RemoveOneDrive": true,
  "DisableTelemetry": true,
  "DisableDefender": false,
  "GamingMode": true,
  "DisableCpuMitigations": true
}
```

## Vercel Deployment

This project includes Vercel configuration for web hosting:

1. Fork this repository
2. Connect to Vercel
3. Deploy automatically
4. Access via `irm https://your-domain.vercel.app/install | iex`

## Safety Notes

- Always test on a virtual machine first
- Keep your original ISO as backup
- Some tweaks (CPU mitigations) trade security for performance
- Windows Defender remains functional by default

## Credits

- [tiny11builder](https://github.com/ntdevlabs/tiny11builder) - Original lightweight Windows builder
- [Atlas OS](https://github.com/Atlas-OS/Atlas) - Gaming optimization inspiration
- Community contributors

## License

MIT License - See [LICENSE](LICENSE) for details

## Disclaimer

This tool modifies Windows installation images. Use at your own risk. Not affiliated with Microsoft.
