# Azure DCR Source-IP Filtering Demo

This demo shows how an **Azure Monitor Data Collection Rule (DCR)** can filter out
log records from unwanted **source IP addresses** *before* they are ingested into
a Log Analytics workspace, using the DCR's `transformKql` expression.

## What gets deployed

The templates (ARM or Bicep) create:

| Resource | Purpose |
|---|---|
| Log Analytics workspace | Destination for ingested logs |
| Custom table `NetworkLogs_CL` | Schema for the demo logs |
| Data Collection Rule (DCR) | Direct-ingestion DCR exposing its own `logsIngestion` endpoint and **filtering out blocked source IPs via `transformKql`** |

## How the filtering works

The DCR contains a transform similar to:

```kusto
source | where SourceIP !in ('10.0.0.5','192.168.1.100')
```

Any record posted to the Logs Ingestion API whose `SourceIP` matches the
blocked list is dropped at ingestion time — it never lands in
`NetworkLogs_CL` and is never billed for ingestion/retention.

The blocked IP list is configurable via the `blockedIps` parameter.

## Project layout

```
infra/
  main.json                   # ARM template (single file, used by deploy script)
  main.bicep                  # Bicep entry point (alternative to main.json)
  main.parameters.json        # Parameter values (shared by both ARM and Bicep)
  modules/
    logAnalytics.bicep        # Workspace + custom NetworkLogs_CL table
    dcr.bicep                 # Direct-ingestion DCR with transformKql filter
scripts/
  deploy.ps1                  # az deployment group create wrapper (uses main.json by default)
  send-sample-logs.ps1        # Posts both allowed and blocked records via Logs Ingestion API
  query-results.ps1           # Runs a KQL query to prove the blocked rows were dropped
```

## Prerequisites

- Azure CLI 2.61+
- An Azure subscription and a resource group you can deploy to
- PowerShell 7+

## Deploy

```powershell
# 1. Sign in and pick a subscription
az login
az account set --subscription "<your-subscription-id>"

# 2. Create a resource group
az group create -n rg-dcr-filter-demo -l eastus

# 3. Deploy using ARM template (default)
./scripts/deploy.ps1 -ResourceGroup rg-dcr-filter-demo -Location eastus

# Or deploy using Bicep instead
./scripts/deploy.ps1 -ResourceGroup rg-dcr-filter-demo -Location eastus `
    -TemplateFile infra/main.bicep
```

After deployment, grant yourself the **Monitoring Metrics Publisher** role on
the DCR so the send script can POST logs:

```powershell
$userId = az ad signed-in-user show --query id -o tsv
$dcrId  = az deployment group show -g rg-dcr-filter-demo -n dcr-filter-demo `
    --query properties.outputs.dcrResourceId.value -o tsv
az role assignment create --assignee $userId `
    --role "Monitoring Metrics Publisher" --scope $dcrId
```

## Logs Ingestion endpoint

A `kind: Direct` DCR automatically exposes a **public Logs Ingestion API
endpoint**. This is the URL that clients (scripts, applications) POST log
records to. The DCR's `transformKql` is evaluated *before* records reach the
workspace, so filtered rows never land in the table.

The endpoint URL looks like:

```
https://<dcr-name>-<hash>-<region>.logs.z1.ingest.monitor.azure.com
```

**How to retrieve it:**

```powershell
# From deployment outputs
az deployment group show -g rg-dcr-filter-demo -n dcr-filter-demo `
    --query properties.outputs.logsIngestionEndpoint.value -o tsv

# Or directly from the DCR resource
az resource show --ids <dcr-resource-id> --query properties.endpoints.logsIngestion -o tsv
```

**In the Azure portal:** Navigate to **Monitor → Data Collection Rules →**
click the DCR **→ Overview** — the endpoint is listed under **Logs ingestion**
in the Essentials section.

The full URL used by the send script to POST records is:

```
<endpoint>/dataCollectionRules/<dcrImmutableId>/streams/<streamName>?api-version=2023-01-01
```

> **Note:** For agent-based DCRs (`kind: Windows`), AMA does *not* use this
> public endpoint. AMA sends data through Azure Monitor's internal pipeline.
> The `transformKql` still applies — it filters events regardless of how
> they arrive.

## Send sample logs

```powershell
./scripts/send-sample-logs.ps1 `
    -ResourceGroup rg-dcr-filter-demo `
    -DeploymentName dcr-filter-demo
```

The script sends 6 records: 4 from allowed IPs and 2 from blocked IPs
(`10.0.0.5` and `192.168.1.100`).

## Verify the filter worked

```powershell
./scripts/query-results.ps1 -ResourceGroup rg-dcr-filter-demo
```

You should see only the 4 allowed records in `NetworkLogs_CL`. The 2 blocked
ones were dropped by the DCR transform.

## Customize the blocked list

Edit `infra/main.parameters.json` and redeploy:

```jsonc
"blockedIps": {
    "value": [ "10.0.0.5", "192.168.1.100", "203.0.113.7" ]
}
```

## Clean up

```powershell
az group delete -n rg-dcr-filter-demo --yes --no-wait
```
