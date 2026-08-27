# setup-scheduled-task.ps1
#
# Register a Windows Scheduled Task that runs birdwatch-start.cmd at user logon, after
# waiting up to 5 minutes for Docker Desktop to come online. Belt-and-suspenders for
# the "Docker Desktop starts at login + container restart policy" defaults — most
# installs don't need this, but it's a safety net for hosts where Docker has been
# observed to flake on cold start.
#
# Usage (PowerShell, as Administrator, from this folder):
#   .\setup-scheduled-task.ps1
#
# Idempotent: running it again updates the existing task definition.
#
# To remove the task later:
#   Unregister-ScheduledTask -TaskName "BirdWatchAI Server Autostart" -Confirm:$false

$ErrorActionPreference = "Stop"

$TaskName = "BirdWatchAI Server Autostart"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$StartScript = Join-Path $ScriptDir "birdwatch-start.cmd"

if (-not (Test-Path $StartScript)) {
    Write-Error "Could not find $StartScript next to this script."
    exit 1
}

# Require admin — schtasks needs it to register tasks for the local user account.
$currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "This script must be run as Administrator. Right-click PowerShell and choose 'Run as Administrator'."
    exit 1
}

# The action wraps birdwatch-start.cmd in a small PowerShell prologue that waits for Docker
# to be ready (polls `docker info` until it succeeds, up to 5 minutes). Avoids the race
# where the task fires before Docker Desktop has finished starting after login.
$waitForDocker = @'
$deadline = (Get-Date).AddMinutes(5)
while ((Get-Date) -lt $deadline) {
    & docker info *>$null
    if ($LASTEXITCODE -eq 0) { break }
    Start-Sleep -Seconds 5
}
'@
$invokeStart = "& `"$StartScript`""
$psCommand = "$waitForDocker; $invokeStart"
$encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($psCommand))

$action = New-ScheduledTaskAction -Execute "powershell.exe" `
    -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -EncodedCommand $encoded"

# AtLogOn for the current user. Delaying a few seconds avoids racing the Docker Desktop
# launcher itself, which the system spawns on the same trigger.
$trigger = New-ScheduledTaskTrigger -AtLogOn -User $currentUser.Name
$trigger.Delay = "PT15S"

$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -RunOnlyIfNetworkAvailable:$false `
    -ExecutionTimeLimit (New-TimeSpan -Hours 1)

# Run as the current user (interactive — so it can talk to the user's Docker Desktop).
$taskPrincipal = New-ScheduledTaskPrincipal -UserId $currentUser.Name -LogonType Interactive -RunLevel Limited

# Idempotent: replace if it already exists.
if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) {
    Write-Host "Updating existing scheduled task '$TaskName'..."
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
}

Register-ScheduledTask -TaskName $TaskName `
    -Description "Auto-start BirdWatchAI Server (waits for Docker Desktop, then runs birdwatch-start.cmd)." `
    -Action $action `
    -Trigger $trigger `
    -Settings $settings `
    -Principal $taskPrincipal | Out-Null

Write-Host ""
Write-Host "Scheduled task '$TaskName' registered." -ForegroundColor Green
Write-Host "It will run at your next login. To test now:"
Write-Host "    Start-ScheduledTask -TaskName `"$TaskName`""
Write-Host ""
Write-Host "To remove later:"
Write-Host "    Unregister-ScheduledTask -TaskName `"$TaskName`" -Confirm:`$false"
