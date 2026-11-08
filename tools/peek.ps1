# Reads bytes from the running game's guest memory.
# usage: peek.ps1 -Phys 0x1C659000 [-Count 64]   (physical address; host = physical base + addr)
#        peek.ps1 -Host 0x11C659000              (raw host address)
param([UInt64]$Phys = 0, [UInt64]$HostAddr = 0, [int]$Count = 64, [UInt64]$PhysBase = 0x200000000)
Add-Type @'
using System; using System.Runtime.InteropServices;
public static class Peek {
  [DllImport("kernel32.dll")] public static extern IntPtr OpenProcess(int a, bool i, int pid);
  [DllImport("kernel32.dll")] public static extern bool ReadProcessMemory(IntPtr h, IntPtr addr, byte[] buf, int size, out int read);
}
'@
$p = Get-Process skylanders_sa
$h = [Peek]::OpenProcess(0x0410, $false, $p.Id)
$addr = if ($HostAddr) { $HostAddr } else { $PhysBase + $Phys }
$buf = New-Object byte[] $Count
$n = 0
$ok = [Peek]::ReadProcessMemory($h, [IntPtr][Int64]$addr, $buf, $Count, [ref]$n)
if (-not $ok) { "{0:X}: read failed" -f $addr; return }
for ($i = 0; $i -lt $n; $i += 32) {
    "{0:X}: {1}" -f ($addr + $i), (($buf[$i..([Math]::Min($i + 31, $n - 1))] | % { $_.ToString('X2') }) -join ' ')
}
