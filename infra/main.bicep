targetScope = 'resourceGroup'

@description('Base name used as a prefix for all resources.')
@minLength(3)
@maxLength(16)
param namePrefix string = 'dcrdemo'

@description('Azure region for all resources.')
param location string = resourceGroup().location

@description('IPs to block. Events containing these source IPs will be dropped at ingestion.')
param blockedIps array = [
  '10.0.0.5'
  '192.168.1.100'
]

@description('Retention in days for the Log Analytics workspace.')
@minValue(30)
@maxValue(730)
param retentionInDays int = 30

var suffix = uniqueString(resourceGroup().id, namePrefix)
var workspaceName = '${namePrefix}-law-${suffix}'
var dcrName = '${namePrefix}-dcr-${suffix}'
var customTableName = 'NetworkLogs'

// Build the transformKql expression that drops events from blocked source IPs.
// Example output:
//   source | where SourceIP !in ('10.0.0.5','192.168.1.100')
var ipList = join(map(blockedIps, ip => '\'${ip}\''), ',')
var transformKql = empty(blockedIps)
  ? 'source'
  : 'source | where SourceIP !in (${ipList})'

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
output blockedIps array = blockedIps
