targetScope = 'resourceGroup'

@description('Name of Azure AI Services account.')
param aiName string

@description('Location for the Azure AI Services account.')
param location string

@description('SKU for the Azure AI Services account.')
param aiSku object = {
  name: 'S0'
  tier: 'Standard'
}


@description('Identity for the Azure AI Services account.')
param aiServicesIdentity object = {
  type: 'SystemAssigned'
}

@description('Custom subdomain name for the Azure AI Services account.')
param customSubDomainName string

@description('Resource tags.')
param tags object = {}

@description('Array of model deployments to create: [{ model:{name,version}, sku:{name,capacity} }].')
param modelDeployments array = []

resource aiServices 'Microsoft.CognitiveServices/accounts@2023-05-01' = {
  name: aiName
  location: location
  sku: aiSku
  kind: 'AIServices'
  identity: aiServicesIdentity
  tags: tags
  properties: {
    customSubDomainName: customSubDomainName
    publicNetworkAccess: 'Disabled' // keep Disabled; access only via PE
    networkAcls: {
      defaultAction: 'Deny'
      virtualNetworkRules: []
      ipRules: []
    }
    disableLocalAuth: false
  }
}

// Optional: deployments
@batchSize(1)
resource model 'Microsoft.CognitiveServices/accounts/deployments@2023-05-01' = [for d in modelDeployments: {
  name: d.model.name
  parent: aiServices
  sku: {
    capacity: d.sku.capacity ?? 100
    name: empty(d.sku.name) ? 'Standard' : d.sku.name
  }
  properties: {
    model: {
      format: 'OpenAI'
      name: d.model.name
      version: d.model.version
    }
  }
}]

// Cognitive Services User role for the account’s MI
resource cognitiveServicesUserRoleDefinition 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: '64702f94-c441-49e6-a78b-ef80e0188fee'
  scope: subscription()
}

resource cognitiveServicesUserRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(aiServices.id, cognitiveServicesUserRoleDefinition.id, aiServices.id)
  scope: aiServices
  properties: {
    roleDefinitionId: cognitiveServicesUserRoleDefinition.id
    principalType: 'ServicePrincipal'
    principalId: aiServices.identity.principalId
  }
}

output aiServicesPrincipalId string = aiServices.identity.principalId
