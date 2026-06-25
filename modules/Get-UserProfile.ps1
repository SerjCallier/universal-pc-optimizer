# =============================================================================
# Get-UserProfile.ps1  -  Paso 0: Orientacion inicial del usuario
# Determina nivel tecnico, uso principal y preocupacion para personalizar
# el analisis y los reportes generados.
# =============================================================================

# ---------------------------------------------------------------------------
# Show-ProfileQuestion (GUI) : dialogo modal con radio buttons dark theme
# Devuelve el string Value de la opcion elegida (primera por defecto).
# ---------------------------------------------------------------------------
function Show-ProfileQuestion {
    param(
        [string]   $QuestionText,
        [string[]] $Labels,
        [string[]] $Values
    )

    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    $formH = 80 + ($Labels.Count * 34) + 70
    $dlg   = New-Object System.Windows.Forms.Form
    $dlg.Text            = "Orientacion inicial"
    $dlg.Size            = New-Object System.Drawing.Size(450, $formH)
    $dlg.StartPosition   = "CenterScreen"
    $dlg.BackColor       = [System.Drawing.Color]::FromArgb(14, 32, 48)
    $dlg.FormBorderStyle = "FixedDialog"
    $dlg.MaximizeBox     = $false
    $dlg.MinimizeBox     = $false

    $lblQ = New-Object System.Windows.Forms.Label
    $lblQ.Text      = $QuestionText
    $lblQ.Font      = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $lblQ.ForeColor = [System.Drawing.Color]::FromArgb(220, 230, 240)
    $lblQ.Location  = New-Object System.Drawing.Point(20, 18)
    $lblQ.Size      = New-Object System.Drawing.Size(405, 44)
    $dlg.Controls.Add($lblQ)

    $radioButtons = @()
    for ($i = 0; $i -lt $Labels.Count; $i++) {
        $rb = New-Object System.Windows.Forms.RadioButton
        $rb.Text      = $Labels[$i]
        $rb.Tag       = $Values[$i]
        $rb.Font      = New-Object System.Drawing.Font("Segoe UI", 9)
        $rb.ForeColor = [System.Drawing.Color]::FromArgb(200, 215, 230)
        $rb.BackColor = [System.Drawing.Color]::FromArgb(14, 32, 48)
        $rb.Location  = New-Object System.Drawing.Point(30, (66 + $i * 34))
        $rb.Size      = New-Object System.Drawing.Size(400, 28)
        if ($i -eq 0) { $rb.Checked = $true }
        $dlg.Controls.Add($rb)
        $radioButtons += $rb
    }

    $btnY  = 66 + ($Labels.Count * 34) + 12
    $btnOk = New-Object System.Windows.Forms.Button
    $btnOk.Text      = "Aceptar"
    $btnOk.Font      = New-Object System.Drawing.Font("Segoe UI", 9)
    $btnOk.ForeColor = [System.Drawing.Color]::White
    $btnOk.BackColor = [System.Drawing.Color]::FromArgb(0, 128, 190)
    $btnOk.FlatStyle = "Flat"
    $btnOk.FlatAppearance.BorderSize = 0
    $btnOk.Location  = New-Object System.Drawing.Point(310, $btnY)
    $btnOk.Size      = New-Object System.Drawing.Size(110, 30)

    $script:profileResult = $Values[0]
    $btnOk.Add_Click({
        foreach ($rb in $radioButtons) {
            if ($rb.Checked) { $script:profileResult = $rb.Tag }
        }
        $dlg.Close()
    })
    $dlg.Controls.Add($btnOk)
    $dlg.AcceptButton = $btnOk

    $dlg.ShowDialog() | Out-Null
    $dlg.Dispose()
    return $script:profileResult
}

# ---------------------------------------------------------------------------
# Invoke-UserProfile : cuestionario de 3 preguntas, pobla $Global:UserProfile
# ---------------------------------------------------------------------------
function Invoke-UserProfile {

    # -- Intro ----------------------------------------------------------------
    if ($Global:UI -and -not $Global:UI.Form.IsDisposed) {
        Set-UIStep     -StepIndex 0
        Set-UITitle    -Title "Orientacion inicial" `
                       -Desc  "3 preguntas rapidas para personalizar el analisis."
        Set-UIProgress -Percent 0 -StatusText "Conociendo tu perfil..."
        Add-UILog "Antes de comenzar, necesitamos conocerte un poco." ([System.Drawing.Color]::FromArgb(80, 195, 225))
        Add-UILog "Responde las preguntas que apareceran ahora." ([System.Drawing.Color]::FromArgb(160, 180, 200))
        [System.Windows.Forms.Application]::DoEvents()
    } else {
        Write-Host ""
        Write-Host "  +======================================================================+" -ForegroundColor Cyan
        Write-Host "  |   ORIENTACION INICIAL  -  3 preguntas rapidas                       |" -ForegroundColor Cyan
        Write-Host "  +======================================================================+" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "  Vamos a personalizar el analisis y el reporte segun tu perfil." -ForegroundColor Gray
        Write-Host ""
    }

    # -------------------------------------------------------------------------
    # PREGUNTA 1 - Nivel tecnico
    # -------------------------------------------------------------------------
    $levelLabels = @(
        "Basico      - Soy usuario comun, no se mucho de tecnologia",
        "Intermedio  - Entiendo algo de computadoras",
        "Avanzado    - Tengo conocimientos tecnicos profundos"
    )
    $levelValues = @("Basico", "Intermedio", "Avanzado")

    if ($Global:UI -and -not $Global:UI.Form.IsDisposed) {
        $Global:UserProfile.TechLevel = Show-ProfileQuestion `
            -QuestionText "Pregunta 1 de 3: Cual es tu nivel tecnico?" `
            -Labels $levelLabels `
            -Values $levelValues
        Set-UIProgress -Percent 33 -StatusText "Pregunta 1 de 3 completada."
    } else {
        Write-Host "  PREGUNTA 1 DE 3: Nivel tecnico" -ForegroundColor Cyan
        for ($i = 0; $i -lt $levelLabels.Count; $i++) {
            Write-Host ("  [{0}] {1}" -f ($i + 1), $levelLabels[$i]) -ForegroundColor White
        }
        Write-Host ""
        $valid = $false
        do {
            $r = Read-Host "  Tu eleccion (1-3)"
            if ($r -match '^[123]$') { $valid = $true }
            else { Write-Host "  Opcion invalida. Ingresa 1, 2 o 3." -ForegroundColor Yellow }
        } while (-not $valid)
        $levelMap = @{ "1" = "Basico"; "2" = "Intermedio"; "3" = "Avanzado" }
        $Global:UserProfile.TechLevel = $levelMap[$r]
        Write-Host ""
    }

    # -------------------------------------------------------------------------
    # PREGUNTA 2 - Uso principal
    # -------------------------------------------------------------------------
    $useLabels = @(
        "Trabajo o estudio  (Office, correo, videoconferencias)",
        "Navegacion web y redes sociales",
        "Diseno o edicion   (fotos, video, diseno grafico)",
        "Gaming             (juegos de PC)",
        "Todo lo anterior   (uso variado / general)"
    )
    $useValues = @("Trabajo", "Navegacion", "Diseno", "Gaming", "General")

    if ($Global:UI -and -not $Global:UI.Form.IsDisposed) {
        $Global:UserProfile.PrimaryUse = Show-ProfileQuestion `
            -QuestionText "Pregunta 2 de 3: Para que usas principalmente esta computadora?" `
            -Labels $useLabels `
            -Values $useValues
        Set-UIProgress -Percent 66 -StatusText "Pregunta 2 de 3 completada."
    } else {
        Write-Host "  PREGUNTA 2 DE 3: Uso principal" -ForegroundColor Cyan
        for ($i = 0; $i -lt $useLabels.Count; $i++) {
            Write-Host ("  [{0}] {1}" -f ($i + 1), $useLabels[$i]) -ForegroundColor White
        }
        Write-Host ""
        $valid = $false
        do {
            $r = Read-Host "  Tu eleccion (1-5)"
            if ($r -match '^[12345]$') { $valid = $true }
            else { Write-Host "  Opcion invalida. Ingresa un numero entre 1 y 5." -ForegroundColor Yellow }
        } while (-not $valid)
        $useMap = @{ "1" = "Trabajo"; "2" = "Navegacion"; "3" = "Diseno"; "4" = "Gaming"; "5" = "General" }
        $Global:UserProfile.PrimaryUse = $useMap[$r]
        Write-Host ""
    }

    # -------------------------------------------------------------------------
    # PREGUNTA 3 - Preocupacion principal
    # -------------------------------------------------------------------------
    $concernLabels = @(
        "Va lenta o tarda en abrir programas",
        "Se calienta mucho",
        "La bateria dura poco",
        "El WiFi va lento o se corta",
        "Me queda poco espacio en disco",
        "Quiero una evaluacion general (sin queja especifica)"
    )
    $concernValues = @("Lentitud", "Temperatura", "Bateria", "WiFi", "Espacio", "General")

    if ($Global:UI -and -not $Global:UI.Form.IsDisposed) {
        $Global:UserProfile.MainConcern = Show-ProfileQuestion `
            -QuestionText "Pregunta 3 de 3: Cual es tu principal preocupacion?" `
            -Labels $concernLabels `
            -Values $concernValues
        Set-UIProgress -Percent 100 -StatusText "Perfil completado."
    } else {
        Write-Host "  PREGUNTA 3 DE 3: Principal preocupacion" -ForegroundColor Cyan
        for ($i = 0; $i -lt $concernLabels.Count; $i++) {
            Write-Host ("  [{0}] {1}" -f ($i + 1), $concernLabels[$i]) -ForegroundColor White
        }
        Write-Host ""
        $valid = $false
        do {
            $r = Read-Host "  Tu eleccion (1-6)"
            if ($r -match '^[123456]$') { $valid = $true }
            else { Write-Host "  Opcion invalida. Ingresa un numero entre 1 y 6." -ForegroundColor Yellow }
        } while (-not $valid)
        $concernMap = @{ "1" = "Lentitud"; "2" = "Temperatura"; "3" = "Bateria"; "4" = "WiFi"; "5" = "Espacio"; "6" = "General" }
        $Global:UserProfile.MainConcern = $concernMap[$r]
        Write-Host ""
    }

    # -- Confirmacion ---------------------------------------------------------
    $summary = "Nivel: $($Global:UserProfile.TechLevel) | Uso: $($Global:UserProfile.PrimaryUse) | Preocupacion: $($Global:UserProfile.MainConcern)"
    Add-TechLog "Perfil de usuario registrado: $summary"

    if ($Global:UI -and -not $Global:UI.Form.IsDisposed) {
        Add-UILog "" ([System.Drawing.Color]::White)
        Add-UILog "Perfil registrado correctamente:" ([System.Drawing.Color]::FromArgb(85, 200, 110))
        Add-UILog ("  Nivel tecnico:   {0}" -f $Global:UserProfile.TechLevel)   ([System.Drawing.Color]::FromArgb(160, 180, 200))
        Add-UILog ("  Uso principal:   {0}" -f $Global:UserProfile.PrimaryUse)  ([System.Drawing.Color]::FromArgb(160, 180, 200))
        Add-UILog ("  Preocupacion:    {0}" -f $Global:UserProfile.MainConcern) ([System.Drawing.Color]::FromArgb(160, 180, 200))
        Add-UILog "" ([System.Drawing.Color]::White)
        Add-UILog "Presiona 'Siguiente' para comenzar el analisis." ([System.Drawing.Color]::FromArgb(80, 195, 225))
    } else {
        Write-Host "  Perfil registrado:" -ForegroundColor Green
        Write-Host ("  Nivel tecnico:   {0}" -f $Global:UserProfile.TechLevel)   -ForegroundColor Cyan
        Write-Host ("  Uso principal:   {0}" -f $Global:UserProfile.PrimaryUse)  -ForegroundColor Cyan
        Write-Host ("  Preocupacion:    {0}" -f $Global:UserProfile.MainConcern) -ForegroundColor Cyan
        Write-Host ""
        Start-Sleep -Seconds 1
    }
}

Write-Color "  [Get-UserProfile] Cargado correctamente." -Color DarkGray
