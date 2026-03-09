# =============================================================================
# Get-BottleneckAnalysis.ps1  -  Modulo 4: Identificacion de Cuellos de Botella
# =============================================================================

# Builds de Windows 10/11 conocidos como actualizados (a la fecha del script)
$Script:KnownCurrentBuilds = @{
    "10.0.19045" = "Windows 10 22H2"   # Build mas reciente de Win10
    "10.0.22621" = "Windows 11 22H2"
    "10.0.22631" = "Windows 11 23H2"
    "10.0.26100" = "Windows 11 24H2"
}

function Invoke-BottleneckAnalysis {

    Show-StageIntro -StageNum 4 -TotalStages 6 `
        -Title "Identificacion de Cuellos de Botella" `
        -Duration "Aproximadamente 1 a 2 minutos" `
        -WhatItDoes "Vamos a identificar que componentes de hardware o software estan limitando el rendimiento de tu notebook. Buscaremos problemas de procesador, disco, memoria y refrigeracion." `
        -Instructions "Solo espera. Analizaremos lo que ya recopilamos y haremos algunas verificaciones adicionales."

    $data     = @{}
    $goodNews = @()
    $concerns = @()
    $diag     = $Global:SystemData.Diagnostics

    # -- 4.1  Throttling termico -----------------------------------------------
    Show-ProgressStep -Current 1 -Total 8 -Label "Verificando throttling termico..."

    try {
        $cpu = Get-WmiObject Win32_Processor -ErrorAction Stop | Select-Object -First 1
        $ratio = if ($cpu.MaxClockSpeed -gt 0) {
            [Math]::Round($cpu.CurrentClockSpeed / $cpu.MaxClockSpeed, 2)
        } else { 1 }
        $data.ThrottleRatio = $ratio
        $data.ThrottlingActive = ($ratio -lt 0.85)

        Add-TechLog "Throttle ratio: $ratio (max $($cpu.MaxClockSpeed) MHz, actual $($cpu.CurrentClockSpeed) MHz)"

        if ($data.ThrottlingActive) {
            $pctOfMax = [Math]::Round($ratio * 100, 0)
            $concerns += "Tu procesador esta funcionando al $pctOfMax% de su velocidad maxima por temperatura elevada."
            # Ya penalizado en Modulo 1; solo registrar si no fue registrado antes
        } else {
            $goodNews += "Tu procesador corre a velocidad completa. No hay throttling termico."
        }
    } catch {
        Add-TechLog "No se pudo verificar throttling: $_"
    }

    # -- 4.2  Temperatura en reposo ---------------------------------------------
    Show-ProgressStep -Current 2 -Total 8 -Label "Evaluando temperatura en reposo..."

    $tempC   = if ($diag -and $diag.ContainsKey('CpuTempC')) { $diag.CpuTempC } else { $null }
    $cpuLoad = if ($diag -and $diag.ContainsKey('CpuLoad') -and $diag.CpuLoad -ne $null) { $diag.CpuLoad } else { 50 }

    if ($tempC -and $tempC -gt 70 -and $cpuLoad -lt 20) {
        $concerns += "Tu procesador esta caliente ($tempC degC) incluso sin casi nada abierto. Puede que el ventilador este tapado de polvo."
        Add-Finding -Category "Refrigeracion" -Issue "Temperatura alta en reposo: $tempC degC con $cpuLoad% de carga" `
            -Recommendation "Limpiar el interior de la notebook con aire comprimido. Asegurarse de que la rejilla de ventilacion no este bloqueada. Usar la notebook en superficie dura y plana." `
            -Severity "Alto" -ScorePenalty 10
    } elseif ($tempC -and $tempC -le 70) {
        $goodNews += "La temperatura en reposo es normal ($tempC degC)."
    }

    # -- 4.3  RAM limitante ----------------------------------------------------
    Show-ProgressStep -Current 3 -Total 8 -Label "Evaluando memoria RAM..."

    $ramTotalMB = if ($diag -and $diag.ContainsKey('RamTotalMB') -and $diag.RamTotalMB) { $diag.RamTotalMB } else { 0 }
    $slotsUsed  = if ($diag -and $diag.ContainsKey('RamSlotsUsed')  -and $diag.RamSlotsUsed)  { $diag.RamSlotsUsed  } else { 0 }
    $slotsTotal = if ($diag -and $diag.ContainsKey('RamSlotsTotal') -and $diag.RamSlotsTotal) { $diag.RamSlotsTotal } else { 0 }
    $data.RamLimiting = $false

    if ($ramTotalMB -gt 0 -and $ramTotalMB -lt 8192) {
        $data.RamLimiting = $true
        $slotsMsg = if ($slotsTotal -gt 0) { " (Slots: $slotsUsed/$slotsTotal usados)" } else { "" }
        $concerns += "La RAM ($ramTotalMB MB) es el principal limitante de rendimiento$slotsMsg."

        if ($slotsUsed -lt $slotsTotal -or $slotsTotal -eq 0) {
            Add-Finding -Category "RAM" -Issue "RAM insuficiente ($ramTotalMB MB) con slots disponibles" `
                -Recommendation "Tenes espacios de RAM libres. Agregar mas RAM (hasta llegar a 8 GB o 16 GB) es una mejora costo-efectiva." `
                -Severity "Alto" -ScorePenalty 0  # ya penalizado en Modulo 1
        } else {
            Add-Finding -Category "RAM" -Issue "RAM insuficiente ($ramTotalMB MB) sin slots disponibles" `
                -Recommendation "Los slots de RAM estan todos ocupados. Para mas memoria habria que reemplazar los modulos existentes o considerar un equipo nuevo." `
                -Severity "Alto" -ScorePenalty 0
        }
    } elseif ($ramTotalMB -ge 8192) {
        $goodNews += "La RAM ($ramTotalMB MB) es suficiente para un uso normal."
    }

    # -- 4.4  Disco HDD + fragmentacion ----------------------------------------
    Show-ProgressStep -Current 4 -Total 8 -Label "Verificando tipo de disco y fragmentacion..."

    $diagDisks  = if ($diag -and $diag.ContainsKey('Disks')) { $diag.Disks } else { @() }
    $hasHDD     = ($diagDisks | Where-Object { $_.MediaType -eq "HDD" } | Measure-Object).Count -gt 0
    $data.HasHDD = $hasHDD

    if ($hasHDD) {
        # Intentar analisis de fragmentacion
        try {
            $volumes = Get-WmiObject -Class Win32_Volume -Filter "DriveType=3 AND FileSystem='NTFS'" -ErrorAction Stop
            $fragResults = @()
            foreach ($vol in $volumes) {
                try {
                    $analysis = $vol.DefragAnalysis()
                    if ($analysis.ReturnValue -eq 0) {
                        $fragPct = $analysis.DefragAnalysis.FilePercentFragmentation
                        $fragResults += @{ Drive = $vol.DriveLetter; FragPct = $fragPct }
                        Add-TechLog "Fragmentacion $($vol.DriveLetter): $fragPct%"
                        if ($fragPct -gt 10) {
                            Add-Finding -Category "Disco" `
                                -Issue "Fragmentacion en $($vol.DriveLetter): $fragPct%" `
                                -Recommendation "Desfragmentar el disco desde 'Optimizar unidades' en el menu de inicio. Hacerlo mensualmente en discos HDD." `
                                -Severity "Medio" -ScorePenalty 5
                            $concerns += "El disco $($vol.DriveLetter) tiene $fragPct% de fragmentacion. Necesita desfragmentacion."
                        }
                    }
                } catch { <# algunos volumenes no soportan DefragAnalysis #> }
            }
            $data.FragmentationResults = $fragResults
        } catch {
            Add-TechLog "DefragAnalysis no disponible: $_"
        }
    } else {
        $goodNews += "Tu disco es SSD/NVMe. No requiere desfragmentacion."
    }

    # -- 4.5  Degradacion de bateria -------------------------------------------
    Show-ProgressStep -Current 5 -Total 8 -Label "Re-verificando salud de bateria..."

    $battHealth = if ($diag -and $diag.ContainsKey('BatteryHealthPct')) { $diag.BatteryHealthPct } else { $null }
    if ($battHealth) {
        $data.BatteryHealth = $battHealth
        # La penalizacion ya fue aplicada en Modulo 1; calculamos vida restante aqui
        if ($battHealth -lt 100) {
            $degradedPct = 100 - $battHealth
            # Estimacion simple: si perdio X% en N anos, le quedan proporcional
            # Asumimos promedio 3 anos = 20% degradacion
            $estimatedMonthsLeft = if ($degradedPct -lt 80) {
                [Math]::Round(((80 - $degradedPct) / 80) * 36, 0)
            } else { 0 }
            $data.BatteryEstimatedMonthsLeft = $estimatedMonthsLeft
            Add-TechLog "Salud bateria: $battHealth% | Estimacion de vida restante: $estimatedMonthsLeft meses"
        }
    }

    # -- 4.6  Procesos con alto consumo sostenido -------------------------------
    Show-ProgressStep -Current 6 -Total 8 -Label "Buscando procesos que consumen muchos recursos..."

    try {
        # Medir CPU 2 veces con 2s de intervalo para obtener uso real
        $procs1 = Get-Process -ErrorAction SilentlyContinue | Select-Object Id, Name,
            @{N="CPU1";E={$_.CPU}}, @{N="WS";E={$_.WorkingSet64}}
        Start-Sleep -Seconds 2
        $procs2 = Get-Process -ErrorAction SilentlyContinue

        $highCPUProcs  = @()
        $highRAMProcs  = @()

        foreach ($p2 in $procs2) {
            $p1 = $procs1 | Where-Object { $_.Id -eq $p2.Id } | Select-Object -First 1
            if ($p1 -and ($p2.CPU - $p1.CPU1) -gt 4) {  # >2 CPU-segundos en 2s = >100% de 1 core
                $highCPUProcs += $p2.ProcessName
            }
            if ($p2.WorkingSet64 -gt 1.5GB) {
                $highRAMProcs += @{ Name = $p2.ProcessName; MB = [Math]::Round($p2.WorkingSet64/1MB, 0) }
            }
        }

        $data.HighCPUProcesses = $highCPUProcs | Select-Object -Unique
        $data.HighRAMProcesses = $highRAMProcs

        if ($highCPUProcs.Count -gt 0) {
            $concerns += "Estos procesos consumen mucha CPU ahora mismo: $($highCPUProcs -join ', ')"
            Add-Finding -Category "CPU" `
                -Issue "Procesos con alto consumo de CPU: $($highCPUProcs -join ', ')" `
                -Recommendation "Considera cerrar o reiniciar estas aplicaciones si no las necesitas en este momento." `
                -Severity "Medio" -ScorePenalty 5
        }
        if ($highRAMProcs.Count -gt 0) {
            $names = ($highRAMProcs | ForEach-Object { "$($_.Name) ($($_.MB) MB)" }) -join ", "
            $concerns += "Procesos usando mucha RAM: $names"
            Add-Finding -Category "RAM" `
                -Issue "Procesos con alto consumo de RAM: $names" `
                -Recommendation "Cierra las aplicaciones que no estes usando para liberar memoria." `
                -Severity "Medio" -ScorePenalty 5
        }

        if ($highCPUProcs.Count -eq 0 -and $highRAMProcs.Count -eq 0) {
            $goodNews += "Ningun proceso esta consumiendo recursos de forma excesiva ahora mismo."
        }
    } catch {
        Add-TechLog "Error analizando procesos: $_"
    }

    # -- 4.7  Version de Windows ------------------------------------------------
    Show-ProgressStep -Current 7 -Total 8 -Label "Verificando version de Windows..."

    try {
        $osVersion = [System.Environment]::OSVersion.Version
        $buildKey  = "$($osVersion.Major).$($osVersion.Minor).$($osVersion.Build)"
        # Verificar si el build es al menos el minimo conocido de Windows 10
        $isCurrentBuild = $false
        foreach ($k in $Script:KnownCurrentBuilds.Keys) {
            if ($k -like "$($osVersion.Major).$($osVersion.Minor).*") {
                $kBuild = [int]($k.Split(".")[-1])
                if ($osVersion.Build -ge $kBuild) { $isCurrentBuild = $true }
            }
        }

        $data.WindowsBuild = $buildKey
        $data.WindowsName  = (Get-WmiObject Win32_OperatingSystem -ErrorAction SilentlyContinue).Caption

        Add-TechLog "Windows: $($data.WindowsName) | Build: $buildKey"

        if ($osVersion.Major -eq 10 -and $osVersion.Build -lt 19041) {
            $concerns += "Tu version de Windows esta desactualizada (Build $($osVersion.Build))."
            Add-Finding -Category "Windows" -Issue "Version de Windows antigua: Build $($osVersion.Build)" `
                -Recommendation "Actualiza Windows a la version mas reciente disponible para tu equipo desde Configuracion > Windows Update." `
                -Severity "Alto" -ScorePenalty 10
        } else {
            $goodNews += "Version de Windows: $($data.WindowsName) (Build $($osVersion.Build)) ? aceptable."
        }
    } catch {
        Add-TechLog "Error leyendo version de Windows: $_"
    }

    # -- 4.8  Numero de procesos activos ---------------------------------------
    Show-ProgressStep -Current 8 -Total 8 -Label "Contando procesos activos..."

    $procCount = (Get-Process -ErrorAction SilentlyContinue | Measure-Object).Count
    $data.ProcessCount = $procCount
    Add-TechLog "Procesos activos: $procCount"

    if ($procCount -gt 150) {
        $concerns += "Hay $procCount procesos activos. Esto puede sobrecargar el sistema."
        Add-Finding -Category "Rendimiento" -Issue "$procCount procesos activos ? cantidad elevada" `
            -Recommendation "Reinicia la computadora y revisa los programas de inicio para reducir la carga." `
            -Severity "Bajo" -ScorePenalty 3
    } else {
        $goodNews += "Cantidad de procesos activos: $procCount ? normal."
    }

    $Global:SystemData.Bottlenecks = $data
    Add-TechLog "Analisis de cuellos de botella completo."
    Show-MiniSummary -ModuleName "Cuellos de Botella" -GoodNews $goodNews -Concerns $concerns
}
