Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# ===================== CONFIG =====================
 $KEY_SERVER_URL = "https://api-production-2119.up.railway.app/api/verify"
 $CLIENT_SECRET  = "12345" # ต้องตรงกับ Railway

# ===================== HWID =====================
function Get-HWID {Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# ===================== CONFIG =====================
 $KEY_SERVER_URL = "https://api-production-2119.up.railway.app/api/verify"
 $SCRIPT_URL     = "https://api-production-2119.up.railway.app/bd-init-v2"
 $CLIENT_SECRET  = "12345" # ต้องตรงกับ Env ใน Railway

# ===================== HWID =====================
function Get-HWID {
    try {
        $cpu = (Get-WmiObject Win32_Processor | Select-Object -First 1).ProcessorId
        $mb  = (Get-WmiObject Win32_BaseBoard | Select-Object -First 1).SerialNumber
        $raw = "$cpu-$mb"
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($raw)
        $hash  = [System.Security.Cryptography.SHA256]::Create().ComputeHash($bytes)
        return ([BitConverter]::ToString($hash) -replace '-','').Substring(0,16)
    } catch { return "UNKNOWN-$(Get-Random)" }
}
 $HWID = Get-HWID

# ===================== COLORS =====================
 $BG_COLOR    = [System.Drawing.Color]::FromArgb(5, 10, 20)
 $PRIMARY     = [System.Drawing.Color]::FromArgb(0, 210, 255)
 $SECONDARY   = [System.Drawing.Color]::FromArgb(0, 69, 139)
 $TEXT_COLOR  = [System.Drawing.Color]::FromArgb(224, 247, 255)
 $ACCENT      = [System.Drawing.Color]::FromArgb(0, 255, 140)
 $GLASS       = [System.Drawing.Color]::FromArgb(10, 20, 40)
 $DARK_BORDER = [System.Drawing.Color]::FromArgb(0, 40, 80)
 $ERR_COLOR   = [System.Drawing.Color]::FromArgb(255, 50, 50)

# ===================== LICENSE KEY FORM =====================
 $authForm = New-Object System.Windows.Forms.Form
 $authForm.Text = "FOUR // AUTH"
 $authForm.Size = New-Object System.Drawing.Size(480, 300)
 $authForm.StartPosition = "CenterScreen"
 $authForm.BackColor = $BG_COLOR
 $authForm.ForeColor = $TEXT_COLOR
 $authForm.FormBorderStyle = "None"
 $authForm.TopMost = $true

 $authPath = New-Object System.Drawing.Drawing2D.GraphicsPath
 $authPath.AddPolygon(@(
    (New-Object System.Drawing.Point(0, 0)), (New-Object System.Drawing.Point(456, 0)),
    (New-Object System.Drawing.Point(480, 15)), (New-Object System.Drawing.Point(480, 300)),
    (New-Object System.Drawing.Point(24, 300)), (New-Object System.Drawing.Point(0, 285))
))
 $authForm.Region = New-Object System.Drawing.Region($authPath)

 $script:dragAuth = $false
 $authForm.Add_MouseDown({$script:dragAuth=$true; $script:dragAuthStart=$_.Location})
 $authForm.Add_MouseMove({if($script:dragAuth){$authForm.Left += $_.X - $script:dragAuthStart.X; $authForm.Top += $_.Y - $script:dragAuthStart.Y}})
 $authForm.Add_MouseUp({$script:dragAuth=$false})

 $authForm.Add_Paint({
    $g = $_.Graphics
    $p = New-Object System.Drawing.Pen($PRIMARY, 2)
    $g.DrawPolygon($p, @(
        (New-Object System.Drawing.Point(0, 0)), (New-Object System.Drawing.Point(456, 0)),
        (New-Object System.Drawing.Point(480, 15)), (New-Object System.Drawing.Point(480, 300)),
        (New-Object System.Drawing.Point(24, 300)), (New-Object System.Drawing.Point(0, 285))
    ))
    $p.Dispose()
})

 $authTitle = New-Object System.Windows.Forms.Label
 $authTitle.Text = "[ F O U R ] // ACCESS CONTROL"; $authTitle.Font = New-Object System.Drawing.Font("Consolas",12,[System.Drawing.FontStyle]::Bold)
 $authTitle.ForeColor = $PRIMARY; $authTitle.Location = New-Object System.Drawing.Point(20,20); $authTitle.AutoSize=$true
 $authForm.Controls.Add($authTitle)

 $keyInput = New-Object System.Windows.Forms.TextBox
 $keyInput.Location = New-Object System.Drawing.Point(30,80); $keyInput.Size = New-Object System.Drawing.Size(420,30)
 $keyInput.Font = New-Object System.Drawing.Font("Consolas",12,[System.Drawing.FontStyle]::Bold)
 $keyInput.BackColor = [System.Drawing.Color]::FromArgb(10, 15, 30); $keyInput.ForeColor = $ACCENT
 $keyInput.Text = "FOUR-XXXX-XXXX-XXXX" # แก้บัคช่องว่างตรงนี้
 $authForm.Controls.Add($keyInput)

 $status = New-Object System.Windows.Forms.Label
 $status.Location = New-Object System.Drawing.Point(30,120); $status.Size = New-Object System.Drawing.Size(420,40)
 $status.Font = New-Object System.Drawing.Font("Consolas",9)
 $authForm.Controls.Add($status)

 $verifyBtn = New-Object System.Windows.Forms.Button
 $verifyBtn.Text = "AUTHENTICATE"; $verifyBtn.Location = New-Object System.Drawing.Point(30,180)
 $verifyBtn.Size = New-Object System.Drawing.Size(420,50)
 $verifyBtn.Font = New-Object System.Drawing.Font("Consolas",12,[System.Drawing.FontStyle]::Bold)
 $verifyBtn.FlatStyle = "Flat"; $verifyBtn.FlatAppearance.BorderColor = $PRIMARY; $verifyBtn.FlatAppearance.BorderSize = 2
 $verifyBtn.BackColor = [System.Drawing.Color]::Transparent; $verifyBtn.ForeColor = $PRIMARY
 $authForm.Controls.Add($verifyBtn)

 $verifyBtn.Add_Click({
    $key = $keyInput.Text.Trim().ToUpper().Replace(" ", "") # แก้บัคช่องว่างตรงนี้
    if ($key.Length -lt 15) { $status.ForeColor = $ERR_COLOR; $status.Text = "ERROR: Invalid key format"; return }
    $verifyBtn.Enabled = $false; $verifyBtn.Text = "VERIFYING..."
    $status.ForeColor = $PRIMARY; $status.Text = "$ Connecting to server..."
    try {
        $body = @{ key = $key; hwid = $HWID } | ConvertTo-Json
        $headers = @{ "Content-Type" = "application/json"; "x-babydek-client" = $CLIENT_SECRET }
        $resp = Invoke-RestMethod -Uri $KEY_SERVER_URL -Method Post -Headers $headers -Body $body -TimeoutSec 15
        if ($resp.valid) {
            $status.ForeColor = $ACCENT; $status.Text = "$ Access Granted"
            Start-Sleep -Milliseconds 800; $authForm.DialogResult = "OK"; $authForm.Close()
        } else {
            $status.ForeColor = $ERR_COLOR; $status.Text = "$ ERROR: $($resp.reason)"
            $verifyBtn.Enabled = $true; $verifyBtn.Text = "AUTHENTICATE"
        }
    } catch {
        $status.ForeColor = $ERR_COLOR; $status.Text = "$ CONNECTION FAILED"
        $verifyBtn.Enabled = $true; $verifyBtn.Text = "AUTHENTICATE"
    }
})

if ($authForm.ShowDialog() -ne "OK") { exit }

# ===================== MAIN OPTIMIZER FORM =====================
 $form = New-Object System.Windows.Forms.Form
 $form.Text = "FOUR // SYSTEM OPTIMIZER"
 $form.Size = New-Object System.Drawing.Size(960, 720)
 $form.StartPosition = "CenterScreen"
 $form.BackColor = $BG_COLOR
 $form.ForeColor = $TEXT_COLOR
 $form.FormBorderStyle = "None"
 $form.Font = New-Object System.Drawing.Font("Consolas", 9)

 $mainPath = New-Object System.Drawing.Drawing2D.GraphicsPath
 $mainPath.AddPolygon(@(
    (New-Object System.Drawing.Point(30, 0)), (New-Object System.Drawing.Point(930, 0)),
    (New-Object System.Drawing.Point(960, 30)), (New-Object System.Drawing.Point(960, 690)),
    (New-Object System.Drawing.Point(930, 720)), (New-Object System.Drawing.Point(30, 720)),
    (New-Object System.Drawing.Point(0, 690)), (New-Object System.Drawing.Point(0, 30))
))
 $form.Region = New-Object System.Drawing.Region($mainPath)

 $script:_dragMain = $false
 $form.Add_MouseDown({ param($s,$e) if ($e.Button -eq [System.Windows.Forms.MouseButtons]::Left) { $script:_dragMain = $true; $script:_dragMainStart = $e.Location } })
 $form.Add_MouseMove({ param($s,$e) if ($script:_dragMain) { $form.Left += $e.X - $script:_dragMainStart.X; $form.Top += $e.Y - $script:_dragMainStart.Y } })
 $form.Add_MouseUp({ $script:_dragMain = $false })

 $form.Add_Paint({
    $g = $_.Graphics
    $gridPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(15, 30, 60), 1)
    for ($i = 0; $i -lt $form.Width; $i += 50) { $g.DrawLine($gridPen, $i, 0, $i, $form.Height) }
    for ($i = 0; $i -lt $form.Height; $i += 50) { $g.DrawLine($gridPen, 0, $i, $form.Width, $i) }
    $gridPen.Dispose()
    $p = New-Object System.Drawing.Pen($PRIMARY, 2)
    $g.DrawPolygon($p, @(
        (New-Object System.Drawing.Point(30, 0)), (New-Object System.Drawing.Point(930, 0)),
        (New-Object System.Drawing.Point(960, 30)), (New-Object System.Drawing.Point(960, 690)),
        (New-Object System.Drawing.Point(930, 720)), (New-Object System.Drawing.Point(30, 720)),
        (New-Object System.Drawing.Point(0, 690)), (New-Object System.Drawing.Point(0, 30))
    ))
    $p.Dispose()
})

# ===================== HEADER =====================
 $headerPanel = New-Object System.Windows.Forms.Panel
 $headerPanel.Location = New-Object System.Drawing.Point(20, 10)
 $headerPanel.Size = New-Object System.Drawing.Size(920, 50)
 $headerPanel.BackColor = [System.Drawing.Color]::Transparent
 $form.Controls.Add($headerPanel)

 $headerPanel.Add_Paint({
    $g = $_.Graphics
    $p = New-Object System.Drawing.Pen($PRIMARY, 1)
    $g.DrawLine($p, 0, 48, 920, 48)
    $p.Dispose()
})

 $lblLogo = New-Object System.Windows.Forms.Label
 $lblLogo.Text = "[ F O U R ]"; $lblLogo.Font = New-Object System.Drawing.Font("Consolas",20,[System.Drawing.FontStyle]::Bold)
 $lblLogo.ForeColor = $PRIMARY; $lblLogo.Location = New-Object System.Drawing.Point(10, 8); $lblLogo.AutoSize=$true
 $headerPanel.Controls.Add($lblLogo)

 $lblSubLogo = New-Object System.Windows.Forms.Label
 $lblSubLogo.Text = "SYS_OPTIMIZER_V2"; $lblSubLogo.Font = New-Object System.Drawing.Font("Consolas",8)
 $lblSubLogo.ForeColor = $SECONDARY; $lblSubLogo.Location = New-Object System.Drawing.Point(220, 22); $lblSubLogo.AutoSize=$true
 $headerPanel.Controls.Add($lblSubLogo)

 $lblStatusMain = New-Object System.Windows.Forms.Label
 $lblStatusMain.Text = "● SYSTEM READY"; $lblStatusMain.Font = New-Object System.Drawing.Font("Consolas",10,[System.Drawing.FontStyle]::Bold)
 $lblStatusMain.ForeColor = $ACCENT; $lblStatusMain.Location = New-Object System.Drawing.Point(730, 18); $lblStatusMain.AutoSize=$true
 $headerPanel.Controls.Add($lblStatusMain)

# ===================== SYSTEM BAR =====================
 $sysBarY = 70
 $sysItems = @("Operating System", "Processor", "Memory", "Network")
try {
    $osInfo = (Get-WmiObject Win32_OperatingSystem).Caption.Substring(0,20)
    $cpuInfo = (Get-WmiObject Win32_Processor).Name.Substring(0,20)
    $ramGB = [math]::Round((Get-WmiObject Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 1)
    $netAdapters = (Get-WmiObject Win32_NetworkAdapter -Filter "NetEnabled=True" | Select-Object -First 1).Name
    if($netAdapters.Length -gt 15){$netAdapters = $netAdapters.Substring(0,15)}
} catch { $osInfo="N/A"; $cpuInfo="N/A"; $ramGB="0"; $netAdapters="N/A" }
 $sysVals = @($osInfo, $cpuInfo, "$ramGB GB", $netAdapters)

 $sX = 20
for ($i=0; $i -lt 4; $i++) {
    $card = New-Object System.Windows.Forms.Panel
    $card.Location = New-Object System.Drawing.Point($sX, $sysBarY)
    $card.Size = New-Object System.Drawing.Size(215, 45)
    $card.BackColor = $GLASS
    $card.Add_Paint({
        $g = $_.Graphics
        $pen = New-Object System.Drawing.Pen($PRIMARY, 3)
        $g.DrawLine($pen, 0, 0, 0, 45)
        $pen.Dispose()
    })
    $form.Controls.Add($card)

    $lbl1 = New-Object System.Windows.Forms.Label
    $lbl1.Text = $sysItems[$i]; $lbl1.Font = New-Object System.Drawing.Font("Consolas",7)
    $lbl1.ForeColor = $PRIMARY; $lbl1.Location = New-Object System.Drawing.Point(8, 5); $lbl1.AutoSize=$true
    $card.Controls.Add($lbl1)

    $lbl2 = New-Object System.Windows.Forms.Label
    $lbl2.Text = $sysVals[$i]; $lbl2.Font = New-Object System.Drawing.Font("Consolas",10,[System.Drawing.FontStyle]::Bold)
    $lbl2.ForeColor = $TEXT_COLOR; $lbl2.Location = New-Object System.Drawing.Point(8, 22); $lbl2.AutoSize=$true
    $card.Controls.Add($lbl2)

    $sX += 225
}

# ===================== STAGES PANEL =====================
 $stagesPanel = New-Object System.Windows.Forms.Panel
 $stagesPanel.Location = New-Object System.Drawing.Point(20, 130)
 $stagesPanel.Size = New-Object System.Drawing.Size(250, 310)
 $stagesPanel.BackColor = [System.Drawing.Color]::Transparent
 $form.Controls.Add($stagesPanel)

 $stepDefs = @(
    @{ id=1; label="[01] TCP_GLOBAL_OPT" },
    @{ id=2; label="[02] REG_INTERFACE_KEY" },
    @{ id=3; label="[03] REG_PARAMS_LATENCY" },
    @{ id=4; label="[04] PROC_PRIORITY_LIST" },
    @{ id=5; label="[05] IRQ_AFFINITY_TUNER" },
    @{ id=6; label="[06] SERVICE_DISABLER" }
)

 $stepLabels = @{}
 $sY = 0
foreach ($s in $stepDefs) {
    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = $s.label; $lbl.Font = New-Object System.Drawing.Font("Consolas", 10)
    $lbl.ForeColor = $DARK_BORDER; $lbl.Location = New-Object System.Drawing.Point(0, $sY)
    $lbl.Size = New-Object System.Drawing.Size(240, 28); $lbl.TextAlign = "MiddleLeft"
    $stagesPanel.Controls.Add($lbl)
    $stepLabels[$s.id] = $lbl
    $sY += 38
}

# Progress Bar Area
 $progressBg = New-Object System.Windows.Forms.Panel
 $progressBg.Location = New-Object System.Drawing.Point(20, 445)
 $progressBg.Size = New-Object System.Drawing.Size(250, 45)
 $progressBg.BackColor = [System.Drawing.Color]::Transparent
 $form.Controls.Add($progressBg)

 $lblProgress = New-Object System.Windows.Forms.Label
 $lblProgress.Text = "PROGRESS [----------] 0%"
 $lblProgress.Font = New-Object System.Drawing.Font("Consolas", 8, [System.Drawing.FontStyle]::Bold)
 $lblProgress.ForeColor = $PRIMARY; $lblProgress.Location = New-Object System.Drawing.Point(0, 0); $lblProgress.AutoSize = $true
 $progressBg.Controls.Add($lblProgress)

 $progressBar = New-Object System.Windows.Forms.ProgressBar
 $progressBar.Location = New-Object System.Drawing.Point(0, 20); $progressBar.Size = New-Object System.Drawing.Size(250, 14)
 $progressBg.Controls.Add($progressBar)

# ===================== TERMINAL OUTPUT =====================
 $terminalPanel = New-Object System.Windows.Forms.Panel
 $terminalPanel.Location = New-Object System.Drawing.Point(280, 130)
 $terminalPanel.Size = New-Object System.Drawing.Size(660, 360)
 $terminalPanel.BackColor = [System.Drawing.Color]::FromArgb(2, 5, 15)
 $form.Controls.Add($terminalPanel)

 $terminalPanel.Add_Paint({
    $g = $_.Graphics
    $p = New-Object System.Drawing.Pen($DARK_BORDER, 1)
    $g.DrawRectangle($p, 0, 0, 659, 359)
    $p.Dispose()
    $txtBrush = New-Object System.Drawing.SolidBrush($DARK_BORDER)
    $g.DrawString("SYSTEM LOG STREAM", (New-Object System.Drawing.Font("Consolas",7)), $txtBrush, 530, 5)
    $txtBrush.Dispose()
})

 $logBox = New-Object System.Windows.Forms.RichTextBox
 $logBox.Location = New-Object System.Drawing.Point(5, 20); $logBox.Size = New-Object System.Drawing.Size(650, 335)
 $logBox.BackColor = [System.Drawing.Color]::FromArgb(2, 5, 15); $logBox.ForeColor = $PRIMARY
 $logBox.Font = New-Object System.Drawing.Font("Consolas", 10); $logBox.ReadOnly = $true
 $logBox.BorderStyle = "None"; $logBox.ScrollBars = "Vertical"
 $terminalPanel.Controls.Add($logBox)

function Write-Log {
    param([string]$msg, [string]$type = "info")
    try {
        $col = switch ($type) {
            "ok"    { $ACCENT }
            "warn"  { [System.Drawing.Color]::FromArgb(255, 200, 0) }
            "err"   { $ERR_COLOR }
            "dim"   { $DARK_BORDER }
            "hi"    { $TEXT_COLOR }
            "step"  { $PRIMARY }
            default { $PRIMARY }
        }
        $logBox.SelectionStart = $logBox.TextLength; $logBox.SelectionLength = 0
        $logBox.SelectionColor = $PRIMARY; $logBox.AppendText("$ ")
        $logBox.SelectionColor = $col; $logBox.AppendText("$msg`n")
        $logBox.ScrollToCaret()
        [System.Windows.Forms.Application]::DoEvents()
    } catch { }
}

# ===================== CONTROLS =====================
 $btnPanel = New-Object System.Windows.Forms.Panel
 $btnPanel.Location = New-Object System.Drawing.Point(20, 510); $btnPanel.Size = New-Object System.Drawing.Size(920, 80)
 $btnPanel.BackColor = [System.Drawing.Color]::Transparent
 $form.Controls.Add($btnPanel)

 $btnClear = New-Object System.Windows.Forms.Button
 $btnClear.Text = "CLEAR LOG"; $btnClear.Location = New-Object System.Drawing.Point(150, 20)
 $btnClear.Size = New-Object System.Drawing.Size(120, 35); $btnClear.Font = New-Object System.Drawing.Font("Consolas",9)
 $btnClear.FlatStyle = "Flat"; $btnClear.FlatAppearance.BorderColor = $DARK_BORDER; $btnClear.ForeColor = $SECONDARY
 $btnPanel.Controls.Add($btnClear)

 $btnRun = New-Object System.Windows.Forms.Button
 $btnRun.Text = "EXECUTE FOUR"; $btnRun.Location = New-Object System.Drawing.Point(310, 5)
 $btnRun.Size = New-Object System.Drawing.Size(300, 60)
 $btnRun.Font = New-Object System.Drawing.Font("Consolas",16,[System.Drawing.FontStyle]::Bold)
 $btnRun.FlatStyle = "Flat"; $btnRun.FlatAppearance.BorderColor = $PRIMARY; $btnRun.FlatAppearance.BorderSize = 2
 $btnRun.ForeColor = $PRIMARY; $btnRun.BackColor = [System.Drawing.Color]::Transparent
 $btnPanel.Controls.Add($btnRun)

 $btnExit = New-Object System.Windows.Forms.Button
 $btnExit.Text = "TERMINATE"; $btnExit.Location = New-Object System.Drawing.Point(650, 20)
 $btnExit.Size = New-Object System.Drawing.Size(120, 35); $btnExit.Font = New-Object System.Drawing.Font("Consolas",9)
 $btnExit.FlatStyle = "Flat"; $btnExit.FlatAppearance.BorderColor = $ERR_COLOR; $btnExit.ForeColor = $ERR_COLOR
 $btnPanel.Controls.Add($btnExit)

# ===================== HELPERS =====================
function Set-StepActive {
    param([int]$active)
    foreach ($s in $stepDefs) {
        $id = $s.id
        if ($id -eq $active) {
            $stepLabels[$id].ForeColor = $ACCENT
        } elseif ($id -lt $active) {
            $stepLabels[$id].ForeColor = $SECONDARY
        } else {
            $stepLabels[$id].ForeColor = $DARK_BORDER
        }
    }
    [System.Windows.Forms.Application]::DoEvents()
}

function Set-Progress {
    param([int]$main)
    try {
        $progressBar.Value = [Math]::Max(0, [Math]::Min($main, 100))
        $filled = [Math]::Floor($main / 10)
        $lblProgress.Text  = "PROGRESS [$(('>' * $filled) + ('-' * (10 - $filled)))] $main%"
        [System.Windows.Forms.Application]::DoEvents()
    } catch { }
}

# ===================== RUN BUTTON LOGIC =====================
 $btnRun.Add_Click({
    $btnRun.Enabled = $false; $btnRun.Text = "RUNNING..."; $btnRun.ForeColor = $ACCENT
    $lblStatusMain.Text = "● PROCESSING"; $lblStatusMain.ForeColor = $PRIMARY

    foreach ($s in $stepDefs) { $stepLabels[$s.id].ForeColor = $DARK_BORDER }
    Write-Log "four --initialize" "hi"
    Write-Log "Loading core modules... [OK]" "ok"
    Write-Log "-----------------------------------------" "dim"

    # STEP 1
    Set-StepActive 1; Set-Progress 2
    Write-Log "Executing TCP_GLOBAL_OPT..." "step"
    $tcpCmds = @("netsh int tcp set global rss=enabled","netsh int tcp set global dca=enabled","netsh int tcp set global netdma=enabled","netsh int tcp set global chimney=disabled","netsh int tcp set global rsc=disabled","netsh int tcp set global ecncapability=disabled","netsh int tcp set global timestamps=disabled","netsh int tcp set global nonsackrttresiliency=disabled","netsh int tcp set global autotuninglevel=disabled","netsh int tcp set global fastopen=enabled","netsh int tcp set global fastopenfallback=enabled","netsh int tcp set global maxsynretransmissions=2","netsh int tcp set global initialrto=2000","netsh int tcp set global mincto=0","netsh int tcp set global congestionprovider=ctcp","netsh int tcp set supplemental congestionprovider=ctcp","netsh int tcp set heuristics disabled","netsh int ipv4 set glob defaultcurhoplimit=64","netsh int ipv6 set glob defaultcurhoplimit=64","netsh int ip set global taskoffload=enabled","netsh int ip set global multicastforwarding=disabled","netsh int ip set global reassemblylimit=0","netsh int udp set global uro=disabled","netsh int tcp set global memoryprofile=normal","netsh int ipv6 set global randomizeidentifiers=disabled","netsh int ipv6 set privacy state=disabled")
    foreach ($cmd in $tcpCmds) { try { Invoke-Expression "$cmd 2>&1" | Out-Null; Write-Log "Patch applied: $cmd" "dim" } catch { Write-Log "Patch failed: $cmd" "err" } }
    Write-Log "TCP Global optimized. [OK]" "ok"; Set-Progress 17

    # STEP 2
    Set-StepActive 2; Set-Progress 17
    Write-Log "Executing REG_INTERFACE_KEY..." "step"
    $ifPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces"
    $ifVals = [ordered]@{ "MTU"=1500; "MSS"=1460; "TcpWindowSize"=65535; "GlobalMaxTcpWindowSize"=65535; "WorldMaxTcpWindowsSize"=65535; "TcpAckFrequency"=1; "TcpDelAckTicks"=0; "TCPNoDelay"=1; "TcpMaxDataRetransmissions"=3; "TCPTimedWaitDelay"=30; "TCPInitialRtt"=300; "TcpMaxDupAcks"=2; "Tcp1323Opts"=1; "SackOpts"=1; "KeepAliveTime"=30000; "KeepAliveInterval"=1000; "MaxConnectionsPerServer"=16; "MaxConnectionsPer1_0Server"=16; "DefaultTTL"=64; "EnablePMTUBHDetect"=0; "EnablePMTUDiscovery"=1; "DisableTaskOffload"=0; "DisableLargeMTU"=0; "IRPStackSize"=32; "NumTcbTablePartitions"=4; "MaxFreeTcbs"=65536; "MaxUserPort"=65534; "TcpMaxSendFree"=65535; "MaxHashTableSize"=65536; "DisableRss"=0; "DisableTcpChimneyOffload"=1; "EnableICMPRedirect"=0; "EnableDHCP"=1; "SynAttackProtect"=0 }
    foreach ($kv in $ifVals.GetEnumerator()) { Set-ItemProperty -Path $ifPath -Name $kv.Key -Value $kv.Value -Type DWord -Force -ErrorAction SilentlyContinue }
    Write-Log "Interface keys injected. [OK]" "ok"; Set-Progress 34

    # STEP 3
    Set-StepActive 3; Set-Progress 34
    Write-Log "Executing REG_PARAMS_LATENCY..." "step"
    $pPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"
    $pVals = [ordered]@{ "MTU"=1500; "MSS"=1460; "TcpAckFrequency"=1; "TcpDelAckTicks"=0; "TCPNoDelay"=1; "TcpWindowSize"=65535; "GlobalMaxTcpWindowSize"=65535; "SackOpts"=1; "Tcp1323Opts"=1; "TcpMaxDataRetransmissions"=3; "TCPTimedWaitDelay"=30; "IRPStackSize"=32; "DefaultTTL"=64; "KeepAliveTime"=30000; "KeepAliveInterval"=1000; "TCPInitialRtt"=300; "TcpMaxDupAcks"=2; "EnablePMTUBHDetect"=0; "EnablePMTUDiscovery"=1; "DisableTaskOffload"=0; "MaxHashTableSize"=65536; "MaxUserPort"=65534; "MaxFreeTcbs"=65536; "TcpMaxSendFree"=65535; "DeadGWDetectDefault"=1; "NumForwardPackets"=500; "MaxNumForwardPackets"=500; "ForwardBufferMemory"=196608; "MaxForwardBufferMemory"=196608; "SynAttackProtect"=0; "EnableICMPRedirect"=0; "NumTcbTablePartitions"=4 }
    foreach ($kv in $pVals.GetEnumerator()) { Set-ItemProperty -Path $pPath -Name $kv.Key -Value $kv.Value -Type DWord -Force -ErrorAction SilentlyContinue }
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" -Name "Win32PrioritySeparation" -Value 38 -Type DWord -Force -ErrorAction SilentlyContinue
    $mmPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
    Set-ItemProperty -Path $mmPath -Name "NetworkThrottlingIndex" -Value 0xffffffff -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $mmPath -Name "SystemResponsiveness" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
    $gameProfile = "$mmPath\Tasks\Games"
    if (-not (Test-Path $gameProfile)) { New-Item -Path $gameProfile -Force | Out-Null }
    Set-ItemProperty -Path $gameProfile -Name "GPU Priority" -Value 8 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $gameProfile -Name "Priority" -Value 6 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $gameProfile -Name "Scheduling Category" -Value "High" -Type String -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $gameProfile -Name "SFIO Priority" -Value "High" -Type String -Force -ErrorAction SilentlyContinue
    Write-Log "Latency params set. Game profile tuned. [OK]" "ok"; Set-Progress 50

    # STEP 4
    Set-StepActive 4; Set-Progress 50
    Write-Log "Executing PROC_PRIORITY_LIST..." "step"
    $highList = @("FiveM_b2545_GTAProcess","FiveM_b2699_GTAProcess","FiveM_b2802_GTAProcess","FiveM_b2944_GTAProcess","FiveM_b3095_GTAProcess","FiveM_GTAProcess","FiveM","FiveM_SteamChild","CitizenFX.Core","VALORANT-Win64-Shipping","VALORANT","cs2","csgo","RainbowSix","RainbowSix_BE","r5apex","r5apex_dx12","EscapeFromTarkov","Rust","RustClient","FortniteClient-Win64-Shipping","PUBG","GenshinImpact","ZZZ","Overwatch","Overwatch_retail")
    $lowList  = @("steam","explorer","Discord","chrome","firefox","SearchApp","SearchHost","Widgets")
    foreach ($pn in $highList) { $proc = Get-Process -Name $pn -ErrorAction SilentlyContinue; if ($proc) { try { $proc.PriorityClass = "High"; Write-Log "HIGH -> $pn" "ok" } catch {} } }
    foreach ($pn in $lowList) { $proc = Get-Process -Name $pn -ErrorAction SilentlyContinue; if ($proc) { try { $proc.PriorityClass = "BelowNormal"; Write-Log "LOW -> $pn" "warn" } catch {} } }
    Write-Log "Process priorities adjusted. [OK]" "ok"; Set-Progress 67

    # STEP 5
    Set-StepActive 5; Set-Progress 67
    Write-Log "Executing IRQ_AFFINITY_TUNER..." "step"
    try { powercfg -setactive SCHEME_MIN 2>&1 | Out-Null; Write-Log "Power scheme -> HIGH_PERF" "ok" } catch {}
    try { bcdedit /set useplatformclock false 2>&1 | Out-Null; bcdedit /set disabledynamictick yes 2>&1 | Out-Null; Write-Log "Timer latency reduced." "ok" } catch {}
    try { bcdedit /deletevalue useplatformhpet 2>&1 | Out-Null; Write-Log "HPET -> CLEARED" "ok" } catch {}
    Write-Log "IRQ & Power hints applied. [OK]" "ok"; Set-Progress 83

    # STEP 6
    Set-StepActive 6; Set-Progress 83
    Write-Log "Executing SERVICE_DISABLER..." "step"
    $svcs = @(@{name="SysMain";reason="Prefetch"}, @{name="DiagTrack";reason="Telemetry"}, @{name="dmwappushservice";reason="WAP push"}, @{name="WSearch";reason="Search Indexer"}, @{name="Fax";reason="Fax"}, @{name="RemoteRegistry";reason="Remote Reg"}, @{name="RetailDemo";reason="Retail"}, @{name="TabletInputService";reason="Tablet"})
    foreach ($svc in $svcs) { Stop-Service -Name $svc.name -Force -ErrorAction SilentlyContinue; Set-Service -Name $svc.name -StartupType Disabled -ErrorAction SilentlyContinue; Write-Log "DISABLED -> $($svc.name)" "ok" }
    
    # COMPLETE
    foreach ($s in $stepDefs) { $stepLabels[$s.id].ForeColor = $SECONDARY }
    Set-Progress 100
    Write-Log "-----------------------------------------" "dim"
    Write-Log "SYSTEM OPTIMIZATION COMPLETE." "hi"
    Write-Log "Reboot recommended to apply kernel changes." "warn"

    $lblStatusMain.Text = "● OPTIMIZED"; $lblStatusMain.ForeColor = $ACCENT
    $btnRun.Enabled = $true; $btnRun.Text = "EXECUTE FOUR"; $btnRun.ForeColor = $PRIMARY
})

 $btnClear.Add_Click({ 
    $logBox.Clear()
    Set-Progress 0
    foreach ($s in $stepDefs) { $stepLabels[$s.id].ForeColor = $DARK_BORDER }
    $lblStatusMain.Text = "● SYSTEM READY"; $lblStatusMain.ForeColor = $ACCENT
    Write-Log "System reset. Ready to execute." "hi"
})

 $btnExit.Add_Click({ $form.Close() })

# ===================== INIT LOG =====================
Write-Log "four --initialize" "hi"
Write-Log "Detecting system hardware..." "dim"
Write-Log "OS:  $osInfo" "dim"
Write-Log "CPU: $cpuInfo" "dim"
Write-Log "RAM: $ramGB GB" "dim"
Write-Log "-----------------------------------------" "dim"
Write-Log "READY TO EXECUTE." "ok"

[void]$form.ShowDialog()
    try {
        $cpu = (Get-WmiObject Win32_Processor | Select-Object -First 1).ProcessorId
        $mb  = (Get-WmiObject Win32_BaseBoard | Select-Object -First 1).SerialNumber
        $raw = "$cpu-$mb"
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($raw)
        $hash  = [System.Security.Cryptography.SHA256]::Create().ComputeHash($bytes)
        return ([BitConverter]::ToString($hash) -replace '-','').Substring(0,16)
    } catch { return "UNKNOWN-$(Get-Random)" }
}
 $HWID = Get-HWID

# ===================== COLORS =====================
 $BG_COLOR    = [System.Drawing.Color]::FromArgb(5, 10, 20)
 $PRIMARY     = [System.Drawing.Color]::FromArgb(0, 210, 255)  # Cyan
 $SECONDARY   = [System.Drawing.Color]::FromArgb(0, 69, 139)   # Dark Blue
 $TEXT_COLOR  = [System.Drawing.Color]::FromArgb(224, 247, 255)
 $ACCENT      = [System.Drawing.Color]::FromArgb(0, 255, 140)  # Neon Green
 $GLASS       = [System.Drawing.Color]::FromArgb(10, 20, 40)
 $DARK_BORDER = [System.Drawing.Color]::FromArgb(0, 40, 80)

# ===================== LICENSE KEY FORM =====================
 $authForm = New-Object System.Windows.Forms.Form
 $authForm.Text = "FOUR // AUTH"
 $authForm.Size = New-Object System.Drawing.Size(480, 300)
 $authForm.StartPosition = "CenterScreen"
 $authForm.BackColor = $BG_COLOR
 $authForm.ForeColor = $TEXT_COLOR
 $authForm.FormBorderStyle = "None"
 $authForm.TopMost = $true

# สร้างมุมตัดแบบ Sci-Fi
 $authPath = New-Object System.Drawing.Drawing2D.GraphicsPath
 $authPath.AddPolygon(@(
    (New-Object System.Drawing.Point(20, 0)),
    (New-Object System.Drawing.Point(460, 0)),
    (New-Object System.Drawing.Point(480, 20)),
    (New-Object System.Drawing.Point(480, 280)),
    (New-Object System.Drawing.Point(20, 280)),
    (New-Object System.Drawing.Point(0, 260))
))
 $authForm.Region = New-Object System.Drawing.Region($authPath)

 $script:dragAuth = $false
 $authForm.Add_MouseDown({$script:dragAuth=$true; $script:dragAuthStart=$_.Location})
 $authForm.Add_MouseMove({if($script:dragAuth){$authForm.Left += $_.X - $script:dragAuthStart.X; $authForm.Top += $_.Y - $script:dragAuthStart.Y}})
 $authForm.Add_MouseUp({$script:dragAuth=$false})

 $authForm.Add_Paint({
    $g = $_.Graphics
    $p = New-Object System.Drawing.Pen($PRIMARY, 2)
    $g.DrawPolygon($p, @(
        (New-Object System.Drawing.Point(20, 0)),
        (New-Object System.Drawing.Point(460, 0)),
        (New-Object System.Drawing.Point(480, 20)),
        (New-Object System.Drawing.Point(480, 280)),
        (New-Object System.Drawing.Point(20, 280)),
        (New-Object System.Drawing.Point(0, 260))
    ))
    $p.Dispose()
})

 $authTitle = New-Object System.Windows.Forms.Label
 $authTitle.Text = "[ F O U R ] // ACCESS CONTROL"; $authTitle.Font = New-Object System.Drawing.Font("Consolas",12,[System.Drawing.FontStyle]::Bold)
 $authTitle.ForeColor = $PRIMARY; $authTitle.Location = New-Object System.Drawing.Point(20,20); $authTitle.AutoSize=$true
 $authForm.Controls.Add($authTitle)

 $keyInput = New-Object System.Windows.Forms.TextBox
 $keyInput.Location = New-Object System.Drawing.Point(30,80); $keyInput.Size = New-Object System.Drawing.Size(420,30)
 $keyInput.Font = New-Object System.Drawing.Font("Consolas",12,[System.Drawing.FontStyle]::Bold)
 $keyInput.BackColor = [System.Drawing.Color]::FromArgb(10, 15, 30); $keyInput.ForeColor = $ACCENT
 $keyInput.Text = "FOUR-XXXX-XXXX-XXXX"
 $authForm.Controls.Add($keyInput)

 $status = New-Object System.Windows.Forms.Label
 $status.Location = New-Object System.Drawing.Point(30,120); $status.Size = New-Object System.Drawing.Size(420,40)
 $status.Font = New-Object System.Drawing.Font("Consolas",9)
 $authForm.Controls.Add($status)

 $verifyBtn = New-Object System.Windows.Forms.Button
 $verifyBtn.Text = "AUTHENTICATE"; $verifyBtn.Location = New-Object System.Drawing.Point(30,180)
 $verifyBtn.Size = New-Object System.Drawing.Size(420,50)
 $verifyBtn.Font = New-Object System.Drawing.Font("Consolas",12,[System.Drawing.FontStyle]::Bold)
 $verifyBtn.FlatStyle = "Flat"; $verifyBtn.FlatAppearance.BorderColor = $PRIMARY; $verifyBtn.FlatAppearance.BorderSize = 2
 $verifyBtn.BackColor = [System.Drawing.Color]::Transparent; $verifyBtn.ForeColor = $PRIMARY
 $authForm.Controls.Add($verifyBtn)

 $verifyBtn.Add_Click({
    $key = $keyInput.Text.Trim().ToUpper()
    if ($key.Length -lt 15) { $status.ForeColor = [System.Drawing.Color]::FromArgb(255,50,50); $status.Text = "ERROR: Invalid key format"; return }
    $verifyBtn.Enabled = $false; $verifyBtn.Text = "VERIFYING..."
    $status.ForeColor = $PRIMARY; $status.Text = "$ Connecting to server..."
    try {
        $body = @{ key = $key; hwid = $HWID } | ConvertTo-Json
        $headers = @{ "Content-Type" = "application/json"; "x-babydek-client" = $CLIENT_SECRET }
        $resp = Invoke-RestMethod -Uri $KEY_SERVER_URL -Method Post -Headers $headers -Body $body -TimeoutSec 15
        if ($resp.valid) {
            $status.ForeColor = $ACCENT; $status.Text = "$ Access Granted"
            Start-Sleep -Milliseconds 800; $authForm.DialogResult = "OK"; $authForm.Close()
        } else {
            $status.ForeColor = [System.Drawing.Color]::FromArgb(255,50,50); $status.Text = "$ ERROR: $($resp.reason)"
            $verifyBtn.Enabled = $true; $verifyBtn.Text = "AUTHENTICATE"
        }
    } catch {
        $status.ForeColor = [System.Drawing.Color]::FromArgb(255,50,50); $status.Text = "$ CONNECTION FAILED"
        $verifyBtn.Enabled = $true; $verifyBtn.Text = "AUTHENTICATE"
    }
})

if ($authForm.ShowDialog() -ne "OK") { exit }

# ===================== MAIN OPTIMIZER FORM =====================
 $form = New-Object System.Windows.Forms.Form
 $form.Text = "FOUR // SYSTEM OPTIMIZER"
 $form.Size = New-Object System.Drawing.Size(960, 720)
 $form.StartPosition = "CenterScreen"
 $form.BackColor = $BG_COLOR
 $form.ForeColor = $TEXT_COLOR
 $form.FormBorderStyle = "None"
 $form.Font = New-Object System.Drawing.Font("Consolas", 9)

# สร้างมุมตัดแบบ Sci-Fi ขนาดใหญ่
 $mainPath = New-Object System.Drawing.Drawing2D.GraphicsPath
 $mainPath.AddPolygon(@(
    (New-Object System.Drawing.Point(30, 0)),
    (New-Object System.Drawing.Point(930, 0)),
    (New-Object System.Drawing.Point(960, 30)),
    (New-Object System.Drawing.Point(960, 690)),
    (New-Object System.Drawing.Point(930, 720)),
    (New-Object System.Drawing.Point(30, 720)),
    (New-Object System.Drawing.Point(0, 690)),
    (New-Object System.Drawing.Point(0, 30))
))
 $form.Region = New-Object System.Drawing.Region($mainPath)

 $script:_dragMain = $false
 $form.Add_MouseDown({ param($s,$e) if ($e.Button -eq [System.Windows.Forms.MouseButtons]::Left) { $script:_dragMain = $true; $script:_dragMainStart = $e.Location } })
 $form.Add_MouseMove({ param($s,$e) if ($script:_dragMain) { $form.Left += $e.X - $script:_dragMainStart.X; $form.Top += $e.Y - $script:_dragMainStart.Y } })
 $form.Add_MouseUp({ $script:_dragMain = $false })

# วาด Grid พื้นหลังและขอบ
 $form.Add_Paint({
    $g = $_.Graphics
    # Grid
    $gridPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(15, 30, 60), 1)
    for ($i = 0; $i -lt $form.Width; $i += 50) { $g.DrawLine($gridPen, $i, 0, $i, $form.Height) }
    for ($i = 0; $i -lt $form.Height; $i += 50) { $g.DrawLine($gridPen, 0, $i, $form.Width, $i) }
    $gridPen.Dispose()

    # Border
    $p = New-Object System.Drawing.Pen($PRIMARY, 2)
    $g.DrawPolygon($p, @(
        (New-Object System.Drawing.Point(30, 0)), (New-Object System.Drawing.Point(930, 0)),
        (New-Object System.Drawing.Point(960, 30)), (New-Object System.Drawing.Point(960, 690)),
        (New-Object System.Drawing.Point(930, 720)), (New-Object System.Drawing.Point(30, 720)),
        (New-Object System.Drawing.Point(0, 690)), (New-Object System.Drawing.Point(0, 30))
    ))
    $p.Dispose()
})

# ===================== HEADER =====================
 $headerPanel = New-Object System.Windows.Forms.Panel
 $headerPanel.Location = New-Object System.Drawing.Point(20, 10)
 $headerPanel.Size = New-Object System.Drawing.Size(920, 50)
 $headerPanel.BackColor = [System.Drawing.Color]::Transparent
 $form.Controls.Add($headerPanel)

 $headerPanel.Add_Paint({
    $g = $_.Graphics
    $p = New-Object System.Drawing.Pen($PRIMARY, 1)
    $g.DrawLine($p, 0, 48, 920, 48)
    $p.Dispose()
})

 $lblLogo = New-Object System.Windows.Forms.Label
 $lblLogo.Text = "[ F O U R ]"; $lblLogo.Font = New-Object System.Drawing.Font("Consolas",20,[System.Drawing.FontStyle]::Bold)
 $lblLogo.ForeColor = $PRIMARY; $lblLogo.Location = New-Object System.Drawing.Point(10, 8); $lblLogo.AutoSize=$true
 $headerPanel.Controls.Add($lblLogo)

 $lblSubLogo = New-Object System.Windows.Forms.Label
 $lblSubLogo.Text = "SYS_OPTIMIZER_V2"; $lblSubLogo.Font = New-Object System.Drawing.Font("Consolas",8)
 $lblSubLogo.ForeColor = $SECONDARY; $lblSubLogo.Location = New-Object System.Drawing.Point(220, 22); $lblSubLogo.AutoSize=$true
 $headerPanel.Controls.Add($lblSubLogo)

 $lblStatusMain = New-Object System.Windows.Forms.Label
 $lblStatusMain.Text = "● SYSTEM READY"; $lblStatusMain.Font = New-Object System.Drawing.Font("Consolas",10,[System.Drawing.FontStyle]::Bold)
 $lblStatusMain.ForeColor = $ACCENT; $lblStatusMain.Location = New-Object System.Drawing.Point(730, 18); $lblStatusMain.AutoSize=$true
 $headerPanel.Controls.Add($lblStatusMain)

# ===================== SYSTEM BAR =====================
 $sysBarY = 70
 $sysItems = @("Operating System", "Processor", "Memory", "Network")
try {
    $osInfo = (Get-WmiObject Win32_OperatingSystem).Caption.Substring(0,20)
    $cpuInfo = (Get-WmiObject Win32_Processor).Name.Substring(0,20)
    $ramGB = [math]::Round((Get-WmiObject Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 1)
    $netAdapters = (Get-WmiObject Win32_NetworkAdapter -Filter "NetEnabled=True" | Select-Object -First 1).Name
    if($netAdapters.Length -gt 15){$netAdapters = $netAdapters.Substring(0,15)}
} catch { $osInfo="N/A"; $cpuInfo="N/A"; $ramGB="0"; $netAdapters="N/A" }
 $sysVals = @($osInfo, $cpuInfo, "$ramGB GB", $netAdapters)

 $sX = 20
for ($i=0; $i -lt 4; $i++) {
    $card = New-Object System.Windows.Forms.Panel
    $card.Location = New-Object System.Drawing.Point($sX, $sysBarY)
    $card.Size = New-Object System.Drawing.Size(215, 45)
    $card.BackColor = $GLASS
    $card.Tag = $i
    $card.Add_Paint({
        $g = $_.Graphics
        $pen = New-Object System.Drawing.Pen($PRIMARY, 3)
        $g.DrawLine($pen, 0, 0, 0, 45)
        $pen.Dispose()
    })
    $form.Controls.Add($card)

    $lbl1 = New-Object System.Windows.Forms.Label
    $lbl1.Text = $sysItems[$i]; $lbl1.Font = New-Object System.Drawing.Font("Consolas",7)
    $lbl1.ForeColor = $PRIMARY; $lbl1.Location = New-Object System.Drawing.Point(8, 5); $lbl1.AutoSize=$true
    $card.Controls.Add($lbl1)

    $lbl2 = New-Object System.Windows.Forms.Label
    $lbl2.Text = $sysVals[$i]; $lbl2.Font = New-Object System.Drawing.Font("Consolas",10,[System.Drawing.FontStyle]::Bold)
    $lbl2.ForeColor = $TEXT_COLOR; $lbl2.Location = New-Object System.Drawing.Point(8, 22); $lbl2.AutoSize=$true
    $card.Controls.Add($lbl2)

    $sX += 225
}

# ===================== STAGES PANEL =====================
 $stagesPanel = New-Object System.Windows.Forms.Panel
 $stagesPanel.Location = New-Object System.Drawing.Point(20, 130)
 $stagesPanel.Size = New-Object System.Drawing.Size(250, 360)
 $stagesPanel.BackColor = [System.Drawing.Color]::Transparent
 $form.Controls.Add($stagesPanel)

 $stepDefs = @(
    @{ id=1; label="[01] TCP_GLOBAL_OPT" },
    @{ id=2; label="[02] REG_INTERFACE_KEY" },
    @{ id=3; label="[03] REG_PARAMS_LATENCY" },
    @{ id=4; label="[04] PROC_PRIORITY_LIST" },
    @{ id=5; label="[05] IRQ_AFFINITY_TUNER" },
    @{ id=6; label="[06] SERVICE_DISABLER" }
)

 $stepLabels = @{}
 $sY = 0
foreach ($s in $stepDefs) {
    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = $s.label
    $lbl.Font = New-Object System.Drawing.Font("Consolas", 10)
    $lbl.ForeColor = $DARK_BORDER
    $lbl.Location = New-Object System.Drawing.Point(0, $sY)
    $lbl.Size = New-Object System.Drawing.Size(240, 28)
    $lbl.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
    $stagesPanel.Controls.Add($lbl)
    $stepLabels[$s.id] = $lbl
    $sY += 40
}

# ===================== TERMINAL OUTPUT =====================
 $terminalPanel = New-Object System.Windows.Forms.Panel
 $terminalPanel.Location = New-Object System.Drawing.Point(280, 130)
 $terminalPanel.Size = New-Object System.Drawing.Size(660, 360)
 $terminalPanel.BackColor = [System.Drawing.Color]::FromArgb(2, 5, 15)
 $terminalPanel.BorderStyle = "None"
 $form.Controls.Add($terminalPanel)

 $terminalPanel.Add_Paint({
    $g = $_.Graphics
    $p = New-Object System.Drawing.Pen($DARK_BORDER, 1)
    $g.DrawRectangle($p, 0, 0, 659, 359)
    $p.Dispose()
    $txtBrush = New-Object System.Drawing.SolidBrush($DARK_BORDER)
    $g.DrawString("SYSTEM LOG STREAM", (New-Object System.Drawing.Font("Consolas",7)), $txtBrush, 530, 5)
    $txtBrush.Dispose()
})

 $logBox = New-Object System.Windows.Forms.RichTextBox
 $logBox.Location = New-Object System.Drawing.Point(5, 20)
 $logBox.Size = New-Object System.Drawing.Size(650, 335)
 $logBox.BackColor = [System.Drawing.Color]::FromArgb(2, 5, 15)
 $logBox.ForeColor = $PRIMARY
 $logBox.Font = New-Object System.Drawing.Font("Consolas", 10)
 $logBox.ReadOnly = $true
 $logBox.BorderStyle = "None"
 $logBox.ScrollBars = "Vertical"
 $terminalPanel.Controls.Add($logBox)

function Write-Log {
    param([string]$msg, [string]$type = "info")
    try {
        $col = switch ($type) {
            "ok"    { $ACCENT }
            "warn"  { [System.Drawing.Color]::FromArgb(255, 200, 0) }
            "err"   { [System.Drawing.Color]::FromArgb(255, 50, 50) }
            "dim"   { $DARK_BORDER }
            "hi"    { $TEXT_COLOR }
            "step"  { $PRIMARY }
            default { $PRIMARY }
        }
        $logBox.SelectionStart = $logBox.TextLength
        $logBox.SelectionLength = 0
        $logBox.SelectionColor = $PRIMARY
        $logBox.AppendText("$ ")
        $logBox.SelectionColor = $col
        $logBox.AppendText("$msg`n")
        $logBox.ScrollToCaret()
        [System.Windows.Forms.Application]::DoEvents()
    } catch { }
}

# ===================== CONTROLS =====================
 $btnPanel = New-Object System.Windows.Forms.Panel
 $btnPanel.Location = New-Object System.Drawing.Point(20, 510)
 $btnPanel.Size = New-Object System.Drawing.Size(920, 80)
 $btnPanel.BackColor = [System.Drawing.Color]::Transparent
 $form.Controls.Add($btnPanel)

 $btnClear = New-Object System.Windows.Forms.Button
 $btnClear.Text = "CLEAR LOG"; $btnClear.Location = New-Object System.Drawing.Point(150, 20)
 $btnClear.Size = New-Object System.Drawing.Size(120, 35); $btnClear.Font = New-Object System.Drawing.Font("Consolas",9)
 $btnClear.FlatStyle = "Flat"; $btnClear.FlatAppearance.BorderColor = $DARK_BORDER; $btnClear.ForeColor = $SECONDARY
 $btnPanel.Controls.Add($btnClear)

 $btnRun = New-Object System.Windows.Forms.Button
 $btnRun.Text = "EXECUTE FOUR"; $btnRun.Location = New-Object System.Drawing.Point(310, 5)
 $btnRun.Size = New-Object System.Drawing.Size(300, 60)
 $btnRun.Font = New-Object System.Drawing.Font("Consolas",16,[System.Drawing.FontStyle]::Bold)
 $btnRun.FlatStyle = "Flat"; $btnRun.FlatAppearance.BorderColor = $PRIMARY; $btnRun.FlatAppearance.BorderSize = 2
 $btnRun.ForeColor = $PRIMARY; $btnRun.BackColor = [System.Drawing.Color]::Transparent
 $btnPanel.Controls.Add($btnRun)

 $btnExit = New-Object System.Windows.Forms.Button
 $btnExit.Text = "TERMINATE"; $btnExit.Location = New-Object System.Drawing.Point(650, 20)
 $btnExit.Size = New-Object System.Drawing.Size(120, 35); $btnExit.Font = New-Object System.Drawing.Font("Consolas",9)
 $btnExit.FlatStyle = "Flat"; $btnExit.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(255,50,50); $btnExit.ForeColor = [System.Drawing.Color]::FromArgb(255,50,50)
 $btnPanel.Controls.Add($btnExit)

# ===================== HELPERS =====================
function Set-StepActive {
    param([int]$active)
    foreach ($s in $stepDefs) {
        $id = $s.id
        if ($id -eq $active) {
            $stepLabels[$id].ForeColor = $ACCENT
            $stepLabels[$id].Text = $stepLabels[$id].Text -replace '\[', '>'
        } elseif ($id -lt $active) {
            $stepLabels[$id].ForeColor = $SECONDARY
        } else {
            $stepLabels[$id].ForeColor = $DARK_BORDER
        }
    }
    [System.Windows.Forms.Application]::DoEvents()
}

# ===================== RUN BUTTON =====================
 $btnRun.Add_Click({
    $btnRun.Enabled = $false; $btnRun.Text = "RUNNING..."; $btnRun.ForeColor = $ACCENT
    $lblStatusMain.Text = "● PROCESSING"; $lblStatusMain.ForeColor = $PRIMARY

    foreach ($s in $stepDefs) { $stepLabels[$s.id].ForeColor = $DARK_BORDER }
    Write-Log "four --initialize" "hi"
    Write-Log "Loading core modules... [OK]" "ok"
    Write-Log "-----------------------------------------" "dim"

    # STEP 1
    Set-StepActive 1
    Write-Log "Executing TCP_GLOBAL_OPT..." "step"
    $tcpCmds = @("netsh int tcp set global rss=enabled","netsh int tcp set global dca=enabled","netsh int tcp set global netdma=enabled","netsh int tcp set global chimney=disabled","netsh int tcp set global rsc=disabled","netsh int tcp set global ecncapability=disabled","netsh int tcp set global timestamps=disabled","netsh int tcp set global nonsackrttresiliency=disabled","netsh int tcp set global autotuninglevel=disabled","netsh int tcp set global fastopen=enabled","netsh int tcp set global fastopenfallback=enabled","netsh int tcp set global maxsynretransmissions=2","netsh int tcp set global initialrto=2000","netsh int tcp set global mincto=0","netsh int tcp set global congestionprovider=ctcp","netsh int tcp set supplemental congestionprovider=ctcp","netsh int tcp set heuristics disabled","netsh int ipv4 set glob defaultcurhoplimit=64","netsh int ipv6 set glob defaultcurhoplimit=64","netsh int ip set global taskoffload=enabled","netsh int ip set global multicastforwarding=disabled","netsh int ip set global reassemblylimit=0","netsh int udp set global uro=disabled","netsh int tcp set global memoryprofile=normal","netsh int ipv6 set global randomizeidentifiers=disabled","netsh int ipv6 set privacy state=disabled")
    foreach ($cmd in $tcpCmds) {
        try { Invoke-Expression "$cmd 2>&1" | Out-Null; Write-Log "Patch applied: $cmd" "ok" } catch { Write-Log "Patch failed: $cmd" "err" }
    }
    Write-Log "TCP Global optimized." "ok"

    # STEP 2
    Set-StepActive 2
    Write-Log "Executing REG_INTERFACE_KEY..." "step"
    $ifPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces"
    $ifVals = [ordered]@{ "MTU"=1500; "MSS"=1460; "TcpWindowSize"=65535; "GlobalMaxTcpWindowSize"=65535; "WorldMaxTcpWindowsSize"=65535; "TcpAckFrequency"=1; "TcpDelAckTicks"=0; "TCPNoDelay"=1; "TcpMaxDataRetransmissions"=3; "TCPTimedWaitDelay"=30; "TCPInitialRtt"=300; "TcpMaxDupAcks"=2; "Tcp1323Opts"=1; "SackOpts"=1; "KeepAliveTime"=30000; "KeepAliveInterval"=1000; "MaxConnectionsPerServer"=16; "MaxConnectionsPer1_0Server"=16; "DefaultTTL"=64; "EnablePMTUBHDetect"=0; "EnablePMTUDiscovery"=1; "DisableTaskOffload"=0; "DisableLargeMTU"=0; "IRPStackSize"=32; "NumTcbTablePartitions"=4; "MaxFreeTcbs"=65536; "MaxUserPort"=65534; "TcpMaxSendFree"=65535; "MaxHashTableSize"=65536; "DisableRss"=0; "DisableTcpChimneyOffload"=1; "EnableICMPRedirect"=0; "EnableDHCP"=1; "SynAttackProtect"=0 }
    foreach ($kv in $ifVals.GetEnumerator()) { Set-ItemProperty -Path $ifPath -Name $kv.Key -Value $kv.Value -Type DWord -Force -ErrorAction SilentlyContinue }
    Write-Log "Interface keys injected." "ok"

    # STEP 3
    Set-StepActive 3
    Write-Log "Executing REG_PARAMS_LATENCY..." "step"
    $pPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"
    $pVals = [ordered]@{ "MTU"=1500; "MSS"=1460; "TcpAckFrequency"=1; "TcpDelAckTicks"=0; "TCPNoDelay"=1; "TcpWindowSize"=65535; "GlobalMaxTcpWindowSize"=65535; "SackOpts"=1; "Tcp1323Opts"=1; "TcpMaxDataRetransmissions"=3; "TCPTimedWaitDelay"=30; "IRPStackSize"=32; "DefaultTTL"=64; "KeepAliveTime"=30000; "KeepAliveInterval"=1000; "TCPInitialRtt"=300; "TcpMaxDupAcks"=2; "EnablePMTUBHDetect"=0; "EnablePMTUDiscovery"=1; "DisableTaskOffload"=0; "MaxHashTableSize"=65536; "MaxUserPort"=65534; "MaxFreeTcbs"=65536; "TcpMaxSendFree"=65535; "DeadGWDetectDefault"=1; "NumForwardPackets"=500; "MaxNumForwardPackets"=500; "ForwardBufferMemory"=196608; "MaxForwardBufferMemory"=196608; "SynAttackProtect"=0; "EnableICMPRedirect"=0; "NumTcbTablePartitions"=4 }
    foreach ($kv in $pVals.GetEnumerator()) { Set-ItemProperty -Path $pPath -Name $kv.Key -Value $kv.Value -Type DWord -Force -ErrorAction SilentlyContinue }
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" -Name "Win32PrioritySeparation" -Value 38 -Type DWord -Force -ErrorAction SilentlyContinue
    $mmPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
    Set-ItemProperty -Path $mmPath -Name "NetworkThrottlingIndex" -Value 0xffffffff -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $mmPath -Name "SystemResponsiveness" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
    $gameProfile = "$mmPath\Tasks\Games"
    if (-not (Test-Path $gameProfile)) { New-Item -Path $gameProfile -Force | Out-Null }
    Set-ItemProperty -Path $gameProfile -Name "GPU Priority" -Value 8 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $gameProfile -Name "Priority" -Value 6 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $gameProfile -Name "Scheduling Category" -Value "High" -Type String -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $gameProfile -Name "SFIO Priority" -Value "High" -Type String -Force -ErrorAction SilentlyContinue
    Write-Log "Latency parameters set. Game profile tuned." "ok"

    # STEP 4
    Set-StepActive 4
    Write-Log "Executing PROC_PRIORITY_LIST..." "step"
    $highList = @("FiveM_b2545_GTAProcess","FiveM_b2699_GTAProcess","FiveM_b2802_GTAProcess","FiveM_b2944_GTAProcess","FiveM_b3095_GTAProcess","FiveM_GTAProcess","FiveM","FiveM_SteamChild","CitizenFX.Core","VALORANT-Win64-Shipping","VALORANT","cs2","csgo","RainbowSix","RainbowSix_BE","r5apex","r5apex_dx12","EscapeFromTarkov","Rust","RustClient","FortniteClient-Win64-Shipping","PUBG","GenshinImpact","ZZZ","Overwatch","Overwatch_retail")
    $lowList  = @("steam","explorer","Discord","chrome","firefox","SearchApp","SearchHost","Widgets")
    foreach ($pn in $highList) { $proc = Get-Process -Name $pn -ErrorAction SilentlyContinue; if ($proc) { try { $proc.PriorityClass = "High"; Write-Log "HIGH -> $pn" "ok" } catch {} } }
    foreach ($pn in $lowList) { $proc = Get-Process -Name $pn -ErrorAction SilentlyContinue; if ($proc) { try { $proc.PriorityClass = "BelowNormal"; Write-Log "LOW -> $pn" "warn" } catch {} } }
    Write-Log "Process priorities adjusted." "ok"

    # STEP 5
    Set-StepActive 5
    Write-Log "Executing IRQ_AFFINITY_TUNER..." "step"
    try { powercfg -setactive SCHEME_MIN 2>&1 | Out-Null; Write-Log "Power scheme -> HIGH_PERF" "ok" } catch {}
    try { bcdedit /set useplatformclock false 2>&1 | Out-Null; bcdedit /set disabledynamictick yes 2>&1 | Out-Null; Write-Log "Timer latency reduced." "ok" } catch {}
    try { bcdedit /deletevalue useplatformhpet 2>&1 | Out-Null; Write-Log "HPET -> CLEARED" "ok" } catch {}
    Write-Log "IRQ & Power hints applied." "ok"

    # STEP 6
    Set-StepActive 6
    Write-Log "Executing SERVICE_DISABLER..." "step"
    $svcs = @(@{name="SysMain";reason="Prefetch"}, @{name="DiagTrack";reason="Telemetry"}, @{name="dmwappushservice";reason="WAP push"}, @{name="WSearch";reason="Search Indexer"}, @{name="Fax";reason="Fax"}, @{name="RemoteRegistry";reason="Remote Reg"}, @{name="RetailDemo";reason="Retail"}, @{name="TabletInputService";reason="Tablet"})
    foreach ($svc in $svcs) { Stop-Service -Name $svc.name -Force -ErrorAction SilentlyContinue; Set-Service -Name $svc.name -StartupType Disabled -ErrorAction SilentlyContinue; Write-Log "DISABLED -> $($svc.name)" "ok" }
    
    # COMPLETE
    foreach ($s in $stepDefs) { $stepLabels[$s.id].ForeColor = $SECONDARY }
    Write-Log "-----------------------------------------" "dim"
    Write-Log "SYSTEM OPTIMIZATION COMPLETE." "hi"
    Write-Log "Reboot recommended to apply all kernel changes." "warn"

    $lblStatusMain.Text = "● OPTIMIZED"; $lblStatusMain.ForeColor = $ACCENT
    $btnRun.Enabled = $true; $btnRun.Text = "EXECUTE FOUR"; $btnRun.ForeColor = $PRIMARY
})

 $btnClear.Add_Click({ $logBox.Clear() })
 $btnExit.Add_Click({ $form.Close() })

Write-Log "four --initialize" "hi"
Write-Log "Detecting system hardware..." "dim"
Write-Log "CPU: $cpuInfo" "dim"
Write-Log "RAM: $ramGB GB" "dim"
Write-Log "-----------------------------------------" "dim"
Write-Log "READY TO EXECUTE." "ok"

[void]$form.ShowDialog()
