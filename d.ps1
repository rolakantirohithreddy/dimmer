# 1. Switch Windows & Apps to Dark Mode (User-level, no Admin needed)
Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name AppsUseLightTheme -Value 0 -ErrorAction SilentlyContinue
Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name SystemUsesLightTheme -Value 0 -ErrorAction SilentlyContinue

# 2. In-Memory Click-Through Screen Dimmer (Zero .exe files)
$script:dimProc = $null
function Set-Dim($level) {
    if ($script:dimProc) {
        Stop-Process -Id $script:dimProc.Id -Force -ErrorAction SilentlyContinue
        $script:dimProc = $null
    }
    if ($level -eq "off" -or [int]$level -le 0) { return }
    $op = [math]::Max(10, [math]::Min(90, [int]$level)) / 100.0
    $cmd = "`$c='using System;using System.Runtime.InteropServices;public class W{[DllImport(~user32.dll~)]public static extern int GetWindowLong(IntPtr h,int i);[DllImport(~user32.dll~)]public static extern int SetWindowLong(IntPtr h,int i,int v);}'.Replace('~',[char]34);Add-Type `$c;Add-Type -AssemblyName System.Windows.Forms,System.Drawing;`$f=New-Object Windows.Forms.Form;`$f.BackColor='Black';`$f.FormBorderStyle='None';`$f.WindowState='Maximized';`$f.TopMost=`$true;`$f.ShowInTaskbar=`$false;`$f.Opacity=$op;`$f.Add_Load({[W]::SetWindowLong(`$f.Handle,-20,([W]::GetWindowLong(`$f.Handle,-20) -bor 0x80000 -bor 0x20))});[Windows.Forms.Application]::Run(`$f)"
    $script:dimProc = Start-Process powershell -WindowStyle Hidden -PassThru -ArgumentList "-NoProfile -Command `"$cmd`""
}

Set-Dim 65
Clear-Host
Write-Host "=== Screen Dimmed (65%) & AI Ready ===" -ForegroundColor Green
Write-Host "Controls: Type 10-90 to change darkness | Type 'off' to remove dimmer | Type 'exit' to quit" -ForegroundColor Yellow

# 3. Interactive AI Chat in Terminal
while ($true) {
    Write-Host -NoNewline "`nYou: " -ForegroundColor Cyan
    $q = Read-Host
    if ($q -eq "exit") { break }
    if ($q -eq "off" -or $q -match '^\d{1,2}$') {
        Set-Dim $q
        Write-Host "Screen darkness updated to: $q" -ForegroundColor Yellow
        continue
    }
    if ($q) {
        Write-Host "`nBot:" -ForegroundColor Green
        $ans = Invoke-RestMethod ("https://text.pollinations.ai/" + [uri]::EscapeDataString($q))
        Write-Host $ans
    }
}
