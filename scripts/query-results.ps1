<#
.SYNOPSIS
    Queries the Log Analytics workspace to verify which records
    survived the DCR transform (blocked-IP events should be absent).
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $ResourceGroup,
    [string] $DeploymentName = 'dcr-filter-demo',
    [int]    $LookbackMinutes = 60
)

$ErrorActionPreference = 'Stop'

$outputs = az deployment group show `
    --resource-group $ResourceGroup `
    --name $DeploymentName `
    --query properties.outputs `
    --output json | ConvertFrom-Json

$workspaceName = $outputs.workspaceName.value
$blocked       = $outputs.blockedIps.value

$workspaceGuid = az monitor log-analytics workspace show `
    --resource-group $ResourceGroup `
    --workspace-name $workspaceName `
    --query customerId --output tsv

$kql = @"
NetworkLogs_CL
| where TimeGenerated > ago(${LookbackMinutes}m)
| project TimeGenerated, Computer, SourceIP, EventID, Message
| order by TimeGenerated desc
"@

Write-Host "Workspace : $workspaceName ($workspaceGuid)" -ForegroundColor Cyan
Write-Host "Blocked IPs (rows with these SourceIPs should be ABSENT):" -ForegroundColor Yellow
Write-Host "  $($blocked -join ', ')" -ForegroundColor Yellow
Write-Host "`nKQL:`n$kql`n" -ForegroundColor DarkGray

az monitor log-analytics query `
    --workspace $workspaceGuid `
    --analytics-query $kql `
    --output table
