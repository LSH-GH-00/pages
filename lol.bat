@echo off
setlocal

set "SCRIPT=%temp%\hydra_main.ps1"

powershell -NoProfile -Command ^
  "$a=Get-Content -LiteralPath '%~f0' -Encoding UTF8; $i=($a | Select-String '^#PS_CODE_START$').LineNumber; $a[($i)..($a.Count-1)] | Set-Content -LiteralPath '%SCRIPT%' -Encoding UTF8"

:: 숨김 모드로 백그라운드 관리자 가동 후 현재 창 종료
start "" powershell -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "%SCRIPT%" "%SCRIPT%"

exit /b

#PS_CODE_START
param($ScriptPath)

Add-Type @'
using System;
using System.Runtime.InteropServices;

public static class WinAPI
{
    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    public static extern IntPtr FindWindow(string lpClassName, string lpWindowName);

    [DllImport("user32.dll")]
    public static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, uint uFlags);

    [DllImport("user32.dll")]
    public static extern int GetSystemMetrics(int nIndex);
}
'@

# [A] lol 무빙 창 모드
if ($args[0] -eq "BOUNCE") {
    $myId = $args[1]
    $title = "lol_$myId"
    $host.UI.RawUI.WindowTitle = $title

    $hwnd = [IntPtr]::Zero
    for ($i = 0; $i -lt 30; $i++) {
        $hwnd = [WinAPI]::FindWindow("CASCADIA_HOSTING_WINDOW_CLASS", $title)
        if ($hwnd -eq [IntPtr]::Zero) { $hwnd = [WinAPI]::FindWindow([string]$null, $title) }
        if ($hwnd -ne [IntPtr]::Zero) { break }
        Start-Sleep -Milliseconds 100
    }
    if ($hwnd -eq [IntPtr]::Zero) { exit }

    $rand = New-Object Random
    $x = $rand.Next(50, 400)
    $y = $rand.Next(50, 300)

    # dx, dy를 -5 ~ 5 사이의 무작위 값으로 설정 (0 제외)
    do { $dx = $rand.Next(-5, 6) } while ($dx -eq 0)
    do { $dy = $rand.Next(-5, 6) } while ($dy -eq 0)

    $width = 400
    $height = 200

    while ($true) {
        $screenWidth = [WinAPI]::GetSystemMetrics(0)
        $screenHeight = [WinAPI]::GetSystemMetrics(1)

        $x += $dx
        $y += $dy

        if ($x -le 0) { $x = 0; $dx = -$dx }
        if ($y -le 0) { $y = 0; $dy = -$dy }
        if ($x + $width -ge $screenWidth) { $x = $screenWidth - $width; $dx = -$dx }
        if ($y + $height -ge $screenHeight) { $y = $screenHeight - $height; $dy = -$dy }

        [WinAPI]::SetWindowPos($hwnd, [IntPtr]::Zero, $x, $y, $width, $height, 4)
        Start-Sleep -Milliseconds 5
    }
    exit
}

# [B] 백그라운드 관리자 (PID 감시)
function Spawn-Lol {
    param($Script)
    $uid = (Get-Random -Minimum 10000 -Maximum 99999)
    $p = Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$Script`" `"$Script`" BOUNCE $uid" -PassThru
    return $p
}

$procList = New-Object System.Collections.Generic.List[System.Diagnostics.Process]

# 첫 번째 lol 창 소환
$procList.Add((Spawn-Lol -Script $ScriptPath))

while ($true) {
    Start-Sleep -Milliseconds 200

    $aliveList = New-Object System.Collections.Generic.List[System.Diagnostics.Process]
    $closedCount = 0

    foreach ($p in $procList) {
        if ($p -ne $null -and -not $p.HasExited) {
            $aliveList.Add($p)
        } else {
            $closedCount++
        }
    }

    # 창을 닫아 종료 감지 시 2개 스폰
    if ($closedCount -gt 0) {
        for ($k = 0; $k -lt ($closedCount * 2); $k++) {
            $aliveList.Add((Spawn-Lol -Script $ScriptPath))
        }
    }

    $procList = $aliveList

    # 4개 이상 도달 시 관리자 프로세스 및 스크립트 파일 정리 후 사망
    if ($procList.Count -ge 8) {
        Remove-Item -Path $ScriptPath -Force -ErrorAction SilentlyContinue
        exit
    }
}
