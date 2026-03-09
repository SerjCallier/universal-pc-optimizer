# =============================================================================
# Invoke-SystemCleanup.ps1  -  Modulo 2: Limpieza segura de archivos
# =============================================================================

function Invoke-SystemCleanup {

    Show-StageIntro -StageNum 2 -TotalStages 6 `
        -Title "Limpieza de Archivos" `
        -Duration "Entre 5 y 45 minutos (dependiendo de las opciones elegidas)" `
        -WhatItDoes "Vamos a eliminar archivos temporales y caches que Windows ya no necesita. Esto puede liberar espacio y hacer que tu computadora arranque mas rapido." `
        -Instructions "Te vamos a preguntar antes de cada limpieza. Podes elegir que limpiar y que no."

    Show-RiskWarning `
        -WhatIsIt "ANTES DE CONTINUAR: Asegurate de tener guardados todos los archivos abiertos en Word, Excel, navegadores, etc. Este proceso eliminara archivos temporales que no se pueden recuperar." `
        -WhyItsSafe "Este programa NO toca tus documentos, fotos ni programas instalados. Solo limpia archivos que Windows crea automaticamente y ya no usa." `
        -PathsAffected "%TEMP%  (archivos temporales de tu usuario)`nC:\Windows\Temp  (archivos temporales del sistema)`nCaches de navegadores web (Chrome, Edge, Firefox)`nPapelera de reciclaje"

    $totalFreedBytes = 0L
    $goodNews = @()
    $concerns = @()

    # Funcion interna: limpia una carpeta y devuelve bytes liberados
    function Remove-FolderContents {
        param([string]$Path, [string]$Label)
        if (-not (Test-Path $Path)) { return 0L }
        $before = Get-FolderSize -Path $Path
        try {
            Get-ChildItem -Path $Path -Recurse -Force -ErrorAction SilentlyContinue |
                Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
        } catch { <# ignora archivos bloqueados #> }
        $after = Get-FolderSize -Path $Path
        $freed = [Math]::Max(0L, $before - $after)
        Add-TechLog "Limpieza $Label : antes=$( Format-Bytes $before) | despues=$(Format-Bytes $after) | liberado=$(Format-Bytes $freed)"
        return $freed
    }

    # -- 2.1  Archivos temporales ----------------------------------------------
    Show-ProgressStep -Current 1 -Total 6 -Label "Calculando archivos temporales..."

    $tempPaths = @(
        @{ Path = $env:TEMP;           Label = "Temp usuario (%TEMP%)" },
        @{ Path = "C:\Windows\Temp";   Label = "Temp sistema (C:\Windows\Temp)" }
    )

    $tempTotalBefore = 0L
    foreach ($t in $tempPaths) {
        if (Test-Path $t.Path) {
            $sz = Get-FolderSize -Path $t.Path
            $tempTotalBefore += $sz
            Write-Color ("     {0,-35} {1}" -f $t.Label, (Format-Bytes $sz)) -Color Gray
        }
    }

    Write-Host ""
    Write-Color "  Espacio a liberar en archivos temporales: $(Format-Bytes $tempTotalBefore)" -Color White

    $doTemp = $tempTotalBefore -gt 0
    if ($doTemp) {
        if (Get-UserConfirmation "Deseas eliminar los archivos temporales? ($(Format-Bytes $tempTotalBefore))" "Limpiar archivos temporales") {
            foreach ($t in $tempPaths) {
                $freed = Remove-FolderContents -Path $t.Path -Label $t.Label
                $totalFreedBytes += $freed
            }
            $goodNews += "Archivos temporales limpiados: $(Format-Bytes $tempTotalBefore) liberados."
        } else {
            Write-Color "  Saltando limpieza de archivos temporales." -Color Yellow
        }
    } else {
        $goodNews += "Las carpetas temporales ya estaban limpias."
    }

    # -- 2.2  Cache de navegadores ---------------------------------------------
    Show-ProgressStep -Current 2 -Total 6 -Label "Buscando cache de navegadores..."

    $browserCaches = @(
        @{
            Name  = "Google Chrome"
            Paths = @(
                "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache",
                "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Code Cache",
                "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\GPUCache"
            )
        },
        @{
            Name  = "Microsoft Edge"
            Paths = @(
                "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache",
                "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Code Cache",
                "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\GPUCache"
            )
        },
        @{
            Name  = "Mozilla Firefox"
            Paths = @(
                (Get-ChildItem "$env:LOCALAPPDATA\Mozilla\Firefox\Profiles" -Filter "*.default*" -ErrorAction SilentlyContinue |
                 Select-Object -First 1 | ForEach-Object { Join-Path $_.FullName "cache2" })
            )
        }
    )

    $browserTotal = 0L
    $foundBrowsers = @()
    foreach ($browser in $browserCaches) {
        $bSize = 0L
        foreach ($path in $browser.Paths) {
            if ($path -and (Test-Path $path)) {
                $bSize += Get-FolderSize -Path $path
            }
        }
        if ($bSize -gt 0) {
            Write-Color ("     {0,-20} Cache: {1}" -f $browser.Name, (Format-Bytes $bSize)) -Color Gray
            $browserTotal += $bSize
            $foundBrowsers += $browser
        }
    }

    if ($browserTotal -gt 0) {
        Write-Host ""
        Write-Color "  Cache total de navegadores: $(Format-Bytes $browserTotal)" -Color White
        if (Get-UserConfirmation "Deseas limpiar el cache de los navegadores? $(Format-Bytes $browserTotal)`n(Tus favoritos y contrasenas NO se borran)" "Limpiar cache de navegadores") {
            foreach ($browser in $foundBrowsers) {
                foreach ($path in $browser.Paths) {
                    if ($path -and (Test-Path $path)) {
                        $freed = Remove-FolderContents -Path $path -Label "$($browser.Name) cache"
                        $totalFreedBytes += $freed
                    }
                }
            }
            $goodNews += "Cache de navegadores limpiado: $(Format-Bytes $browserTotal) liberados."
        } else {
            Write-Color "  Saltando limpieza de navegadores." -Color Yellow
        }
    } else {
        Write-Color "  No se encontro cache de navegadores para limpiar." -Color DarkGray
    }

    # -- 2.3  Papelera de reciclaje --------------------------------------------
    Show-ProgressStep -Current 3 -Total 6 -Label "Revisando papelera de reciclaje..."

    try {
        $shell    = New-Object -ComObject Shell.Application
        $recycle  = $shell.Namespace(0xA)
        $itemCount = ($recycle.Items() | Measure-Object).Count

        if ($itemCount -gt 0) {
            Write-Color "  La papelera tiene $itemCount elemento(s)." -Color White
            if (Get-UserConfirmation "La papelera tiene $itemCount elemento(s). Deseas vaciarla?" "Vaciar papelera") {
                Clear-RecycleBin -Force -ErrorAction SilentlyContinue
                $goodNews += "Papelera vaciada ($itemCount elementos eliminados)."
                Add-TechLog "Papelera vaciada: $itemCount elementos"
            } else {
                Write-Color "  Saltando vaciado de papelera." -Color Yellow
            }
        } else {
            Write-Color "  La papelera ya esta vacia." -Color DarkGray
            $goodNews += "La papelera ya estaba vacia."
        }
    } catch {
        Add-TechLog "Error accediendo a la papelera: $_"
    }

    # -- 2.4  Limpieza WinSxS / DISM ------------------------------------------
    Show-ProgressStep -Current 4 -Total 6 -Label "Preparando limpieza de actualizaciones antiguas..."

    $runDism = Show-DismWarning
    if ($runDism) {
        try {
            Invoke-DismWithProgress | Out-Null
            $goodNews += "Limpieza de actualizaciones de Windows completada."
        } catch {
            Add-TechLog "Error en DISM: $_"
            $concerns += "La limpieza de actualizaciones de Windows no pudo completarse."
        }
    } else {
        Write-Color "  Saltando limpieza de componentes de Windows." -Color Yellow
        Add-TechLog "DISM saltado por el usuario"
    }

    # -- 2.5  Logs del sistema > 30 dias --------------------------------------
    Show-ProgressStep -Current 5 -Total 6 -Label "Buscando logs antiguos del sistema..."

    $logPaths = @("C:\Windows\Logs", "C:\Windows\System32\winevt\Logs")
    $oldLogs  = @()
    $logBytes = 0L
    $cutoff   = (Get-Date).AddDays(-30)

    foreach ($lp in $logPaths) {
        if (Test-Path $lp) {
            $files = Get-ChildItem -Path $lp -Recurse -Force -ErrorAction SilentlyContinue |
                     Where-Object { -not $_.PSIsContainer -and $_.LastWriteTime -lt $cutoff }
            $oldLogs += $files
            $logBytes += ($files | Measure-Object -Property Length -Sum).Sum
        }
    }

    if ($logBytes -gt 0) {
        Show-HighRiskWarning `
            -FileOrFolder "Logs del sistema (C:\Windows\Logs)" `
            -WhatIsIt "Son archivos de registro que Windows usa para registrar lo que sucede. Los que tienen m?s de 30 d?as raramente se necesitan." `
            -ConsequenceIfDeleted "No afecta el funcionamiento de Windows. Solo perdes el historial antiguo de eventos (util solo para diagnostico avanzado)." `
            -Recommendation "Si no tenes problemas tecnicos que investigar, es seguro borrarlos. Si un tecnico te pidio que los guardes, decile que no a esta opcion."

        Write-Color "  Logs del sistema con mas de 30 dias: $(Format-Bytes $logBytes) en $($oldLogs.Count) archivos" -Color White
        if (Get-UserConfirmation "Deseas eliminar los logs del sistema de mas de 30 dias? ($(Format-Bytes $logBytes) en $($oldLogs.Count) archivos)" "Eliminar logs antiguos") {
            $freedLogs = 0L
            foreach ($f in $oldLogs) {
                $freedLogs += $f.Length
                Remove-Item $f.FullName -Force -ErrorAction SilentlyContinue
            }
            $totalFreedBytes += $freedLogs
            $goodNews += "Logs antiguos eliminados: $(Format-Bytes $freedLogs) liberados."
            Add-TechLog "Logs elimindos: $($oldLogs.Count) archivos, $(Format-Bytes $freedLogs)"
        } else {
            Write-Color "  Saltando eliminacion de logs." -Color Yellow
        }
    } else {
        Write-Color "  No se encontraron logs antiguos que limpiar." -Color DarkGray
    }

    # -- 2.6  Hiberfil.sys -----------------------------------------------------
    Show-ProgressStep -Current 6 -Total 6 -Label "Verificando archivo de hibernacion..."

    $hiberFile = "C:\hiberfil.sys"
    if (Test-Path $hiberFile) {
        $hiberSize = (Get-Item $hiberFile -Force -ErrorAction SilentlyContinue).Length

        Show-HighRiskWarning `
            -FileOrFolder "C:\hiberfil.sys ($(Format-Bytes $hiberSize))" `
            -WhatIsIt "Este archivo es lo que usa Windows para guardar el estado de tu computadora cuando la 'hibernas'. La hibernacion es diferente al modo suspension." `
            -ConsequenceIfDeleted "Ya no podras usar el modo hibernacion. El arranque rapido de Windows tambien se desactivara. La suspension normal seguira funcionando igual." `
            -Recommendation "Si nunca usas 'Hibernar' (en lugar de 'Apagar' o 'Suspender'), pod?s eliminarlo. Si no estas seguro, mejor no lo elimines."

        if (Get-UserConfirmation "Deseas deshabilitar la hibernacion y liberar $(Format-Bytes $hiberSize)?" "Deshabilitar hibernacion") {
            try {
                & powercfg /hibernate off 2>&1 | Out-Null
                $totalFreedBytes += $hiberSize
                $goodNews += "Hibernacion deshabilitada: $(Format-Bytes $hiberSize) liberados."
                Add-TechLog "Hibernacion deshabilitada. Espacio liberado: $(Format-Bytes $hiberSize)"
            } catch {
                Add-TechLog "Error deshabilitando hibernacion: $_"
                $concerns += "No se pudo deshabilitar la hibernacion."
            }
        } else {
            Write-Color "  Conservando archivo de hibernacion." -Color Yellow
        }
    } else {
        Write-Color "  La hibernacion ya estaba deshabilitada o no existe el archivo." -Color DarkGray
    }

    # -- Resumen final del modulo -----------------------------------------------
    $Global:SystemData.CleanupFreedBytes = $totalFreedBytes
    $Global:AfterState.DiskFreeGB = if ($Global:SystemData.Diagnostics.LogicalDisks) {
        $beforeFree = ($Global:SystemData.Diagnostics.LogicalDisks | Where-Object { $_.Drive -eq "C:" } | Select-Object -First 1).FreeGB
        [Math]::Round($beforeFree + ($totalFreedBytes / 1GB), 2)
    } else { 0 }

    if ($totalFreedBytes -gt 0) {
        $goodNews += "Total liberado en esta etapa: $(Format-Bytes $totalFreedBytes)"
        Write-Host ""
        Write-Color "  ? Total de espacio liberado: $(Format-Bytes $totalFreedBytes)" -Color Green
    } else {
        Write-Color "  No se libero espacio en esta etapa." -Color DarkGray
    }

    Add-TechLog "Limpieza completa. Total liberado: $(Format-Bytes $totalFreedBytes)"
    Show-MiniSummary -ModuleName "Limpieza de Archivos" -GoodNews $goodNews -Concerns $concerns
}
