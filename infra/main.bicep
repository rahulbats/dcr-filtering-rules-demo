targetScope = 'resourceGroup'

@description('Base name used as a prefix for all resources.')
@minLength(3)
@maxLength(16)
param namePrefix string = 'dcrdemo'

@description('Azure region for all resources.')
param location string = resourceGroup().location

@description('IP ranges (CIDR) to allow. Only events with a source IP in one of these ranges are kept at ingestion.')
param allowedIps array = [
  '10.0.0.0/24'
  '192.168.1.0/24'
]

@description('Retention in days for the Log Analytics workspace.')
@minValue(30)
@maxValue(730)
param retentionInDays int = 30

var suffix = uniqueString(resourceGroup().id, namePrefix)
var workspaceName = '${namePrefix}-law-${suffix}'
var dcrName = '${namePrefix}-dcr-${suffix}'
var customTableName = 'NetworkLogs'

// DCR ingestion-time transformations support only a limited KQL subset with NO IP functions
// (ipv4_is_in_range / ipv4_is_in_any_range are unavailable). We match on octet boundaries using
// the supported `==` (exact IP) and `startswith` (CIDR prefix) operators. Entries may be a bare
// IP (exact match) or CIDR on an octet boundary (e.g. 10.0.0.0/24 -> SourceIP startswith '10.0.0.').
// Build the transformKql expression that keeps only events whose source IP matches an allowed entry.
// Example output:
//   source | where SourceIP == '10.0.0.5' or SourceIP startswith '192.168.1.'
var ipConditions = join(map(allowedIps, ip => contains(ip, '/')
  ? 'SourceIP startswith \'${join(take(split(first(split(ip, '/')), '.'), int(last(split(ip, '/'))) / 8), '.')}.\''
  : 'SourceIP == \'${ip}\''), ' or ')
var transformKql = empty(allowedIps)
  ? 'source'
  : 'source | where ${ipConditions}'

module law 'modules/logAnalytics.bicep' = {
  name: 'logAnalytics'
  params: {
    workspaceName: workspaceName
    location: location
    retentionInDays: retentionInDays
    customTableName: customTableName
  }
}

module dcr 'modules/dcr.bicep' = {
  name: 'dcr'
  params: {
    dcrName: dcrName
    location: location
    workspaceId: law.outputs.workspaceId
    workspaceName: workspaceName
    customTableName: customTableName
    transformKql: transformKql
  }
}

output workspaceName string = workspaceName
output workspaceId string = law.outputs.workspaceId
output dcrImmutableId string = dcr.outputs.dcrImmutableId
output dcrResourceId string = dcr.outputs.dcrId
output dcrName string = dcr.outputs.dcrName
output logsIngestionEndpoint string = dcr.outputs.logsIngestionEndpoint
output streamName string = dcr.outputs.streamName
output transformKql string = transformKql
output allowedIps array = allowedIps
