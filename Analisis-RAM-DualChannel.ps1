# =============================================================================
# Analisis-RAM-DualChannel.ps1
# Recopila TODOS los datos de RAM del equipo:
#  - Modelo exacto de cada modulo (fabricante, part number, serie)
#  - Velocidad, tipo, voltaje, latencia
#  - Slots ocupados y disponibles
#  - Deteccion de modo Dual Channel
#  - Recomendaciones para comprar el modulo identico
# Guarda todo en RAM_Reporte.txt junto al script
# =============================================================================

#Requires -Version 5.1

# Auto-elevacion UAC
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    $self = $MyInvocation.MyCommand.Path
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$self`"" -Verb RunAs
    exit
}

$ScriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$ReportPath = Join-Path $ScriptDir "RAM_Reporte.txt"
$lines      = [System.Collections.Generic.List[string]]::new()

function L  { param([string]$t = "") $lines.Add($t) }
function LH { param([string]$t)      $lines.Add(""); $lines.Add($t); $lines.Add(("-" * $t.Length)) }
function LHH{ param([string]$t)      $lines.Add(""); $lines.Add(("=" * 68)); $lines.Add("  $t"); $lines.Add(("=" * 68)) }

$Host.UI.RawUI.WindowTitle = "Analisis RAM - Dual Channel"
Clear-Host
Write-Host ""
Write-Host "  Analizando RAM del sistema..." -ForegroundColor Cyan
Write-Host ""

# =============================================================================
$fecha = Get-Date -Format "dd/MM/yyyy HH:mm:ss"
LHH "REPORTE DE ANALISIS RAM - DUAL CHANNEL"
L   "Fecha:    $fecha"
L   "Equipo:   $env:COMPUTERNAME"
L   "Usuario:  $env:USERNAME"

# =============================================================================
# 1. INFO DEL SISTEMA BASE
# =============================================================================
LHH "1. SISTEMA BASE"

$cs   = Get-CimInstance Win32_ComputerSystem       -ErrorAction SilentlyContinue
$mb   = Get-CimInstance Win32_BaseBoard            -ErrorAction SilentlyContinue
$bios = Get-CimInstance Win32_BIOS                 -ErrorAction SilentlyContinue
$cpu  = Get-CimInstance Win32_Processor            -ErrorAction SilentlyContinue | Select-Object -First 1

LH "Computadora"
L "  Fabricante    : $($cs.Manufacturer)"
L "  Modelo        : $($cs.Model)"
L "  Sistema       : $($cs.SystemType)"

LH "Placa Madre (Motherboard)"
L "  Fabricante    : $($mb.Manufacturer)"
L "  Producto      : $($mb.Product)"
L "  Version       : $($mb.Version)"
L "  Numero Serie  : $($mb.SerialNumber)"

LH "BIOS"
L "  Fabricante    : $($bios.Manufacturer)"
L "  Version       : $($bios.SMBIOSBIOSVersion)"
L "  Fecha BIOS    : $($bios.ReleaseDate)"

LH "Procesador (CPUMemory Controller)"
L "  Modelo        : $($cpu.Name.Trim())"
L "  Nucleos fisic : $($cpu.NumberOfCores)"
L "  Nucleos logic : $($cpu.NumberOfLogicalProcessors)"
L "  Max velocidad : $($cpu.MaxClockSpeed) MHz"

Write-Host "  [1/7] Sistema base recopilado." -ForegroundColor Green

# =============================================================================
# 2. SLOTS DE MEMORIA (Physical Memory Array)
# =============================================================================
LHH "2. SLOTS DE MEMORIA DISPONIBLES"

$memArrays = Get-CimInstance Win32_PhysicalMemoryArray -ErrorAction SilentlyContinue
foreach ($arr in $memArrays) {
    L "  Slots totales      : $($arr.MemoryDevices)"
    L "  Capacidad maxima   : $([Math]::Round($arr.MaxCapacity / 1MB, 0)) GB"
    $typeMap = @{2="DRAM";6="Flash";7="EEPROM";8="FEPROM";9="EPROM";10="CDRAM";
                 11="3DRAM";12="SDRAM";13="SGRAM";14="RDRAM";15="DDR";16="DDR2";
                 17="DDR2 FB-DIMM";18="DDR3";19="FBD2";20="DDR3";24="DDR4";26="DDR5";0="Desconocido"}
    $memType = if ($typeMap.ContainsKey([int]$arr.MemoryType)) { $typeMap[[int]$arr.MemoryType] } else { "Tipo $($arr.MemoryType)" }
    L "  Tipo de memoria    : $memType"
    switch ($arr.Use) {
        3 { L "  Uso               : Memoria del sistema" }
        4 { L "  Uso               : Video" }
        5 { L "  Uso               : Flash" }
        default { L "  Uso               : $($arr.Use)" }
    }
}

Write-Host "  [2/7] Slots analizados." -ForegroundColor Green

# =============================================================================
# 3. MODULOS RAM INSTALADOS (detalle exhaustivo)
# =============================================================================
LHH "3. MODULOS RAM INSTALADOS (DETALLE EXACTO)"

$sticks = Get-CimInstance Win32_PhysicalMemory -ErrorAction SilentlyContinue
$stickCount = 0

$memTypeMap = @{
    0="Desconocido";1="Otro";2="DRAM";3="Sincrona DRAM";4="Cache DRAM";
    5="EDO";6="EDRAM";7="VRAM";8="SRAM";9="RAM";10="ROM";11="Flash";
    12="EEPROM";13="FEPROM";14="EPROM";15="CDRAM";16="3DRAM";17="SDRAM";
    18="SGRAM";19="RDRAM";20="DDR";21="DDR2";22="DDR2 FB-DIMM";
    24="DDR3";26="DDR4";27="LPDDR";28="LPDDR2";29="LPDDR3";30="LPDDR4";
    31="Logica No Volatil";32="HBM";33="HBM2";34="DDR5";35="LPDDR5"
}

$formMap = @{
    0="Desconocido";1="Otro";2="SIP";3="DIP";4="ZIP";5="SOJ";6="Propietario";
    7="SIMM";8="DIMM";9="TSOP";10="PGA";11="RIMM";12="SO-DIMM";13="SRIMM";
    14="SMD";15="SSMP";16="QFP";17="TQFP";18="SOIC";19="LCC";20="PLCC";
    21="BGA";22="FPBGA";23="LGA"
}

foreach ($s in $sticks) {
    $stickCount++
    $capGB = [Math]::Round($s.Capacity / 1GB, 1)
    $tipo  = if ($memTypeMap.ContainsKey([int]$s.MemoryType)) { $memTypeMap[[int]$s.MemoryType] } else { "Tipo $($s.MemoryType)" }
    $form  = if ($formMap.ContainsKey([int]$s.FormFactor))    { $formMap[[int]$s.FormFactor]    } else { "Form $($s.FormFactor)"  }

    LH "Modulo #$stickCount - Slot: $($s.DeviceLocator)  |  Banco: $($s.BankLabel)"
    L  "  *** DATOS PARA COMPRAR IDENTICO ***"
    L  "  Fabricante        : $(if($s.Manufacturer.Trim())  {$s.Manufacturer.Trim()} else {'No disponible'})"
    L  "  Numero de parte   : $(if($s.PartNumber.Trim())    {$s.PartNumber.Trim()}   else {'No disponible - ver pegatina fisica'})"
    L  "  Numero de serie   : $(if($s.SerialNumber.Trim())  {$s.SerialNumber.Trim()} else {'No disponible'})"
    L  ""
    L  "  Capacidad         : $capGB GB"
    L  "  Tipo              : $tipo"
    L  "  Factor de forma   : $form"
    L  "  Velocidad config. : $($s.ConfiguredClockSpeed) MHz   <-- velocidad REAL corriendo"
    L  "  Velocidad nominal : $($s.Speed) MHz               <-- velocidad maxima del modulo"
    L  "  Velocidad datos   : $($s.ConfiguredClockSpeed * 2) MT/s  (DDR efectivo)"
    L  ""
    L  "  Voltaje config.   : $(if($s.ConfiguredVoltage) {"$($s.ConfiguredVoltage / 1000) V"} else {"No disponible"})"
    L  "  Voltaje minimo    : $(if($s.MinVoltage)  {"$($s.MinVoltage / 1000) V"}  else {"No disponible"})"
    L  "  Voltaje maximo    : $(if($s.MaxVoltage)  {"$($s.MaxVoltage / 1000) V"}  else {"No disponible"})"
    L  ""
    L  "  Slot fisico       : $($s.DeviceLocator)"
    L  "  Banco             : $($s.BankLabel)"
    L  "  Tag               : $($s.Tag)"
    L  ""
    L  "  Interleave pos.   : $($s.InterleavePosition)"
    L  "  Data width        : $($s.DataWidth) bits"
    L  "  Total width       : $($s.TotalWidth) bits  (incluye ECC si aplica)"
    L  "  ECC               : $(if($s.TotalWidth -gt $s.DataWidth) {'SI - tiene bits de paridad'} else {'No'})"
    L  "  Atrib. tipo       : $($s.TypeDetail)"
}

L ""
L "  TOTAL MODULOS INSTALADOS : $stickCount"
L "  TOTAL RAM                : $([Math]::Round(($sticks | Measure-Object -Property Capacity -Sum).Sum / 1GB, 1)) GB"

Write-Host "  [3/7] Modulos RAM analizados." -ForegroundColor Green

# =============================================================================
# 4. DETECCION DE DUAL CHANNEL
# =============================================================================
LHH "4. DETECCION MODO DUAL CHANNEL"

$slotsOcupados  = @($sticks | Where-Object { $_.Capacity -gt 0 })
$totalModulos   = $slotsOcupados.Count
$cantidadesBanc = $slotsOcupados | Group-Object BankLabel

# Heuristica Dual Channel:
# Dual Channel = 2 modulos en bancos distintos con igual capacidad
$esDualChannel  = $false
$motivoDual     = ""

if ($totalModulos -eq 1) {
    $esDualChannel = $false
    $motivoDual    = "Solo hay 1 modulo instalado. Dual Channel IMPOSIBLE."
} elseif ($totalModulos -ge 2) {
    # Verificar si los modulos estan en bancos alternos (A1/B1 o DIMM0/DIMM2)
    $bancos = $slotsOcupados.BankLabel | ForEach-Object { $_.Trim() }
    $caps   = $slotsOcupados.Capacity  | Sort-Object
    $speeds = $slotsOcupados.ConfiguredClockSpeed | Sort-Object
    $todosMismaCap   = ($caps   | Select-Object -Unique).Count -eq 1
    $todosMismaVel   = ($speeds | Select-Object -Unique).Count -eq 1
    $bancosDistintos = ($bancos | Select-Object -Unique).Count -eq $totalModulos

    if ($bancosDistintos -and $todosMismaCap) {
        $esDualChannel = $true
        $motivoDual    = "Modulos en bancos distintos con igual capacidad. DUAL CHANNEL ACTIVO (probable)."
    } elseif (-not $bancosDistintos) {
        $esDualChannel = $false
        $motivoDual    = "Modulos en el MISMO banco. DUAL CHANNEL NO activo. Mover al slot correcto."
    } elseif (-not $todosMismaCap) {
        $esDualChannel = $false
        $motivoDual    = "Modulos de distinta capacidad. Puede funcionar en Dual Channel Flexible/Asimetrico."
    }
}

L  "  Modulos instalados   : $totalModulos"
L  "  Slots detectados     :"
foreach ($s in $slotsOcupados) {
    L "    - Slot '$($s.DeviceLocator)' | Banco '$($s.BankLabel)' | $([Math]::Round($s.Capacity/1GB,1)) GB | $($s.ConfiguredClockSpeed) MHz"
}
L  ""
L  "  ESTADO DUAL CHANNEL  : $(if($esDualChannel){'*** ACTIVO ***'}else{'--- NO ACTIVO ---'})"
L  "  Detalle              : $motivoDual"
L  ""

# Verificacion extra: velocidad efectiva
$velReal = ($slotsOcupados | Select-Object -First 1).ConfiguredClockSpeed
if ($velReal -gt 0) {
    L "  Velocidad RAM actual : $velReal MHz ($($velReal * 2) MT/s efectivos)"
}

# Consistencia entre modulos
$fabricantes = ($slotsOcupados.Manufacturer | ForEach-Object {$_.Trim()} | Select-Object -Unique)
$partNums    = ($slotsOcupados.PartNumber   | ForEach-Object {$_.Trim()} | Select-Object -Unique)
$velocidades = ($slotsOcupados.Speed        | Select-Object -Unique)

L  ""
L  "  Consistencia entre modulos:"
L  "  - Fabricantes distintos   : $($fabricantes.Count)  $(if($fabricantes.Count -gt 1){'[ATENCION: mezcla de marcas]'}else{'[OK: misma marca]'})"
L  "  - Part Numbers distintos  : $($partNums.Count)    $(if($partNums.Count -gt 1){'[ATENCION: modulos distintos]'}else{'[OK: identicos]'})"
L  "  - Velocidades distintas   : $($velocidades.Count)  $(if($velocidades.Count -gt 1){'[ATENCION: velocidades distintas]'}else{'[OK: igual velocidad]'})"

Write-Host "  [4/7] Dual Channel analizado." -ForegroundColor Green

# =============================================================================
# 5. CONFIGURACION XMP / JEDEC
# =============================================================================
LHH "5. CONFIGURACION DE VELOCIDAD (JEDEC / XMP)"

foreach ($s in $slotsOcupados) {
    L "  Slot $($s.DeviceLocator):"
    L "    Velocidad JEDEC base : $($s.Speed) MHz"
    L "    Velocidad configurad : $($s.ConfiguredClockSpeed) MHz"
    if ($s.Speed -gt 0 -and $s.ConfiguredClockSpeed -lt $s.Speed) {
        L "    Estado XMP           : DESACTIVADO (corriendo por debajo del maximo)"
        L "    RECOMENDACION        : Activar XMP/DOCP en BIOS para llegar a $($s.Speed) MHz"
    } elseif ($s.ConfiguredClockSpeed -ge $s.Speed) {
        L "    Estado XMP           : Activo o corriendo a capacidad maxima"
    }
}

Write-Host "  [5/7] XMP/JEDEC analizado." -ForegroundColor Green

# =============================================================================
# 6. RESUMEN DE MEMORIA DEL SO
# =============================================================================
LHH "6. USO DE MEMORIA EN TIEMPO REAL"

$os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
if ($os) {
    $totalRAM  = [Math]::Round($os.TotalVisibleMemorySize / 1MB, 2)
    $freeRAM   = [Math]::Round($os.FreePhysicalMemory     / 1MB, 2)
    $usedRAM   = [Math]::Round($totalRAM - $freeRAM, 2)
    $usedPct   = [Math]::Round(($usedRAM / $totalRAM) * 100, 1)
    $pageTotal = [Math]::Round($os.TotalVirtualMemorySize / 1MB, 2)
    $pageFree  = [Math]::Round($os.FreeVirtualMemory      / 1MB, 2)

    L "  RAM Total (SO)       : $totalRAM GB"
    L "  RAM Usada            : $usedRAM GB  ($usedPct%%)"
    L "  RAM Libre            : $freeRAM GB"
    L "  Memoria virtual tot  : $pageTotal GB"
    L "  Memoria virtual lib  : $pageFree GB"
}

# Top procesos por RAM
$topProc = Get-Process -ErrorAction SilentlyContinue |
    Sort-Object WorkingSet64 -Descending |
    Select-Object -First 10
L ""
L "  Top 10 procesos por uso de RAM ahora mismo:"
foreach ($p in $topProc) {
    $mb = [Math]::Round($p.WorkingSet64 / 1MB, 0)
    L ("  {0,-30} {1,6} MB" -f $p.Name, $mb)
}

Write-Host "  [6/7] Uso de memoria capturado." -ForegroundColor Green

# =============================================================================
# 7. RECOMENDACIONES PARA COMPRAR RAM IDENTICA
# =============================================================================
LHH "7. GUIA PARA COMPRAR RAM IDENTICA (DUAL CHANNEL)"

$mod1 = $slotsOcupados | Select-Object -First 1

L  "  Para correr en Dual Channel necesitas UN MODULO IDENTICO al que ya tenes."
L  ""
L  "  DATOS CLAVE PARA BUSCAR EN MERCADOLIBRE / AMAZON / TIENDA:"
L  "  ----------------------------------------------------------"
L  "  Fabricante     : $(if($mod1.Manufacturer.Trim()){'***  ' + $mod1.Manufacturer.Trim() + '  ***'}else{'Revisar pegatina fisica del modulo'})"
L  "  Numero de Parte: $(if($mod1.PartNumber.Trim()){'***  ' + $mod1.PartNumber.Trim() + '  ***'}else{'Revisar pegatina fisica del modulo'})"
L  "  Capacidad      : $([Math]::Round($mod1.Capacity/1GB,0)) GB"
L  "  Tipo           : $(if ($memTypeMap.ContainsKey([int]$mod1.MemoryType)) { $memTypeMap[[int]$mod1.MemoryType] } else { 'DDR4/DDR5 - verificar' })"
L  "  Velocidad      : $($mod1.Speed) MHz  (busca igual o compatible)"
L  "  Factor forma   : $(if ($formMap.ContainsKey([int]$mod1.FormFactor)) { $formMap[[int]$mod1.FormFactor] } else { 'SO-DIMM (notebook) o DIMM (desktop)' })"
L  "  Voltaje        : $(if($mod1.ConfiguredVoltage){"$($mod1.ConfiguredVoltage / 1000) V"}else{'1.2V (DDR4 estandar) o 1.1V (DDR5)'})"
L  ""
L  "  DONDE INSTALAR EL MODULO NUEVO:"

$slotsLibres = @()
$arraySlots  = if ($memArrays) { $memArrays | Select-Object -First 1 } else { $null }
if ($arraySlots) {
    $totalSlots  = $arraySlots.MemoryDevices
    $slotsFilled = $stickCount
    $slotsLibres = $totalSlots - $slotsFilled
    L  "    Slots totales en la placa : $totalSlots"
    L  "    Slots ocupados            : $slotsFilled"
    L  "    Slots LIBRES              : $slotsLibres"
}

L  ""
L  "  REGLA DE ORO DUAL CHANNEL:"
L  "    - Poner los 2 modulos en los slots del MISMO COLOR en la placa"
L  "    - Generalmente: DIMM_A1 + DIMM_B1  o  DIMM1 + DIMM3"
L  "    - NUNCA poner los 2 en slots contiguos del mismo color"
L  "    - Consultar el manual de la placa madre para el orden exacto"
L  ""
L  "  VERIFICACION POST-INSTALACION:"
L  "    1. Arrancar el equipo y entrar al BIOS"
L  "    2. Verificar que aparezca el total de RAM (ej: 32 GB si pones 2x16)"
L  "    3. Activar XMP/DOCP si esta disponible para velocidad maxima"
L  "    4. En Windows: Administrador de tareas > Rendimiento > Memoria"
L  "       Debe decir 'Canal: Doble' para confirmar Dual Channel"

Write-Host "  [7/7] Recomendaciones generadas." -ForegroundColor Green

# =============================================================================
# GUARDAR REPORTE
# =============================================================================
$separator = "`r`n"
$content   = $lines -join $separator
Set-Content -Path $ReportPath -Value $content -Encoding UTF8

Write-Host ""
Write-Host "  =============================================================" -ForegroundColor Cyan
Write-Host "  REPORTE GUARDADO EN:" -ForegroundColor Green
Write-Host "  $ReportPath" -ForegroundColor White
Write-Host "  =============================================================" -ForegroundColor Cyan
Write-Host ""

# Abrir el reporte automaticamente
Start-Process notepad.exe -ArgumentList "`"$ReportPath`""

Write-Host "  Presiona ENTER para cerrar..." -ForegroundColor DarkGray
Read-Host | Out-Null
