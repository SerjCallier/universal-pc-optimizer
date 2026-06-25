# =============================================================================
# Show-WizardUI.ps1  -  Interfaz grafica estilo instalador Windows
# WinForms dark theme: sidebar de pasos, barra de progreso, log en tiempo real
# Requiere: Helper-Functions.ps1 cargado antes
# =============================================================================

# ---------------------------------------------------------------------------
# Initialize-WizardUI : crea y muestra la ventana wizard
# Almacena todos los controles en $Global:UI
# ---------------------------------------------------------------------------
function Initialize-WizardUI {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    # -- Paleta de colores dark theme -----------------------------------------
    $clrBg      = [System.Drawing.Color]::FromArgb(14, 32, 48)
    $clrSidebar = [System.Drawing.Color]::FromArgb(8, 20, 32)
    $clrAccent  = [System.Drawing.Color]::FromArgb(0, 128, 190)
    $clrDone    = [System.Drawing.Color]::FromArgb(60, 185, 105)
    $clrText    = [System.Drawing.Color]::FromArgb(220, 230, 240)
    $clrMuted   = [System.Drawing.Color]::FromArgb(110, 140, 165)
    $clrLogBg   = [System.Drawing.Color]::FromArgb(8, 18, 28)
    $clrBorder  = [System.Drawing.Color]::FromArgb(24, 50, 72)
    $clrBtn     = [System.Drawing.Color]::FromArgb(24, 50, 72)
    $clrWarn    = [System.Drawing.Color]::FromArgb(220, 170, 0)
    $clrErr     = [System.Drawing.Color]::FromArgb(210, 65, 65)

    # -- Fuentes --------------------------------------------------------------
    $fntTitle  = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
    $fntSub    = New-Object System.Drawing.Font("Segoe UI", 9)
    $fntStep   = New-Object System.Drawing.Font("Segoe UI", 9)
    $fntStepN  = New-Object System.Drawing.Font("Segoe UI", 8, [System.Drawing.FontStyle]::Bold)
    $fntMono   = New-Object System.Drawing.Font("Consolas", 8)
    $fntBtn    = New-Object System.Drawing.Font("Segoe UI", 9)
    $fntBrand  = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
    $fntBrandS = New-Object System.Drawing.Font("Segoe UI", 8)

    # =========================================================================
    # FORM PRINCIPAL
    # =========================================================================
    $form = New-Object System.Windows.Forms.Form
    $form.Text            = "Optimizador Universal de Notebooks"
    $form.Size            = New-Object System.Drawing.Size(860, 560)
    $form.MinimumSize     = New-Object System.Drawing.Size(800, 520)
    $form.StartPosition   = "CenterScreen"
    $form.BackColor       = $clrBg
    $form.FormBorderStyle = "FixedDialog"
    $form.MaximizeBox     = $false

    # =========================================================================
    # SIDEBAR (panel izquierdo, 200px)
    # =========================================================================
    $sidebar = New-Object System.Windows.Forms.Panel
    $sidebar.Dock       = "None"
    $sidebar.Location   = New-Object System.Drawing.Point(0, 0)
    $sidebar.Size       = New-Object System.Drawing.Size(200, 560)
    $sidebar.BackColor  = $clrSidebar
    $form.Controls.Add($sidebar)

    # Marca / logo
    $lblBrand = New-Object System.Windows.Forms.Label
    $lblBrand.Text      = "OPTIMIZADOR`nUNIVERSAL"
    $lblBrand.Font      = $fntBrand
    $lblBrand.ForeColor = $clrAccent
    $lblBrand.Location  = New-Object System.Drawing.Point(14, 20)
    $lblBrand.Size      = New-Object System.Drawing.Size(175, 46)
    $sidebar.Controls.Add($lblBrand)

    $lblOs = New-Object System.Windows.Forms.Label
    $lblOs.Text      = "Windows 10 / 11"
    $lblOs.Font      = $fntBrandS
    $lblOs.ForeColor = $clrMuted
    $lblOs.Location  = New-Object System.Drawing.Point(14, 68)
    $lblOs.Size      = New-Object System.Drawing.Size(175, 18)
    $sidebar.Controls.Add($lblOs)

    # Linea separadora
    $sep0 = New-Object System.Windows.Forms.Panel
    $sep0.Location  = New-Object System.Drawing.Point(10, 90)
    $sep0.Size      = New-Object System.Drawing.Size(178, 1)
    $sep0.BackColor = $clrBorder
    $sidebar.Controls.Add($sep0)

    # Nombres de las etapas (sidebar)
    $stepNames = @(
        "Orientacion",
        "Diagnostico",
        "Limpieza",
        "Aplicaciones",
        "Cuellos de Botella",
        "Reporte Final"
    )

    $stepNumLabels  = @()
    $stepNameLabels = @()

    for ($i = 0; $i -lt $stepNames.Count; $i++) {
        $baseY = 102 + $i * 58

        # Circulo con numero
        $circle = New-Object System.Windows.Forms.Label
        $circle.Text      = ($i + 1).ToString()
        $circle.Font      = $fntStepN
        $circle.ForeColor = $clrMuted
        $circle.BackColor = $clrBorder
        $circle.Location  = New-Object System.Drawing.Point(14, $baseY)
        $circle.Size      = New-Object System.Drawing.Size(26, 26)
        $circle.TextAlign = "MiddleCenter"
        $sidebar.Controls.Add($circle)
        $stepNumLabels += $circle

        # Nombre de la etapa
        $stepLbl = New-Object System.Windows.Forms.Label
        $stepLbl.Text      = $stepNames[$i]
        $stepLbl.Font      = $fntStep
        $stepLbl.ForeColor = $clrMuted
        $stepLbl.Location  = New-Object System.Drawing.Point(46, ($baseY + 3))
        $stepLbl.Size      = New-Object System.Drawing.Size(148, 20)
        $sidebar.Controls.Add($stepLbl)
        $stepNameLabels += $stepLbl
    }

    # Version (pie del sidebar)
    $lblVer = New-Object System.Windows.Forms.Label
    $lblVer.Text      = "v1.0"
    $lblVer.Font      = $fntBrandS
    $lblVer.ForeColor = $clrMuted
    $lblVer.Location  = New-Object System.Drawing.Point(14, 510)
    $lblVer.Size      = New-Object System.Drawing.Size(80, 16)
    $sidebar.Controls.Add($lblVer)

    # =========================================================================
    # PANEL CONTENIDO (derecho, 660px)
    # =========================================================================
    $content = New-Object System.Windows.Forms.Panel
    $content.Location  = New-Object System.Drawing.Point(200, 0)
    $content.Size      = New-Object System.Drawing.Size(660, 560)
    $content.BackColor = $clrBg
    $form.Controls.Add($content)

    # Linea divisoria lateral
    $sepV = New-Object System.Windows.Forms.Panel
    $sepV.Location  = New-Object System.Drawing.Point(199, 0)
    $sepV.Size      = New-Object System.Drawing.Size(1, 560)
    $sepV.BackColor = $clrBorder
    $form.Controls.Add($sepV)

    # -- Header ---------------------------------------------------------------
    $lblTitle = New-Object System.Windows.Forms.Label
    $lblTitle.Text      = "Bienvenido"
    $lblTitle.Font      = $fntTitle
    $lblTitle.ForeColor = $clrText
    $lblTitle.Location  = New-Object System.Drawing.Point(22, 18)
    $lblTitle.Size      = New-Object System.Drawing.Size(620, 30)
    $content.Controls.Add($lblTitle)

    $lblDesc = New-Object System.Windows.Forms.Label
    $lblDesc.Text      = "Iniciando el optimizador..."
    $lblDesc.Font      = $fntSub
    $lblDesc.ForeColor = $clrMuted
    $lblDesc.Location  = New-Object System.Drawing.Point(22, 52)
    $lblDesc.Size      = New-Object System.Drawing.Size(620, 18)
    $content.Controls.Add($lblDesc)

    # Linea bajo el header
    $sepH = New-Object System.Windows.Forms.Panel
    $sepH.Location  = New-Object System.Drawing.Point(22, 76)
    $sepH.Size      = New-Object System.Drawing.Size(618, 1)
    $sepH.BackColor = $clrBorder
    $content.Controls.Add($sepH)

    # -- Barra de progreso + porcentaje ---------------------------------------
    $progress = New-Object System.Windows.Forms.ProgressBar
    $progress.Location  = New-Object System.Drawing.Point(22, 88)
    $progress.Size      = New-Object System.Drawing.Size(568, 16)
    $progress.Minimum   = 0
    $progress.Maximum   = 100
    $progress.Value     = 0
    $progress.Style     = "Continuous"
    $content.Controls.Add($progress)

    $lblPct = New-Object System.Windows.Forms.Label
    $lblPct.Text      = "0%"
    $lblPct.Font      = $fntSub
    $lblPct.ForeColor = $clrMuted
    $lblPct.Location  = New-Object System.Drawing.Point(596, 86)
    $lblPct.Size      = New-Object System.Drawing.Size(42, 18)
    $content.Controls.Add($lblPct)

    # -- RichTextBox log en tiempo real ---------------------------------------
    $logBox = New-Object System.Windows.Forms.RichTextBox
    $logBox.Location    = New-Object System.Drawing.Point(22, 114)
    $logBox.Size        = New-Object System.Drawing.Size(618, 360)
    $logBox.BackColor   = $clrLogBg
    $logBox.ForeColor   = $clrText
    $logBox.Font        = $fntMono
    $logBox.ReadOnly    = $true
    $logBox.ScrollBars  = "Vertical"
    $logBox.BorderStyle = "None"
    $logBox.WordWrap    = $true
    $content.Controls.Add($logBox)

    # -- Linea sobre los botones ----------------------------------------------
    $sepB = New-Object System.Windows.Forms.Panel
    $sepB.Location  = New-Object System.Drawing.Point(22, 482)
    $sepB.Size      = New-Object System.Drawing.Size(618, 1)
    $sepB.BackColor = $clrBorder
    $content.Controls.Add($sepB)

    # -- Status label (abajo izquierda) ---------------------------------------
    $lblStatus = New-Object System.Windows.Forms.Label
    $lblStatus.Text      = "Listo."
    $lblStatus.Font      = $fntBrandS
    $lblStatus.ForeColor = $clrMuted
    $lblStatus.Location  = New-Object System.Drawing.Point(22, 493)
    $lblStatus.Size      = New-Object System.Drawing.Size(300, 18)
    $content.Controls.Add($lblStatus)

    # -- Botones (abajo derecha) ----------------------------------------------
    # Cancelar
    $btnCancel = New-Object System.Windows.Forms.Button
    $btnCancel.Text      = "Cancelar"
    $btnCancel.Font      = $fntBtn
    $btnCancel.Location  = New-Object System.Drawing.Point(360, 487)
    $btnCancel.Size      = New-Object System.Drawing.Size(90, 28)
    $btnCancel.BackColor = $clrBtn
    $btnCancel.ForeColor = $clrText
    $btnCancel.FlatStyle = "Flat"
    $btnCancel.FlatAppearance.BorderColor = $clrBorder
    $btnCancel.FlatAppearance.BorderSize  = 1
    $btnCancel.Add_Click({
        $ans = [System.Windows.Forms.MessageBox]::Show(
            "Seguro que deseas cancelar?`nLos cambios ya realizados no se revertiran.",
            "Cancelar Optimizador",
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        )
        if ($ans -eq [System.Windows.Forms.DialogResult]::Yes) {
            $Global:UI.Cancelled = $true
            $Global:UI.Form.Close()
            exit
        }
    })
    $content.Controls.Add($btnCancel)

    # Saltar
    $btnSkip = New-Object System.Windows.Forms.Button
    $btnSkip.Text      = "Saltar"
    $btnSkip.Font      = $fntBtn
    $btnSkip.Location  = New-Object System.Drawing.Point(458, 487)
    $btnSkip.Size      = New-Object System.Drawing.Size(74, 28)
    $btnSkip.BackColor = $clrBtn
    $btnSkip.ForeColor = $clrMuted
    $btnSkip.FlatStyle = "Flat"
    $btnSkip.FlatAppearance.BorderColor = $clrBorder
    $btnSkip.Enabled   = $false
    $btnSkip.Add_Click({ $Global:UI.SkipClicked = $true })
    $content.Controls.Add($btnSkip)

    # Siguiente
    $btnNext = New-Object System.Windows.Forms.Button
    $btnNext.Text      = "Siguiente >>"
    $btnNext.Font      = $fntBtn
    $btnNext.Location  = New-Object System.Drawing.Point(540, 487)
    $btnNext.Size      = New-Object System.Drawing.Size(100, 28)
    $btnNext.BackColor = $clrAccent
    $btnNext.ForeColor = [System.Drawing.Color]::White
    $btnNext.FlatStyle = "Flat"
    $btnNext.FlatAppearance.BorderSize = 0
    $btnNext.Enabled   = $false
    $btnNext.Add_Click({ $Global:UI.NextClicked = $true })
    $content.Controls.Add($btnNext)

    # =========================================================================
    # Almacenar referencias en $Global:UI
    # =========================================================================
    $Global:UI = @{
        Form         = $form
        StepNums     = $stepNumLabels
        StepNames    = $stepNameLabels
        Title        = $lblTitle
        Desc         = $lblDesc
        Progress     = $progress
        PctLabel     = $lblPct
        Log          = $logBox
        Status       = $lblStatus
        BtnNext      = $btnNext
        BtnSkip      = $btnSkip
        BtnCancel    = $btnCancel
        NextClicked  = $false
        SkipClicked  = $false
        Cancelled    = $false
        CurrentStep  = -1
        Colors       = @{
            Accent  = $clrAccent
            Done    = $clrDone
            Text    = $clrText
            Muted   = $clrMuted
            Warn    = $clrWarn
            Err     = $clrErr
            Border  = $clrBorder
        }
    }

    $form.Show()
    [System.Windows.Forms.Application]::DoEvents()
}

# ---------------------------------------------------------------------------
# Add-UILog : agrega una linea coloreada al RichTextBox (limite 300 lineas)
# ---------------------------------------------------------------------------
function Add-UILog {
    param(
        [string]$Message,
        [System.Drawing.Color]$Color = [System.Drawing.Color]::FromArgb(200, 215, 230)
    )
    if (-not $Global:UI -or -not $Global:UI.Form -or $Global:UI.Form.IsDisposed) { return }

    $log = $Global:UI.Log

    # Limpiar si supera 300 lineas (eliminar primeras 50)
    if ($log.Lines.Count -gt 300) {
        $toRemove = ($log.Lines[0..49] -join "`n") + "`n"
        $log.SelectionStart  = 0
        $log.SelectionLength = $toRemove.Length
        $log.SelectedText    = ""
    }

    $ts = Get-Date -Format "HH:mm:ss"

    # Timestamp en gris
    $log.SelectionStart  = $log.TextLength
    $log.SelectionLength = 0
    $log.SelectionColor  = [System.Drawing.Color]::FromArgb(75, 100, 125)
    $log.AppendText("[$ts] ")

    # Mensaje coloreado
    $log.SelectionColor = $Color
    $log.AppendText("$Message`n")
    $log.ScrollToCaret()

    [System.Windows.Forms.Application]::DoEvents()
}

# ---------------------------------------------------------------------------
# Set-UIProgress : actualiza barra de progreso y label de porcentaje
# ---------------------------------------------------------------------------
function Set-UIProgress {
    param(
        [int]$Percent,
        [string]$StatusText = ""
    )
    if (-not $Global:UI -or -not $Global:UI.Form) { return }
    $v = [Math]::Max(0, [Math]::Min(100, $Percent))
    $Global:UI.Progress.Value  = $v
    $Global:UI.PctLabel.Text   = "$v%"
    if ($StatusText) { $Global:UI.Status.Text = $StatusText }
    [System.Windows.Forms.Application]::DoEvents()
}

# ---------------------------------------------------------------------------
# Set-UIStep : marca done/current/pending en la sidebar
# ---------------------------------------------------------------------------
function Set-UIStep {
    param([int]$StepIndex)   # 0-based (0=Bienvenida ... 5=Reporte)
    if (-not $Global:UI) { return }

    $ui = $Global:UI
    $c  = $ui.Colors

    for ($i = 0; $i -lt $ui.StepNums.Count; $i++) {
        if ($i -lt $StepIndex) {
            # Completado
            $ui.StepNums[$i].BackColor  = $c.Done
            $ui.StepNums[$i].ForeColor  = [System.Drawing.Color]::Black
            $ui.StepNums[$i].Text       = "v"
            $ui.StepNames[$i].ForeColor = $c.Done
        } elseif ($i -eq $StepIndex) {
            # Actual
            $ui.StepNums[$i].BackColor  = $c.Accent
            $ui.StepNums[$i].ForeColor  = [System.Drawing.Color]::White
            $ui.StepNums[$i].Text       = ($i + 1).ToString()
            $ui.StepNames[$i].ForeColor = $c.Text
        } else {
            # Pendiente
            $ui.StepNums[$i].BackColor  = $c.Border
            $ui.StepNums[$i].ForeColor  = $c.Muted
            $ui.StepNums[$i].Text       = ($i + 1).ToString()
            $ui.StepNames[$i].ForeColor = $c.Muted
        }
    }
    $ui.CurrentStep = $StepIndex
    [System.Windows.Forms.Application]::DoEvents()
}

# ---------------------------------------------------------------------------
# Set-UITitle : actualiza el header de la seccion de contenido
# ---------------------------------------------------------------------------
function Set-UITitle {
    param([string]$Title, [string]$Desc = "")
    if (-not $Global:UI) { return }
    $Global:UI.Title.Text = $Title
    if ($Desc) { $Global:UI.Desc.Text = $Desc }
    [System.Windows.Forms.Application]::DoEvents()
}

# ---------------------------------------------------------------------------
# Wait-UINext : habilita el boton Siguiente y espera click (low-CPU polling)
# ---------------------------------------------------------------------------
function Wait-UINext {
    param([string]$Label = "Siguiente >>")
    if (-not $Global:UI) { return }
    $Global:UI.NextClicked       = $false
    $Global:UI.BtnNext.Text      = $Label
    $Global:UI.BtnNext.Enabled   = $true
    $Global:UI.BtnNext.BackColor = $Global:UI.Colors.Accent

    while (-not $Global:UI.NextClicked -and -not $Global:UI.Cancelled) {
        [System.Windows.Forms.Application]::DoEvents()
        Start-Sleep -Milliseconds 50
    }
    $Global:UI.BtnNext.Enabled = $false
}

# ---------------------------------------------------------------------------
# Invoke-DismWithProgress : ejecuta DISM sin bloquear la GUI
# Usa Start-Process -PassThru + polling loop con DoEvents (Correccion #1)
# ---------------------------------------------------------------------------
function Invoke-DismWithProgress {
    if ($Global:UI) {
        Add-UILog "Iniciando limpieza de componentes de Windows (DISM)..." $Global:UI.Colors.Warn
        Add-UILog "Este proceso puede tardar entre 10 y 30 minutos." $Global:UI.Colors.Warn
        Set-UIProgress -Percent 5 -StatusText "Ejecutando DISM..."
    } else {
        Write-Color "  Ejecutando DISM (puede tardar varios minutos)..." -Color Yellow
    }

    $procArgs = "/Online /Cleanup-Image /StartComponentCleanup"
    $proc = Start-Process -FilePath "dism.exe" -ArgumentList $procArgs `
        -WindowStyle Hidden -PassThru -ErrorAction Stop

    $elapsed = 0
    while (-not $proc.HasExited) {
        [System.Windows.Forms.Application]::DoEvents()
        Start-Sleep -Milliseconds 200
        $elapsed++

        # Pulso visual cada 5 segundos (~25 iteraciones de 200ms)
        if ($elapsed % 25 -eq 0) {
            $secs = $elapsed * 0.2
            $mins = [Math]::Floor($secs / 60)
            $secsR = [int]($secs % 60)
            $msg = "Procesando DISM... {0}:{1:00} transcurridos" -f $mins, $secsR
            if ($Global:UI) {
                Set-UIProgress -StatusText $msg
                Add-UILog $msg $Global:UI.Colors.Muted
            } else {
                Write-Host "`r  $msg   " -NoNewline -ForegroundColor Cyan
            }
        }
    }

    $totalSecs = [int]($elapsed * 0.2)
    $totalMins = [Math]::Floor($totalSecs / 60)
    $msg = "DISM completado en {0} minuto(s). Codigo de salida: {1}" -f $totalMins, $proc.ExitCode
    if ($Global:UI) {
        Add-UILog $msg $Global:UI.Colors.Done
        Set-UIProgress -Percent 100 -StatusText "DISM completado."
    } else {
        Write-Host ""
        Write-Color "  $msg" -Color Green
    }
    Add-TechLog $msg
}

# ===========================================================================
# REDEFINICION DE FUNCIONES DE UI (mode GUI transparente para todos los modulos)
# ===========================================================================

# Redefine Write-Color: consola + GUI log
function Write-Color {
    param(
        [string]$Message,
        [ConsoleColor]$Color = [ConsoleColor]::White,
        [switch]$NoNewline
    )
    # Siempre al terminal (fallback / debugging)
    $prev = $Host.UI.RawUI.ForegroundColor
    $Host.UI.RawUI.ForegroundColor = $Color
    if ($NoNewline) { Write-Host $Message -NoNewline } else { Write-Host $Message }
    $Host.UI.RawUI.ForegroundColor = $prev

    # Tambien al log GUI (ignorar separadores y vacios)
    $trimmed = $Message.Trim()
    if ($Global:UI -and $Global:UI.Form -and -not $Global:UI.Form.IsDisposed `
        -and $trimmed -ne "" -and $trimmed -notmatch '^[-=+]{4,}$') {
        $guiColor = switch ($Color) {
            "Cyan"     { [System.Drawing.Color]::FromArgb(80, 195, 225) }
            "Green"    { [System.Drawing.Color]::FromArgb(85, 200, 110) }
            "Yellow"   { [System.Drawing.Color]::FromArgb(220, 185, 0)  }
            "Red"      { [System.Drawing.Color]::FromArgb(210, 70, 70)  }
            "Gray"     { [System.Drawing.Color]::FromArgb(160, 175, 190) }
            "DarkGray" { [System.Drawing.Color]::FromArgb(100, 120, 140) }
            "DarkCyan" { [System.Drawing.Color]::FromArgb(0, 155, 160)  }
            default    { [System.Drawing.Color]::FromArgb(215, 225, 235) }
        }
        Add-UILog -Message $trimmed -Color $guiColor
    }
}

# Redefine Show-ProgressStep: consola ASCII + barra GUI
function Show-ProgressStep {
    param([int]$Current, [int]$Total, [string]$Label)
    $pct = [Math]::Round(($Current / $Total) * 100)
    if ($Global:UI -and -not $Global:UI.Form.IsDisposed) {
        Set-UIProgress -Percent $pct -StatusText $Label
        Add-UILog "[$pct%] $Label" ([System.Drawing.Color]::FromArgb(90, 160, 200))
    } else {
        $filled  = [Math]::Round(($Current / $Total) * 20)
        $bar     = "#" * $filled + "-" * (20 - $filled)
        Write-Host ("  [{0}] {1,3}%  {2}" -f $bar, $pct, $Label) -ForegroundColor Cyan
    }
}

# Redefine Show-StageIntro: actualiza sidebar + header en GUI
function Show-StageIntro {
    param(
        [int]$StageNum,
        [int]$TotalStages = 6,
        [string]$Title,
        [string]$Duration,
        [string]$Instructions,
        [string]$WhatItDoes
    )
    if ($Global:UI -and -not $Global:UI.Form.IsDisposed) {
        Set-UIStep  -StepIndex $StageNum
        Set-UITitle -Title ("ETAPA {0}/{1}: {2}" -f $StageNum, $TotalStages, $Title) -Desc $WhatItDoes
        Set-UIProgress -Percent 0 -StatusText ("Iniciando {0}..." -f $Title)
        Add-UILog ("--- ETAPA {0}: {1} ---" -f $StageNum, $Title) ([System.Drawing.Color]::FromArgb(0, 128, 190))
        if ($Duration)  { Add-UILog "Tiempo estimado: $Duration" ([System.Drawing.Color]::FromArgb(100, 130, 155)) }
    } else {
        Write-Host ""
        Write-Host ("  +-- ETAPA {0}/{1}: {2}" -f $StageNum, $TotalStages, $Title.ToUpper()) -ForegroundColor Cyan
        Write-Host "  +------------------------------------------------------------------+" -ForegroundColor Cyan
        if ($WhatItDoes)  { Write-Host "  QUE VA A HACER: $WhatItDoes"   -ForegroundColor Gray }
        if ($Duration)    { Write-Host "  TIEMPO ESTIMADO: $Duration"     -ForegroundColor Gray }
        if ($Instructions){ Write-Host "  QUE HACER: $Instructions"       -ForegroundColor Gray }
        Write-Host ""
    }
}

# Redefine Show-MiniSummary: resumen visual en GUI
function Show-MiniSummary {
    param([string]$ModuleName, [string[]]$GoodNews, [string[]]$Concerns)
    if ($Global:UI -and -not $Global:UI.Form.IsDisposed) {
        Add-UILog "--- Resumen: $ModuleName ---" ([System.Drawing.Color]::FromArgb(0, 128, 190))
        foreach ($g in $GoodNews)  { Add-UILog "[OK] $g"  ([System.Drawing.Color]::FromArgb(85, 200, 110)) }
        foreach ($w in $Concerns)  { Add-UILog "[!]  $w"  ([System.Drawing.Color]::FromArgb(220, 185, 0)) }
    } else {
        Write-Host ""
        Write-Host "  === RESUMEN: $ModuleName ===" -ForegroundColor Cyan
        foreach ($g in $GoodNews) { Write-Host "  [OK] $g" -ForegroundColor Green }
        foreach ($w in $Concerns) { Write-Host "  [!]  $w" -ForegroundColor Yellow }
        Write-Host ""
    }
}

# Redefine Confirm-ModuleSkip: MessageBox en GUI
function Confirm-ModuleSkip {
    param([string]$ModuleName, [string]$Description = "")
    if ($Global:UI -and -not $Global:UI.Form.IsDisposed) {
        $msg  = if ($Description) { "$Description`n`nDeseas ejecutar esta etapa?" } else { "Deseas ejecutar: $ModuleName?" }
        $resp = [System.Windows.Forms.MessageBox]::Show(
            $msg, $ModuleName,
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Question
        )
        $run = ($resp -eq [System.Windows.Forms.DialogResult]::Yes)
        if (-not $run) { Add-UILog "Etapa saltada: $ModuleName" $Global:UI.Colors.Muted }
        return $run
    } else {
        Write-Host ""
        if ($Description) { Write-Host "  $Description" -ForegroundColor Gray; Write-Host "" }
        Write-Host "  Deseas ejecutar: $ModuleName?" -ForegroundColor White
        $r = Read-Host "  [S] Si  [N] No"
        if ($r -match '^[Nn]') {
            Write-Host "  OK. Saltando esta etapa." -ForegroundColor Yellow
            return $false
        }
        return $true
    }
}

# Redefine Show-RiskWarning: informativa en GUI
function Show-RiskWarning {
    param([string]$WhatIsIt, [string]$WhyItsSafe, [string]$PathsAffected = "")
    if ($Global:UI -and -not $Global:UI.Form.IsDisposed) {
        Add-UILog "AVISO: $WhatIsIt"    $Global:UI.Colors.Warn
        Add-UILog "Seguridad: $WhyItsSafe" ([System.Drawing.Color]::FromArgb(85, 200, 110))
    } else {
        Write-Host ""
        Write-Host "  ANTES DE CONTINUAR:" -ForegroundColor Yellow
        Write-Host "  $WhatIsIt" -ForegroundColor White
        if ($WhyItsSafe) { Write-Host "  $WhyItsSafe" -ForegroundColor Green }
        Write-Host ""
    }
}

# Redefine Show-HighRiskWarning: MessageBox con icono de advertencia en GUI
function Show-HighRiskWarning {
    param([string]$FileOrFolder, [string]$WhatIsIt, [string]$ConsequenceIfDeleted, [string]$Recommendation)
    if ($Global:UI -and -not $Global:UI.Form.IsDisposed) {
        $msg = "Archivo/Carpeta: $FileOrFolder`n`nQUE ES: $WhatIsIt`n`nQUE PASA SI SE ELIMINA: $ConsequenceIfDeleted`n`nRECOMENDACION: $Recommendation"
        [System.Windows.Forms.MessageBox]::Show(
            $msg, "Accion de Mayor Riesgo",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        ) | Out-Null
    } else {
        Write-Host ""
        Write-Host "  +== ACCION DE MAYOR RIESGO ==" -ForegroundColor Red
        Write-Host "  Archivo: $FileOrFolder"           -ForegroundColor White
        Write-Host "  Que es: $WhatIsIt"                -ForegroundColor Gray
        Write-Host "  Si se elimina: $ConsequenceIfDeleted" -ForegroundColor Yellow
        Write-Host "  Recomendacion: $Recommendation"   -ForegroundColor Cyan
        Write-Host ""
    }
}

# Redefine Show-DismWarning: MessageBox con OK/Cancel en GUI
function Show-DismWarning {
    if ($Global:UI -and -not $Global:UI.Form.IsDisposed) {
        $resp = [System.Windows.Forms.MessageBox]::Show(
            "Esta etapa limpia archivos de actualizaciones antiguas de Windows.`n`n" +
            "IMPORTANTE: puede tardar entre 10 y 30 minutos.`n" +
            "La pantalla puede parecer inactiva -- esto es completamente normal.`n" +
            "NO cierres la ventana ni presiones Cancelar durante el proceso.",
            "Limpieza de actualizaciones de Windows",
            [System.Windows.Forms.MessageBoxButtons]::OKCancel,
            [System.Windows.Forms.MessageBoxIcon]::Information
        )
        return ($resp -eq [System.Windows.Forms.DialogResult]::OK)
    } else {
        Write-Host ""
        Write-Host "  +== LIMPIEZA DE ACTUALIZACIONES WINDOWS ==" -ForegroundColor Cyan
        Write-Host "  IMPORTANTE: puede tardar entre 10 y 30 minutos." -ForegroundColor Yellow
        Write-Host "  NO cierres la ventana ni presiones Ctrl+C." -ForegroundColor Red
        Write-Host ""
        $r = Read-Host "  Deseas continuar? [S/N]"
        return ($r -notmatch '^[Nn]')
    }
}

# Redefine Show-WelcomeBanner: solo en consola (no se necesita en GUI)
function Show-WelcomeBanner {
    if (-not $Global:UI) {
        Clear-Host
        Write-Host ""
        Write-Host "  +======================================================================+" -ForegroundColor Cyan
        Write-Host "  |   OPTIMIZADOR UNIVERSAL DE NOTEBOOKS  -  Windows 10/11             |" -ForegroundColor Cyan
        Write-Host "  |              Diagnostico y Optimizacion                              |" -ForegroundColor Cyan
        Write-Host "  +======================================================================+" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "  Presiona ENTER para comenzar..." -ForegroundColor Cyan
        Read-Host | Out-Null
    }
}

# Redefine Show-ClosingMessage: GUI actualiza step 5 + wait
function Show-ClosingMessage {
    param([string]$ReportFolder)
    if ($Global:UI -and -not $Global:UI.Form.IsDisposed) {
        Set-UIStep    -StepIndex 5
        Set-UITitle   -Title "Proceso completado" -Desc "Tu notebook fue analizada y optimizada."
        Set-UIProgress -Percent 100 -StatusText "Proceso completado."
        Add-UILog "--- PROCESO COMPLETADO ---" $Global:UI.Colors.Done
        if ($ReportFolder) {
            Add-UILog "Reporte guardado en: $ReportFolder" $Global:UI.Colors.Done
        }
        Wait-UINext -Label "Cerrar"
        $Global:UI.Form.Close()
    } else {
        Write-Host ""
        Write-Host "  LISTO! Tu notebook fue analizada y optimizada." -ForegroundColor Green
        if ($ReportFolder) { Write-Host "  Reporte en: $ReportFolder" -ForegroundColor Cyan }
        Write-Host ""
        Write-Host "  Presiona ENTER para cerrar..." -ForegroundColor DarkGray
        Read-Host | Out-Null
    }
}

Write-Color "  [Show-WizardUI] Cargado correctamente." -Color DarkGray
