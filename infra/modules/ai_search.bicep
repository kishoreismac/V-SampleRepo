targetScope = 'resourceGroup'

@description('Name of the Azure Cognitive Search service')
param searchServiceName string

@description('Location for the search service')
param searchLocation string

resource searchService 'Microsoft.Search/searchServices@2025-05-01' = {
  name: searchServiceName
  identity: {
    type: 'SystemAssigned'
  }
  location: searchLocation
  sku: {
    name: 'basic'
  }
  properties: {
    replicaCount: 1
    partitionCount: 1
    endpoint: 'https://${searchServiceName}.search.windows.net'
    hostingMode: 'default'
    computeType: 'Default'
    publicNetworkAccess: 'disabled'
    networkRuleSet: {
      ipRules: []
      bypass: 'None'
    }
    encryptionWithCmk: {
      enforcement: 'Unspecified'
    }
    disableLocalAuth: false
    authOptions: {
      aadOrApiKey: {}
    }
    dataExfiltrationProtections: []
    semanticSearch: 'free'
    upgradeAvailable: 'notAvailable'
  }
}

resource searchServiceContributor 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: '7ca78c08-252a-4471-8644-bb5ff32d4ba0'
  scope: subscription()
}

resource searchIndexContributor 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: '8ebe5a00-799e-43f5-93ac-243d3dce84a7'
  scope: subscription()
}

resource searchIndexDataAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(searchService.id, searchIndexContributor.id, searchService.id)
  scope: searchService
  properties: {
    roleDefinitionId: searchIndexContributor.id
    principalType: 'ServicePrincipal'
    principalId: searchService.identity.principalId
  }
}

resource searchContributorAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(searchService.id, searchServiceContributor.id, searchService.id)
  scope: searchService
  properties: {
    roleDefinitionId: searchServiceContributor.id
    principalType: 'ServicePrincipal'
    principalId: searchService.identity.principalId
  }
}

output searchServiceId string = searchService.id

output searchServiceEndpoint string = 'https://${searchServiceName}.search.windows.net'
