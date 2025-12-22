targetScope = 'resourceGroup'

param location string
param hubName string
param keyVaultId string

@description('Name of the Azure Container Registry')
param containerRegistryname string

@description('Name of application insights resource')
param appInsightsName string

@description('Storage account name')
param storageName string

@description('AI services name (Azure AI Services account)')
param aiName string

@description('Short name of the Azure Cognitive Search service (used to form target URL)')
param searchServiceName string

resource aiServices 'Microsoft.CognitiveServices/accounts@2024-04-01-preview' existing = {
  name: aiName
}

resource search 'Microsoft.Search/searchServices@2022-09-01' existing = {
  name: searchServiceName
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' existing = {
  name: appInsightsName
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2021-09-01' existing = {
  name: storageName
}

resource containerRegistry 'Microsoft.ContainerRegistry/registries@2021-12-01-preview' existing = {
  name: containerRegistryname
}

resource hub 'Microsoft.MachineLearningServices/workspaces@2025-06-01' = {
  name: hubName
  location: location
  sku: { name: 'Basic', tier: 'Basic' }
  kind: 'Hub'
  identity: { type: 'SystemAssigned' }
  properties: {
    friendlyName: hubName
    storageAccount: storageAccount.id
    keyVault: keyVaultId
    applicationInsights: appInsights.id
    containerRegistry: containerRegistry.id
    hbiWorkspace: false
    managedNetwork: { isolationMode: 'Disabled', managedNetworkKind: 'V1' }
    publicNetworkAccess: 'Enabled'
    enableDataIsolation: true
    
  }

  // AIServices (Azure Cognitive Services / Azure OpenAI) connection
  resource aiServicesConnection 'connections@2024-01-01-preview' = {
    name: '${hubName}-connection'
    properties: {
      category: 'AIServices'
      target: aiServices.properties.endpoints['OpenAI Language Model Instance API']
      authType: 'AAD'
      isSharedToAll: true
      metadata: {
        ResourceId: aiServices.id
      }
      //   credentials: connectionAuthType == 'ApiKey'
      //     ? {
      //           key: aiServices.listKeys().key1        }
      //     : null
      // }
    }
  }

  // Cognitive Search connection
  resource searchServicesConnection 'connections@2024-01-01-preview' = {
    name: '${hubName}-search-connection'
    properties: {
      category: 'CognitiveSearch'
      target: 'https://${searchServiceName}.search.windows.net'
      authType: 'AAD'
      isSharedToAll: true
      metadata: {
        ResourceId: search.id
      }
    }
    // If not ApiKey, create a separate resource with authType set to connectionAuthType and omit credentials
    // You can use a conditional resource deployment if needed, or split into two resources based on connectionAuthType
  }

}
// output hubId string = hub.id
output hubPrincipalId string = hub.identity.principalId
output azureStorageConnection string = storageName
output aiSearchConnection string = searchServiceName
