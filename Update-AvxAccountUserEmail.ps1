<#
.SYNOPSIS
  Updates the admin user and CoPilot service account emails on an Aviatrix controller (v2 API).
  Password is read from $env:AVX_PASSWORD. See ADMIN_EMAIL_UPDATE_API.md in the original deployment.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$ControllerIp,
    [string]$Username = 'admin',
    [Parameter(Mandatory)][string]$AdminEmail,
    [Parameter(Mandatory)][string]$CopilotEmail,
    [string]$CopilotUsername = 'copilot_service_account'
)
$ErrorActionPreference = 'Stop'
if (-not $env:AVX_PASSWORD) { throw 'AVX_PASSWORD environment variable is not set.' }

function Invoke-AvxApi {
    param([hashtable]$Body, [int]$MaxRetry = 3, [int]$RetryIntervalSec = 3)
    $irm = @{
        Uri = "https://$ControllerIp/v2/api"; Method = 'Post'
        Body = ($Body | ConvertTo-Json -Depth 10); ContentType = 'application/json'
    }
    if ($PSVersionTable.PSVersion.Major -ge 6) { $irm.SkipCertificateCheck = $true }
    for ($i = 1; $i -le $MaxRetry; $i++) {
        try {
            $r = Invoke-RestMethod @irm
            if ($r.return) { return $r }          # HTTP 200 alone is not success
            throw "API '$($Body.action)' failed: $($r.reason)"
        } catch {
            if ($i -eq $MaxRetry) { throw }
            Start-Sleep -Seconds $RetryIntervalSec
        }
    }
}

function Set-UserEmail([string]$Cid, [string]$User, [string]$Email) {
    Invoke-AvxApi -Body @{ action = 'edit_account_user'; CID = $Cid; username = $User; what = 'email'; email = $Email } | Out-Null
    Write-Host "Updated email for user '$User'."
}

$cid = (Invoke-AvxApi -MaxRetry 30 -RetryIntervalSec 10 -Body @{
    action = 'login'; username = $Username; password = $env:AVX_PASSWORD }).CID
if (-not $cid) { throw 'Login returned no CID.' }

$users = (Invoke-AvxApi -Body @{ action = 'list_account_users'; CID = $cid }).results
Write-Host "Before: $($users | ConvertTo-Json -Depth 6 -Compress)"

Set-UserEmail $cid 'admin' $AdminEmail

# CoPilot user may not exist (copilot_initialization = false); tolerate that.
if ($users | ConvertTo-Json -Depth 6 | Select-String -SimpleMatch "`"$CopilotUsername`"") {
    Set-UserEmail $cid $CopilotUsername $CopilotEmail
} else {
    Write-Warning "User '$CopilotUsername' not found; skipping."
}

$after = (Invoke-AvxApi -Body @{ action = 'list_account_users'; CID = $cid }).results
Write-Host "After: $($after | ConvertTo-Json -Depth 6 -Compress)"
