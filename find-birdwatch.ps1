#requires -version 5.1
<#
.SYNOPSIS
  Finds BirdWatchAI Server instances on your local network.

.DESCRIPTION
  When http://birdwatch.local:8080 won't load (some Windows, corporate, or VPN
  setups disable the mDNS ".local" resolver), you need the server's actual IP
  address. Your Raspberry Pi is headless, so there's no screen to read it off.

  This script finds it for you. It sweeps your local network for anything
  answering on TCP 8080, then confirms each hit is genuinely a BirdWatchAI
  server by calling its /api/status endpoint. It prints the dashboard URL(s)
  and offers to open one in your browser.

  Nothing is installed and nothing leaves your machine — it only talks to hosts
  on your own LAN.

.PARAMETER Port
  TCP port to probe. Default 8080 (the BirdWatchAI default).

.PARAMETER TimeoutMs
  Per-host TCP connect timeout in milliseconds. Raise it (e.g. 800) on a slow
  or congested Wi-Fi network if the scan misses a server you know is up.
  Default 400.

.PARAMETER Subnet
  Force a specific /24 prefix, e.g. "192.168.1". By default the script
  auto-detects the subnet(s) from your active network adapters.

.EXAMPLE
  .\find-birdwatch.ps1
  Auto-detect the subnet and scan it.

.EXAMPLE
  .\find-birdwatch.ps1 -Subnet 10.0.0 -TimeoutMs 800
  Scan 10.0.0.1-254 with a more forgiving timeout.

.NOTES
  If PowerShell refuses to run this with a script-execution error, launch it as:
    powershell -ExecutionPolicy Bypass -File .\find-birdwatch.ps1
#>
[CmdletBinding()]
param(
    [int]$Port = 8080,
    [int]$TimeoutMs = 400,
    [string]$Subnet
)

$ErrorActionPreference = 'Stop'

function Get-LocalPrefixes {
    # Return the unique /24 prefixes (first three octets) of every usable IPv4
    # address on this machine, skipping loopback (127.) and APIPA/link-local
    # (169.254.) ranges. Get-NetIPAddress is the modern path; fall back to a
    # DNS lookup on older hosts where the cmdlet isn't present.
    $prefixes = @()
    try {
        $addrs = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction Stop |
            Where-Object { $_.IPAddress -notmatch '^(127\.|169\.254\.)' }
        foreach ($a in $addrs) {
            $o = $a.IPAddress.Split('.')
            if ($o.Count -eq 4) { $prefixes += ($o[0..2] -join '.') }
        }
    } catch {
        foreach ($ip in [System.Net.Dns]::GetHostAddresses([System.Net.Dns]::GetHostName())) {
            if ($ip.AddressFamily -eq 'InterNetwork') {
                $s = $ip.ToString()
                if ($s -notmatch '^(127\.|169\.254\.)') {
                    $prefixes += (($s.Split('.'))[0..2] -join '.')
                }
            }
        }
    }
    ,@($prefixes | Select-Object -Unique)
}

function Test-PortBatch {
    # Fire a non-blocking TCP connect at every target at once, wait one shared
    # timeout window, then collect the ones that connected. This keeps the whole
    # batch's wall-clock cost at ~TimeoutMs regardless of how many hosts we probe
    # (a serial scan of 254 hosts would take minutes). Closed ports RST fast and
    # throw on EndConnect; dead hosts simply never complete before the timeout.
    param([string[]]$Targets, [int]$Port, [int]$TimeoutMs)
    $pending = @()
    foreach ($ip in $Targets) {
        $client = New-Object System.Net.Sockets.TcpClient
        try {
            $async = $client.BeginConnect($ip, $Port, $null, $null)
            $pending += [pscustomobject]@{ Ip = $ip; Client = $client; Async = $async }
        } catch {
            $client.Close()
        }
    }
    Start-Sleep -Milliseconds $TimeoutMs
    $open = @()
    foreach ($p in $pending) {
        try {
            if ($p.Async.IsCompleted) {
                $p.Client.EndConnect($p.Async)
                if ($p.Client.Connected) { $open += $p.Ip }
            }
        } catch {
            # Connection refused / reset — port closed. Ignore.
        } finally {
            $p.Client.Close()
        }
    }
    ,@($open)
}

function Confirm-BirdWatch {
    # Confirm a host that answered on the port is actually a BirdWatchAI server
    # by fetching /api/status. The EngineStatus JSON always carries the
    # "cameraConnected" and "detectionsToday" fields — a fingerprint nothing
    # else on a home LAN will have. Returns the parsed status, or $null.
    param([string]$Ip, [int]$Port)
    $url = "http://${Ip}:${Port}/api/status"
    try {
        $resp = Invoke-RestMethod -Uri $url -TimeoutSec 3 -ErrorAction Stop
        $names = @($resp.PSObject.Properties.Name)
        if (($names -contains 'cameraConnected') -and ($names -contains 'detectionsToday')) {
            return $resp
        }
    } catch {
        # Something else is listening on this port; not our server.
    }
    return $null
}

Write-Host ""
Write-Host "BirdWatchAI Server finder" -ForegroundColor Cyan
Write-Host "-------------------------"

$prefixes = if ($Subnet) { ,@($Subnet.TrimEnd('.')) } else { Get-LocalPrefixes }
if (-not $prefixes -or $prefixes.Count -eq 0) {
    Write-Host "Couldn't determine your local network. Pass one explicitly, e.g.:" -ForegroundColor Yellow
    Write-Host "    .\find-birdwatch.ps1 -Subnet 192.168.1"
    exit 1
}

Write-Host ("Scanning {0} on port {1} ..." -f (($prefixes | ForEach-Object { "$_.0/24" }) -join ', '), $Port)

# Phase 1: fast parallel port sweep, chunked so we never hold an unreasonable
# number of sockets open at once across multiple subnets.
$openHosts = @()
foreach ($prefix in $prefixes) {
    $targets = 1..254 | ForEach-Object { "$prefix.$_" }
    foreach ($chunk in ($targets | ForEach-Object -Begin { $i = 0; $bucket = @() } -Process {
                $bucket += $_
                if ($bucket.Count -ge 128) { ,@($bucket); $bucket = @() }
            } -End { if ($bucket.Count) { ,@($bucket) } })) {
        $openHosts += Test-PortBatch -Targets $chunk -Port $Port -TimeoutMs $TimeoutMs
    }
}
$openHosts = @($openHosts | Select-Object -Unique)

# Phase 2: confirm each open host is a BirdWatchAI server.
$found = @()
foreach ($ip in $openHosts) {
    $status = Confirm-BirdWatch -Ip $ip -Port $Port
    if ($status) {
        $names = @($status.PSObject.Properties.Name)
        $found += [pscustomobject]@{
            Ip         = $ip
            Url        = "http://${ip}:${Port}"
            State      = "$($status.state)"
            Camera     = if ($status.cameraConnected) { 'Connected' } else { 'Disconnected' }
            DetsToday  = $status.detectionsToday
            # feederName/hostname are only present on newer servers.
            Feeder     = if ($names -contains 'feederName') { $status.feederName } else { $null }
            Hostname   = if ($names -contains 'hostname')   { $status.hostname }   else { $null }
        }
    }
}

Write-Host ""
if ($found.Count -eq 0) {
    Write-Host "No BirdWatchAI servers found on your network." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Things to check:"
    Write-Host "  * Is the Pi powered on and on the SAME network as this PC?"
    Write-Host "    (A PC on a 'Guest' Wi-Fi or a work VPN often can't see it.)"
    Write-Host "  * Give it more time on slow Wi-Fi:  .\find-birdwatch.ps1 -TimeoutMs 800"
    Write-Host "  * If your network isn't a /24, force it:  .\find-birdwatch.ps1 -Subnet 10.1.2"
    Write-Host "  * Last resort: your router's admin page lists connected devices by name."
    exit 2
}

Write-Host ("Found {0} BirdWatchAI server{1}:" -f $found.Count, $(if ($found.Count -eq 1) { '' } else { 's' })) -ForegroundColor Green
Write-Host ""
$i = 0
foreach ($f in $found) {
    $i++
    # Headline with the feeder name if the operator set one; otherwise lead with the URL.
    if ($f.Feeder) {
        Write-Host ("  [{0}] {1}" -f $i, $f.Feeder) -ForegroundColor Green
        Write-Host ("      {0}" -f $f.Url) -ForegroundColor Green
    } else {
        Write-Host ("  [{0}] {1}" -f $i, $f.Url) -ForegroundColor Green
    }
    # Detail line — prefix the host name when we have a real one (reachable as <hostname>.local).
    $host_ = if ($f.Hostname) { "host: {0}   " -f $f.Hostname } else { "" }
    Write-Host ("      {0}camera: {1}   detections today: {2}   monitoring: {3}" -f $host_, $f.Camera, $f.DetsToday, $f.State)
}
Write-Host ""

# Offer to open one. Default to the only one when there's a single result.
# Skip the prompt entirely when there's no interactive console (e.g. run via
# "irm ... | iex", or piped) — just leave the printed link(s) for the user.
# Returns the typed answer, or $null when there's no console to prompt at (so a
# non-interactive run just leaves the links printed instead of auto-opening).
function Read-Prompt {
    param([string]$Message)
    if (-not [Environment]::UserInteractive) { return $null }
    try { return (Read-Host $Message) } catch { return $null }
}

$choice = $null
if ($found.Count -eq 1) {
    $ans = Read-Prompt "Open it in your browser? [Y/n]"
    if ($null -ne $ans -and ($ans -eq '' -or $ans -match '^(y|yes)$')) { $choice = $found[0] }
} else {
    $ans = Read-Prompt ("Open which one in your browser? [1-{0}, or Enter to skip]" -f $found.Count)
    if ($ans -match '^\d+$') {
        $n = [int]$ans
        if ($n -ge 1 -and $n -le $found.Count) { $choice = $found[$n - 1] }
    }
}

if ($choice) {
    Write-Host ("Opening {0} ..." -f $choice.Url)
    Start-Process $choice.Url
}

Write-Host ""
Write-Host "Tip: bookmark the address above so you don't have to scan again."
Write-Host "If the IP keeps changing, reserve it for the Pi in your router's DHCP settings."
