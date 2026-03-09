# =============================================================================
# main.ps1  -  Punto de entrada del Optimizador Universal de Notebooks
# Uso: .\main.ps1           -> modo GUI (wizard WinForms)
#      .\main.ps1 -Console  -> modo consola (comportamiento clasico)
# Compatible con PowerShell 5.1 / Windows 10 y 11
# =============================================================================

#Requires -Version 5.1

param(
    [switch]$Console    # Fuerza el modo consola sin GUI
)

# ── Capturar la ruta absoluta del script ANTES de cualquier otra accion ───────
$ScriptFullPath = if ($PSCommandPath) {
    $PSCommandPath
} elseif ($MyInvocation.MyCommand.Path) {
    $MyInvocation.MyCommand.Path
} else {
    Join-Path (Get-Location).Path "main.ps1"
}
$ScriptDir = Split-Path -Parent $ScriptFullPath

# ── Manejador global de errores: pausa antes de cerrar en cualquier excepcion ─
trap {
    Write-Host ""
    Write-Host "  ERROR INESPERADO: $_" -ForegroundColor Red
    Write-Host "  $($_.ScriptStackTrace)" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  Presiona ENTER para cerrar esta ventana..." -ForegroundColor Yellow
    Read-Host | Out-Null
    exit 1
}

# ── Auto-elevacion de privilegios ─────────────────────────────────────────────
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host ""
    Write-Host "  Este programa necesita permisos de administrador." -ForegroundColor Yellow
    Write-Host "  Se abrira una nueva ventana solicitando confirmacion..." -ForegroundColor Yellow
    Write-Host ""
    Start-Sleep -Seconds 1
    # Preservar el flag -Console en la re-elevacion
    $consoleFlag = if ($Console) { " -Console" } else { "" }
    Start-Process -FilePath "powershell.exe" `
        -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$ScriptFullPath`"$consoleFlag" `
        -Verb RunAs `
        -WorkingDirectory $ScriptDir
    exit
}

# ── Configurar consola ────────────────────────────────────────────────────────
$Host.UI.RawUI.WindowTitle = "Optimizador Universal de Notebooks"
try {
    $Host.UI.RawUI.BufferSize = New-Object System.Management.Automation.Host.Size(120, 3000)
    $Host.UI.RawUI.WindowSize = New-Object System.Management.Automation.Host.Size(100, 40)
} catch { }

# ── Cargar modulos ────────────────────────────────────────────────────────────
$ModulesPath = Join-Path $ScriptDir "modules"

if (-not (Test-Path $ModulesPath)) {
    Write-Host ""
    Write-Host "  ERROR: No se encontro la carpeta 'modules'." -ForegroundColor Red
    Write-Host "  Ruta buscada: $ModulesPath" -ForegroundColor DarkGray
    Write-Host "  Presiona ENTER para cerrar..." -ForegroundColor Yellow
    Read-Host | Out-Null
    exit 1
}

# Modulos base (siempre se cargan primero)
$baseModules = @(
    "Helper-Functions.ps1",
    "Show-UserInterface.ps1",
    "Get-SystemDiagnostics.ps1",
    "Invoke-SystemCleanup.ps1",
    "Get-AppAndPowerAnalysis.ps1",
    "Get-BottleneckAnalysis.ps1",
    "Write-SystemReport.ps1"
)

foreach ($f in $baseModules) {
    $fullPath = Join-Path $ModulesPath $f
    if (Test-Path $fullPath) {
        try {
            . $fullPath
        } catch {
            Write-Host ""
            Write-Host "  ERROR cargando modulo '$f':" -ForegroundColor Red
            Write-Host "  $_" -ForegroundColor Red
            Write-Host "  Presiona ENTER para cerrar..." -ForegroundColor Yellow
            Read-Host | Out-Null
            exit 1
        }
    } else {
        Write-Host "  ERROR: No se encontro el modulo: $f" -ForegroundColor Red
        Read-Host | Out-Null
        exit 1
    }
}

# ── Cargar y lanzar wizard GUI (si no se usa -Console) ────────────────────────
if (-not $Console) {
    $wizardPath = Join-Path $ModulesPath "Show-WizardUI.ps1"
    if (Test-Path $wizardPath) {
        try {
            . $wizardPath
        } catch {
            Write-Host "  Advertencia: No se pudo cargar la GUI ($_ ). Continuando en modo consola." -ForegroundColor Yellow
            $Console = $true
        }
    } else {
        Write-Host "  Advertencia: Show-WizardUI.ps1 no encontrado. Continuando en modo consola." -ForegroundColor Yellow
        $Console = $true
    }

    if (-not $Console) {
        try {
            Initialize-WizardUI
        } catch {
            Write-Host "  Advertencia: No se pudo inicializar la GUI ($_). Continuando en modo consola." -ForegroundColor Yellow
            $Console = $true
        }
    }
}

# ── Pantalla de bienvenida ────────────────────────────────────────────────────
if ($Global:UI -and -not $Global:UI.Form.IsDisposed) {
    # GUI: mostrar mensaje de bienvenida y esperar click
    Set-UIStep  -StepIndex 0
    Set-UITitle -Title "Bienvenido al Optimizador Universal" `
                -Desc  "Diagnostico y optimizacion de notebooks Windows 10/11"
    Set-UIProgress -Percent 0 -StatusText "Listo para comenzar."
    Add-UILog "Bienvenido! Este programa realizara las siguientes etapas:" ([System.Drawing.Color]::FromArgb(80, 195, 225))
    Add-UILog "  1. Diagnostico del sistema (CPU, RAM, disco, bateria, WiFi)" ([System.Drawing.Color]::FromArgb(160, 180, 200))
    Add-UILog "  2. Limpieza de archivos temporales y cache" ([System.Drawing.Color]::FromArgb(160, 180, 200))
    Add-UILog "  3. Revision de aplicaciones y plan de energia" ([System.Drawing.Color]::FromArgb(160, 180, 200))
    Add-UILog "  4. Identificacion de cuellos de botella" ([System.Drawing.Color]::FromArgb(160, 180, 200))
    Add-UILog "  5. Reporte final con recomendaciones en tu Escritorio" ([System.Drawing.Color]::FromArgb(160, 180, 200))
    Add-UILog "" ([System.Drawing.Color]::White)
    Add-UILog "Presiona 'Siguiente' para comenzar." ([System.Drawing.Color]::FromArgb(80, 195, 225))
    Wait-UINext -Label "Comenzar >>"
} else {
    Show-WelcomeBanner
}

# ── Etapa 1: Diagnostico ──────────────────────────────────────────────────────
$runDiag = Confirm-ModuleSkip `
    -ModuleName  "Diagnostico del Sistema (Etapa 1/5)" `
    -Description "Revisaremos CPU, RAM, disco, bateria y WiFi. Solo lectura, sin cambios."
if ($runDiag) { Invoke-SystemDiagnostics }
if ($Global:UI -and -not $Global:UI.Form.IsDisposed) { Wait-UINext }

# ── Etapa 2: Limpieza ─────────────────────────────────────────────────────────
$runClean = Confirm-ModuleSkip `
    -ModuleName  "Limpieza de Archivos (Etapa 2/5)" `
    -Description "Archivos temporales, caches de navegadores, papelera, logs antiguos."
if ($runClean) { Invoke-SystemCleanup }
if ($Global:UI -and -not $Global:UI.Form.IsDisposed) { Wait-UINext }

# ── Etapa 3: Aplicaciones y energia ───────────────────────────────────────────
$runApps = Confirm-ModuleSkip `
    -ModuleName  "Aplicaciones y Plan de Energia (Etapa 3/5)" `
    -Description "Programas de inicio, software no deseado y plan de energia."
if ($runApps) { Invoke-AppAndPowerAnalysis }
if ($Global:UI -and -not $Global:UI.Form.IsDisposed) { Wait-UINext }

# ── Etapa 4: Cuellos de botella ───────────────────────────────────────────────
$runBottleneck = Confirm-ModuleSkip `
    -ModuleName  "Cuellos de Botella (Etapa 4/5)" `
    -Description "Identificaremos que componente limita mas el rendimiento."
if ($runBottleneck) { Invoke-BottleneckAnalysis }
if ($Global:UI -and -not $Global:UI.Form.IsDisposed) { Wait-UINext }

# ── Etapa 5: Reporte final ────────────────────────────────────────────────────
if ($Global:UI -and -not $Global:UI.Form.IsDisposed) {
    Set-UIStep  -StepIndex 5
    Set-UITitle -Title "Etapa 5/5: Generando Reporte Final" -Desc "Calculando puntaje y guardando resultados..."
}
Write-SystemReport

# ── Cierre ────────────────────────────────────────────────────────────────────
Show-ClosingMessage -ReportFolder $Global:SystemData.ReportFolder
