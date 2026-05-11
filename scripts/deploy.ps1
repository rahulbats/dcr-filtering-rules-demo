<#
.SYNOPSIS
    Deploys the DCR source-IP filtering demo infrastructure.

.EXAMPLE
    ./scripts/deploy.ps1 -ResourceGroup rg-dcr-filter-demo -Location eastus
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $ResourceGroup,
    [Parameter(Mandatory)] [string] $Location,
    [string] $DeploymentName = 'dcr-filter-demo',
    [string] $ParametersFile = (Join-Path $PSScriptRoot '..\infra\main.parameters.json'),
    [string] $TemplateFile  = (Join-Path $PSScriptRoot '..\infra\main.json')
)

$ErrorActionPreference = 'Stop'

Write-Host "Ensuring resource group '$ResourceGroup' exists in $Location..." -ForegroundColor Cyan
az group create --name $ResourceGroup --location $Location --output none

Write-Host "Deploying ARM template..." -ForegroundColor Cyan
az deployment group create `
    --name $DeploymentName `
    --resource-group $ResourceGroup `
    --template-file $TemplateFile `
    --parameters "@$ParametersFile" `
    --output none

Write-Host "Deployment outputs:" -ForegroundColor Green
az deployment group show `
    --resource-group $ResourceGroup `
    --name $DeploymentName `
    --query properties.outputs `
    --output jsonc
