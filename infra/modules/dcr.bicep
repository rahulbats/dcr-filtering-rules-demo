@description('Name of the Data Collection Rule.')
param dcrName string

@description('Azure region.')
param location string

@description('Resource ID of the destination Log Analytics workspace.')
param workspaceId string

@description('Friendly name used to refer to the workspace destination inside the DCR.')
param workspaceName string

@description('Name of the custom log table (without the _CL suffix).')
param customTableName string

@description('KQL transform applied at ingestion time. Records not matching are dropped.')
param transformKql string

// Direct-ingestion DCR — accepts logs via the Logs Ingestion API (HTTP POST).
// The transformKql filters out events containing blocked IPs before ingestion.
resource dcr 'Microsoft.Insights/dataCollectionRules@2023-03-11' = {
  name: dcrName
  location: location
  kind: 'Direct'
  properties: {
    streamDeclarations: {
      'Custom-${customTableName}_CL': {
        columns: [
          { name: 'TimeGenerated', type: 'datetime' }
          { name: 'Computer',      type: 'string' }
          { name: 'SourceIP',      type: 'string' }
          { name: 'EventID',       type: 'int' }
          { name: 'EventData',     type: 'string' }
          { name: 'Message',       type: 'string' }
        ]
      }
    }
    destinations: {
      logAnalytics: [
        {
          workspaceResourceId: workspaceId
          name: workspaceName
        }
      ]
    }
    dataFlows: [
      {
        streams: [
          'Custom-${customTableName}_CL'
        ]
        destinations: [
          workspaceName
        ]
        transformKql: transformKql
        outputStream: 'Custom-${customTableName}_CL'
      }
    ]
  }
}

output dcrId string = dcr.id
output dcrName string = dcr.name
output dcrImmutableId string = dcr.properties.immutableId
output logsIngestionEndpoint string = any(dcr.properties).endpoints.logsIngestion
output streamName string = 'Custom-${customTableName}_CL'
