#Requires -Version 5.1

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

if (-not ('NativeMethods' -as [type])) {
    Add-Type @"
using System;
using System.Runtime.InteropServices;
public class NativeMethods {
    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    public static extern bool DestroyIcon(IntPtr handle);
}
"@
}

$ErrorActionPreference = 'Stop'

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $scriptRoot 'EthernetToggle.Common.ps1')

$paths = Get-EthernetTogglePaths -ScriptRoot $scriptRoot
$config = Get-EthernetToggleConfig -ConfigPath $paths.ConfigPath
Initialize-EthernetToggleState -ActionDir $paths.ActionDir

$singleInstanceMutex = New-Object System.Threading.Mutex($false, 'Global\EthernetToggleApp')
if (-not $singleInstanceMutex.WaitOne(0, $false)) {
    Request-EthernetToggleWindowFocus -SignalFile $paths.SignalFile
    exit 0
}

$currentIconHandle = [IntPtr]::Zero
$heldBitmap = $null
$isClosing = $false

function Update-ApplicationState {
    param(
        [System.Windows.Forms.NotifyIcon]$NotifyIcon,
        [System.Windows.Forms.Label]$StatusLabel,
        [System.Windows.Forms.Button]$ToggleButton
    )

    $isEnabled = Get-EthernetAdapterEnabled -AdapterName $config.adapterName
    $iconParts = Get-EthernetToggleTrayIcon -IconPath $paths.IconPath -IsOn $isEnabled
    $newIcon = $iconParts[0]
    $newBitmap = $iconParts[1]
    $newHandle = $iconParts[2]

    if ($null -ne $NotifyIcon.Icon) {
        $NotifyIcon.Icon.Dispose()
    }

    if ($currentIconHandle -ne [IntPtr]::Zero) {
        [NativeMethods]::DestroyIcon($currentIconHandle) | Out-Null
    }

    $NotifyIcon.Icon = $newIcon
    $script:currentIconHandle = $newHandle
    $NotifyIcon.Text = if ($isEnabled) { "$($config.appName): On" } else { "$($config.appName): Off" }

    if ($isEnabled) {
        $StatusLabel.Text = 'Ethernet is ON'
        $StatusLabel.ForeColor = [System.Drawing.Color]::FromArgb(46, 160, 67)
        $ToggleButton.Text = 'Disable Ethernet'
    }
    else {
        $StatusLabel.Text = 'Ethernet is OFF'
        $StatusLabel.ForeColor = [System.Drawing.Color]::FromArgb(160, 160, 160)
        $ToggleButton.Text = 'Enable Ethernet'
    }

    if ($null -ne $script:heldBitmap) {
        $script:heldBitmap.Dispose()
    }

    $script:heldBitmap = $newBitmap
}

function Invoke-UiEthernetAction {
    param(
        [ValidateSet('Toggle', 'Enable', 'Disable')]
        [string]$Action,
        [System.Windows.Forms.NotifyIcon]$NotifyIcon,
        [System.Windows.Forms.Label]$StatusLabel,
        [System.Windows.Forms.Button]$ToggleButton
    )

    Invoke-EthernetToggleAction -TaskName $config.taskName -ActionFile $paths.ActionFile -Action $Action
    Start-Sleep -Milliseconds 750
    Update-ApplicationState -NotifyIcon $NotifyIcon -StatusLabel $StatusLabel -ToggleButton $ToggleButton
}

$form = New-Object System.Windows.Forms.Form
$form.Text = $config.appName
$form.Size = New-Object System.Drawing.Size 340, 220
$form.MinimumSize = New-Object System.Drawing.Size 340, 220
$form.MaximumSize = New-Object System.Drawing.Size 340, 220
$form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedSingle
$form.MaximizeBox = $false
$form.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
$form.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 30)
$form.ForeColor = [System.Drawing.Color]::White

if (Test-Path -LiteralPath $paths.IconPath) {
    $form.Icon = New-Object System.Drawing.Icon($paths.IconPath)
}

$headerPanel = New-Object System.Windows.Forms.Panel
$headerPanel.Dock = [System.Windows.Forms.DockStyle]::Top
$headerPanel.Height = 72
$headerPanel.BackColor = [System.Drawing.Color]::FromArgb(24, 24, 24)

$logoPicture = New-Object System.Windows.Forms.PictureBox
$logoPicture.Size = New-Object System.Drawing.Size 48, 48
$logoPicture.Location = New-Object System.Drawing.Point 16, 12
$logoPicture.SizeMode = [System.Windows.Forms.PictureBoxSizeMode]::Zoom
if (Test-Path -LiteralPath $paths.LogoPath) {
    $logoPicture.Image = [System.Drawing.Image]::FromFile($paths.LogoPath)
}

$titleLabel = New-Object System.Windows.Forms.Label
$titleLabel.Text = $config.appName
$titleLabel.Font = New-Object System.Drawing.Font 'Segoe UI', 12, [System.Drawing.FontStyle]::Bold
$titleLabel.ForeColor = [System.Drawing.Color]::White
$titleLabel.AutoSize = $true
$titleLabel.Location = New-Object System.Drawing.Point 76, 16

$adapterLabel = New-Object System.Windows.Forms.Label
$adapterLabel.Text = "Adapter: $($config.adapterName)"
$adapterLabel.Font = New-Object System.Drawing.Font 'Segoe UI', 9
$adapterLabel.ForeColor = [System.Drawing.Color]::FromArgb(170, 170, 170)
$adapterLabel.AutoSize = $true
$adapterLabel.Location = New-Object System.Drawing.Point 78, 42

$statusLabel = New-Object System.Windows.Forms.Label
$statusLabel.Font = New-Object System.Drawing.Font 'Segoe UI', 11, [System.Drawing.FontStyle]::Bold
$statusLabel.AutoSize = $true
$statusLabel.Location = New-Object System.Drawing.Point 20, 88

$toggleButton = New-Object System.Windows.Forms.Button
$toggleButton.Size = New-Object System.Drawing.Size 292, 36
$toggleButton.Location = New-Object System.Drawing.Point 20, 118
$toggleButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$toggleButton.BackColor = [System.Drawing.Color]::FromArgb(70, 130, 220)
$toggleButton.ForeColor = [System.Drawing.Color]::White
$toggleButton.Font = New-Object System.Drawing.Font 'Segoe UI', 10, [System.Drawing.FontStyle]::Bold
$toggleButton.Cursor = [System.Windows.Forms.Cursors]::Hand
$toggleButton.FlatAppearance.BorderSize = 0

$buttonPanel = New-Object System.Windows.Forms.Panel
$buttonPanel.Location = New-Object System.Drawing.Point 20, 162
$buttonPanel.Size = New-Object System.Drawing.Size 292, 32

$enableButton = New-Object System.Windows.Forms.Button
$enableButton.Text = 'Enable'
$enableButton.Size = New-Object System.Drawing.Size 140, 32
$enableButton.Location = New-Object System.Drawing.Point 0, 0
$enableButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$enableButton.BackColor = [System.Drawing.Color]::FromArgb(45, 45, 45)
$enableButton.ForeColor = [System.Drawing.Color]::White
$enableButton.Font = New-Object System.Drawing.Font 'Segoe UI', 9
$enableButton.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(70, 70, 70)

$disableButton = New-Object System.Windows.Forms.Button
$disableButton.Text = 'Disable'
$disableButton.Size = New-Object System.Drawing.Size 140, 32
$disableButton.Location = New-Object System.Drawing.Point 152, 0
$disableButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$disableButton.BackColor = [System.Drawing.Color]::FromArgb(45, 45, 45)
$disableButton.ForeColor = [System.Drawing.Color]::White
$disableButton.Font = New-Object System.Drawing.Font 'Segoe UI', 9
$disableButton.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(70, 70, 70)

$notifyIcon = New-Object System.Windows.Forms.NotifyIcon
$contextMenu = New-Object System.Windows.Forms.ContextMenuStrip

$showItem = New-Object System.Windows.Forms.ToolStripMenuItem 'Show Window'
$enableItem = New-Object System.Windows.Forms.ToolStripMenuItem 'Enable Ethernet'
$disableItem = New-Object System.Windows.Forms.ToolStripMenuItem 'Disable Ethernet'
$exitItem = New-Object System.Windows.Forms.ToolStripMenuItem 'Exit'

[void]$contextMenu.Items.Add($showItem)
[void]$contextMenu.Items.Add($enableItem)
[void]$contextMenu.Items.Add($disableItem)
[void]$contextMenu.Items.Add($exitItem)

$notifyIcon.ContextMenuStrip = $contextMenu
$notifyIcon.Visible = $true

$showItem.Add_Click({
    $form.Show()
    $form.WindowState = [System.Windows.Forms.FormWindowState]::Normal
    $form.Activate()
})
$enableItem.Add_Click({
    Invoke-UiEthernetAction -Action 'Enable' -NotifyIcon $notifyIcon -StatusLabel $statusLabel -ToggleButton $toggleButton
})
$disableItem.Add_Click({
    Invoke-UiEthernetAction -Action 'Disable' -NotifyIcon $notifyIcon -StatusLabel $statusLabel -ToggleButton $toggleButton
})
$exitItem.Add_Click({
    $script:isClosing = $true
    $form.Close()
})

$toggleButton.Add_Click({
    Invoke-UiEthernetAction -Action 'Toggle' -NotifyIcon $notifyIcon -StatusLabel $statusLabel -ToggleButton $toggleButton
})
$enableButton.Add_Click({
    Invoke-UiEthernetAction -Action 'Enable' -NotifyIcon $notifyIcon -StatusLabel $statusLabel -ToggleButton $toggleButton
})
$disableButton.Add_Click({
    Invoke-UiEthernetAction -Action 'Disable' -NotifyIcon $notifyIcon -StatusLabel $statusLabel -ToggleButton $toggleButton
})

$notifyIcon.Add_MouseClick({
    param($sender, $eventArgs)

    if ($eventArgs.Button -eq [System.Windows.Forms.MouseButtons]::Left) {
        $form.Show()
        $form.WindowState = [System.Windows.Forms.FormWindowState]::Normal
        $form.Activate()
    }
})

$form.Add_FormClosing({
    param($sender, $eventArgs)

    if (-not $script:isClosing) {
        $eventArgs.Cancel = $true
        $form.Hide()
    }
})

[void]$headerPanel.Controls.Add($logoPicture)
[void]$headerPanel.Controls.Add($titleLabel)
[void]$headerPanel.Controls.Add($adapterLabel)
[void]$form.Controls.Add($headerPanel)
[void]$form.Controls.Add($statusLabel)
[void]$form.Controls.Add($toggleButton)
[void]$buttonPanel.Controls.Add($enableButton)
[void]$buttonPanel.Controls.Add($disableButton)
[void]$form.Controls.Add($buttonPanel)

Update-ApplicationState -NotifyIcon $notifyIcon -StatusLabel $statusLabel -ToggleButton $toggleButton

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 2000
$timer.Add_Tick({
    if (Test-EthernetToggleFocusSignal -SignalFile $paths.SignalFile) {
        $form.Show()
        $form.WindowState = [System.Windows.Forms.FormWindowState]::Normal
        $form.Activate()
    }

    Update-ApplicationState -NotifyIcon $notifyIcon -StatusLabel $statusLabel -ToggleButton $toggleButton
})
$timer.Start()

$form.Add_FormClosed({
    $timer.Stop()
    $timer.Dispose()
    $notifyIcon.Visible = $false
    if ($null -ne $notifyIcon.Icon) {
        $notifyIcon.Icon.Dispose()
    }
    if ($currentIconHandle -ne [IntPtr]::Zero) {
        [NativeMethods]::DestroyIcon($currentIconHandle) | Out-Null
    }
    if ($null -ne $heldBitmap) {
        $heldBitmap.Dispose()
    }
    if ($null -ne $logoPicture.Image) {
        $logoPicture.Image.Dispose()
    }
    $notifyIcon.Dispose()
})

[void][System.Windows.Forms.Application]::Run($form)
