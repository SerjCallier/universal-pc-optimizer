# =============================================================================
# Write-SystemReport.ps1  -  Modulo 5: Puntaje de Salud y Reportes
# Genera 4 archivos adaptados al perfil del usuario (TechLevel).
# Compatible con PowerShell 5.1 (sin ?. ni ?? ni ternario)
# =============================================================================

# ---------------------------------------------------------------------------
# Get-Safe : acceso seguro a una clave de hashtable ($null si no existe)
# ---------------------------------------------------------------------------
function Get-Safe {
    param($Hashtable, [string]$Key, $Default = $null)
    if ($Hashtable -and $Hashtable.ContainsKey($Key) -and ($null -ne $Hashtable[$Key])) {
        return $Hashtable[$Key]
    }
    return $Default
}

# ---------------------------------------------------------------------------
# Get-TechLevelText : devuelve el texto segun nivel tecnico del usuario
# ---------------------------------------------------------------------------
function Get-TechLevelText {
    param([string]$Level, [string]$Basico, [string]$Intermedio, [string]$Avanzado)
    if ($Level -eq "Avanzado")   { return $Avanzado }
    if ($Level -eq "Intermedio") { return $Intermedio }
    return $Basico
}

# ---------------------------------------------------------------------------
# Get-FindingHorizon : clasifica un finding en Corto / Mediano / Largo plazo
# ---------------------------------------------------------------------------
function Get-FindingHorizon {
    param($Finding)
    $largoKW = @("SSD", "RAM", "bateria", "pasta termica", "servicio tecnico",
                 "reemplazar", "upgrade", "GPU dedicada", "notebook gaming",
                 "nuevo equipo", "modulos", "reemplazar")
    foreach ($kw in $largoKW) {
        if ($Finding.Recommendation -match $kw -or $Finding.Issue -match $kw) {
            return "Largo"
        }
    }
    $cortoCategories = @("Energia", "Inicio", "Software", "Red", "Rendimiento")
    if ($Finding.Category -in $cortoCategories) { return "Corto" }
    return "Mediano"
}

# ---------------------------------------------------------------------------
# Format-FindingLine : formatea un finding segun nivel tecnico
# ---------------------------------------------------------------------------
function Format-FindingLine {
    param($Finding, [string]$TechLevel, [int]$Num)
    $prefix = switch ($Finding.Severity) {
        "Alto"  { "[!!]" }
        "Medio" { "[ !]" }
        "Bajo"  { "[  ]" }
        default { "[  ]" }
    }
    if ($TechLevel -eq "Avanzado") {
        return "$Num. $prefix [$($Finding.Category)] $($Finding.Issue)`n   Accion: $($Finding.Recommendation)`n"
    }
    if ($TechLevel -eq "Intermedio") {
        return "$Num. $prefix $($Finding.Issue)`n   Que hacer: $($Finding.Recommendation)`n"
    }
    return "$Num. $prefix $($Finding.Issue)`n   Como solucionarlo: $($Finding.Recommendation)`n"
}

function Write-SystemReport {

    Show-StageIntro -StageNum 5 -TotalStages 5 `
        -Title "Generando Reporte Final" `
        -Duration "Menos de 1 minuto" `
        -WhatItDoes "Calculamos el puntaje de salud y creamos 4 archivos en tu Escritorio con el diagnostico y el plan de accion." `
        -Instructions "Solo espera. En breve tendras todos los reportes listos."

    # -- 5.1  Snapshot AfterState ----------------------------------------------
    Show-ProgressStep -Current 1 -Total 5 -Label "Tomando instantanea del estado actual..."

    $afterProcs     = (Get-Process -ErrorAction SilentlyContinue | Measure-Object).Count
    $afterOS        = Get-WmiObject Win32_OperatingSystem -ErrorAction SilentlyContinue
    $afterRamFreeMB = 0
    if ($afterOS) { $afterRamFreeMB = [Math]::Round($afterOS.FreePhysicalMemory / 1KB, 0) }

    $Global:AfterState.ProcessCount = $afterProcs
    $Global:AfterState.RamFreeMB    = $afterRamFreeMB
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

    Write-SectionHeader "RESULTADO FINAL - SALUD DE TU NOTEBOOK" -Color $healthColor
    Write-Host ""
    Write-Color ("  PUNTAJE DE SALUD: {0}/100 - {1}" -f $healthScore, $healthLabel.ToUpper()) -Color $healthColor
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
        Write-SectionHeader "PROBLEMAS CRITICOS" -Color Red
        foreach ($f in $high) {
            Write-Color "  X [$($f.Category)] $($f.Issue)" -Color Red
            Write-Color "     -> $($f.Recommendation)" -Color White
            Write-Host ""
        }
    }
    if ($medium.Count -gt 0) {
        Write-SectionHeader "ADVERTENCIAS" -Color Yellow
        foreach ($f in $medium) {
            Write-Color "  ! [$($f.Category)] $($f.Issue)" -Color Yellow
            Write-Color "     -> $($f.Recommendation)" -Color White
            Write-Host ""
        }
    }
    if ($low.Count -gt 0) {
        Write-SectionHeader "SUGERENCIAS" -Color Cyan
        foreach ($f in $low) {
            Write-Color "  * [$($f.Category)] $($f.Issue)" -Color Cyan
            Write-Color "     -> $($f.Recommendation)" -Color White
            Write-Host ""
        }
    }
    if ($Global:Findings.Count -eq 0) {
        Write-Color "  Tu notebook esta en excelente estado. No se encontraron problemas." -Color Green
    }

    # -- 5.4  Crear carpeta de reporte -----------------------------------------
    Show-ProgressStep -Current 4 -Total 5 -Label "Creando carpeta de reportes..."

    $baseDir   = if ($Global:ScriptDir -and (Test-Path $Global:ScriptDir)) {
                     $Global:ScriptDir
                 } else {
                     [Environment]::GetFolderPath("Desktop")
                 }
    $dateStr   = Get-Date -Format "yyyyMMdd_HHmm"
    $reportDir = Join-Path $baseDir "Reporte_OptimizacionPC_$dateStr"
    New-Item -ItemType Directory -Force -Path $reportDir | Out-Null
    Add-TechLog "Carpeta de reporte creada: $reportDir"

    # -- Variables de datos comunes --------------------------------------------
    $db       = $Global:SystemData.Diagnostics
    $appData  = $Global:SystemData.AppAnalysis
    $btData   = $Global:SystemData.Bottlenecks
    $freedRaw = Get-Safe $Global:SystemData 'CleanupFreedBytes' 0
    $freed    = Format-Bytes $freedRaw

    $techLevel   = $Global:UserProfile.TechLevel
    $primaryUse  = $Global:UserProfile.PrimaryUse
    $mainConcern = $Global:UserProfile.MainConcern

    $machineMake   = Get-Safe $db 'MachineMake'   'No disponible'
    $machineModel  = Get-Safe $db 'MachineModel'  'No disponible'
    $machineSerial = Get-Safe $db 'MachineSerial' 'No disponible'
    $osName        = Get-Safe $db 'OsName'        'No disponible'
    $osBuild       = Get-Safe $db 'OsBuild'       '?'
    $osInstall     = Get-Safe $db 'OsInstallDate' 'No disponible'
    $cpuName       = Get-Safe $db 'CpuName'       'No disponible'
    $cpuCores      = Get-Safe $db 'CpuCores'      '?'
    $cpuLogical    = Get-Safe $db 'CpuLogical'    '?'
    $cpuMaxMhz     = Get-Safe $db 'CpuMaxMhz'     '?'
    $cpuCurrMhz    = Get-Safe $db 'CpuCurrentMhz' '?'
    $cpuLoad       = Get-Safe $db 'CpuLoad'       '?'
    $cpuThrottle   = Get-Safe $db 'CpuThrottling' $false
    $cpuTempC      = Get-Safe $db 'CpuTempC'
    $ramTotal      = Get-Safe $db 'RamTotalMB'    0
    $ramUsed       = Get-Safe $db 'RamUsedMB'     0
    $ramFree       = Get-Safe $db 'RamFreeMB'     0
    $ramUsedPct    = Get-Safe $db 'RamUsedPct'    0
    $ramSlotsUsed  = Get-Safe $db 'RamSlotsUsed'  '?'
    $ramSlotsTotal = Get-Safe $db 'RamSlotsTotal' '?'
    $battHealth    = Get-Safe $db 'BatteryHealthPct'
    $battCurrMWh   = Get-Safe $db 'BatteryCurrentMWh'  'N/D'
    $battDesnMWh   = Get-Safe $db 'BatteryDesignedMWh' 'N/D'
    $battCharge    = Get-Safe $db 'BatteryCharge'
    $ssid          = Get-Safe $db 'WifiSSID'
    $wifiSignal    = Get-Safe $db 'WifiSignal'
    $wifiAdapter   = Get-Safe $db 'WifiAdapter'
    $latencyMs     = Get-Safe $db 'NetworkLatencyMs'
    $latencyTgt    = Get-Safe $db 'NetworkLatencyTarget'
    $disks         = Get-Safe $db 'Disks'        @()
    $logicalDisks  = Get-Safe $db 'LogicalDisks' @()

    $powerPlan    = Get-Safe $db 'PowerPlan' ''
    if (-not $powerPlan) { $powerPlan = Get-Safe $appData 'PowerPlanName' 'No disponible' }
    $ppName       = Get-Safe $appData 'PowerPlanName'  'No disponible'
    $lastUpdate   = Get-Safe $appData 'LastUpdateDate' 'No disponible'
    $daysSince    = Get-Safe $appData 'DaysSinceUpdate' '--'
    $detectedPUPs = Get-Safe $appData 'DetectedPUPs'   @()
    $startupItems = Get-Safe $appData 'StartupItems'   @()
    $highImpactStartups = @($startupItems | Where-Object { $_.Impact -eq "Alto" })

    $battMonthsLeft = Get-Safe $btData 'BatteryEstimatedMonthsLeft'
    $gpuList        = Get-Safe $btData 'GpuList'         @()
    $hasDedGpu      = Get-Safe $btData 'HasDedicatedGpu' $false
    $fragResults    = Get-Safe $btData 'FragmentationResults' @()
    $throttleRatio  = Get-Safe $btData 'ThrottleRatio'   1
    $winName        = Get-Safe $btData 'WindowsName'     'No disponible'
    $winBuild       = Get-Safe $btData 'WindowsBuild'    'No disponible'
    $hasHDD         = Get-Safe $btData 'HasHDD'          $false

    $wifiStr   = if ($ssid)            { "$ssid - Senal: $wifiSignal" }   else { "No conectado o no disponible" }
    $battStr   = if ($null -ne $battHealth) { "$battHealth% de capacidad original" } else { "No disponible" }
    $latStr    = if ($null -ne $latencyMs)  { "$latencyMs ms (a $latencyTgt)" }      else { "Sin conectividad" }
    $tempStr   = if ($null -ne $cpuTempC)   { "$cpuTempC C" }                         else { "No disponible" }

    $beforeRamFree   = Get-Safe $Global:BeforeState 'RamFreeMB'    'N/D'
    $afterRamFree    = Get-Safe $Global:AfterState  'RamFreeMB'    'N/D'
    $beforeRamUsed   = Get-Safe $Global:BeforeState 'RamUsedPct'   'N/D'
    $afterRamUsed    = Get-Safe $Global:AfterState  'RamUsedPct'   'N/D'
    $beforeDiskFree  = Get-Safe $Global:BeforeState 'DiskFreeGB'   'N/D'
    $afterDiskFree   = Get-Safe $Global:AfterState  'DiskFreeGB'   'N/D'
    $beforeProcCount = Get-Safe $Global:BeforeState 'ProcessCount' 'N/D'
    $afterProcCount  = Get-Safe $Global:AfterState  'ProcessCount' 'N/D'

    $topRam     = Get-Safe $db 'TopRamProcesses' @()
    $topRamStr  = ($topRam | ForEach-Object { "  - $($_.Name): $($_.MB) MB" }) -join "`n"
    $disksStr   = ($disks | ForEach-Object {
        "  $($_.Model) | Tipo: $($_.MediaType) | Salud: $($_.Health) | $($_.SizeGB) GB"
    }) -join "`n"
    $logDiskStr = ($logicalDisks | ForEach-Object {
        "  $($_.Drive)  Total: $($_.TotalGB) GB | Libre: $($_.FreeGB) GB ($($_.FreePct)%)"
    }) -join "`n"
    $fragStr = if ($fragResults.Count -gt 0) {
        ($fragResults | ForEach-Object { "  $($_.Drive): $($_.FragPct)% fragmentado" }) -join "`n"
    } else { "  Sin fragmentacion relevante o no aplica (SSD)." }
    $gpuStr = if ($gpuList.Count -gt 0) {
        ($gpuList | ForEach-Object { "  $($_.Name) | $($_.Type) | $($_.RamMB) MB VRAM" }) -join "`n"
    } else { "  No disponible" }
    $startupStr = if ($startupItems.Count -gt 0) {
        ($startupItems | ForEach-Object { "  - $($_.Name) | Impacto: $($_.Impact)" }) -join "`n"
    } else { "  Ninguno detectado." }
    $pupStr = if ($detectedPUPs.Count -gt 0) { ($detectedPUPs -join "`n") } else { "  Ninguno detectado." }

    $healthBars  = [Math]::Round($healthScore / 5)
    $healthBar   = ("#" * $healthBars) + ("." * (20 - $healthBars))

    # ==========================================================================
    # ARCHIVO 1: diagnostico_equipo.txt
    # ==========================================================================
    $battSection = if ($null -ne $battHealth) {
        "Salud:              $battHealth%`n" +
        "Capacidad actual:   $battCurrMWh mWh`n" +
        "Capacidad original: $battDesnMWh mWh`n" +
        "Vida restante est:  " + (if ($null -ne $battMonthsLeft) { "$battMonthsLeft meses" } else { "N/D" })
    } else {
        "No se detecto bateria (PC de escritorio o datos no disponibles)."
    }

    $diagEquipo = @"
====================================================================
DIAGNOSTICO DEL EQUIPO
Fecha: $(Get-Date -Format 'dd/MM/yyyy HH:mm')
====================================================================

--- IDENTIDAD DEL EQUIPO ---
Marca:             $machineMake
Modelo:            $machineModel
Numero de serie:   $machineSerial

--- SISTEMA OPERATIVO ---
Version:           $osName
Build:             $osBuild
Instalado el:      $osInstall

--- PROCESADOR (CPU) ---
Modelo:            $cpuName
Nucleos:           $cpuCores fisicos / $cpuLogical logicos
Frecuencia maxima: $cpuMaxMhz MHz
Frecuencia actual: $cpuCurrMhz MHz
Carga al analizar: $cpuLoad%
Throttling:        $(if ($cpuThrottle) { "ACTIVO (ratio $throttleRatio)" } else { "No detectado" })
Temperatura:       $tempStr

--- MEMORIA RAM ---
Total:             $ramTotal MB
En uso:            $ramUsed MB ($ramUsedPct%)
Libre:             $ramFree MB
Slots:             $ramSlotsUsed usados de $ramSlotsTotal disponibles

--- TARJETA GRAFICA (GPU) ---
$gpuStr

--- BATERIA ---
$battSection

--- DISCO(S) ---
$disksStr

Espacio por unidad:
$logDiskStr

--- RED / WIFI ---
Red WiFi:          $wifiStr
Adaptador:         $wifiAdapter
Latencia:          $latStr

--- PUNTAJE DE SALUD ---
[$healthBar] $healthScore/100 - $healthLabel
====================================================================
"@

    Set-Content -Path (Join-Path $reportDir "diagnostico_equipo.txt") -Value $diagEquipo -Encoding UTF8

    # ==========================================================================
    # ARCHIVO 2: analisis_funcional.txt
    # ==========================================================================
    $findingCount = $Global:Findings.Count
    $highCount    = $high.Count
    $medCount     = $medium.Count
    $lowCount     = $low.Count

    # Seccion de hallazgos formateada por nivel
    $findingsFormatted = ""
    if ($findingCount -eq 0) {
        $findingsFormatted = "No se encontraron problemas. Tu notebook esta en buen estado."
    } else {
        $n = 1
        foreach ($f in $Global:Findings) {
            $findingsFormatted += Format-FindingLine -Finding $f -TechLevel $techLevel -Num $n
            $n++
        }
    }

    # Lead segun MainConcern (adaptado al nivel)
    $concernLead = ""
    if ($mainConcern -eq "Lentitud") {
        if ($hasHDD) {
            $concernLead = Get-TechLevelText -Level $techLevel `
                -Basico     "SOBRE LA LENTITUD:`nEl principal motivo es que tu computadora tiene un disco mecanico (HDD). Es como tener un tocadiscos en lugar de un pendrive: funciona, pero es mucho mas lento. Reemplazarlo por un SSD es la mejora mas grande que podrias hacer.`n" `
                -Intermedio "RENDIMIENTO - DISCO:`nSe detecto disco HDD. Los discos mecanicos tienen velocidades de lectura/escritura de ~100 MB/s, contra ~500 MB/s de un SSD. Esto genera la mayor parte de la lentitud percibida en arranque y apertura de aplicaciones.`n" `
                -Avanzado   "BOTTLENECK - STORAGE:`nHDD detectado: velocidad I/O ~100 MB/s vs SSD SATA ~500 MB/s / NVMe ~3500 MB/s. Throttle ratio: $throttleRatio. Reemplazar HDD por SSD reducira dramáticamente los tiempos de acceso aleatorio.`n"
        } elseif ($cpuThrottle) {
            $concernLead = Get-TechLevelText -Level $techLevel `
                -Basico     "SOBRE LA LENTITUD:`nTu procesador esta funcionando mas despacio de lo normal por exceso de calor. Es como correr con el calzado demasiado apretado. Limpiar el ventilador puede mejorar mucho la velocidad.`n" `
                -Intermedio "RENDIMIENTO - CPU THROTTLING:`nThrottle ratio: $throttleRatio (frecuencia actual / maxima). El procesador baja su velocidad automaticamente al calentarse. Limpieza de ventiladores o reemplazo de pasta termica puede mejorar esto.`n" `
                -Avanzado   "CPU THROTTLING ACTIVO:`nThrottle ratio: $throttleRatio ($cpuCurrMhz MHz / $cpuMaxMhz MHz). Temperatura: $tempStr. Probable causa: acumulacion de polvo o pasta termica degradada. Ver: Get-WmiObject -Namespace root/wmi -Class MSAcpi_ThermalZoneTemperature`n"
        } elseif ($ramTotal -lt 8192) {
            $concernLead = Get-TechLevelText -Level $techLevel `
                -Basico     "SOBRE LA LENTITUD:`nTu computadora tiene poca memoria RAM, que es como una mesa de trabajo muy chica. Cuando abres muchos programas a la vez, no entran todos y el sistema se pone lento. Agregar mas RAM ayudaria mucho.`n" `
                -Intermedio "RENDIMIENTO - RAM:`nRAM total: $ramTotal MB, actualmente en uso: $ramUsedPct%. Con menos de 8 GB, el sistema usa el disco como memoria adicional (paginacion), lo que reduce la velocidad significativamente.`n" `
                -Avanzado   "BOTTLENECK - RAM:`nRAM: $ramTotal MB total / $ramUsed MB in use ($ramUsedPct%). Paging file activity probable. Slots: $ramSlotsUsed/$ramSlotsTotal en uso. Upgrade a 8 GB o 16 GB recomendado.`n"
        } else {
            $concernLead = Get-TechLevelText -Level $techLevel `
                -Basico     "SOBRE LA LENTITUD:`nNo encontramos un problema obvio de hardware. Puede deberse a muchos programas abiertos al iniciar o a actualizaciones pendientes de Windows.`n" `
                -Intermedio "RENDIMIENTO - SIN CUELLO DE BOTELLA CRITICO:`nHardware dentro de parametros normales. Revisar programas de inicio y actualizaciones pendientes.`n" `
                -Avanzado   "PERFORMANCE - NO CRITICAL BOTTLENECK:`nRAM: $ramTotal MB ($ramUsedPct% in use). CPU ratio: $throttleRatio. Disk: SSD/NVMe. Investigate startup programs and background services.`n"
        }
    } elseif ($mainConcern -eq "Temperatura") {
        $tempVal = if ($null -ne $cpuTempC) { $cpuTempC } else { 0 }
        $concernLead = Get-TechLevelText -Level $techLevel `
            -Basico     "SOBRE EL CALENTAMIENTO:`nTu procesador esta a $tempStr. Para comparar, el agua hierve a 100 grados. $(if ($tempVal -gt 85) { 'Esto es alto y puede danar el equipo. Apagala y llevala a revisar.' } elseif ($tempVal -gt 70) { 'Esta un poco elevada. Usa la computadora siempre en una superficie dura (mesa), nunca sobre camas o almohadones.' } else { 'Esta dentro de lo normal.' })`n" `
            -Intermedio "TEMPERATURA CPU:`n$tempStr en este momento. $(if ($tempVal -gt 85) { 'Temperatura critica. Posible causa: acumulacion de polvo severa o pasta termica degradada.' } elseif ($tempVal -gt 70) { 'Temperatura elevada en reposo. Revisar ventilacion y superficie de uso.' } else { 'Dentro de rango normal.' }) Throttle ratio: $throttleRatio`n" `
            -Avanzado   "THERMAL ANALYSIS:`nCPU Temp: $tempStr (ACPI MSAcpiThermalZoneTemperature). Throttle ratio: $throttleRatio ($cpuCurrMhz/$cpuMaxMhz MHz). CPU Load: $cpuLoad%.`nVerificar: Get-WmiObject -Namespace root/wmi -Class MSAcpi_ThermalZoneTemperature | Select CurrentTemperature`n"
    } elseif ($mainConcern -eq "Bateria") {
        $concernLead = Get-TechLevelText -Level $techLevel `
            -Basico     "SOBRE LA BATERIA:`n$(if ($null -ne $battHealth) { "Tu bateria tiene el $battHealth% de su capacidad original. $(if ($battHealth -lt 60) { 'Esta muy desgastada y probablemente dure mucho menos que cuando era nueva. Es hora de cambiarla.' } elseif ($battHealth -lt 80) { 'Se nota el desgaste. Durara menos que antes.' } else { 'Todavia esta en buen estado.' })" } else { 'No se pudo leer el estado de la bateria en este equipo.' })`n" `
            -Intermedio "ESTADO DE BATERIA:`nSalud: $battStr. Capacidad actual: $battCurrMWh mWh / Capacidad disenada: $battDesnMWh mWh. Vida estimada restante: $(if ($null -ne $battMonthsLeft) { "$battMonthsLeft meses" } else { 'N/D' }).`n" `
            -Avanzado   "BATTERY ANALYSIS:`nHealth: $battHealth% | Full charge: $battCurrMWh mWh | Design: $battDesnMWh mWh. Est. remaining: $(if ($null -ne $battMonthsLeft) { "$battMonthsLeft mo" } else { 'N/D' }).`nVerificar: Get-CimInstance -Namespace root/wmi -ClassName BatteryFullChargedCapacity`n"
    } elseif ($mainConcern -eq "WiFi") {
        $concernLead = Get-TechLevelText -Level $techLevel `
            -Basico     "SOBRE EL WIFI:`n$(if ($ssid) { "Tu computadora esta conectada a '$ssid' con senal $wifiSignal." } else { "No se detecto conexion WiFi activa." }) La latencia (tiempo de respuesta de la red) es $latStr. Si el WiFi va lento, proba acercarte mas al router o usar un cable de red.`n" `
            -Intermedio "RED / WIFI:`nRed: $wifiStr. Latencia: $latStr. Adaptador: $wifiAdapter. Si la senal es baja o la latencia alta, considera conectar por Ethernet o instalar un extensor WiFi.`n" `
            -Avanzado   "NETWORK ANALYSIS:`nSSID: $ssid | Signal: $wifiSignal | Adapter: $wifiAdapter | Latency: $latStr.`nVerificar: netsh wlan show interfaces`n"
    } else {
        $concernLead = ""
    }

    # Seccion por uso principal (perfil)
    $profileSection = ""
    if ($primaryUse -eq "Gaming") {
        $gpuDesc = if ($gpuList.Count -gt 0) {
            ($gpuList | ForEach-Object { "$($_.Name) ($($_.Type), $($_.RamMB) MB VRAM)" }) -join "; "
        } else { "No detectada" }
        $profileSection = Get-TechLevelText -Level $techLevel `
            -Basico     "PARA GAMING:`nTu tarjeta de video es: $gpuDesc. $(if ($hasDedGpu) { 'Tenes una GPU dedicada, lo que es bueno para juegos.' } else { 'Solo tenes la grafica integrada. Para juegos exigentes necesitas una GPU dedicada.' }) RAM: $ramTotal MB (lo minimo para gaming es 8 GB).`n" `
            -Intermedio "GAMING - HARDWARE:`nGPU: $gpuDesc. RAM: $ramTotal MB. CPU: $cpuName. $(if (-not $hasDedGpu) { 'GPU integrada detectada: rendimiento en juegos sera limitado para titulos exigentes.' }) $(if ($ramTotal -lt 8192) { 'RAM inferior a 8 GB: impacto negativo en juegos modernos.' })`n" `
            -Avanzado   "GAMING PROFILE:`nGPU: $gpuDesc | RAM: $ramTotal MB | CPU: $cpuName ($cpuCores cores, $cpuMaxMhz MHz). Dedicated GPU: $hasDedGpu. Throttle ratio: $throttleRatio.`n"
    } elseif ($primaryUse -eq "Diseno") {
        $profileSection = Get-TechLevelText -Level $techLevel `
            -Basico     "PARA DISENO Y EDICION:`nRAM: $ramTotal MB. Para edicion de fotos necesitas al menos 8 GB; para video, 16 GB o mas. $(if ($ramTotal -lt 8192) { 'Con la RAM actual puede que el programa vaya lento con archivos grandes.' })`n" `
            -Intermedio "DISENO/EDICION - RECURSOS:`nRAM: $ramTotal MB (recomendado: 16 GB para video 4K). GPU: $(if ($gpuList.Count -gt 0) { $gpuList[0].Name } else { 'No detectada' }). Disco: $(($disks | ForEach-Object { $_.MediaType }) -join '/'). Para Premiere/Resolve se recomienda SSD y GPU dedicada.`n" `
            -Avanzado   "CREATIVE WORKLOAD:`nRAM: $ramTotal MB ($ramUsedPct% utilization). GPU: $gpuStr. Storage: $disksStr. For GPU-accelerated encoding verify CUDA/OpenCL support in GPU driver.`n"
    } elseif ($primaryUse -eq "Trabajo") {
        $profileSection = Get-TechLevelText -Level $techLevel `
            -Basico     "PARA TRABAJO Y ESTUDIO:`nSe detectaron $($startupItems.Count) programas que arrancan solos con Windows. $(if ($highImpactStartups.Count -gt 0) { "De estos, $($highImpactStartups.Count) son de alto impacto y hacen mas lento el inicio." }) Windows fue actualizado hace $daysSince dias.`n" `
            -Intermedio "PRODUCTIVIDAD:`nProgramas de inicio: $($startupItems.Count) total, $($highImpactStartups.Count) de alto impacto. Dias desde ultima actualizacion Windows: $daysSince. Plan de energia: $ppName.`n" `
            -Avanzado   "PRODUCTIVITY PROFILE:`nStartup items: $($startupItems.Count) ($($highImpactStartups.Count) high-impact). Windows last patched: $lastUpdate ($daysSince days ago). Power plan: $ppName.`n"
    } elseif ($primaryUse -eq "Navegacion") {
        $profileSection = Get-TechLevelText -Level $techLevel `
            -Basico     "PARA NAVEGACION Y REDES SOCIALES:`nTu conexion es: $wifiStr. Latencia de red: $latStr. $(if ($ssid) { 'Si el navegador va lento, proba limpiando el cache del navegador o acercandote al router.' })`n" `
            -Intermedio "NAVEGACION:`nWiFi: $wifiStr | Latencia: $latStr | Adaptador: $wifiAdapter. Si la navegacion es lenta, verificar: 1) Extensiones del navegador, 2) Cache del navegador, 3) Distancia al router.`n" `
            -Avanzado   "BROWSING PROFILE:`nNetwork: $wifiStr | Latency: $latStr | Adapter: $wifiAdapter. Check: browser extensions, DNS resolution time, WiFi channel congestion.`n"
    }

    $analisisFuncional = @"
====================================================================
ANALISIS FUNCIONAL DE TU NOTEBOOK
Fecha: $(Get-Date -Format 'dd/MM/yyyy HH:mm')
Perfil: $techLevel | Uso: $primaryUse | Preocupacion: $mainConcern
====================================================================

$(Get-TechLevelText -Level $techLevel `
    -Basico     "ESTADO GENERAL EN PALABRAS SIMPLES:" `
    -Intermedio "ESTADO DEL SISTEMA:" `
    -Avanzado   "SYSTEM SUMMARY:")
Puntaje de salud: $healthScore/100 - $healthLabel  [$healthBar]

$(Get-TechLevelText -Level $techLevel `
    -Basico     "$(if ($healthScore -ge 85) { "Tu computadora esta en excelente estado. Podes usarla sin preocupaciones." } elseif ($healthScore -ge 70) { "Tu computadora esta en buen estado con algunas cosas para mejorar." } elseif ($healthScore -ge 50) { "Tiene problemas que la hacen mas lenta de lo que podria ser. Vale la pena atenderlos." } else { "Tiene problemas serios que afectan tu uso diario. Te recomendamos actuar pronto." })" `
    -Intermedio "$(if ($healthScore -ge 85) { "Sistema en buen estado. Sin cuellos de botella criticos." } elseif ($healthScore -ge 70) { "Sistema funcional con areas de mejora." } else { "Problemas detectados que impactan el rendimiento. Ver hallazgos a continuacion." })" `
    -Avanzado   "$machineMake $machineModel | $osName Build $osBuild | CPU: $cpuName | RAM: $ramTotal MB ($ramUsedPct% used) | Throttle: $throttleRatio")

$concernLead
$profileSection
--- $(Get-TechLevelText -Level $techLevel -Basico "LO QUE NECESITA ATENCION" -Intermedio "HALLAZGOS" -Avanzado "FINDINGS ($highCount critical, $medCount warning, $lowCount info)") ---

$findingsFormatted
"@

    Set-Content -Path (Join-Path $reportDir "analisis_funcional.txt") -Value $analisisFuncional -Encoding UTF8

    # ==========================================================================
    # ARCHIVO 3: plan_optimizacion.txt
    # ==========================================================================

    # Clasificar findings por horizonte
    $findingsCorto   = @($Global:Findings | Where-Object { (Get-FindingHorizon $_) -eq "Corto"   })
    $findingsMediano = @($Global:Findings | Where-Object { (Get-FindingHorizon $_) -eq "Mediano" })
    $findingsLargo   = @($Global:Findings | Where-Object { (Get-FindingHorizon $_) -eq "Largo"   })

    # Armar cada seccion
    $cortoItems   = ""
    $medianoItems = ""
    $largoItems   = ""

    $n = 1
    foreach ($f in $findingsCorto) {
        $cortoItems += Format-FindingLine -Finding $f -TechLevel $techLevel -Num $n
        $n++
    }
    # Ítems estáticos Corto
    $planEnergia = Get-Safe $appData 'PowerPlanName' ''
    if ($planEnergia -match "[Ee]conomizador|[Pp]ower [Ss]aver|[Aa]horro") {
        $cortoItems += "$n. Cambia el plan de energia a 'Equilibrado':`n   Panel de Control > Opciones de energia > Equilibrado.`n   Tarda 30 segundos y mejora el rendimiento sin consumir mucha bateria.`n"
        $n++
    }
    if ($highImpactStartups.Count -gt 3) {
        $cortoItems += "$n. Deshabilita programas de inicio innecesarios:`n   Configuracion > Aplicaciones > Inicio.`n   Solo deja activos los que usas todos los dias.`n"
        $n++
    }
    if ($primaryUse -eq "Navegacion" -or $mainConcern -eq "WiFi") {
        $cortoItems += "$n. Conéctate por cable Ethernet si tu notebook tiene puerto:`n   Es mas estable y rapido que el WiFi para navegacion y videollamadas.`n"
        $n++
    }
    $cortoItems += "$n. Reinicia la notebook al menos una vez por semana:`n   Libera memoria RAM acumulada y aplica actualizaciones pendientes.`n"

    $n = 1
    foreach ($f in $findingsMediano) {
        $medianoItems += Format-FindingLine -Finding $f -TechLevel $techLevel -Num $n
        $n++
    }
    $daysSinceNum = 0
    if ($daysSince -match '^\d+$') { $daysSinceNum = [int]$daysSince }
    if ($daysSinceNum -gt 30 -or $daysSince -eq '--') {
        $medianoItems += "$n. Actualiza Windows:`n   Configuracion > Windows Update > Buscar actualizaciones.`n   Las actualizaciones corrigen problemas de seguridad y rendimiento.`n"
        $n++
    }
    if ($hasHDD) {
        $medianoItems += "$n. Desfragmenta el disco mensualmente:`n   Inicio > Optimizar unidades > Seleccionar C: > Optimizar.`n   Solo aplica a discos HDD; los SSD se optimizan solos.`n"
        $n++
    }
    if ($detectedPUPs.Count -gt 0) {
        $medianoItems += "$n. Desinstala el software no deseado detectado:`n   Configuracion > Aplicaciones > busca y desinstala: $($detectedPUPs -join ', ').`n"
        $n++
    }
    $medianoItems += "$n. Limpia fisicamente los ventiladores con aire comprimido:`n   El polvo acumulado es la causa mas comun de sobrecalentamiento en notebooks.`n   Si no te animas a abrirla, pedilo en cualquier servicio tecnico (costo bajo).`n"

    $n = 1
    foreach ($f in $findingsLargo) {
        $largoItems += Format-FindingLine -Finding $f -TechLevel $techLevel -Num $n
        $n++
    }
    if ($hasHDD) {
        $hddExtra = if ($techLevel -eq 'Avanzado') { "   Clonar disco con Macrium Reflect (gratis) antes de remover el HDD." + [char]10 } else { "" }
        $largoItems += "$n. Reemplazar el disco HDD por un SSD:" + [char]10 + "   Es la mejora mas impactante que podes hacer. La diferencia es inmediata." + [char]10 + "   Costo aproximado: USD 30-80 segun capacidad." + [char]10 + $hddExtra
        $n++
    }
    if ($ramTotal -lt 8192) {
        $slotsMsg = if ($ramSlotsUsed -lt $ramSlotsTotal) { "Tenes slots de RAM disponibles." } else { "Los slots estan llenos; habria que reemplazar los modulos." }
        $ramExtra = if ($techLevel -eq 'Avanzado') { "   Verificar tipo y velocidad con CPU-Z antes de comprar." + [char]10 } else { "" }
        $largoItems += "$n. Ampliar la memoria RAM a 8 GB o 16 GB:" + [char]10 + "   $slotsMsg" + [char]10 + "   Costo aproximado: USD 20-50 por modulo de 8 GB." + [char]10 + $ramExtra
        $n++
    }
    if ($null -ne $battHealth -and $battHealth -lt 80) {
        $urgencia = if ($battHealth -lt 60) { "Recomendado pronto: la bateria puede apagarse sin aviso." } else { "Considerar en el proximo ano." }
        $largoItems += "$n. Reemplazo de bateria:`n   $urgencia`n   Llevar a servicio tecnico con el modelo del equipo para cotizar.`n"
        $n++
    }
    if ($primaryUse -eq "Gaming" -and -not $hasDedGpu) {
        $largoItems += "$n. Para gaming exigente: upgrade a notebook con GPU dedicada:`n   Esta notebook tiene GPU integrada, con limitaciones para juegos 3D modernos.`n   Buscar modelos con NVIDIA GeForce RTX 3050 o superior.`n"
        $n++
    }
    $tempVal2 = if ($null -ne $cpuTempC) { $cpuTempC } else { 0 }
    if ($tempVal2 -gt 70) {
        $largoItems += "$n. Servicio tecnico: limpieza profunda y pasta termica:`n   Temperatura en reposo de $tempStr indica necesidad de mantenimiento interno.`n   Costo aproximado: USD 20-40. Extiende la vida util del equipo varios anos.`n"
        $n++
    }

    $planHeader = Get-TechLevelText -Level $techLevel `
        -Basico     "Este plan te dice, en palabras simples, que hacer con tu computadora:`ncuando hacerlo y si cuesta plata o no." `
        -Intermedio "Acciones organizadas por urgencia e inversion requerida. Cada seccion indica el costo aproximado y el nivel de dificultad." `
        -Avanzado   "Action plan sorted by time horizon and investment. Items within each section are ordered by impact."

    $planOptimizacion = @"
====================================================================
PLAN DE OPTIMIZACION
Fecha: $(Get-Date -Format 'dd/MM/yyyy HH:mm')
Perfil: $techLevel | Uso: $primaryUse | Preocupacion: $mainConcern
Puntaje de salud: $healthScore/100 - $healthLabel
====================================================================

$planHeader

=== CORTO PLAZO: HOY / ESTA SEMANA ===
(Sin costo - podes hacerlo vos mismo en menos de 15 minutos)

$cortoItems
=== MEDIANO PLAZO: ESTE MES ===
(Sin costo o costo minimo - requiere algo mas de tiempo)

$medianoItems
=== LARGO PLAZO: PROXIMOS MESES ===
(Requiere inversion economica o servicio tecnico)

$(if ($largoItems -ne "") { $largoItems } else { "No se identificaron mejoras de hardware urgentes para este equipo.`n" })
====================================================================
"@

    Set-Content -Path (Join-Path $reportDir "plan_optimizacion.txt") -Value $planOptimizacion -Encoding UTF8

    # ==========================================================================
    # ARCHIVO 4: detalles_tecnicos.txt
    # ==========================================================================
    $techNote = if ($techLevel -ne "Avanzado") {
        "NOTA: Este archivo contiene informacion tecnica detallada para profesionales`nde soporte. Si consultas con alguien de soporte o servicio tecnico, comparti`neste archivo para que puedan diagnosticar con precision.`n`n"
    } else { "" }

    $techLog = ($Global:TechLog) -join "`n"

    $detallesTecnicos = @"
====================================================================
LOG TECNICO COMPLETO - Optimizador Universal de Notebooks
Fecha: $(Get-Date -Format 'dd/MM/yyyy HH:mm')
Perfil de usuario: $techLevel | Uso: $primaryUse | Preocupacion: $mainConcern
====================================================================

${techNote}--- IDENTIDAD DEL EQUIPO ---
Marca:             $machineMake
Modelo:            $machineModel
Numero de serie:   $machineSerial
OS:                $osName (Build $osBuild)
Instalado el:      $osInstall

--- CPU ---
Modelo:      $cpuName
Nucleos:     $cpuCores fisicos / $cpuLogical logicos
Frecuencia:  $cpuCurrMhz MHz actual / $cpuMaxMhz MHz maxima
Carga:       $cpuLoad%
Throttling:  $(if ($cpuThrottle) { "ACTIVO (ratio $throttleRatio)" } else { "No detectado" })
Temperatura: $tempStr

--- GPU ---
$gpuStr

--- RAM ---
Total:  $ramTotal MB
Usada:  $ramUsed MB ($ramUsedPct%)
Libre:  $ramFree MB
Slots:  $ramSlotsUsed usados de $ramSlotsTotal disponibles

Top procesos por RAM:
$topRamStr

--- BATERIA ---
$battSection

--- DISCO ---
$disksStr

Espacio por unidad:
$logDiskStr

Fragmentacion:
$fragStr

--- RED ---
WiFi:      $wifiStr
Adaptador: $wifiAdapter
Latencia:  $latStr

--- PLAN DE ENERGIA ---
$ppName

--- APLICACIONES AL INICIO ---
$startupStr

--- PUPs DETECTADOS ---
$pupStr

--- VERSION DE WINDOWS ---
$winName (Build $winBuild)
Ultima actualizacion: $lastUpdate ($daysSince dias)

--- ESTADO ANTES / DESPUES ---
                           ANTES           DESPUES
RAM Libre (MB):            $("{0,-15}" -f $beforeRamFree)   $afterRamFree
RAM Usada (%):             $("{0,-15}" -f $beforeRamUsed)   $afterRamUsed
Espacio libre C: (GB):     $("{0,-15}" -f $beforeDiskFree)   $afterDiskFree
Procesos activos:          $("{0,-15}" -f $beforeProcCount)   $afterProcCount

Espacio total liberado: $freed

--- LOG DE EVENTOS ---
$techLog
"@

    Set-Content -Path (Join-Path $reportDir "detalles_tecnicos.txt") -Value $detallesTecnicos -Encoding UTF8

    # -- 5.5  Finalizar --------------------------------------------------------
    Show-ProgressStep -Current 5 -Total 5 -Label "Finalizando..."

    $Global:SystemData.ReportFolder = $reportDir
    Add-TechLog "Reporte generado en: $reportDir"

    Write-Host ""
    Write-Color "  Carpeta de resultados:" -Color Cyan
    Write-Color "     $reportDir" -Color White
    Write-Host ""
    Write-Color "      diagnostico_equipo.txt   -> Ficha tecnica del equipo" -Color DarkGray
    Write-Color "      analisis_funcional.txt   -> Analisis adaptado a tu perfil" -Color DarkGray
    Write-Color "      plan_optimizacion.txt    -> Que hacer (corto, mediano y largo plazo)" -Color DarkGray
    Write-Color "      detalles_tecnicos.txt    -> Log completo para soporte tecnico" -Color DarkGray
    Write-Host ""
}
