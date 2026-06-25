# =============================================================================
# Build-Exe.ps1  -  Empaqueta el Optimizador Universal en un .exe de un click
# Uso: ejecutar desde PowerShell (doble click o desde VS Code)
# Ubicacion: _dev\Build-Exe.ps1
# Requiere conexion a internet la primera vez (instala ps2exe desde PSGallery)
# =============================================================================

#Requires -Version 5.1

$ErrorActionPreference = "Stop"
$DevDir     = Split-Path -Parent $MyInvocation.MyCommand.Path   # carpeta _dev
$RootDir    = Split-Path -Parent $DevDir                        # raiz del proyecto
$LauncherPs = Join-Path $DevDir  "launcher-for-exe.ps1"         # input para ps2exe
$OutputExe  = Join-Path $RootDir "OptimizadorUniversal.exe"     # sale a la raiz
$IconPath   = Join-Path $DevDir  "icon.ico"   # opcional – se ignora si no existe

Write-Host ""
Write-Host "  =============================================================" -ForegroundColor Cyan
Write-Host "         BUILD: Optimizador Universal  ->  .exe" -ForegroundColor Cyan
Write-Host "  =============================================================" -ForegroundColor Cyan
Write-Host ""

# ── 1. Instalar ps2exe si no esta disponible ──────────────────────────────────
if (-not (Get-Command ps2exe -ErrorAction SilentlyContinue)) {
    Write-Host "  [1/3] Instalando ps2exe desde PSGallery..." -ForegroundColor Yellow
    try {
        Install-Module -Name ps2exe -Scope CurrentUser -Force -AllowClobber
        Import-Module ps2exe -Force
        Write-Host "        ps2exe instalado correctamente." -ForegroundColor Green
    } catch {
        Write-Host ""
        Write-Host "  ERROR: No se pudo instalar ps2exe." -ForegroundColor Red
        Write-Host "  $_" -ForegroundColor Red
        Write-Host ""
        Write-Host "  Intenta correr este comando manualmente:" -ForegroundColor Yellow
        Write-Host "    Install-Module -Name ps2exe -Scope CurrentUser -Force" -ForegroundColor White
        Write-Host ""
        Read-Host "  Presiona ENTER para cerrar..."
        exit 1
    }
} else {
    Write-Host "  [1/3] ps2exe ya disponible. OK." -ForegroundColor Green
}

# ── 2. Verificar que el launcher existe ───────────────────────────────────────
Write-Host "  [2/3] Verificando launcher-for-exe.ps1..." -ForegroundColor Yellow
if (-not (Test-Path $LauncherPs)) {
    Write-Host "  ERROR: No se encontro launcher-for-exe.ps1 en:" -ForegroundColor Red
    Write-Host "         $LauncherPs" -ForegroundColor DarkGray
    Read-Host "  Presiona ENTER para cerrar..."
    exit 1
}
Write-Host "        Encontrado. OK." -ForegroundColor Green

# ── 3. Compilar con ps2exe ────────────────────────────────────────────────────
Write-Host "  [3/3] Compilando .exe con ps2exe..." -ForegroundColor Yellow
Write-Host "        Entrada : $LauncherPs" -ForegroundColor DarkGray
Write-Host "        Salida  : $OutputExe"  -ForegroundColor DarkGray
Write-Host ""

$ps2exeParams = @{
    InputFile       = $LauncherPs
    OutputFile      = $OutputExe
    Title           = "Optimizador Universal de Notebooks"
    Description     = "Diagnostico y optimizacion de notebooks Windows 10/11"
    Company         = ""
    Product         = "Optimizador Universal"
    Version         = "1.0.0.0"
    RequireAdmin    = $true          # solicita UAC automaticamente
    NoConsole       = $false         # mantiene consola (la GUI abre sobre ella)
    NoOutput        = $false
    NoError         = $false
    Verbose         = $false
    x64             = $false         # compatible con 32 y 64 bits
}

# Agregar icono solo si existe
if (Test-Path $IconPath) {
    $ps2exeParams["IconFile"] = $IconPath
    Write-Host "        Icono   : $IconPath" -ForegroundColor DarkGray
}

try {
    ps2exe @ps2exeParams
} catch {
    Write-Host ""
    Write-Host "  ERROR compilando:" -ForegroundColor Red
    Write-Host "  $_" -ForegroundColor Red
    Write-Host ""
    Read-Host "  Presiona ENTER para cerrar..."
    exit 1
}

# ── Resultado ─────────────────────────────────────────────────────────────────
Write-Host ""
if (Test-Path $OutputExe) {
    $sizeMB = [Math]::Round((Get-Item $OutputExe).Length / 1MB, 2)
    Write-Host "  BUILD EXITOSO!" -ForegroundColor Green
    Write-Host "  Ejecutable generado : $OutputExe" -ForegroundColor Cyan
    Write-Host "  Tamanio             : $sizeMB MB" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  Para distribuir, comprime en .rar:" -ForegroundColor Yellow
    Write-Host "    OptimizadorUniversal.exe" -ForegroundColor White
    Write-Host "    main.ps1" -ForegroundColor White
    Write-Host "    modules\" -ForegroundColor White
    Write-Host "  (NO incluir la carpeta _dev\)" -ForegroundColor DarkGray
} else {
    Write-Host "  ERROR: El archivo .exe no fue creado." -ForegroundColor Red
}

Write-Host ""
Read-Host "  Presiona ENTER para cerrar..."
