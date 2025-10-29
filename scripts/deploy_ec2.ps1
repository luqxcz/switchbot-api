param(
  [Parameter(Mandatory=$true)] [string] $PemPath,
  [Parameter(Mandatory=$true)] [string] $RemoteHost,
  [string] $User = "ubuntu",
  [Parameter(Mandatory=$true)] [string] $Token,
  [Parameter(Mandatory=$true)] [string] $Secret,
  [string] $OutPath = "/opt/switchbot-api/timeseries.csv",
  [ValidateSet("local", "utc")] [string] $Timezone = "local",
  [switch] $SkipInfrared,
  [int] $IntervalSeconds = 1800
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $PemPath)) {
  throw "PEM file not found: $PemPath"
}

$remote = "$User@$RemoteHost"

Write-Host "==> Ensuring remote directory exists and owned by $User"
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i "$PemPath" "${remote}" "sudo mkdir -p /opt/switchbot-api && sudo chown -R ${User}:${User} /opt/switchbot-api"

Write-Host "==> Uploading repository to EC2 (staging to home, then promoting to /opt)"
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i "$PemPath" "${remote}" "rm -rf ~/switchbot-api-upload && mkdir -p ~/switchbot-api-upload"
scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i "$PemPath" -r . "${remote}:~/switchbot-api-upload/"
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i "$PemPath" "${remote}" "sudo rm -rf /opt/switchbot-api/* && sudo cp -a ~/switchbot-api-upload/. /opt/switchbot-api/ && rm -rf ~/switchbot-api-upload"

Write-Host "==> Making setup script executable"
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i "$PemPath" "${remote}" "sudo sed -i 's/\r$//' /opt/switchbot-api/scripts/setup_ec2_switchbot.sh && sudo chmod +x /opt/switchbot-api/scripts/setup_ec2_switchbot.sh"

$skipFlag = if ($SkipInfrared) { "--skip-infrared" } else { "" }

Write-Host "==> Running remote setup with systemd"
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i "$PemPath" "${remote}" "sudo /opt/switchbot-api/scripts/setup_ec2_switchbot.sh --token '$Token' --secret '$Secret' --repo-dir /opt/switchbot-api --user ${User} --out '$OutPath' --timezone '$Timezone' --interval-seconds $IntervalSeconds $skipFlag"

Write-Host "==> Service status"
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i "$PemPath" "${remote}" "sudo systemctl status switchbot-logger.service --no-pager || true"

Write-Host "==> Last 20 log lines"
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i "$PemPath" "${remote}" "sudo journalctl -u switchbot-logger.service -n 20 --no-pager || true"

Write-Host "Done. Use: ssh -i `"$PemPath`" $remote 'journalctl -u switchbot-logger.service -f' to follow logs."