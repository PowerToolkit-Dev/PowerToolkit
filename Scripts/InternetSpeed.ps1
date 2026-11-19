<#
.SYNOPSIS
    High-accuracy download speed test, true ICMP latency, and network details.
.CATEGORY
    Monitoring
#>

Clear-Host
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "                NETWORK & SPEED BENCHMARK                   " -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

# Ensure TLS 1.2 is enabled
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12

# 1. Network Interfaces & Gateway
$ipInfo = Get-NetIPAddress -AddressFamily IPv4 | 
    Where-Object { $_.InterfaceAlias -notlike "*Loopback*" -and $_.IPAddress -notlike "169.254*" } | 
    Select-Object -First 1

$localIP = if ($ipInfo) { $ipInfo.IPAddress } else { "Unknown" }
$gateway = (Get-NetRoute -DestinationPrefix "0.0.0.0/0" -ErrorAction SilentlyContinue | Select-Object -First 1).NextHop
$dns = (Get-DnsClientServerAddress -AddressFamily IPv4 -InterfaceIndex $ipInfo.InterfaceIndex -ErrorAction SilentlyContinue).ServerAddresses -join ", "

Write-Host "Local IP:        $localIP"
Write-Host "Default Gateway: $gateway"
Write-Host "DNS Servers:     $dns"
Write-Host ""

# 2. True Hardware ICMP Latency & Jitter (via .NET Ping)
Write-Host "Measuring latency & jitter (Cloudflare / Google)..." -ForegroundColor Yellow
$pinger = [System.Net.NetworkInformation.Ping]::new()
$pings = [System.Collections.Generic.List[long]]::new()

foreach ($target in @("1.1.1.1", "8.8.8.8")) {
    for ($i = 0; $i -lt 3; $i++) {
        try {
            $reply = $pinger.Send($target, 1000)
            if ($reply.Status -eq 'Success') {
                $pings.Add($reply.RoundtripTime)
            }
        } catch {}
    }
}

if ($pings.Count -gt 0) {
    $avgPing = [math]::Round(($pings | Measure-Object -Average).Average, 1)
    $minPing = ($pings | Measure-Object -Minimum).Minimum
    $maxPing = ($pings | Measure-Object -Maximum).Maximum
    $jitter  = [math]::Round($maxPing - $minPing, 1)
    Write-Host "Latency:         $avgPing ms (Min: ${minPing}ms, Max: ${maxPing}ms, Jitter: ${jitter}ms)" -ForegroundColor Green
} else {
    Write-Host "Latency:         N/A (ICMP ping blocked)" -ForegroundColor Red
}

Write-Host ""

# 3. High-Speed Benchmark Engine (.NET WebClient)
$wc = [System.Net.WebClient]::new()
$wc.Headers.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36")

try {
    # Step A: Warmup connection (5 MB) to bypass TCP slow-start
    Write-Host "Warming up connection (bypassing TCP slow-start)..." -ForegroundColor DarkGray
    $warmupUrl = "https://speed.cloudflare.com/__down?bytes=5000000"
    [void]$wc.DownloadData($warmupUrl)

    # Step B: Measured Full-Throttle Run (25 MB)
    Write-Host "Running full bandwidth test (25 MB payload)..." -ForegroundColor Yellow
    $testUrl = "https://speed.cloudflare.com/__down?bytes=25000000"
    
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $data = $wc.DownloadData($testUrl)
    $sw.Stop()

    $durationSeconds = $sw.Elapsed.TotalSeconds
    $totalMegabits = ($data.Length * 8) / 1MB
    $mbps = [math]::Round($totalMegabits / $durationSeconds, 2)
    $downloadedMB = [math]::Round($data.Length / 1MB, 1)

    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host "SPEED TEST RESULT" -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host "Download Speed:  " -NoNewline
    Write-Host "$mbps Mbps" -ForegroundColor Green
    Write-Host "Data Transferred: $downloadedMB MB in $([math]::Round($durationSeconds, 2))s" -ForegroundColor DarkGray
    Write-Host "Engine:          High-Throughput .NET Direct Socket" -ForegroundColor DarkGray
    Write-Host ""
}
catch {
    Write-Host "Speed test failed: $($_.Exception.Message)" -ForegroundColor Red
}
finally {
    $wc.Dispose()
    $pinger.Dispose()
}
