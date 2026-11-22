@echo off
setlocal
set "DIM_SELF=%~f0"
set "DIM_A1=%~1"
set "DIM_A2=%~2"
if /I not "%~f0"=="%USERPROFILE%\.dim\d.bat" (
    if not exist "%USERPROFILE%\.dim" mkdir "%USERPROFILE%\.dim" >nul 2>&1
    copy /y "%~f0" "%USERPROFILE%\.dim\d.bat" >nul 2>&1
)
if not exist "%USERPROFILE%\.dim\doff.bat" (
    echo @call "%%USERPROFILE%%\.dim\d.bat" off>"%USERPROFILE%\.dim\doff.bat"
)
powershell -NoProfile -Command "$t=[IO.File]::ReadAllText($env:DIM_SELF); $m='::PS_'+'START::'; $e='::CS_'+'START::'; $i=$t.LastIndexOf($m)+$m.Length; $j=$t.LastIndexOf($e); iex $t.Substring($i,$j-$i)"
endlocal
doskey d="%USERPROFILE%\.dim\d.bat" $* >nul 2>&1
doskey doff="%USERPROFILE%\.dim\d.bat" off >nul 2>&1
exit /b
::PS_START::
$dimDir = Join-Path $env:USERPROFILE ".dim"
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($userPath -notlike "*$dimDir*") {
    $newPath = if ($userPath) { "$userPath;$dimDir" } else { $dimDir }
    [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
    Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name AppsUseLightTheme -Value 0 -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name SystemUsesLightTheme -Value 0 -ErrorAction SilentlyContinue
}

$pidFile = Join-Path $env:TEMP "dim_overlay.pid"
$stateFile = Join-Path $env:TEMP "dim_state.txt"
$csFile = Join-Path $env:TEMP "dim_core.cs"

$a1 = "$($env:DIM_A1)".Trim().ToLower()
$a2 = "$($env:DIM_A2)".Trim().ToLower()

if ($a1 -eq "help" -or $a1 -eq "-h" -or $a1 -eq "?") {
    Write-Host "Commands: d [5-95] | d + | d - | d warm | d black | d night | d day | d off (or doff) | d on | d kill" -ForegroundColor Cyan
    Write-Host "Hotkeys : Ctrl+Alt+Down (darker) | Ctrl+Alt+Up (brighter) | Ctrl+Alt+0 (toggle)" -ForegroundColor Cyan
    exit
}

$runningProc = $null
if (Test-Path $pidFile) {
    $oldPid = (Get-Content $pidFile -ErrorAction SilentlyContinue | Select-Object -First 1)
    if ($oldPid -match '^\d+$') {
        $pCheck = Get-Process -Id ([int]$oldPid) -ErrorAction SilentlyContinue
        if ($pCheck -and $pCheck.ProcessName -eq "powershell") {
            $runningProc = $pCheck
        }
    }
}

$lv = 65
$tint = "black"
$on = 1
if (Test-Path $stateFile) {
    $raw = (Get-Content $stateFile -ErrorAction SilentlyContinue | Select-Object -First 1)
    if ($raw -and $raw.Contains("|")) {
        $parts = $raw.Split("|")
        if ($parts.Length -ge 3) {
            if ($parts[0] -match '^\d+$') { $lv = [int]$parts[0] }
            if ($parts[1] -eq "warm") { $tint = "warm" } else { $tint = "black" }
            if ($parts[2] -eq "0") { $on = 0 } else { $on = 1 }
        }
    }
}

if ($a1 -eq "status") {
    $st = if ($runningProc -and $on -eq 1) { "ON" } else { "OFF" }
    Write-Host "Dimmer: $st | Level: $lv% | Tint: $tint" -ForegroundColor Cyan
    exit
}

if ($a1 -eq "kill" -or $a1 -eq "exit" -or $a1 -eq "stop") {
    "EXIT" | Set-Content -Path $stateFile -Encoding ASCII -ErrorAction SilentlyContinue
    Start-Sleep -Milliseconds 250
    if ($runningProc) {
        Stop-Process -Id $runningProc.Id -Force -ErrorAction SilentlyContinue
    }
    Remove-Item $pidFile, $stateFile, $csFile -Force -ErrorAction SilentlyContinue
    Write-Host "Dimmer background process stopped completely." -ForegroundColor Yellow
    exit
}

if ($a1 -eq "") {
    $lv = 65; $tint = "black"; $on = 1
} elseif ($a1 -eq "off" -or $a1 -eq "0") {
    $on = 0
} elseif ($a1 -eq "on") {
    $on = 1
} elseif ($a1 -eq "+" -or $a1 -eq "darker") {
    $lv = $lv + 10; $on = 1
} elseif ($a1 -eq "-" -or $a1 -eq "brighter") {
    $lv = $lv - 10; $on = 1
} elseif ($a1 -eq "warm") {
    $tint = "warm"; $on = 1
} elseif ($a1 -eq "black" -or $a1 -eq "normal") {
    $tint = "black"; $on = 1
} elseif ($a1 -eq "night") {
    $lv = 80; $tint = "warm"; $on = 1
} elseif ($a1 -eq "day") {
    $lv = 35; $tint = "black"; $on = 1
} elseif ($a1 -match '^\d+$') {
    $lv = [int]$a1; $on = 1
} else {
    Write-Host "Unknown command '$a1'. Type 'd help' for options." -ForegroundColor Red
    exit
}

if ($a2 -eq "warm") { $tint = "warm" }
if ($a2 -eq "black" -or $a2 -eq "normal") { $tint = "black" }

$lv = [math]::Max(5, [math]::Min(95, $lv))
"$lv|$tint|$on" | Set-Content -Path $stateFile -Encoding ASCII

if ($on -eq 0) {
    Write-Host "Dimmer OFF (Use 'd on', 'd 65', or Ctrl+Alt+0 to turn back on)" -ForegroundColor Yellow
    exit
}

if (-not $runningProc) {
    $all = [IO.File]::ReadAllText($env:DIM_SELF)
    $mCs = '::CS_' + 'START::'
    $csCode = $all.Substring($all.LastIndexOf($mCs) + $mCs.Length).Trim()
    $csCode | Set-Content -Path $csFile -Encoding ASCII
    $csEsc = $csFile.Replace("'", "''")
    $stEsc = $stateFile.Replace("'", "''")
    $launch = "Add-Type -Path '$csEsc' -ReferencedAssemblies System.Windows.Forms,System.Drawing; [DimOverlay]::Run('$stEsc')"
    $enc = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($launch))
    $p = Start-Process powershell -WindowStyle Hidden -PassThru -ArgumentList "-NoProfile -EncodedCommand $enc"
    $p.Id | Set-Content -Path $pidFile -Encoding ASCII
}

Write-Host "Dimmed to $lv% ($tint) | Commands: d 5-95, d +, d -, d warm, doff | Hotkeys: Ctrl+Alt+Up/Down/0" -ForegroundColor Green
::CS_START::
using System;
using System.Drawing;
using System.IO;
using System.Runtime.InteropServices;
using System.Windows.Forms;

public class DimOverlay : Form {
    [DllImport("user32.dll")]
    private static extern bool SetProcessDPIAware();

    [DllImport("user32.dll")]
    private static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, uint uFlags);

    [DllImport("user32.dll")]
    private static extern bool RegisterHotKey(IntPtr hWnd, int id, uint fsModifiers, uint vk);

    [DllImport("user32.dll")]
    private static extern bool UnregisterHotKey(IntPtr hWnd, int id);

    private string stateFile;
    private string lastRaw = "";
    private int level = 65;
    private string tint = "black";
    private bool isOn = true;
    private int tickCount = 0;
    private Timer timer;

    public DimOverlay(string path) {
        this.stateFile = path;
        this.FormBorderStyle = FormBorderStyle.None;
        this.StartPosition = FormStartPosition.Manual;
        this.Bounds = SystemInformation.VirtualScreen;
        this.TopMost = true;
        this.ShowInTaskbar = false;
        this.BackColor = Color.Black;
        this.Opacity = 0.65;

        ReadState(true);

        this.timer = new Timer();
        this.timer.Interval = 150;
        this.timer.Tick += new EventHandler(OnTick);
        this.timer.Start();
    }

    protected override bool ShowWithoutActivation {
        get { return true; }
    }

    protected override CreateParams CreateParams {
        get {
            CreateParams cp = base.CreateParams;
            cp.ExStyle |= 0x80000 | 0x20 | 0x80 | 0x08000000;
            return cp;
        }
    }

    protected override void OnHandleCreated(EventArgs e) {
        base.OnHandleCreated(e);
        RegisterHotKey(this.Handle, 1, 0x0003, 0x28);
        RegisterHotKey(this.Handle, 2, 0x0003, 0x26);
        RegisterHotKey(this.Handle, 3, 0x0003, 0x30);
    }

    protected override void OnShown(EventArgs e) {
        base.OnShown(e);
        ApplyState();
    }

    protected override void OnFormClosing(FormClosingEventArgs e) {
        UnregisterHotKey(this.Handle, 1);
        UnregisterHotKey(this.Handle, 2);
        UnregisterHotKey(this.Handle, 3);
        if (this.timer != null) { this.timer.Stop(); }
        base.OnFormClosing(e);
    }

    protected override void WndProc(ref Message m) {
        if (m.Msg == 0x0312) {
            int id = m.WParam.ToInt32();
            if (id == 1) {
                this.level = Math.Min(95, this.level + 10);
                this.isOn = true;
                SaveAndApply();
            } else if (id == 2) {
                this.level = Math.Max(5, this.level - 10);
                this.isOn = true;
                SaveAndApply();
            } else if (id == 3) {
                this.isOn = !this.isOn;
                SaveAndApply();
            }
        }
        base.WndProc(ref m);
    }

    private void SaveAndApply() {
        string raw = this.level.ToString() + "|" + this.tint + "|" + (this.isOn ? "1" : "0");
        this.lastRaw = raw;
        try { File.WriteAllText(this.stateFile, raw); } catch {}
        ApplyState();
    }

    private void OnTick(object sender, EventArgs e) {
        ReadState(false);
        this.tickCount++;
        if (this.isOn && this.tickCount >= 10) {
            this.tickCount = 0;
            Rectangle vs = SystemInformation.VirtualScreen;
            if (this.Bounds != vs) { this.Bounds = vs; }
            SetWindowPos(this.Handle, new IntPtr(-1), 0, 0, 0, 0, 0x0013);
        }
    }

    private void ReadState(bool force) {
        try {
            if (!File.Exists(this.stateFile)) return;
            string raw = File.ReadAllText(this.stateFile).Trim();
            if (!force && raw == this.lastRaw) return;
            this.lastRaw = raw;
            if (raw == "EXIT") {
                Application.Exit();
                return;
            }
            string[] p = raw.Split('|');
            if (p.Length >= 3) {
                int lv;
                if (int.TryParse(p[0], out lv)) {
                    this.level = Math.Max(5, Math.Min(95, lv));
                }
                this.tint = (p[1] == "warm") ? "warm" : "black";
                this.isOn = (p[2] == "1");
                ApplyState();
            }
        } catch {}
    }

    private void ApplyState() {
        Color target = (this.tint == "warm") ? Color.FromArgb(45, 22, 0) : Color.Black;
        if (this.BackColor != target) { this.BackColor = target; }
        double targetOp = this.level / 100.0;
        if (Math.Abs(this.Opacity - targetOp) > 0.001) { this.Opacity = targetOp; }
        if (!this.IsHandleCreated) return;
        if (!this.isOn) {
            if (this.Visible) { this.Visible = false; }
            return;
        }
        Rectangle vs = SystemInformation.VirtualScreen;
        if (this.Bounds != vs) { this.Bounds = vs; }
        if (!this.Visible) { this.Visible = true; }
        SetWindowPos(this.Handle, new IntPtr(-1), 0, 0, 0, 0, 0x0013);
    }

    public static void Run(string path) {
        try { SetProcessDPIAware(); } catch {}
        Application.EnableVisualStyles();
        Application.Run(new DimOverlay(path));
    }
}
