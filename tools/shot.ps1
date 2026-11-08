# Runs the game, saves a picture of its window at each given second, then stops only that process.
# usage: powershell -Command "& H:\skylanders-sa\tools\shot.ps1 -Name x -At 10,25"
param([string]$Name = 'shot', [double[]]$At = @(15, 30, 45), [string]$Config = 'win-amd64-relwithdebinfo', [string[]]$Extra = @(), [string[]]$Keys = @())
# -Keys '40:13','45:13' holds virtual key codes (13 = Return = Start) for 250 ms at those seconds (needs --mnk_mode true in -Extra).
# 'sec:vk:ms' holds for ms instead (87 = W walks forward). Holding blocks the loop, so keep shots outside holds.

Add-Type -AssemblyName System.Drawing
Add-Type @'
using System;
using System.Runtime.InteropServices;
public struct Rect { public int L, T, R, B; }
public static class Win {
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out Rect r);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
    [DllImport("user32.dll")] public static extern void keybd_event(byte vk, byte scan, uint flags, UIntPtr extra);
}
'@

$dir = "H:\skylanders-sa\out\build\$Config"
$logs = 'H:\skylanders-sa\logs'
New-Item -ItemType Directory -Force $logs | Out-Null
Remove-Item "$logs\$Name.log" -ErrorAction SilentlyContinue
$args = @('--game_data_root', 'H:\skylanders-sa\game\files', '--log_file', "$logs\$Name.log", '--log_flush_interval', '1') + $Extra
$p = Start-Process -FilePath "$dir\skylanders_sa.exe" -ArgumentList $args -WorkingDirectory $dir `
    -RedirectStandardOutput "$logs\$Name.out.log" -RedirectStandardError "$logs\$Name.err.log" -PassThru
$start = Get-Date
$keyq = [System.Collections.Generic.List[object]]::new(); foreach ($k in $Keys) { $parts = $k.Split(':'); $hold = 250; if ($parts.Count -gt 2) { $hold = [int]$parts[2] }; $keyq.Add(@([double]$parts[0], $parts[1], $hold)) }
foreach ($s in $At) {
    while (((Get-Date) - $start).TotalSeconds -lt $s) {
        if ($p.HasExited) { "exited with code $($p.ExitCode) before $s s"; return }
        $el = ((Get-Date) - $start).TotalSeconds
        while ($keyq.Count -gt 0 -and $keyq[0][0] -le $el) { $p.Refresh(); [void][Win]::SetForegroundWindow($p.MainWindowHandle); Start-Sleep -Milliseconds 150; $vk=[byte][int]$keyq[0][1]; [Win]::keybd_event($vk,0,0,[UIntPtr]::Zero); Start-Sleep -Milliseconds $keyq[0][2]; [Win]::keybd_event($vk,0,2,[UIntPtr]::Zero); $keyq.RemoveAt(0) }
        Start-Sleep -Milliseconds 200
    }
    $p.Refresh()
    $r = New-Object Rect
    [void][Win]::GetWindowRect($p.MainWindowHandle, [ref]$r)
    $w = $r.R - $r.L; $h = $r.B - $r.T
    if ($w -le 0 -or $h -le 0) { "no window at $s s"; continue }
    $b = New-Object System.Drawing.Bitmap $w, $h
    $g = [System.Drawing.Graphics]::FromImage($b)
    $g.CopyFromScreen($r.L, $r.T, 0, 0, $b.Size)
    $b.Save(("{0}\{1}-{2:000.0}.png" -f $logs,$Name,$s))
    
}
Stop-Process -Id $p.Id -Force -Confirm:$false

