# Writes a big-endian u32 into the running game's guest memory.
# usage: poke.ps1 -HostAddr 0x182BB4574 -Value 1
param([UInt64]$HostAddr, [UInt32]$Value)
Add-Type @'
using System; using System.Runtime.InteropServices;
public static class Poke {
  [DllImport("kernel32.dll")] public static extern IntPtr OpenProcess(int a, bool i, int pid);
  [DllImport("kernel32.dll")] public static extern bool WriteProcessMemory(IntPtr h, IntPtr addr, byte[] buf, int size, out int written);
}
'@
$p = Get-Process skylanders_sa
$h = [Poke]::OpenProcess(0x0028, $false, $p.Id)  # VM_OPERATION | VM_WRITE
$b = [BitConverter]::GetBytes($Value); [Array]::Reverse($b)
$n = 0
$ok = [Poke]::WriteProcessMemory($h, [IntPtr][Int64]$HostAddr, $b, 4, [ref]$n)
"{0:X}: wrote {1:X8} ok={2}" -f $HostAddr, $Value, $ok
