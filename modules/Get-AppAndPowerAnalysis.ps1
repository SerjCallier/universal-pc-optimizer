# =============================================================================
# Get-AppAndPowerAnalysis.ps1  -  Modulo 3: Revision de Aplicaciones y Energia
# =============================================================================

# Lista de PUPs conocidos (nombres parciales, busqueda case-insensitive)
$Script:KnownPUPs = @(
    "Ask Toolbar","Ask.com","AskPartnerNetwork","Babylon","OpenCandy","Conduit",
    "Delta Toolbar","iLivid","Search Protect","MyPCBackup","PC Speed Maximizer",
    "SpeedUpMyPC","Optimizer Pro","RegClean Pro","Advanced SystemCare","Driver Easy",
    "Driver Booster","Driver Updater","WinZip Registry Optimizer","Reimage",
    "MySearchDial","SearchManager","Trovi","Yontoo","BonanzaDeals","Coupon Printer",
    "SweetPacks","MyStartSearch","Bing Bar","Browser Manager","PC Performer"
)

function Invoke-AppAndPowerAnalysis {

    Show-StageIntro -StageNum 3 -TotalStages 6 `
        -Title "Aplicaciones y Plan de Energia" `
        -Duration "Aproximadamente 1 a 2 minutos" `
        -WhatItDoes "Vamos a revisar que programas arrancan con Windows, cuales consumen bateria innecesariamente, si hay software no deseado instalado, y si el plan de energia es el mas adecuado." `
        -Instructions "Solo espera. Al final te mostraremos lo que encontramos."

    $data     = @{}
    $goodNews = @()
    $concerns = @()

    # -- 3.1  Programas de inicio ----------------------------------------------
    Show-ProgressStep -Current 1 -Total 5 -Label "Analizando programas de inicio..."

    $startupItems = @()
    try {
        # Via WMI
        $wmiStartup = Get-CimInstance Win32_StartupCommand -ErrorAction SilentlyContinue
        foreach ($item in $wmiStartup) {
            $startupItems += @{ Name = $item.Name; Command = $item.Command; Location = $item.Location }
        }
    } catch { Add-TechLog "Win32_StartupCommand error: $_" }

    # Via Registro (HKLM y HKCU)
    $regRunPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run",
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run"
    )
    foreach ($regPath in $regRunPaths) {
        try {
            if (Test-Path $regPath) {
                $regValues = Get-ItemProperty -Path $regPath -ErrorAction SilentlyContinue
                $regValues.PSObject.Properties |
                    Where-Object { $_.Name -notmatch "^PS" } |
                    ForEach-Object {
                        if (-not ($startupItems | Where-Object { $_.Name -eq $_.Name })) {
                            $startupItems += @{ Name = $_.Name; Command = $_.Value; Location = $regPath }
                        }
                    }
            }
        } catch { Add-TechLog "Registro startup $regPath error: $_" }
    }

    # Leer impacto de arranque desde StartupApproved (0x03 = deshabilitado, 0x02 = habilitado alto impacto)
    $startupApproved = @{}
    @("HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run",
      "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run") |
    ForEach-Object {
        if (Test-Path $_) {
            $v = Get-ItemProperty $_ -ErrorAction SilentlyContinue
            $v.PSObject.Properties | Where-Object { $_.Name -notmatch "^PS" } |
                ForEach-Object { $startupApproved[$_.Name] = $_.Value[0] }
        }
    }

    $data.StartupItems = $startupItems
    $highImpactCount = 0
    foreach ($item in $startupItems) {
        $impact = if ($startupApproved.ContainsKey($item.Name)) {
            switch ($startupApproved[$item.Name]) {
                2 { "Alto impacto" }; 3 { "Deshabilitado" }; default { "Normal" }
            }
        } else { "Desconocido" }
        $item.Impact = $impact
        if ($impact -eq "Alto impacto") { $highImpactCount++ }
        Add-TechLog "Inicio: $($item.Name) | Impacto: $impact | Cmd: $($item.Command)"
    }

    if ($highImpactCount -gt 3) {
        $concerns += "Hay $highImpactCount programas con alto impacto en el arranque. Esto hace que Windows tarde mas en iniciar."
        Add-Finding -Category "Inicio" -Issue "$highImpactCount programas de alto impacto en el arranque" `
            -Recommendation "Revisa en Configuracion > Aplicaciones > Inicio y deshabilita los programas que no necesitas que arranquen con Windows." `
            -Severity "Medio" -ScorePenalty 5
    } elseif ($startupItems.Count -gt 0) {
        $goodNews += "Encontramos $($startupItems.Count) programa(s) de inicio. El impacto en el arranque es aceptable."
    }

    # -- 3.2  Aplicaciones instaladas (via Registro) ---------------------------
    Show-ProgressStep -Current 2 -Total 5 -Label "Leyendo aplicaciones instaladas..."

    $uninstallPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
    )

    $installedApps = [System.Collections.Generic.List[hashtable]]::new()
    $cutoffDate    = (Get-Date).AddDays(-90).ToString("yyyyMMdd")

    foreach ($path in $uninstallPaths) {
        if (-not (Test-Path $path)) { continue }
        Get-ChildItem -Path $path -ErrorAction SilentlyContinue | ForEach-Object {
            try {
                $props = Get-ItemProperty -Path $_.PSPath -ErrorAction SilentlyContinue
                $name  = $props.DisplayName
                if (-not $name) { return }

                $app = @{
                    Name         = $name
                    Publisher    = $props.Publisher
                    Version      = $props.DisplayVersion
                    InstallDate  = $props.InstallDate  # formato yyyyMMdd o vacio
                    EstimatedMB  = if ($props.EstimatedSize) { [Math]::Round($props.EstimatedSize / 1KB, 0) } else { 0 }
                }
                $installedApps.Add($app)
            } catch { <# saltear entradas corruptas #> }
        }
    }

    # Deduplicate by name
    $installedApps = $installedApps | Sort-Object { $_.Name } | Group-Object { $_.Name } |
                     ForEach-Object { $_.Group | Select-Object -First 1 }

    $data.InstalledApps = $installedApps
    Add-TechLog "Aplicaciones instaladas encontradas: $($installedApps.Count)"

    # -- 3.3  Deteccion de PUPs ------------------------------------------------
    Show-ProgressStep -Current 3 -Total 5 -Label "Buscando software no deseado (PUPs)..."

    $detectedPUPs = @()
    foreach ($app in $installedApps) {
        foreach ($pupName in $Script:KnownPUPs) {
            if ($app.Name -like "*$pupName*") {
                $detectedPUPs += $app.Name
                Add-TechLog "PUP detectado: $($app.Name)"
                break
            }
        }
    }
    $data.DetectedPUPs = $detectedPUPs

    if ($detectedPUPs.Count -gt 0) {
        $concerns += "Encontramos $($detectedPUPs.Count) programa(s) posiblemente no deseados."
        foreach ($pup in $detectedPUPs) {
            Add-Finding -Category "Software" -Issue "PUP potencial: $pup" `
                -Recommendation "Considera desinstalar '$pup' desde Configuracion > Aplicaciones si no lo instalaste intencionalmente. Puede consumir recursos o mostrar publicidad." `
                -Severity "Medio" -ScorePenalty 5
        }
    } else {
        $goodNews += "No se detecto software no deseado conocido."
    }

    # Apps sin uso reciente (installDate > 90 dias atras y sin actividad reciente)
    $unusedApps = @()
    foreach ($app in $installedApps) {
        if ($app.InstallDate -and $app.InstallDate.Length -eq 8) {
            if ($app.InstallDate -lt $cutoffDate) { $unusedApps += $app.Name }
        }
    }
    $data.PotentiallyUnusedApps = $unusedApps
    if ($unusedApps.Count -gt 5) {
        $concerns += "Hay $($unusedApps.Count) aplicaciones instaladas hace mas de 90 dias que pueden ya no necesitarse."
        Add-Finding -Category "Software" -Issue "$($unusedApps.Count) aplicaciones con mas de 90 dias instaladas sin verificar uso" `
            -Recommendation "Revisa en Configuracion > Aplicaciones si hay programas que ya no uses. Desinstalarlos libera espacio y recursos." `
            -Severity "Bajo" -ScorePenalty 3
    }

    # -- 3.4  Actualizaciones de Windows --------------------------------------
    Show-ProgressStep -Current 4 -Total 5 -Label "Verificando actualizaciones de Windows..."

    try {
        $hotfixes = Get-HotFix -ErrorAction Stop | Sort-Object InstalledOn -Descending | Select-Object -First 5
        if ($hotfixes) {
            $lastUpdate = $hotfixes[0].InstalledOn
            $daysSince  = ((Get-Date) - $lastUpdate).Days
            $data.LastUpdateDate = $lastUpdate.ToString("dd/MM/yyyy")
            $data.DaysSinceUpdate = $daysSince
            Add-TechLog "Ultima actualizacion: $($data.LastUpdateDate) ? hace $daysSince dias"

            if ($daysSince -gt 60) {
                $concerns += "Windows no se ha actualizado en $daysSince dias. Las actualizaciones son importantes para la seguridad."
                Add-Finding -Category "Windows" -Issue "Sin actualizaciones desde hace $daysSince dias" `
                    -Recommendation "Ve a Configuracion > Windows Update y ejecuta las actualizaciones pendientes." `
                    -Severity "Alto" -ScorePenalty 10
            } elseif ($daysSince -gt 30) {
                $concerns += "Han pasado $daysSince dias desde la ultima actualizacion de Windows."
                Add-Finding -Category "Windows" -Issue "Ultima actualizacion hace $daysSince dias" `
                    -Recommendation "Ejecuta Windows Update pronto para mantener la seguridad del sistema." `
                    -Severity "Medio" -ScorePenalty 5
            } else {
                $goodNews += "Windows esta actualizado (ultima actualizacion hace $daysSince dias)."
            }
        }
    } catch {
        Add-TechLog "Error verificando HotFix: $_"
    }

    # -- 3.5  Plan de Energia --------------------------------------------------
    Show-ProgressStep -Current 5 -Total 5 -Label "Analizando plan de energia..."

    try {
        $activeLine  = & powercfg /getactivescheme 2>$null

        # GUIDs de planes conocidos
        $planGUIDs = @{
            "381b4222-f694-41f0-9685-ff5bb260df2e" = "Equilibrado"
            "8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c" = "Alto rendimiento"
            "a1841308-3541-4fab-bc81-f71556f20b4a" = "Economizador"
            "e9a42b02-d5df-448d-aa00-03f14749eb61" = "Alto rendimiento (Ultimate)"
        }

        $activeGUID = ""
        if ($activeLine -match "([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})") {
            $activeGUID = $Matches[1].ToLower()
        }

        $planName = if ($planGUIDs.ContainsKey($activeGUID)) { $planGUIDs[$activeGUID] } else { "Personalizado" }
        $data.PowerPlanName = $planName
        $data.PowerPlanGUID = $activeGUID
        Add-TechLog "Plan de energia activo: $planName (GUID: $activeGUID)"

        if ($planName -eq "Economizador") {
            $concerns += "El plan de energia 'Economizador' puede limitar el rendimiento de tu procesador."
            Add-Finding -Category "Energia" -Issue "Plan Economizador activo ? puede limitar rendimiento" `
                -Recommendation "Si la notebook esta enchufada, cambia a 'Equilibrado' en Panel de Control > Opciones de energiaa para mejor rendimiento." `
                -Severity "Medio" -ScorePenalty 5
        } elseif ($planName -eq "Equilibrado" -or $planName -eq "Alto rendimiento") {
            $goodNews += "El plan de energia '$planName' es adecuado para el uso actual."
        }
    } catch {
        Add-TechLog "Error leyendo plan de energia: $_"
    }

    $Global:SystemData.AppAnalysis = $data
    Add-TechLog "Analisis de aplicaciones y energia completo."
    Show-MiniSummary -ModuleName "Aplicaciones y Plan de Energia" -GoodNews $goodNews -Concerns $concerns
}
