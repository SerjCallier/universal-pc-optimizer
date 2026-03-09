# =============================================================================
# Write-SystemReport.ps1  ?  Modulo 5: Puntaje de Salud, Reporte y Archivos
# Totalmente compatible con PowerShell 5.1 (sin ?. ni ??)
# =============================================================================

# ---------------------------------------------------------------------------
# Get-Safe : acceso seguro a una clave de un hashtable ($null si no existe)
# Compatible con PowerShell 5.1 (reemplaza el operador ?.)
# ---------------------------------------------------------------------------
function Get-Safe {
    param($Hashtable, [string]$Key, $Default = $null)
    if ($Hashtable -and $Hashtable.ContainsKey($Key) -and ($null -ne $Hashtable[$Key])) {
        return $Hashtable[$Key]
    }
    return $Default
}

function Write-SystemReport {

    Show-StageIntro -StageNum 5 -TotalStages 6 `
        -Title "Generando Reporte Final" `
        -Duration "Menos de 1 minuto" `
        -WhatItDoes "Vamos a calcular el puntaje de salud de tu notebook y crear una carpeta en tu Escritorio con todos los resultados del analisis." `
        -Instructions "Solo espera. En breve tendra todos los reportes listos."

    # -- 5.1  Snapshot AfterState ----------------------------------------------
    Show-ProgressStep -Current 1 -Total 5 -Label "Tomando instantanea del estado actual..."

    $afterProcs = (Get-Process -ErrorAction SilentlyContinue | Measure-Object).Count
    $afterOS    = Get-WmiObject Win32_OperatingSystem -ErrorAction SilentlyContinue
    $afterRamFreeMB = 0
    if ($afterOS) { $afterRamFreeMB = [Math]::Round($afterOS.FreePhysicalMemory / 1KB, 0) }

    $Global:AfterState.ProcessCount  = $afterProcs
    $Global:AfterState.RamFreeMB     = $afterRamFreeMB
    if (-not $Global:AfterState.RamUsedPct) {
        $diagSnap = $Global:SystemData.Diagnostics
        if ($diagSnap) { $Global:AfterState.RamUsedPct = Get-Safe $diagSnap 'RamUsedPct' }
    }

    # -- 5.2  Calcular puntaje de salud ----------------------------------------
    Show-ProgressStep -Current 2 -Total 5 -Label "Calculando puntaje de salud..."

    $healthScore = [Math]::Max(0, [Math]::Min(100, $Global:HealthScore))

    $healthLabel = "Regular"
    if     ($healthScore -ge 85) { $healthLabel = "Excelente" }
    elseif ($healthScore -ge 70) { $healthLabel = "Bueno"     }
    elseif ($healthScore -ge 50) { $healthLabel = "Regular"   }
    elseif ($healthScore -ge 30) { $healthLabel = "Malo"      }
    else                         { $healthLabel = "Critico"   }

    $healthColor = [ConsoleColor]::Yellow
    if ($healthLabel -in @("Excelente","Bueno")) { $healthColor = [ConsoleColor]::Green }
    if ($healthLabel -in @("Malo","Critico"))    { $healthColor = [ConsoleColor]::Red   }

    # -- 5.3  Mostrar resumen ejecutivo en consola -----------------------------
    Show-ProgressStep -Current 3 -Total 5 -Label "Mostrando resumen en consola..."

    Write-SectionHeader "RESULTADO FINAL ? SALUD DE TU NOTEBOOK" -Color $healthColor
    Write-Host ""
    Write-Color ("  PUNTAJE DE SALUD DEL SISTEMA: {0}/100 ? {1}" -f $healthScore, $healthLabel.ToUpper()) -Color $healthColor
    Write-Host ""

    $bars  = [Math]::Round($healthScore / 5)
    $empty = 20 - $bars
    $bar   = ("#" * $bars) + ("." * $empty)
    Write-Color "  [$bar] $healthScore pts" -Color $healthColor
    Write-Host ""

    $high   = @($Global:Findings | Where-Object { $_.Severity -eq "Alto"  })
    $medium = @($Global:Findings | Where-Object { $_.Severity -eq "Medio" })
    $low    = @($Global:Findings | Where-Object { $_.Severity -eq "Bajo"  })

    if ($high.Count -gt 0) {
        Write-SectionHeader "PROBLEMAS CRITICOS (requieren atencion inmediata)" -Color Red
        foreach ($f in $high) {
            Write-Color "  X [$($f.Category)] $($f.Issue)" -Color Red
            Write-Color "     -> $($f.Recommendation)" -Color White
            Write-Host ""
        }
    }

    if ($medium.Count -gt 0) {
        Write-SectionHeader "ADVERTENCIAS (recomendado resolver pronto)" -Color Yellow
        foreach ($f in $medium) {
            Write-Color "  ! [$($f.Category)] $($f.Issue)" -Color Yellow
            Write-Color "     -> $($f.Recommendation)" -Color White
            Write-Host ""
        }
    }

    if ($low.Count -gt 0) {
        Write-SectionHeader "SUGERENCIAS (mejoras opcionales)" -Color Cyan
        foreach ($f in $low) {
            Write-Color "  * [$($f.Category)] $($f.Issue)" -Color Cyan
            Write-Color "     -> $($f.Recommendation)" -Color White
            Write-Host ""
        }
    }

    if ($Global:Findings.Count -eq 0) {
        Write-Color "  Tu notebook esta en excelente estado. No se encontraron problemas." -Color Green
    }

    # Seccion de bateria
    $diag        = $Global:SystemData.Diagnostics
    $battHealth  = Get-Safe $diag 'BatteryHealthPct'
    if ($null -ne $battHealth) {
        Write-SectionHeader "SALUD DE LA BATERIA" -Color Cyan
        $battBars  = [Math]::Round($battHealth / 5)
        $battEmpty = 20 - $battBars
        $battColor = [ConsoleColor]::Green
        if ($battHealth -lt 80) { $battColor = [ConsoleColor]::Yellow }
        if ($battHealth -lt 60) { $battColor = [ConsoleColor]::Red    }
        $battBar = ("#" * $battBars) + ("." * $battEmpty)
        Write-Color ("  Salud: {0}% [{1}]" -f $battHealth, $battBar) -Color $battColor

        $btData = $Global:SystemData.Bottlenecks
        if ($btData) {
            $monthsLeft = Get-Safe $btData 'BatteryEstimatedMonthsLeft'
            if ($null -ne $monthsLeft) {
                Write-Color "  Vida util restante estimada: ~$monthsLeft meses" -Color $battColor
            }
        }
        Write-Host ""
    }

    # -- 5.4  Crear carpeta de reporte en Escritorio ---------------------------
    Show-ProgressStep -Current 4 -Total 5 -Label "Creando carpeta de reportes en el Escritorio..."

    $desktop   = [Environment]::GetFolderPath("Desktop")
    $dateStr   = Get-Date -Format "yyyyMMdd_HHmm"
    $reportDir = Join-Path $desktop "Reporte_OptimizacionPC_$dateStr"
    New-Item -ItemType Directory -Force -Path $reportDir | Out-Null
    Add-TechLog "Carpeta de reporte creada: $reportDir"

    # Extraer datos con Get-Safe para evitar errores por claves ausentes
    $db       = $Global:SystemData.Diagnostics
    $appData  = $Global:SystemData.AppAnalysis
    $btData   = $Global:SystemData.Bottlenecks
    $freedRaw = Get-Safe $Global:SystemData 'CleanupFreedBytes' 0
    $freed    = Format-Bytes $freedRaw

    $cpuName     = Get-Safe $db 'CpuName'     'No disponible'
    $ramTotal    = Get-Safe $db 'RamTotalMB'  'No disponible'
    $powerPlan   = Get-Safe $db 'PowerPlan'   ''
    if (-not $powerPlan) { $powerPlan = Get-Safe $appData 'PowerPlanName' 'No disponible' }
    $battHealthSt = Get-Safe $db 'BatteryHealthPct'
    $battStr     = if ($null -ne $battHealthSt) { "$battHealthSt% de capacidad original" } else { "No disponible" }
    $ssid        = Get-Safe $db 'WifiSSID'
    $wifiSignal  = Get-Safe $db 'WifiSignal'
    $wifiStr     = if ($ssid) { "$ssid ? Se?al: $wifiSignal" } else { "No conectado o no disponible" }

    $lastUpdate   = Get-Safe $appData 'LastUpdateDate'   'No disponible'
    $daysSince    = Get-Safe $appData 'DaysSinceUpdate'  '--'
    $ppName       = Get-Safe $appData 'PowerPlanName'    'No disponible'
    $wifiAdapter  = Get-Safe $db 'WifiAdapter'
    $latencyMs    = Get-Safe $db 'NetworkLatencyMs'
    $latencyTgt   = Get-Safe $db 'NetworkLatencyTarget'
    $latencyStr   = if ($null -ne $latencyMs) { "$latencyMs ms (a $latencyTgt)" } else { "Sin conectividad" }

    $winName  = Get-Safe $btData 'WindowsName'  'No disponible'
    $winBuild = Get-Safe $btData 'WindowsBuild' 'No disponible'

    $beforeRamFree   = Get-Safe $Global:BeforeState 'RamFreeMB'    'N/D'
    $afterRamFree    = Get-Safe $Global:AfterState  'RamFreeMB'    'N/D'
    $beforeRamUsed   = Get-Safe $Global:BeforeState 'RamUsedPct'   'N/D'
    $afterRamUsed    = Get-Safe $Global:AfterState  'RamUsedPct'   'N/D'
    $beforeDiskFree  = Get-Safe $Global:BeforeState 'DiskFreeGB'   'N/D'
    $afterDiskFree   = Get-Safe $Global:AfterState  'DiskFreeGB'   'N/D'
    $beforeProcCount = Get-Safe $Global:BeforeState 'ProcessCount' 'N/D'
    $afterProcCount  = Get-Safe $Global:AfterState  'ProcessCount' 'N/D'

    # Discos info
    $disks = Get-Safe $db 'Disks' @()
    $disksStr = ($disks | ForEach-Object {
        "Disco: $($_.Model) | Tipo: $($_.MediaType) | Salud: $($_.Health) | $($_.SizeGB) GB"
    }) -join "`n"

    $logicalDisks = Get-Safe $db 'LogicalDisks' @()
    $logDisksStr  = ($logicalDisks | ForEach-Object {
        "  $($_.Drive)  Total: $($_.TotalGB) GB | Libre: $($_.FreeGB) GB ($($_.FreePct)%)"
    }) -join "`n"

    $fragResults = Get-Safe $btData 'FragmentationResults' @()
    $fragStr = if ($fragResults.Count -gt 0) {
        "Fragmentacion:`n" + (($fragResults | ForEach-Object { "  $($_.Drive): $($_.FragPct)%" }) -join "`n")
    } else { "" }

    $topRam = Get-Safe $db 'TopRamProcesses' @()
    $topRamStr = ($topRam | ForEach-Object { "  - $($_.Name): $($_.MB) MB" }) -join "`n"

    $startupItems = Get-Safe $appData 'StartupItems' @()
    $startupStr   = ($startupItems | ForEach-Object {
        "  - $($_.Name) | Impacto: $($_.Impact) | $($_.Command)"
    }) -join "`n"

    $detectedPUPs = Get-Safe $appData 'DetectedPUPs' @()
    $pupStr = if ($detectedPUPs.Count -gt 0) { $detectedPUPs -join "`n" } else { "Ninguno detectado." }

    $battCurrentMWh  = Get-Safe $db 'BatteryCurrentMWh'  'N/D'
    $battDesignedMWh = Get-Safe $db 'BatteryDesignedMWh' 'N/D'
    $battMonthsLeft  = Get-Safe $btData 'BatteryEstimatedMonthsLeft'
    $battMonthsStr   = if ($null -ne $battMonthsLeft) { "$battMonthsLeft meses" } else { "N/D" }

    $battSection = if ($null -ne $battHealthSt) {
        "Salud:             $battHealthSt%`n" +
        "Capacidad actual:  $battCurrentMWh mWh`n" +
        "Capacidad disenada: $battDesignedMWh mWh`n" +
        "Vida restante est: $battMonthsStr"
    } else {
        "No se detecto bateria o datos no disponibles."
    }

    # Hallazgos para archivos de reporte
    $findingsSimple = if ($Global:Findings.Count -eq 0) {
        "No se encontraron problemas. Tu notebook esta en buen estado."
    } else {
        ($Global:Findings | ForEach-Object {
            "[$($_.Severity.ToUpper())] $($_.Issue)`n   Que hacer: $($_.Recommendation)`n"
        }) -join ""
    }

    # Construir secciones priorizadas
    $highFindings   = @($Global:Findings | Where-Object { $_.Severity -eq "Alto"  })
    $mediumFindings = @($Global:Findings | Where-Object { $_.Severity -eq "Medio" })
    $lowFindings    = @($Global:Findings | Where-Object { $_.Severity -eq "Bajo"  })

    $recsContent = ""
    if ($highFindings.Count -gt 0) {
        $recsContent += "=== PRIORIDAD ALTA (hacer lo antes posible) ===`n`n"
        $i = 1; foreach ($f in $highFindings) {
            $recsContent += "$i. [$($f.Category)] $($f.Issue)`n   Que hacer: $($f.Recommendation)`n`n"; $i++
        }
    }
    if ($mediumFindings.Count -gt 0) {
        $recsContent += "=== PRIORIDAD MEDIA (hacer en el proximo mes) ===`n`n"
        $i = 1; foreach ($f in $mediumFindings) {
            $recsContent += "$i. [$($f.Category)] $($f.Issue)`n   Que hacer: $($f.Recommendation)`n`n"; $i++
        }
    }
    if ($lowFindings.Count -gt 0) {
        $recsContent += "=== PRIORIDAD BAJA (mejoras opcionales) ===`n`n"
        $i = 1; foreach ($f in $lowFindings) {
            $recsContent += "$i. [$($f.Category)] $($f.Issue)`n   Que hacer: $($f.Recommendation)`n`n"; $i++
        }
    }
    if ($recsContent -eq "") { $recsContent = "No se encontraron problemas. Tu notebook esta en buen estado." }

    $techLog = ($Global:TechLog) -join "`n"

    # -- Archivo 1: resumen.txt -----------------------------------------------
    $resumen = @"
====================================================================
RESUMEN DE OPTIMIZACION DE TU NOTEBOOK
Fecha: $(Get-Date -Format 'dd/MM/yyyy HH:mm')
====================================================================

Hola! Aca te contamos en palabras simples lo que hicimos y lo que encontramos
en tu computadora:

PUNTAJE DE SALUD: $healthScore/100 -- $healthLabel

--- LO QUE HICIMOS ---

1. DIAGNOSTICO: Revisamos el estado de tu procesador, memoria, disco y bateria.
2. LIMPIEZA:    Eliminamos archivos temporales y caches innecesarios.
   Espacio liberado: $freed
3. APLICACIONES: Revisamos los programas que arrancan solos con Windows.
4. CUELLOS DE BOTELLA: Identificamos que esta haciendo mas lenta tu notebook.

--- ESTADO GENERAL ---

Procesador:      $cpuName
Memoria RAM:     $ramTotal MB
Plan de energia: $powerPlan
Salud bateria:   $battStr
WiFi:            $wifiStr

--- LO QUE NECESITA ATENCION ---

$findingsSimple
--- GARANTIAS ---

* No se modifico ningun archivo de Windows ni tus datos personales.
* Todas las acciones de limpieza fueron confirmadas por vos antes de ejecutarse.
* Para mas detalles tecnicos consulta el archivo detalles_tecnicos.txt

Gracias por usar el Optimizador Universal de Notebooks.
"@

    Set-Content -Path (Join-Path $reportDir "resumen.txt") -Value $resumen -Encoding UTF8

    # -- Archivo 2: detalles_tecnicos.txt -------------------------------------
    $tecnico = @"
====================================================================
LOG TECNICO COMPLETO -- Optimizador Universal de Notebooks
Fecha: $(Get-Date -Format 'dd/MM/yyyy HH:mm')
====================================================================

--- CPU ---
Modelo:     $cpuName
Nucleos:    $(Get-Safe $db 'CpuCores') fisicos / $(Get-Safe $db 'CpuLogical') logicos
Frecuencia: $(Get-Safe $db 'CpuCurrentMhz') MHz actual / $(Get-Safe $db 'CpuMaxMhz') MHz maxima
Carga:      $(Get-Safe $db 'CpuLoad')%
Throttling: $(if (Get-Safe $db 'CpuThrottling') { 'ACTIVO' } else { 'No detectado' })
Temperatura: $(if ($null -ne (Get-Safe $db 'CpuTempC')) { "$(Get-Safe $db 'CpuTempC') C" } else { 'No disponible en este equipo' })

--- RAM ---
Total:  $ramTotal MB
Usada:  $(Get-Safe $db 'RamUsedMB') MB ($(Get-Safe $db 'RamUsedPct')%)
Libre:  $(Get-Safe $db 'RamFreeMB') MB
Slots:  $(Get-Safe $db 'RamSlotsUsed') usados de $(Get-Safe $db 'RamSlotsTotal') disponibles

Top procesos por RAM:
$topRamStr

--- BATERIA ---
$battSection

--- DISCO ---
$disksStr

Espacio por unidad:
$logDisksStr

$fragStr

--- RED ---
WiFi:      $wifiStr
Adaptador: $wifiAdapter
Latencia:  $latencyStr

--- PLAN DE ENERGIA ---
$ppName

--- APLICACIONES AL INICIO ---
$startupStr

--- PUPs DETECTADOS ---
$pupStr

--- VERSION DE WINDOWS ---
$winName (Build $winBuild)
Ultima actualizacion: $lastUpdate ($daysSince dias)

--- LIMPIEZA ---
Espacio total liberado: $freed

--- LOG DE EVENTOS ---
$techLog
"@

    Set-Content -Path (Join-Path $reportDir "detalles_tecnicos.txt") -Value $tecnico -Encoding UTF8

    # -- Archivo 3: recomendaciones.txt ---------------------------------------
    $recomendaciones = @"
====================================================================
RECOMENDACIONES PRIORIZADAS -- Optimizador Universal de Notebooks
Fecha: $(Get-Date -Format 'dd/MM/yyyy HH:mm')
Puntaje de salud: $healthScore/100 -- $healthLabel
====================================================================

$recsContent
"@

    Set-Content -Path (Join-Path $reportDir "recomendaciones.txt") -Value $recomendaciones -Encoding UTF8

    # -- Archivo 4: captura_estado_sistema.txt (before/after) ----------------
    $captura = @"
====================================================================
CAPTURA DE ESTADO DEL SISTEMA -- ANTES Y DESPUES
Fecha: $(Get-Date -Format 'dd/MM/yyyy HH:mm')
====================================================================

                           ANTES           DESPUES
                           -------------   -------------
RAM Libre (MB):            $("{0,-15}" -f $beforeRamFree)   $afterRamFree
RAM Usada (%):             $("{0,-15}" -f $beforeRamUsed)   $afterRamUsed
Espacio libre C: (GB):     $("{0,-15}" -f $beforeDiskFree)   $afterDiskFree
Procesos activos:          $("{0,-15}" -f $beforeProcCount)   $afterProcCount

Espacio total liberado: $freed

Puntaje de salud del sistema: $healthScore / 100 -- $healthLabel
"@

    Set-Content -Path (Join-Path $reportDir "captura_estado_sistema.txt") -Value $captura -Encoding UTF8

    # -- 5.5  Finalizar --------------------------------------------------------
    Show-ProgressStep -Current 5 -Total 5 -Label "Finalizando..."

    $Global:SystemData.ReportFolder = $reportDir
    Add-TechLog "Reporte generado en: $reportDir"

    Write-Host ""
    Write-Color "  Carpeta de resultados creada en el Escritorio:" -Color Cyan
    Write-Color "     $reportDir" -Color White
    Write-Host ""
    Write-Color "      resumen.txt                -> Que se hizo (lenguaje simple)" -Color DarkGray
    Write-Color "      detalles_tecnicos.txt       -> Log completo para tecnicos" -Color DarkGray
    Write-Color "      recomendaciones.txt         -> Proximos pasos sugeridos" -Color DarkGray
    Write-Color "      captura_estado_sistema.txt  -> Estado antes y despues" -Color DarkGray
    Write-Host ""
}
