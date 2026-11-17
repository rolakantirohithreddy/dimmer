Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name AppsUseLightTheme -Value 0 -ErrorAction SilentlyContinue
Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name SystemUsesLightTheme -Value 0 -ErrorAction SilentlyContinue

function global:d($lv = 65) {
    if ($global:dimPid) {
        Stop-Process -Id $global:dimPid -Force -ErrorAction SilentlyContinue
        $global:dimPid = $null
    }
    if ($lv -eq "off" -or [int]$lv -le 0) {
        Write-Host "Screen dimmer turned OFF." -ForegroundColor Yellow
        return
    }
    $n = [math]::Max(5, [math]::Min(95, [int]$lv))
    $s = "using System;using System.Runtime.InteropServices;public class W{[DllImport(`"user32.dll`")]public static extern int GetWindowLong(IntPtr h,int i);[DllImport(`"user32.dll`")]public static extern int SetWindowLong(IntPtr h,int i,int v);}"
    $cmd = "Add-Type '$s';Add-Type -AssemblyName System.Windows.Forms,System.Drawing;`$f=New-Object Windows.Forms.Form;`$f.BackColor='Black';`$f.FormBorderStyle='None';`$f.WindowState='Maximized';`$f.TopMost=`$true;`$f.ShowInTaskbar=`$false;`$f.Opacity=$n/100;`$f.Add_Load({[W]::SetWindowLong(`$f.Handle,-20,([W]::GetWindowLong(`$f.Handle,-20) -bor 0x80000 -bor 0x20))});[Windows.Forms.Application]::Run(`$f)"
    $enc = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($cmd))
    $p = Start-Process powershell -WindowStyle Hidden -PassThru -ArgumentList "-NoProfile -EncodedCommand $enc"
    $global:dimPid = $p.Id
    Write-Host "Screen dimmed to $n% (Adjust: d 5 to d 95 | Turn off: d off)" -ForegroundColor Green
}
d 65
