@description('Name of the Log Analytics Workspace.')
param logAnalyticsWorkspacename string
@description('Location for the Log Analytics Workspace')
param location string = resourceGroup().location
@description('Resource tags.')
param tags object
@description('SKU for the Log Analytics Workspace')
@allowed(['PerGB2018', 'PerNode', 'Free', 'Premium', 'Standalone'])
param lasku string = 'PerNode'

@description('Workspace data retention in days.')
param retentionInDays int = 60

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2021-12-01-preview' = {
  name: logAnalyticsWorkspacename
  tags: tags
  location: location
  properties: {
    sku: {
      name: lasku
    }
    retentionInDays: retentionInDays
  }
}

output logAnalyticsWorkspaceId string = logAnalyticsWorkspace.id
