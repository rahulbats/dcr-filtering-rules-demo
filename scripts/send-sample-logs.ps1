<#
.SYNOPSIS
    Sends sample log events to the DCR's Logs Ingestion API endpoint.
    Events from blocked IPs should be dropped by the DCR's transformKql.

.DESCRIPTION
    Reads deployment outputs to get the logsIngestionEndpoint, dcrImmutableId,
    and streamName, then POSTs 6 sample records (4 allowed, 2 blocked IPs).
    Authenticates using the signed-in az CLI identity.

.EXAMPLE
    ./scripts/send-sample-logs.ps1 -ResourceGroup rg-dcr-filter-demo
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $ResourceGroup,
    [string] $DeploymentName = 'dcr-filter-demo'
)

$ErrorActionPreference = 'Stop'

# Get deployment outputs
$outputs = az deployment group show `
    --resource-group $ResourceGroup `
    --name $DeploymentName `
    --query properties.outputs `
    --output json | ConvertFrom-Json

$endpoint    = $outputs.logsIngestionEndpoint.value
$dcrId       = $outputs.dcrImmutableId.value
$streamName  = $outputs.streamName.value
$blocked     = $outputs.blockedIps.value

Write-Host "Endpoint   : $endpoint" -ForegroundColor Cyan
Write-Host "DCR ID     : $dcrId" -ForegroundColor Cyan
Write-Host "Stream     : $streamName" -ForegroundColor Cyan
Write-Host "Blocked IPs: $($blocked -join ', ')" -ForegroundColor Yellow

# Get an access token for the Logs Ingestion API
$token = az account get-access-token --resource https://monitor.azure.com --query accessToken --output tsv

$uri = "$endpoint/dataCollectionRules/$dcrId/streams/${streamName}?api-version=2023-01-01"

$headers = @{
    'Authorization' = "Bearer $token"
    'Content-Type'  = 'application/json'
}

# Sample events — 4 allowed, 2 blocked
$events = @(
    @{ SourceIP = '10.0.0.1';      Computer = 'WEB-01'; EventID = 1098; EventData = '<IntuneEvent><Status>OK</Status></IntuneEvent>';   Message = 'Policy sync from allowed device' }
    @{ SourceIP = '10.0.0.2';      Computer = 'WEB-02'; EventID = 1098; EventData = '<IntuneEvent><Status>OK</Status></IntuneEvent>';   Message = 'Compliance check from allowed device' }
    @{ SourceIP = '10.0.0.5';      Computer = 'WEB-03'; EventID = 1098; EventData = '<IntuneEvent><Status>OK</Status></IntuneEvent>';   Message = 'SHOULD BE FILTERED - blocked IP' }
    @{ SourceIP = '192.168.1.100'; Computer = 'WEB-04'; EventID = 1098; EventData = '<IntuneEvent><Status>OK</Status></IntuneEvent>';   Message = 'SHOULD BE FILTERED - blocked IP' }
    @{ SourceIP = '203.0.113.42';  Computer = 'WEB-05'; EventID = 1098; EventData = '<IntuneEvent><Status>OK</Status></IntuneEvent>';   Message = 'Enrollment from allowed device' }
    @{ SourceIP = '198.51.100.7';  Computer = 'WEB-06'; EventID = 1098; EventData = '<IntuneEvent><Status>OK</Status></IntuneEvent>';   Message = 'App install from allowed device' }
)

$body = $events | ForEach-Object {
    @{
        TimeGenerated = (Get-Date).ToUniversalTime().ToString('o')
        Computer      = $_.Computer
        SourceIP      = $_.SourceIP
        EventID       = $_.EventID
        EventData     = $_.EventData
        Message       = $_.Message
    }
}

$json = $body | ConvertTo-Json -AsArray -Depth 5

Write-Host "`nSending $($events.Count) events to Logs Ingestion API..." -ForegroundColor Cyan

$response = Invoke-WebRequest -Uri $uri -Method Post -Headers $headers -Body $json -UseBasicParsing

if ($response.StatusCode -eq 204) {
    Write-Host "Success (HTTP 204) — all events accepted by the API." -ForegroundColor Green
    Write-Host "The DCR transform will DROP events from: $($blocked -join ', ')" -ForegroundColor Yellow
    Write-Host "`nWait ~2-5 minutes, then run:" -ForegroundColor Yellow
    Write-Host "  ./scripts/query-results.ps1 -ResourceGroup $ResourceGroup" -ForegroundColor Yellow
} else {
    Write-Host "Unexpected status: $($response.StatusCode)" -ForegroundColor Red
    Write-Host $response.Content
}
