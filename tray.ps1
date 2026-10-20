param(
    [Parameter(Mandatory = $true)][string]$IpcDirectory,
    [Parameter(Mandatory = $true)][int]$OwnerProcessId,
    [Parameter(Mandatory = $true)][string]$IconPath
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$ownerProcess = [System.Diagnostics.Process]::GetProcessById($OwnerProcessId)
$icon = [System.Drawing.Icon]::ExtractAssociatedIcon($IconPath)
$menu = New-Object System.Windows.Forms.ContextMenuStrip
$showItem = $menu.Items.Add('显示 Zotero')
[void]$menu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator))
$quitItem = $menu.Items.Add('退出 Zotero')
$tray = New-Object System.Windows.Forms.NotifyIcon
$tray.Icon = $icon
$tray.Text = 'Zotero — 点击关闭后缩小到托盘'
$tray.ContextMenuStrip = $menu
$encoding = New-Object System.Text.UTF8Encoding($false)

$showItem.add_Click({
    [System.IO.File]::WriteAllText((Join-Path $IpcDirectory 'restore'), '', $encoding)
})
$quitItem.add_Click({
    [System.IO.File]::WriteAllText((Join-Path $IpcDirectory 'quit'), '', $encoding)
})
$tray.add_MouseClick({
    param($sender, $eventArgs)
    if ($eventArgs.Button -eq [System.Windows.Forms.MouseButtons]::Left) {
        [System.IO.File]::WriteAllText((Join-Path $IpcDirectory 'restore'), '', $encoding)
    }
})

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 250
$timer.add_Tick({
    if ($ownerProcess.HasExited -or [System.IO.File]::Exists((Join-Path $IpcDirectory 'stop'))) {
        [System.Windows.Forms.Application]::Exit()
    }
})

try {
    $tray.Visible = $true
    [System.IO.File]::WriteAllText((Join-Path $IpcDirectory 'ready'), '', $encoding)
    $timer.Start()
    [System.Windows.Forms.Application]::Run()
}
finally {
    $timer.Stop()
    $timer.Dispose()
    $tray.Visible = $false
    $tray.Dispose()
    $menu.Dispose()
    $icon.Dispose()
    $ownerProcess.Dispose()
    Remove-Item -LiteralPath $IpcDirectory -Recurse -Force
}
