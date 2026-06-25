# empaquetar.ps1 - Genera el ZIP de distribucion
$devDir = Split-Path -Parent $MyInvocation.MyCommand.Path   # carpeta _dev
$src    = Split-Path -Parent $devDir                        # raiz del proyecto
$out    = Join-Path $src "OptimizadorUniversal-DISTRIBUCION.zip"

if (Test-Path $out) { Remove-Item $out -Force }

$tmp = Join-Path $env:TEMP "OptimizadorDist"
if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force }
New-Item -ItemType Directory $tmp | Out-Null

Copy-Item (Join-Path $src "main.ps1")                          (Join-Path $tmp "main.ps1")
Copy-Item (Join-Path $src "Ejecutar como Administrador.bat")   (Join-Path $tmp "Ejecutar como Administrador.bat")
Copy-Item (Join-Path $src "modules")                           (Join-Path $tmp "modules") -Recurse

Compress-Archive -Path "$tmp\*" -DestinationPath $out -Force
Remove-Item $tmp -Recurse -Force

$sz = [Math]::Round((Get-Item $out).Length / 1KB, 0)
Write-Host ""
Write-Host "  ZIP listo: $out" -ForegroundColor Green
Write-Host "  Tamanio  : $sz KB" -ForegroundColor DarkGray
Write-Host ""
Read-Host "  Presiona ENTER para cerrar"
