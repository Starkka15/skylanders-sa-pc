# Finds every big-endian u32 equal to -Value in physical guest memory and prints the dwords around it,
# grouped by the dword pattern before it (tells command-buffer copies from CPU-side objects).
# usage: ctxscan.ps1 -Value 1C659086 [-Before 8] [-After 4] [-Max 5000]
param([string]$Value, [int]$Before = 8, [int]$After = 4, [int]$Max = 5000, [UInt64]$PhysBase = 0x200000000)
$v = [Convert]::ToUInt32(($Value -replace '^0x', ''), 16)
Add-Type @'
using System; using System.Collections.Generic; using System.Runtime.InteropServices; using System.Text;
public static class Ctx {
  [DllImport("kernel32.dll")] static extern IntPtr OpenProcess(int a, bool i, int pid);
  [DllImport("kernel32.dll")] static extern bool ReadProcessMemory(IntPtr h, IntPtr addr, byte[] buf, int size, out int read);
  static uint U(byte[] b, int i) { return ((uint)b[i] << 24) | ((uint)b[i+1] << 16) | ((uint)b[i+2] << 8) | b[i+3]; }
  public static List<string> Run(int pid, long physBase, uint val, int before, int after, int max) {
    var o = new List<string>();
    IntPtr h = OpenProcess(0x0410, false, pid);
    const int chunk = 1 << 20; int pad = 256;
    byte[] buf = new byte[chunk + pad * 2];
    for (long off = 0; off < 0x20000000L && o.Count < max; off += chunk) {
      int read; long start = Math.Max(0, off - pad);
      if (!ReadProcessMemory(h, new IntPtr(physBase + start), buf, buf.Length, out read)) {
        if (!ReadProcessMemory(h, new IntPtr(physBase + off), buf, chunk, out read)) continue; start = off; }
      int lo = (int)(off - start);
      for (int i = lo; i < lo + chunk && i + 4 <= read; i += 4) {
        if (U(buf, i) != val) continue;
        var sb = new StringBuilder(String.Format("{0:X8}:", start + i));
        for (int k = -before; k <= after; k++) { int j = i + k * 4; sb.Append(j >= 0 && j + 4 <= read ? String.Format(" {0:X8}", U(buf, j)) : " ????????"); if (k == 0) sb.Append(" |"); }
        o.Add(sb.ToString());
        if (o.Count >= max) break;
      }
    }
    return o;
  }
}
'@
$p = Get-Process skylanders_sa
[Ctx]::Run($p.Id, $PhysBase, $v, $Before, $After, $Max)
