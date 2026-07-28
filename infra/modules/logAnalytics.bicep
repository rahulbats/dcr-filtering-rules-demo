@description('Name of the Log Analytics workspace.')
param workspaceName string

@description('Azure region.')
param location string

@description('Workspace data retention in days.')
param retentionInDays int = 30

@description('Name of the custom log table (without _CL suffix).')
param customTableName string

@description('Public network access for ingestion. Set to Disabled if org policy forbids public access.')
@allowed([
  'Enabled'
  'Disabled'
])
param publicNetworkAccessForIngestion string = 'Disabled'

@description('Public network access for query. Set to Disabled if org policy forbids public access.')
@allowed([
  'Enabled'
  'Disabled'
])
param publicNetworkAccessForQuery string = 'Disabled'

resource workspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: workspaceName
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: retentionInDays
    publicNetworkAccessForIngestion: publicNetworkAccessForIngestion
    publicNetworkAccessForQuery: publicNetworkAccessForQuery
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
  }
}

resource customTable 'Microsoft.OperationalInsights/workspaces/tables@2022-10-01' = {
  parent: workspace
  name: '${customTableName}_CL'
  properties: {
    schema: {
      name: '${customTableName}_CL'
      columns: [
        { name: 'TimeGenerated', type: 'dateTime' }
        { name: 'Computer',      type: 'string' }
        { name: 'SourceIP',      type: 'string' }
        { name: 'EventID',       type: 'int' }
        { name: 'EventData',     type: 'string' }
        { name: 'Message',       type: 'string' }
      ]
    }
    retentionInDays: retentionInDays
  }
}

output workspaceId string = workspace.id
output workspaceCustomerId string = workspace.properties.customerId
