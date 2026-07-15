# ============================================================
# start-private-access.ps1
# MANDATE-01: Expose internal ops ports qua Tailscale VPN
#
# Cổng vận hành chỉ truy cập được khi kết nối Tailscale:
#   - Grafana   : http://[ts-ip]:3000
#   - Jaeger    : http://[ts-ip]:16686
#   - ArgoCD    : http://[ts-ip]:8081
#   - flagd     : http://[ts-ip]:8013
#
# Chạy script này SAU KHI đã kết nối Tailscale.
# ============================================================

param(
    [switch]$Stop   # Dùng -Stop để dừng tất cả port-forward
)

# ── Dừng tất cả nếu có flag -Stop ──────────────────────────
if ($Stop) {
    Write-Host "Stopping all private access port-forwards..." -ForegroundColor Yellow
    Get-Process kubectl -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -match "port-forward" } | Stop-Process -Force -ErrorAction SilentlyContinue
    Write-Host "Done." -ForegroundColor Green
    exit 0
}

# ── Kiểm tra Tailscale đang chạy ───────────────────────────
Write-Host "Checking Tailscale status..." -ForegroundColor Cyan

$tsPath = "C:\Program Files\Tailscale\tailscale.exe"
if (-not (Test-Path $tsPath)) {
    $tsPath = "$env:LOCALAPPDATA\Tailscale\tailscale.exe"
}

if (Test-Path $tsPath) {
    $tsStatus = & $tsPath status --json 2>$null | ConvertFrom-Json
} else {
    $tsStatus = $null
}
if (-not $tsStatus) {
    Write-Error "Tailscale is not running or not installed. Please install and login first."
    Write-Host "Download: https://tailscale.com/download/windows" -ForegroundColor Yellow
    exit 1
}

# Lấy Tailscale IP của máy này
$tsIP = $tsStatus.Self.TailscaleIPs | Where-Object { $_ -match "^\d+\.\d+\.\d+\.\d+$" } | Select-Object -First 1
if (-not $tsIP) {
    Write-Error "Could not get Tailscale IP. Make sure you are logged in: & `"$tsPath`" login"
    exit 1
}

Write-Host "Tailscale IP: $tsIP" -ForegroundColor Green

# ── Dừng các process cũ nếu còn ────────────────────────────────
Get-Process kubectl -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -match "port-forward" } | Stop-Process -Force -ErrorAction SilentlyContinue

# ── Cấu hình các cổng vận hành ─────────────────────────────
$services = @(
    @{ Name = "grafana";      Namespace = "techx-tf3"; LocalPort = 3000;  RemotePort = 80    },
    @{ Name = "jaeger";       Namespace = "techx-tf3"; LocalPort = 16686; RemotePort = 16686 },
    @{ Name = "argocd-server";Namespace = "argocd";    LocalPort = 8081;  RemotePort = 80    },
    @{ Name = "flagd";        Namespace = "techx-tf3"; LocalPort = 8013;  RemotePort = 8013  }
)

# ── Khởi động port-forward bind vào Tailscale IP ───────────
Write-Host "`nStarting private access tunnels..." -ForegroundColor Cyan

$processes = @{}

foreach ($svc in $services) {
    $argsList = "port-forward svc/$($svc.Name) --address=0.0.0.0 $($svc.LocalPort):$($svc.RemotePort) -n $($svc.Namespace)"
    
    $proc = Start-Process -FilePath "kubectl" -ArgumentList $argsList -WindowStyle Minimized -PassThru
    $processes[$svc.Name] = @{ Process = $proc; Args = $argsList }
    
    Write-Host "  [OK] $($svc.Name.PadRight(15)) → http://${tsIP}:$($svc.LocalPort) (and localhost)" -ForegroundColor White
}

# ── In ra bảng URL để gửi cho mentor ───────────────────────
Write-Host ""
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Magenta
Write-Host "  PRIVATE ACCESS URLs (Tailscale VPN required)         " -ForegroundColor Magenta
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Magenta
Write-Host "  Grafana   : http://${tsIP}:3000"   -ForegroundColor Yellow
Write-Host "  Jaeger    : http://${tsIP}:16686"  -ForegroundColor Yellow
Write-Host "  ArgoCD    : http://${tsIP}:8081"   -ForegroundColor Yellow
Write-Host "  flagd     : http://${tsIP}:8013"   -ForegroundColor Yellow
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Magenta
Write-Host ""
Write-Host "  PUBLIC URL (internet):" -ForegroundColor Cyan
Write-Host "  Storefront: (check ngrok URL)" -ForegroundColor Cyan
Write-Host ""
Write-Host "Press Ctrl+C to stop all tunnels." -ForegroundColor Gray

# ── Giữ script chạy và tự động restart ─────────────────────
try {
    while ($true) {
        Start-Sleep -Seconds 5
        foreach ($svcName in $processes.Keys) {
            $pInfo = $processes[$svcName]
            if ($pInfo.Process.HasExited) {
                Write-Host "  [RESTART] $svcName tunnel died, restarting..." -ForegroundColor Red
                $pInfo.Process = Start-Process -FilePath "kubectl" -ArgumentList $pInfo.Args -WindowStyle Minimized -PassThru
            }
        }
    }
} finally {
    Write-Host "`nStopping all tunnels..." -ForegroundColor Yellow
    Get-Process kubectl -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -match "port-forward" } | Stop-Process -Force -ErrorAction SilentlyContinue
    Write-Host "Done." -ForegroundColor Green
}
