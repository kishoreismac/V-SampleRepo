targetScope = 'resourceGroup'

@description('Principal ID (objectId) of the User-Assigned Managed Identity')
param principalId string

@description('Principal ID (objectId) of Service Principal')
param spPrincipalId string

@description('Name of the Key Vault')
param keyVaultName string

@description('Name of the Azure Cognitive Search service')
param searchServiceName string

@description('Name of the Azure Container Registry')
param acrName string

@description('Name of the Azure AI Services')
param aiName string

@description('Name of the Azure AI Project')
param projectName string

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: keyVaultName
}

resource searchService 'Microsoft.Search/searchServices@2025-05-01' existing = {
  name: searchServiceName
}

resource acr 'Microsoft.ContainerRegistry/registries@2023-01-01-preview' existing = {
  name: acrName
}

resource aiServices 'Microsoft.CognitiveServices/accounts@2024-04-01-preview' existing = {
  name: aiName
}

resource project 'Microsoft.MachineLearningServices/workspaces@2025-06-01' existing = {
  name: projectName
}

var role_KeyVaultSecretsUser = subscriptionResourceId(
  'Microsoft.Authorization/roleDefinitions',
  '4633458b-17de-408a-b874-0445c86b69e6'
)
var role_AcrPull = subscriptionResourceId(
  'Microsoft.Authorization/roleDefinitions',
  '7f951dda-4ed3-4680-a7ca-43fe172d538d'
)
var role_AzureAIDeveloper = subscriptionResourceId(
  'Microsoft.Authorization/roleDefinitions',
  '64702f94-c441-49e6-a78b-ef80e0188fee'
)
var role_SearchIndexDataContributor = subscriptionResourceId(
  'Microsoft.Authorization/roleDefinitions',
  '1407120a-92aa-4202-b7e9-c0e197c71c8f'
)
var role_azureMLDataScientist = subscriptionResourceId(
  'Microsoft.Authorization/roleDefinitions',
  'f6c7c914-8db3-469d-8ca1-694a8f32e121'
)
var role_SearchServiceContributor = subscriptionResourceId(
  'Microsoft.Authorization/roleDefinitions',
  'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
)

// 🔹 Loop over both principals: UAMI + SP
var principals = [
  principalId
  spPrincipalId
]

// -----------------------------
// Key Vault: Secrets User
// -----------------------------
resource kvSecretsUser 'Microsoft.Authorization/roleAssignments@2022-04-01' = [
  for p in principals: {
    name: guid(keyVault.id, p, 'kv-secrets-user')
    scope: keyVault
    properties: {
      principalId: p
      roleDefinitionId: role_KeyVaultSecretsUser
      principalType: 'ServicePrincipal'
    }
  }
]

// -----------------------------
// Search: Data Contributor
// -----------------------------
resource searchDataContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = [
  for p in principals: {
    name: guid(searchService.id, p, 'search-data-contrib')
    scope: searchService
    properties: {
      principalId: p
      roleDefinitionId: role_SearchIndexDataContributor
      principalType: 'ServicePrincipal'
    }
  }
]

resource searchServiceContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = [
  for p in principals: {
    name: guid(searchService.id, p, 'search-service-contrib')
    scope: searchService
    properties: {
      principalId: p
      roleDefinitionId: role_SearchServiceContributor
      principalType: 'ServicePrincipal'
    }
  }
]
// -----------------------------
// ACR: AcrPull
// -----------------------------
resource acrPull 'Microsoft.Authorization/roleAssignments@2022-04-01' = [
  for p in principals: {
    name: guid(acr.id, p, 'acr-pull')
    scope: acr
    properties: {
      principalId: p
      roleDefinitionId: role_AcrPull
      principalType: 'ServicePrincipal'
    }
  }
]

// -----------------------------
// Azure AI Services: Developer
// -----------------------------
resource wsAIDev 'Microsoft.Authorization/roleAssignments@2022-04-01' = [
  for p in principals: {
    name: guid(aiServices.id, p, 'ai-developer')
    scope: aiServices
    properties: {
      principalId: p
      roleDefinitionId: role_AzureAIDeveloper
      principalType: 'ServicePrincipal'
    }
  }
]

// -----------------------------
// Azure ML Workspace: Data Scientist
// -----------------------------
resource azureMLDataScientistRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = [
  for p in principals: {
    name: guid(project.id, p, 'ml-scientist')
    scope: project
    properties: {
      principalId: p
      roleDefinitionId: role_azureMLDataScientist
      principalType: 'ServicePrincipal'
    }
  }
]
