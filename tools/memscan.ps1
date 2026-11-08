# Scans the running game's 512 MB physical guest memory for big-endian 32-bit values.
# usage: memscan.ps1 -Values 0xFC658000,0x1C659000 [-Mask 0xFFFFF000] [-Max 40]
# Values and Mask are hex strings (PowerShell reads 0xFC658000 as a negative Int32).
param([string[]]$Values, [string]$Mask = 'FFFFFFFF', [int]$Max = 40, [UInt64]$PhysBase = 0x200000000,
      [string]$SkipFrom = '0', [string]$SkipTo = '0')
$skipA = [Convert]::ToInt64(($SkipFrom -replace '^0x', ''), 16)
$skipB = [Convert]::ToInt64(($SkipTo -replace '^0x', ''), 16)
$vals = [UInt32[]]($Values | % { $_ -split ',' } | ? { $_ } | % { [Convert]::ToUInt32(($_ -replace '^0x', ''), 16) })
$maskv = [Convert]::ToUInt32(($Mask -replace '^0x', ''), 16)
Add-Type @'
using System; using System.Collections.Generic; using System.Runtime.InteropServices;
public static class Scan {
  [DllImport("kernel32.dll")] static extern IntPtr OpenProcess(int a, bool i, int pid);
  [DllImport("kernel32.dll")] static extern bool ReadProcessMemory(IntPtr h, IntPtr addr, byte[] buf, int size, out int read);
  public static List<string> Run(int pid, long physBase, uint[] values, uint mask, int max, long skipA, long skipB) {
    var hits = new List<string>();
    IntPtr h = OpenProcess(0x0410, false, pid);
    const int chunk = 1 << 20;
    byte[] buf = new byte[chunk];
    for (long off = 0; off < 0x20000000L && hits.Count < max; off += chunk) {
      int read;
      if (off + chunk > skipA && off < skipB) continue;
      if (!ReadProcessMemory(h, new IntPtr(physBase + off), buf, chunk, out read) || read < 4) continue;
      for (int i = 0; i + 4 <= read; i += 4) {
        uint v = ((uint)buf[i] << 24) | ((uint)buf[i + 1] << 16) | ((uint)buf[i + 2] << 8) | buf[i + 3];
        foreach (uint t in values) {
          if ((v & mask) == (t & mask)) { hits.Add(String.Format("phys {0:X8}: {1:X8}", off + i, v)); break; }
        }
        if (hits.Count >= max) break;
      }
    }
    return hits;
  }
}
'@
$p = Get-Process skylanders_sa
[Scan]::Run($p.Id, $PhysBase, $vals, $maskv, $Max, $skipA, $skipB)
