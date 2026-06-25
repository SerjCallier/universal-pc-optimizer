# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A PowerShell 5.1 diagnostic and optimization tool for Windows 10/11 notebooks. No internet, no install — requires admin rights (auto-elevates). Targets non-technical end users.

## How to run

```powershell
# From PowerShell as Administrator:
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\main.ps1            # GUI mode (WinForms wizard, default)
.\main.ps1 -Console   # Console mode (no GUI)
```

## How to build the .exe

```powershell
# Requires internet on first run (installs ps2exe from PSGallery)
.\_dev\Build-Exe.ps1
# Output: OptimizadorUniversal.exe at project root
```

## Architecture

`main.ps1` is the sole entry point. It auto-elevates, dot-sources all modules from `modules\`, then runs a linear 5-stage pipeline. Each stage can be skipped by the user.

**Global state** (defined in `Helper-Functions.ps1`, shared across all modules):
- `$Global:SystemData` — hashtable accumulating all collected data
- `$Global:HealthScore` — starts at 100, decremented by each module when issues are found
- `$Global:Findings` — list of hashtables with severity, description, and recommendation
- `$Global:TechLog` — raw technical log lines for the report
- `$Global:BeforeState` / `$Global:AfterState` — snapshots for before/after comparison

**Module load order** (matters — Helper-Functions must be first):
1. `Helper-Functions.ps1` — shared functions and global vars
2. `Show-UserInterface.ps1` — console UI (banners, prompts, `Confirm-ModuleSkip`)
3. `Get-SystemDiagnostics.ps1` — Stage 1: `Invoke-SystemDiagnostics`
4. `Invoke-SystemCleanup.ps1` — Stage 2: `Invoke-SystemCleanup`
5. `Get-AppAndPowerAnalysis.ps1` — Stage 3: `Invoke-AppAndPowerAnalysis`
6. `Get-BottleneckAnalysis.ps1` — Stage 4: `Invoke-BottleneckAnalysis`
7. `Write-SystemReport.ps1` — Stage 5: `Write-SystemReport`
8. `Show-WizardUI.ps1` — GUI only, loaded last via `Initialize-WizardUI`

**Dual-mode pattern:** Every stage checks `$Global:UI` to decide whether to write to the WinForms panel (`Add-UILog`, `Set-UIProgress`) or to the console (`Write-Color`, `Write-SectionHeader`). New stages must handle both paths.

**Output:** A folder `Reporte_OptimizacionPC_YYYYMMDD_HHMM` on the Desktop with 4 files: `resumen.txt`, `detalles_tecnicos.txt`, `recomendaciones.txt`, `captura_estado_sistema.txt`.

## Key constraints

- PowerShell 5.1 only — no PS7 syntax (`??`, `?.`, `&&`, `||` pipeline chains, ternary)
- All user-facing text in Spanish
- Every destructive action requires explicit `[S/N]` confirmation before executing
- `$Global:ScriptDir` holds the script root; use it (not `$PSScriptRoot`) when referencing paths from modules
