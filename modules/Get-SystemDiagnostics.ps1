# =============================================================================
# Get-SystemDiagnostics.ps1  -  Modulo 1: Diagnostico completo del sistema
# =============================================================================

function Invoke-SystemDiagnostics {

    Show-StageIntro -StageNum 1 -TotalStages 6 `
        -Title "Diagnostico del Sistema" `
        -Duration "Aproximadamente 30 a 60 segundos" `
        -WhatItDoes "Vamos a revisar el estado de tu procesador, memoria RAM, disco duro, bateria, WiFi y temperatura. Solo estamos leyendo informacion ? no se modifica nada." `
        -Instructions "Solo espera. No necesitas hacer nada durante esta etapa."

    $data = @{}
    $goodNews = @()
    $concerns = @()

    # -- 1.1  CPU ------------------------------------------------------------
    Show-ProgressStep -Current 1 -Total 7 -Label "Analizando procesador (CPU)..."

    try {
        $cpu = Get-WmiObject -Class Win32_Processor -ErrorAction Stop | Select-Object -First 1
        $data.CpuName        = $cpu.Name.Trim()
        $data.CpuCores       = $cpu.NumberOfCores
        $data.CpuLogical     = $cpu.NumberOfLogicalProcessors
        $data.CpuMaxMhz      = $cpu.MaxClockSpeed
        $data.CpuCurrentMhz  = $cpu.CurrentClockSpeed
        $data.CpuLoad        = $cpu.LoadPercentage

        # Throttling termico: frecuencia actual < 85% de la maxima
        $throttleRatio = if ($cpu.MaxClockSpeed -gt 0) {
            [Math]::Round($cpu.CurrentClockSpeed / $cpu.MaxClockSpeed, 2)
        } else { 1 }
        $data.CpuThrottling = ($throttleRatio -lt 0.85)

        Add-TechLog "CPU: $($data.CpuName) | Nucleos: $($data.CpuCores) | Freq: $($data.CpuCurrentMhz) MHz / $($data.CpuMaxMhz) MHz | Carga: $($data.CpuLoad)% | Ratio: $throttleRatio"

        if ($data.CpuThrottling) {
            $concerns += "Tu procesador esta funcionando mas lento de lo normal (posiblemente por calor)."
            Add-Finding -Category "CPU" -Issue "Throttling termico activo (ratio $throttleRatio)" `
                -Recommendation "Limpiar el ventilador de la notebook y aplicar pasta termica si tiene mas de 3 anos." `
                -Severity "Alto" -ScorePenalty 15
        } else {
            $goodNews += "Tu procesador esta funcionando a velocidad normal."
        }
    } catch {
        Add-TechLog "ERROR leyendo CPU: $_"
        $data.CpuError = $true
    }

    # -- 1.2  Temperatura CPU -------------------------------------------------
    Show-ProgressStep -Current 2 -Total 7 -Label "Leyendo temperatura..."

    try {
        $tempZones = Get-WmiObject -Namespace "root/wmi" `
                                   -Class MSAcpi_ThermalZoneTemperature `
                                   -ErrorAction Stop
        if ($tempZones) {
            # Los valores estan en decimas de Kelvin
            $kelvin  = ($tempZones | Measure-Object -Property CurrentTemperature -Maximum).Maximum
            $celsius = [Math]::Round(($kelvin / 10) - 273.15, 1)
            $data.CpuTempC = $celsius
            Add-TechLog "Temperatura CPU (ACPI): $celsius degC"

            if ($celsius -gt 90) {
                $concerns += "Tu procesador esta muy caliente ($celsius degC). Esto puede danar el equipo."
                Add-Finding -Category "Temperatura" -Issue "CPU a $celsius degC ? temperatura critica" `
                    -Recommendation "Apaga la notebook y revisa que el ventilador no este tapado. Lleva a servicio tecnico si persiste." `
                    -Severity "Alto" -ScorePenalty 15
            } elseif ($celsius -gt 70) {
                $concerns += "Tu procesador esta un poco caliente ($celsius degC). Asegurate de usar la notebook en una superficie dura y plana."
                Add-Finding -Category "Temperatura" -Issue "CPU a $celsius degC ? temperatura elevada en reposo" `
                    -Recommendation "Usar la notebook en superficie rigida, no sobre camas o almohadones. Limpiar ventiladores." `
                    -Severity "Medio" -ScorePenalty 10
            } else {
                $goodNews += "La temperatura del procesador es normal ($celsius degC)."
            }
        } else {
            $data.CpuTempC = $null
            Write-Color "     Temperatura no disponible en este equipo." -Color DarkGray
            Add-TechLog "MSAcpi_ThermalZoneTemperature: sin datos reportados."
        }
    } catch {
        $data.CpuTempC = $null
        Write-Color "     Temperatura no disponible en este equipo." -Color DarkGray
        Add-TechLog "Temperatura CPU: no disponible via WMI ($($_.Exception.Message))"
    }

    # -- 1.3  RAM -------------------------------------------------------------
    Show-ProgressStep -Current 3 -Total 7 -Label "Analizando memoria RAM..."

    try {
        $os = Get-WmiObject -Class Win32_OperatingSystem -ErrorAction Stop
        $totalRamMB = [Math]::Round($os.TotalVisibleMemorySize / 1KB, 0)
        $freeRamMB  = [Math]::Round($os.FreePhysicalMemory   / 1KB, 0)
        $usedRamMB  = $totalRamMB - $freeRamMB
        $usedPct    = [Math]::Round(($usedRamMB / $totalRamMB) * 100, 0)

        $data.RamTotalMB = $totalRamMB
        $data.RamFreeMB  = $freeRamMB
        $data.RamUsedMB  = $usedRamMB
        $data.RamUsedPct = $usedPct

        # Top 5 procesos por RAM
        $topProcs = Get-Process -ErrorAction SilentlyContinue |
                    Sort-Object WorkingSet64 -Descending |
                    Select-Object -First 5 |
                    ForEach-Object {
                        @{ Name = $_.ProcessName; MB = [Math]::Round($_.WorkingSet64/1MB,0) }
                    }
        $data.TopRamProcesses = $topProcs

        Add-TechLog ("RAM Total: {0} MB | Usada: {1} MB ({2}%) | Libre: {3} MB" -f $totalRamMB, $usedRamMB, $usedPct, $freeRamMB)

        if ($totalRamMB -lt 4096) {
            $concerns += "Tenes muy poca memoria RAM ($totalRamMB MB). Tu computadora puede ir muy lenta."
            Add-Finding -Category "RAM" -Issue "RAM total $totalRamMB MB ? inferior a 4 GB" `
                -Recommendation "Considera actualizar la RAM a al menos 8 GB para un uso comodo en 2024+." `
                -Severity "Alto" -ScorePenalty 15
        } elseif ($totalRamMB -lt 8192) {
            $concerns += "Tenes $totalRamMB MB de RAM. Es suficiente para uso basico, pero puede quedarse corta con varias pestanas abiertas."
            Add-Finding -Category "RAM" -Issue "RAM total $totalRamMB MB ? menos de 8 GB" `
                -Recommendation "Si notas lentitud con varias aplicaciones abiertas, considera ampliar la RAM a 8 GB o mas." `
                -Severity "Medio" -ScorePenalty 10
        } else {
            $goodNews += "Tenes $totalRamMB MB de RAM. Eso es suficiente para la mayoria de usos."
        }

        if ($usedPct -gt 85) {
            $concerns += "Estas usando el $usedPct% de tu RAM ahora mismo. Cerr? las aplicaciones que no uses."
        }

        # Slots de RAM
        try {
            $memArray  = Get-WmiObject Win32_PhysicalMemoryArray -ErrorAction Stop | Select-Object -First 1
            $ramSticks = Get-WmiObject Win32_PhysicalMemory -ErrorAction Stop
            $data.RamSlotsTotal = $memArray.MemoryDevices
            $data.RamSlotsUsed  = ($ramSticks | Measure-Object).Count
            Add-TechLog "Slots de RAM: $($data.RamSlotsUsed) usados de $($data.RamSlotsTotal) disponibles"
        } catch {
            Add-TechLog "No se pudieron leer los slots de RAM: $_"
        }

    } catch {
        Add-TechLog "ERROR leyendo RAM: $_"
    }

    # -- 1.4  Bateria ----------------------------------------------------------
    Show-ProgressStep -Current 4 -Total 7 -Label "Revisando bateria..."

    try {
        $bat = Get-WmiObject -Class Win32_Battery -ErrorAction Stop | Select-Object -First 1
        if ($bat) {
            $data.BatteryName       = $bat.Name
            $data.BatteryStatus     = $bat.BatteryStatus
            $data.BatteryCharge     = $bat.EstimatedChargeRemaining
            $data.BatteryRuntime    = $bat.EstimatedRunTime

            # Capacidad disenada vs actual via CIM
            try {
                $cimBat = Get-CimInstance -Namespace "root/wmi" -ClassName BatteryFullChargedCapacity -ErrorAction Stop |
                          Select-Object -First 1
                $cimStatic = Get-CimInstance -Namespace "root/wmi" -ClassName BatteryStaticData -ErrorAction Stop |
                             Select-Object -First 1
                if ($cimBat -and $cimStatic -and $cimStatic.DesignedCapacity -gt 0) {
                    $data.BatteryDesignedMWh = $cimStatic.DesignedCapacity
                    $data.BatteryCurrentMWh  = $cimBat.FullChargedCapacity
                    $data.BatteryHealthPct   = [Math]::Round(($cimBat.FullChargedCapacity / $cimStatic.DesignedCapacity) * 100, 1)
                    Add-TechLog "Bateria: capacidad disenada $($data.BatteryDesignedMWh) mWh | actual $($data.BatteryCurrentMWh) mWh | salud $($data.BatteryHealthPct)%"

                    if ($data.BatteryHealthPct -lt 60) {
                        $concerns += "Tu bateria solo tiene el $($data.BatteryHealthPct)% de su capacidad original. DurA mucho menos que cuando era nueva."
                        Add-Finding -Category "Bateria" -Issue "Salud de bateria: $($data.BatteryHealthPct)% ? degradacion severa" `
                            -Recommendation "Considerar reemplazar la bateria. A este nivel la autonomia es muy corta y puede apagarse sin previo aviso." `
                            -Severity "Alto" -ScorePenalty 15
                    } elseif ($data.BatteryHealthPct -lt 80) {
                        $concerns += "Tu bateria tiene el $($data.BatteryHealthPct)% de su capacidad original. Dura menos que antes."
                        Add-Finding -Category "Bateria" -Issue "Salud de bateria: $($data.BatteryHealthPct)% ? degradacion notable" `
                            -Recommendation "La bateria esta desgastada. Considera reemplazarla en el corto plazo." `
                            -Severity "Medio" -ScorePenalty 10
                    } else {
                        $goodNews += "Tu bateria esta en buen estado ($($data.BatteryHealthPct)% de capacidad original)."
                    }
                }
            } catch {
                Add-TechLog "CIM bateria no disponible: $_"
                $data.BatteryHealthPct = $null
            }

            # Plan de energia
            try {
                $planOutput = & powercfg /getactivescheme 2>$null
                $data.PowerPlan = $planOutput -replace ".*:\s+", "" -replace "\(.*\)", "" | ForEach-Object { $_.Trim() } | Select-Object -First 1
                Add-TechLog "Plan de energia activo: $($data.PowerPlan)"
            } catch {
                $data.PowerPlan = "No disponible"
            }

        } else {
            $data.BatteryPresent = $false
            Add-TechLog "No se detecto bateria (puede ser PC de escritorio o bateria no reportada)."
        }
    } catch {
        Add-TechLog "ERROR leyendo bateria: $_"
    }

    # -- 1.5  Disco ------------------------------------------------------------
    Show-ProgressStep -Current 5 -Total 7 -Label "Revisando disco y almacenamiento..."

    try {
        $disks = Get-PhysicalDisk -ErrorAction Stop
        $data.Disks = @()
        foreach ($disk in $disks) {
            $diskInfo = @{
                Model       = $disk.FriendlyName
                MediaType   = $disk.MediaType
                Health      = $disk.HealthStatus
                Operational = $disk.OperationalStatus
                SizeGB      = [Math]::Round($disk.Size / 1GB, 1)
            }
            $data.Disks += $diskInfo
            Add-TechLog "Disco: $($disk.FriendlyName) | Tipo: $($disk.MediaType) | Salud: $($disk.HealthStatus) | Tamano: $($diskInfo.SizeGB) GB"

            if ($disk.MediaType -eq "HDD") {
                $concerns += "Tu disco es mecanico (HDD). Los SSD son entre 5 y 10 veces mas rapidos."
                Add-Finding -Category "Disco" -Issue "Disco HDD detectado: $($disk.FriendlyName)" `
                    -Recommendation "Reemplazar el HDD por un SSD es la mejora mas impactante que podes hacer en esta notebook. La diferencia en velocidad es inmediata." `
                    -Severity "Alto" -ScorePenalty 20
            } elseif ($disk.MediaType -in @("SSD","NVMe","Unspecified")) {
                $goodNews += "Tu disco es SSD o NVMe. Eso es bueno para la velocidad."
            }

            if ($disk.HealthStatus -ne "Healthy") {
                $concerns += "Tu disco puede tener problemas. Estado reportado: $($disk.HealthStatus)."
                Add-Finding -Category "Disco" -Issue "Disco con estado no saludable: $($disk.HealthStatus)" `
                    -Recommendation "Hace una copia de seguridad inmediatamente. Un disco con problemas puede fallar sin aviso." `
                    -Severity "Alto" -ScorePenalty 20
            }
        }
    } catch {
        Add-TechLog "Get-PhysicalDisk no disponible: $_ ? usando WMI fallback"
        try {
            $wmiDisks = Get-WmiObject Win32_DiskDrive -ErrorAction Stop
            $data.Disks = $wmiDisks | ForEach-Object {
                @{ Model = $_.Model; SizeGB = [Math]::Round($_.Size/1GB,1); MediaType = "Desconocido" }
            }
        } catch { Add-TechLog "ERROR leyendo discos via WMI: $_" }
    }

    # Espacio logico por unidad
    try {
        $logicalDisks = Get-WmiObject Win32_LogicalDisk -Filter "DriveType=3" -ErrorAction Stop
        $data.LogicalDisks = @()
        foreach ($ld in $logicalDisks) {
            $freePct = if ($ld.Size -gt 0) { [Math]::Round(($ld.FreeSpace / $ld.Size) * 100, 1) } else { 0 }
            $ldInfo  = @{
                Drive   = $ld.DeviceID
                TotalGB = [Math]::Round($ld.Size / 1GB, 1)
                FreeGB  = [Math]::Round($ld.FreeSpace / 1GB, 1)
                FreePct = $freePct
            }
            $data.LogicalDisks += $ldInfo
            Add-TechLog "Unidad $($ld.DeviceID): $($ldInfo.FreeGB) GB libres de $($ldInfo.TotalGB) GB ($freePct% libre)"

            if ($freePct -lt 10) {
                $concerns += "Tu disco $($ld.DeviceID) tiene muy poco espacio libre ($($ldInfo.FreeGB) GB)."
                Add-Finding -Category "Disco" -Issue "Espacio libre critico en $($ld.DeviceID): $($ldInfo.FreeGB) GB ($freePct%)" `
                    -Recommendation "Elimina archivos innecesarios o mueve fotos/videos a un disco externo o la nube. Con menos del 10% libre, Windows puede ir muy lento." `
                    -Severity "Alto" -ScorePenalty 10
            } elseif ($freePct -lt 20) {
                $concerns += "Queda poco espacio en $($ld.DeviceID) ($($ldInfo.FreeGB) GB libres)."
                Add-Finding -Category "Disco" -Issue "Espacio libre bajo en $($ld.DeviceID): $($ldInfo.FreeGB) GB ($freePct%)" `
                    -Recommendation "Libera espacio pronto. La limpieza de esta herramienta puede ayudar." `
                    -Severity "Medio" -ScorePenalty 5
            }
        }
    } catch {
        Add-TechLog "ERROR leyendo discos logicos: $_"
    }

    # -- 1.6  Red / WiFi -------------------------------------------------------
    Show-ProgressStep -Current 6 -Total 7 -Label "Revisando conectividad de red..."

    try {
        $wlanOutput = & netsh wlan show interfaces 2>$null
        if ($wlanOutput) {
            $ssid    = ($wlanOutput | Select-String "SSID\s+:\s(.+)" | ForEach-Object { $_.Matches[0].Groups[1].Value.Trim() } | Select-Object -First 1)
            $signal  = ($wlanOutput | Select-String "Signal\s+:\s(.+)" | ForEach-Object { $_.Matches[0].Groups[1].Value.Trim() } | Select-Object -First 1)
            $adapter = ($wlanOutput | Select-String "Description\s+:\s(.+)" | ForEach-Object { $_.Matches[0].Groups[1].Value.Trim() } | Select-Object -First 1)
            $data.WifiSSID    = $ssid
            $data.WifiSignal  = $signal
            $data.WifiAdapter = $adapter
            Add-TechLog "WiFi: $ssid | Senal: $signal | Adaptador: $adapter"

            $signalPct = [int]($signal -replace "[^0-9]","")
            if ($signalPct -gt 0 -and $signalPct -lt 40) {
                $concerns += "La senal WiFi es debil ($signal). Esto puede causar lentitud al navegar."
                Add-Finding -Category "Red" -Issue "Senal WiFi baja: $signal" `
                    -Recommendation "Acercate al router o considera usar un extensor WiFi. La conexion por cable Ethernet es mas estable si tu notebook lo permite." `
                    -Severity "Medio" -ScorePenalty 5
            }
        }
    } catch {
        Add-TechLog "netsh wlan no disponible o sin WiFi: $_"
    }

    # Latencia con fallbacks
    try {
        $gateway = Get-LocalGateway
        $targets = @("8.8.8.8", "1.1.1.1")
        if ($gateway) { $targets += $gateway }
        $latency = $null
        foreach ($target in $targets) {
            try {
                $ping = Test-Connection -ComputerName $target -Count 2 -ErrorAction Stop |
                        Measure-Object -Property ResponseTime -Average
                $latency = [Math]::Round($ping.Average, 0)
                $data.NetworkLatencyMs = $latency
                $data.NetworkLatencyTarget = $target
                Add-TechLog "Latencia red a $target : $latency ms"
                break
            } catch { <# siguiente fallback #> }
        }
        if (-not $latency) {
            $data.NetworkLatencyMs = $null
            Add-TechLog "Sin conectividad a ninguno de los servidores de prueba."
        }
    } catch {
        Add-TechLog "ERROR midiendo latencia: $_"
    }

    # -- 1.7  Snapshot BeforeState ---------------------------------------------
    Show-ProgressStep -Current 7 -Total 7 -Label "Guardando estado inicial..."

    $Global:BeforeState.RamFreeMB    = $data.RamFreeMB
    $Global:BeforeState.RamUsedPct   = $data.RamUsedPct
    $Global:BeforeState.ProcessCount = (Get-Process -ErrorAction SilentlyContinue | Measure-Object).Count
    if ($data.LogicalDisks) {
        $Global:BeforeState.DiskFreeGB = ($data.LogicalDisks | Where-Object { $_.Drive -eq "C:" } | Select-Object -First 1).FreeGB
    }

    $Global:SystemData.Diagnostics = $data
    Add-TechLog "Diagnostico completo. BeforeState registrado."

    Show-MiniSummary -ModuleName "Diagnostico del Sistema" -GoodNews $goodNews -Concerns $concerns
}
