# =============================================================================
# launcher-for-exe.ps1
# Este script es empaquetado por ps2exe para generar OptimizadorUniversal.exe
# Detecta su propia ruta (como .exe), localiza la carpeta 'modules' contigua,
# y delega la ejecucion a main.ps1 via powershell.exe con elevacion UAC.
#
# ESTRUCTURA REQUERIDA en la misma carpeta que el .exe:
#   OptimizadorUniversal.exe
#   modules\
#     Helper-Functions.ps1
#     Show-UserInterface.ps1
#     Get-SystemDiagnostics.ps1
#     ... (todos los modulos)
# =============================================================================

#Requires -Version 5.1

# ── Determinar ruta del .exe (o del .ps1 durante development) ─────────────────
# ps2exe expone $MyInvocation.MyCommand.Path como la ruta del .exe en ejecucion
$ExePath = if ($MyInvocation.MyCommand.Path) {
    $MyInvocation.MyCommand.Path
} else {
    [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
}
$ExeDir = Split-Path -Parent $ExePath

# ── Verificar que la carpeta modules existe junto al .exe ─────────────────────
$ModulesPath = Join-Path $ExeDir "modules"
$MainScript  = Join-Path $ExeDir "main.ps1"

if (-not (Test-Path $ModulesPath)) {
    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.MessageBox]::Show(
        "No se encontro la carpeta 'modules' junto al ejecutable.`n`n" +
        "Ruta buscada:`n$ModulesPath`n`n" +
        "Asegurate de que la carpeta 'modules\' este en la misma ubicacion que OptimizadorUniversal.exe",
        "Error - Optimizador Universal",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    ) | Out-Null
    exit 1
}

# ── Verificar main.ps1 ────────────────────────────────────────────────────────
if (-not (Test-Path $MainScript)) {
    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.MessageBox]::Show(
        "No se encontro main.ps1 junto al ejecutable.`n`n" +
        "Ruta buscada:`n$MainScript`n`n" +
        "El archivo main.ps1 debe estar en la misma carpeta que OptimizadorUniversal.exe",
        "Error - Optimizador Universal",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    ) | Out-Null
    exit 1
}

# ── Verificar si ya somos administrador ───────────────────────────────────────
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    # Solicitar elevacion UAC: relanzar powershell.exe con -Verb RunAs
    # (ps2exe ya puede pedir UAC via RequireAdmin=$true, pero esto es fallback)
    $psArgs = "-NoProfile -ExecutionPolicy Bypass -File `"$MainScript`""
    Start-Process -FilePath "powershell.exe" `
        -ArgumentList $psArgs `
        -Verb RunAs `
        -WorkingDirectory $ExeDir
    exit
}

# ── Lanzar main.ps1 directamente (ya somos admin) ────────────────────────────
# Configurar ventana de consola
$Host.UI.RawUI.WindowTitle = "Optimizador Universal de Notebooks"
try {
    $Host.UI.RawUI.BufferSize = New-Object System.Management.Automation.Host.Size(120, 3000)
    $Host.UI.RawUI.WindowSize = New-Object System.Management.Automation.Host.Size(100, 40)
} catch { }

# Punto de entrada principal
& $MainScript
