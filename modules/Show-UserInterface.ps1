# =============================================================================
# Show-UserInterface.ps1  -  Modulo 6: UX y Dialogos para usuarios no tecnicos
# Guardado con UTF-8 BOM para compatibilidad con PowerShell 5.1
# =============================================================================

# ---------------------------------------------------------------------------
# Show-WelcomeBanner : Pantalla de bienvenida con recomendacion de backup
# ---------------------------------------------------------------------------
function Show-WelcomeBanner {
    Clear-Host
    $banner = @"

  +======================================================================+
  |                                                                      |
  |        OPTIMIZADOR UNIVERSAL DE NOTEBOOKS  -  Windows 10/11         |
  |                    Diagnostico y Optimizacion                        |
  |                                                                      |
  +======================================================================+
"@
    Write-Color $banner -Color Cyan

    Write-Host ""
    Write-Color "  Este programa va a:" -Color White
    Write-Color "    1.  Revisar el estado de tu computadora (CPU, memoria, disco, bateria)" -Color Gray
    Write-Color "    2.  Limpiar archivos innecesarios de forma segura" -Color Gray
    Write-Color "    3.  Identificar que esta haciendo lenta tu computadora" -Color Gray
    Write-Color "    4.  Darte recomendaciones claras de que hacer a continuacion" -Color Gray
    Write-Host ""

    Write-Color "  ---------------------------------------------------------------------" -Color DarkGray
    Write-Color ""
    Write-Color "  RECOMENDACION ANTES DE CONTINUAR:" -Color Yellow
    Write-Color ""
    Write-Color "     Si tenes archivos importantes sin guardar (documentos, fotos, etc.)," -Color White
    Write-Color "     guardalos ahora. Si podes, haz una copia de seguridad antes de seguir." -Color White
    Write-Host ""
    Write-Color "     Este programa NO borra archivos del sistema ni tus datos personales." -Color Green
    Write-Color "     Cualquier limpieza te pedira confirmacion antes de ejecutarse." -Color Green
    Write-Color ""
    Write-Color "  ---------------------------------------------------------------------" -Color DarkGray
    Write-Host ""

    Write-Color "  Presiona ENTER para comenzar..." -Color Cyan
    Read-Host | Out-Null
}

# ---------------------------------------------------------------------------
# Show-StageIntro : Pantalla de introduccion para cada etapa
# ---------------------------------------------------------------------------
function Show-StageIntro {
    param(
        [int]$StageNum,
        [int]$TotalStages = 6,
        [string]$Title,
        [string]$Duration,
        [string]$Instructions,
        [string]$WhatItDoes
    )
    Write-Host ""
    Write-Color ("  +-- ETAPA {0}/{1}: {2}" -f $StageNum, $TotalStages, $Title.ToUpper()) -Color Cyan
    Write-Color "  +------------------------------------------------------------------+" -Color Cyan
    Write-Host ""
    Write-Color "  QUE VA A HACER:" -Color White
    Write-Color "     $WhatItDoes" -Color Gray
    Write-Host ""
    Write-Color "  TIEMPO ESTIMADO:" -Color White
    Write-Color "     $Duration" -Color Gray
    Write-Host ""
    Write-Color "  QUE NECESITAS HACER:" -Color White
    Write-Color "     $Instructions" -Color Gray
    Write-Host ""
}

# ---------------------------------------------------------------------------
# Show-ProgressStep : barra de progreso visual dentro de una etapa
# ---------------------------------------------------------------------------
function Show-ProgressStep {
    param(
        [int]$Current,
        [int]$Total,
        [string]$Label
    )
    $filled  = [Math]::Round(($Current / $Total) * 20)
    $empty   = 20 - $filled
    $bar     = "#" * $filled + "-" * $empty
    $percent = [Math]::Round(($Current / $Total) * 100)
    Write-Color ("  [{0}] {1,3}%  {2}" -f $bar, $percent, $Label) -Color Cyan
}

# ---------------------------------------------------------------------------
# Confirm-ModuleSkip : pregunta si el usuario quiere ejecutar la etapa
# ---------------------------------------------------------------------------
function Confirm-ModuleSkip {
    param(
        [string]$ModuleName,
        [string]$Description = ""
    )
    Write-Host ""
    if ($Description) {
        Write-Color "  $Description" -Color Gray
        Write-Host ""
    }
    Write-Color "  Deseas ejecutar: $ModuleName?" -Color White
    Write-Color "  [S] Si, ejecutar    [N] No, saltar esta etapa" -Color DarkGray
    Write-Host ""
    $resp = Read-Host "  Tu respuesta"
    if ($resp -match '^[Nn]') {
        Write-Color "  OK. Saltando esta etapa." -Color Yellow
        Add-TechLog "Etapa saltada por el usuario: $ModuleName"
        return $false
    }
    return $true
}

# ---------------------------------------------------------------------------
# Show-RiskWarning : advertencia previa a una accion de limpieza
# ---------------------------------------------------------------------------
function Show-RiskWarning {
    param(
        [string]$WhatIsIt,
        [string]$WhyItsSafe,
        [string]$PathsAffected = ""
    )
    Write-Host ""
    Write-Color "  ANTES DE CONTINUAR:" -Color Yellow
    Write-Color "  -------------------------------------------------------------------" -Color DarkGray
    Write-Color "  $WhatIsIt" -Color White
    Write-Host ""
    if ($PathsAffected) {
        Write-Color "  Carpetas/archivos que se van a revisar:" -Color Gray
        foreach ($p in ($PathsAffected -split "`n")) {
            Write-Color "     $p" -Color DarkCyan
        }
        Write-Host ""
    }
    Write-Color "  $WhyItsSafe" -Color Green
    Write-Color "  -------------------------------------------------------------------" -Color DarkGray
    Write-Host ""
}

# ---------------------------------------------------------------------------
# Show-HighRiskWarning : advertencia extra para acciones con mayor riesgo
# ---------------------------------------------------------------------------
function Show-HighRiskWarning {
    param(
        [string]$FileOrFolder,
        [string]$WhatIsIt,
        [string]$ConsequenceIfDeleted,
        [string]$Recommendation
    )
    Write-Host ""
    Write-Color "  +==============================================================+" -Color Red
    Write-Color "  |  ACCION DE MAYOR RIESGO -- Leer antes de continuar          |" -Color Red
    Write-Color "  +==============================================================+" -Color Red
    Write-Host ""
    Write-Color "  Archivo/carpeta: $FileOrFolder" -Color White
    Write-Host ""
    Write-Color "  QUE ES?  $WhatIsIt" -Color Gray
    Write-Host ""
    Write-Color "  QUE PASA SI SE ELIMINA?  $ConsequenceIfDeleted" -Color Yellow
    Write-Host ""
    Write-Color "  RECOMENDACION:  $Recommendation" -Color Cyan
    Write-Host ""
}

# ---------------------------------------------------------------------------
# Show-MiniSummary : muestra resumen en lenguaje cotidiano al cerrar un modulo
# ---------------------------------------------------------------------------
function Show-MiniSummary {
    param(
        [string]$ModuleName,
        [string[]]$GoodNews,
        [string[]]$Concerns
    )
    Write-Host ""
    Write-Color "  === RESUMEN DE ETAPA: $ModuleName ===" -Color Cyan
    Write-Color "  -------------------------------------------------------------------" -Color DarkGray
    if ($GoodNews) {
        foreach ($line in $GoodNews) { Write-Color "  [OK] $line" -Color Green }
    }
    if ($Concerns) {
        foreach ($line in $Concerns) { Write-Color "  [!]  $line" -Color Yellow }
    }
    Write-Color "  -------------------------------------------------------------------" -Color DarkGray
    Write-Host ""
}

# ---------------------------------------------------------------------------
# Show-DismWarning : aviso especifico antes de ejecutar DISM
# Devuelve $true si el usuario confirma, $false si salta
# ---------------------------------------------------------------------------
function Show-DismWarning {
    Write-Host ""
    Write-Color "  +==============================================================+" -Color Cyan
    Write-Color "  |  LIMPIEZA DE ARCHIVOS DE ACTUALIZACION DE WINDOWS           |" -Color Cyan
    Write-Color "  +==============================================================+" -Color Cyan
    Write-Host ""
    Write-Color "  IMPORTANTE: Esta etapa puede tardar entre 10 y 30 minutos." -Color Yellow
    Write-Color "  La pantalla puede parecer inactiva -- esto es completamente normal." -Color Yellow
    Write-Color "  NO cierres esta ventana aunque parezca que nada esta pasando." -Color Yellow
    Write-Color "  NO presiones Ctrl+C o interrumpiras el proceso a mitad." -Color Red
    Write-Host ""
    Write-Color "  Windows limpiara archivos de actualizaciones antiguas" -Color White
    Write-Color "  que ya no necesita. Esto puede liberar varios GB de espacio." -Color White
    Write-Host ""
    Write-Color "  Presiona ENTER para comenzar (o escribe N+ENTER para saltar)..." -Color Cyan
    $r = Read-Host "  Tu respuesta"
    if ($r -match '^[Nn]') { return $false }
    return $true
}

# ---------------------------------------------------------------------------
# Show-DismProgress : muestra puntos de progreso mientras DISM corre
# Se ejecuta con Start-Job / polling para no bloquear la UI
# ---------------------------------------------------------------------------
function Invoke-DismWithProgress {
    Write-Color "  Ejecutando limpieza... (puede tardar varios minutos)" -Color Cyan
    Write-Host ""

    # Lanzar DISM como job en background
    $job = Start-Job -ScriptBlock {
        & dism /Online /Cleanup-Image /StartComponentCleanup 2>&1
    }

    $frames  = @('|', '/', '-', '\')
    $i       = 0
    $elapsed = 0

    while ($job.State -eq 'Running') {
        $mins = [Math]::Floor($elapsed / 60)
        $secs = $elapsed % 60
        $frame = $frames[$i % 4]
        Write-Host ("`r  {0}  Procesando... {1:00}:{2:00} transcurridos   " -f $frame, $mins, $secs) -NoNewline -ForegroundColor Cyan
        Start-Sleep -Seconds 1
        $elapsed++
        $i++
    }

    # Limpiar la linea del spinner
    Write-Host "`r                                                        " -NoNewline
    Write-Host ""

    $output = Receive-Job $job -ErrorAction SilentlyContinue
    Remove-Job $job -ErrorAction SilentlyContinue

    $mins = [Math]::Floor($elapsed / 60)
    Write-Color ("  Limpieza completada en {0} minuto(s)." -f $mins) -Color Green
    Add-TechLog "DISM completado en $elapsed segundos. Ultima linea: $($output[-1])"
    return $output
}

# ---------------------------------------------------------------------------
# Show-ClosingMessage : mensaje final de tranquilidad
# ---------------------------------------------------------------------------
function Show-ClosingMessage {
    param([string]$ReportFolder)
    Write-Host ""
    Write-Color "  +====================================================================+" -Color Green
    Write-Color "  |                                                                    |" -Color Green
    Write-Color "  |  LISTO! Tu notebook fue analizada y optimizada.                   |" -Color Green
    Write-Color "  |                                                                    |" -Color Green
    Write-Color "  |  Encontraras un resumen de todo lo que hicimos en tu Escritorio.  |" -Color Green
    Write-Color "  |  No se elimino ningun archivo importante.                         |" -Color Green
    Write-Color "  |                                                                    |" -Color Green
    Write-Color "  +====================================================================+" -Color Green
    Write-Host ""
    if ($ReportFolder) {
        Write-Color "  Carpeta de resultados:" -Color Cyan
        Write-Color "     $ReportFolder" -Color White
    }
    Write-Host ""
    Write-Color "  Presiona ENTER para cerrar..." -Color DarkGray
    Read-Host | Out-Null
}

Write-Color "  [Show-UserInterface] Cargado correctamente." -Color DarkGray
