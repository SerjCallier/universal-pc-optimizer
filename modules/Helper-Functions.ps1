# =============================================================================
# Helper-Functions.ps1
# Funciones compartidas: salida en color, formateo, logs, elevaciOn admin
# =============================================================================

# ---------------------------------------------------------------------------
# Variables globales compartidas entre modulos
# ---------------------------------------------------------------------------
$Global:SystemData   = @{}          # Datos recopilados por cada modulo
$Global:TechLog      = [System.Collections.Generic.List[string]]::new()
$Global:Findings     = [System.Collections.Generic.List[hashtable]]::new()
$Global:HealthScore  = 100          # Comienza perfecto; modulos lo reducen
$Global:BeforeState  = @{}          # Instantanea antes de la limpieza
$Global:AfterState   = @{}          # Instantanea despues de la limpieza
$Global:UserProfile  = @{           # Perfil del usuario (Paso 0)
    TechLevel   = "Basico"
    PrimaryUse  = "General"
    MainConcern = "General"
}

# ---------------------------------------------------------------------------
# Write-Color : imprime texto con color sin perder el newline
# Uso: Write-Color "Mensaje" -Color Green
# ---------------------------------------------------------------------------
function Write-Color {
    param(
        [string]$Message,
        [ConsoleColor]$Color = [ConsoleColor]::White,
        [switch]$NoNewline
    )
    $prev = $Host.UI.RawUI.ForegroundColor
    $Host.UI.RawUI.ForegroundColor = $Color
    if ($NoNewline) { Write-Host $Message -NoNewline }
    else            { Write-Host $Message }
    $Host.UI.RawUI.ForegroundColor = $prev
}

# ---------------------------------------------------------------------------
# Format-Bytes : convierte bytes a cadena legible (KB / MB / GB)
# ---------------------------------------------------------------------------
function Format-Bytes {
    param([long]$Bytes)
    if ($Bytes -ge 1GB) { return "{0:N2} GB" -f ($Bytes / 1GB) }
    if ($Bytes -ge 1MB) { return "{0:N2} MB" -f ($Bytes / 1MB) }
    if ($Bytes -ge 1KB) { return "{0:N2} KB" -f ($Bytes / 1KB) }
    return "$Bytes B"
}

# ---------------------------------------------------------------------------
# Write-SectionHeader : linea divisoria con titulo
# ---------------------------------------------------------------------------
function Write-SectionHeader {
    param([string]$Title, [ConsoleColor]$Color = [ConsoleColor]::Cyan)
    Write-Host ""
    Write-Color ("=" * 70) -Color $Color
    Write-Color "  $Title" -Color $Color
    Write-Color ("=" * 70) -Color $Color
    Write-Host ""
}

# ---------------------------------------------------------------------------
# Write-StatusLine : linea tipo "[OK]  Descripcion"
# ---------------------------------------------------------------------------
function Write-StatusLine {
    param(
        [ValidateSet("OK","ADVERTENCIA","CRITICO","INFO")]
        [string]$Status,
        [string]$Message
    )
    $map = @{
        OK          = @{ Label = "[  OK  ]"; Color = [ConsoleColor]::Green  }
        ADVERTENCIA = @{ Label = "[AVISO ]"; Color = [ConsoleColor]::Yellow }
        CRITICO     = @{ Label = "[CRIT! ]"; Color = [ConsoleColor]::Red    }
        INFO        = @{ Label = "[ INFO ]"; Color = [ConsoleColor]::Cyan   }
    }
    $entry = $map[$Status]
    Write-Color $entry.Label -Color $entry.Color -NoNewline
    Write-Host "  $Message"
}

# ---------------------------------------------------------------------------
# Add-TechLog : agrega una linea al log tecnico global
# ---------------------------------------------------------------------------
function Add-TechLog {
    param([string]$Line)
    $ts = Get-Date -Format "HH:mm:ss"
    $Global:TechLog.Add("[$ts] $Line")
}

# ---------------------------------------------------------------------------
# Add-Finding : registra un hallazgo para el reporte final
# Severidad: Alto | Medio | Bajo
# ---------------------------------------------------------------------------
function Add-Finding {
    param(
        [string]$Category,
        [string]$Issue,
        [string]$Recommendation,
        [ValidateSet("Alto","Medio","Bajo")]
        [string]$Severity,
        [int]$ScorePenalty = 0
    )
    $Global:Findings.Add(@{
        Category       = $Category
        Issue          = $Issue
        Recommendation = $Recommendation
        Severity       = $Severity
        ScorePenalty   = $ScorePenalty
    })
    $Global:HealthScore -= $ScorePenalty
    if ($Global:HealthScore -lt 0) { $Global:HealthScore = 0 }
    Add-TechLog "Hallazgo [$Severity] en [$Category]: $Issue"
}

# ---------------------------------------------------------------------------
# Test-IsAdmin : devuelve $true si corre como administrador
# ---------------------------------------------------------------------------
function Test-IsAdmin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $p  = New-Object Security.Principal.WindowsPrincipal($id)
    return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# ---------------------------------------------------------------------------
# Start-AdminElevation : re-lanza el script con privilegios elevados
# ---------------------------------------------------------------------------
function Start-AdminElevation {
    param([string]$ScriptPath)
    Write-Color "`n  Solicitando permisos de administrador..." -Color Yellow
    Start-Process -FilePath "powershell.exe" `
        -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath`"" `
        -Verb RunAs
    exit
}

# ---------------------------------------------------------------------------
# Get-UserConfirmation : prompt Si/No adaptado a GUI o consola
# En modo GUI usa MessageBox; en consola usa Read-Host
# ---------------------------------------------------------------------------
function Get-UserConfirmation {
    param(
        [string]$Prompt,
        [string]$Title = "Confirmacion"
    )
    if ($Global:UI -and $Global:UI.Form) {
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue
        $result = [System.Windows.Forms.MessageBox]::Show(
            $Prompt, $Title,
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Question
        )
        return ($result -eq [System.Windows.Forms.DialogResult]::Yes)
    } else {
        $resp = Read-Host "`n  $Prompt [S/N]"
        return ($resp -notmatch '^[Nn]')
    }
}

# ---------------------------------------------------------------------------
# Get-FolderSize : calcula el tamano total de una carpeta en bytes
# ---------------------------------------------------------------------------
function Get-FolderSize {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return 0 }
    try {
        $size = (Get-ChildItem -Path $Path -Recurse -Force -ErrorAction SilentlyContinue |
                 Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
        return [long](if ($null -ne $size) { $size } else { 0 })
    } catch { return 0 }
}

# ---------------------------------------------------------------------------
# Get-LocalGateway : obtiene la IP del gateway predeterminado
# ---------------------------------------------------------------------------
function Get-LocalGateway {
    try {
        $gw = (Get-NetRoute -DestinationPrefix "0.0.0.0/0" -ErrorAction Stop |
               Sort-Object RouteMetric | Select-Object -First 1).NextHop
        return $gw
    } catch { return $null }
}

Write-Color "  [Helper-Functions] Cargado correctamente." -Color DarkGray
